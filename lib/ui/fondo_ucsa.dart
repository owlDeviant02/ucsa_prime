/// Fondo institucional de la pantalla de ingreso: degradado azul de la marca
/// con una malla triangular y un brillo diagonal animado. Está optimizado para
/// no reconstruir widgets en cada cuadro (ver la documentación de [FondoUcsa]).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ucsa_prime/ui/tema.dart';

/// Fondo institucional: degradado azul con malla triangular y un brillo diagonal.
///
/// Optimización respecto de la versión 2.0: antes un `Timer` de 40 ms emitía un
/// estado nuevo del Cubit global en cada cuadro (25 reconstrucciones por segundo
/// por cada fondo montado, también el de las pantallas tapadas) y se creaban
/// ~700 `Path` por cuadro. Ahora:
///  * la animación la conduce un `AnimationController` conectado al `repaint` del
///    `CustomPainter`: no se reconstruye ningún widget, solo se repinta la capa;
///  * la capa está aislada en un `RepaintBoundary`, así que el contenido de la
///    pantalla no se repinta con el brillo;
///  * la malla es un único `Path` cacheado por tamaño y el brillo es un `Shader`
///    sobre ese mismo trazo: dos llamadas de dibujo por cuadro;
///  * el `Ticker` se detiene solo cuando la ruta queda tapada (TickerMode) y la
///    animación se desactiva si el sistema pide reducir movimientos.
class FondoUcsa extends StatefulWidget {
  const FondoUcsa({super.key, this.animado = false, this.child});

  /// Si es verdadero, un brillo recorre la malla en diagonal.
  final bool animado;

  /// Contenido que se dibuja sobre el fondo.
  final Widget? child;

  @override
  State<FondoUcsa> createState() => _FondoUcsaState();
}

class _FondoUcsaState extends State<FondoUcsa> with SingleTickerProviderStateMixin {
  late final AnimationController _brillo =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late final _PintorMalla _pintor = _PintorMalla(brillo: _brillo);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizarAnimacion();
  }

  @override
  void didUpdateWidget(FondoUcsa anterior) {
    super.didUpdateWidget(anterior);
    _actualizarAnimacion();
  }

  void _actualizarAnimacion() {
    final animar = widget.animado && !MediaQuery.disableAnimationsOf(context);
    _pintor.mostrarBrillo = animar;
    if (animar) {
      if (!_brillo.isAnimating) _brillo.repeat();
    } else if (_brillo.isAnimating || _brillo.value != 0) {
      _brillo
        ..stop()
        ..value = 0; // fuerza un último repintado sin el brillo
    }
  }

  @override
  void dispose() {
    _brillo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _pintor, isComplex: true, willChange: widget.animado),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// Pinta el degradado, la malla triangular (cacheada por tamaño) y el brillo.
class _PintorMalla extends CustomPainter {
  _PintorMalla({required this.brillo}) : super(repaint: brillo);

  final Animation<double> brillo;
  bool mostrarBrillo = false;

  static const double _lado = 24;
  Path? _malla;
  Size? _tamanoMalla;

  final Paint _pinturaMalla = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = whiteUcsa.withAlpha(26);

  final Paint _pinturaBrillo = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;

  Path _construirMalla(Size size) {
    final alto = _lado * math.sqrt(3) / 2;
    final path = Path();
    var fila = 0;
    for (double y = 0; y < size.height + alto; y += alto, fila++) {
      final desplazar = fila.isOdd;
      for (double x = -_lado; x < size.width + _lado; x += _lado) {
        final dx = desplazar ? x + _lado / 2 : x;
        path
          ..moveTo(dx, y)
          ..lineTo(dx + _lado / 2, y + alto)
          ..lineTo(dx - _lado / 2, y + alto)
          ..close();
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas.drawRect(area, Paint()..shader = degradadoUcsa.createShader(area));

    if (_tamanoMalla != size || _malla == null) {
      _malla = _construirMalla(size);
      _tamanoMalla = size;
    }
    final malla = _malla!;
    canvas.drawPath(malla, _pinturaMalla);

    if (!mostrarBrillo) return;
    // Banda de brillo que recorre la diagonal (de -0.2 a 1.2 para entrar y salir).
    final centro = -0.2 + 1.4 * brillo.value;
    _pinturaBrillo.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.transparent, whiteUcsa.withAlpha(110), Colors.transparent],
      stops: [
        (centro - 0.12).clamp(0.0, 1.0),
        centro.clamp(0.0, 1.0),
        (centro + 0.12).clamp(0.0, 1.0),
      ],
    ).createShader(area);
    canvas.drawPath(malla, _pinturaBrillo);
  }

  @override
  bool shouldRepaint(covariant _PintorMalla anterior) => !identical(anterior, this);
}
