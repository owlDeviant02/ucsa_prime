/// Editor de una entrada nueva de la bitácora (vista del patrón MVVM).
///
/// El integrante escribe o dicta un apunte informal; con «Formalizar con IA»,
/// `EditorBitacoraController` lo envía a Gemini (Firebase AI Logic), que lo
/// reescribe en español formal y técnico sin agregar información. La respuesta
/// llega en streaming a una hoja inferior; si el usuario la acepta, reemplaza
/// el apunte en el campo para revisarla antes de guardar. Al guardar se
/// escribe el nodo `bitacoras/{id}` con fecha, autor, tipo y la marca
/// `generadaPorIA` (y el apunte original, para la trazabilidad).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ucsa_prime/controllers/bitacora_controller.dart';
import 'package:ucsa_prime/models/bitacora.dart';
import 'package:ucsa_prime/services/avisos.dart';
import 'package:ucsa_prime/ui/componentes.dart';
import 'package:ucsa_prime/ui/modulos.dart';
import 'package:ucsa_prime/ui/tema.dart';

/// Nueva entrada de bitácora. Flujo del apartado IV.6.3.3: captura por teclado o
/// voz → formalización con Gemini (en streaming) → revisión del usuario →
/// guardado con metadatos (fecha, autor, tipo y marca `generadaPorIA`).
class EditorBitacoraPage extends StatefulWidget {
  const EditorBitacoraPage({super.key});

  @override
  State<EditorBitacoraPage> createState() => _EditorBitacoraPageState();
}

class _EditorBitacoraPageState extends State<EditorBitacoraPage> {
  late final EditorBitacoraController _vm = EditorBitacoraController();
  final TextEditingController _texto = TextEditingController();
  String _textoAntesDeDictar = '';
  bool _guardado = false;

  @override
  void dispose() {
    _vm.dispose();
    _texto.dispose();
    super.dispose();
  }

  bool get _hayBorrador => !_guardado && _texto.text.trim().isNotEmpty;

  Future<void> _alternarDictado() async {
    if (_vm.estado.dictando) {
      await _vm.detenerDictado();
      return;
    }
    final disponible = await _vm.prepararDictado((error) => mostrarAviso(error, error: true));
    if (!disponible) {
      mostrarAviso(
        'No se pudo activar el dictado: permití el acceso al micrófono y verificá que el '
        'teléfono tenga reconocimiento de voz.',
        error: true,
      );
      return;
    }
    _textoAntesDeDictar = _texto.text.trimRight();
    await _vm.dictar((reconocido, _) {
      if (!mounted) return;
      final nuevo = _textoAntesDeDictar.isEmpty ? reconocido : '$_textoAntesDeDictar $reconocido';
      _texto.value = TextEditingValue(text: nuevo, selection: TextSelection.collapsed(offset: nuevo.length));
    });
  }

  Future<void> _formalizar() async {
    final apunte = _texto.text.trim();
    if (apunte.length < 15) {
      mostrarAviso('Escribí un poco más (al menos 15 caracteres) para que la IA tenga contexto.', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    if (_vm.estado.dictando) await _vm.detenerDictado();
    if (!mounted) return;
    unawaited(_vm.formalizar(apunte));
    final usar = await mostrarHoja<bool>(
      context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _HojaFormalizacion(vm: _vm, apunte: apunte),
    );
    final generado = _vm.estado.textoGenerado.trim();
    if (usar == true && generado.isNotEmpty) {
      _vm.aceptarTextoIA(apunte);
      _texto.value = TextEditingValue(text: generado, selection: const TextSelection.collapsed(offset: 0));
      mostrarAviso('Texto formalizado. Revisalo antes de guardar.');
    } else {
      _vm.cancelarFormalizacion();
    }
  }

  void _restaurarApunte() {
    final original = _vm.restaurarApunte();
    if (original != null) _texto.text = original;
  }

  void _guardar() {
    final contenido = _texto.text.trim();
    if (contenido.length < 10) {
      mostrarAviso('La entrada es demasiado corta (mínimo 10 caracteres).', error: true);
      return;
    }
    _vm.detenerDictado();
    sincronizarEnSegundoPlano(_vm.guardar(contenido), accion: 'No se pudo guardar la bitácora');
    _guardado = true;
    Navigator.of(context).pop();
    mostrarAviso('Entrada guardada en la bitácora');
  }

  Future<void> _alSalir() async {
    if (!_hayBorrador) {
      Navigator.of(context).pop();
      return;
    }
    final descartar = await confirmar(
      context,
      titulo: '¿Descartar el borrador?',
      mensaje: 'El texto escrito todavía no se guardó.',
      textoConfirmar: 'Descartar',
    );
    if (descartar && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _alSalir();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Nueva entrada')),
        body: ListView(
          padding: rellenoLista(context, fin: Espacio.l),
          children: [
            Text('Tipo de registro', style: tema.textTheme.labelLarge),
            const SizedBox(height: Espacio.xs),
            VistaReactiva<EditorBitacoraEstado>(
              viewModel: _vm,
              builder: (context, estado) => Wrap(
                spacing: Espacio.xs,
                runSpacing: Espacio.xs,
                children: [
                  for (final tipo in TipoBitacora.values)
                    ChoiceChip(
                      avatar: Icon(iconoTipoBitacora(tipo)),
                      label: Text(tipo.etiqueta),
                      selected: estado.tipo == tipo,
                      onSelected: (_) => _vm.cambiarTipo(tipo),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Espacio.m),
            VistaReactiva<EditorBitacoraEstado>(
              viewModel: _vm,
              builder: (context, estado) => estado.usaIA
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: Espacio.s),
                      child: _AvisoTextoIA(alRestaurar: _restaurarApunte),
                    )
                  : const SizedBox.shrink(),
            ),
            TextField(
              controller: _texto,
              minLines: 8,
              maxLines: 18,
              maxLength: 6000,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Escribí o dictá tu apunte informal.\nEj.: "hoy probamos el autónomo, el robot se '
                    'desvió como 5 cm después de 2 metros…"',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: Espacio.xs),
            VistaReactiva<EditorBitacoraEstado>(
              viewModel: _vm,
              builder: (context, estado) => Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: estado.generando ? null : _alternarDictado,
                      style: estado.dictando
                          ? OutlinedButton.styleFrom(
                              foregroundColor: ColoresUcsa.peligro,
                              side: const BorderSide(color: ColoresUcsa.peligro),
                            )
                          : null,
                      icon: Icon(estado.dictando ? Icons.stop_circle_rounded : Icons.mic_rounded),
                      label: Text(estado.dictando ? 'Detener' : 'Dictar'),
                    ),
                  ),
                  const SizedBox(width: Espacio.s),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: ColoresUcsa.ia),
                      onPressed: estado.generando ? null : _formalizar,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Formalizar con IA'),
                    ),
                  ),
                ],
              ),
            ),
            VistaReactiva<EditorBitacoraEstado>(
              viewModel: _vm,
              builder: (context, estado) => AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: estado.dictando
                    ? const Padding(
                        padding: EdgeInsets.only(top: Espacio.s),
                        child: Row(
                          children: [
                            SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: Espacio.s),
                            Text('Escuchando… hablá con naturalidad'),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
            const SizedBox(height: Espacio.m),
            Text(
              'Gemini reescribe el apunte en español formal y técnico, con los mismos hechos y '
              'valores, sin agregar información. Revisá siempre el resultado antes de guardarlo.',
              style: tema.textTheme.bodySmall?.copyWith(color: ColoresUcsa.textoSuave),
            ),
          ],
        ),
        bottomNavigationBar: BarraAccionInferior(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: ColoresUcsa.bitacora, foregroundColor: ColoresUcsa.texto),
            onPressed: _guardar,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Guardar entrada'),
          ),
        ),
      ),
    );
  }
}

