/// Formato de fechas en español sin dependencias externas (no se usa `intl`
/// para mantener la aplicación liviana).
///
/// Reúne los formatos que muestran las vistas (fecha, hora, texto relativo y
/// vencimientos) y la conversión de fechas hacia y desde Firebase: los modelos
/// guardan las fechas como texto ISO 8601 en UTC ([fechaIso]) y las leen en hora
/// local con [leerFecha].
library;

const List<String> _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', //
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
const List<String> _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic', //
];
const List<String> _dias = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo', //
];

String _dos(int n) => n.toString().padLeft(2, '0');

/// 13/11/2026
String formatearFecha(DateTime f) => '${_dos(f.day)}/${_dos(f.month)}/${f.year}';

/// 14:05
String formatearHora(DateTime f) => '${_dos(f.hour)}:${_dos(f.minute)}';

/// 13/11/2026 14:05
String formatearFechaHora(DateTime f) => '${formatearFecha(f)} ${formatearHora(f)}';

/// 13 nov
String fechaCorta(DateTime f) => '${f.day} ${_mesesCortos[f.month - 1]}';

/// jueves 13 de noviembre de 2026
String fechaLarga(DateTime f) => '${_dias[f.weekday - 1]} ${f.day} de ${_meses[f.month - 1]} de ${f.year}';

/// Medianoche local del día de [f].
DateTime soloFecha(DateTime f) => DateTime(f.year, f.month, f.day);

/// Días de calendario entre [desde] y [hasta] (redondeado: tolera cambios de horario).
int diasEntre(DateTime desde, DateTime hasta) =>
    (soloFecha(hasta).difference(soloFecha(desde)).inHours / 24).round();

/// Texto relativo: "recién", "hace 5 min", "hace 2 h", "ayer 18:30", "hace 3 días".
String haceCuanto(DateTime fecha, {DateTime? ahora}) {
  final referencia = ahora ?? DateTime.now();
  final diferencia = referencia.difference(fecha);
  // Tolera pequeñas diferencias de reloj entre dispositivos.
  if (diferencia.inSeconds < 60 && diferencia.inMinutes > -5) return 'recién';
  if (diferencia.isNegative) return formatearFechaHora(fecha);
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
  final dias = diasEntre(fecha, referencia);
  if (dias == 0) return 'hace ${diferencia.inHours} h';
  if (dias == 1) return 'ayer ${formatearHora(fecha)}';
  if (dias < 7) return 'hace $dias días';
  return formatearFecha(fecha);
}

/// Descripción del vencimiento de una tarea: "Vence hoy", "Venció hace 2 días"…
String describirVencimiento(DateTime vence, {DateTime? ahora}) {
  final dias = diasEntre(ahora ?? DateTime.now(), vence);
  if (dias < -1) return 'Venció hace ${-dias} días';
  if (dias == -1) return 'Venció ayer';
  if (dias == 0) return 'Vence hoy';
  if (dias == 1) return 'Vence mañana';
  if (dias < 7) return 'Vence en $dias días';
  return 'Vence el ${fechaCorta(vence)}';
}

/// Lee una fecha guardada en Firebase (ISO 8601 o milisegundos) en hora local.
DateTime? leerFecha(Object? valor) {
  if (valor is String && valor.isNotEmpty) return DateTime.tryParse(valor)?.toLocal();
  if (valor is int) return DateTime.fromMillisecondsSinceEpoch(valor);
  if (valor is double) return DateTime.fromMillisecondsSinceEpoch(valor.round());
  return null;
}

/// Fecha en formato ISO 8601 UTC (p. ej. 2025-01-15T14:30:00.000Z), como en la tesis.
String fechaIso(DateTime fecha) => fecha.toUtc().toIso8601String();

/// Primera letra en mayúscula.
String capitalizar(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
