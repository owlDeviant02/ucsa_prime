/// Tablero de tareas del equipo (vista del patrón MVVM).
///
/// Observa a `TareasController`, que escucha el nodo `tareas/` de Firebase y
/// entrega las tres columnas (pendientes, en progreso y completadas) ya
/// filtradas y ordenadas por prioridad y vencimiento. Desde cada tarjeta se
/// avanza la tarea a la columna siguiente (con opción de deshacer), se edita o
/// se elimina. El formulario de alta/edición se abre en una hoja inferior.
library;

import 'package:flutter/material.dart';
import 'package:ucsa_prime/controllers/sesion_controller.dart';
import 'package:ucsa_prime/controllers/tareas_controller.dart';
import 'package:ucsa_prime/models/tarea.dart';
import 'package:ucsa_prime/services/avisos.dart';
import 'package:ucsa_prime/ui/componentes.dart';
import 'package:ucsa_prime/ui/modulos.dart';
import 'package:ucsa_prime/ui/tema.dart';
import 'package:ucsa_prime/utils/fechas.dart';

/// Tablero de tareas: pendiente / en progreso / completada.
class TareasPage extends StatefulWidget {
  const TareasPage({super.key});

  @override
  State<TareasPage> createState() => _TareasPageState();
}

class _TareasPageState extends State<TareasPage> {
  final TareasController _vm = TareasController();

