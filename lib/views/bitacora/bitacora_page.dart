/// Bitácora técnica: lista y detalle de entradas (vistas del patrón MVVM).
///
/// [BitacoraPage] observa a `BitacoraController`, que escucha el nodo
/// `bitacoras/` de Firebase en tiempo real y aplica la búsqueda y el filtro por
/// tipo. Cada tarjeta muestra el título (primera línea) y, debajo, el texto que
/// sigue. [DetalleBitacoraPage] muestra la entrada completa, el apunte original
/// cuando el texto se formalizó con Gemini, y permite copiarla o eliminarla
/// (con opción de deshacer). Las entradas nuevas se escriben en
/// `editor_bitacora_page.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ucsa_prime/controllers/bitacora_controller.dart';
import 'package:ucsa_prime/models/bitacora.dart';
import 'package:ucsa_prime/services/avisos.dart';
import 'package:ucsa_prime/services/firebase_service.dart';
import 'package:ucsa_prime/ui/componentes.dart';
import 'package:ucsa_prime/ui/modulos.dart';
import 'package:ucsa_prime/ui/tema.dart';
import 'package:ucsa_prime/utils/fechas.dart';
import 'package:ucsa_prime/views/bitacora/editor_bitacora_page.dart';

/// Bitácora técnica del equipo (lista en tiempo real con búsqueda y filtro por tipo).
class BitacoraPage extends StatefulWidget {
  const BitacoraPage({super.key});

  @override
  State<BitacoraPage> createState() => _BitacoraPageState();
}

