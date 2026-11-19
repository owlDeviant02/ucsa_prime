/// Acceso centralizado a Firebase (capa de servicios).
///
/// Define las rutas de Realtime Database ([Rutas]), inicializa Firebase, App
/// Check y la persistencia offline al arrancar (lo llama `main`), mantiene los
/// nodos principales sincronizados en la caché local (`keepSynced`) y traduce
/// los errores a mensajes en español. Los controladores obtienen aquí sus
/// referencias a la base; las vistas nunca acceden a Firebase directamente.
library;

import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:ucsa_prime/backend/firebase_options.dart';

/// Rutas de Firebase Realtime Database, según la estructura jerárquica del
/// apartado IV.6.2.1 de la tesis (`ucsa-prime-robotics/{inventario,tareas,…}`).
abstract final class Rutas {
  /// Nodo raíz de los datos de la aplicación; las escrituras multiruta usan
  /// claves relativas a él.
  static const String raiz = 'ucsa-prime-robotics';
  static const String inventario = '$raiz/inventario';
  static const String movimientos = '$raiz/inventario_movimientos';
  static const String tareas = '$raiz/tareas';
  static const String bitacoras = '$raiz/bitacoras';
  static const String checklists = '$raiz/checklists';
  static const String usuarios = '$raiz/usuarios';
  static const String actividad = '$raiz/actividad';

  /// Nodos que se mantienen sincronizados en la caché local (`keepSynced`).
  static const List<String> sincronizadas = [inventario, tareas, bitacoras];
}

/// Inicialización y acceso centralizado a Firebase.
abstract final class FirebaseService {
  /// URL de Realtime Database, tomada de la configuración local de Firebase
  /// (`lib/backend/firebase_options.dart`, generada con `flutterfire configure`
  /// y excluida del repositorio).
  static String get urlBaseDatos => DefaultFirebaseOptions.currentPlatform.databaseURL!;

  /// Proveedor de App Check: `--dart-define=APP_CHECK=debug` o `playIntegrity`.
  /// Por defecto: depuración en compilaciones debug/profile y Play Integrity en release.
  static const String _proveedorAppCheck = String.fromEnvironment('APP_CHECK');

  /// Opcional: token de depuración generado en la consola de Firebase (App Check →
  /// Administrar tokens de depuración) con `--dart-define=APP_CHECK_DEBUG_TOKEN=…`.
  /// Así no hace falta buscar en logcat el token que genera el dispositivo.
  static const String _tokenDepuracionAppCheck = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

  static bool _inicializado = false;
  static bool _appCheckActivo = false;
  static Object? _errorInicio;

  /// Firebase quedó inicializado y la base de datos puede usarse.
  static bool get disponible => _inicializado;

  /// App Check se activó correctamente (lo requiere Gemini).
  static bool get appCheckActivo => _appCheckActivo;

  /// Error de la inicialización, si la hubo (se muestra en la pantalla de ingreso).
  static Object? get errorInicio => _errorInicio;

