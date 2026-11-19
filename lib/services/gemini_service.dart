// Servicio de IA generativa de la bitácora (capa de servicios).
//
// Reescribe en versión formal y técnica el apunte informal de una entrada de la
// bitácora, sin agregar información. Usa Gemini a través de Firebase AI Logic,
// protegido con App Check (activado por FirebaseService al arrancar). Para
// responder rápido aplica una «carrera escalonada» entre gemini-3.8-flash y
// gemini-3.5-flash-lite. Lo consume EditorBitacoraController; los errores se
// entregan como ErrorIA, con un mensaje en español para la vista.

import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
// firebase_core 4.15+ también exporta una interfaz `FirebaseService`.
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:ucsa_prime/services/firebase_service.dart';

/// Error de IA ya traducido a un mensaje para el usuario.
class ErrorIA implements Exception {
  const ErrorIA(this.mensaje);

  final String mensaje;

  /// Clasifica un error del SDK (tiempo agotado, cuota, App Check, red, modelo
  /// no habilitado…) y devuelve el mensaje correspondiente. `null` significa
  /// que ningún modelo configurado estuvo disponible.
  factory ErrorIA.desde(Object? error) {
    if (error is ErrorIA) return error;
    if (error == null) {
      return const ErrorIA('Ningún modelo de Gemini configurado está disponible. '
          'Actualizá la lista de modelos en lib/services/gemini_service.dart.');
    }
    final texto = error.toString();
    final m = texto.toLowerCase();
    if (error is TimeoutException) {
      return const ErrorIA('Gemini no respondió a tiempo. Revisá la conexión e intentá de nuevo.');
    }
    // 400 INVALID_ARGUMENT: el modelo no admite el nivel de razonamiento pedido.
    if (_mencionaNivelRazonamiento(m)) {
      return const ErrorIA('El modelo de Gemini rechazó el nivel de razonamiento configurado '
          '(thinkingLevel). Revisá los niveles en lib/services/gemini_service.dart.');
    }
    if (m.contains('app check') || m.contains('appcheck') || m.contains('attestation')) {
      return const ErrorIA('Firebase App Check rechazó la solicitud. Registrá el token de depuración '
          'de este dispositivo en la consola de Firebase (ver README.md).');
    }
    if (error is QuotaExceeded ||
        m.contains('quota') ||
        m.contains('resource_exhausted') ||
        m.contains('rate limit')) {
      return const ErrorIA('Se alcanzó la cuota de uso de Gemini. Esperá un minuto e intentá de nuevo.');
    }
    if (error is InvalidApiKey || m.contains('api_key_invalid') || m.contains('api key not valid')) {
      return const ErrorIA('La clave de API de Firebase no es válida para Gemini.');
    }
    if (error is ServiceApiNotEnabled ||
        m.contains('has not been used') ||
        m.contains('is disabled') ||
        m.contains('not enabled')) {
      return const ErrorIA('Firebase AI Logic no está habilitado en el proyecto de Firebase.');
    }
    if (m.contains('blocked')) {
      return const ErrorIA('Gemini bloqueó la respuesta por sus filtros de seguridad. Reformulá el texto.');
    }
    if (m.contains('socketexception') || m.contains('failed host lookup') ||
        m.contains('clientexception') || m.contains('network')) {
      return const ErrorIA('Sin conexión a internet. Gemini necesita conexión para responder.');
    }
    final corto = texto.length > 160 ? '${texto.substring(0, 157)}…' : texto;
    return ErrorIA('No se pudo completar la solicitud a Gemini: $corto');
  }

  /// El error menciona el nivel de razonamiento (thinking level / thinking_level).
  static bool _mencionaNivelRazonamiento(String mensaje) =>
      mensaje.contains('thinking level') ||
      mensaje.contains('thinking_level') ||
      mensaje.contains('thinkinglevel');

  @override
  String toString() => mensaje;
}

/// Servicio de IA generativa (Gemini a través de Firebase AI Logic), usado para
/// formalizar los apuntes de la bitácora.
///
/// App Check se aplica automáticamente: firebase_ai 4.x toma la instancia de
/// App Check que activa `FirebaseService` al arrancar.
class GeminiService {
  GeminiService._();

  /// Instancia única; conserva el último modelo que respondió.
  static final GeminiService instancia = GeminiService._();

  /// Modelos Gemini Flash en orden de preferencia: el Flash más reciente y, como
  /// respaldo rápido, Flash-Lite. Se consultan en «carrera escalonada» (ver [_generar]).
  static const List<String> _modelos = [
    'gemini-3.8-flash', // Gemini 3.8 Flash (el más reciente)
    'gemini-3-flash-preview', // Gemini 3 Flash: suele responder en pocos segundos
    'gemini-3.5-flash-lite', // respaldo: Gemini 3.5 Flash-Lite
  ];

