/// Modelo del registro de actividad del equipo (capa Modelo del patrón MVVM).
///
/// Cada operación de los módulos (inventario, tareas, bitácora, checklist) deja
/// un evento inmutable en el nodo `actividad` de Realtime Database, escrito junto
/// con la operación mediante `entradaActividad` (lib/controllers/sesion_controller.dart).
/// La pantalla de inicio muestra los más recientes.
library;

import 'package:ucsa_prime/models/json.dart';
import 'package:ucsa_prime/utils/fechas.dart';

/// Módulo que originó un evento de actividad. [clave] es el valor guardado en Firebase.
enum TipoActividad {
  inventario('inventario'),
  tarea('tarea'),
  bitacora('bitacora'),
  checklist('checklist'),
  sistema('sistema');

  const TipoActividad(this.clave);
  final String clave;

  /// Tipo a partir de la clave guardada; si no se reconoce, [sistema].
  static TipoActividad desdeClave(Object? valor) =>
      TipoActividad.values.firstWhere((t) => t.clave == valor, orElse: () => sistema);
}

/// Evento del registro de actividad del equipo (nodo `actividad/{id}`): da
/// trazabilidad a quién hizo qué y cuándo en todos los módulos.
class Actividad {
  const Actividad({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.usuario,
    required this.fecha,
  });

  final String id;
  final TipoActividad tipo;
  final String descripcion;
  final String usuario;
  final DateTime fecha;

  /// Serialización para Firebase (el id es la clave del nodo, no se repite).
  Map<String, dynamic> toJson() => {
        'tipo': tipo.clave,
        'descripcion': descripcion,
        'usuario': usuario,
        'fecha': fechaIso(fecha),
      };

  /// Deserialización tolerante a datos incompletos.
  factory Actividad.fromJson(String id, Map<String, dynamic> json) => Actividad(
        id: id,
        tipo: TipoActividad.desdeClave(json['tipo']),
        descripcion: comoTexto(json['descripcion']),
        usuario: comoTexto(json['usuario'], 'Desconocido'),
        fecha: leerFecha(json['fecha']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Convierte el nodo `actividad` en una lista del evento más reciente al más antiguo.
  static List<Actividad> listaDesdeNodo(Object? valor) {
    final lista = [
      for (final hijo in hijosDe(valor))
        if (hijo.value is Map) Actividad.fromJson(hijo.key, comoMapa(hijo.value)),
    ];
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }
}
