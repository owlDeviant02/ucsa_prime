/// Clase base de todos los controladores (ViewModels) de la aplicación.
///
/// Define el contrato común de la capa ViewModel: estado inmutable expuesto como
/// `Stream`, emisión de estados nuevos y liberación ordenada de las suscripciones
/// a Firebase cuando la vista se cierra. La extienden los controladores de
/// lib/controllers.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Base de la capa ViewModel del patrón MVVM reactivo (apartado IV.6.1.2).
///
/// Cada controlador expone el estado de su pantalla como un flujo (`Stream`)
/// que la vista observa con `StreamBuilder`; la vista solo invoca intenciones
/// (métodos públicos) y nunca accede a Firebase directamente. El estado es
/// inmutable: cada cambio emite un objeto nuevo, ya calculado (filtros, conteos),
/// para que el `build` de la vista no haga trabajo pesado.
abstract class ViewModel<E> {
  ViewModel(E inicial) : _estado = inicial;

  final StreamController<E> _controlador = StreamController<E>.broadcast();
  final List<StreamSubscription<Object?>> _suscripciones = [];
  E _estado;
  bool _liberado = false;

  /// Último estado emitido (sirve como `initialData` del StreamBuilder).
  E get estado => _estado;

  /// Flujo de estados que observa la vista.
  late final Stream<E> flujo = _controlador.stream;

  /// Indica si ya se llamó a [dispose]; a partir de entonces no se emiten estados.
  bool get liberado => _liberado;

  /// Reemplaza el estado actual y lo publica en [flujo]. Se ignora si el
  /// ViewModel ya fue liberado.
  @protected
  void emitir(E nuevo) {
    if (_liberado) return;
    _estado = nuevo;
    _controlador.add(nuevo);
  }

  /// Se suscribe a un flujo de datos; la suscripción se cancela en [dispose].
  @protected
  void escuchar<T>(
    Stream<T> origen,
    void Function(T dato) alRecibir, {
    void Function(Object error)? alFallar,
  }) {
    _suscripciones.add(origen.listen(
      alRecibir,
      onError: (Object error, StackTrace _) => alFallar?.call(error),
    ));
  }

  /// Libera suscripciones y el flujo. La vista lo llama en su `dispose`.
  @mustCallSuper
  void dispose() {
    _liberado = true;
    for (final suscripcion in _suscripciones) {
      suscripcion.cancel();
    }
    _suscripciones.clear();
    _controlador.close();
  }
}
