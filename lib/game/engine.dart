import 'dart:math';
import 'package:flutter/painting.dart';
import '../store.dart';

enum DropResult { none, perfect, good, miss }

class Block {
  double x, w;
  final int i;
  Block(this.x, this.w, this.i);
}

class FallingPiece {
  final double x, w;
  final int i;
  double dy = 0, vy = 0;
  FallingPiece(this.x, this.w, this.i);
}

class Particle {
  double x, y, vx, vy;
  int life = 30;
  final bool big;
  Particle(this.x, this.y, this.vx, this.vy, this.big);
}

class Popup {
  final double x;
  final int i;
  final String text;
  int life = 45;
  Popup(this.x, this.i, this.text);
}

/// Pure game logic, independent of Flutter widgets (unit-testable).
class GameEngine {
  static const double blockH = 28, baseInset = 140, startWidth = 200, perfectTol = 5;

  final Random rnd;
  GameEngine({Random? rnd}) : rnd = rnd ?? Random();

  double width = 360, height = 640;
  List<Block> blocks = [];
  late Block cur;
  int score = 0, combo = 0, runCoins = 0, runPerfects = 0;
  double speed = 2.4, camY = 0;
  int dir = 1;
  bool over = false, vip = false;
  final falling = <FallingPiece>[];
  final particles = <Particle>[];
  final popups = <Popup>[];

  void reset(double w, double h, {bool isVip = false}) {
    width = w;
    height = h;
    vip = isVip;
    blocks = [Block((w - startWidth) / 2, startWidth, 0)];
    score = combo = runCoins = runPerfects = 0;
    speed = 2.4;
    camY = 0;
    dir = 1;
    over = false;
    falling.clear();
    particles.clear();
    popups.clear();
    _spawn();
  }

  Block get top => blocks.last;

  void _spawn() {
    cur = Block(dir > 0 ? -top.w : width, top.w, blocks.length);
  }

  /// Re-spawn after a revive (keeps the tower).
  void revive() {
    over = false;
    _spawn();
  }

  double yOf(int i) => height - baseInset - (i + 1) * blockH + camY;

  /// Advance the simulation by [f] frames (1.0 == one 60fps frame).
  void update(double f, {bool moving = true}) {
    final target = max(0, blocks.length - 6) * blockH;
    camY += (target - camY) * min(1.0, 0.1 * f);
    if (moving && !over) {
      cur.x += speed * dir * f;
      if (cur.x > width) {
        dir = -1;
      } else if (cur.x < -cur.w - 1) {
        dir = 1;
      }
    }
    for (final p in falling) {
      p.vy += 0.6 * f;
      p.dy += p.vy * f;
    }
    falling.removeWhere((p) => p.dy > height);
    for (final p in particles) {
      p.life -= 1;
      p.x += p.vx * f;
      p.y += p.vy * f;
      p.vy += 0.2 * f;
    }
    particles.removeWhere((p) => p.life <= 0);
    for (final p in popups) {
      p.life -= 1;
    }
    popups.removeWhere((p) => p.life <= 0);
  }

  DropResult drop() {
    if (over) return DropResult.none;
    final l = max(cur.x, top.x), r = min(cur.x + cur.w, top.x + top.w), ov = r - l;
    if (ov <= 0) {
      falling.add(FallingPiece(cur.x, cur.w, cur.i));
      over = true;
      return DropResult.miss;
    }
    final perfect = (cur.x - top.x).abs() < perfectTol;
    if (perfect) {
      combo++;
      runPerfects++;
      cur.x = top.x;
      cur.w = top.w;
      if (combo >= 3) cur.w = min(cur.w + 8, 220);
      _burst(cur.x + cur.w / 2, true);
      popups.add(Popup(cur.x + cur.w / 2, cur.i, combo >= 2 ? 'PERFECT x$combo' : 'PERFECT'));
    } else {
      combo = 0;
      if (cur.x < l) falling.add(FallingPiece(cur.x, l - cur.x, cur.i));
      if (cur.x + cur.w > r) falling.add(FallingPiece(r, cur.x + cur.w - r, cur.i));
      _burst(cur.x + cur.w / 2, false);
      cur.x = l;
      cur.w = ov;
    }
    blocks.add(cur);
    score++;
    runCoins += (perfect ? 2 : 1) * (vip ? 2 : 1);
    speed = min(2.4 + score * 0.06, 7);
    dir = -dir;
    _spawn();
    return perfect ? DropResult.perfect : DropResult.good;
  }

  void _burst(double x, bool big) {
    final y = yOf(blocks.length);
    for (var k = 0; k < (big ? 18 : 6); k++) {
      particles.add(Particle(x, y, (rnd.nextDouble() - .5) * 5, -rnd.nextDouble() * 4, big));
    }
  }

  static Color colorFor(Skin s, int i) =>
      HSLColor.fromAHSL(1, (s.hue + i * s.step) % 360, .8, .58).toColor();
}
