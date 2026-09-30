import 'dart:math';
import 'package:flutter/material.dart';
import '../config.dart';
import '../services/app_services.dart';

/// Creates a looping animation controller (it stays still in the diagnostic 'noanim' CI variant).
AnimationController loopController(TickerProvider vsync, Duration duration, {bool reverse = false, bool freeze = false}) {
  final c = AnimationController(vsync: vsync, duration: duration);
  if (!AppConfig.noLoops && !freeze) c.repeat(reverse: reverse);
  return c;
}

/// Compact icon tile used in the menu's single row of secondary actions.
class MenuTile extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  final String? badge;
  final bool wiggle;
  const MenuTile(this.icon, this.label, this.onTap, {super.key, this.badge, this.wiggle = false});
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Material(
          color: Colors.black.withValues(alpha: .38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.white.withValues(alpha: .3))),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              app.audio.click();
              onTap();
            },
            child: SizedBox(
              width: 66,
              height: 74,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                wiggle ? RepaintBoundary(child: Wiggle(child: Text(icon, style: const TextStyle(fontSize: 28)))) : Text(icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: -6,
            top: -8,
            child: RepaintBoundary(
              child: Bob(
              amplitude: 2.5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
                child: Text(badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
            ),
          ),
      ]);
}

/// Round translucent icon button for corner utilities (sound, settings).
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const RoundIconButton({super.key, required this.icon, required this.onTap, required this.tooltip});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.black.withValues(alpha: .4),
          shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: .3))),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              app.audio.click();
              onTap();
            },
            child: SizedBox(width: 46, height: 46, child: Icon(icon, size: 24, color: Colors.white)),
          ),
        ),
      );
}

/// Floats its child gently up and down.
class Bob extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;
  const Bob({super.key, required this.child, this.amplitude = 4, this.period = const Duration(milliseconds: 2600)});
  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = loopController(this, widget.period, reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(offset: Offset(0, (Curves.easeInOut.transform(_c.value) - .5) * 2 * widget.amplitude), child: child),
        child: widget.child,
      );
}

/// Swings its child left and right (a happy "look at me" wiggle), then rests.
class Wiggle extends StatefulWidget {
  final Widget child;
  const Wiggle({super.key, required this.child});
  @override
  State<Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<Wiggle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = loopController(this, const Duration(milliseconds: 1400));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = _c.value;
          final a = t < .4 ? sin(t / .4 * pi * 4) * .22 * (1 - t / .4) : 0.0;
          return Transform.rotate(angle: a, child: child);
        },
        child: widget.child,
      );
}

/// Scales + fades its child in after [delay] (used to stagger menu tiles).
class PopIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const PopIn({super.key, required this.child, this.delay = Duration.zero});
  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  static const _anim = Duration(milliseconds: 520);
  // The delay is part of the animation itself (no Timer needed): 0..delay is idle, then the pop plays.
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.delay + _anim)..value = AppConfig.noLoops ? 1 : 0;
  @override
  void initState() {
    super.initState();
    if (!AppConfig.noLoops) _c.forward();
  }

  late final double _start = widget.delay.inMilliseconds / (widget.delay + _anim).inMilliseconds;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = ((_c.value - _start) / (1 - _start)).clamp(0.0, 1.0);
          return Opacity(
            opacity: Curves.easeOut.transform(t),
            child: Transform.scale(scale: .55 + .45 * Curves.elasticOut.transform(t), child: child),
          );
        },
        child: widget.child,
      );
}

/// A gold coin that spins around its vertical axis.
class SpinningCoin extends StatefulWidget {
  final double size;
  const SpinningCoin({super.key, this.size = 22});
  @override
  State<SpinningCoin> createState() => _SpinningCoinState();
}

class _SpinningCoinState extends State<SpinningCoin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = loopController(this, const Duration(milliseconds: 1700), freeze: AppConfig.noCoin);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final a = _c.value * 2 * pi;
            final face = cos(a).abs();
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(face.clamp(.14, 1.0), 1, 1),
              child: CustomPaint(painter: _CoinPainter(shade: .5 + .5 * face)),
            );
          },
        ),
        ),
      );
}

class _CoinPainter extends CustomPainter {
  final double shade; // 1 = face-on (bright), 0 = edge-on (dark)
  _CoinPainter({required this.shade});
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2, ctr = s.center(Offset.zero);
    c.drawCircle(
        ctr,
        r,
        Paint()
          ..shader = RadialGradient(center: const Alignment(-.3, -.4), colors: [
            Color.lerp(const Color(0xFFB8860B), const Color(0xFFFFF0A0), shade)!,
            Color.lerp(const Color(0xFF8A5A00), const Color(0xFFFFC107), shade)!,
            const Color(0xFFB45309),
          ]).createShader(Rect.fromCircle(center: ctr, radius: r)));
    c.drawCircle(ctr, r * .78, Paint()..style = PaintingStyle.stroke..strokeWidth = r * .14..color = const Color(0xFFB45309).withValues(alpha: .75));
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r * .46 : r * .2;
      final ang = -pi / 2 + i * pi / 5;
      final p = ctr + Offset(cos(ang) * rr, sin(ang) * rr);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    c.drawPath(star..close(), Paint()..color = const Color(0xFFFFF6C2).withValues(alpha: .95));
  }

  @override
  bool shouldRepaint(covariant _CoinPainter old) => old.shade != shade;
}
