import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/app_services.dart';
import '../services/music.dart';
import 'block_painter.dart';
import 'engine.dart';
import 'worlds.dart';

class _Star {
  final double x, y, size, phase;
  _Star(this.x, this.y, this.size, this.phase);
}

class _Cloud {
  double x;
  final double y, scale, speed;
  _Cloud(this.x, this.y, this.scale, this.speed);
}

class _Drop {
  double x, y;
  final double speed, len;
  _Drop(this.x, this.y, this.speed, this.len);
}

class _Shoot {
  double x, y, life;
  _Shoot(this.x, this.y, this.life);
}

class _Building {
  final double x, w, h;
  final int seed;
  List<Offset>? windows; // lit-window positions relative to the building's top-left (cached)
  double _winWidth = -1;
  _Building(this.x, this.w, this.h, this.seed);

  List<Offset> windowsFor(double pixelWidth) {
    if (windows == null || _winWidth != pixelWidth) {
      final r = Random(seed);
      final list = <Offset>[];
      for (var wy = 8.0; wy < h - 6; wy += 11) {
        for (var wx = 4.0; wx < pixelWidth - 6; wx += 9) {
          if (r.nextDouble() < .38) list.add(Offset(wx, wy));
        }
      }
      windows = list;
      _winWidth = pixelWidth;
    }
    return windows!;
  }
}

class _Bird {
  double x;
  final double y, speed, phase;
  _Bird(this.x, this.y, this.speed, this.phase);
}

/// Animated background: sky, celestial bodies, weather and a parallax city skyline.
class Scenery {
  final Random rnd;
  Scenery({int seed = 7}) : rnd = Random(seed) {
    for (var i = 0; i < 110; i++) {
      stars.add(_Star(rnd.nextDouble(), rnd.nextDouble() * .75, .6 + rnd.nextDouble() * 1.6, rnd.nextDouble() * 6.28));
    }
    for (var i = 0; i < 8; i++) {
      clouds.add(_Cloud(rnd.nextDouble() * 1.4 - .2, .06 + rnd.nextDouble() * .34, .6 + rnd.nextDouble() * .9, .004 + rnd.nextDouble() * .008));
    }
    for (var i = 0; i < 170; i++) {
      drops.add(_Drop(rnd.nextDouble(), rnd.nextDouble(), 1.1 + rnd.nextDouble() * .7, .025 + rnd.nextDouble() * .03));
    }
    for (var i = 0; i < 3; i++) {
      birds.add(_Bird(rnd.nextDouble(), .12 + rnd.nextDouble() * .2, .02 + rnd.nextDouble() * .02, rnd.nextDouble() * 6));
    }
    double x = -.05;
    while (x < 1.1) {
      final w = .05 + rnd.nextDouble() * .06;
      far.add(_Building(x, w, 50 + rnd.nextDouble() * 80, rnd.nextInt(1 << 20)));
      x += w * .9;
    }
    x = -.05;
    while (x < 1.1) {
      final w = .06 + rnd.nextDouble() * .07;
      near.add(_Building(x, w, 30 + rnd.nextDouble() * 70, rnd.nextInt(1 << 20)));
      x += w * .95;
    }
  }

  final stars = <_Star>[];
  final clouds = <_Cloud>[];
  final drops = <_Drop>[];
  final birds = <_Bird>[];
  final shooting = <_Shoot>[];
  final far = <_Building>[];
  final near = <_Building>[];
  double time = 0, flash = 0, nextBolt = 5, nextShoot = 3, boltX = .5;

