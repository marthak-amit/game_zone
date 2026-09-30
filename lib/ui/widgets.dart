import 'package:flutter/material.dart';
import '../game/engine.dart';
import '../game/scenery.dart';
import '../services/app_services.dart';

/// Animated world background (slowly cycles through all worlds) used on menus.
class SkyBackground extends StatelessWidget {
  final Widget child;
  final bool decorTower;
  const SkyBackground({super.key, required this.child, this.decorTower = false});
  @override
  Widget build(BuildContext context) => SceneryView(decorTower: decorTower, child: child);
}

class BigButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  const BigButton(this.label, this.onPressed,
      {super.key, this.color = const Color(0xFF3B82F6), this.textColor = Colors.white});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: SizedBox(
          width: 280,
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: textColor,
              disabledBackgroundColor: color.withValues(alpha: .4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            onPressed: onPressed,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
          ),
        ),
      );
}

const kGreen = Color(0xFF16A34A);
const kGold = Color(0xFFF59E0B);
const kGrey = Color(0xFF475569);

class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app.store,
        builder: (_, _) => Text('🪙 ${app.store.coins}',
            key: const Key('coins'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      );
}

/// Standard sub-screen scaffold (shop, missions, settings).
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
                      IconButton(
                          key: const Key('back'),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context)),
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
