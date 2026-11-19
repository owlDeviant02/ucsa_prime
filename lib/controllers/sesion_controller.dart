/// Sesión del integrante e ingreso a la aplicación (capa ViewModel del patrón MVVM).
///
/// [SesionController] es un singleton que consume `IngresoPage` y consultan los
/// demás controladores para saber quién hace cada cambio. El ingreso NO usa
/// Firebase Authentication: la cuenta se valida contra su nodo en Realtime
/// Database (limitación declarada de esta versión). El archivo también define
/// [entradaActividad], que todos los módulos usan para dejar su traza en el nodo
/// `actividad`.
library;

import 'dart:async';

// firebase_core 4.15+ también exporta una interfaz `FirebaseService`.
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:firebase_database/firebase_database.dart';
import 'package:ucsa_prime/controllers/view_model.dart';
import 'package:ucsa_prime/models/actividad.dart';
import 'package:ucsa_prime/models/json.dart';
import 'package:ucsa_prime/models/usuario.dart';
import 'package:ucsa_prime/services/avisos.dart';
import 'package:ucsa_prime/services/firebase_service.dart';
import 'package:ucsa_prime/utils/fechas.dart';

/// Estado de la sesión: integrante con sesión iniciada (o `null`), si se está
/// verificando la cuenta y el último error de ingreso.
class EstadoSesion {
  const EstadoSesion({this.usuario, this.verificando = false, this.error});

  final Usuario? usuario;
  final bool verificando;
  final String? error;
}

/// Sesión del integrante (ViewModel de la pantalla de ingreso).
///
/// Mantiene el mecanismo de cuentas de la versión anterior: cada cuenta es un
/// nodo `/{usuario}` en la raíz con los campos `name` y `password`. A diferencia
/// de la versión 2.0, que descargaba la base COMPLETA para validar un usuario, solo
/// se lee el nodo de ese usuario.
class SesionController extends ViewModel<EstadoSesion> {
  SesionController._() : super(const EstadoSesion());

  /// Instancia única, compartida por toda la aplicación.
  static final SesionController instancia = SesionController._();

  /// Integrante con sesión iniciada, o `null` si no hay sesión.
  Usuario? get usuario => estado.usuario;

  /// Nombre que se registra como responsable de cada cambio ('Invitado' sin sesión).
  String get nombreUsuario => usuario?.nombre ?? 'Invitado';

  /// Caracteres que Firebase no admite en una clave de nodo.
  static final RegExp _caracteresInvalidos = RegExp(r'[.#$\[\]/]');

  /// Validador del campo de usuario: devuelve el mensaje de error o `null`.
  static String? validarUsuario(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Ingresá tu usuario';
    if (texto.length > 64) return 'El usuario es demasiado largo';
    if (_caracteresInvalidos.hasMatch(texto) || texto == Rutas.raiz) {
      return 'El usuario contiene caracteres no válidos';
    }
    return null;
  }

  /// Validador del campo de contraseña: devuelve el mensaje de error o `null`.
  static String? validarClave(String? valor) {
    if (valor == null || valor.isEmpty) return 'Ingresá tu contraseña';
    return null;
  }

  /// Valida la cuenta contra su nodo en la base y, si es correcta, inicia la
  /// sesión, activa la sincronización local (`keepSynced`) y publica el perfil.
  /// Devuelve si el ingreso tuvo éxito; el motivo de un fallo queda en el estado.
  Future<bool> iniciarSesion(String usuarioId, String clave) async {
    final id = usuarioId.trim();
    if (!FirebaseService.disponible) {
      emitir(EstadoSesion(
        error: 'Firebase no está disponible: ${describirErrorFirebase(FirebaseService.errorInicio ?? 'sin inicializar')}',
      ));
      return false;
    }
    emitir(const EstadoSesion(verificando: true));
    try {
      final datos = await _leerCuenta(id);
      if (datos == null) {
        emitir(const EstadoSesion(error: 'El usuario ingresado no existe.'));
        return false;
      }
      if (datos['password']?.toString() != clave) {
        emitir(const EstadoSesion(error: 'Contraseña incorrecta, intentá de nuevo.'));
        return false;
      }
      final usuario = Usuario(
        id: id,
        nombre: comoTexto(datos['name'] ?? datos['nombre'], id),
        rol: datos['rol']?.toString(),
      );
      emitir(EstadoSesion(usuario: usuario));
      FirebaseService.mantenerSincronizado(true);
      _publicarPerfil(usuario);
      return true;
    } catch (e) {
      emitir(EstadoSesion(error: describirErrorFirebase(e)));
      return false;
    }
  }

  /// Lee solo el nodo del usuario. Si el servidor no responde, intenta con la
  /// caché local de la persistencia offline (ingreso sin conexión).
  Future<Map<String, dynamic>?> _leerCuenta(String id) async {
    final referencia = FirebaseService.ref(id);
    DataSnapshot instantanea;
    try {
      instantanea = await referencia.get().timeout(const Duration(seconds: 10));
    } catch (errorServidor) {
      if (errorServidor is FirebaseException && errorServidor.code == 'permission-denied') rethrow;
      try {
        instantanea = (await referencia.once().timeout(const Duration(seconds: 3))).snapshot;
      } catch (_) {
        throw errorServidor;
      }
    }
    if (!instantanea.exists || instantanea.value is! Map) return null;
    return comoMapa(instantanea.value);
  }

  /// Perfil público en `usuarios/{id}` (nombre y último acceso, sin contraseña):
  /// alimenta la lista de responsables al asignar tareas.
  void _publicarPerfil(Usuario usuario) {
    final perfil = usuario.toPerfilJson(fechaIso(DateTime.now()));
    sincronizarEnSegundoPlano(
      FirebaseService.ref('${Rutas.usuarios}/${usuario.id}').update(perfil),
      accion: 'No se pudo actualizar tu perfil',
    );
  }

  /// Cierra la sesión y desactiva la sincronización local de los módulos.
  void cerrarSesion() {
    FirebaseService.mantenerSincronizado(false);
    emitir(const EstadoSesion());
  }

  /// Quita el mensaje de error del estado, si lo hay.
  void limpiarError() {
    if (estado.error != null) emitir(EstadoSesion(usuario: estado.usuario));
  }
}

/// Entrada del registro de actividad para incluirla en una escritura multiruta
/// (la clave es relativa a [Rutas.raiz]): la operación y su traza se guardan
/// de forma atómica.
Map<String, Object?> entradaActividad(TipoActividad tipo, String descripcion) {
  final clave = FirebaseService.nuevaClave(Rutas.actividad);
  final actividad = Actividad(
    id: clave,
    tipo: tipo,
    descripcion: descripcion,
    usuario: SesionController.instancia.nombreUsuario,
    fecha: DateTime.now(),
  );
  return {'actividad/$clave': actividad.toJson()};
}
