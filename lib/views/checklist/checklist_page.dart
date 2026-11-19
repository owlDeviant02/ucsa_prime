/// Checklist previo al partido (vista del patrón MVVM).
///
/// Observa a `ChecklistController`: el carrusel elige el robot (cada uno con su
/// plantilla de ítems), cada ítem se marca con la hora de verificación y, al
/// registrar, se guarda en Firebase quién lo hizo, cuándo y qué quedó sin
/// verificar. La hoja de historial muestra los registros anteriores. El último
/// checklist de Jordan aparece también en la tarjeta del inicio.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ucsa_prime/controllers/checklist_controller.dart';
import 'package:ucsa_prime/models/checklist.dart';
import 'package:ucsa_prime/services/avisos.dart';
import 'package:ucsa_prime/ui/componentes.dart';
import 'package:ucsa_prime/ui/modulos.dart';
import 'package:ucsa_prime/ui/tema.dart';
import 'package:ucsa_prime/utils/fechas.dart';

/// Checklist pre-partido: selección del robot, verificación ítem por ítem (con
/// hora) y registro en Firebase para conservar el historial.
class ChecklistPage extends StatefulWidget {
  const ChecklistPage({super.key});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  final ChecklistController _vm = ChecklistController();
  final PageController _paginas = PageController(viewportFraction: 0.72);

  static const Color _color = ColoresUcsa.checklist;

  @override
  void initState() {
    super.initState();
    _vm.iniciar();
  }

  @override
  void dispose() {
    _vm.dispose();
    _paginas.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final estado = _vm.estado;
    if (estado.completados == 0) {
      mostrarAviso('Verificá al menos un ítem antes de registrar.', error: true);
      return;
    }
    if (!estado.completo) {
      final faltan = estado.total - estado.completados;
      final ok = await confirmar(
        context,
        titulo: 'Checklist incompleto',
        mensaje: 'Faltan $faltan ítem${faltan == 1 ? '' : 's'} por verificar en ${estado.plantilla.robot}. '
            '¿Registrar de todos modos? Quedará marcado como incompleto.',
        textoConfirmar: 'Registrar',
        destructivo: false,
        icono: Icons.warning_amber_rounded,
      );
      if (!ok) return;
    }
    final robot = estado.plantilla.robot;
    final completo = estado.completo;
    HapticFeedback.mediumImpact();
    sincronizarEnSegundoPlano(_vm.registrar(), accion: 'No se pudo registrar el checklist');
    mostrarAviso(completo ? '$robot listo para competir ✓ Checklist registrado' : 'Checklist de $robot registrado');
  }

  void _verHistorial() {
    mostrarHoja<void>(context, builder: (_) => _HojaHistorial(vm: _vm));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist pre-partido'),
        actions: [
          IconButton(tooltip: 'Historial', onPressed: _verHistorial, icon: const Icon(Icons.history_rounded)),
        ],
      ),
      body: VistaReactiva<ChecklistEstado>(
        viewModel: _vm,
        builder: (context, estado) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _SelectorRobot(estado: estado, vm: _vm, paginas: _paginas)),
            SliverToBoxAdapter(child: _Progreso(estado: estado, vm: _vm)),
            SliverPadding(
              padding: rellenoLista(context, fin: Espacio.l),
              sliver: SliverList.builder(
                itemCount: estado.plantilla.items.length,
                itemBuilder: (context, i) {
                  final item = estado.plantilla.items[i];
                  final hora = estado.marcasActuales[item];
                  return _FilaItem(item: item, hora: hora, alPulsar: () {
                    HapticFeedback.selectionClick();
                    _vm.alternar(item);
                  });
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BarraAccionInferior(
        child: VistaReactiva<ChecklistEstado>(
          viewModel: _vm,
          builder: (context, estado) => FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: estado.completo ? ColoresUcsa.exito : _color),
            onPressed: _registrar,
            icon: Icon(estado.completo ? Icons.verified_rounded : Icons.save_rounded),
            label: Text(estado.completo ? 'Listo para competir · Registrar' : 'Registrar checklist'),
          ),
        ),
      ),
    );
  }
}