  void update(double dt, WorldState w) {
    time += dt;
    for (final c in clouds) {
      c.x += c.speed * dt * (1 + w.rain);
      if (c.x > 1.25) c.x = -.3;
    }
    if (w.rain > .02) {
      for (final d in drops) {
        d.y += d.speed * dt;
        d.x -= .12 * dt; // slanted by a light wind
        if (d.y > 1) {
          d.y = -.05;
          d.x = rnd.nextDouble() * 1.15;
        }
        if (d.x < -.05) d.x += 1.1;
      }
    }
    for (final b in birds) {
      b.x += b.speed * dt;
      if (b.x > 1.15) b.x = -.15;
    }
    flash = max(0, flash - dt * 2.2);
    if (w.rain > .6) {
      nextBolt -= dt;
      if (nextBolt <= 0) {
        flash = 1;
        boltX = .15 + rnd.nextDouble() * .7;
        nextBolt = 4 + rnd.nextDouble() * 6;
      }
    }
    if (w.stars > .5) {
      nextShoot -= dt;
      if (nextShoot <= 0) {
        shooting.add(_Shoot(rnd.nextDouble() * .8, rnd.nextDouble() * .3, 1));
        nextShoot = 3 + rnd.nextDouble() * 6;
      }
    }
    for (final s in shooting) {
      s.life -= dt * 1.4;
      s.x += dt * .5;
      s.y += dt * .25;
    }
    shooting.removeWhere((s) => s.life <= 0);
  }

  Color _dark(Color c, double t) => Color.lerp(c, Colors.black, t)!;

