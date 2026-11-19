/// Avisos globales para el usuario (capa de servicios).
///
/// Permite que los controladores informen el resultado de una operación sin
/// depender de la interfaz: publican un [Aviso] en [Avisos] y el componente raíz
/// de lib/ui lo muestra como SnackBar. Incluye [sincronizarEnSegundoPlano], que
/// lanza escrituras a Firebase sin bloquear la pantalla y avisa si fallan.
library;

import 'dart:async';

import 'package:ucsa_prime/services/firebase_service.dart';

/// Mensaje breve para el usuario (se muestra como SnackBar desde la raíz de la app).
class Aviso {
  const Aviso(this.mensaje, {this.esError = false});
  final String mensaje;
  final bool esError;
}

/// Canal global de avisos: los controladores (ViewModels) informan resultados de
/// escrituras en segundo plano sin depender de widgets ni de un BuildContext.
abstract final class Avisos {
  static final StreamController<Aviso> _canal = StreamController<Aviso>.broadcast();

  /// Flujo de avisos que escucha la interfaz.
  static Stream<Aviso> get flujo => _canal.stream;

  /// Publica un aviso para que la interfaz lo muestre.
  static void publicar(Aviso aviso) => _canal.add(aviso);
}

/// Lanza una escritura sin bloquear la interfaz. Con la persistencia activa el SDK
/// aplica el cambio localmente al instante y lo envía al servidor cuando hay
/// conexión, por lo que esperar el `Future` congelaría la pantalla sin red.
/// Si el servidor rechaza la escritura (p. ej., reglas), se avisa al usuario.
void sincronizarEnSegundoPlano(Future<void> escritura, {required String accion}) {
  unawaited(escritura.catchError((Object error) {
    Avisos.publicar(Aviso('$accion: ${describirErrorFirebase(error)}', esError: true));
  }));
}
