/// Modelos del inventario de componentes (capa Modelo del patrón MVVM).
///
/// Define las categorías, el componente ([ComponenteInventario], nodo
/// `inventario/{categoria}/{id}`), el cálculo puro de los ajustes de stock que
/// `InventarioController` ejecuta dentro de una transacción, los movimientos de
/// stock (nodo `inventario_movimientos/{componente}/{id}`) y los filtros de la
/// vista de inventario.
library;

import 'package:ucsa_prime/models/json.dart';
import 'package:ucsa_prime/utils/fechas.dart';

/// Categorías del inventario. La clave es el nombre del nodo en Firebase
/// (`inventario/{categoria}/{id}`, apartado IV.6.2.1) y el valor, la etiqueta visible.
const Map<String, String> categoriasInventario = {
  'motores': 'Motores',
  'sensores': 'Sensores',
  'estructurales': 'Estructurales',
  'neumaticos': 'Neumáticos',
  'electronica': 'Electrónica',
  'otros': 'Otros',
};

/// Etiqueta legible de una categoría (también para claves cargadas a mano en la consola).
String etiquetaCategoria(String clave) =>
    categoriasInventario[clave] ?? (clave.isEmpty ? 'Sin categoría' : capitalizar(clave));

/// Componente del inventario del equipo (capa Modelo del patrón MVVM).
class ComponenteInventario {
  const ComponenteInventario({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.cantidadDisponible,
    required this.cantidadMinima,
    required this.ubicacion,
    required this.ultimaActualizacion,
    this.actualizadoPor,
  });

  final String id;
  final String nombre;

  /// Clave de la categoría (ver [categoriasInventario]).
  final String categoria;

  /// Unidades disponibles. Después del alta solo cambia por transacción.
  final int cantidadDisponible;

  /// Mínimo que dispara la alerta de stock bajo.
  final int cantidadMinima;
  final String ubicacion;
  final DateTime ultimaActualizacion;

  /// Integrante que hizo el último cambio (trazabilidad).
  final String? actualizadoPor;

  /// Alerta de stock bajo: la cantidad llegó al mínimo definido (punto de reposición).
  bool get stockBajo => cantidadDisponible <= cantidadMinima;
  bool get agotado => cantidadDisponible <= 0;

  /// Serialización a JSON para Firebase.
  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'categoria': categoria,
        'cantidadDisponible': cantidadDisponible,
        'cantidadMinima': cantidadMinima,
        'ubicacion': ubicacion,
        'ultimaActualizacion': fechaIso(ultimaActualizacion),
        if (actualizadoPor != null) 'actualizadoPor': actualizadoPor,
      };

  /// Deserialización desde JSON (tolerante a datos incompletos).
  factory ComponenteInventario.fromJson(Map<String, dynamic> json) {
    return ComponenteInventario(
      id: comoTexto(json['id']),
      nombre: comoTexto(json['nombre'], 'Sin nombre'),
      categoria: comoTexto(json['categoria'], 'otros'),
      cantidadDisponible: comoEntero(json['cantidadDisponible']),
      cantidadMinima: comoEntero(json['cantidadMinima']),
      ubicacion: comoTexto(json['ubicacion']),
      ultimaActualizacion:
          leerFecha(json['ultimaActualizacion']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      actualizadoPor: json['actualizadoPor']?.toString(),
    );
  }

  /// Copia con los campos indicados (el id no cambia).
  ComponenteInventario copyWith({
    String? nombre,
    String? categoria,
    int? cantidadDisponible,
    int? cantidadMinima,
    String? ubicacion,
    DateTime? ultimaActualizacion,
    String? actualizadoPor,
  }) {
    return ComponenteInventario(
      id: id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      cantidadDisponible: cantidadDisponible ?? this.cantidadDisponible,
      cantidadMinima: cantidadMinima ?? this.cantidadMinima,
      ubicacion: ubicacion ?? this.ubicacion,
      ultimaActualizacion: ultimaActualizacion ?? this.ultimaActualizacion,
      actualizadoPor: actualizadoPor ?? this.actualizadoPor,
    );
  }

  /// Convierte el nodo `inventario` (`{categoria: {id: datos}}`) en una lista ordenada
  /// por nombre. La categoría y el id se toman de las claves de los nodos.
  static List<ComponenteInventario> listaDesdeNodo(Object? valor) {
    final lista = <ComponenteInventario>[];
    for (final categoria in hijosDe(valor)) {
      for (final item in hijosDe(categoria.value)) {
        if (item.value is! Map) continue;
        lista.add(ComponenteInventario.fromJson({
          ...comoMapa(item.value),
          'id': item.key,
          'categoria': categoria.key,
        }));
      }
    }
    lista.sort(compararPorNombre);
    return lista;
  }

  /// Orden alfabético por nombre, sin distinguir mayúsculas ni acentos.
  static int compararPorNombre(ComponenteInventario a, ComponenteInventario b) =>
      normalizar(a.nombre).compareTo(normalizar(b.nombre));

  /// Paso de lectura-comparación-escritura de un ajuste de stock. Es una función
  /// pura: `InventarioController` la ejecuta dentro de `DatabaseReference.runTransaction`,
  /// que puede invocarla varias veces si otro dispositivo modificó el dato.
  static ResultadoAjuste calcularAjuste(
    Object? actual, {
    required int delta,
    required DateTime fecha,
    required String usuario,
  }) {
    if (actual is! Map) return const AjusteSinDatos();
    final datos = comoMapa(actual);
    final anterior = comoEntero(datos['cantidadDisponible']);
    final nueva = anterior + delta;
    if (nueva < 0) return AjusteInsuficiente(anterior);
    return AjusteAplicado(
      <String, Object?>{
        ...datos,
        'cantidadDisponible': nueva,
        'ultimaActualizacion': fechaIso(fecha),
        'actualizadoPor': usuario,
      },
      cantidadAnterior: anterior,
      cantidadNueva: nueva,
    );
  }
}

