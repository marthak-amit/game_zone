import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../game/block_painter.dart';
import '../game/engine.dart';
import '../game/scenery.dart';
import '../game/worlds.dart';
import '../services/app_services.dart';
import 'widgets.dart';

enum Phase { play, pause, over }

class GameScreen extends StatefulWidget {
  final GameMode mode;
  const GameScreen({super.key, this.mode = GameMode.classic});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final engine = GameEngine();
  final scenery = Scenery();
  WorldState _ws = WorldState.at(0);
  bool _rainOn = false;
  final _frame = FrameTicker();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size? _size;
  Phase phase = Phase.play;
  bool revived = false, newBest = false, doubled = false;
  final score = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    app.audio.setRain(false);
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) _pause();
  }

  void _onTick(Duration t) {
    final dt = ((t - _last).inMicroseconds / 16667).clamp(0.0, 3.0);
    _last = t;
    engine.update(dt, moving: phase == Phase.play);
    _ws = engine.worldState;
    scenery.update(dt / 60, _ws);
    final wantRain = phase == Phase.play && _ws.rain > .35;
    if (wantRain != _rainOn) {
      _rainOn = wantRain;
      app.audio.setRain(wantRain);
    }
    _frame.ping();
  }

  void _start() {
    final s = _size!;
    engine.reset(s.width, s.height, isVip: app.store.vip, mode: widget.mode, fixedWorld: app.store.fixedWorldIndex);
    score.value = 0;
    revived = false;
    newBest = false;
    doubled = false;
    phase = Phase.play;
  }

  void _tap() {
    if (phase != Phase.play) return;
    final r = engine.drop();
    switch (r) {
      case DropResult.perfect:
        app.audio.chime(engine.combo - 1);
        app.audio.buzz();
      case DropResult.good:
        app.audio.beep(330, .1);
        app.audio.buzz(8);
      case DropResult.miss:
        app.audio.beep(140, .3);
        app.audio.buzz(40);
        if (engine.over) _gameOver();
      case DropResult.none:
    }
    score.value = engine.score;
  }

  void _gameOver() {
    final st = app.store;
    app.audio.beep(120, .4);
    app.audio.buzz(60);
    newBest = st.recordGame(engine.score, chill: engine.chill);
    st.missionEvent('combo', engine.maxCombo);
    if (engine.chill) st.missionEvent('chill', 1);
    st.missionEvent('score', engine.score);
    st.missionEvent('perfect', engine.runPerfects);
    st.missionEvent('games', 1);
    st.addCoins(engine.runCoins);
    setState(() => phase = Phase.over);
  }

  void _pause() {
    if (phase == Phase.play && mounted) setState(() => phase = Phase.pause);
  }

  Future<void> _revive() async {
    if (await app.rewarded(context, 'revive') && mounted) {
      revived = true;
      app.store.addCoins(-engine.runCoins);
      engine.revive();
      setState(() => phase = Phase.play);
    }
  }

  Future<void> _double() async {
    if (await app.rewarded(context, 'double_coins') && mounted) {
      app.store.addCoins(engine.runCoins);
      setState(() => doubled = true);
    }
  }

  Future<void> _again() async {
    await app.maybeInterstitial(context);
    if (mounted) setState(_start);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): _tap,
          const SingleActivator(LogicalKeyboardKey.escape): () => phase == Phase.pause ? setState(() => phase = Phase.play) : _pause(),
        },
        child: Focus(
          autofocus: true,
          child: ColoredBox(
            color: const Color(0xFF0B1020),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: LayoutBuilder(builder: (context, c) {
                  final size = Size(c.maxWidth, c.maxHeight);
                  if (_size != size) {
                    final first = _size == null;
                    _size = size;
                    if (first) _start();
                    engine.width = size.width;
                    engine.height = size.height;
                  }
                  return Stack(children: [
                    Positioned.fill(
                      child: GestureDetector(
                        key: const Key('playfield'),
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => _tap(),
                        child: CustomPaint(
                          painter: GamePainter(engine, scenery, () => _ws, _frame, () => phase == Phase.play && engine.score == 0 && app.store.games < 2),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const CoinBadge(),
                            if (widget.mode == GameMode.chill)
                              ValueListenableBuilder<int>(
                                valueListenable: score,
                                builder: (_, _, _) => Text('❤' * engine.lives.clamp(0, 3), key: const Key('lives'), style: const TextStyle(color: Colors.redAccent, fontSize: 18)),
                              ),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            ListenableBuilder(
                              listenable: app.store,
                              builder: (_, _) => Text('Best ${widget.mode == GameMode.chill ? app.store.bestChill : app.store.best}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                            ),
                            if (phase == Phase.play)
                              IconButton(key: const Key('pauseBtn'), icon: const Icon(Icons.pause_circle, size: 34, color: Colors.white70), onPressed: _pause),
                          ]),
                        ]),
                      ),
                    ),
                    if (phase != Phase.over)
                      IgnorePointer(
                        child: Align(
                          alignment: const Alignment(0, -.7),
                          child: ValueListenableBuilder<int>(
                            valueListenable: score,
                            builder: (_, v, _) => Text('$v', key: const Key('score'),
                                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 8, color: Colors.black54)])),
                          ),
                        ),
                      ),
                    if (phase == Phase.pause) _panel([
                      const Text('Paused', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
                      BigButton('▶ Resume', () => setState(() => phase = Phase.play), color: kGreen),
                      BigButton('🏠 Quit to menu', () => Navigator.pop(context), color: kGrey),
                    ]),
                    if (phase == Phase.over) _overPanel(),
                  ]);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(List<Widget> kids) => Positioned.fill(
        child: Container(
          color: Colors.black54,
          child: Center(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: kids))),
        ),
      );

  Widget _overPanel() => _panel([
        Text(widget.mode == GameMode.chill ? 'Chill Over' : 'Game Over', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
        if (newBest) const Text('🏆 NEW BEST!', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 22)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text.rich(TextSpan(style: const TextStyle(fontSize: 22), children: [
            const TextSpan(text: 'Score '),
            TextSpan(text: '${engine.score}', style: const TextStyle(fontWeight: FontWeight.w900)),
            const TextSpan(text: '  ·  +🪙'),
            TextSpan(text: '${engine.runCoins * (doubled ? 2 : 1)}', style: const TextStyle(fontWeight: FontWeight.w900)),
          ]), key: const Key('finalText')),
        ),
        if (!revived && engine.score >= 3) BigButton('📺 Continue (watch ad)', _revive, color: kGold, textColor: Colors.black),
        if (engine.runCoins > 0) BigButton('📺 Double coins', doubled ? null : _double, color: kGreen),
        BigButton('↻ Play again', _again),
        BigButton('📤 Share score', () => SharePlus.instance.share(ShareParams(text: 'I stacked ${engine.score} blocks in Sky Stack! Can you beat me?')), color: kGrey),
        BigButton('🏠 Menu', () => Navigator.pop(context), color: kGrey),
      ]);
}