  @override
  void initState() {
    super.initState();
    _vm.iniciar();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: EstadoTarea.values.length,
      child: VistaReactiva<TareasEstado>(
        viewModel: _vm,
        builder: (context, estado) => Scaffold(
          appBar: AppBar(
            title: const Text('Tareas'),
            actions: [
              // Con el relleno de las acciones del tema, el chip queda alineado
              // con el margen lateral del contenido.
              Padding(
                padding: const EdgeInsets.only(right: Espacio.s),
                child: FilterChip(
                  avatar: const Icon(Icons.person_rounded),
                  label: const Text('Mías'),
                  selected: estado.soloMias,
                  onSelected: (_) => _vm.alternarSoloMias(),
                ),
              ),
            ],
            bottom: TabBar(
              // Desplazable: las etiquetas con contadores no se cortan en pantallas angostas.
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              // Etiquetas algo más compactas para que las tres columnas entren en
              // un teléfono de ~360 dp; la primera queda en el margen lateral
              // (Espacio.xxs + Espacio.s = Espacio.margen).
              padding: const EdgeInsets.symmetric(horizontal: Espacio.xxs),
              labelPadding: const EdgeInsets.symmetric(horizontal: Espacio.s),
              labelStyle: Theme.of(context).textTheme.labelMedium,
              unselectedLabelStyle: Theme.of(context).textTheme.labelMedium,
              tabs: [
                for (final columna in EstadoTarea.values)
                  Tab(text: '${columna.plural} (${estado.columna(columna).length})'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab-tareas',
            onPressed: () => mostrarFormularioTarea(context, _vm),
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Nueva tarea'),
          ),
          body: _contenido(estado),
        ),
      ),
    );
  }

  Widget _contenido(TareasEstado estado) {
    if (estado.error != null && estado.todas.isEmpty) return EstadoMensaje.error(mensaje: estado.error!);
    if (estado.cargando) return const EstadoCargando(mensaje: 'Sincronizando tareas…');
    return TabBarView(
      children: [
        for (final columna in EstadoTarea.values)
          _ListaTareas(columna: columna, tareas: estado.columna(columna), vm: _vm, soloMias: estado.soloMias),
      ],
    );
  }
}

/// Una columna del tablero (o su estado vacío).
class _ListaTareas extends StatelessWidget {
  const _ListaTareas({required this.columna, required this.tareas, required this.vm, required this.soloMias});

  final EstadoTarea columna;
  final List<Tarea> tareas;
  final TareasController vm;
  final bool soloMias;

  @override
  Widget build(BuildContext context) {
    if (tareas.isEmpty) {
      return EstadoMensaje(
        icono: iconoEstado(columna),
        titulo: switch (columna) {
          EstadoTarea.pendiente => 'Sin tareas pendientes',
          EstadoTarea.enProgreso => 'Nada en progreso',
          EstadoTarea.completada => 'Aún no hay tareas completadas',
        },
        mensaje: soloMias
            ? 'No tenés tareas en esta columna. Desactivá el filtro "Mías" para ver las del equipo.'
            : 'Creá una tarea con el botón "Nueva tarea".',
        color: Modulos.tareas.color,
      );
    }
    final ahora = DateTime.now();
    return ListView.builder(
      padding: rellenoLista(context, arriba: Espacio.s),
      itemCount: tareas.length,
      itemBuilder: (context, i) => _TarjetaTarea(
        key: ValueKey(tareas[i].id),
        tarea: tareas[i],
        vm: vm,
        ahora: ahora,
      ),
    );
  }
}

/// Tarjeta de una tarea: prioridad, título, descripción, vencimiento, responsable y acción para avanzarla.
class _TarjetaTarea extends StatelessWidget {
  const _TarjetaTarea({super.key, required this.tarea, required this.vm, required this.ahora});

  final Tarea tarea;
  final TareasController vm;
  final DateTime ahora;

  /// Sangría del texto bajo el título: ancho del ícono de prioridad y su separación.
  static const double _sangria = _tamanoBandera + Espacio.s;
  static const double _tamanoBandera = 18;

  void _avanzar() {
    final siguiente = tarea.estado.siguiente;
    sincronizarEnSegundoPlano(vm.cambiarEstado(tarea, siguiente), accion: 'No se pudo actualizar la tarea');
    mostrarAviso(
      '"${tarea.titulo}" → ${siguiente.etiqueta}',
      accion: SnackBarAction(
        label: 'DESHACER',
        onPressed: () =>
            sincronizarEnSegundoPlano(vm.cambiarEstado(tarea, tarea.estado), accion: 'No se pudo deshacer'),
      ),
    );
  }

  Future<void> _eliminar(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar tarea',
      mensaje: '¿Eliminar "${tarea.titulo}"? Podrás deshacerlo durante unos segundos.',
    );
    if (!ok) return;
    sincronizarEnSegundoPlano(vm.eliminar(tarea), accion: 'No se pudo eliminar');
    mostrarAviso(
      'Tarea eliminada',
      accion: SnackBarAction(
        label: 'DESHACER',
        onPressed: () => sincronizarEnSegundoPlano(vm.restaurar(tarea), accion: 'No se pudo restaurar'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colorPrio = colorPrioridad(tarea.prioridad);
    final vencida = tarea.estaVencida(ahora);
    final pronto = tarea.venceProntoDesde(ahora);
    final (String textoAccion, IconData iconoAccion) = switch (tarea.estado) {
      EstadoTarea.pendiente => ('Iniciar', Icons.play_arrow_rounded),
      EstadoTarea.enProgreso => ('Completar', Icons.check_rounded),
      EstadoTarea.completada => ('Reabrir', Icons.replay_rounded),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.s),
      child: TarjetaPulsable(
        alPulsar: () => mostrarFormularioTarea(context, vm, existente: tarea),
        alMantener: () => _eliminar(context),
        relleno: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.xs, Espacio.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: Espacio.xxs, right: Espacio.s),
                  child: Icon(Icons.flag_rounded, size: _tamanoBandera, color: colorPrio),
                ),
                Expanded(
                  child: Text(
                    tarea.titulo,
                    style: tema.textTheme.titleSmall?.copyWith(
                      decoration: tarea.completada ? TextDecoration.lineThrough : null,
                      color: tarea.completada ? ColoresUcsa.textoSuave : ColoresUcsa.texto,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones',
                  icon: const Icon(Icons.more_horiz_rounded, size: 20),
                  onSelected: (opcion) {
                    if (opcion == 'editar') mostrarFormularioTarea(context, vm, existente: tarea);
                    if (opcion == 'eliminar') _eliminar(context);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'editar', child: Text('Editar')),
                    PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            if (tarea.descripcion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: _sangria, right: Espacio.xs),
                child: Text(
                  tarea.descripcion,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.bodyMedium?.copyWith(color: ColoresUcsa.textoSuave),
                ),
              ),
            const SizedBox(height: Espacio.xs),
            Padding(
              padding: const EdgeInsets.only(left: _sangria),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: Espacio.xs,
                      runSpacing: Espacio.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Etiqueta(tarea.prioridad.etiqueta, color: colorPrio),
                        if (tarea.fechaVencimiento != null)
                          Etiqueta(
                            tarea.completada
                                ? 'Venció el ${fechaCorta(tarea.fechaVencimiento!)}'
                                : describirVencimiento(tarea.fechaVencimiento!, ahora: ahora),
                            color: vencida
                                ? ColoresUcsa.peligro
                                : pronto
                                    ? ColoresUcsa.alerta
                                    : ColoresUcsa.textoSuave,
                            icono: Icons.event_rounded,
                            relleno: vencida,
                          ),
                        if (tarea.asignadoA.isNotEmpty) AutorConAvatar(tarea.asignadoA),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _avanzar,
                    icon: Icon(iconoAccion, size: 18),
                    label: Text(textoAccion),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Formulario
// -----------------------------------------------------------------------------

/// Abre el formulario de tarea nueva (o de edición, si se pasa [existente]).
Future<void> mostrarFormularioTarea(BuildContext context, TareasController vm, {Tarea? existente}) {
  return mostrarHoja<void>(context, builder: (_) => _FormularioTarea(vm: vm, existente: existente));
}

class _FormularioTarea extends StatefulWidget {
  const _FormularioTarea({required this.vm, this.existente});

  final TareasController vm;
  final Tarea? existente;

  @override
  State<_FormularioTarea> createState() => _FormularioTareaState();
}

class _FormularioTareaState extends State<_FormularioTarea> {
  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _titulo = TextEditingController(text: widget.existente?.titulo);
  late final TextEditingController _descripcion = TextEditingController(text: widget.existente?.descripcion);
  late final TextEditingController _asignado = TextEditingController(
    text: widget.existente?.asignadoA ?? SesionController.instancia.nombreUsuario,
  );
  late PrioridadTarea _prioridad = widget.existente?.prioridad ?? PrioridadTarea.media;
  late EstadoTarea _estado = widget.existente?.estado ?? EstadoTarea.pendiente;
  late DateTime? _vence = widget.existente?.fechaVencimiento;

  bool get _editando => widget.existente != null;

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _asignado.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = soloFecha(DateTime.now());
    final inicial = soloFecha(_vence ?? hoy.add(const Duration(days: 1)));
    var primera = hoy.subtract(const Duration(days: 365));
    var ultima = hoy.add(const Duration(days: 730));
    // Una tarea antigua puede tener una fecha fuera del rango por defecto.
    if (inicial.isBefore(primera)) primera = inicial;
    if (inicial.isAfter(ultima)) ultima = inicial;
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: primera,
      lastDate: ultima,
      helpText: 'Fecha de vencimiento',
    );
    if (elegida != null && mounted) {
      setState(() => _vence = DateTime(elegida.year, elegida.month, elegida.day, 18));
    }
  }

  void _guardar() {
    if (!(_formulario.currentState?.validate() ?? false)) return;
    final existente = widget.existente;
    final base = Tarea(
      id: existente?.id ?? widget.vm.nuevoId(),
      titulo: _titulo.text.trim(),
      descripcion: _descripcion.text.trim(),
      asignadoA: _asignado.text.trim(),
      prioridad: _prioridad,
      estado: existente?.estado ?? EstadoTarea.pendiente,
      fechaCreacion: existente?.fechaCreacion ?? DateTime.now(),
      fechaVencimiento: _vence,
      creadoPor: existente?.creadoPor ?? SesionController.instancia.nombreUsuario,
      fechaCompletada: existente?.fechaCompletada,
    );
    final tarea = base.estado == _estado ? base : base.conEstado(_estado);
    sincronizarEnSegundoPlano(
      widget.vm.guardar(tarea, nueva: existente == null),
      accion: 'No se pudo guardar la tarea',
    );
    Navigator.of(context).pop();
    mostrarAviso(_editando ? 'Tarea actualizada' : 'Tarea creada');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final responsables = widget.vm.estado.responsables;
    return CuerpoHoja(
      child: Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoHoja(_editando ? 'Editar tarea' : 'Nueva tarea'),
            TextFormField(
              controller: _titulo,
              autofocus: !_editando,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Título', hintText: 'Ej.: Calibrar odometría'),
              validator: (valor) {
                final texto = valor?.trim() ?? '';
                if (texto.isEmpty) return 'El título es obligatorio';
                if (texto.length < 3) return 'Usá al menos 3 caracteres';
                return null;
              },
            ),
            TextFormField(
              controller: _descripcion,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
            const SizedBox(height: Espacio.xxs),
            TextFormField(
              controller: _asignado,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Asignada a', prefixIcon: Icon(Icons.person_rounded)),
              validator: (valor) => (valor?.trim().isEmpty ?? true) ? 'Indicá un responsable' : null,
            ),
            if (responsables.isNotEmpty)
              FilaDeChips(
                relleno: EdgeInsets.zero,
                chips: [
                  for (final nombre in responsables)
                    ActionChip(
                      avatar: AvatarIniciales(nombre, radio: 10),
                      label: Text(nombre),
                      onPressed: () => setState(() => _asignado.text = nombre),
                    ),
                ],
              ),
            const SizedBox(height: Espacio.m),
            Text('Prioridad', style: tema.textTheme.labelLarge),
            const SizedBox(height: Espacio.xs),
            SegmentedButton<PrioridadTarea>(
              segments: [
                for (final p in PrioridadTarea.values)
                  ButtonSegment(
                    value: p,
                    label: Text(p.etiqueta),
                    icon: Icon(Icons.flag_rounded, color: colorPrioridad(p)),
                  ),
              ],
              selected: {_prioridad},
              onSelectionChanged: (seleccion) => setState(() => _prioridad = seleccion.first),
            ),
            if (_editando) ...[
              const SizedBox(height: Espacio.m),
              Text('Estado', style: tema.textTheme.labelLarge),
              const SizedBox(height: Espacio.xs),
              SegmentedButton<EstadoTarea>(
                showSelectedIcon: false,
                segments: [
                  for (final e in EstadoTarea.values)
                    ButtonSegment(value: e, label: Text(e.etiqueta), icon: Icon(iconoEstado(e), size: 18)),
                ],
                selected: {_estado},
                onSelectionChanged: (seleccion) => setState(() => _estado = seleccion.first),
              ),
            ],
            const SizedBox(height: Espacio.m),
            Text('Vencimiento', style: tema.textTheme.labelLarge),
            const SizedBox(height: Espacio.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirFecha,
                    icon: const Icon(Icons.event_rounded),
                    label: Text(_vence == null ? 'Sin fecha límite' : fechaLarga(_vence!)),
                  ),
                ),
                if (_vence != null)
                  IconButton(
                    tooltip: 'Quitar fecha',
                    onPressed: () => setState(() => _vence = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: Espacio.l),
            FilledButton.icon(
              onPressed: _guardar,
              icon: const Icon(Icons.save_rounded),
              label: Text(_editando ? 'Guardar cambios' : 'Crear tarea'),
            ),
          ],
        ),
      ),
    );
  }
}
