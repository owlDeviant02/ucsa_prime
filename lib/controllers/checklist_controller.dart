/// ViewModel del checklist pre-partido (capa ViewModel del patrón MVVM).
///
/// Las marcas de verificación de cada robot viven solo en memoria mientras se
/// completa el checklist en `ChecklistPage`; al registrarlo se escribe en el
/// nodo `checklists` de Realtime Database, con la hora de cada ítem y su entrada
/// en el registro de actividad. También expone el historial reciente.
library;

import 'package:firebase_database/firebase_database.dart';
import 'package:ucsa_prime/controllers/sesion_controller.dart';
import 'package:ucsa_prime/controllers/view_model.dart';
import 'package:ucsa_prime/models/actividad.dart';
import 'package:ucsa_prime/models/checklist.dart';
import 'package:ucsa_prime/services/firebase_service.dart';

/// Estado del checklist: robot seleccionado, marcas en curso e historial.
class ChecklistEstado {
  const ChecklistEstado({
    this.indice = 0,
    this.marcas = const {},
    this.historial = const [],
    this.cargandoHistorial = true,
    this.errorHistorial,
  });

  /// Robot seleccionado (índice en [plantillasChecklist]).
  final int indice;

  /// Por robot: ítem verificado → hora de verificación. Se conserva el avance
  /// de cada robot al cambiar de uno a otro.
  final Map<String, Map<String, DateTime>> marcas;

  /// Últimos checklists registrados, del más reciente al más antiguo.
  final List<RegistroChecklist> historial;
  final bool cargandoHistorial;
  final String? errorHistorial;

  /// Plantilla del robot seleccionado.
  PlantillaChecklist get plantilla => plantillasChecklist[indice];

  /// Marcas del robot seleccionado.
  Map<String, DateTime> get marcasActuales => marcas[plantilla.robot] ?? const {};
  int get total => plantilla.items.length;
  int get completados => plantilla.items.where(marcasActuales.containsKey).length;
  bool get completo => completados == total;

  /// Avance entre 0 y 1, para la barra de progreso.
  double get progreso => total == 0 ? 0 : completados / total;

  /// Último checklist registrado de [robot] dentro del historial cargado.
  RegistroChecklist? ultimoDe(String robot) {
    for (final registro in historial) {
      if (registro.robot == robot) return registro;
    }
    return null;
  }
}

/// ViewModel del checklist pre-partido (nodo `checklists`).
class ChecklistController extends ViewModel<ChecklistEstado> {
  ChecklistController() : super(const ChecklistEstado());

  late final DatabaseReference _checklistsRef = FirebaseService.ref(Rutas.checklists);

  /// Últimos registros (las claves de `push()` son cronológicas: no hace falta índice).
  Stream<List<RegistroChecklist>> obtenerHistorialStream({int limite = 25}) => _checklistsRef
      .orderByKey()
      .limitToLast(limite)
      .onValue
      .map((evento) => RegistroChecklist.listaDesdeNodo(evento.snapshot.value));

  /// Comienza a escuchar el historial; la vista lo llama al abrirse.
  void iniciar() {
    escuchar<List<RegistroChecklist>>(
      obtenerHistorialStream(),
      (historial) => emitir(_copiar(historial: historial, cargandoHistorial: false)),
      alFallar: (e) => emitir(_copiar(
        cargandoHistorial: false,
        errorHistorial: describirErrorFirebase(e),
      )),
    );
  }

  ChecklistEstado _copiar({
    int? indice,
    Map<String, Map<String, DateTime>>? marcas,
    List<RegistroChecklist>? historial,
    bool? cargandoHistorial,
    String? errorHistorial,
  }) {
    return ChecklistEstado(
      indice: indice ?? estado.indice,
      marcas: marcas ?? estado.marcas,
      historial: historial ?? estado.historial,
      cargandoHistorial: cargandoHistorial ?? estado.cargandoHistorial,
      errorHistorial: errorHistorial,
    );
  }

  /// Cambia de robot; se conservan las marcas de cada uno.
  void seleccionarRobot(int indice) {
    if (indice != estado.indice) emitir(_copiar(indice: indice));
  }

  void _actualizarMarcas(Map<String, DateTime> nuevas) {
    emitir(_copiar(marcas: {...estado.marcas, estado.plantilla.robot: nuevas}));
  }

  /// Marca o desmarca un ítem; al marcarlo se guarda la hora de verificación.
  void alternar(String item) {
    final nuevas = Map<String, DateTime>.of(estado.marcasActuales);
    if (nuevas.remove(item) == null) nuevas[item] = DateTime.now();
    _actualizarMarcas(nuevas);
  }

  /// Marca los ítems pendientes con la hora actual; los ya marcados conservan su hora.
  void marcarTodo() {
    final ahora = DateTime.now();
    final nuevas = Map<String, DateTime>.of(estado.marcasActuales);
    for (final item in estado.plantilla.items) {
      nuevas.putIfAbsent(item, () => ahora);
    }
    _actualizarMarcas(nuevas);
  }

  /// Borra las marcas del robot seleccionado.
  void reiniciar() => _actualizarMarcas(const {});

  /// Registra el checklist del robot seleccionado (con hora de cada verificación)
  /// y reinicia sus marcas. La escritura se sincroniza en segundo plano.
  Future<void> registrar({String observaciones = ''}) {
    final plantilla = estado.plantilla;
    final marcas = estado.marcasActuales;
    final clave = FirebaseService.nuevaClave(Rutas.checklists);
    final registro = RegistroChecklist(
      id: clave,
      robot: plantilla.robot,
      fecha: DateTime.now(),
      usuario: SesionController.instancia.nombreUsuario,
      items: [
        for (final item in plantilla.items)
          ItemVerificado(nombre: item, ok: marcas.containsKey(item), hora: marcas[item]),
      ],
      observaciones: observaciones.trim(),
    );
    reiniciar();
    return FirebaseService.ref(Rutas.raiz).update({
      'checklists/$clave': registro.toJson(),
      ...entradaActividad(
        TipoActividad.checklist,
        'Checklist de ${registro.robot}: ${registro.completados}/${registro.total}'
        '${registro.completo ? ' ✓' : ''}',
      ),
    });
  }
}
