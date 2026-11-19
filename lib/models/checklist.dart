/// Modelos del checklist pre-partido (capa Modelo del patrón MVVM).
///
/// Las plantillas por robot son constantes de la aplicación; cada checklist
/// completado se guarda como [RegistroChecklist] en el nodo `checklists` de
/// Realtime Database. Los usa `ChecklistController` y la pantalla de inicio
/// (último checklist registrado).
library;

import 'package:ucsa_prime/models/json.dart';
import 'package:ucsa_prime/utils/fechas.dart';

/// Plantilla de verificación de un robot (ítems definidos por el equipo).
class PlantillaChecklist {
  const PlantillaChecklist({
    required this.robot,
    required this.descripcion,
    required this.imagen,
    required this.fondo,
    required this.items,
  });

  final String robot;
  final String descripcion;

  /// Recurso (asset) con la imagen del robot.
  final String imagen;

  /// Recurso (asset) con la imagen de fondo de la tarjeta.
  final String fondo;

  /// Ítems que se verifican antes de cada partido, en orden.
  final List<String> items;
}

/// Plantillas de la versión anterior de la aplicación, sin cambios en los ítems.
const List<PlantillaChecklist> plantillasChecklist = [
  PlantillaChecklist(
    robot: 'Jordan',
    descripcion: 'VEX U · High Stakes',
    imagen: 'assets/robots/jordan.png',
    fondo: 'assets/backgrounds/michael.jpg',
    items: [
      'Batería', 'Carga Aire', 'Sensor Inercial', 'Placa UCSA', 'Válvula', //
      'Cadena', 'Tragadera', 'Brazo', 'Puertos', 'Pantalla',
    ],
  ),
  PlantillaChecklist(
    robot: 'TARS',
    descripcion: 'Robot del equipo',
    imagen: 'assets/robots/tars.png',
    fondo: 'assets/backgrounds/tars.jpg',
    items: [
      'Batería', 'Carga Aire', 'Placa UCSA', 'Válvula', 'Sensor Inercial', //
      'Cadena', 'Tragadera', 'Elevación', 'Puertos', 'Pantalla',
    ],
  ),
  PlantillaChecklist(
    robot: 'Pochita',
    descripcion: 'Robot del equipo',
    imagen: 'assets/robots/pochita.png',
    fondo: 'assets/backgrounds/pochita.png',
    items: [
      'Batería', 'Puertos', 'Placa UCSA', 'Sensor Inercial', 'Carga Aire', 'Válvula', //
      'Cinta Transportadora', 'Cadenas tragadera', 'Cadenas Ruedas Frente',
      'Movimiento Lineal', 'Movimiento Angular', 'Pantalla',
    ],
  ),
  PlantillaChecklist(
    robot: 'BMO',
    descripcion: 'Robot del equipo',
    imagen: 'assets/robots/bmo.png',
    fondo: 'assets/backgrounds/bmo.png',
    items: [
      'Batería', 'Carga Aire', 'Placa UCSA', 'Válvula', 'Cadena', 'Tragadera', //
      'Puertos', 'Pantalla',
    ],
  ),
];

/// Resultado de un ítem: verificado o no, con la hora de verificación.
class ItemVerificado {
  const ItemVerificado({required this.nombre, required this.ok, this.hora});

  final String nombre;
  final bool ok;
  final DateTime? hora;

  /// Serialización para Firebase (la hora solo si el ítem se verificó).
  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'ok': ok,
        if (hora != null) 'hora': fechaIso(hora!),
      };

  /// Deserialización tolerante a datos incompletos.
  factory ItemVerificado.fromJson(Map<String, dynamic> json) => ItemVerificado(
        nombre: comoTexto(json['nombre'], '¿?'),
        ok: comoBool(json['ok']),
        hora: leerFecha(json['hora']),
      );
}

/// Checklist registrado (nodo `checklists/{id}`): queda el historial por robot.
class RegistroChecklist {
  const RegistroChecklist({
    required this.id,
    required this.robot,
    required this.fecha,
    required this.usuario,
    required this.items,
    this.observaciones = '',
  });

  final String id;
  final String robot;
  final DateTime fecha;
  final String usuario;
  final List<ItemVerificado> items;
  final String observaciones;

  int get total => items.length;
  int get completados => items.where((i) => i.ok).length;
  bool get completo => total > 0 && completados == total;

  /// Nombres de los ítems que quedaron sin verificar.
  Iterable<String> get pendientes => items.where((i) => !i.ok).map((i) => i.nombre);

  /// Serialización para Firebase; incluye los conteos para consultarlos sin
  /// recorrer los ítems.
  Map<String, dynamic> toJson() => {
        'robot': robot,
        'fecha': fechaIso(fecha),
        'usuario': usuario,
        'completados': completados,
        'total': total,
        'items': [for (final item in items) item.toJson()],
        if (observaciones.isNotEmpty) 'observaciones': observaciones,
      };

  /// Deserialización tolerante a datos incompletos.
  factory RegistroChecklist.fromJson(String id, Map<String, dynamic> json) {
    // Firebase devuelve las listas como List o como Map con claves "0", "1"…
    final items = [
      for (final hijo in hijosDe(json['items']))
        if (hijo.value is Map) ItemVerificado.fromJson(comoMapa(hijo.value)),
    ];
    return RegistroChecklist(
      id: id,
      robot: comoTexto(json['robot'], 'Robot'),
      fecha: leerFecha(json['fecha']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      usuario: comoTexto(json['usuario'], 'Desconocido'),
      items: items,
      observaciones: comoTexto(json['observaciones']),
    );
  }

  /// Lista del más reciente al más antiguo.
  static List<RegistroChecklist> listaDesdeNodo(Object? valor) {
    final lista = [
      for (final hijo in hijosDe(valor))
        if (hijo.value is Map) RegistroChecklist.fromJson(hijo.key, comoMapa(hijo.value)),
    ];
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }
}
