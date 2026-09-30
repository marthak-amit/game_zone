import 'dart:math';
import 'package:flutter/material.dart';
import '../services/app_services.dart';
import '../store.dart';
import 'confetti.dart';
import 'widgets.dart';

/// Daily lucky wheel: one free spin per day, plus up to 3 extra spins for watching an ad.
class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});
  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  final confetti = ConfettiController();
  double _from = 0, _to = 0;
  int _lastSeg = -1;
  bool spinning = false;
  int? won;
  static const seg = 2 * pi / 8;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      final s = (angle / seg).floor();
      if (s != _lastSeg) {
        _lastSeg = s;
        if (spinning) app.audio.beep(900, .03);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get angle => _from + (_to - _from) * Curves.easeOutCubic.transform(_c.value);

  Future<void> _spin({required bool free}) async {
    if (spinning) return;
    if (!free) {
      if (!await app.rewarded(context, 'extra_spin') || !mounted) return;
    }
    final prize = app.store.rollSpin();
    // Segment i is centred at angle i*seg from the top; rotate so that segment ends under the pointer.
    final cur = angle % (2 * pi);
    final target = (-(prize * seg)) % (2 * pi);
    var delta = (target - cur) % (2 * pi);
    if (delta < 0) delta += 2 * pi;
    setState(() {
      spinning = true;
      won = null;
      _from = angle;
      _to = _from + 5 * 2 * pi + delta;
    });
    _c.forward(from: 0);
    await Future.delayed(_c.duration!);
    if (!mounted) return;
    app.store.finishSpin(prize, free: free);
    final coins = Store.spinPrizes[prize];
    app.audio.fanfare();
    app.audio.voice.say(coins >= 250 ? 'Jackpot! $coins coins' : '$coins coins', force: true);
    if (coins >= 100) confetti.fire(seconds: coins >= 250 ? 5 : 2.5, density: coins >= 250 ? 2 : 1);
    setState(() {
      spinning = false;
      won = coins;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      SubScreen(
        title: 'Lucky Wheel',
        child: ListenableBuilder(
          listenable: app.store,
          builder: (context, _) {
            final s = app.store;
            final free = s.freeSpinAvailable;
            return ListView(padding: const EdgeInsets.all(16), children: [
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  width: 300,
                  height: 320,
                  child: Stack(alignment: Alignment.topCenter, children: [
                    Positioned(
                      top: 20,
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (_, _) => Transform.rotate(angle: angle, child: SizedBox(width: 290, height: 290, child: CustomPaint(painter: _WheelPainter()))),
                      ),
                    ),
                    const Positioned(top: 0, child: Icon(Icons.arrow_drop_down, size: 54, color: Colors.white, shadows: [Shadow(blurRadius: 8, color: Colors.black87)])),
                  ]),
                ),
              ),
              Center(
                child: SizedBox(
                  height: 34,
                  child: Text(won != null ? '🎉 You won $won coins!' : (spinning ? 'Good luck…' : (free ? 'Your free daily spin is ready!' : 'Come back tomorrow for a free spin')),
                      key: const Key('spinMsg'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
              Center(child: BigButton(free ? '🎡  SPIN (free)' : '🎡  SPIN', free && !spinning ? () => _spin(free: true) : null, color: kGreen)),
              Center(
                child: BigButton(
                  s.adSpinsToday >= Store.maxAdSpins ? 'No more extra spins today' : '📺 Extra spin (${Store.maxAdSpins - s.adSpinsToday} left)',
                  spinning || free || s.adSpinsToday >= Store.maxAdSpins ? null : () => _spin(free: false),
                  color: kGold,
                  textColor: Colors.black,
                ),
              ),
              if (free) const Center(child: Text('Use your free spin first', style: TextStyle(color: Colors.white70, fontSize: 12))),
            ]);
          },
        ),
      ),
      Positioned.fill(child: Confetti(controller: confetti)),
    ]);
  }
}

class _WheelPainter extends CustomPainter {
  static const _colors = [Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF06B6D4), Color(0xFFF97316)];
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width / 2 - 4;
    const seg = 2 * pi / 8;
    canvas.drawCircle(c, r + 4, Paint()..color = Colors.white);
    for (var i = 0; i < 8; i++) {
      // segment i centred at angle (i*seg) measured from the top, clockwise
      final start = -pi / 2 + i * seg - seg / 2;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, seg, true, Paint()..color = _colors[i]);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, seg, true, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * seg);
      final tp = TextPainter(
        text: TextSpan(text: '🪙${Store.spinPrizes[i]}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(blurRadius: 3, color: Colors.black54)])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -r + 20));
      canvas.restore();
    }
    canvas.drawCircle(c, 26, Paint()..color = Colors.white);
    canvas.drawCircle(c, 20, Paint()..color = const Color(0xFF1F2937));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