  /// Instancia de Realtime Database de la aplicación.
  static FirebaseDatabase get db =>
      FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: urlBaseDatos);

  /// Referencia a una ruta de la base (normalmente una constante de [Rutas]).
  static DatabaseReference ref(String ruta) => db.ref(ruta);

  /// Clave única y cronológica generada localmente con `push()` (no requiere red).
  static String nuevaClave(String ruta) => ref(ruta).push().key!;

  /// Inicializa Firebase, App Check y la persistencia offline. Nunca lanza:
  /// si algo falla, la interfaz muestra [errorInicio] en lugar de cerrarse.
  static Future<void> inicializar() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
          .timeout(const Duration(seconds: 15));
      _inicializado = true;
    } catch (e) {
      _errorInicio = e;
      debugPrint('Firebase no se pudo inicializar: $e');
      return;
    }
    // La persistencia debe configurarse antes de cualquier otro uso de la base.
    _configurarPersistencia();
    await _activarAppCheck();
  }

  /// Caché en disco de Realtime Database (hasta 20 MB): la aplicación sigue
  /// funcionando sin conexión y las escrituras quedan en cola hasta reconectar.
  /// Solo existe en Android/iOS; en web no se llama (el SDK web no la soporta).
  static void _configurarPersistencia() {
    if (kIsWeb) return;
    try {
      db.setPersistenceEnabled(true);
      db.setPersistenceCacheSizeBytes(20 * 1024 * 1024);
    } catch (e) {
      debugPrint('Persistencia offline no disponible: $e');
    }
  }

  /// App Check es obligatorio para Firebase AI Logic (Gemini) en este proyecto.
  /// firebase_ai 4.x usa automáticamente esta instancia en cada solicitud.
  /// Usa el proveedor de depuración o Play Integrity según [_proveedorAppCheck].
  static Future<void> _activarAppCheck() async {
    if (kIsWeb) return; // En web requeriría un proveedor reCAPTCHA no configurado.
    final token = _tokenDepuracionAppCheck.isEmpty ? null : _tokenDepuracionAppCheck;
    final usarDepuracion = _proveedorAppCheck == 'debug' ||
        (_proveedorAppCheck.isEmpty && (token != null || !kReleaseMode));
    try {
      await FirebaseAppCheck.instance
          .activate(
            providerAndroid: usarDepuracion
                ? AndroidDebugProvider(debugToken: token)
                : const AndroidPlayIntegrityProvider(),
            providerApple: usarDepuracion
                ? AppleDebugProvider(debugToken: token)
                : const AppleDeviceCheckProvider(),
          )
          .timeout(const Duration(seconds: 8));
      _appCheckActivo = true;
    } catch (e) {
      debugPrint('App Check no se pudo activar: $e');
    }
  }

  /// `keepSynced` sobre inventario, tareas y bitácoras: con [activo] en `true`
  /// (al iniciar sesión) el SDK los mantiene actualizados en la caché local
  /// aunque ninguna pantalla los esté mostrando; con `false` (al cerrarla) deja
  /// de hacerlo.
  static void mantenerSincronizado(bool activo) {
    if (!_inicializado || kIsWeb) return;
    for (final ruta in Rutas.sincronizadas) {
      try {
        unawaited(ref(ruta).keepSynced(activo).catchError((Object e) {
          debugPrint('keepSynced($ruta) falló: $e');
        }));
      } catch (e) {
        debugPrint('keepSynced($ruta) no disponible: $e');
      }
    }
  }

  /// Estado de la conexión con el servidor (`.info/connected`); sin Firebase
  /// inicializado, emite `false`.
  static Stream<bool> conexion() {
    if (!_inicializado) return Stream<bool>.value(false);
    return ref('.info/connected').onValue.map((e) => e.snapshot.value == true).distinct();
  }
}

/// Traduce errores de Firebase a mensajes claros en español.
String describirErrorFirebase(Object error) {
  if (error is TimeoutException) {
    return 'Firebase no respondió a tiempo. Revisá la conexión a internet; si el problema '
        'persiste, verificá en la consola de Firebase que Realtime Database esté activa.';
  }
  if (error is FirebaseException) {
    final mensaje = (error.message ?? '').toLowerCase();
    if (error.code == 'permission-denied' || mensaje.contains('permission')) {
      return 'Permiso denegado por las reglas de seguridad de Firebase.';
    }
    if (mensaje.contains('deactivated')) {
      return 'La base de datos de Firebase está desactivada. Reactivala desde la consola de Firebase.';
    }
    if (error.code == 'disconnected' || error.code == 'network-error' || mensaje.contains('offline')) {
      return 'Sin conexión con Firebase. Los cambios se sincronizarán al reconectar.';
    }
    return 'Error de Firebase (${error.code})${error.message != null ? ': ${error.message}' : ''}';
  }
  if (error is UnsupportedError) {
    // firebase_options.dart solo tiene configuración para Android.
    return 'Firebase no está configurado para esta plataforma. Usá la aplicación en Android.';
  }
  return 'Error inesperado: $error';
}
