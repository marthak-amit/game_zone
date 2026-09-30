import 'package:flutter/material.dart';
import '../game/engine.dart';
import '../game/scenery.dart';
import '../services/app_services.dart';

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
                onTap: widget.onPressed,
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat(reverse: true);
  @override
  void dispose() {
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

/// Square glass tile used in the menu grid.
class MenuCard extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  final String? badge;
  const MenuCard(this.icon, this.label, this.onTap, {super.key, this.badge});
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Material(
          color: Colors.black.withValues(alpha: .32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.white.withValues(alpha: .3))),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: SizedBox(
              width: 100,
              height: 78,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: -4,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
              child: Text(badge!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
      ]);
}

class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (_, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .3), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
          child: Text('🪙 ${app.store.coins}', key: const Key('coins'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      );
}

/// "Lv 3 · Builder" with an XP progress bar.
class LevelChip extends StatelessWidget {
  const LevelChip({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (_, _) {
          final s = app.store;
          return Container(
            key: const Key('levelChip'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .3), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Lv ${s.level} · ${s.title}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 4),
              SizedBox(width: 110, child: XpBar(value: s.xpInLevel / s.xpNeeded)),
            ]),
          );
        },
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
