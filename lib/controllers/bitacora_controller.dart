/// ViewModels del módulo de bitácora técnica (capa ViewModel del patrón MVVM).
///
/// [BitacoraController] alimenta la lista de entradas (`BitacoraPage`) a partir
/// del nodo `bitacoras` de Realtime Database, con búsqueda y filtro por tipo.
/// [EditorBitacoraController] gestiona el editor (`EditorBitacoraPage`): dictado
/// por voz, reescritura formal del apunte con Gemini (que no agrega información)
/// y guardado de la entrada junto con su registro de actividad.
library;

import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:ucsa_prime/controllers/sesion_controller.dart';
import 'package:ucsa_prime/controllers/view_model.dart';
import 'package:ucsa_prime/models/actividad.dart';
import 'package:ucsa_prime/models/bitacora.dart';
import 'package:ucsa_prime/models/json.dart';
import 'package:ucsa_prime/services/dictado_service.dart';
import 'package:ucsa_prime/services/firebase_service.dart';
import 'package:ucsa_prime/services/gemini_service.dart';

/// Estado de la lista de bitácoras: todas las entradas, las visibles según los
/// filtros y los criterios de búsqueda vigentes.
class BitacoraEstado {
  const BitacoraEstado({
    this.cargando = true,
    this.error,
    this.todas = const [],
    this.visibles = const [],
    this.texto = '',
    this.tipo,
  });

  final bool cargando;
  final String? error;
  final List<EntradaBitacora> todas;
  final List<EntradaBitacora> visibles;
  final String texto;
  final TipoBitacora? tipo;

  /// Hay un texto de búsqueda o un tipo seleccionado.
  bool get filtrando => texto.trim().isNotEmpty || tipo != null;
}

/// ViewModel de la bitácora técnica (nodo `bitacoras`).
class BitacoraController extends ViewModel<BitacoraEstado> {
  BitacoraController() : super(const BitacoraEstado());

  late final DatabaseReference _bitacorasRef = FirebaseService.ref(Rutas.bitacoras);
  late final DatabaseReference _raizRef = FirebaseService.ref(Rutas.raiz);

  /// Entradas de la bitácora en tiempo real (también lo usa el inicio).
  Stream<List<EntradaBitacora>> obtenerBitacorasStream() => _bitacorasRef.onValue
      .map((evento) => EntradaBitacora.listaDesdeNodo(evento.snapshot.value));

  /// Comienza a escuchar el nodo `bitacoras`; la vista lo llama al abrirse.
  void iniciar() {
    escuchar<List<EntradaBitacora>>(
      obtenerBitacorasStream(),
      (lista) => emitir(_calcular(lista, estado.texto, estado.tipo, cargando: false)),
      alFallar: (e) => emitir(_calcular(estado.todas, estado.texto, estado.tipo,
          cargando: false, error: describirErrorFirebase(e))),
    );
  }

  /// Filtra por texto en el contenido o el autor (sin distinguir acentos).
  void buscar(String texto) => emitir(_calcular(estado.todas, texto, estado.tipo));

  /// Filtra por tipo de entrada; `null` muestra todos los tipos.
  void filtrarTipo(TipoBitacora? tipo) => emitir(_calcular(estado.todas, estado.texto, tipo));

  BitacoraEstado _calcular(
    List<EntradaBitacora> todas,
    String texto,
    TipoBitacora? tipo, {
    bool? cargando,
    String? error,
  }) {
    final consulta = normalizar(texto);
    final visibles = todas.where((e) {
      if (tipo != null && e.tipo != tipo) return false;
      if (consulta.isEmpty) return true;
      return normalizar(e.contenido).contains(consulta) || normalizar(e.autor).contains(consulta);
    }).toList(growable: false);
    return BitacoraEstado(
      cargando: cargando ?? estado.cargando,
      error: error,
      todas: todas,
      visibles: visibles,
      texto: texto,
      tipo: tipo,
    );
  }