/// Resultado del paso de comparación de una transacción de stock.
sealed class ResultadoAjuste {
  const ResultadoAjuste();
}

/// La cantidad resultante es válida: se escribe [datos].
final class AjusteAplicado extends ResultadoAjuste {
  const AjusteAplicado(this.datos, {required this.cantidadAnterior, required this.cantidadNueva});
  final Map<String, Object?> datos;
  final int cantidadAnterior;
  final int cantidadNueva;
}

/// El ajuste dejaría el stock en negativo: la transacción se aborta.
final class AjusteInsuficiente extends ResultadoAjuste {
  const AjusteInsuficiente(this.disponible);
  final int disponible;
}

/// No hay datos válidos en la ubicación (componente eliminado o corrupto).
final class AjusteSinDatos extends ResultadoAjuste {
  const AjusteSinDatos();
}

/// Movimiento de stock registrado para la trazabilidad (fecha y responsable).
class MovimientoInventario {
  const MovimientoInventario({
    required this.id,
    required this.componenteId,
    required this.componente,
    required this.delta,
    required this.cantidadResultante,
    required this.usuario,
    required this.fecha,
    this.motivo = '',
  });

  final String id;
  final String componenteId;

  /// Nombre del componente en el momento del movimiento.
  final String componente;

  /// Variación de stock: positiva para ingresos, negativa para retiros.
  final int delta;

  /// Stock que quedó después del movimiento.
  final int cantidadResultante;
  final String usuario;
  final DateTime fecha;
  final String motivo;

  /// Serialización para Firebase (el id es la clave del nodo).
  Map<String, dynamic> toJson() => {
        'componenteId': componenteId,
        'componente': componente,
        'delta': delta,
        'cantidadResultante': cantidadResultante,
        'usuario': usuario,
        'fecha': fechaIso(fecha),
        if (motivo.isNotEmpty) 'motivo': motivo,
      };

  /// Deserialización tolerante a datos incompletos.
  factory MovimientoInventario.fromJson(String id, Map<String, dynamic> json) {
    return MovimientoInventario(
      id: id,
      componenteId: comoTexto(json['componenteId']),
      componente: comoTexto(json['componente']),
      delta: comoEntero(json['delta']),
      cantidadResultante: comoEntero(json['cantidadResultante']),
      usuario: comoTexto(json['usuario'], 'Desconocido'),
      fecha: leerFecha(json['fecha']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      motivo: comoTexto(json['motivo']),
    );
  }

  /// Lista ordenada del más reciente al más antiguo.
  static List<MovimientoInventario> listaDesdeNodo(Object? valor) {
    final lista = [
      for (final hijo in hijosDe(valor))
        if (hijo.value is Map) MovimientoInventario.fromJson(hijo.key, comoMapa(hijo.value)),
    ];
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }
}

/// Criterios de búsqueda y filtrado de la vista de inventario.
class FiltroInventario {
  const FiltroInventario({this.texto = '', this.categoria, this.soloStockBajo = false});

  final String texto;
  final String? categoria;
  final bool soloStockBajo;

  /// Hay al menos un criterio aplicado.
  bool get activo => texto.trim().isNotEmpty || categoria != null || soloStockBajo;

  /// Copia con otro texto de búsqueda.
  FiltroInventario conTexto(String valor) =>
      FiltroInventario(texto: valor, categoria: categoria, soloStockBajo: soloStockBajo);

  /// Copia con otra categoría (`null` = todas).
  FiltroInventario conCategoria(String? valor) =>
      FiltroInventario(texto: texto, categoria: valor, soloStockBajo: soloStockBajo);

  /// Copia con el filtro de stock bajo activado o desactivado.
  FiltroInventario conStockBajo(bool valor) =>
      FiltroInventario(texto: texto, categoria: categoria, soloStockBajo: valor);

  /// El componente cumple todos los criterios; el texto se busca en el nombre,
  /// la ubicación y la etiqueta de la categoría, sin distinguir acentos.
  bool coincide(ComponenteInventario c) {
    if (soloStockBajo && !c.stockBajo) return false;
    if (categoria != null && c.categoria != categoria) return false;
    final consulta = normalizar(texto);
    if (consulta.isEmpty) return true;
    return normalizar(c.nombre).contains(consulta) ||
        normalizar(c.ubicacion).contains(consulta) ||
        normalizar(etiquetaCategoria(c.categoria)).contains(consulta);
  }
}
