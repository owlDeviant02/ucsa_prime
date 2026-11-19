/// Pantalla de inicio (vista del patrón MVVM).
///
/// Muestra, en tiempo real, el resumen de todos los módulos que calcula
/// `DashboardController`: estado de la conexión con Firebase, último checklist
/// de Jordan, estadísticas (componentes, stock bajo, tareas y bitácoras),
/// accesos a los cuatro módulos, componentes con stock bajo y la actividad
/// reciente del equipo. El menú de la cabecera permite cargar o quitar los
/// datos de demostración, ver la información de la app y cerrar sesión.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ucsa_prime/app.dart';
import 'package:ucsa_prime/controllers/dashboard_controller.dart';
import 'package:ucsa_prime/controllers/sesion_controller.dart';
import 'package:ucsa_prime/models/actividad.dart';
import 'package:ucsa_prime/models/componente_inventario.dart';
import 'package:ucsa_prime/services/avisos.dart';
import 'package:ucsa_prime/ui/componentes.dart';
import 'package:ucsa_prime/ui/modulos.dart';
import 'package:ucsa_prime/ui/tema.dart';
import 'package:ucsa_prime/utils/fechas.dart';
import 'package:ucsa_prime/views/bitacora/bitacora_page.dart';
import 'package:ucsa_prime/views/checklist/checklist_page.dart';
import 'package:ucsa_prime/views/ingreso/ingreso_page.dart';
import 'package:ucsa_prime/views/inventario/inventario_page.dart';
import 'package:ucsa_prime/views/tareas/tareas_page.dart';

/// Opciones del menú de la cabecera.
enum _AccionMenu { cargarDemo, quitarDemo, acercaDe, salir }

