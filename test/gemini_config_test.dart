import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucsa_prime/services/gemini_service.dart';

void main() {
  group('Configuración de Gemini (sin red)', () {
    test('modelos: el Flash más reciente (3.8) y el respaldo rápido 3.5 Flash-Lite', () {
      expect(GeminiService.modelosCandidatos, ['gemini-3.8-flash', 'gemini-3-flash-preview', 'gemini-3.5-flash-lite']);
      // Modelos retirados o no admitidos por Firebase AI Logic.
      for (final retirado in ['gemini-2.0-flash', 'gemini-2.5-flash', 'gemini-flash-latest']) {
        expect(GeminiService.modelosCandidatos, isNot(contains(retirado)));
      }
    });

    test('razonamiento mínimo admitido por cada modelo (3.8 Flash no admite MINIMAL)', () {
      expect(GeminiService.nivelPara('gemini-3.8-flash'), ThinkingLevel.low);
      expect(GeminiService.nivelPara('gemini-3.5-flash-lite'), ThinkingLevel.minimal);
    });

    test('carrera escalonada: el respaldo entra a los 2,5 s', () {
      expect(GeminiService.escalonamiento, const Duration(milliseconds: 2500));
      expect(GeminiService.plazo, greaterThan(GeminiService.escalonamiento));
    });

    test('se pasa al siguiente modelo ante modelo inexistente, saturado o nivel no admitido', () {
      expect(
        GeminiService.debeProbarOtroModelo(
            ServerException('models/gemini-3.8-flash is not found for API version v1beta')),
        isTrue,
      );
      expect(
        GeminiService.debeProbarOtroModelo(
            ServerException('Thinking level MINIMAL is not supported for this model.')),
        isTrue,
      );
      expect(GeminiService.debeProbarOtroModelo(ServerException('Quota exceeded for requests')), isFalse);
      expect(GeminiService.debeProbarOtroModelo(const ErrorIA('vacía')), isFalse);
    });
  });

  group('ErrorIA traduce los errores al español', () {
    test('400 INVALID_ARGUMENT por el nivel de razonamiento', () {
      final error = ErrorIA.desde(ServerException(
          "Invalid value at 'generation_config.thinking_config.thinking_level' (INVALID_ARGUMENT)"));
      expect(error.mensaje, contains('nivel de razonamiento'));
    });

    test('App Check, cuota, tiempo de espera y sin modelos disponibles', () {
      expect(ErrorIA.desde(ServerException('Firebase App Check token is invalid.')).mensaje,
          contains('App Check'));
      expect(ErrorIA.desde(QuotaExceeded('Quota exceeded')).mensaje, contains('cuota'));
      expect(ErrorIA.desde(TimeoutException('lento')).mensaje, contains('a tiempo'));
      expect(ErrorIA.desde(null).mensaje, contains('Ningún modelo'));
    });
  });
}