  /// Si el primer modelo no empezó a responder en este tiempo, se consulta en
  /// paralelo el siguiente y se muestra la respuesta que llegue primero.
  static const Duration escalonamiento = Duration(milliseconds: 2500);

  /// Plazo máximo hasta el primer texto (y entre fragmentos) antes de abandonar.
  static const Duration plazo = Duration(seconds: 25);

  /// Opcional: modelo que se prueba primero, fijado al compilar
  /// (`--dart-define=GEMINI_PRIMERO=<modelo>`); por defecto, [_modelos].
  static const String _primero = String.fromEnvironment('GEMINI_PRIMERO');

  /// Lista de modelos configurados (para las pruebas).
  @visibleForTesting
  static List<String> get modelosCandidatos => List.unmodifiable(_modelos);

  /// Orden de consulta: [_primero], si se definió, y luego el resto de [_modelos].
  static List<String> get _orden =>
      _primero.isEmpty ? _modelos : [_primero, ..._modelos.where((m) => m != _primero)];

  /// Razonamiento lo más bajo que admite cada modelo, para que la respuesta empiece
  /// a llegar cuanto antes: Flash-Lite admite MINIMAL; 3.8 Flash, como mínimo LOW.
  @visibleForTesting
  static ThinkingLevel nivelPara(String modelo) =>
      modelo == 'gemini-3.8-flash' ? ThinkingLevel.low : ThinkingLevel.minimal;

  /// Instrucción de sistema de la formalización de la bitácora.
  static const String _instruccionesBitacora =
      'Eres un asistente de redacción técnica del equipo de robótica UCSA Prime (VEX U). Reescribes '
      'apuntes informales en español formal y técnico, sin agregar información.';

  String? _activo;

  /// Solo para pruebas: reemplaza la llamada real a Gemini por un flujo simulado.
  @visibleForTesting
  static Stream<GenerateContentResponse> Function(String modelo)? fuentePrueba;

  /// Solo para pruebas: olvida el último modelo que respondió.
  @visibleForTesting
  void reiniciarParaPruebas() => _activo = null;

  /// Nombre del modelo que respondió por última vez (informativo).
  String? get modeloActivo => _activo;

  FirebaseAI get _ai => FirebaseAI.googleAI(app: Firebase.app());

