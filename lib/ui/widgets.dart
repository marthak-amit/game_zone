import 'package:flutter/material.dart';
import '../game/engine.dart';
import '../game/scenery.dart';
import '../services/app_services.dart';
import '../services/perf.dart';
import 'anim_widgets.dart';
export 'anim_widgets.dart';
import 'level_screen.dart';

/// Animated world background (slowly cycles through all worlds) used on menus.
class SkyBackground extends StatelessWidget {
  final Widget child;
  final bool decorTower;

  /// Darkening applied over the scenery so white text stays readable on bright skies.
  final double dim;
  const SkyBackground({super.key, required this.child, this.decorTower = false, this.dim = .42});
  @override
  Widget build(BuildContext context) => SceneryView(
        decorTower: decorTower,
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: dim + .12), Colors.black.withValues(alpha: dim * .5), Colors.black.withValues(alpha: dim + .05)],
                ),
              ),
            ),
          ),
          child,
        ]),
      );
}

const kGreen = Color(0xFF16A34A);
const kGold = Color(0xFFF59E0B);
const kGrey = Color(0xFF475569);
const kBlue = Color(0xFF3B82F6);
const kPurple = Color(0xFF7C3AED);

/// Glossy gradient button with a press animation.
class BigButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final double width, height;
  const BigButton(this.label, this.onPressed,
      {super.key, this.color = kBlue, this.textColor = Colors.white, this.width = 280, this.height = 52});
  @override
  State<BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<BigButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final c = widget.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: AnimatedScale(
        scale: _down ? .96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1 : .45,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(c, Colors.white, .22)!, c, Color.lerp(c, Colors.black, .22)!],
                stops: const [0, .5, 1],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: .28)),
              boxShadow: [BoxShadow(color: c.withValues(alpha: .45), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  app.audio.click();
                  widget.onPressed!();
                },
                onHighlightChanged: (v) => setState(() => _down = v),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(widget.label,
                          style: TextStyle(color: widget.textColor, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: .3)),
                    ),
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

/// Gently pulses its child to draw the eye (used on PLAY).
class Pulse extends StatefulWidget {
  final Widget child;
  const Pulse({super.key, required this.child});
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = loopController(this, const Duration(milliseconds: 1300), reverse: true);
  @override
  void dispose() {
    Perf.instance.unregister(_c);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(scale: 1 + .04 * Curves.easeInOut.transform(_c.value), child: child),
        child: widget.child,
      );
}

class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (_, _) => Container(
          padding: const EdgeInsets.fromLTRB(8, 5, 14, 5),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .42), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white30)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const SpinningCoin(size: 26),
            const SizedBox(width: 7),
            // counts up/down smoothly whenever the balance changes
            TweenAnimationBuilder<int>(
              tween: IntTween(end: app.store.coins),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOut,
              builder: (_, v, _) => Text('$v', key: const Key('coins'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ),
          ]),
        ),
      );
}

/// Tappable player-level badge: gold level circle, title, XP bar. Opens the "Your Level" screen.
class LevelChip extends StatelessWidget {
  const LevelChip({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (_, _) {
          final s = app.store;
          return Material(
            color: Colors.black.withValues(alpha: .45),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: const BorderSide(color: Colors.white30)),
            child: InkWell(
              key: const Key('levelChip'),
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                app.audio.click();
                Navigator.push(context, fadeRoute(const LevelScreen()));
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  LevelBadge(level: s.level, size: 38),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 3),
                    SizedBox(width: 82, child: XpBar(value: s.xpInLevel / s.xpNeeded, height: 6)),
                  ]),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.white70),
                ]),
              ),
            ),
          );
        },
      );
}

/// Gold circle with the level number (like a rank badge).
class LevelBadge extends StatelessWidget {
  final int level;
  final double size;
  const LevelBadge({super.key, required this.level, this.size = 40});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE27A), Color(0xFFF59E0B), Color(0xFFB45309)]),
          border: Border.all(color: Colors.white, width: size > 60 ? 3 : 2),
          boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: .5), blurRadius: size / 3)],
        ),
        child: Text('$level', style: TextStyle(fontSize: size * .44, fontWeight: FontWeight.w900, color: const Color(0xFF3B2100))),
      );
}

class XpBar extends StatelessWidget {
  final double value;
  final double height;
  const XpBar({super.key, required this.value, this.height = 7});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(value: value.clamp(0.0, 1.0), minHeight: height, color: const Color(0xFF5BE7A9), backgroundColor: Colors.white24),
      );
}

/// Standard sub-screen scaffold (shop, missions, settings, ...).
class SubScreen extends StatelessWidget {
  final String title;
  final Widget child;
  const SubScreen({super.key, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SkyBackground(
          dim: .78,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                    child: Row(children: [
                      IconButton(key: const Key('back'), icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const CoinBadge(),
                    ]),
                  ),
                  Expanded(child: child),
                ]),
              ),
            ),
          ),
        ),
      );
}

Color blockColor(int i) => GameEngine.colorFor(app.store.skin, i);

/// Smooth slide+fade page transition used for all screens.
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: SlideTransition(position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)), child: child),
      ),
    );

/// Dark rounded card used on sub-screens so text is always readable.
const kCardColor = Color(0xCC0B1224);

BoxDecoration cardDecoration({Color? border, Color? color}) => BoxDecoration(
      color: color ?? kCardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border ?? Colors.white.withValues(alpha: .14)),
    );

/// Big rounded PLAY button: vector play icon, glow, pulse and a light shine that sweeps across.
class PlayButton extends StatefulWidget {
  final VoidCallback onPressed;
  const PlayButton({super.key, required this.onPressed});
  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _shine = loopController(this, const Duration(milliseconds: 2800));
  @override
  void dispose() {
    Perf.instance.unregister(_shine);
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Pulse(
        // RepaintBoundary: the blurred glow is rasterised once; pulsing only scales the cached layer.
        child: RepaintBoundary(
          child: Container(
          width: 270,
          height: 74,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4ADE80), Color(0xFF16A34A), Color(0xFF0F7A35)]),
            border: Border.all(color: Colors.white.withValues(alpha: .55), width: 2),
            boxShadow: [BoxShadow(color: const Color(0xFF22C55E).withValues(alpha: .6), blurRadius: 22, spreadRadius: 1, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(38),
            child: Stack(children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                   child: AnimatedBuilder(
                    animation: _shine,
                    builder: (_, _) {
                      final t = (_shine.value / .45).clamp(0.0, 1.0); // sweep during the first 45% of each cycle
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-2.2 + 4.4 * t, -.4),
                            end: Alignment(-1.2 + 4.4 * t, .4),
                            colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: .38), Colors.white.withValues(alpha: 0)],
                          ),
                        ),
                      );
                    },
                  ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('playButton'),
                  onTap: () {
                    app.audio.click();
                    widget.onPressed();
                  },
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))]),
                      child: const Icon(Icons.play_arrow_rounded, size: 44, color: Color(0xFF15803D)),
                    ),
                    const SizedBox(width: 14),
                    const Text('PLAY', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 3, shadows: [Shadow(blurRadius: 6, color: Colors.black38, offset: Offset(0, 2))])),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        ),
      );
}

/// Dark card built on Material (required when it contains ListTile / SwitchListTile so ripples show).
class CardBox extends StatelessWidget {
  final Widget child;
  const CardBox({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Material(
        color: kCardColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: .14))),
        child: child,
      );
}
