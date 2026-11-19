/// Modelo del integrante del equipo (capa Modelo del patrón MVVM).
///
/// Representa al integrante con sesión iniciada (`SesionController`) y a los
/// perfiles públicos del nodo `usuarios/{id}` de Realtime Database, que
/// `TareasController` usa para sugerir responsables. El perfil público nunca
/// incluye la contraseña.
library;

import 'package:ucsa_prime/models/json.dart';

/// Integrante del equipo: el que tiene la sesión iniciada o uno de los perfiles
/// públicos registrados.
class Usuario {
  const Usuario({required this.id, required this.nombre, this.rol});

  final String id;
  final String nombre;
  final String? rol;

  /// Iniciales para el avatar ("Juan Pérez" → "JP").
  String get iniciales => inicialesDe(nombre);

  /// Perfil público en `usuarios/{id}` (nunca incluye la contraseña).
  Map<String, dynamic> toPerfilJson(String ultimoAcceso) => {
        'nombre': nombre,
        if (rol != null && rol!.isNotEmpty) 'rol': rol,
        'ultimoAcceso': ultimoAcceso,
      };

  /// Deserialización tolerante: acepta el campo `nombre` del perfil o `name`
  /// del nodo de la cuenta.
  factory Usuario.fromJson(String id, Map<String, dynamic> json) => Usuario(
        id: id,
        nombre: comoTexto(json['nombre'] ?? json['name'], id),
        rol: json['rol']?.toString(),
      );

  /// Convierte el nodo `usuarios` en una lista ordenada alfabéticamente.
  static List<Usuario> listaDesdeNodo(Object? valor) {
    final lista = [
      for (final hijo in hijosDe(valor))
        if (hijo.value is Map) Usuario.fromJson(hijo.key, comoMapa(hijo.value)),
    ];
    lista.sort((a, b) => normalizar(a.nombre).compareTo(normalizar(b.nombre)));
    return lista;
  }
}

/// Iniciales de un nombre (máximo dos letras).
String inicialesDe(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return (partes.first[0] + partes.last[0]).toUpperCase();
}
