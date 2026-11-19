/// Inventario de componentes (vista del patrón MVVM).
///
/// Observa a `InventarioController`, que escucha `inventario/{categoria}/{id}`
/// en Firebase y entrega las filas ya agrupadas por categoría, con búsqueda,
/// filtro por categoría y filtro de stock bajo. Cada tarjeta tiene botones
/// − / + que ajustan el stock con una transacción (`runTransaction`), de modo
/// que dos integrantes pueden cambiarlo a la vez sin perder actualizaciones.
/// El detalle y el formulario de alta/edición están en `componente_hojas.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ucsa_prime/controllers/inventario_controller.dart';
import 'package:ucsa_prime/models/componente_inventario.dart';
import 'package:ucsa_prime/ui/componentes.dart';
import 'package:ucsa_prime/ui/modulos.dart';
import 'package:ucsa_prime/ui/tema.dart';
import 'package:ucsa_prime/utils/fechas.dart';
import 'package:ucsa_prime/views/inventario/componente_hojas.dart';

/// Inventario en tiempo real, agrupado por categoría.
class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key, this.soloStockBajo = false});

  final bool soloStockBajo;

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  final InventarioController _vm = InventarioController();
  final TextEditingController _busqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.iniciar(soloStockBajo: widget.soloStockBajo);
  }

  @override
  void dispose() {
    _vm.dispose();
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          VistaReactiva<InventarioEstado>(
            viewModel: _vm,
            builder: (context, estado) => IconButton(
              tooltip: estado.filtro.soloStockBajo ? 'Mostrar todo' : 'Solo stock bajo',
              isSelected: estado.filtro.soloStockBajo,
              onPressed: _vm.alternarStockBajo,
              icon: Badge(
                isLabelVisible: estado.totalStockBajo > 0,
                label: Text('${estado.totalStockBajo}'),
                child: const Icon(Icons.warning_amber_rounded),
              ),
              selectedIcon: const Icon(Icons.warning_rounded, color: ColoresUcsa.peligro),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-inventario',
        onPressed: () => mostrarFormularioComponente(context, _vm),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
      ),
      body: Column(
        children: [
          // El buscador queda fuera del StreamBuilder: no se reconstruye con los datos.
          CampoBusqueda(
            controlador: _busqueda,
            alCambiar: _vm.buscar,
            pista: 'Buscar por nombre, categoría o ubicación',
          ),
          Expanded(
            child: VistaReactiva<InventarioEstado>(
              viewModel: _vm,
              builder: (context, estado) => Column(
                children: [
                  _FiltroCategorias(estado: estado, vm: _vm),
                  Expanded(child: _contenido(context, estado)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido(BuildContext context, InventarioEstado estado) {
    if (estado.error != null && estado.todos.isEmpty) {
      return EstadoMensaje.error(mensaje: estado.error!);
    }
    if (estado.cargando) {
      return EstadoCargando(
        mensaje: 'Sincronizando inventario…',
        detalle: estado.sinRespuesta
            ? 'Firebase no responde. Si no hay conexión, se mostrarán los datos guardados en el '
                'teléfono en cuanto estén disponibles.'
            : null,
      );
    }
    if (estado.todos.isEmpty) {
      return EstadoMensaje(
        icono: Icons.inventory_2_outlined,
        titulo: 'Inventario vacío',
        mensaje: 'Agregá el primer componente con el botón "Agregar" o cargá los datos de '
            'demostración desde el menú del inicio.',
        color: Modulos.inventario.colorTexto,
      );
    }
    if (estado.filas.isEmpty) {
      return EstadoMensaje(
        icono: Icons.search_off_rounded,
        titulo: 'Sin resultados',
        mensaje: 'Ningún componente coincide con los filtros aplicados.',
        accion: OutlinedButton.icon(
          onPressed: () {
            _busqueda.clear();
            _vm.limpiarFiltros();
          },
          icon: const Icon(Icons.filter_alt_off_rounded),
          label: const Text('Quitar filtros'),
        ),
      );
    }
    return ListView.builder(
      padding: rellenoLista(context),
      itemCount: estado.filas.length,
      itemBuilder: (context, indice) => switch (estado.filas[indice]) {
        FilaCategoria(:final categoria, :final cantidad) => _EncabezadoCategoria(categoria: categoria, cantidad: cantidad),
        FilaComponente(:final componente) => _TarjetaComponente(
            key: ValueKey(componente.id),
            componente: componente,
            vm: _vm,
          ),
      },
    );
  }
}

/// Chips de filtro: stock bajo (si está activo), todas y una por categoría.
class _FiltroCategorias extends StatelessWidget {
  const _FiltroCategorias({required this.estado, required this.vm});

  final InventarioEstado estado;
  final InventarioController vm;

  @override
  Widget build(BuildContext context) {
    final categorias = [
      ...categoriasInventario.keys.where(estado.conteoPorCategoria.containsKey),
      ...estado.conteoPorCategoria.keys.where((k) => !categoriasInventario.containsKey(k)),
    ];
    if (categorias.isEmpty && !estado.filtro.soloStockBajo) return const SizedBox.shrink();
    return FilaDeChips(
      chips: [
        if (estado.filtro.soloStockBajo)
          InputChip(
            label: const Text('Stock bajo'),
            avatar: const Icon(Icons.warning_amber_rounded, color: ColoresUcsa.peligro),
            onDeleted: vm.alternarStockBajo,
            deleteButtonTooltipMessage: 'Quitar filtro',
          ),
        ChoiceChip(
          label: Text('Todas (${estado.todos.length})'),
          selected: estado.filtro.categoria == null,
          onSelected: (_) => vm.filtrarCategoria(null),
        ),
        for (final categoria in categorias)
          ChoiceChip(
            avatar: Icon(iconoCategoria(categoria)),
            label: Text('${etiquetaCategoria(categoria)} (${estado.conteoPorCategoria[categoria]})'),
            selected: estado.filtro.categoria == categoria,
            onSelected: (seleccionado) => vm.filtrarCategoria(seleccionado ? categoria : null),
          ),
      ],
    );
  }
}

/// Título de cada grupo de la lista (categoría y cantidad de componentes).
class _EncabezadoCategoria extends StatelessWidget {
  const _EncabezadoCategoria({required this.categoria, required this.cantidad});

  final String categoria;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final color = Modulos.inventario.colorTexto;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.xxs, Espacio.m, Espacio.xxs, Espacio.xs),
      child: Row(
        children: [
          Icon(iconoCategoria(categoria), size: 18, color: color),
          const SizedBox(width: Espacio.xs),
          Text(
            etiquetaCategoria(categoria).toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color, letterSpacing: 1),
          ),
          const SizedBox(width: Espacio.xxs),
          Text('· $cantidad', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: ColoresUcsa.textoSuave)),
        ],
      ),
    );
  }
}

/// Tarjeta de un componente: categoría, nombre, ubicación, alerta y stock.
class _TarjetaComponente extends StatelessWidget {
  const _TarjetaComponente({super.key, required this.componente, required this.vm});

  final ComponenteInventario componente;
  final InventarioController vm;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final alerta = componente.stockBajo;
    final colorAlerta = componente.agotado ? ColoresUcsa.peligro : ColoresUcsa.alerta;
    final detalle = [
      if (componente.ubicacion.isNotEmpty) componente.ubicacion,
      if (componente.ultimaActualizacion.millisecondsSinceEpoch > 0) haceCuanto(componente.ultimaActualizacion),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.s),
      child: TarjetaPulsable(
        alPulsar: () => mostrarDetalleComponente(context, vm, componente.id),
        colorBorde: alerta ? tonoSuave(colorAlerta, alfa: 140) : null,
        relleno: const EdgeInsets.all(Espacio.s),
        child: Row(
          children: [
            IconoEnCaja(iconoCategoria(componente.categoria), color: alerta ? colorAlerta : Modulos.inventario.colorTexto),
            const SizedBox(width: Espacio.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(componente.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleSmall),
                  if (detalle.isNotEmpty)
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: ColoresUcsa.textoSuave),
                    ),
                  if (alerta) ...[
                    const SizedBox(height: Espacio.xxs),
                    Etiqueta(
                      componente.agotado ? 'Agotado' : 'Stock bajo · mín. ${componente.cantidadMinima}',
                      color: colorAlerta,
                      icono: Icons.warning_amber_rounded,
                    ),
                  ],
                ],
              ),
            ),
            SelectorStock(componente: componente, vm: vm),
          ],
        ),
      ),
    );
  }
}