/// Carrusel de robots con la imagen, el nombre y el último registro.
class _SelectorRobot extends StatelessWidget {
  const _SelectorRobot({required this.estado, required this.vm, required this.paginas});

  final ChecklistEstado estado;
  final ChecklistController vm;
  final PageController paginas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final plantilla = estado.plantilla;
    final ultimo = estado.ultimoDe(plantilla.robot);
    return SizedBox(
      height: 238,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Image(
                key: ValueKey(plantilla.fondo),
                image: imagenReducida(plantilla.fondo, ancho: 720),
                // El AnimatedSwitcher no impone tamaño: sin esto la imagen
                // quedaba como una franja angosta en el centro.
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.12),
                gaplessPlayback: true,
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: paginas,
                  itemCount: plantillasChecklist.length,
                  onPageChanged: (indice) {
                    HapticFeedback.selectionClick();
                    vm.seleccionarRobot(indice);
                  },
                  itemBuilder: (context, indice) => _ImagenRobot(
                    plantilla: plantillasChecklist[indice],
                    paginas: paginas,
                    indice: indice,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Espacio.margen),
                child: Column(
                  children: [
                    Text(plantilla.robot, style: tema.textTheme.headlineMedium?.copyWith(color: ColoresUcsa.checklist)),
                    Text(
                      ultimo == null
                          ? '${plantilla.descripcion} · sin registros previos'
                          : '${plantilla.descripcion} · último: ${ultimo.completados}/${ultimo.total} ${haceCuanto(ultimo.fecha)}',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: ColoresUcsa.textoSuave),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Espacio.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < plantillasChecklist.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: Espacio.xxs / 2),
                      width: i == estado.indice ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == estado.indice ? ColoresUcsa.checklist : ColoresUcsa.borde,
                        borderRadius: BorderRadius.circular(Radios.chico),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Espacio.xs),
            ],
          ),
        ],
      ),
    );
  }
}

/// Imagen del robot con efecto de escala según su posición en el carrusel. Usa
/// AnimatedBuilder sobre el PageController: solo se repinta la transformación.
class _ImagenRobot extends StatelessWidget {
  const _ImagenRobot({required this.plantilla, required this.paginas, required this.indice});

  final PlantillaChecklist plantilla;
  final PageController paginas;
  final int indice;

  @override
  Widget build(BuildContext context) {
    final imagen = Padding(
      padding: const EdgeInsets.symmetric(vertical: Espacio.s),
      child: Image(
        image: imagenReducida(plantilla.imagen, ancho: 800),
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );
    return AnimatedBuilder(
      animation: paginas,
      child: plantilla.robot == 'Jordan' ? Hero(tag: 'robot-Jordan', child: imagen) : imagen,
      builder: (context, child) {
        var pagina = indice.toDouble();
        if (paginas.hasClients && paginas.position.haveDimensions) {
          pagina = paginas.page ?? pagina;
        }
        final distancia = (pagina - indice).abs().clamp(0.0, 1.0);
        return Transform.scale(scale: 1 - distancia * 0.28, child: Opacity(opacity: 1 - distancia * 0.5, child: child));
      },
    );
  }
}

/// Avance de la verificación, con «Marcar todo» y «Reiniciar».
class _Progreso extends StatelessWidget {
  const _Progreso({required this.estado, required this.vm});

