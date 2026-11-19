// Pruebas de la «carrera escalonada» de GeminiService con flujos simulados (sin red).
import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucsa_prime/services/gemini_service.dart';

GenerateContentResponse _texto(String t) => GenerateContentResponse(
      [Candidate(Content.model([TextPart(t)]), null, null, null, null)],
      null,
    );

/// Flujo que emite [partes] después de [demora] y termina.
Stream<GenerateContentResponse> _responde(Duration demora, List<String> partes) async* {
  await Future<void>.delayed(demora);
  for (final p in partes) {
    yield _texto(p);
  }
}

/// Flujo que nunca emite (conexión colgada).
Stream<GenerateContentResponse> _colgado() => StreamController<GenerateContentResponse>().stream;

void main() {
  setUp(() => GeminiService.instancia.reiniciarParaPruebas());
  tearDown(() => GeminiService.fuentePrueba = null);

  test('si el primero falla al instante (429), responde el respaldo', () async {
    GeminiService.fuentePrueba = (m) => m.contains('lite')
        ? _responde(const Duration(milliseconds: 300), ['Texto ', 'formal.'])
        : Stream.error(QuotaExceeded('Too Many Requests'));
    final r = await GeminiService.instancia.formalizarApunte('apunte').last.timeout(const Duration(seconds: 5));
    expect(r, 'Texto formal.');
  });

  test('si los primeros se cuelgan, el respaldo entra escalonado y responde', () async {
    GeminiService.fuentePrueba =
        (m) => m.contains('lite') ? _responde(const Duration(milliseconds: 500), ['Listo.']) : _colgado();
    final reloj = Stopwatch()..start();
    final r = await GeminiService.instancia.formalizarApunte('apunte').last.timeout(const Duration(seconds: 10));
    expect(r, 'Listo.');
    // 3.8 y 3 Flash colgados: Flash-Lite entra a los 5 s (dos escalones de 2,5 s).
    expect(reloj.elapsed, lessThan(const Duration(seconds: 7)));
  });

  test('si el primero responde rápido, gana el primero', () async {
    GeminiService.fuentePrueba = (m) => m.contains('lite')
        ? _responde(const Duration(seconds: 4), ['respaldo'])
        : _responde(const Duration(milliseconds: 200), [m == 'gemini-3.8-flash' ? 'principal' : 'otro']);
    final r = await GeminiService.instancia.formalizarApunte('apunte').last.timeout(const Duration(seconds: 5));
    expect(r, 'principal');
  });
}