/// Botones − / + de stock. Cada pulsación es una transacción de Firebase
/// (`runTransaction`); la cifra se actualiza al instante por `applyLocally`.
class SelectorStock extends StatelessWidget {
  const SelectorStock({super.key, required this.componente, required this.vm, this.grande = false});

  final ComponenteInventario componente;
  final InventarioController vm;
  final bool grande;

  Future<void> _ajustar(int delta) async {
    HapticFeedback.selectionClick();
    try {
      final resultado = await vm.actualizarCantidad(componente, delta);
      switch (resultado) {
        case ResultadoStock.insuficiente:
          mostrarAviso('No hay stock suficiente de "${componente.nombre}".', error: true);
        case ResultadoStock.noExiste:
          mostrarAviso('"${componente.nombre}" ya no existe en el inventario.', error: true);
        case ResultadoStock.aplicado:
        case ResultadoStock.sinCambios:
          break;
      }
    } catch (e) {
      mostrarAviso('No se pudo actualizar el stock: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = componente.agotado
        ? ColoresUcsa.peligro
        : componente.stockBajo
            ? ColoresUcsa.alerta
            : ColoresUcsa.texto;
    final tamanoBoton = grande ? 48.0 : 34.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Restar una unidad',
          constraints: BoxConstraints.tightFor(width: tamanoBoton, height: tamanoBoton),
          padding: EdgeInsets.zero,
          iconSize: grande ? 26 : 20,
          onPressed: componente.cantidadDisponible > 0 ? () => _ajustar(-1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: grande ? 72 : 38,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animacion) => ScaleTransition(scale: animacion, child: child),
            child: Text(
              '${componente.cantidadDisponible}',
              key: ValueKey(componente.cantidadDisponible),
              textAlign: TextAlign.center,
              style: (grande ? tema.textTheme.displaySmall : tema.textTheme.titleLarge)?.copyWith(color: color),
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Sumar una unidad',
          constraints: BoxConstraints.tightFor(width: tamanoBoton, height: tamanoBoton),
          padding: EdgeInsets.zero,
          iconSize: grande ? 26 : 20,
          onPressed: () => _ajustar(1),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