  /// Configura un modelo con la instrucción de sistema, el nivel de razonamiento
  /// de [nivelPara] y un filtro de seguridad adecuado a textos de taller.
  GenerativeModel _crearModelo(String modelo, String instrucciones) {
    return _ai.generativeModel(
      model: modelo,
      systemInstruction: Content.system(instrucciones),
      generationConfig: GenerationConfig(
        // Gemini 3.x siempre razona: se regula con el nivel de razonamiento.
        // temperature, topK y topP se ignoran en estos modelos.
        thinkingConfig: ThinkingConfig.withThinkingLevel(nivelPara(modelo)),
        maxOutputTokens: 4096,
      ),
      safetySettings: [
        // Textos de taller (corte, baterías, presión) no deben bloquearse por error.
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none, null),
      ],
    );
  }

  /// Genera texto en streaming (cada evento es el texto acumulado).
  ///
  /// «Carrera escalonada»: se consulta el primer modelo; si en [escalonamiento] no
  /// llegó texto (o si falla), se consulta también el siguiente, y se usa el que
  /// responda primero (el otro se cancela). Así se aprovecha el Flash más reciente
  /// cuando está disponible sin esperar de más cuando está saturado. Las
  /// cancelaciones no se esperan: una conexión colgada nunca bloquea la interfaz.
  Stream<String> _generar(List<Content> contenido, {required String instrucciones}) {
    if (fuentePrueba == null && !FirebaseService.disponible) {
      return Stream.error(const ErrorIA('Firebase no está inicializado; la IA no está disponible.'));
    }
    final candidatos = <String>[
      if (_activo != null) _activo!,
      ..._orden.where((m) => m != _activo),
    ];
    final salida = StreamController<String>();
    final activas = <String, StreamSubscription<GenerateContentResponse>>{};
    final errores = <Object>[];
    final texto = StringBuffer();
    String? ganador;
    var lanzados = 0;
    Timer? temporizadorEscalon;
    Timer? temporizadorPlazo;
    var terminado = false;
    // Registro en logcat (etiqueta «flutter») para diagnosticar la carrera en el celular.
    final reloj = Stopwatch()..start();
    void registrar(String m) => debugPrint('[Gemini ${reloj.elapsedMilliseconds} ms] $m');

    void cancelar(String nombre) {
      final s = activas.remove(nombre);
      if (s != null) unawaited(s.cancel().catchError((Object _) {}));
    }

    void terminar([Object? error]) {
      if (terminado) return;
      terminado = true;
      temporizadorEscalon?.cancel();
      temporizadorPlazo?.cancel();
      for (final nombre in activas.keys.toList()) {
        cancelar(nombre);
      }
      if (error != null) salida.addError(ErrorIA.desde(error));
      unawaited(salida.close());
    }

    void reiniciarPlazo() {
      temporizadorPlazo?.cancel();
      temporizadorPlazo = Timer(plazo, () {
        registrar('plazo vencido sin respuesta');
        terminar(TimeoutException('Gemini no respondió', plazo));
      });
    }

    late void Function() lanzar;

    /// Si nadie respondió en [escalonamiento], se suma el siguiente modelo.
    void programarSiguiente() {
      temporizadorEscalon?.cancel();
      if (lanzados >= candidatos.length) return;
      temporizadorEscalon = Timer(escalonamiento, () {
        if (!terminado && ganador == null && lanzados < candidatos.length) lanzar();
      });
    }

    void fallo(String nombre, Object error) {
      registrar('$nombre falló: ${error.toString().split('\n').first}');
      cancelar(nombre);
      if (terminado) return;
      if (ganador == nombre) {
        terminar(error);
        return;
      }
      if (ganador != null) return;
      errores.add(error);
      if (lanzados < candidatos.length) {
        lanzar();
      } else if (activas.isEmpty) {
        // Se informa el error más útil (cuota, App Check, red) antes que «no disponible».
        terminar(errores.firstWhere((e) => !debeProbarOtroModelo(e), orElse: () => errores.first));
      }
    }

    lanzar = () {
      final nombre = candidatos[lanzados++];
      registrar('consultando $nombre');
      final flujo = fuentePrueba?.call(nombre) ??
          _crearModelo(nombre, instrucciones).generateContentStream(contenido);
      activas[nombre] = flujo.listen(
        (respuesta) {
          if (terminado || (ganador != null && ganador != nombre)) return;
          String? parte;
          try {
            parte = respuesta.text;
          } catch (e) {
            fallo(nombre, e);
            return;
          }
          if (parte == null || parte.isEmpty) return;
          if (ganador == null) {
            registrar('primer texto de $nombre');
            ganador = nombre;
            _activo = nombre;
            temporizadorEscalon?.cancel();
            for (final otro in activas.keys.where((n) => n != nombre).toList()) {
              cancelar(otro);
            }
          }
          reiniciarPlazo();
          texto.write(parte);
          salida.add(texto.toString());
        },
        onError: (Object e) => fallo(nombre, e),
        onDone: () {
          activas.remove(nombre);
          if (ganador == nombre) {
            terminar();
          } else {
            fallo(nombre, const ErrorIA('Gemini devolvió una respuesta vacía. Intentá de nuevo.'));
          }
        },
        cancelOnError: true,
      );
      programarSiguiente();
    };

    salida.onListen = () {
      reiniciarPlazo();
      lanzar();
    };
    salida.onCancel = () => terminar();
    return salida.stream;
  }

  /// Errores que justifican pasar al siguiente modelo (inexistente, retirado,
  /// saturado o sin respuesta); los demás (cuota, App Check, red) se informan.
  @visibleForTesting
  static bool debeProbarOtroModelo(Object error) {
    if (error is ErrorIA) return false;
    if (error is TimeoutException) return true;
    final m = error.toString().toLowerCase();
    return ErrorIA._mencionaNivelRazonamiento(m) ||
        m.contains('high demand') ||
        m.contains('overloaded') ||
        m.contains('unavailable') ||
        m.contains('internal error') ||
        m.contains('not found') ||
        m.contains('not_found') ||
        m.contains('is not supported') ||
        m.contains('no longer available') ||
        m.contains('deprecated') ||
        m.contains('retired');
  }

  /// Reescribe un apunte informal en versión formal (IV.6.3.3): el mismo contenido,
  /// sin agregar secciones, títulos, datos ni conclusiones. Cada evento del flujo
  /// es el texto acumulado hasta el momento.
  Stream<String> formalizarApunte(String apunte) {
    final prompt = '''
Reescribe el siguiente apunte en español formal y técnico.

Reglas:
- Conserva exactamente la información del apunte: los mismos hechos, valores y unidades, en el mismo orden.
- No agregues nada que no esté en el apunte: ni títulos, secciones, fechas, autor, causas, conclusiones, recomendaciones ni próximos pasos.
- Corrige la ortografía, completa las palabras abreviadas y usa redacción impersonal o en primera persona del plural.
- Responde solo con el texto reescrito, en texto plano, sin Markdown ni comillas.

APUNTE:
${apunte.trim()}''';
    return _generar([Content.text(prompt)], instrucciones: _instruccionesBitacora);
  }
}