class _BitacoraPageState extends State<BitacoraPage> {
  final BitacoraController _vm = BitacoraController();
  final TextEditingController _busqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.iniciar();
  }

  @override
  void dispose() {
    _vm.dispose();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _importar() async {
    final ok = await confirmar(
      context,
      titulo: 'Importar registros anteriores',
      mensaje: 'La versión 2.0 guardaba las bitácoras sueltas en la raíz de la base de datos. '
          'Se copiarán a la nueva estructura (sin borrar los originales). Si ya se importaron, '
          'no se duplican.',
      textoConfirmar: 'Importar',
      destructivo: false,
      icono: Icons.history_edu_rounded,
    );
    if (!ok) return;
    mostrarAviso('Buscando registros anteriores…');
    try {
      final cantidad = await _vm.importarRegistrosAntiguos();
      mostrarAviso(cantidad == 0
          ? 'No se encontraron registros anteriores'
          : 'Se importaron $cantidad registros anteriores');
    } catch (e) {
      mostrarAviso('No se pudo importar: ${describirErrorFirebase(e)}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bitácora técnica'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (_) => _importar(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'importar',
                child: ListTile(
                  leading: Icon(Icons.history_edu_rounded),
                  title: Text('Importar registros anteriores'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-bitacora',
        backgroundColor: ColoresUcsa.bitacora,
        foregroundColor: blackUcsa,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EditorBitacoraPage()),
        ),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Nueva entrada'),
      ),
      body: Column(
        children: [
          // El buscador queda fuera del StreamBuilder: no se reconstruye con los datos.
          CampoBusqueda(
            controlador: _busqueda,
            alCambiar: _vm.buscar,
            pista: 'Buscar por texto o autor',
          ),
          Expanded(
            child: VistaReactiva<BitacoraEstado>(
              viewModel: _vm,
              builder: (context, estado) => Column(
                children: [
                  FilaDeChips(
                    chips: [
                      ChoiceChip(
                        label: Text('Todas (${estado.todas.length})'),
                        selected: estado.tipo == null,
                        onSelected: (_) => _vm.filtrarTipo(null),
                      ),
                      for (final tipo in TipoBitacora.values)
                        ChoiceChip(
                          avatar: Icon(iconoTipoBitacora(tipo)),
                          label: Text(tipo.etiqueta),
                          selected: estado.tipo == tipo,
                          onSelected: (si) => _vm.filtrarTipo(si ? tipo : null),
                        ),
                    ],
                  ),
                  Expanded(child: _contenido(estado)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido(BitacoraEstado estado) {
    if (estado.error != null && estado.todas.isEmpty) return EstadoMensaje.error(mensaje: estado.error!);
    if (estado.cargando) return const EstadoCargando(mensaje: 'Sincronizando bitácoras…');
    if (estado.todas.isEmpty) {
      return EstadoMensaje(
        icono: Icons.menu_book_outlined,
        titulo: 'Sin entradas todavía',
        mensaje: 'Escribí o dictá un apunte y dejá que Gemini lo reescriba en versión formal.',
        color: Modulos.bitacora.colorTexto,
      );
    }
    if (estado.visibles.isEmpty) {
      return const EstadoMensaje(
        icono: Icons.search_off_rounded,
        titulo: 'Sin resultados',
        mensaje: 'Ninguna entrada coincide con la búsqueda o el filtro.',
      );
    }
    return ListView.builder(
      padding: rellenoLista(context),
      itemCount: estado.visibles.length,
      itemBuilder: (context, i) => _TarjetaBitacora(
        key: ValueKey(estado.visibles[i].id),
        entrada: estado.visibles[i],
        vm: _vm,
      ),
    );
  }
}

/// Tarjeta de una entrada: tipo, marcas, fecha, título, continuación del texto y autor.
class _TarjetaBitacora extends StatelessWidget {
  const _TarjetaBitacora({super.key, required this.entrada, required this.vm});

  final EntradaBitacora entrada;
  final BitacoraController vm;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = Modulos.bitacora.colorTexto;
    final vistaPrevia = entrada.vistaPrevia;
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.s),
      child: TarjetaPulsable(
        alPulsar: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DetalleBitacoraPage(entrada: entrada, vm: vm)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(child: Etiqueta(entrada.tipo.etiqueta, color: color, icono: iconoTipoBitacora(entrada.tipo))),
                if (entrada.generadaPorIA) ...[
                  const SizedBox(width: Espacio.xs),
                  const Etiqueta('IA', color: ColoresUcsa.ia, icono: Icons.auto_awesome_rounded),
                ],
                if (entrada.importada) ...[
                  const SizedBox(width: Espacio.xs),
                  const Etiqueta('v2.0', color: ColoresUcsa.textoSuave),
                ],
                const Spacer(),
                Text(haceCuanto(entrada.fecha), style: tema.textTheme.bodySmall?.copyWith(color: ColoresUcsa.textoSuave)),
              ],
            ),
            const SizedBox(height: Espacio.s),
            Text(entrada.titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: tema.textTheme.titleSmall),
            if (vistaPrevia.isNotEmpty) ...[
              const SizedBox(height: Espacio.xxs),
              Text(
                vistaPrevia,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodyMedium?.copyWith(color: ColoresUcsa.textoSuave),
              ),
            ],
            const SizedBox(height: Espacio.s),
            AutorConAvatar(entrada.autor, color: color),
          ],
        ),
      ),
    );
  }
}

/// Detalle de una entrada: texto completo seleccionable, apunte original y acciones.
class DetalleBitacoraPage extends StatelessWidget {
  const DetalleBitacoraPage({super.key, required this.entrada, required this.vm});

  final EntradaBitacora entrada;
  final BitacoraController vm;

  Future<void> _eliminar(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar entrada',
      mensaje: '¿Eliminar esta entrada de la bitácora? Podrás deshacerlo durante unos segundos.',
    );
    if (!ok || !context.mounted) return;
    Navigator.of(context).pop();
    sincronizarEnSegundoPlano(vm.eliminar(entrada), accion: 'No se pudo eliminar');
    mostrarAviso(
      'Entrada eliminada',
      accion: SnackBarAction(
        label: 'DESHACER',
        onPressed: () => sincronizarEnSegundoPlano(vm.restaurar(entrada), accion: 'No se pudo restaurar'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(entrada.tipo.etiqueta),
        actions: [
          IconButton(
            tooltip: 'Copiar texto',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: entrada.contenido));
              mostrarAviso('Texto copiado al portapapeles');
            },
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline_rounded, color: ColoresUcsa.peligro),
            onPressed: () => _eliminar(context),
          ),
        ],
      ),
      body: ListView(
        padding: rellenoLista(context, fin: Espacio.xl),
        children: [
          Wrap(
            spacing: Espacio.xs,
            runSpacing: Espacio.xs,
            children: [
              Etiqueta(formatearFechaHora(entrada.fecha), color: ColoresUcsa.textoSuave, icono: Icons.event_rounded),
              Etiqueta(entrada.autor, color: blueUcsa, icono: Icons.person_rounded),
              if (entrada.generadaPorIA)
                const Etiqueta('Formalizada con Gemini', color: ColoresUcsa.ia, icono: Icons.auto_awesome_rounded),
            ],
          ),
          const SizedBox(height: Espacio.m),
          Card(
            child: Padding(
              padding: Espacio.tarjeta,
              child: SelectableText(entrada.contenido, style: tema.textTheme.bodyLarge),
            ),
          ),
          if (entrada.apunteOriginal != null && entrada.apunteOriginal!.isNotEmpty) ...[
            const SizedBox(height: Espacio.s),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: Text('Apunte original', style: tema.textTheme.titleSmall),
                subtitle: Text(
                  'Texto informal que se envió a la IA',
                  style: tema.textTheme.bodySmall?.copyWith(color: ColoresUcsa.textoSuave),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(Espacio.m, 0, Espacio.m, Espacio.m),
                children: [
                  SelectableText(
                    entrada.apunteOriginal!,
                    style: tema.textTheme.bodyMedium?.copyWith(color: ColoresUcsa.textoSuave, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
