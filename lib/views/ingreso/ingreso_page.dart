/// Pantalla de presentación e ingreso (vista del patrón MVVM).
///
/// Sobre el fondo institucional animado muestra el logo y la tarjeta de
/// ingreso. `SesionController` valida el usuario y la contraseña contra la base
/// de datos (la app no usa Firebase Authentication; ver «Limitaciones» en el
/// README). Después del primer ingreso con contraseña, la app ofrece activar el
/// ingreso con huella (`HuellaService`): las credenciales quedan cifradas solo
/// en el teléfono. Si Firebase no pudo iniciarse, la tarjeta muestra el motivo
/// en lugar de cerrar la app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ucsa_prime/app.dart';
import 'package:ucsa_prime/controllers/sesion_controller.dart';
import 'package:ucsa_prime/services/avisos.dart';
import 'package:ucsa_prime/services/firebase_service.dart';
import 'package:ucsa_prime/services/huella_service.dart';
import 'package:ucsa_prime/ui/componentes.dart';
import 'package:ucsa_prime/ui/fondo_ucsa.dart';
import 'package:ucsa_prime/ui/tema.dart';
import 'package:ucsa_prime/views/inicio/inicio_page.dart';

/// Presentación + ingreso. La animación de entrada dura menos de 1 s (antes:
/// 1 s de espera + 3 s hasta mostrar el formulario).
class IngresoPage extends StatefulWidget {
  const IngresoPage({super.key});

  @override
  State<IngresoPage> createState() => _IngresoPageState();
}

class _IngresoPageState extends State<IngresoPage> with SingleTickerProviderStateMixin {
  late final AnimationController _entrada =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..forward();
  late final Animation<double> _logo =
      CurvedAnimation(parent: _entrada, curve: const Interval(0, 0.55, curve: Curves.easeOutBack));
  late final Animation<double> _formulario =
      CurvedAnimation(parent: _entrada, curve: const Interval(0.4, 1, curve: Curves.easeOutCubic));
  late final Animation<double> _opacidadLogo = _entrada.drive(CurveTween(curve: const Interval(0, 0.4)));
  late final Animation<double> _escalaLogo = Tween<double>(begin: 0.7, end: 1).animate(_logo);
  late final Animation<Offset> _desplazamientoFormulario =
      Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(_formulario);
  bool _precargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Con "reducir movimiento" activado en el sistema se omite la animación de entrada.
    if (MediaQuery.disableAnimationsOf(context) && _entrada.value < 1) _entrada.value = 1;
    if (!_precargado) {
      _precargado = true;
      // Las imágenes del inicio quedan decodificadas mientras el usuario ingresa.
      precacheImage(imagenReducida('assets/robots/jordan.png', ancho: 900), context);
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: blueUcsa,
        body: FondoUcsa(
          animado: true,
          child: SafeArea(
            child: LayoutBuilder(
              // El Scaffold ya reduce el cuerpo cuando aparece el teclado.
              builder: (context, restricciones) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Espacio.margen, vertical: Espacio.m),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: restricciones.maxHeight - 2 * Espacio.m),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: _opacidadLogo,
                        child: ScaleTransition(
                          scale: _escalaLogo,
                          child: Image.asset('assets/logo.png', height: 120, gaplessPlayback: true),
                        ),
                      ),
                      const SizedBox(height: Espacio.l),
                      FadeTransition(
                        opacity: _formulario,
                        child: SlideTransition(
                          position: _desplazamientoFormulario,
                          child: const _TarjetaIngreso(),
                        ),
                      ),
                      const SizedBox(height: Espacio.l),
                      Text(
                        'VEX Robotics Competition',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: Espacio.xxs),
                      Text(
                        'UCSA Prime · Versión $versionApp',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ColoresUcsa.textoSobreAzul),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca con el formulario de ingreso y el acceso con huella.
class _TarjetaIngreso extends StatefulWidget {
  const _TarjetaIngreso();

  @override
  State<_TarjetaIngreso> createState() => _TarjetaIngresoState();
}

class _TarjetaIngresoState extends State<_TarjetaIngreso> {
  final _formulario = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  final _focoClave = FocusNode();
  bool _ocultarClave = true;

  /// Ingreso con huella: disponible en el dispositivo y usuario que la activó aquí.
  bool _huellaDisponible = false;
  String? _usuarioHuella;

  final SesionController _sesion = SesionController.instancia;

  @override
  void initState() {
    super.initState();
    _cargarHuella();
  }

  Future<void> _cargarHuella() async {
    final disponible = await HuellaService.disponible();
    final usuario = disponible ? await HuellaService.usuarioGuardado() : null;
    if (!mounted) return;
    setState(() {
      _huellaDisponible = disponible;
      _usuarioHuella = usuario;
    });
    // Si ya está activada, se pide la huella directamente al abrir la app.
    if (usuario != null && FirebaseService.errorInicio == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ingresarConHuella());
    }
  }

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    _focoClave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    FocusScope.of(context).unfocus();
    if (_sesion.estado.verificando) return;
    if (!(_formulario.currentState?.validate() ?? false)) return;
    final usuario = _usuario.text.trim();
    final clave = _clave.text;
    final correcto = await _sesion.iniciarSesion(usuario, clave);
    if (!correcto || !mounted) return;
    _clave.clear();
    if (_huellaDisponible && _usuarioHuella != usuario) {
      await _ofrecerHuella(usuario, clave);
      if (!mounted) return;
    }
    await _abrirInicio();
  }