  /// Elimina la entrada y registra la actividad en una sola escritura multiruta.
  Future<void> eliminar(EntradaBitacora entrada) {
    return _raizRef.update({
      'bitacoras/${entrada.id}': null,
      ...entradaActividad(TipoActividad.bitacora, 'Bitácora eliminada: "${entrada.titulo}"'),
    });
  }

  /// Deshace una eliminación escribiendo de nuevo la entrada tal como estaba.
  Future<void> restaurar(EntradaBitacora entrada) =>
      _bitacorasRef.child(entrada.id).set(entrada.toJson());

  /// Copia a `bitacoras/` los registros que la versión 2.0 guardaba sueltos en la
  /// raíz de la base. No borra los originales y es idempotente (ids fijos).
  Future<int> importarRegistrosAntiguos() async {
    final raiz = await FirebaseService.ref('/').get().timeout(const Duration(seconds: 20));
    final cambios = <String, Object?>{};
    for (final hijo in hijosDe(raiz.value)) {
      final entrada = EntradaBitacora.desdeRegistroAntiguo(hijo.key, hijo.value);
      if (entrada != null) cambios[entrada.id] = entrada.toJson();
    }
    if (cambios.isEmpty) return 0;
    await _bitacorasRef.update(cambios).timeout(const Duration(seconds: 20));
    return cambios.length;
  }
}

// -----------------------------------------------------------------------------
// Editor de una entrada (dictado y formalización con IA)
// -----------------------------------------------------------------------------

/// Estado del editor. El texto en sí vive en el `TextEditingController` de la vista.
class EditorBitacoraEstado {
  const EditorBitacoraEstado({
    this.tipo = TipoBitacora.prueba,
    this.generando = false,
    this.textoGenerado = '',
    this.errorIA,
    this.usaIA = false,
    this.apunteOriginal,
    this.dictando = false,
  });

  final TipoBitacora tipo;

  /// Gemini está generando la versión formal.
  final bool generando;

  /// Texto formal acumulado hasta el momento (llega en streaming).
  final String textoGenerado;

  /// Mensaje del último error de la IA, ya traducido para el usuario.
  final String? errorIA;

  /// El contenido actual proviene de una formalización con Gemini.
  final bool usaIA;

  /// Apunte informal que se reemplazó por la versión formal (se guarda con la
  /// entrada para conservar el original).
  final String? apunteOriginal;

  /// El dictado por voz está escuchando.
  final bool dictando;

  /// Copia con los campos indicados. Los campos anulables se pasan como función
  /// para poder distinguir «no cambiar» de «poner en `null`».
  EditorBitacoraEstado copiar({
    TipoBitacora? tipo,
    bool? generando,
    String? textoGenerado,
    String? Function()? errorIA,
    bool? usaIA,
    String? Function()? apunteOriginal,
    bool? dictando,
  }) {
    return EditorBitacoraEstado(
      tipo: tipo ?? this.tipo,
      generando: generando ?? this.generando,
      textoGenerado: textoGenerado ?? this.textoGenerado,
      errorIA: errorIA != null ? errorIA() : this.errorIA,
      usaIA: usaIA ?? this.usaIA,
      apunteOriginal: apunteOriginal != null ? apunteOriginal() : this.apunteOriginal,
      dictando: dictando ?? this.dictando,
    );
  }
}

/// ViewModel del editor de una entrada de bitácora. Los servicios de IA y de
/// dictado se pueden inyectar (por ejemplo, en pruebas).
class EditorBitacoraController extends ViewModel<EditorBitacoraEstado> {
  EditorBitacoraController({GeminiService? gemini, DictadoService? dictado})
      : _gemini = gemini ?? GeminiService.instancia,
        _dictado = dictado ?? DictadoService(),
        super(const EditorBitacoraEstado());

  final GeminiService _gemini;
  final DictadoService _dictado;
  StreamSubscription<String>? _generacion;
  Completer<String?>? _resultado;

  /// Cambia el tipo de la entrada que se está redactando.
  void cambiarTipo(TipoBitacora tipo) => emitir(estado.copiar(tipo: tipo));

