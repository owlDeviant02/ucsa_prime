/// Hojas inferiores del inventario (vistas del patrón MVVM).
///
/// * Detalle de un componente: stock en vivo, ajuste por cantidad con motivo
///   (cada ajuste es una transacción de Firebase), edición, eliminación con
///   opción de deshacer e historial de movimientos
///   (`inventario_movimientos/`).
/// * Formulario de alta y edición: nombre, categoría, cantidades y ubicación.
///   En la edición, la cantidad no se escribe directamente: solo cambia por
///   transacción, para no pisar los ajustes de otros integrantes.
///
/// Ambas hojas reciben el `InventarioController` de la pantalla que las abre.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ucsa_prime/controllers/inventario_controller.dart';
import 'package:ucsa_prime/models/componente_inventario.dart';
import 'package:ucsa_prime/services/avisos.dart';
import 'package:ucsa_prime/services/firebase_service.dart';
import 'package:ucsa_prime/ui/componentes.dart';
import 'package:ucsa_prime/ui/modulos.dart';
import 'package:ucsa_prime/ui/tema.dart';
import 'package:ucsa_prime/utils/fechas.dart';
import 'package:ucsa_prime/views/inventario/inventario_page.dart';

// -----------------------------------------------------------------------------
// Detalle del componente (stock en vivo, ajuste por cantidad e historial)
// -----------------------------------------------------------------------------

/// Abre la hoja de detalle del componente [componenteId].
Future<void> mostrarDetalleComponente(BuildContext context, InventarioController vm, String componenteId) {
  return mostrarHoja<void>(context, builder: (_) => _DetalleComponente(vm: vm, componenteId: componenteId));
}

class _DetalleComponente extends StatefulWidget {
  const _DetalleComponente({required this.vm, required this.componenteId});

  final InventarioController vm;
  final String componenteId;

  @override
  State<_DetalleComponente> createState() => _DetalleComponenteState();
}

class _DetalleComponenteState extends State<_DetalleComponente> {
  late final Stream<List<MovimientoInventario>> _movimientos =
      widget.vm.obtenerMovimientosStream(widget.componenteId);
  final TextEditingController _cantidad = TextEditingController(text: '1');
  final TextEditingController _motivo = TextEditingController();

