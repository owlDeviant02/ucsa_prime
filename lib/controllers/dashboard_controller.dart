/// ViewModel de la pantalla de inicio (`InicioPage`), capa ViewModel del patrón MVVM.
///
/// Combina en un único [ResumenDashboard] los flujos de inventario, tareas,
/// bitácoras, checklists y el registro de `actividad`, además del estado de la
/// conexión con Realtime Database (`.info/connected`). También carga y quita los
/// datos de demostración desde el menú del inicio.
library;

import 'dart:async';

import 'package:ucsa_prime/controllers/bitacora_controller.dart';
import 'package:ucsa_prime/controllers/checklist_controller.dart';
import 'package:ucsa_prime/controllers/inventario_controller.dart';
import 'package:ucsa_prime/controllers/sesion_controller.dart';
import 'package:ucsa_prime/controllers/tareas_controller.dart';
import 'package:ucsa_prime/controllers/view_model.dart';
import 'package:ucsa_prime/models/actividad.dart';
import 'package:ucsa_prime/models/bitacora.dart';
import 'package:ucsa_prime/models/checklist.dart';
import 'package:ucsa_prime/models/componente_inventario.dart';
import 'package:ucsa_prime/models/tarea.dart';
import 'package:ucsa_prime/services/datos_demo.dart';
import 'package:ucsa_prime/services/firebase_service.dart';

/// Resumen que muestra la pantalla de inicio. Los campos `null` significan
/// "todavía cargando".
class ResumenDashboard {
  const ResumenDashboard({
    this.conexion,
    this.totalComponentes,
    this.stockBajo = const [],
    this.tareasActivas,
    this.tareasVencidas = 0,
    this.misTareasActivas = 0,
    this.totalBitacoras,
    this.ultimaBitacora,
    this.checklistCargado = false,
    this.ultimoChecklist,
    this.actividad = const [],
    this.actividadCargada = false,
  });

  /// `null`: conectando; `true`: en línea; `false`: sin conexión (modo offline).
  final bool? conexion;
  final int? totalComponentes;

  /// Componentes en o por debajo del mínimo, del más crítico al menos crítico.
  final List<ComponenteInventario> stockBajo;

  /// Tareas no completadas.
  final int? tareasActivas;
  final int tareasVencidas;

  /// Tareas activas asignadas al integrante con sesión iniciada.
  final int misTareasActivas;
  final int? totalBitacoras;
  final EntradaBitacora? ultimaBitacora;
  final bool checklistCargado;
  final RegistroChecklist? ultimoChecklist;

  /// Últimos eventos del registro de actividad del equipo.
  final List<Actividad> actividad;
  final bool actividadCargada;
}

/// ViewModel del inicio: combina los flujos de los demás módulos en un resumen.
class DashboardController extends ViewModel<ResumenDashboard> {
  DashboardController() : super(const ResumenDashboard());

  // Se reutilizan los flujos de datos de cada módulo (misma fuente que sus pantallas;
  // el SDK comparte una sola sincronización por ruta).
  final InventarioController _inventario = InventarioController();
  final TareasController _tareas = TareasController();
  final BitacoraController _bitacoras = BitacoraController();
  final ChecklistController _checklists = ChecklistController();

  bool? _conexion;
  bool _ultimaConexion = false;
  Timer? _graciaConexion;
  List<ComponenteInventario>? _componentes;
  List<Tarea>? _listaTareas;
  List<EntradaBitacora>? _listaBitacoras;
  bool _checklistCargado = false;
  RegistroChecklist? _ultimoChecklist;
  List<Actividad>? _actividad;

  /// Comienza a escuchar todos los flujos; la vista lo llama al abrirse.
  void iniciar() {
    // Al abrir la app `.info/connected` vale false hasta que se establece la
    // conexión: durante unos segundos se muestra "Conectando…" en lugar de un
    // falso "Sin conexión".
    _graciaConexion = Timer(const Duration(seconds: 5), () {
      _conexion = _ultimaConexion;
      _emitir();
    });
    escuchar<bool>(FirebaseService.conexion(), (conectado) {
      _ultimaConexion = conectado;
      if (conectado || _graciaConexion?.isActive != true) {
        _conexion = conectado;
        _emitir();
      }
    });
    escuchar<List<ComponenteInventario>>(_inventario.obtenerInventarioStream(), (lista) {
      _componentes = lista;
      _emitir();
    });
    escuchar<List<Tarea>>(_tareas.obtenerTareasStream(), (lista) {
      _listaTareas = lista;
      _emitir();
    });
    escuchar<List<EntradaBitacora>>(_bitacoras.obtenerBitacorasStream(), (lista) {
      _listaBitacoras = lista;
      _emitir();
    });
    escuchar<List<RegistroChecklist>>(_checklists.obtenerHistorialStream(limite: 1), (lista) {
      _checklistCargado = true;
      _ultimoChecklist = lista.isEmpty ? null : lista.first;
      _emitir();
    });
    escuchar<List<Actividad>>(
      FirebaseService.ref(Rutas.actividad)
          .orderByKey()
          .limitToLast(6)
          .onValue
          .map((evento) => Actividad.listaDesdeNodo(evento.snapshot.value)),
      (lista) {
        _actividad = lista;
        _emitir();
      },
    );
  }

  void _emitir() {
    final ahora = DateTime.now();
    final yo = SesionController.instancia.nombreUsuario;
    final tareas = _listaTareas;
    final activas = tareas?.where((t) => !t.completada).toList();
    // Los más críticos primero (mayor faltante respecto del mínimo).
    final stockBajo = [...?_componentes?.where((c) => c.stockBajo)]
      ..sort((a, b) => (a.cantidadDisponible - a.cantidadMinima)
          .compareTo(b.cantidadDisponible - b.cantidadMinima));
    final bitacoras = _listaBitacoras;
    emitir(ResumenDashboard(
      conexion: _conexion,
      totalComponentes: _componentes?.length,
      stockBajo: stockBajo,
      tareasActivas: activas?.length,
      tareasVencidas: activas?.where((t) => t.estaVencida(ahora)).length ?? 0,
      misTareasActivas: activas?.where((t) => t.asignadaA(yo)).length ?? 0,
      totalBitacoras: bitacoras?.length,
      ultimaBitacora: (bitacoras == null || bitacoras.isEmpty) ? null : bitacoras.first,
      checklistCargado: _checklistCargado,
      ultimoChecklist: _ultimoChecklist,
      actividad: _actividad ?? const [],
      actividadCargada: _actividad != null,
    ));
  }

  /// Carga (o vuelve a cargar) los datos de demostración en una sola escritura atómica.
  Future<void> cargarDatosDemo() {
    return FirebaseService.ref(Rutas.raiz).update({
      ...DatosDemo.cambiosCarga(usuario: SesionController.instancia.nombreUsuario, ahora: DateTime.now()),
      ...entradaActividad(TipoActividad.sistema, 'Se cargaron los datos de demostración'),
    });
  }

  /// Quita solo los datos con prefijo `demo-`, sin tocar los datos reales.
  Future<void> quitarDatosDemo() {
    return FirebaseService.ref(Rutas.raiz).update({
      ...DatosDemo.cambiosBorrado(),
      ...entradaActividad(TipoActividad.sistema, 'Se quitaron los datos de demostración'),
    });
  }

  @override
  void dispose() {
    _graciaConexion?.cancel();
    _inventario.dispose();
    _tareas.dispose();
    _bitacoras.dispose();
    _checklists.dispose();
    super.dispose();
  }
}
