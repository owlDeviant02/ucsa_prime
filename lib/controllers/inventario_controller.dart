/// ViewModel del módulo de inventario (capa ViewModel del patrón MVVM).
///
/// Lee el nodo `inventario/{categoria}/{id}` de Realtime Database, calcula la
/// lista agrupada por categoría con los filtros de `InventarioPage` y ejecuta
/// las altas, ediciones, bajas y ajustes de stock. Los ajustes se hacen con
/// `runTransaction` y dejan su historial en `inventario_movimientos`, que
/// consultan las hojas de detalle del componente.
library;

import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:ucsa_prime/controllers/sesion_controller.dart';
import 'package:ucsa_prime/controllers/view_model.dart';
import 'package:ucsa_prime/models/actividad.dart';
import 'package:ucsa_prime/models/componente_inventario.dart';
import 'package:ucsa_prime/models/json.dart';
import 'package:ucsa_prime/services/avisos.dart';
import 'package:ucsa_prime/services/firebase_service.dart';

/// Resultado de una transacción de stock.
enum ResultadoStock { aplicado, insuficiente, noExiste, sinCambios }

/// Fila de la lista agrupada por categoría (vista jerárquica).
sealed class FilaInventario {
  const FilaInventario();
}

/// Encabezado de una categoría con la cantidad de componentes visibles en ella.
final class FilaCategoria extends FilaInventario {
  const FilaCategoria(this.categoria, this.cantidad);
  final String categoria;
  final int cantidad;
}

/// Fila de un componente dentro de su categoría.
final class FilaComponente extends FilaInventario {
  const FilaComponente(this.componente);
  final ComponenteInventario componente;
}

/// Estado inmutable de la vista de inventario, con los datos derivados ya calculados.
class InventarioEstado {
  const InventarioEstado({
    this.cargando = true,
    this.sinRespuesta = false,
    this.error,
    this.todos = const [],
    this.filtro = const FiltroInventario(),
    this.filas = const [],
    this.visibles = 0,
    this.conteoPorCategoria = const {},
    this.totalStockBajo = 0,
  });

  final bool cargando;

  /// No llegaron datos tras varios segundos (sin conexión o base desactivada).
  final bool sinRespuesta;
  final String? error;
  final List<ComponenteInventario> todos;
  final FiltroInventario filtro;

  /// Lista agrupada (encabezados de categoría y componentes) que dibuja la vista.
  final List<FilaInventario> filas;

  /// Cantidad de componentes que cumplen el filtro.
  final int visibles;

  /// Total de componentes por categoría, sin aplicar filtros.
  final Map<String, int> conteoPorCategoria;
  final int totalStockBajo;

