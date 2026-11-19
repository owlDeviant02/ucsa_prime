// Ingreso con huella digital (capa de servicios).
//
// Lo usa la pantalla de ingreso (IngresoPage) para activar, usar y desactivar
// el ingreso rápido. Tras verificar la huella con local_auth, entrega las
// credenciales guardadas, que la vista envía a SesionController como en un
// ingreso normal. Las credenciales se guardan cifradas solo en el teléfono
// (flutter_secure_storage); nunca se suben a la nube.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// Credenciales guardadas para el ingreso con huella.
typedef CredencialesHuella = ({String usuario, String clave});

/// Ingreso con huella digital.
///
/// Las credenciales se guardan cifradas SOLO en este dispositivo (almacén seguro de
/// Android, con claves en el Keystore), nunca en la nube ni en el gestor de
/// contraseñas de Google, y solo se leen después de que la huella se verifica.
abstract final class HuellaService {
  static const FlutterSecureStorage _almacen = FlutterSecureStorage();
  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _kUsuario = 'huella_usuario';
  static const String _kClave = 'huella_clave';

  static const List<AndroidAuthMessages> _mensajes = [
    AndroidAuthMessages(
      signInTitle: 'Ingreso con huella',
      biometricHint: 'Tocá el sensor de huellas',
      biometricNotRecognized: 'Huella no reconocida. Intentá de nuevo.',
      biometricSuccess: 'Huella verificada',
      biometricRequiredTitle: 'Se necesita una huella',
      cancelButton: 'Usar contraseña',
      goToSettingsButton: 'Ir a Ajustes',
      goToSettingsDescription: 'Registrá una huella en los Ajustes del teléfono para usar esta función.',
    ),
  ];

  /// El dispositivo tiene sensor y al menos una huella registrada.
  static Future<bool> disponible() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Usuario con huella activada en este dispositivo (null si no hay).
  static Future<String?> usuarioGuardado() async {
    try {
      return await _almacen.read(key: _kUsuario);
    } catch (_) {
      return null;
    }
  }

  /// Pide la huella. Devuelve true si se verificó.
  static Future<bool> verificar(String motivo) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        authMessages: _mensajes,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } on PlatformException catch (e) {
      debugPrint('Huella: ${e.code} ${e.message}');
      return false;
    }
  }

  /// Activa el ingreso con huella para [usuario] (después de verificar la huella).
  static Future<bool> activar(String usuario, String clave) async {
    if (!await verificar('Confirmá tu huella para activar el ingreso rápido')) return false;
    await _almacen.write(key: _kUsuario, value: usuario);
    await _almacen.write(key: _kClave, value: clave);
    return true;
  }

  /// Verifica la huella y devuelve las credenciales guardadas.
  static Future<CredencialesHuella?> ingresar() async {
    final usuario = await usuarioGuardado();
    if (usuario == null) return null;
    if (!await verificar('Usá tu huella para ingresar a UCSA Prime')) return null;
    final clave = await _almacen.read(key: _kClave);
    if (clave == null) return null;
    return (usuario: usuario, clave: clave);
  }

  /// Borra las credenciales guardadas de este dispositivo.
  static Future<void> desactivar() async {
    try {
      await _almacen.delete(key: _kUsuario);
      await _almacen.delete(key: _kClave);
    } catch (_) {}
  }
}
