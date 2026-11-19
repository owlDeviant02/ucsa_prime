/// ViewModel del tablero de tareas (capa ViewModel del patrón MVVM).
///
/// Lee los nodos `tareas` y `usuarios` de Realtime Database y entrega a
/// `TareasPage` las columnas pendiente, en progreso y completada ya ordenadas,
/// con el filtro «solo mis tareas» y las sugerencias de responsables. Cada alta,
/// edición, cambio de estado o baja se escribe junto con su registro de actividad.
library;

import 'package:firebase_database/firebase_database.dart';
import 'package:ucsa_prime/controllers/sesion_controller.dart';
import 'package:ucsa_prime/controllers/view_model.dart';
import 'package:ucsa_prime/models/actividad.dart';
import 'package:ucsa_prime/models/json.dart';
import 'package:ucsa_prime/models/tarea.dart';
import 'package:ucsa_prime/models/usuario.dart';
import 'package:ucsa_prime/services/firebase_service.dart';

/// Estado del tablero de tareas, con columnas ya filtradas y ordenadas.
class TareasEstado {
  const TareasEstado({
    this.cargando = true,
    this.error,
    this.todas = const [],
    this.soloMias = false,
    this.columnas = const {},
    this.responsables = const [],
  });

  final bool cargando;
  final String? error;
  final List<Tarea> todas;

  /// Solo se muestran las tareas asignadas al integrante con sesión iniciada.
  final bool soloMias;

  /// Tareas visibles agrupadas por estado, ya ordenadas.
  final Map<EstadoTarea, List<Tarea>> columnas;

  /// Sugerencias para "Asignado a": integrantes registrados y responsables usados.
  final List<String> responsables;

  /// Tareas de una columna del tablero.
  List<Tarea> columna(EstadoTarea estado) => columnas[estado] ?? const [];
}

/// ViewModel de tareas (nodo `tareas`).
class TareasController extends ViewModel<TareasEstado> {
  TareasController() : super(const TareasEstado());

  late final DatabaseReference _tareasRef = FirebaseService.ref(Rutas.tareas);
  late final DatabaseReference _raizRef = FirebaseService.ref(Rutas.raiz);
  List<Usuario> _miembros = const [];

  /// Tareas en tiempo real (también lo usa el inicio).
  Stream<List<Tarea>> obtenerTareasStream() =>
      _tareasRef.onValue.map((evento) => Tarea.listaDesdeNodo(evento.snapshot.value));

  /// Perfiles públicos de los integrantes (nodo `usuarios`).
  Stream<List<Usuario>> obtenerMiembrosStream() => FirebaseService.ref(Rutas.usuarios)
      .onValue
      .map((evento) => Usuario.listaDesdeNodo(evento.snapshot.value));

  /// Comienza a escuchar tareas e integrantes; la vista lo llama al abrirse.
  void iniciar() {
    escuchar<List<Tarea>>(
      obtenerTareasStream(),
      (tareas) => emitir(_calcular(tareas, estado.soloMias, cargando: false)),
      alFallar: (e) => emitir(_calcular(estado.todas, estado.soloMias,
          cargando: false, error: describirErrorFirebase(e))),
    );
    escuchar<List<Usuario>>(obtenerMiembrosStream(), (miembros) {
      _miembros = miembros;
      emitir(_calcular(estado.todas, estado.soloMias));
    });
  }

  /// Activa o desactiva el filtro «solo mis tareas».
  void alternarSoloMias() => emitir(_calcular(estado.todas, !estado.soloMias));

  TareasEstado _calcular(List<Tarea> tareas, bool soloMias, {bool? cargando, String? error}) {
    final yo = SesionController.instancia.nombreUsuario;
    final columnas = {for (final e in EstadoTarea.values) e: <Tarea>[]};
    for (final tarea in tareas) {
      if (soloMias && !tarea.asignadaA(yo)) continue;
      columnas[tarea.estado]!.add(tarea);
    }
    columnas[EstadoTarea.pendiente]!.sort(Tarea.compararParaTablero);
    columnas[EstadoTarea.enProgreso]!.sort(Tarea.compararParaTablero);
    columnas[EstadoTarea.completada]!.sort(Tarea.compararCompletadas);

    final nombres = <String, String>{};
    void agregar(String nombre) {
      final limpio = nombre.trim();
      if (limpio.isNotEmpty) nombres.putIfAbsent(normalizar(limpio), () => limpio);
    }

    agregar(yo);
    for (final miembro in _miembros) {
      agregar(miembro.nombre);
    }
    for (final tarea in tareas) {
      agregar(tarea.asignadoA);
    }
    return TareasEstado(
      cargando: cargando ?? estado.cargando,
      error: error,
      todas: tareas,
      soloMias: soloMias,
      columnas: columnas,
      responsables: nombres.values.toList(growable: false),
    );
  }

  /// Identificador para una tarea nueva (generado localmente con `push()`).
  String nuevoId() => FirebaseService.nuevaClave(Rutas.tareas);

  /// Alta ([nueva]) o edición de una tarea, con su registro de actividad.
  Future<void> guardar(Tarea tarea, {required bool nueva}) {
    return _raizRef.update({
      'tareas/${tarea.id}': tarea.toJson(),
      ...entradaActividad(
        TipoActividad.tarea,
        nueva ? 'Nueva tarea: "${tarea.titulo}"' : 'Tarea editada: "${tarea.titulo}"',
      ),
    });
  }

  /// Mueve la tarea a otra columna; al completarla se guarda la fecha de
  /// finalización y al reabrirla se borra.
  Future<void> cambiarEstado(Tarea tarea, EstadoTarea nuevo) {
    final actualizada = tarea.conEstado(nuevo);
    return _raizRef.update({
      'tareas/${tarea.id}/estado': nuevo.clave,
      'tareas/${tarea.id}/fechaCompletada': actualizada.toJson()['fechaCompletada'],
      ...entradaActividad(TipoActividad.tarea, '"${tarea.titulo}" → ${nuevo.etiqueta}'),
    });
  }

  /// Elimina la tarea y registra la actividad en una escritura multiruta.
  Future<void> eliminar(Tarea tarea) {
    return _raizRef.update({
      'tareas/${tarea.id}': null,
      ...entradaActividad(TipoActividad.tarea, 'Tarea eliminada: "${tarea.titulo}"'),
    });
  }

  /// Deshace una eliminación escribiendo de nuevo la tarea tal como estaba.
  Future<void> restaurar(Tarea tarea) => _tareasRef.child(tarea.id).set(tarea.toJson());
}