/// Aviso de que el campo contiene texto generado por IA, con la opción de
/// volver al apunte original.
class _AvisoTextoIA extends StatelessWidget {
  const _AvisoTextoIA({required this.alRestaurar});

  final VoidCallback alRestaurar;

  @override
  Widget build(BuildContext context) {
    return RecuadroAviso(
      icono: Icons.auto_awesome_rounded,
      color: ColoresUcsa.ia,
      mensaje: 'Texto generado por IA: revisalo y corregilo si hace falta.',
      accion: TextButton(onPressed: alRestaurar, child: const Text('Ver original')),
    );
  }
}

/// Hoja que muestra la respuesta de Gemini a medida que llega (streaming).
class _HojaFormalizacion extends StatelessWidget {
  const _HojaFormalizacion({required this.vm, required this.apunte});

  final EditorBitacoraController vm;
  final String apunte;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: VistaReactiva<EditorBitacoraEstado>(
        viewModel: vm,
        builder: (context, estado) {
          final terminado = !estado.generando && estado.textoGenerado.isNotEmpty && estado.errorIA == null;
          // Sin asa de arrastre (la hoja no se puede arrastrar): el título lleva
          // su propio margen superior. Los botones quedan por encima de la barra
          // de navegación del sistema.
          return Padding(
            padding: EdgeInsets.fromLTRB(
              Espacio.margen,
              Espacio.l,
              Espacio.margen,
              Espacio.m + margenBarraNavegacion(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: ColoresUcsa.ia),
                    const SizedBox(width: Espacio.xs),
                    Expanded(
                      child: Text(
                        estado.errorIA != null
                            ? 'No se pudo formalizar'
                            : estado.generando
                                ? 'Gemini está redactando…'
                                : 'Versión formal lista',
                        style: tema.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Espacio.s),
                if (estado.generando)
                  LinearProgressIndicator(
                    color: ColoresUcsa.ia,
                    backgroundColor: tonoSuave(ColoresUcsa.ia),
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(Radios.chico),
                  ),
                const SizedBox(height: Espacio.s),
                Expanded(
                  child: Card(
                    child: estado.errorIA != null
                        ? Padding(
                            padding: Espacio.tarjeta,
                            child: Text(
                              estado.errorIA!,
                              style: tema.textTheme.bodyMedium?.copyWith(color: ColoresUcsa.peligro),
                            ),
                          )
                        : estado.textoGenerado.isEmpty
                            ? const EstadoCargando(
                                mensaje: 'Enviando el apunte a Gemini…',
                                detalle: 'La respuesta aparecerá aquí a medida que se genera.',
                              )
                            : SingleChildScrollView(
                                reverse: estado.generando,
                                padding: Espacio.tarjeta,
                                child: SelectableText(estado.textoGenerado, style: tema.textTheme.bodyLarge),
                              ),
                  ),
                ),
                const SizedBox(height: Espacio.s),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(estado.generando ? 'Cancelar' : 'Descartar'),
                      ),
                    ),
                    const SizedBox(width: Espacio.s),
                    Expanded(
                      child: estado.errorIA != null
                          ? FilledButton.icon(
                              onPressed: () => vm.formalizar(apunte),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reintentar'),
                            )
                          : FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: ColoresUcsa.ia),
                              onPressed: terminado ? () => Navigator.of(context).pop(true) : null,
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Usar este texto'),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