/// Inicio: resumen en tiempo real de todos los módulos.
class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  final DashboardController _vm = DashboardController();

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

  void _abrir(Widget pagina) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => pagina));
  }

  Future<void> _alElegir(_AccionMenu accion) async {
    switch (accion) {
      case _AccionMenu.cargarDemo:
        final ok = await confirmar(
          context,
          titulo: 'Cargar datos de demostración',
          mensaje: 'Se agregarán 10 componentes VEX, 5 tareas y una bitácora de ejemplo '
              '(identificados con el prefijo "demo-"). Si ya estaban cargados, se restablecen. '
              'No se modifica ningún otro dato del equipo.',
          textoConfirmar: 'Cargar',
          destructivo: false,
          icono: Icons.dataset_rounded,
        );
        if (!ok) return;
        sincronizarEnSegundoPlano(_vm.cargarDatosDemo(), accion: 'No se pudieron cargar los datos');
        mostrarAviso('Datos de demostración cargados');
      case _AccionMenu.quitarDemo:
        final ok = await confirmar(
          context,
          titulo: 'Quitar datos de demostración',
          mensaje: 'Se eliminarán solo los componentes, tareas y bitácoras con prefijo "demo-" '
              '(y el historial de esos componentes).',
          textoConfirmar: 'Quitar',
        );
        if (!ok) return;
        sincronizarEnSegundoPlano(_vm.quitarDatosDemo(), accion: 'No se pudieron quitar los datos');
        mostrarAviso('Datos de demostración quitados');
      case _AccionMenu.acercaDe:
        showAboutDialog(
          context: context,
          applicationName: 'UCSA Prime',
          applicationVersion: 'Versión $versionApp',
          applicationIcon: DecoratedBox(
            decoration: BoxDecoration(gradient: degradadoUcsa, borderRadius: BorderRadius.circular(Radios.medio)),
            child: Padding(
              padding: const EdgeInsets.all(Espacio.xs),
              child: Image.asset('assets/logo.png', width: 40, height: 40),
            ),
          ),
          applicationLegalese: 'Equipo UCSA Prime · VEX U',
          children: const [
            SizedBox(height: Espacio.m),
            Text(
              'Aplicación de gestión del equipo: inventario, tareas, checklist pre-partido y '
              'bitácora técnica. Flutter + Firebase Realtime Database (sincronización en tiempo '
              'real y caché sin conexión), arquitectura MVVM reactiva y formalización de apuntes '
              'con Gemini (Firebase AI Logic).',
            ),
          ],
        );
      case _AccionMenu.salir:
        final ok = await confirmar(
          context,
          titulo: 'Cerrar sesión',
          mensaje: '¿Querés salir de tu cuenta en este dispositivo?',
          textoConfirmar: 'Salir',
          icono: Icons.logout_rounded,
        );
        if (!ok || !mounted) return;
        SesionController.instancia.cerrarSesion();
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const IngresoPage()),
          (_) => false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final margenes = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            // Franja fija bajo la barra de estado: los íconos blancos siguen
            // legibles cuando la cabecera azul se desplaza fuera de la pantalla.
            SizedBox(
              height: margenes.top,
              width: double.infinity,
              child: const DecoratedBox(decoration: BoxDecoration(gradient: degradadoBarraEstado)),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: _contenido(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    return VistaReactiva<ResumenDashboard>(
      viewModel: _vm,
      builder: (context, resumen) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Cabecera(
              resumen: resumen,
              alElegir: _alElegir,
              alAbrirChecklist: () => _abrir(const ChecklistPage()),
            ),
          ),
          SliverPadding(
            padding: rellenoLista(context, arriba: Espacio.m, fin: Espacio.xl),
            sliver: SliverList.list(
              children: [
                _Estadisticas(resumen: resumen, abrir: _abrir),
                const EncabezadoSeccion('Módulos'),
                _GrillaModulos(resumen: resumen, abrir: _abrir),
                if (resumen.stockBajo.isNotEmpty) ...[
                  EncabezadoSeccion(
                    'Stock bajo',
                    accion: 'Ver todo',
                    alPulsar: () => _abrir(const InventarioPage(soloStockBajo: true)),
                  ),
                  _ListaStockBajo(componentes: resumen.stockBajo.take(3).toList()),
                ],
                const EncabezadoSeccion('Actividad reciente'),
                _ActividadReciente(resumen: resumen),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

/// Cabecera azul: logo, conexión, menú, saludo, fecha y tarjeta de Jordan.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.resumen, required this.alElegir, required this.alAbrirChecklist});

  final ResumenDashboard resumen;
  final ValueChanged<_AccionMenu> alElegir;
  final VoidCallback alAbrirChecklist;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nombre = SesionController.instancia.nombreUsuario.split(' ').first;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: degradadoUcsa,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Radios.extra + 6)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Espacio.margen, Espacio.xs, Espacio.xxs, Espacio.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset('assets/logo.png', height: 30),
                  const SizedBox(width: Espacio.s),
                  Expanded(
                    child: Text(
                      'UCSA Prime',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                  _ChipConexion(conexion: resumen.conexion),
                  PopupMenuButton<_AccionMenu>(
                    tooltip: 'Más opciones',
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                    onSelected: alElegir,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _AccionMenu.cargarDemo,
                        child: ListTile(leading: Icon(Icons.dataset_rounded), title: Text('Cargar datos de demostración')),
                      ),
                      PopupMenuItem(
                        value: _AccionMenu.quitarDemo,
                        child: ListTile(leading: Icon(Icons.layers_clear_rounded), title: Text('Quitar datos de demostración')),
                      ),
                      PopupMenuItem(
                        value: _AccionMenu.acercaDe,
                        child: ListTile(leading: Icon(Icons.info_outline_rounded), title: Text('Acerca de la aplicación')),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: _AccionMenu.salir,
                        child: ListTile(leading: Icon(Icons.logout_rounded), title: Text('Cerrar sesión')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Espacio.s),
              Text('¡Hola, $nombre!', style: tema.textTheme.headlineMedium?.copyWith(color: Colors.white)),
              Text(
                capitalizar(fechaLarga(DateTime.now())),
                style: tema.textTheme.bodyMedium?.copyWith(color: ColoresUcsa.textoSobreAzul),
              ),
              const SizedBox(height: Espacio.m),
              Padding(
                padding: const EdgeInsets.only(right: Espacio.s),
                child: _TarjetaRobot(resumen: resumen, alPulsar: alAbrirChecklist),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador del estado de la conexión con Firebase (sobre la cabecera azul).
class _ChipConexion extends StatelessWidget {
  const _ChipConexion({required this.conexion});

  final bool? conexion;

  @override
  Widget build(BuildContext context) {
    final (texto, color, icono) = switch (conexion) {
      null => ('Conectando…', Colors.white, Icons.sync_rounded),
      true => ('En línea', ColoresUcsa.enLineaSobreAzul, Icons.cloud_done_rounded),
      false => ('Sin conexión', ColoresUcsa.sinConexionSobreAzul, Icons.cloud_off_rounded),
    };
    return Tooltip(
      message: conexion == false
          ? 'Modo sin conexión: los cambios se guardan en el teléfono y se sincronizan al reconectar.'
          : 'Sincronización en tiempo real con Firebase',
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white.withAlpha(36), borderRadius: BorderRadius.circular(Radios.extra)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espacio.s, vertical: Espacio.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 15, color: color),
              const SizedBox(width: Espacio.xxs),
              Text(texto, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de Jordan con el resultado del último checklist; abre el checklist.
class _TarjetaRobot extends StatelessWidget {
  const _TarjetaRobot({required this.resumen, required this.alPulsar});

  final ResumenDashboard resumen;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final registro = resumen.ultimoChecklist;
    final (String estado, Color color, IconData icono) = !resumen.checklistCargado
        ? ('Consultando checklist…', ColoresUcsa.textoSuave, Icons.hourglass_empty_rounded)
        : registro == null
            ? ('Sin checklist registrado', ColoresUcsa.textoSuave, Icons.fact_check_outlined)
            : (
                '${registro.robot} ${registro.completados}/${registro.total} · ${haceCuanto(registro.fecha)}',
                registro.completo ? ColoresUcsa.exito : ColoresUcsa.alerta,
                registro.completo ? Icons.verified_rounded : Icons.warning_amber_rounded,
              );
    return Material(
      color: ColoresUcsa.superficie,
      borderRadius: BorderRadius.circular(Radios.extra),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPulsar,
        child: SizedBox(
          height: 140,
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: 6,
                bottom: 6,
                width: 210,
                child: Hero(
                  tag: 'robot-Jordan',
                  child: Image(
                    image: imagenReducida('assets/robots/jordan.png', ancho: 900),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.m, 150, Espacio.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jordan', style: tema.textTheme.headlineSmall?.copyWith(color: blueUcsa)),
                    Text(
                      'Robot VEX U · High Stakes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(color: ColoresUcsa.textoSuave),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(icono, size: 16, color: color),
                        const SizedBox(width: Espacio.xs),
                        Flexible(
                          child: Text(
                            estado,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.labelMedium?.copyWith(color: color),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

/// Cuatro cifras clave; cada tarjeta abre su módulo.
class _Estadisticas extends StatelessWidget {
  const _Estadisticas({required this.resumen, required this.abrir});

  final ResumenDashboard resumen;
  final void Function(Widget pagina) abrir;

  @override
  Widget build(BuildContext context) {
    final ultima = resumen.ultimaBitacora;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TarjetaEstadistica(
                titulo: 'Componentes',
                valor: resumen.totalComponentes,
                detalle: 'en inventario',
                icono: Modulos.inventario.icono,
                color: Modulos.inventario.colorTexto,
                alPulsar: () => abrir(const InventarioPage()),
              ),
            ),
            const SizedBox(width: Espacio.s),
            Expanded(
              child: _TarjetaEstadistica(
                titulo: 'Stock bajo',
                valor: resumen.totalComponentes == null ? null : resumen.stockBajo.length,
                detalle: resumen.stockBajo.isEmpty ? 'todo en orden' : 'requieren reposición',
                icono: Icons.warning_amber_rounded,
                color: resumen.stockBajo.isEmpty ? ColoresUcsa.exito : ColoresUcsa.peligro,
                alPulsar: () => abrir(const InventarioPage(soloStockBajo: true)),
              ),
            ),
          ],
        ),
        const SizedBox(height: Espacio.s),
        Row(
          children: [
            Expanded(
              child: _TarjetaEstadistica(
                titulo: 'Tareas activas',
                valor: resumen.tareasActivas,
                detalle: resumen.tareasVencidas > 0
                    ? '${resumen.tareasVencidas} vencida${resumen.tareasVencidas == 1 ? '' : 's'}'
                    : '${resumen.misTareasActivas} asignada${resumen.misTareasActivas == 1 ? '' : 's'} a vos',
                detalleEsAlerta: resumen.tareasVencidas > 0,
                icono: Modulos.tareas.icono,
                color: Modulos.tareas.colorTexto,
                alPulsar: () => abrir(const TareasPage()),
              ),
            ),
            const SizedBox(width: Espacio.s),
            Expanded(
              child: _TarjetaEstadistica(
                titulo: 'Bitácoras',
                valor: resumen.totalBitacoras,
                detalle: ultima == null ? 'sin entradas' : 'última ${haceCuanto(ultima.fecha)}',
                icono: Modulos.bitacora.icono,
                color: Modulos.bitacora.colorTexto,
                alPulsar: () => abrir(const BitacoraPage()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TarjetaEstadistica extends StatelessWidget {
  const _TarjetaEstadistica({
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.icono,
    required this.color,
    required this.alPulsar,
    this.detalleEsAlerta = false,
  });

  final String titulo;
  final int? valor;
  final String detalle;
  final IconData icono;
  final Color color;
  final VoidCallback alPulsar;
  final bool detalleEsAlerta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return TarjetaPulsable(
      alPulsar: alPulsar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: color),
              const SizedBox(width: Espacio.xs),
              Expanded(
                child: Text(titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.labelLarge?.copyWith(color: ColoresUcsa.textoSuave)),
              ),
            ],
          ),
          const SizedBox(height: Espacio.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 38),
            child: Align(
              alignment: Alignment.centerLeft,
              child: valor == null
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text('$valor', style: tema.textTheme.headlineLarge?.copyWith(color: color, height: 1)),
            ),
          ),
          Text(
            valor == null ? 'cargando…' : detalle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tema.textTheme.bodySmall?.copyWith(
              color: detalleEsAlerta ? ColoresUcsa.peligro : ColoresUcsa.textoSuave,
              fontWeight: detalleEsAlerta ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

/// Accesos a los cuatro módulos, en dos filas.
class _GrillaModulos extends StatelessWidget {
  const _GrillaModulos({required this.resumen, required this.abrir});

  final ResumenDashboard resumen;
  final void Function(Widget pagina) abrir;

  @override
  Widget build(BuildContext context) {
    final pendientes = resumen.tareasActivas;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TarjetaModulo(
                modulo: Modulos.inventario,
                insignia: resumen.stockBajo.isEmpty
                    ? null
                    : '${resumen.stockBajo.length} alerta${resumen.stockBajo.length == 1 ? '' : 's'}',
                alPulsar: () => abrir(const InventarioPage()),
              ),
            ),
            const SizedBox(width: Espacio.s),
            Expanded(
              child: _TarjetaModulo(
                modulo: Modulos.tareas,
                insignia: (pendientes == null || pendientes == 0) ? null : '$pendientes activas',
                alPulsar: () => abrir(const TareasPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: Espacio.s),
        Row(
          children: [
            Expanded(
              child: _TarjetaModulo(modulo: Modulos.checklist, alPulsar: () => abrir(const ChecklistPage())),
            ),
            const SizedBox(width: Espacio.s),
            Expanded(
              child: _TarjetaModulo(modulo: Modulos.bitacora, alPulsar: () => abrir(const BitacoraPage())),
            ),
          ],
        ),
      ],
    );
  }
}

class _TarjetaModulo extends StatelessWidget {
  const _TarjetaModulo({required this.modulo, required this.alPulsar, this.insignia});

  final InfoModulo modulo;
  final VoidCallback alPulsar;

  /// Dato destacado en la esquina (p. ej. «4 activas»); `null` si no hay.
  final String? insignia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPulsar,
        child: Ink(
          height: 132,
          decoration: BoxDecoration(
            image: modulo.imagen == null
                ? null
                : DecorationImage(
                    image: imagenReducida(modulo.imagen!, ancho: 520),
                    fit: BoxFit.cover,
                    opacity: 0.08,
                  ),
          ),
          child: Padding(
            padding: Espacio.tarjeta,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconoEnCaja(modulo.icono, color: modulo.colorTexto),
                    const SizedBox(width: Espacio.xs),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: insignia == null ? null : Etiqueta(insignia!, color: modulo.colorTexto),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(modulo.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleMedium),
                Text(
                  modulo.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.bodySmall?.copyWith(color: ColoresUcsa.textoSuave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

/// Hasta tres componentes con stock bajo.
class _ListaStockBajo extends StatelessWidget {
  const _ListaStockBajo({required this.componentes});

  final List<ComponenteInventario> componentes;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < componentes.length; i++) ...[
            if (i > 0) const Divider(indent: Espacio.m, endIndent: Espacio.m),
            ListTile(
              leading: Icon(iconoCategoria(componentes[i].categoria), color: ColoresUcsa.peligro),
              title: Text(componentes[i].nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                componentes[i].ubicacion.isEmpty
                    ? etiquetaCategoria(componentes[i].categoria)
                    : '${etiquetaCategoria(componentes[i].categoria)} · ${componentes[i].ubicacion}',
              ),
              trailing: Text(
                '${componentes[i].cantidadDisponible} / mín. ${componentes[i].cantidadMinima}',
                style: tema.textTheme.labelLarge?.copyWith(color: ColoresUcsa.peligro),
              ),
              subtitleTextStyle: tema.textTheme.bodySmall?.copyWith(color: ColoresUcsa.textoSuave),
            ),
          ],
        ],
      ),
    );
  }
}

/// Últimas acciones del equipo (quién hizo qué y cuándo).
class _ActividadReciente extends StatelessWidget {
  const _ActividadReciente({required this.resumen});

  final ResumenDashboard resumen;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (!resumen.actividadCargada) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(Espacio.l),
          child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))),
        ),
      );
    }
    if (resumen.actividad.isEmpty) {
      return Card(
        child: Padding(
          padding: Espacio.tarjeta,
          child: Text(
            'Todavía no hay actividad registrada. Cada cambio de stock, tarea, checklist o '
            'bitácora aparecerá aquí con su autor y hora.',
            style: tema.textTheme.bodyMedium?.copyWith(color: ColoresUcsa.textoSuave),
          ),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < resumen.actividad.length; i++) ...[
            if (i > 0) const Divider(indent: 64),
            _FilaActividad(actividad: resumen.actividad[i]),
          ],
        ],
      ),
    );
  }
}

/// Una acción del registro de actividad.
class _FilaActividad extends StatelessWidget {
  const _FilaActividad({required this.actividad});

  final Actividad actividad;

  @override
  Widget build(BuildContext context) {
    final color = colorActividad(actividad.tipo);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tonoSuave(color),
        child: Icon(iconoActividad(actividad.tipo), color: color, size: 20),
      ),
      title: Text(actividad.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
      titleTextStyle: Theme.of(context).textTheme.bodyMedium,
      subtitleTextStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: ColoresUcsa.textoSuave),
      subtitle: Text('${actividad.usuario} · ${haceCuanto(actividad.fecha)}'),
    );
  }
}
