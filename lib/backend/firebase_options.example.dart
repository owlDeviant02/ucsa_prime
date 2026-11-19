// PLANTILLA SIN CREDENCIALES. El archivo real, `firebase_options.dart`, NO se publica:
// se genera con `flutterfire configure --out=lib/backend/firebase_options.dart`
// o se copia esta plantilla con ese nombre y se completan los valores del proyecto.
// ignore_for_file: type=lint

/// Plantilla de la configuración de Firebase de la aplicación (sin credenciales).
///
/// `FirebaseService` (lib/services/firebase_service.dart) importa el archivo real,
/// `lib/backend/firebase_options.dart`, para inicializar Firebase y obtener la URL
/// de Realtime Database. Ese archivo es local y está excluido del repositorio;
/// esta plantilla solo muestra su estructura con valores de relleno. La aplicación
/// está configurada únicamente para Android.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// [FirebaseOptions] predeterminadas de la aplicación, por plataforma.
///
/// Ejemplo de uso:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  /// Opciones de la plataforma en ejecución. Solo Android está configurado; en
  /// las demás plataformas se lanza [UnsupportedError].
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Configuración de Android. Reemplazar cada valor de relleno por el del
  /// proyecto de Firebase propio (nunca publicar los valores reales).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TU_API_KEY',
    appId: 'TU_APP_ID',
    messagingSenderId: 'TU_SENDER_ID',
    projectId: 'tu-proyecto',
    databaseURL: 'https://tu-proyecto-default-rtdb.firebaseio.com',
    storageBucket: 'tu-proyecto.firebasestorage.app',
  );
}
