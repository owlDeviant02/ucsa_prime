/// Conversión tolerante de los valores que entrega Firebase Realtime Database.
///
/// El SDK devuelve `Map<Object?, Object?>`, `List<Object?>` (cuando las claves
/// son números consecutivos), `int`, `double`, `bool` o `String`. Estas funciones
/// evitan que un dato mal cargado desde la consola rompa la interfaz. Las usan
/// los `fromJson` de los modelos (capa Modelo del patrón MVVM) y los filtros de
/// búsqueda de los controladores ([normalizar]).
library;

/// Convierte cualquier mapa en `Map<String, dynamic>`; si no es un mapa, devuelve uno vacío.
Map<String, dynamic> comoMapa(Object? valor) {
  if (valor is Map) {
    return valor.map((clave, dato) => MapEntry(clave.toString(), dato));
  }
  return <String, dynamic>{};
}

/// Entero a partir de int, double o texto numérico.
int comoEntero(Object? valor, [int porDefecto = 0]) {
  if (valor is int) return valor;
  if (valor is num) return valor.round();
  if (valor is String) return int.tryParse(valor.trim()) ?? porDefecto;
  return porDefecto;
}

/// Texto no nulo.
String comoTexto(Object? valor, [String porDefecto = '']) {
  if (valor == null) return porDefecto;
  final texto = valor.toString();
  return texto.isEmpty ? porDefecto : texto;
}

/// Booleano tolerante (true, "true" o 1).
bool comoBool(Object? valor) => valor == true || valor == 'true' || valor == 1;

/// Recorre los hijos de un nodo, que puede llegar como mapa o como lista.
Iterable<MapEntry<String, Object?>> hijosDe(Object? valor) sync* {
  if (valor is Map) {
    for (final entrada in valor.entries) {
      if (entrada.value != null) yield MapEntry(entrada.key.toString(), entrada.value);
    }
  } else if (valor is List) {
    for (var i = 0; i < valor.length; i++) {
      if (valor[i] != null) yield MapEntry('$i', valor[i]);
    }
  }
}

const Map<String, String> _sinAcentos = {
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', //
};

/// Minúsculas y sin acentos, para búsquedas ("Neumáticos" coincide con "neumaticos").
String normalizar(String texto) {
  final minusculas = texto.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final caracter in minusculas.split('')) {
    buffer.write(_sinAcentos[caracter] ?? caracter);
  }
  return buffer.toString();
}