/// Repaint trigger driven by the ticker.
class FrameTicker extends ChangeNotifier {
  void ping() => notifyListeners();
}

class GamePainter extends CustomPainter {
  final GameEngine e;
  final Scenery scenery;
  final WorldState Function() ws;
  final bool Function() showTutorial;
  GamePainter(this.e, this.scenery, this.ws, Listenable repaint, this.showTutorial) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final skin = app.store.skin;
    canvas.save();
    if (e.shake > 0) {
      canvas.translate(sin(e.shake * 9) * e.shake * .8, cos(e.shake * 7) * e.shake * .5);
    }
    scenery.paint(canvas, size, ws(), e.camY);

    for (final b in e.blocks) {
      drawBlock(canvas, b.x, e.yOf(b.i), b.w, GameEngine.blockH, GameEngine.colorFor(skin, b.i));
    }
    if (!e.over) {
      if (e.fever) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(e.cur.x - 4, e.yOf(e.cur.i) - 3, e.cur.w + 8, GameEngine.blockH + 4), const Radius.circular(9)),
            Paint()..color = const Color(0xFFFFD54A).withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      }
      drawBlock(canvas, e.cur.x, e.yOf(e.cur.i), e.cur.w, GameEngine.blockH, GameEngine.colorFor(skin, e.cur.i));
    }
    for (final f in e.falling) {
      drawBlock(canvas, f.x, e.yOf(f.i) + f.dy, f.w, GameEngine.blockH, GameEngine.colorFor(skin, f.i), alpha: .85);
    }
    for (final r in e.rings) {
      final t = 1 - r.life / 24;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(r.x, e.yOf(r.i) + 14), width: 30 + t * 150, height: 12 + t * 40),
          Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = Colors.white.withValues(alpha: (1 - t) * .8));
    }
    final pp = Paint();
    for (final pt in e.particles) {
      pp.color = (pt.big ? const Color(0xFFFFFFFF) : const Color(0xFFFFD54A)).withValues(alpha: (pt.life / 30).clamp(0, 1));
      canvas.drawCircle(Offset(pt.x, pt.y), pt.big ? 3 : 2.4, pp);
    }
    for (final pop in e.popups) {
      _text(canvas, pop.text, Offset(pop.x.clamp(60, size.width - 60), e.yOf(pop.i) - (45 - pop.life) - 22), 18, alpha: (pop.life / 20).clamp(0, 1).toDouble());
    }
    if (e.bannerLife > 0 && e.banner != null) {
      final a = (e.bannerLife / 40).clamp(0.0, 1.0);
      _text(canvas, e.banner!, Offset(size.width / 2, size.height * .30), 30 + (1 - a) * 4, alpha: a);
    }
    if (e.fever && !e.over) {
      _text(canvas, '🔥 FEVER ×2 coins', Offset(size.width / 2, size.height * .26), 15, alpha: .9);
    }
    if (showTutorial()) {
      _text(canvas, 'TAP to drop the block', Offset(size.width / 2, size.height / 2), 22);
      _text(canvas, 'Line it up for PERFECT bonuses', Offset(size.width / 2, size.height / 2 + 30), 15);
    }
    canvas.restore();
  }

  void _text(Canvas c, String s, Offset center, double size, {double alpha = 1}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha),
          fontSize: size,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 6, color: Colors.black.withValues(alpha: .6 * alpha))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}