  @override
  void dispose() {
    _cantidad.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _ajustar(ComponenteInventario componente, int signo) async {
    final unidades = int.tryParse(_cantidad.text.trim()) ?? 0;
    if (unidades <= 0 || unidades > 9999) {
      mostrarAviso('Ingresá una cantidad entre 1 y 9999.', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    final motivo = _motivo.text.trim();
    _motivo.clear();
    try {
      final resultado = await widget.vm.actualizarCantidad(componente, signo * unidades, motivo: motivo);
      switch (resultado) {
        case ResultadoStock.aplicado:
          mostrarAviso(signo > 0 ? 'Ingresaron $unidades u.' : 'Se retiraron $unidades u.');
        case ResultadoStock.insuficiente:
          mostrarAviso('Stock insuficiente: no se pueden retirar $unidades u.', error: true);
        case ResultadoStock.noExiste:
          mostrarAviso('El componente ya no existe.', error: true);
        case ResultadoStock.sinCambios:
          break;
      }
    } catch (e) {
      mostrarAviso('No se pudo ajustar el stock: $e', error: true);
    }
  }

  Future<void> _eliminar(ComponenteInventario componente) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar componente',
      mensaje: '¿Eliminar "${componente.nombre}" del inventario? Podrás deshacerlo durante unos segundos.',
    );
    if (!ok || !mounted) return;
    Navigator.of(context).pop();
    sincronizarEnSegundoPlano(widget.vm.eliminar(componente), accion: 'No se pudo eliminar');
    mostrarAviso(
      '"${componente.nombre}" eliminado',
      accion: SnackBarAction(
        label: 'DESHACER',
        onPressed: () => sincronizarEnSegundoPlano(widget.vm.restaurar(componente), accion: 'No se pudo restaurar'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return VistaReactiva<InventarioEstado>(
      viewModel: widget.vm,
      builder: (context, estado) {
        final componente = estado.buscarPorId(widget.componenteId);
        if (componente == null) {
          return const SizedBox(
            height: 220,
            child: EstadoMensaje(
              icono: Icons.inventory_2_outlined,
              titulo: 'Componente no disponible',
              mensaje: 'Fue eliminado o movido por otro integrante.',
            ),
          );
        }
        final colorEstado = componente.agotado
            ? ColoresUcsa.peligro
            : componente.stockBajo
                ? ColoresUcsa.alerta
                : ColoresUcsa.exito;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: rellenoHoja(context),
            children: [
              Row(
                children: [
                  Icon(iconoCategoria(componente.categoria), color: Modulos.inventario.colorTexto),
                  const SizedBox(width: Espacio.xs),
                  Text(etiquetaCategoria(componente.categoria),
                      style: tema.textTheme.labelLarge?.copyWith(color: Modulos.inventario.colorTexto)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: () => mostrarFormularioComponente(context, widget.vm, existente: componente),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: () => _eliminar(componente),
                    icon: const Icon(Icons.delete_outline_rounded, color: ColoresUcsa.peligro),
                  ),
                ],
              ),
              Text(componente.nombre, style: tema.textTheme.headlineSmall),
              const SizedBox(height: Espacio.xxs),
              Text(
                [
                  if (componente.ubicacion.isNotEmpty) 'Ubicación: ${componente.ubicacion}',
                  if (componente.ultimaActualizacion.millisecondsSinceEpoch > 0)
                    'Actualizado ${haceCuanto(componente.ultimaActualizacion)}'
                        '${componente.actualizadoPor != null ? ' por ${componente.actualizadoPor}' : ''}',
                ].join('\n'),
                style: tema.textTheme.bodyMedium?.copyWith(color: ColoresUcsa.textoSuave),
              ),
              const SizedBox(height: Espacio.m),
              Card(
                child: Padding(
                  padding: Espacio.tarjeta,
                  child: Column(
                    children: [
                      SelectorStock(componente: componente, vm: widget.vm, grande: true),
                      const SizedBox(height: Espacio.s),
                      Etiqueta(
                        componente.agotado
                            ? 'Agotado'
                            : componente.stockBajo
                                ? 'Stock bajo (mínimo ${componente.cantidadMinima})'
                                : 'Stock suficiente (mínimo ${componente.cantidadMinima})',
                        color: colorEstado,
                        icono: componente.stockBajo ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              const EncabezadoSeccion('Ajustar por cantidad'),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _cantidad,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      decoration: const InputDecoration(labelText: 'Unidades'),
                    ),
                  ),
                  const SizedBox(width: Espacio.s),
                  Expanded(
                    child: TextField(
                      controller: _motivo,
                      maxLength: 60,
                      decoration: const InputDecoration(labelText: 'Motivo (opcional)', counterText: ''),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Espacio.s),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: componente.agotado ? null : () => _ajustar(componente, -1),
                      icon: const Icon(Icons.outbox_rounded),
                      label: const Text('Retirar'),
                    ),
                  ),
                  const SizedBox(width: Espacio.s),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _ajustar(componente, 1),
                      icon: const Icon(Icons.move_to_inbox_rounded),
                      label: const Text('Ingresar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Espacio.xs),
              Text(
                'Cada ajuste se aplica con una transacción de Firebase: si dos integrantes cambian '
                'el stock a la vez, ninguna actualización se pierde.',
                style: tema.textTheme.bodySmall?.copyWith(color: ColoresUcsa.textoSuave),
              ),
              const EncabezadoSeccion('Historial de movimientos'),
              StreamBuilder<List<MovimientoInventario>>(
                stream: _movimientos,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('No se pudo cargar el historial: ${describirErrorFirebase(snapshot.error!)}');
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(Espacio.m),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final movimientos = snapshot.data!;
                  if (movimientos.isEmpty) {
                    return Text('Sin movimientos registrados todavía.',
                        style: tema.textTheme.bodyMedium?.copyWith(color: ColoresUcsa.textoSuave));
                  }
                  return Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < movimientos.length; i++) ...[
                          if (i > 0) const Divider(indent: Espacio.m, endIndent: Espacio.m),
                          _FilaMovimiento(movimiento: movimientos[i]),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Un movimiento del historial: cambio, quién lo hizo, cuándo y por qué.
class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({required this.movimiento});

  final MovimientoInventario movimiento;

  @override
  Widget build(BuildContext context) {
    final positivo = movimiento.delta > 0;
    final color = positivo ? ColoresUcsa.exito : ColoresUcsa.peligro;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: tonoSuave(color),
        child: Text(
          '${positivo ? '+' : ''}${movimiento.delta}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
        ),
      ),
      title: Text('${movimiento.usuario} · quedan ${movimiento.cantidadResultante}'),
      subtitle: Text([
        formatearFechaHora(movimiento.fecha),
        if (movimiento.motivo.isNotEmpty) movimiento.motivo,
      ].join(' · ')),
    );
  }
}

// -----------------------------------------------------------------------------
// Formulario de alta / edición
// -----------------------------------------------------------------------------

/// Abre el formulario de alta (o de edición, si se pasa [existente]).
Future<void> mostrarFormularioComponente(
  BuildContext context,
  InventarioController vm, {
  ComponenteInventario? existente,
}) {
  return mostrarHoja<void>(context, builder: (_) => _FormularioComponente(vm: vm, existente: existente));
}

class _FormularioComponente extends StatefulWidget {
  const _FormularioComponente({required this.vm, this.existente});

  final InventarioController vm;
  final ComponenteInventario? existente;

  @override
  State<_FormularioComponente> createState() => _FormularioComponenteState();
}

class _FormularioComponenteState extends State<_FormularioComponente> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _nombre = TextEditingController(text: widget.existente?.nombre);
  late final TextEditingController _cantidad =
      TextEditingController(text: '${widget.existente?.cantidadDisponible ?? 0}');
  late final TextEditingController _minimo =
      TextEditingController(text: '${widget.existente?.cantidadMinima ?? 1}');
  late final TextEditingController _ubicacion = TextEditingController(text: widget.existente?.ubicacion);
  late String _categoria = widget.existente?.categoria ?? 'motores';

  bool get _editando => widget.existente != null;

  @override
  void dispose() {
    _nombre.dispose();
    _cantidad.dispose();
    _minimo.dispose();
    _ubicacion.dispose();
    super.dispose();
  }

  String? _validarEntero(String? valor, {required String campo}) {
    final numero = int.tryParse(valor?.trim() ?? '');
    if (numero == null) return 'Ingresá un número';
    if (numero < 0 || numero > 9999) return '$campo debe estar entre 0 y 9999';
    return null;
  }

  void _guardar() {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    final existente = widget.existente;
    final componente = ComponenteInventario(
      id: existente?.id ?? widget.vm.nuevoId(),
      nombre: _nombre.text.trim(),
      categoria: _categoria,
      // En la edición se conserva la cantidad vigente: solo cambia por transacción.
      cantidadDisponible: existente?.cantidadDisponible ?? int.parse(_cantidad.text.trim()),
      cantidadMinima: int.parse(_minimo.text.trim()),
      ubicacion: _ubicacion.text.trim(),
      ultimaActualizacion: DateTime.now(),
    );
    sincronizarEnSegundoPlano(
      widget.vm.guardar(componente, original: existente),
      accion: 'No se pudo guardar "${componente.nombre}"',
    );
    Navigator.of(context).pop();
    mostrarAviso(_editando ? 'Cambios guardados' : '"${componente.nombre}" agregado al inventario');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final categorias = {
      ...categoriasInventario.keys,
      if (!categoriasInventario.containsKey(_categoria)) _categoria,
    };
    return CuerpoHoja(
      child: Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoHoja(_editando ? 'Editar componente' : 'Nuevo componente'),
            TextFormField(
              controller: _nombre,
              autofocus: !_editando,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej.: Motor V5 11 W'),
              validator: (valor) {
                final texto = valor?.trim() ?? '';
                if (texto.isEmpty) return 'El nombre es obligatorio';
                if (texto.length < 2) return 'Nombre demasiado corto';
                return null;
              },
            ),
            const SizedBox(height: Espacio.xs),
            Text('Categoría', style: tema.textTheme.labelLarge),
            const SizedBox(height: Espacio.xs),
            Wrap(
              spacing: Espacio.xs,
              runSpacing: Espacio.xs,
              children: [
                for (final categoria in categorias)
                  ChoiceChip(
                    avatar: Icon(iconoCategoria(categoria)),
                    label: Text(etiquetaCategoria(categoria)),
                    selected: _categoria == categoria,
                    onSelected: (_) => setState(() => _categoria = categoria),
                  ),
              ],
            ),
            const SizedBox(height: Espacio.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cantidad,
                    enabled: !_editando,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _editando ? 'Stock actual' : 'Cantidad inicial',
                      helperText: _editando ? 'Se ajusta con − / +' : null,
                    ),
                    validator: _editando ? null : (v) => _validarEntero(v, campo: 'La cantidad'),
                  ),
                ),
                const SizedBox(width: Espacio.s),
                Expanded(
                  child: TextFormField(
                    controller: _minimo,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Stock mínimo', helperText: 'Alerta de reposición'),
                    validator: (v) => _validarEntero(v, campo: 'El mínimo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.s),
            TextFormField(
              controller: _ubicacion,
              maxLength: 40,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Ubicación (opcional)', hintText: 'Ej.: Caja A-3'),
            ),
            const SizedBox(height: Espacio.xs),
            FilledButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save_rounded),
              label: Text(_editando ? 'Guardar cambios' : 'Agregar al inventario'),
            ),
          ],
        ),
      ),
    );
  }
}