  /// Versión vigente de un componente, o `null` si ya no existe.
  ComponenteInventario? buscarPorId(String id) {
    for (final c in todos) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// ViewModel del inventario: transforma el nodo `inventario` de Firebase en
/// flujos que consume la interfaz (apartado IV.6.2.2) y ejecuta las operaciones.
class InventarioController extends ViewModel<InventarioEstado> {
  InventarioController() : super(const InventarioEstado());

  late final DatabaseReference _inventarioRef = FirebaseService.ref(Rutas.inventario);
  late final DatabaseReference _raizRef = FirebaseService.ref(Rutas.raiz);
  Timer? _temporizadorRespuesta;

  // ---------------------------------------------------------------------------
  // Flujos de datos (Firebase → modelos)
  // ---------------------------------------------------------------------------

  /// Inventario completo en tiempo real: cada cambio en cualquier dispositivo
  /// emite la lista actualizada.
  Stream<List<ComponenteInventario>> obtenerInventarioStream() => _inventarioRef.onValue
      .map((evento) => ComponenteInventario.listaDesdeNodo(evento.snapshot.value));

  /// Últimos movimientos de stock de un componente (historial con fecha y responsable).
  Stream<List<MovimientoInventario>> obtenerMovimientosStream(String componenteId, {int limite = 15}) {
    return FirebaseService.ref('${Rutas.movimientos}/$componenteId')
        .orderByKey()
        .limitToLast(limite)
        .onValue
        .map((evento) => MovimientoInventario.listaDesdeNodo(evento.snapshot.value));
  }

  // ---------------------------------------------------------------------------
  // Estado de la vista
  // ---------------------------------------------------------------------------

  /// Comienza a escuchar el inventario; con [soloStockBajo] la vista se abre ya
  /// filtrada (acceso desde la alerta del inicio). Si no llegan datos en 12 s,
  /// el estado lo indica con [InventarioEstado.sinRespuesta].
  void iniciar({bool soloStockBajo = false}) {
    if (soloStockBajo) {
      emitir(_calcular(estado.todos, estado.filtro.conStockBajo(true), cargando: true));
    }
    escuchar<List<ComponenteInventario>>(
      obtenerInventarioStream(),
      (lista) {
        _temporizadorRespuesta?.cancel();
        emitir(_calcular(lista, estado.filtro, cargando: false));
      },
      alFallar: (error) {
        _temporizadorRespuesta?.cancel();
        emitir(_calcular(estado.todos, estado.filtro, cargando: false, error: describirErrorFirebase(error)));
      },
    );
    _temporizadorRespuesta = Timer(const Duration(seconds: 12), () {
      if (estado.cargando) {
        emitir(_calcular(estado.todos, estado.filtro, cargando: true, sinRespuesta: true));
      }
    });
  }

  /// Filtra por texto en el nombre, la ubicación o la categoría.
  void buscar(String texto) => emitir(_calcular(estado.todos, estado.filtro.conTexto(texto)));

  /// Filtra por categoría; `null` muestra todas.
  void filtrarCategoria(String? categoria) =>
      emitir(_calcular(estado.todos, estado.filtro.conCategoria(categoria)));

  /// Activa o desactiva el filtro de stock bajo.
  void alternarStockBajo() =>
      emitir(_calcular(estado.todos, estado.filtro.conStockBajo(!estado.filtro.soloStockBajo)));

  /// Quita todos los filtros.
  void limpiarFiltros() => emitir(_calcular(estado.todos, const FiltroInventario()));

  InventarioEstado _calcular(
    List<ComponenteInventario> todos,
    FiltroInventario filtro, {
    bool? cargando,
    bool sinRespuesta = false,
    String? error,
  }) {
    final conteo = <String, int>{};
    var stockBajo = 0;
    for (final c in todos) {
      conteo[c.categoria] = (conteo[c.categoria] ?? 0) + 1;
      if (c.stockBajo) stockBajo++;
    }
    // Agrupa por categoría respetando el orden definido (vista jerárquica).
    final grupos = <String, List<ComponenteInventario>>{};
    for (final c in todos) {
      if (filtro.coincide(c)) (grupos[c.categoria] ??= []).add(c);
    }
    final ordenCategorias = [
      ...categoriasInventario.keys.where(grupos.containsKey),
      ...grupos.keys.where((k) => !categoriasInventario.containsKey(k)),
    ];
    final filas = <FilaInventario>[];
    var visibles = 0;
    for (final categoria in ordenCategorias) {
      final items = grupos[categoria]!;
      filas.add(FilaCategoria(categoria, items.length));
      for (final c in items) {
        filas.add(FilaComponente(c));
      }
      visibles += items.length;
    }
    return InventarioEstado(
      cargando: cargando ?? estado.cargando,
      sinRespuesta: sinRespuesta,
      error: error,
      todos: todos,
      filtro: filtro,
      filas: filas,
      visibles: visibles,
      conteoPorCategoria: conteo,
      totalStockBajo: stockBajo,
    );
  }

  // ---------------------------------------------------------------------------
  // Operaciones
  // ---------------------------------------------------------------------------

  /// Identificador para un componente nuevo (generado localmente con `push()`).
  String nuevoId() => FirebaseService.nuevaClave(Rutas.inventario);

  /// Alta o edición. La cantidad disponible SOLO se fija en el alta: después se
  /// modifica exclusivamente con [actualizarCantidad] (transacción).
  Future<void> guardar(ComponenteInventario componente, {ComponenteInventario? original}) {
    final ahora = DateTime.now();
    final usuario = SesionController.instancia.nombreUsuario;
    final datos = componente.copyWith(ultimaActualizacion: ahora, actualizadoPor: usuario);
    final cambios = <String, Object?>{};
    final ruta = 'inventario/${datos.categoria}/${datos.id}';
    if (original == null) {
      cambios[ruta] = datos.toJson();
      cambios.addAll(entradaActividad(TipoActividad.inventario,
          'Alta de "${datos.nombre}" (${datos.cantidadDisponible} u.)'));
    } else if (original.categoria != datos.categoria) {
      // Cambio de categoría: se mueve el nodo de forma atómica (escritura multiruta).
      cambios['inventario/${original.categoria}/${datos.id}'] = null;
      cambios[ruta] = datos.toJson();
      cambios.addAll(entradaActividad(TipoActividad.inventario,
          '"${datos.nombre}" pasó a ${etiquetaCategoria(datos.categoria)}'));
    } else {
      // Solo metadatos: no se toca cantidadDisponible.
      final json = datos.toJson();
      for (final campo in const ['nombre', 'cantidadMinima', 'ubicacion', 'ultimaActualizacion', 'actualizadoPor']) {
        cambios['$ruta/$campo'] = json[campo];
      }
      cambios.addAll(entradaActividad(TipoActividad.inventario, 'Edición de "${datos.nombre}"'));
    }
    return _raizRef.update(cambios);
  }

  /// Baja del componente y registro de actividad, en una escritura multiruta.
  Future<void> eliminar(ComponenteInventario componente) {
    return _raizRef.update({
      'inventario/${componente.categoria}/${componente.id}': null,
      ...entradaActividad(TipoActividad.inventario, 'Baja de "${componente.nombre}"'),
    });
  }

  /// Deshace una eliminación restaurando el componente tal como estaba.
  Future<void> restaurar(ComponenteInventario componente) =>
      _inventarioRef.child(componente.categoria).child(componente.id).set(componente.toJson());

  /// Modifica el stock con `DatabaseReference.runTransaction` (lectura-comparación-
  /// escritura). El manejador recibe el valor vigente, comprueba que el resultado no
  /// sea negativo y escribe la nueva cantidad; si otro integrante cambió el dato al
  /// mismo tiempo, Firebase rechaza la escritura y vuelve a ejecutar el manejador con
  /// el valor actualizado, por lo que no se pierde ninguna actualización concurrente.
  /// Con `applyLocally` (por defecto) la interfaz refleja el cambio de inmediato.
  Future<ResultadoStock> actualizarCantidad(
    ComponenteInventario componente,
    int delta, {
    String motivo = '',
  }) async {
    if (delta == 0) return ResultadoStock.sinCambios;
    final referencia = _inventarioRef.child(componente.categoria).child(componente.id);
    final usuario = SesionController.instancia.nombreUsuario;
    final fecha = DateTime.now();
    var insuficiente = false;

    final resultado = await referencia.runTransaction((Object? actual) {
      // Sin dato en caché local: se devuelve sin cambios y el servidor vuelve a
      // invocar el manejador con el valor real.
      if (actual == null) return Transaction.success(null);
      final ajuste = ComponenteInventario.calcularAjuste(
        actual,
        delta: delta,
        fecha: fecha,
        usuario: usuario,
      );
      switch (ajuste) {
        case AjusteAplicado():
          insuficiente = false;
          return Transaction.success(ajuste.datos);
        case AjusteInsuficiente():
          insuficiente = true;
          return Transaction.abort();
        case AjusteSinDatos():
          return Transaction.abort();
      }
    });

    if (!resultado.committed) {
      return insuficiente ? ResultadoStock.insuficiente : ResultadoStock.noExiste;
    }
    final valor = resultado.snapshot.value;
    if (valor == null) return ResultadoStock.noExiste;
    _registrarMovimiento(
      componente,
      delta: delta,
      cantidadResultante: comoEntero(comoMapa(valor)['cantidadDisponible']),
      usuario: usuario,
      fecha: fecha,
      motivo: motivo,
    );
    return ResultadoStock.aplicado;
  }

  /// Historial del componente y registro de actividad, en una escritura atómica
  /// que se sincroniza en segundo plano.
  void _registrarMovimiento(
    ComponenteInventario componente, {
    required int delta,
    required int cantidadResultante,
    required String usuario,
    required DateTime fecha,
    required String motivo,
  }) {
    final clave = FirebaseService.nuevaClave('${Rutas.movimientos}/${componente.id}');
    final movimiento = MovimientoInventario(
      id: clave,
      componenteId: componente.id,
      componente: componente.nombre,
      delta: delta,
      cantidadResultante: cantidadResultante,
      usuario: usuario,
      fecha: fecha,
      motivo: motivo,
    );
    final signo = delta > 0 ? '+' : '';
    sincronizarEnSegundoPlano(
      _raizRef.update({
        'inventario_movimientos/${componente.id}/$clave': movimiento.toJson(),
        ...entradaActividad(TipoActividad.inventario,
            'Stock de "${componente.nombre}": $signo$delta (queda $cantidadResultante)'),
      }),
      accion: 'No se pudo registrar el movimiento',
    );
  }

  @override
  void dispose() {
    _temporizadorRespuesta?.cancel();
    super.dispose();
  }
}