  /// [groundTop] is the y of the ground surface (moves down as the camera climbs).
  void paint(Canvas c, Size s, WorldState w, double camY, {double groundTop = -1}) {
    final rect = Offset.zero & s;
    // sky
    c.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [w.top, w.bottom]).createShader(rect));

    if (w.aurora > .02) _aurora(c, s, w);
    if (w.stars > .02) _stars(c, s, w, camY);
    if (w.planet > .02) _planet(c, s, w, camY);
    if (w.sun > .02) _sun(c, s, w, camY);
    if (w.moon > .02) _moon(c, s, w, camY);
    for (final sh in shooting) {
      final a = (sh.life.clamp(0, 1)) * w.stars;
      final p1 = Offset(sh.x * s.width, sh.y * s.height);
      final p0 = p1 - Offset(70, 35);
      c.drawLine(p0, p1, Paint()
        ..shader = LinearGradient(colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: a)]).createShader(Rect.fromPoints(p0, p1))
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round);
    }
    if (w.clouds > .02) _clouds(c, s, w, camY);
    if (w.sun > .3) _birds(c, s, w, camY);

    final gt = groundTop < 0 ? s.height - GameEngine.baseInset + camY : groundTop;
    _skyline(c, s, w, far, gt, camY * .55, .35, 0.55);
    _skyline(c, s, w, near, gt, camY * .8, .55, 1.0);
    // ground
    final groundCol = _dark(Color.lerp(w.bottom, w.top, .3)!, .55);
    c.drawRect(Rect.fromLTRB(0, gt, s.width, s.height + 2), Paint()..color = groundCol);
    c.drawRect(Rect.fromLTWH(0, gt, s.width, 3), Paint()..color = Color.lerp(groundCol, Colors.white, .22)!);

    if (w.rain > .05) _fogAndRain(c, s, w, gt);
    if (flash > 0) {
      if (flash > .55) _bolt(c, s, gt);
      c.drawRect(rect, Paint()..color = Colors.white.withValues(alpha: flash * .38 * w.rain));
    }
  }

  void _stars(Canvas c, Size s, WorldState w, double camY) {
    final p = Paint();
    for (final st in stars) {
      final tw = .55 + .45 * sin(time * 1.6 + st.phase);
      p.color = Colors.white.withValues(alpha: (w.stars * tw).clamp(0, 1));
      c.drawCircle(Offset(st.x * s.width, st.y * s.height + camY * .04), st.size, p);
    }
  }

  void _sun(Canvas c, Size s, WorldState w, double camY) {
    final pos = Offset(s.width * .74, s.height * w.sunY + camY * .06);
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFFF3B0).withValues(alpha: .85 * w.sun),
        const Color(0xFFFFC46B).withValues(alpha: .25 * w.sun),
        Colors.transparent
      ], stops: const [0, .35, 1]).createShader(Rect.fromCircle(center: pos, radius: 150));
    c.drawCircle(pos, 150, glow);
    c.drawCircle(pos, 30, Paint()..color = const Color(0xFFFFF7D6).withValues(alpha: w.sun));
  }

  void _moon(Canvas c, Size s, WorldState w, double camY) {
    final pos = Offset(s.width * .25, s.height * .17 + camY * .05);
    c.drawCircle(pos, 90, Paint()
      ..shader = RadialGradient(colors: [const Color(0xFFCFE0FF).withValues(alpha: .35 * w.moon), Colors.transparent]).createShader(Rect.fromCircle(center: pos, radius: 90)));
    c.drawCircle(pos, 26, Paint()..color = const Color(0xFFF4F1E4).withValues(alpha: w.moon));
    final crater = Paint()..color = const Color(0xFFCFC9B4).withValues(alpha: .7 * w.moon);
    c.drawCircle(pos + const Offset(-8, -6), 5, crater);
    c.drawCircle(pos + const Offset(9, 5), 4, crater);
    c.drawCircle(pos + const Offset(-2, 12), 3, crater);
  }

  void _planet(Canvas c, Size s, WorldState w, double camY) {
    final pos = Offset(s.width * .72, s.height * .24 + camY * .05);
    final a = w.planet;
    c.drawCircle(pos, 44, Paint()
      ..shader = const RadialGradient(center: Alignment(-.4, -.4), colors: [Color(0xFFFFB86B), Color(0xFFB24A8E), Color(0xFF3B1A66)]).createShader(Rect.fromCircle(center: pos, radius: 44))
      ..color = Colors.white.withValues(alpha: a));
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(-.35);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 130, height: 26),
        Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = const Color(0xFFFFE0A8).withValues(alpha: .6 * a));
    c.restore();
    // small moon
    c.drawCircle(pos + const Offset(-90, 45), 9, Paint()..color = const Color(0xFFB8C4E8).withValues(alpha: .9 * a));
  }

  void _aurora(Canvas c, Size s, WorldState w) {
    for (var k = 0; k < 3; k++) {
      final path = Path();
      final base = s.height * (.18 + k * .1);
      path.moveTo(0, base);
      for (var x = 0.0; x <= s.width; x += 12) {
        path.lineTo(x, base + sin(x / 70 + time * (.5 + k * .2) + k) * 26 + sin(x / 33 + time * .9) * 8);
      }
      path.lineTo(s.width, base + 170);
      path.lineTo(0, base + 170);
      path.close();
      final col = [const Color(0xFF3DFFB0), const Color(0xFF7A6BFF), const Color(0xFF3DD5FF)][k];
      c.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
              col.withValues(alpha: .42 * w.aurora),
              col.withValues(alpha: 0)
            ]).createShader(Rect.fromLTWH(0, base - 30, s.width, 210)));
    }
  }

  void _cloud(Canvas c, Offset o, double sc, Color col, double alpha) {
    final p = Paint()..color = col.withValues(alpha: alpha);
    c.drawOval(Rect.fromCenter(center: o, width: 90 * sc, height: 30 * sc), p);
    c.drawOval(Rect.fromCenter(center: o + Offset(-22 * sc, -10 * sc), width: 50 * sc, height: 32 * sc), p);
    c.drawOval(Rect.fromCenter(center: o + Offset(14 * sc, -14 * sc), width: 56 * sc, height: 38 * sc), p);
  }

  void _clouds(Canvas c, Size s, WorldState w, double camY) {
    final col = Color.lerp(Colors.white, const Color(0xFF2F3644), w.cloudDark)!;
    for (final cl in clouds) {
      _cloud(c, Offset(cl.x * s.width, cl.y * s.height + camY * .08), cl.scale, col, (.8 * w.clouds).clamp(0, 1));
    }
  }

  void _birds(Canvas c, Size s, WorldState w, double camY) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF243B55).withValues(alpha: .7 * w.sun.clamp(0, 1));
    for (final b in birds) {
      final flap = sin(time * 7 + b.phase) * 4;
      final o = Offset(b.x * s.width, b.y * s.height + sin(time + b.phase) * 6 + camY * .08);
      final path = Path()
        ..moveTo(o.dx - 8, o.dy - flap)
        ..quadraticBezierTo(o.dx - 3, o.dy - 3 + flap * .3, o.dx, o.dy)
        ..quadraticBezierTo(o.dx + 3, o.dy - 3 + flap * .3, o.dx + 8, o.dy - flap);
      c.drawPath(path, p);
    }
  }

  void _skyline(Canvas c, Size s, WorldState w, List<_Building> list, double groundY, double shift, double tint, double lightsK) {
    final base = _dark(Color.lerp(w.bottom, w.top, .35)!, tint + .15);
    final p = Paint()..color = base;
    final win = Paint();
    for (final b in list) {
      final x = b.x * s.width, bw = b.w * s.width, bh = b.h;
      final top = groundY - bh + shift;
      c.drawRect(Rect.fromLTWH(x, top, bw, bh + 4), p);
      if (w.lights > .05 && lightsK > .9) {
        win.color = const Color(0xFFFFE08A).withValues(alpha: (.8 * w.lights).clamp(0, 1));
        for (final o in b.windowsFor(bw)) {
          c.drawRect(Rect.fromLTWH(x + o.dx, top + o.dy, 4, 5), win);
        }
      }
    }
  }

  void _fogAndRain(Canvas c, Size s, WorldState w, double gt) {
    final fog = Rect.fromLTWH(0, gt - 140, s.width, 160);
    c.drawRect(fog, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.white.withValues(alpha: .16 * w.rain)]).createShader(fog));
    final p = Paint()
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFCFE3FF).withValues(alpha: .5 * w.rain);
    final n = (drops.length * w.rain).toInt();
    for (var i = 0; i < n; i++) {
      final d = drops[i];
      final o = Offset(d.x * s.width, d.y * s.height);
      c.drawLine(o, o + Offset(-d.len * s.height * .12, d.len * s.height), p);
    }
  }

  void _bolt(Canvas c, Size s, double gt) {
    final path = Path();
    var x = boltX * s.width, y = 0.0;
    path.moveTo(x, y);
    final r = Random((boltX * 1000).toInt());
    while (y < gt * .8) {
      x += (r.nextDouble() - .5) * 46;
      y += 30 + r.nextDouble() * 26;
      path.lineTo(x, y);
    }
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = Colors.white.withValues(alpha: flash));
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 10..color = const Color(0xFFB9C8FF).withValues(alpha: flash * .35));
  }
}

