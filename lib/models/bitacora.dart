/// Modelo de la bitácora técnica (capa Model del patrón MVVM).
///
/// Cada entrada es un nodo `bitacoras/{id}` de Firebase Realtime Database, con
/// fecha, autor, tipo de registro, el texto y la marca `generadaPorIA` cuando el
/// apunte informal se reescribió en versión formal con Gemini. Lo consumen
/// `BitacoraController` y `EditorBitacoraController`, y las vistas de
/// `views/bitacora/`. También convierte los registros sueltos que la versión 2.0
/// guardaba en la raíz de la base.
library;

import 'package:ucsa_prime/models/json.dart';
import 'package:ucsa_prime/utils/fechas.dart';

/// Tipo de registro de la bitácora (filtro de la lista y chip del editor).
enum TipoBitacora {
  prueba('prueba', 'Prueba'),
  diseno('diseno', 'Diseño'),
  construccion('construccion', 'Construcción'),
  programacion('programacion', 'Programación'),
  competencia('competencia', 'Competencia'),
  reunion('reunion', 'Reunión'),
  otro('otro', 'Otro');

  const TipoBitacora(this.clave, this.etiqueta);

  /// Valor que se guarda en Firebase.
  final String clave;

  /// Texto visible en la interfaz.
  final String etiqueta;

  /// Tipo a partir del valor guardado (tolerante a acentos y mayúsculas); si no
  /// se reconoce, [otro].
  static TipoBitacora desdeClave(Object? valor) {
    final clave = normalizar(comoTexto(valor));
    return TipoBitacora.values.firstWhere((t) => t.clave == clave, orElse: () => otro);
  }
}

/// Entrada de la bitácora técnica (nodo `bitacoras/{id}`, apartado IV.6.2.1).
class EntradaBitacora {
  const EntradaBitacora({
    required this.id,
    required this.fecha,
    required this.autor,
    required this.tipo,
    required this.contenido,
    this.generadaPorIA = false,
    this.apunteOriginal,
    this.autorId,
    this.importada = false,
  });

  /// Clave del nodo en Firebase.
  final String id;

  /// Fecha y hora del registro.
  final DateTime fecha;

  /// Nombre del integrante que escribió la entrada.
  final String autor;

  /// Tipo de registro.
  final TipoBitacora tipo;

  /// Texto de la entrada (el formal, si se usó IA).
  final String contenido;

  /// Verdadero si el texto fue formalizado con Gemini (trazabilidad del uso de IA).
  final bool generadaPorIA;

  /// Apunte informal que dio origen al texto formal (solo si se usó IA).
  final String? apunteOriginal;

  /// Identificador del autor (cuenta con la que se inició sesión).
  final String? autorId;

  /// Registro migrado desde la versión anterior de la aplicación.
  final bool importada;

  /// Largo máximo del título en la lista; una primera línea más larga se corta
  /// en [_corteTitulo] caracteres y se completa con «…».
  static const int _largoTitulo = 90;
  static const int _corteTitulo = 87;

  /// Primera línea no vacía, usada como título en la lista.
  String get titulo {
    for (final linea in contenido.split('\n')) {
      final limpia = linea.trim();
      if (limpia.isNotEmpty) {
        return limpia.length > _largoTitulo ? '${limpia.substring(0, _corteTitulo)}…' : limpia;
      }
    }
    return 'Entrada sin texto';
  }

  /// Texto que sigue al [titulo], para la vista previa de la lista (sin repetir
  /// el título). Si la primera línea se cortó, continúa desde el corte con «…»;
  /// si no hay nada más, devuelve una cadena vacía. Los saltos de línea se
  /// reemplazan por espacios.
  String get vistaPrevia {
    final lineas = contenido.split('\n');
    final indice = lineas.indexWhere((l) => l.trim().isNotEmpty);
    if (indice < 0) return '';
    final primera = lineas[indice].trim();
    final resto = lineas.skip(indice + 1).map((l) => l.trim()).where((l) => l.isNotEmpty).join(' ');
    if (primera.length > _largoTitulo) {
      final continuacion = primera.substring(_corteTitulo).trimLeft();
      return '…$continuacion${resto.isEmpty ? '' : ' $resto'}';
    }
    return resto;
  }

  /// Datos que se escriben en `bitacoras/{id}`.
  Map<String, dynamic> toJson() => {
        'fecha': fechaIso(fecha),
        'autor': autor,
        if (autorId != null) 'autorId': autorId,
        'tipo': tipo.clave,
        'contenido': contenido,
        'generadaPorIA': generadaPorIA,
        if (apunteOriginal != null && apunteOriginal!.isNotEmpty) 'apunteOriginal': apunteOriginal,
        if (importada) 'importada': true,
      };

  /// Entrada a partir de un nodo de Firebase (tolera campos faltantes).
  factory EntradaBitacora.fromJson(String id, Map<String, dynamic> json) {
    return EntradaBitacora(
      id: id,
      fecha: leerFecha(json['fecha']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      autor: comoTexto(json['autor'], 'Desconocido'),
      autorId: json['autorId']?.toString(),
      tipo: TipoBitacora.desdeClave(json['tipo']),
      contenido: comoTexto(json['contenido']),
      generadaPorIA: comoBool(json['generadaPorIA']),
      apunteOriginal: json['apunteOriginal']?.toString(),
      importada: comoBool(json['importada']),
    );
  }

  /// Lista ordenada de la más reciente a la más antigua.
  static List<EntradaBitacora> listaDesdeNodo(Object? valor) {
    final lista = [
      for (final hijo in hijosDe(valor))
        if (hijo.value is Map) EntradaBitacora.fromJson(hijo.key, comoMapa(hijo.value)),
    ];
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  /// Claves que la versión 2.0 escribía en la raíz de la base:
  /// `d-m-aaaa_h-m-s_Nombre` con el texto como valor.
  static final RegExp _claveAntigua =
      RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})_(\d{1,2})-(\d{1,2})-(\d{1,2})_(.+)$');

  /// Convierte un registro antiguo en una entrada; `null` si la clave no corresponde.
  static EntradaBitacora? desdeRegistroAntiguo(String clave, Object? valor) {
    if (valor is! String || valor.trim().isEmpty) return null;
    final m = _claveAntigua.firstMatch(clave);
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i)!);
    final dia = g(1), mes = g(2);
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
    return EntradaBitacora(
      id: 'legacy-$clave',
      fecha: DateTime(g(3), mes, dia, g(4), g(5), g(6)),
      autor: m.group(7)!.trim(),
      tipo: TipoBitacora.otro,
      contenido: valor.trim(),
      importada: true,
    );
  }
}
