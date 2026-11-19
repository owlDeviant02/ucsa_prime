/// Raíz de la aplicación: `MaterialApp` con el tema institucional, idioma
/// español, el oyente global de avisos y la pantalla de ingreso como inicio.
///
/// El tema (`construirTema`, en `ui/tema.dart`) se construye una sola vez. El
/// tamaño de letra del sistema se limita a 1,3× para que la interfaz no se
/// desarme en teléfonos con letra muy grande.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ucsa_prime/ui/componentes.dart';
import 'package:ucsa_prime/ui/tema.dart';
import 'package:ucsa_prime/views/ingreso/ingreso_page.dart';

/// Versión visible en el ingreso y en «Acerca de la aplicación».
const String versionApp = '3.0.0';

/// Widget raíz de UCSA Prime.
class UcsaPrimeApp extends StatelessWidget {
  const UcsaPrimeApp({super.key});

  /// El tema se construye una sola vez (no en cada reconstrucción de la raíz).
  static final ThemeData _tema = construirTema();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UCSA Prime',
      debugShowCheckedModeBanner: false,
      theme: _tema,
      scaffoldMessengerKey: mensajeroGlobal,
      // Selector de fechas, menús de texto y tooltips en español.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => OyenteAvisos(
        // Evita que un tamaño de letra del sistema muy grande desarme la interfaz.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const IngresoPage(),
    );
  }
}
