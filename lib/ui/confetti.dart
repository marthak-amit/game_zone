import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Fire this to rain confetti, stars and hearts from the top of the screen.
class ConfettiController {
  _ConfettiState? _state;
  void fire({double seconds = 1.6, double density = 1}) => _state?._fire(seconds, density);
}

class _Bit {
  double x, y, vx, vy, rot, vrot;
  final double size, sway, phase;
  final int shape; // 0 rect, 1 circle, 2 star, 3 heart
  final Color color;
  _Bit(this.x, this.y, this.vx, this.vy, this.rot, this.vrot, this.size, this.sway, this.phase, this.shape, this.color);
}

/// Full-screen, touch-transparent celebration overlay.
class Confetti extends StatefulWidget {
  final ConfettiController controller;
  const Confetti({super.key, required this.controller});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  final _bits = <_Bit>[];
  final _rnd = Random();
  final _repaint = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _emitLeft = 0, _density = 1, _carry = 0, _t = 0;
  Size _size = const Size(400, 800);

  static const _colors = [
    Color(0xFFFF5D8F), Color(0xFFFFC145), Color(0xFF5BE7A9), Color(0xFF5CC8FF),
    Color(0xFFB388FF), Color(0xFFFFFFFF), Color(0xFFFF8A5B),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _ticker = createTicker(_tick);
  }

  @override
  void dispose() {
    widget.controller._state = null;
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _fire(double seconds, double density) {
    _emitLeft = max(_emitLeft, seconds);
    _density = density;
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration d) {
    final dt = _last == Duration.zero ? 0.016 : ((d - _last).inMicroseconds / 1e6).clamp(0.0, .05);
    _last = d;
    _t += dt;
    if (_emitLeft > 0) {
      _emitLeft -= dt;
      _carry += dt * 70 * _density;
      while (_carry >= 1) {
        _carry -= 1;
        _bits.add(_Bit(
          _rnd.nextDouble() * _size.width,
          -8,
          (_rnd.nextDouble() - .5) * 40,
          360 + _rnd.nextDouble() * 320, // fast fall (px/s)
          _rnd.nextDouble() * 6.28,
          (_rnd.nextDouble() - .5) * 14,
          3 + _rnd.nextDouble() * 3.5, // small pieces
          6 + _rnd.nextDouble() * 12,
          _rnd.nextDouble() * 6.28,
          _rnd.nextInt(4),
          _colors[_rnd.nextInt(_colors.length)],
        ));
      }
    }
    for (final b in _bits) {
      b.y += b.vy * dt;
      b.x += (b.vx + sin(_t * 2.2 + b.phase) * b.sway) * dt;
      b.rot += b.vrot * dt;
    }
    _bits.removeWhere((b) => b.y > _size.height + 20);
    _repaint.value++;
    if (_bits.isEmpty && _emitLeft <= 0) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: LayoutBuilder(builder: (context, c) {
          _size = Size(c.maxWidth, c.maxHeight);
          return CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_bits, _repaint));
        }),
      );
}

class _ConfettiPainter extends CustomPainter {
  final List<_Bit> bits;
  _ConfettiPainter(this.bits, Listenable l) : super(repaint: l);

  static Path _star(double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * .45;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  static Path _heart(double r) => Path()
    ..moveTo(0, r * .9)
    ..cubicTo(-r * 1.6, -r * .2, -r * .5, -r * 1.3, 0, -r * .35)
    ..cubicTo(r * .5, -r * 1.3, r * 1.6, -r * .2, 0, r * .9);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final b in bits) {
      p.color = b.color;
      canvas.save();
      canvas.translate(b.x, b.y);
      canvas.rotate(b.rot);
      switch (b.shape) {
        case 0:
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * .55), p);
        case 1:
          canvas.drawCircle(Offset.zero, b.size * .4, p);
        case 2:
          p.color = const Color(0xFFFFE066);
          canvas.drawPath(_star(b.size * .8), p);
        default:
          p.color = const Color(0xFFFF6B9A);
          canvas.drawPath(_heart(b.size * .5), p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}
