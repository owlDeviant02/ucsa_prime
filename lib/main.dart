/// Punto de entrada de UCSA Prime 3.0, la aplicación de gestión del equipo de
/// robótica UCSA Prime (VEX U).
///
/// Fija la orientación vertical, inicializa Firebase (App Check y persistencia
/// offline de Realtime Database) mediante `FirebaseService` y lanza el widget
/// raíz `UcsaPrimeApp` (lib/app.dart), que monta las vistas de la capa MVVM.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ucsa_prime/app.dart';
import 'package:ucsa_prime/services/firebase_service.dart';

/// Inicializa los servicios de la plataforma y arranca la aplicación.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]));
  // Firebase, App Check y persistencia offline. Si algo falla, la aplicación
  // arranca igual y la pantalla de ingreso muestra el motivo en lugar de cerrarse.
  await FirebaseService.inicializar();
  runApp(const UcsaPrimeApp());
}