/// A self-animating scenery widget for menus and sub-screens.
/// With [fixed] null it slowly cycles through all worlds.
class SceneryView extends StatefulWidget {
  final Widget? child;
  final bool decorTower;
  final double? fixed;
  const SceneryView({super.key, this.child, this.decorTower = false, this.fixed});
  @override
  State<SceneryView> createState() => _SceneryViewState();
}

/// World position shared by every menu screen so the scenery (and music) continue seamlessly between them.
double _sharedPos = 0;

class _SceneryViewState extends State<SceneryView> with SingleTickerProviderStateMixin {
  final scenery = Scenery();
  late final Ticker _t;
  Duration _last = Duration.zero;
  double pos = 0;
  final _tick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    pos = widget.fixed ?? _sharedPos;
    _t = createTicker((d) {
      final dt = ((d - _last).inMicroseconds / 1e6).clamp(0.0, .1);
      _last = d;
      if (widget.fixed == null) {
        pos += dt * .05;
        _sharedPos = pos;
      }
      // Menus all share the home-screen music (no-op if it is already the current track).
      if (app.audio.music.current != homeTrack) app.audio.music.setWorld(homeTrack);
      scenery.update(dt, WorldState.at(widget.fixed ?? pos));
      _tick.value++;
    })..start();
  }

  @override
  void dispose() {
    _t.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _ScenePainter(this, _tick)),
          ),
        ),
        if (widget.child != null) Positioned.fill(child: widget.child!),
      ]);
}

class _ScenePainter extends CustomPainter {
  final _SceneryViewState s;
  _ScenePainter(this.s, Listenable l) : super(repaint: l);
  @override
  void paint(Canvas c, Size size) {
    final w = WorldState.at(s.widget.fixed ?? s.pos);
    final gt = size.height - (s.widget.decorTower ? 58 : 90);
    s.scenery.paint(c, size, w, 0, groundTop: gt);
    if (s.widget.decorTower) {
      const cols = 5;
      for (var i = 0; i < cols; i++) {
        final width = 150.0 - i * 12 + (i.isOdd ? -6 : 6);
        final sway = sin(s.scenery.time * .9 + i * .4) * (i * .6);
        final color = HSLColor.fromAHSL(1, (app.store.skin.hue + i * app.store.skin.step) % 360, .8, .58).toColor();
        drawBlock(c, size.width / 2 - width / 2 + sway, gt - (i + 1) * 24, width, 24, color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => true;
}
