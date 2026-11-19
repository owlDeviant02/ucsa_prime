/// Modelo de las tareas del proyecto (capa Modelo del patrón MVVM).
///
/// Cada tarea es un nodo `tareas/{id}` de Realtime Database. Define la prioridad,
/// los estados del tablero, la serialización tolerante y los criterios de orden y
/// de vencimiento que usan `TareasController` y la pantalla de inicio.
library;

import 'package:ucsa_prime/models/json.dart';
import 'package:ucsa_prime/utils/fechas.dart';

/// Prioridad de una tarea. [clave] es el valor guardado en Firebase y
/// [etiqueta], el texto visible.
enum PrioridadTarea {
  alta('alta', 'Alta'),
  media('media', 'Media'),
  baja('baja', 'Baja');

  const PrioridadTarea(this.clave, this.etiqueta);
  final String clave;
  final String etiqueta;

  /// Prioridad a partir del valor guardado; si no se reconoce, [media].
  static PrioridadTarea desdeClave(Object? valor) {
    final clave = normalizar(comoTexto(valor));
    return PrioridadTarea.values.firstWhere((p) => p.clave == clave, orElse: () => media);
  }
}

/// Estados del tablero (pendiente / en progreso / completada).
enum EstadoTarea {
  pendiente('pendiente', 'Pendiente', 'Pendientes'),
  enProgreso('en_progreso', 'En progreso', 'En progreso'),
  completada('completada', 'Completada', 'Completadas');

  const EstadoTarea(this.clave, this.etiqueta, this.plural);
  final String clave;
  final String etiqueta;
  final String plural;

  /// Estado al que avanza la acción rápida de la tarjeta.
  EstadoTarea get siguiente => switch (this) {
        EstadoTarea.pendiente => EstadoTarea.enProgreso,
        EstadoTarea.enProgreso => EstadoTarea.completada,
        EstadoTarea.completada => EstadoTarea.pendiente,
      };

  /// Estado a partir del valor guardado; acepta variantes cargadas a mano
  /// («en progreso», «hecha», «terminada»…) y, si no se reconoce, [pendiente].
  static EstadoTarea desdeClave(Object? valor) {
    final clave = normalizar(comoTexto(valor)).replaceAll(RegExp(r'[\s-]+'), '_');
    return switch (clave) {
      'en_progreso' || 'enprogreso' || 'progreso' => EstadoTarea.enProgreso,
      'completada' || 'completado' || 'hecha' || 'terminada' => EstadoTarea.completada,
      _ => EstadoTarea.pendiente,
    };
  }
}

/// Tarea del proyecto (nodo `tareas/{id}`, apartado IV.6.2.1).
class Tarea {
  const Tarea({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    this.asignadoA = '',
    this.prioridad = PrioridadTarea.media,
    this.estado = EstadoTarea.pendiente,
    required this.fechaCreacion,
    this.fechaVencimiento,
    this.creadoPor = '',
    this.fechaCompletada,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final String asignadoA;
  final PrioridadTarea prioridad;
  final EstadoTarea estado;
  final DateTime fechaCreacion;
  final DateTime? fechaVencimiento;
  final String creadoPor;
  final DateTime? fechaCompletada;

  bool get completada => estado == EstadoTarea.completada;

  /// Vencida: no completada y con fecha límite anterior al día de hoy.
  bool estaVencida(DateTime ahora) =>
      !completada && fechaVencimiento != null && diasEntre(ahora, fechaVencimiento!) < 0;

  /// Vence hoy o mañana (aviso anticipado).
  bool venceProntoDesde(DateTime ahora) {
    if (completada || fechaVencimiento == null) return false;
    final dias = diasEntre(ahora, fechaVencimiento!);
    return dias >= 0 && dias <= 1;
  }

  /// La tarea está asignada a [persona] (comparación sin mayúsculas ni acentos).
  bool asignadaA(String persona) {
    final buscado = normalizar(persona);
    return buscado.isNotEmpty && normalizar(asignadoA) == buscado;
  }

  /// Serialización para Firebase (el id es la clave del nodo).
  Map<String, dynamic> toJson() => {
        'titulo': titulo,
        'descripcion': descripcion,
        'asignadoA': asignadoA,
        'prioridad': prioridad.clave,
        'estado': estado.clave,
        'fechaCreacion': fechaIso(fechaCreacion),
        if (fechaVencimiento != null) 'fechaVencimiento': fechaIso(fechaVencimiento!),
        'creadoPor': creadoPor,
        if (fechaCompletada != null) 'fechaCompletada': fechaIso(fechaCompletada!),
      };

  /// Deserialización tolerante a datos incompletos.
  factory Tarea.fromJson(String id, Map<String, dynamic> json) {
    return Tarea(
      id: id,
      titulo: comoTexto(json['titulo'], 'Sin título'),
      descripcion: comoTexto(json['descripcion']),
      asignadoA: comoTexto(json['asignadoA']),
      prioridad: PrioridadTarea.desdeClave(json['prioridad']),
      estado: EstadoTarea.desdeClave(json['estado']),
      fechaCreacion: leerFecha(json['fechaCreacion']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      fechaVencimiento: leerFecha(json['fechaVencimiento']),
      creadoPor: comoTexto(json['creadoPor']),
      fechaCompletada: leerFecha(json['fechaCompletada']),
    );
  }

  /// Copia con otro estado; registra o limpia la fecha de finalización.
  Tarea conEstado(EstadoTarea nuevo, {DateTime? ahora}) => Tarea(
        id: id,
        titulo: titulo,
        descripcion: descripcion,
        asignadoA: asignadoA,
        prioridad: prioridad,
        estado: nuevo,
        fechaCreacion: fechaCreacion,
        fechaVencimiento: fechaVencimiento,
        creadoPor: creadoPor,
        fechaCompletada: nuevo == EstadoTarea.completada ? (ahora ?? DateTime.now()) : null,
      );

  /// Convierte el nodo `tareas` en una lista (sin ordenar: el orden lo define el tablero).
  static List<Tarea> listaDesdeNodo(Object? valor) => [
        for (final hijo in hijosDe(valor))
          if (hijo.value is Map) Tarea.fromJson(hijo.key, comoMapa(hijo.value)),
      ];

  /// Orden del tablero: prioridad (alta primero), vencimiento más próximo y,
  /// a igualdad, la más reciente.
  static int compararParaTablero(Tarea a, Tarea b) {
    final prioridad = a.prioridad.index.compareTo(b.prioridad.index);
    if (prioridad != 0) return prioridad;
    final va = a.fechaVencimiento;
    final vb = b.fechaVencimiento;
    if (va != null && vb != null) {
      final vencimiento = va.compareTo(vb);
      if (vencimiento != 0) return vencimiento;
    } else if (va != null) {
      return -1;
    } else if (vb != null) {
      return 1;
    }
    return b.fechaCreacion.compareTo(a.fechaCreacion);
  }

  /// Completadas: la más recientemente terminada primero.
  static int compararCompletadas(Tarea a, Tarea b) =>
      (b.fechaCompletada ?? b.fechaCreacion).compareTo(a.fechaCompletada ?? a.fechaCreacion);
}
