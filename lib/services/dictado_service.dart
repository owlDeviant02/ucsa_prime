/// Servicio de dictado por voz (capa de servicios).
///
/// Envuelve el paquete `speech_to_text` para que `EditorBitacoraController`
/// capture el apunte de la bitácora hablando, con preferencia por un
/// reconocedor en español. Los errores se traducen a mensajes para el usuario.
library;

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Dictado por voz para capturar apuntes (paso 1 del flujo del apartado IV.6.3.3:
/// "captura del apunte por teclado o voz"). Falla de forma controlada si el
/// dispositivo no tiene reconocedor de voz o se niega el permiso de micrófono.
class DictadoService {
  final SpeechToText _voz = SpeechToText();
  bool? _disponible;
  String? _idioma;

  /// El reconocedor está escuchando en este momento.
  bool get escuchando => _voz.isListening;

  /// Pide el permiso de micrófono la primera vez. Devuelve si el dictado está disponible.
  Future<bool> inicializar({
    required void Function(bool escuchando) alCambiarEstado,
    required void Function(String error) alFallar,
  }) async {
    void alEstado(String estado) => alCambiarEstado(estado == SpeechToText.listeningStatus);
    void alError(SpeechRecognitionError error) {
      alCambiarEstado(false);
      if (error.permanent) alFallar(_traducirError(error.errorMsg));
    }

    if (_disponible == null) {
      try {
        _disponible = await _voz.initialize(onStatus: alEstado, onError: alError);
        if (_disponible!) _idioma = await _elegirIdiomaEspanol();
      } catch (e) {
        debugPrint('Dictado no disponible: $e');
        _disponible = false;
      }
    }
    // SpeechToText es un singleton e `initialize` solo registra los oyentes la
    // primera vez: se reasignan para que apunten a la pantalla actual.
    _voz.statusListener = alEstado;
    _voz.errorListener = alError;
    return _disponible!;
  }

  /// Quita los oyentes al cerrar la pantalla.
  void liberar() {
    _voz.statusListener = null;
    _voz.errorListener = null;
  }

  /// Idioma español del reconocedor, con preferencia por las variantes de la
  /// región; `null` si no hay ninguno (se usa el idioma del sistema).
  Future<String?> _elegirIdiomaEspanol() async {
    try {
      final idiomas = await _voz.locales();
      const preferidos = ['es_PY', 'es-PY', 'es_419', 'es-419', 'es_AR', 'es-AR', 'es_ES', 'es-ES'];
      for (final preferido in preferidos) {
        if (idiomas.any((l) => l.localeId == preferido)) return preferido;
      }
      for (final idioma in idiomas) {
        if (idioma.localeId.toLowerCase().startsWith('es')) return idioma.localeId;
      }
    } catch (_) {
      // Se usa el idioma del sistema.
    }
    return null;
  }

  /// Escucha y entrega el texto reconocido (parcial y final). Se detiene sola
  /// tras un minuto o después de 5 s de silencio.
  Future<void> escuchar(void Function(String texto, bool esFinal) alReconocer) async {
    if (_disponible != true) return;
    await _voz.listen(
      onResult: (resultado) => alReconocer(resultado.recognizedWords, resultado.finalResult),
      localeId: _idioma,
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(seconds: 5),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  /// Detiene la escucha y entrega el resultado final.
  Future<void> detener() async {
    if (_voz.isListening) await _voz.stop();
  }

  /// Cancela la escucha y descarta el resultado pendiente.
  Future<void> cancelar() async {
    if (_voz.isListening) await _voz.cancel();
  }

  /// Traduce el código de error del reconocedor a un mensaje en español.
  static String _traducirError(String codigo) {
    if (codigo.contains('permission')) return 'Se necesita el permiso de micrófono para dictar.';
    if (codigo.contains('network')) return 'El dictado necesita conexión a internet en este dispositivo.';
    if (codigo.contains('no_match') || codigo.contains('speech_timeout')) {
      return 'No se reconoció ninguna palabra. Intentá de nuevo.';
    }
    return 'El dictado por voz falló ($codigo).';
  }
}
