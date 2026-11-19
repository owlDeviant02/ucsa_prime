import 'package:flutter_test/flutter_test.dart';
import 'package:ucsa_prime/utils/fechas.dart';

void main() {
  final ahora = DateTime(2026, 11, 13, 15, 0);

  test('formatos fijos', () {
    final f = DateTime(2025, 1, 5, 9, 7);
    expect(formatearFecha(f), '05/01/2025');
    expect(formatearHora(f), '09:07');
    expect(formatearFechaHora(f), '05/01/2025 09:07');
    expect(fechaCorta(f), '5 ene');
    expect(fechaLarga(DateTime(2026, 11, 13)), 'viernes 13 de noviembre de 2026');
  });

  test('tiempo relativo', () {
    expect(haceCuanto(ahora.subtract(const Duration(seconds: 20)), ahora: ahora), 'recién');
    expect(haceCuanto(ahora.subtract(const Duration(minutes: 5)), ahora: ahora), 'hace 5 min');
    expect(haceCuanto(ahora.subtract(const Duration(hours: 3)), ahora: ahora), 'hace 3 h');
    expect(haceCuanto(DateTime(2026, 11, 12, 18, 30), ahora: ahora), 'ayer 18:30');
    expect(haceCuanto(DateTime(2026, 11, 10, 8), ahora: ahora), 'hace 3 días');
    expect(haceCuanto(DateTime(2026, 10, 1), ahora: ahora), '01/10/2026');
  });

  test('vencimientos', () {
    expect(describirVencimiento(DateTime(2026, 11, 13, 18), ahora: ahora), 'Vence hoy');
    expect(describirVencimiento(DateTime(2026, 11, 14, 18), ahora: ahora), 'Vence mañana');
    expect(describirVencimiento(DateTime(2026, 11, 16, 18), ahora: ahora), 'Vence en 3 días');
    expect(describirVencimiento(DateTime(2026, 11, 12, 18), ahora: ahora), 'Venció ayer');
    expect(describirVencimiento(DateTime(2026, 11, 10, 18), ahora: ahora), 'Venció hace 3 días');
  });

  test('lectura tolerante de fechas guardadas en Firebase', () {
    expect(leerFecha('2025-01-15T14:30:00Z')!.toUtc(), DateTime.utc(2025, 1, 15, 14, 30));
    expect(leerFecha(0), DateTime.fromMillisecondsSinceEpoch(0));
    expect(leerFecha('no es fecha'), isNull);
    expect(leerFecha(null), isNull);
    expect(fechaIso(DateTime.utc(2025, 1, 15, 14, 30)), '2025-01-15T14:30:00.000Z');
  });
}
