import 'dart:math';
import 'package:flutter/painting.dart';
import '../store.dart';
import 'worlds.dart';

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

/// Expanding ring shown on a perfect drop.
class Ring {
  final double x;
  final int i;
  int life = 24;
  Ring(this.x, this.i);
}

/// Pure game logic, independent of Flutter widgets (unit-testable).
class GameEngine {
  static const double blockH = 28, baseInset = 140, startWidth = 200, perfectTol = 5;
  static const int blocksPerWorld = 12, feverCombo = 5;

  final Random rnd;
  GameEngine({Random? rnd}) : rnd = rnd ?? Random();

  double width = 360, height = 640;
  List<Block> blocks = [];
  late Block cur;
  int score = 0, combo = 0, maxCombo = 0, runCoins = 0, runPerfects = 0;
  double speed = 2.0, camY = 0, elapsed = 0, worldPos = 0, shake = 0;
  int dir = 1;
  bool over = false, vip = false;
  int? fixedWorld;
  String? banner;
  int bannerLife = 0;
  final falling = <FallingPiece>[];
  final particles = <Particle>[];
  final popups = <Popup>[];
  final rings = <Ring>[];

  bool get fever => combo >= feverCombo;

  // Difficulty curve: speed rises smoothly with both score and time played.
  static const double _base = 2.0, _cap = 6.5, _scoreK = .045, _timeK = .008;
  void _recalcSpeed() => speed = min(_cap, _base + score * _scoreK + elapsed * _timeK);

  void reset(double w, double h, {bool isVip = false, int? fixedWorld}) {
    width = w;
    height = h;
    vip = isVip;
    this.fixedWorld = fixedWorld;
    blocks = [Block((w - startWidth) / 2, startWidth, 0)];
    score = combo = maxCombo = runCoins = runPerfects = 0;
    elapsed = 0;
    camY = 0;
    shake = 0;
    dir = 1;
    over = false;
    banner = null;
    bannerLife = 0;
    worldPos = (fixedWorld ?? 0).toDouble();
    falling.clear();
    particles.clear();
    popups.clear();
    rings.clear();
    _recalcSpeed();
    _spawn();
  }

  Block get top => blocks.last;

  void _spawn() {
    cur = Block(dir > 0 ? -top.w : width, top.w, blocks.length);
  }

  /// Continue after losing (rewarded ad): keeps the tower.
  void revive() {
    over = false;
    _spawn();
  }

  double yOf(int i) => height - baseInset - (i + 1) * blockH + camY;

  WorldState get worldState => WorldState.at(worldPos);
  String get worldName => worlds[worldPos.round() % worlds.length].name;

  /// Advance the simulation by [f] frames (1.0 == one 60fps frame).
  void update(double f, {bool moving = true}) {
    final target = max(0, blocks.length - 6) * blockH;
    camY += (target - camY) * min(1.0, 0.1 * f);
    final wt = fixedWorld?.toDouble() ?? score / blocksPerWorld;
    worldPos += (wt - worldPos) * min(1.0, 0.03 * f);
    if (moving && !over) {
      elapsed += f / 60;
      _recalcSpeed();
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
    for (final r in rings) {
      r.life -= 1;
    }
    rings.removeWhere((r) => r.life <= 0);
    if (bannerLife > 0) bannerLife--;
    shake = max(0, shake - .6 * f);
  }

  DropResult drop() {
    if (over) return DropResult.none;
    final l = max(cur.x, top.x), r = min(cur.x + cur.w, top.x + top.w), ov = r - l;
    if (ov <= 0) {
      falling.add(FallingPiece(cur.x, cur.w, cur.i));
      combo = 0;
      shake = 9;
      over = true;
      return DropResult.miss;
    }
    final perfect = (cur.x - top.x).abs() < perfectTol;
    if (perfect) {
      combo++;
      maxCombo = max(maxCombo, combo);
      runPerfects++;
      cur.x = top.x;
      cur.w = top.w;
      if (combo >= 3) cur.w = min(cur.w + 8, 220);
      _burst(cur.x + cur.w / 2, true);
      rings.add(Ring(cur.x + cur.w / 2, cur.i));
      popups.add(Popup(cur.x + cur.w / 2, cur.i, fever ? 'FEVER x$combo' : (combo >= 2 ? 'PERFECT x$combo' : 'PERFECT')));
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
    runCoins += (perfect ? 2 : 1) * (vip ? 2 : 1) * (fever ? 2 : 1);
    _recalcSpeed();
    _milestone();
    dir = -dir;
    _spawn();
    return perfect ? DropResult.perfect : DropResult.good;
  }

  void _milestone() {
    const marks = {10: 'Nice!', 25: 'Great!', 50: 'Amazing!', 100: 'Legendary!'};
    if (fixedWorld == null && score % blocksPerWorld == 0) {
      banner = worlds[(score ~/ blocksPerWorld) % worlds.length].name;
      bannerLife = 150;
    } else if (marks.containsKey(score)) {
      banner = marks[score];
      bannerLife = 110;
    }
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