  Future<void> _abrirInicio() => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const InicioPage()),
      );

  /// Después de ingresar con contraseña: ofrece activar el ingreso con huella.
  Future<void> _ofrecerHuella(String usuario, String clave) async {
    final activar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.fingerprint_rounded, color: blueUcsa, size: 40),
        title: const Text('¿Ingresar con huella?'),
        content: const Text(
          'La próxima vez vas a poder entrar con tu huella. La contraseña queda cifrada '
          'solo en este teléfono y no se guarda en ninguna cuenta.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Ahora no')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Activar')),
        ],
      ),
    );
    if (activar != true) return;
    if (await HuellaService.activar(usuario, clave)) {
      _usuarioHuella = usuario;
      Avisos.publicar(const Aviso('Ingreso con huella activado'));
    }
  }

  Future<void> _ingresarConHuella() async {
    if (_sesion.estado.verificando) return;
    final credenciales = await HuellaService.ingresar();
    if (credenciales == null || !mounted) return;
    final correcto = await _sesion.iniciarSesion(credenciales.usuario, credenciales.clave);
    if (!mounted) return;
    if (!correcto) {
      // Si la contraseña cambió, la huella guardada ya no sirve: se borra.
      if ((_sesion.estado.error ?? '').contains('Contraseña incorrecta') ||
          (_sesion.estado.error ?? '').contains('no existe')) {
        await _quitarHuella();
      }
      return;
    }
    await _abrirInicio();
  }

  Future<void> _quitarHuella() async {
    await HuellaService.desactivar();
    if (!mounted) return;
    setState(() => _usuarioHuella = null);
  }

  void _olvideClave() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_reset_rounded, color: blueUcsa),
        title: const Text('Recuperar acceso'),
        content: const Text(
          'Las cuentas del equipo las administra el encargado de la base de datos. '
          'Pedile que restablezca tu contraseña.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final errorInicio = FirebaseService.errorInicio;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ColoresUcsa.superficie,
          borderRadius: BorderRadius.circular(Radios.extra + 4),
          boxShadow: [BoxShadow(color: ColoresUcsa.texto.withAlpha(45), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Espacio.l, Espacio.l, Espacio.l, Espacio.m),
          child: Form(
            key: _formulario,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('UCSA PRIME',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.headlineMedium?.copyWith(color: blueUcsa, letterSpacing: 1)),
                  Text('Portal de miembros',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.titleSmall?.copyWith(color: ColoresUcsa.textoSuave)),
                  const SizedBox(height: Espacio.l),
                  if (errorInicio != null) ...[
                    _AvisoError(describirErrorFirebase(errorInicio)),
                    const SizedBox(height: Espacio.m),
                  ],
                  TextFormField(
                    controller: _usuario,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    validator: SesionController.validarUsuario,
                    onChanged: (_) => _sesion.limpiarError(),
                    onFieldSubmitted: (_) => _focoClave.requestFocus(),
                  ),
                  const SizedBox(height: Espacio.m),
                  TextFormField(
                    controller: _clave,
                    focusNode: _focoClave,
                    obscureText: _ocultarClave,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        tooltip: _ocultarClave ? 'Mostrar contraseña' : 'Ocultar contraseña',
                        icon: Icon(_ocultarClave ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _ocultarClave = !_ocultarClave),
                      ),
                    ),
                    validator: SesionController.validarClave,
                    onChanged: (_) => _sesion.limpiarError(),
                    onFieldSubmitted: (_) => _ingresar(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _olvideClave, child: const Text('¿Olvidaste tu contraseña?')),
                  ),
                  VistaReactiva<EstadoSesion>(
                    viewModel: _sesion,
                    builder: (context, estado) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: estado.error == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(bottom: Espacio.s),
                                  child: _AvisoError(estado.error!),
                                ),
                        ),
                        FilledButton(
                          onPressed: (errorInicio != null || estado.verificando) ? null : _ingresar,
                          child: estado.verificando
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                    ),
                                    SizedBox(width: Espacio.s),
                                    Text('Verificando…'),
                                  ],
                                )
                              : const Text('Ingresar'),
                        ),
                        if (_huellaDisponible && _usuarioHuella != null) ...[
                          const SizedBox(height: Espacio.s),
                          OutlinedButton.icon(
                            onPressed: estado.verificando ? null : _ingresarConHuella,
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: const Text('Ingresar con huella'),
                          ),
                          // Acción secundaria: en gris, para no confundirla con el ingreso.
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: ColoresUcsa.textoSuave),
                            onPressed: estado.verificando ? null : _quitarHuella,
                            child: const Text('Quitar la huella de este teléfono'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
          ),
        ),
      ),
    );
  }
}

/// Mensaje de error del ingreso (credenciales incorrectas, Firebase no disponible…).
class _AvisoError extends StatelessWidget {
  const _AvisoError(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) =>
      RecuadroAviso(icono: Icons.error_outline_rounded, color: ColoresUcsa.peligro, mensaje: mensaje);
}
