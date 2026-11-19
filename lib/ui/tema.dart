/// Sistema visual de la aplicación: paleta, escala de espaciados, radios de
/// borde, tipografía y el `ThemeData` de Material 3.
///
/// Todas las vistas toman de aquí sus colores y medidas: ningún color ni radio
/// se escribe «a mano» en una pantalla. Los estilos de botones, tarjetas,
/// campos de texto, chips, diálogos y hojas inferiores se definen una sola vez
/// en [construirTema], de modo que basta con usar los widgets de Material para
/// que respeten la identidad del equipo. Las piezas compartidas que no cubre el
/// tema (etiquetas, avisos, buscadores…) están en `componentes.dart`.
library;

import 'package:flutter/material.dart';

/// Tipografía de la identidad del equipo (títulos, etiquetas y botones).
const String ucsaFont = 'Rajdhani';

// -----------------------------------------------------------------------------
// Paleta institucional
// -----------------------------------------------------------------------------

/// Blanco cálido institucional (malla del fondo animado).
const Color whiteUcsa = Color(0xFFF5F7FA);

/// Blanco azulado institucional.
const Color whiteBlue = Color(0xFFF0F8FF);

/// Azul de marca de UCSA Prime: color primario de toda la aplicación.
const Color blueUcsa = Color(0xFF364CE4);

/// Azul más claro que acompaña al de marca en los degradados.
const Color blueAlt = Color(0xFF4666FF);

/// Naranja institucional del logo.
const Color redUcsa = Color(0xFFF6511D);

/// Negro de la marca: color del texto principal.
const Color blackUcsa = Color(0xFF0A0A0B);

/// Colores semánticos y de cada módulo.
///
/// Los colores que se usan como texto o ícono sobre blanco tienen un contraste
/// de al menos 4,5:1 (nivel AA de las pautas WCAG). El checklist es violeta y la
/// bitácora, ámbar, como describe el apartado IV.6.5; como el ámbar es demasiado
/// claro para escribir sobre blanco, la bitácora tiene además un tono oscuro
/// ([bitacoraTexto]) para textos e íconos.
abstract final class ColoresUcsa {
  // Superficies y texto.
  /// Fondo de las pantallas (gris azulado muy claro).
  static const Color fondo = Color(0xFFF3F5FB);

  /// Superficie de tarjetas, campos y diálogos.
  static const Color superficie = Colors.white;

  /// Borde de tarjetas, campos y divisores.
  static const Color borde = Color(0xFFE3E7F1);

  /// Texto principal.
  static const Color texto = blackUcsa;

  /// Texto secundario (descripciones, fechas, ayudas).
  static const Color textoSuave = Color(0xFF5B6275);

  /// Celeste suave del azul de marca (botones tonales, contenedores).
  static const Color azulSuave = Color(0xFFE4E8FC);

  // Estados.
  /// Correcto, completo o stock suficiente.
  static const Color exito = Color(0xFF0F8040);

  /// Advertencia: stock bajo, vencimiento próximo, checklist incompleto.
  static const Color alerta = Color(0xFFAD5A00);

  /// Error, acción destructiva, agotado o vencido.
  static const Color peligro = Color(0xFFD13438);

  // Módulos.
  /// Inventario (verde azulado).
  static const Color inventario = Color(0xFF0E7C86);

  /// Tareas (azul de marca).
  static const Color tareas = blueUcsa;

  /// Checklist pre-partido (violeta).
  static const Color checklist = Color(0xFF6D3FE0);

  /// Bitácora (ámbar): para rellenos, con texto [texto] encima.
  static const Color bitacora = Color(0xFFF2A100);

  /// Ámbar oscuro de la bitácora para textos e íconos sobre blanco.
  static const Color bitacoraTexto = Color(0xFF9A6200);

  /// Funciones con inteligencia artificial (Gemini).
  static const Color ia = Color(0xFF8A3FD1);

  // Sobre el degradado azul de la cabecera del inicio.
  /// Indicador «En línea» sobre fondo azul.
  static const Color enLineaSobreAzul = Color(0xFF7CF5B5);

  /// Indicador «Sin conexión» sobre fondo azul.
  static const Color sinConexionSobreAzul = Color(0xFFFFD27A);

  /// Texto secundario sobre fondo azul.
  static const Color textoSobreAzul = Color(0xDDFFFFFF);
}