  /// Formaliza el apunte con Gemini (reescritura formal sin agregar información);
  /// el texto llega en streaming a [estado].
  /// Devuelve el texto final o `null` si falló o se canceló.
  Future<String?> formalizar(String apunte) {
    cancelarFormalizacion();
    final resultado = _resultado = Completer<String?>();
    emitir(estado.copiar(generando: true, textoGenerado: '', errorIA: () => null));
    _generacion = _gemini
        .formalizarApunte(apunte)
        .listen(
          (texto) => emitir(estado.copiar(textoGenerado: texto)),
          onError: (Object error) {
            emitir(estado.copiar(generando: false, errorIA: () => ErrorIA.desde(error).mensaje));
            if (!resultado.isCompleted) resultado.complete(null);
          },
          onDone: () {
            emitir(estado.copiar(generando: false));
            if (!resultado.isCompleted) resultado.complete(estado.textoGenerado.trim());
          },
          cancelOnError: true,
        );
    return resultado.future;
  }

  /// Cancela la formalización en curso, si la hay; la espera de [formalizar]
  /// termina con `null`.
  void cancelarFormalizacion() {
    _generacion?.cancel();
    _generacion = null;
    final pendiente = _resultado;
    if (pendiente != null && !pendiente.isCompleted) pendiente.complete(null);
    _resultado = null;
    if (estado.generando) emitir(estado.copiar(generando: false));
  }

  /// La vista reemplazó el apunte por el texto formal (revisión del usuario).
  void aceptarTextoIA(String apunteOriginal) =>
      emitir(estado.copiar(usaIA: true, apunteOriginal: () => apunteOriginal, textoGenerado: ''));

  /// Vuelve al apunte original; devuelve el texto a restaurar.
  String? restaurarApunte() {
    final original = estado.apunteOriginal;
    emitir(estado.copiar(usaIA: false, apunteOriginal: () => null));
    return original;
  }

  // --- Dictado por voz -------------------------------------------------------

  /// Inicializa el reconocedor de voz (pide el permiso de micrófono la primera
  /// vez). Devuelve si el dictado está disponible en el dispositivo.
  Future<bool> prepararDictado(void Function(String error) alFallar) {
    return _dictado.inicializar(
      alCambiarEstado: (escuchando) => emitir(estado.copiar(dictando: escuchando)),
      alFallar: alFallar,
    );
  }

  /// Empieza a escuchar; [alReconocer] recibe el texto parcial y el final.
  Future<void> dictar(void Function(String texto, bool esFinal) alReconocer) async {
    emitir(estado.copiar(dictando: true));
    await _dictado.escuchar(alReconocer);
  }

  /// Detiene el dictado y conserva lo reconocido hasta el momento.
  Future<void> detenerDictado() async {
    await _dictado.detener();
    emitir(estado.copiar(dictando: false));
  }

  // --- Guardado ----------------------------------------------------------------

  /// Guarda la entrada (escritura multiruta con su registro de actividad). Si el
  /// contenido proviene de la IA, también se guarda el apunte original.
  Future<void> guardar(String contenido) {
    final usuario = SesionController.instancia.usuario;
    final clave = FirebaseService.nuevaClave(Rutas.bitacoras);
    final entrada = EntradaBitacora(
      id: clave,
      fecha: DateTime.now(),
      autor: usuario?.nombre ?? 'Invitado',
      autorId: usuario?.id,
      tipo: estado.tipo,
      contenido: contenido.trim(),
      generadaPorIA: estado.usaIA,
      apunteOriginal: estado.usaIA ? estado.apunteOriginal : null,
    );
    return FirebaseService.ref(Rutas.raiz).update({
      'bitacoras/$clave': entrada.toJson(),
      ...entradaActividad(
        TipoActividad.bitacora,
        'Nueva bitácora (${entrada.tipo.etiqueta}${entrada.generadaPorIA ? ', con IA' : ''})',
      ),
    });
  }

  @override
  void dispose() {
    cancelarFormalizacion();
    _dictado.cancelar();
    _dictado.liberar();
    super.dispose();
  }
}