  final ChecklistEstado estado;
  final ChecklistController vm;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = estado.completo ? ColoresUcsa.exito : ColoresUcsa.checklist;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.margen, Espacio.s, Espacio.margen, Espacio.xs),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.xs, Espacio.s),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${estado.completados} de ${estado.total} ',
                            style: tema.textTheme.titleLarge?.copyWith(color: color),
                          ),
                          TextSpan(
                            text: estado.completo ? 'verificados ✓' : 'verificados',
                            style: tema.textTheme.titleSmall?.copyWith(color: ColoresUcsa.textoSuave),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: estado.completo ? null : vm.marcarTodo,
                    child: const Text('Marcar todo'),
                  ),
                  IconButton(
                    tooltip: 'Reiniciar',
                    onPressed: estado.completados == 0 ? null : vm.reiniciar,
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                ],
              ),
              const SizedBox(height: Espacio.xs),
              Padding(
                padding: const EdgeInsets.only(right: Espacio.xs),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: estado.progreso),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (context, valor, _) => LinearProgressIndicator(
                    value: valor,
                    minHeight: 8,
                    color: color,
                    backgroundColor: tonoSuave(color, alfa: 30),
                    borderRadius: BorderRadius.circular(Radios.chico),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un ítem del checklist: se marca o desmarca al tocarlo y muestra la hora.
class _FilaItem extends StatelessWidget {
  const _FilaItem({required this.item, required this.hora, required this.alPulsar});

  final String item;
  final DateTime? hora;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final verificado = hora != null;
    const color = ColoresUcsa.checklist;
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.xs),
      child: Material(
        color: verificado ? tonoSuave(color, alfa: 16) : ColoresUcsa.superficie,
        borderRadius: BorderRadius.circular(Radios.grande),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radios.grande),
          onTap: alPulsar,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radios.grande),
              border: Border.all(color: verificado ? tonoSuave(color, alfa: 90) : ColoresUcsa.borde),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: Espacio.s),
              child: Row(
                children: [
                  Icon(iconoItemChecklist(item), color: verificado ? color : ColoresUcsa.textoSuave),
                  const SizedBox(width: Espacio.s),
                  Expanded(child: Text(item, style: tema.textTheme.titleSmall)),
                  if (verificado)
                    Padding(
                      padding: const EdgeInsets.only(right: Espacio.xs),
                      child: Text(formatearHora(hora!),
                          style: tema.textTheme.labelMedium?.copyWith(color: ColoresUcsa.textoSuave)),
                    ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animacion) => ScaleTransition(scale: animacion, child: child),
                    child: Icon(
                      verificado ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      key: ValueKey(verificado),
                      color: verificado ? color : ColoresUcsa.borde,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja con los checklists registrados (fecha, responsable y resultado).
class _HojaHistorial extends StatelessWidget {
  const _HojaHistorial({required this.vm});

  final ChecklistController vm;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => VistaReactiva<ChecklistEstado>(
        viewModel: vm,
        builder: (context, estado) {
          final Widget contenido;
          if (estado.errorHistorial != null && estado.historial.isEmpty) {
            contenido = EstadoMensaje.error(mensaje: estado.errorHistorial!);
          } else if (estado.cargandoHistorial) {
            contenido = const EstadoCargando(mensaje: 'Cargando historial…');
          } else if (estado.historial.isEmpty) {
            contenido = const EstadoMensaje(
              icono: Icons.history_rounded,
              titulo: 'Sin registros',
              mensaje: 'Los checklists registrados aparecerán aquí con fecha, responsable y resultado.',
            );
          } else {
            return ListView.builder(
              controller: scroll,
              padding: rellenoHoja(context),
              itemCount: estado.historial.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return const EncabezadoHoja('Historial de checklists');
                return _FilaRegistro(registro: estado.historial[i - 1]);
              },
            );
          }
          return ListView(
            controller: scroll,
            padding: rellenoHoja(context),
            children: [
              const EncabezadoHoja('Historial de checklists'),
              SizedBox(height: 320, child: contenido),
            ],
          );
        },
      ),
    );
  }
}

/// Un registro del historial.
class _FilaRegistro extends StatelessWidget {
  const _FilaRegistro({required this.registro});

  final RegistroChecklist registro;

  @override
  Widget build(BuildContext context) {
    final color = registro.completo ? ColoresUcsa.exito : ColoresUcsa.alerta;
    final pendientes = registro.pendientes.toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.xs),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: tonoSuave(color, alfa: 28),
            child: Icon(registro.completo ? Icons.verified_rounded : Icons.warning_amber_rounded, color: color),
          ),
          title: Text(
            '${registro.robot} · ${registro.completados}/${registro.total}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text([
            '${formatearFechaHora(registro.fecha)} · ${registro.usuario}',
            if (pendientes.isNotEmpty) 'Sin verificar: ${pendientes.join(', ')}',
          ].join('\n')),
          isThreeLine: pendientes.isNotEmpty,
        ),
      ),
    );
  }
}