/// Degradado institucional (cabecera del inicio, fondo del ingreso, ícono).
const LinearGradient degradadoUcsa = LinearGradient(
  colors: [blueAlt, blueUcsa],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Franja bajo la barra de estado del inicio: continúa el borde superior de
/// [degradadoUcsa] para que la cabecera no se vea cortada al desplazarse.
const LinearGradient degradadoBarraEstado = LinearGradient(colors: [blueAlt, Color(0xFF3D57EF)]);

/// Tono suave de un color para fondos de íconos, etiquetas y avisos.
Color tonoSuave(Color color, {int alfa = 26}) => color.withAlpha(alfa);

// -----------------------------------------------------------------------------
// Medidas
// -----------------------------------------------------------------------------

/// Escala de espaciados (múltiplos de 4). Toda separación de la interfaz usa
/// uno de estos valores.
abstract final class Espacio {
  static const double xxs = 4;
  static const double xs = 8;
  static const double s = 12;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;

  /// Margen lateral de las pantallas.
  static const double margen = m;

  /// Espacio libre al final de una lista con botón flotante, para que el
  /// último elemento no quede tapado.
  static const double finConBotonFlotante = 96;

  /// Relleno interno de las tarjetas.
  static const EdgeInsets tarjeta = EdgeInsets.all(m);

  // Los rellenos de listas y hojas inferiores dependen de la barra de
  // navegación del sistema: ver `rellenoLista` y `rellenoHoja` en
  // `componentes.dart`.
}

/// Radios de borde de la interfaz.
abstract final class Radios {
  /// Etiquetas e indicadores pequeños.
  static const double chico = 8;

  /// Campos de texto, botones, chips y cajas de íconos.
  static const double medio = 12;

  /// Tarjetas y filas pulsables.
  static const double grande = 16;

  /// Diálogos, hojas inferiores, tarjetas destacadas y la cabecera del inicio.
  static const double extra = 24;
}

// -----------------------------------------------------------------------------
// Tema
// -----------------------------------------------------------------------------

/// Construye el tema Material 3 de la aplicación.
///
/// Tipografía: Rajdhani (identidad del equipo) en títulos, etiquetas y botones;
/// la fuente del sistema en el cuerpo, para lectura cómoda. Escala usada en las
/// vistas: `headlineMedium` saludo y títulos grandes, `headlineSmall` títulos de
/// hojas, `titleLarge` barra superior y diálogos, `titleMedium` encabezados de
/// sección, `titleSmall` títulos de tarjeta, `bodyMedium`/`bodySmall` textos y
/// `labelLarge`/`labelMedium`/`labelSmall` etiquetas, botones e indicadores.
ThemeData construirTema() {
  final esquema = ColorScheme.fromSeed(
    seedColor: blueUcsa,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    primary: blueUcsa,
    onPrimary: Colors.white,
    secondary: blueAlt,
    // Botones tonales (− / + del stock) y otros contenedores secundarios:
    // celeste suave con el azul de marca encima.
    secondaryContainer: ColoresUcsa.azulSuave,
    onSecondaryContainer: blueUcsa,
    surface: ColoresUcsa.superficie,
    onSurface: ColoresUcsa.texto,
    onSurfaceVariant: ColoresUcsa.textoSuave,
    outline: ColoresUcsa.borde,
    outlineVariant: ColoresUcsa.borde,
    error: ColoresUcsa.peligro,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: esquema);
  final t = base.textTheme;
  TextStyle rajdhani(TextStyle? estilo, double tamano, {double espaciado = 0}) =>
      (estilo ?? const TextStyle()).copyWith(
        fontFamily: ucsaFont,
        fontSize: tamano,
        fontWeight: FontWeight.w700,
        letterSpacing: espaciado,
        height: 1.15,
      );

  final texto = t
      .copyWith(
        displaySmall: rajdhani(t.displaySmall, 36),
        headlineLarge: rajdhani(t.headlineLarge, 32),
        headlineMedium: rajdhani(t.headlineMedium, 28),
        headlineSmall: rajdhani(t.headlineSmall, 24),
        titleLarge: rajdhani(t.titleLarge, 22),
        titleMedium: rajdhani(t.titleMedium, 19),
        titleSmall: rajdhani(t.titleSmall, 17),
        labelLarge: rajdhani(t.labelLarge, 16, espaciado: 0.3),
        labelMedium: rajdhani(t.labelMedium, 14, espaciado: 0.2),
        labelSmall: rajdhani(t.labelSmall, 13, espaciado: 0.2),
        bodyLarge: t.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: t.bodyMedium?.copyWith(height: 1.4),
        bodySmall: t.bodySmall?.copyWith(height: 1.35),
      )
      .apply(bodyColor: ColoresUcsa.texto, displayColor: ColoresUcsa.texto);

  final formaMedia = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.medio));
  const tamanoBoton = Size(64, 48);

  final bordeCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radios.medio),
    borderSide: const BorderSide(color: ColoresUcsa.borde),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    textTheme: texto,
    scaffoldBackgroundColor: ColoresUcsa.fondo,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarThemeData(
      backgroundColor: ColoresUcsa.fondo,
      foregroundColor: ColoresUcsa.texto,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleSpacing: Espacio.xxs,
      // El último ícono de las acciones no queda pegado al borde de la pantalla.
      actionsPadding: const EdgeInsets.only(right: Espacio.xxs),
      titleTextStyle: texto.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: ColoresUcsa.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radios.grande),
        side: const BorderSide(color: ColoresUcsa.borde),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: ColoresUcsa.superficie,
      contentPadding: const EdgeInsets.symmetric(horizontal: Espacio.m, vertical: 14),
      hintStyle: texto.bodyMedium?.copyWith(color: ColoresUcsa.textoSuave),
      helperStyle: texto.bodySmall?.copyWith(color: ColoresUcsa.textoSuave),
      prefixIconColor: ColoresUcsa.textoSuave,
      suffixIconColor: ColoresUcsa.textoSuave,
      border: bordeCampo,
      enabledBorder: bordeCampo,
      disabledBorder: bordeCampo,
      focusedBorder: bordeCampo.copyWith(borderSide: const BorderSide(color: blueUcsa, width: 1.6)),
      errorBorder: bordeCampo.copyWith(borderSide: const BorderSide(color: ColoresUcsa.peligro)),
      focusedErrorBorder:
          bordeCampo.copyWith(borderSide: const BorderSide(color: ColoresUcsa.peligro, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: tamanoBoton,
        padding: const EdgeInsets.symmetric(horizontal: Espacio.m),
        textStyle: texto.labelLarge,
        shape: formaMedia,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: tamanoBoton,
        padding: const EdgeInsets.symmetric(horizontal: Espacio.m),
        textStyle: texto.labelLarge,
        side: const BorderSide(color: ColoresUcsa.borde),
        backgroundColor: ColoresUcsa.superficie,
        shape: formaMedia,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: texto.labelLarge, shape: formaMedia),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        textStyle: texto.labelMedium,
        side: const BorderSide(color: ColoresUcsa.borde),
        backgroundColor: ColoresUcsa.superficie,
        selectedBackgroundColor: tonoSuave(blueUcsa, alfa: 30),
        selectedForegroundColor: blueUcsa,
        shape: formaMedia,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: blueUcsa,
      foregroundColor: Colors.white,
      extendedTextStyle: texto.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.grande)),
    ),
    // Chips de filtro y selección: el seleccionado se distingue por el fondo y
    // el borde azules (sin la marca de verificación, que tapaba el ícono).
    chipTheme: ChipThemeData(
      labelStyle: texto.labelMedium,
      secondaryLabelStyle: texto.labelMedium?.copyWith(color: blueUcsa),
      backgroundColor: ColoresUcsa.superficie,
      selectedColor: tonoSuave(blueUcsa, alfa: 30),
      showCheckmark: false,
      iconTheme: const IconThemeData(color: ColoresUcsa.textoSuave, size: 18),
      side: WidgetStateBorderSide.resolveWith(
        (estados) => BorderSide(
          color: estados.contains(WidgetState.selected) ? tonoSuave(blueUcsa, alfa: 110) : ColoresUcsa.borde,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Espacio.xxs),
      shape: formaMedia,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ColoresUcsa.texto,
      actionTextColor: ColoresUcsa.enLineaSobreAzul,
      shape: formaMedia,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ColoresUcsa.fondo,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: ColoresUcsa.borde,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radios.extra))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ColoresUcsa.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.extra)),
      titleTextStyle: texto.titleLarge,
      contentTextStyle: texto.bodyMedium?.copyWith(color: ColoresUcsa.textoSuave),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: ColoresUcsa.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radios.grande)),
    ),
    dividerTheme: const DividerThemeData(color: ColoresUcsa.borde, space: 1),
    listTileTheme: ListTileThemeData(
      iconColor: ColoresUcsa.textoSuave,
      titleTextStyle: texto.bodyLarge?.copyWith(height: 1.3),
      subtitleTextStyle: texto.bodyMedium?.copyWith(color: ColoresUcsa.textoSuave, height: 1.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: Espacio.m),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: ColoresUcsa.textoSuave,
      collapsedIconColor: ColoresUcsa.textoSuave,
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: ColoresUcsa.peligro),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: blueUcsa),
    tabBarTheme: TabBarThemeData(
      labelStyle: texto.labelLarge,
      unselectedLabelStyle: texto.labelLarge,
      labelColor: blueUcsa,
      unselectedLabelColor: ColoresUcsa.textoSuave,
      indicatorColor: blueUcsa,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: ColoresUcsa.borde,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: ColoresUcsa.texto.withAlpha(235),
        borderRadius: BorderRadius.circular(Radios.chico),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: blueUcsa,
      selectionColor: tonoSuave(blueUcsa, alfa: 50),
      selectionHandleColor: blueUcsa,
    ),
  );
}
