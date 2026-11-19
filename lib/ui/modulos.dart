/// Identidad visual de cada módulo de la aplicación (inventario, tareas,
/// checklist y bitácora) y de los datos que muestran: íconos de categorías,
/// prioridades, estados, tipos de bitácora y actividad.
///
/// Reúne en un solo lugar la relación «dato → color/ícono» para que todas las
/// pantallas (inicio, listas y detalles) muestren lo mismo de la misma forma.
/// Los colores salen de [ColoresUcsa] (`tema.dart`).
library;

import 'package:flutter/material.dart';
import 'package:ucsa_prime/models/actividad.dart';
import 'package:ucsa_prime/models/bitacora.dart';
import 'package:ucsa_prime/models/tarea.dart';
import 'package:ucsa_prime/ui/tema.dart';

/// Identidad visual de un módulo (título, color, ícono e imagen de su tarjeta).
class InfoModulo {
  const InfoModulo({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.color,
    Color? colorTexto,
    this.imagen,
  }) : colorTexto = colorTexto ?? color;

  /// Nombre visible del módulo.
  final String titulo;

  /// Frase breve que acompaña al título en la tarjeta del inicio.
  final String descripcion;

  /// Ícono del módulo (tarjetas, actividad reciente).
  final IconData icono;

  /// Color de identidad, para rellenos y fondos suaves.
  final Color color;

  /// Color para textos e íconos sobre blanco (igual a [color] salvo en la
  /// bitácora, cuyo ámbar es demasiado claro para leerse sobre blanco).
  final Color colorTexto;

  /// Imagen de fondo tenue de la tarjeta del inicio (opcional).
  final String? imagen;
}

/// Los cuatro módulos de la aplicación.
abstract final class Modulos {
  static const InfoModulo inventario = InfoModulo(
    titulo: 'Inventario',
    descripcion: 'Stock, ubicación y alertas',
    icono: Icons.inventory_2_rounded,
    color: ColoresUcsa.inventario,
  );
  static const InfoModulo tareas = InfoModulo(
    titulo: 'Tareas',
    descripcion: 'Pendientes del proyecto',
    icono: Icons.task_alt_rounded,
    color: ColoresUcsa.tareas,
    imagen: 'assets/backgrounds/tasks.png',
  );
  static const InfoModulo checklist = InfoModulo(
    titulo: 'Checklist',
    descripcion: 'Verificación antes de competir',
    icono: Icons.fact_check_rounded,
    color: ColoresUcsa.checklist,
    imagen: 'assets/backgrounds/checklist.jpg',
  );
  static const InfoModulo bitacora = InfoModulo(
    titulo: 'Bitácora',
    descripcion: 'Registro técnico con IA',
    icono: Icons.menu_book_rounded,
    color: ColoresUcsa.bitacora,
    colorTexto: ColoresUcsa.bitacoraTexto,
    imagen: 'assets/backgrounds/notebook.png',
  );
}

/// Ícono de cada categoría del inventario.
IconData iconoCategoria(String categoria) => switch (categoria) {
      'motores' => Icons.settings_suggest_rounded,
      'sensores' => Icons.sensors_rounded,
      'estructurales' => Icons.construction_rounded,
      'neumaticos' => Icons.air_rounded,
      'electronica' => Icons.memory_rounded,
      _ => Icons.category_rounded,
    };

/// Color de cada prioridad de tarea (alta = peligro, media = alerta, baja = éxito).
Color colorPrioridad(PrioridadTarea prioridad) => switch (prioridad) {
      PrioridadTarea.alta => ColoresUcsa.peligro,
      PrioridadTarea.media => ColoresUcsa.alerta,
      PrioridadTarea.baja => ColoresUcsa.exito,
    };

/// Ícono de cada columna del tablero de tareas.
IconData iconoEstado(EstadoTarea estado) => switch (estado) {
      EstadoTarea.pendiente => Icons.radio_button_unchecked_rounded,
      EstadoTarea.enProgreso => Icons.timelapse_rounded,
      EstadoTarea.completada => Icons.check_circle_rounded,
    };

/// Ícono de cada tipo de entrada de la bitácora.
IconData iconoTipoBitacora(TipoBitacora tipo) => switch (tipo) {
      TipoBitacora.prueba => Icons.science_rounded,
      TipoBitacora.diseno => Icons.architecture_rounded,
      TipoBitacora.construccion => Icons.handyman_rounded,
      TipoBitacora.programacion => Icons.code_rounded,
      TipoBitacora.competencia => Icons.emoji_events_rounded,
      TipoBitacora.reunion => Icons.groups_rounded,
      TipoBitacora.otro => Icons.notes_rounded,
    };

/// Ícono de cada tipo de actividad del registro del inicio.
IconData iconoActividad(TipoActividad tipo) => switch (tipo) {
      TipoActividad.inventario => Modulos.inventario.icono,
      TipoActividad.tarea => Modulos.tareas.icono,
      TipoActividad.bitacora => Modulos.bitacora.icono,
      TipoActividad.checklist => Modulos.checklist.icono,
      TipoActividad.sistema => Icons.bolt_rounded,
    };

/// Color de cada tipo de actividad (el de su módulo, en tono legible sobre blanco).
Color colorActividad(TipoActividad tipo) => switch (tipo) {
      TipoActividad.inventario => Modulos.inventario.colorTexto,
      TipoActividad.tarea => Modulos.tareas.colorTexto,
      TipoActividad.bitacora => Modulos.bitacora.colorTexto,
      TipoActividad.checklist => Modulos.checklist.colorTexto,
      TipoActividad.sistema => ColoresUcsa.textoSuave,
    };

/// Ícono de cada ítem del checklist (los nombres son los que definió el equipo).
IconData iconoItemChecklist(String item) {
  final nombre = item.toLowerCase();
  if (nombre.contains('bater')) return Icons.battery_charging_full_rounded;
  if (nombre.contains('aire')) return Icons.air_rounded;
  if (nombre.contains('inercial')) return Icons.explore_rounded;
  if (nombre.contains('placa')) return Icons.badge_rounded;
  if (nombre.contains('válvula') || nombre.contains('valvula')) return Icons.tune_rounded;
  if (nombre.contains('cadena')) return Icons.link_rounded;
  if (nombre.contains('tragadera') || nombre.contains('cinta')) return Icons.input_rounded;
  if (nombre.contains('brazo') || nombre.contains('elevación')) return Icons.precision_manufacturing_rounded;
  if (nombre.contains('puerto')) return Icons.cable_rounded;
  if (nombre.contains('pantalla')) return Icons.screenshot_monitor_rounded;
  if (nombre.contains('movimiento')) return Icons.open_with_rounded;
  return Icons.check_box_outline_blank_rounded;
}
