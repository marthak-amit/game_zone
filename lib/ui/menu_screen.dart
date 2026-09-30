import 'package:flutter/material.dart';
import '../services/app_services.dart';
import 'achievements_screen.dart';
import 'game_screen.dart';
import 'missions_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'spin_screen.dart';
import 'widgets.dart';

/// Home screen: one big PLAY button, one row of secondary actions, two corner utilities.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _push(BuildContext c, Widget w) => Navigator.push(c, fadeRoute(w));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SkyBackground(
        decorTower: true,
        dim: .22,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListenableBuilder(
                listenable: app.store,
                builder: (context, _) {
                  final s = app.store;
                  final tiles = <Widget>[
                    if (s.dailyAvailable) MenuTile('🎁', 'Daily', () => _claimDaily(context), key: const Key('tile_daily'), badge: '!', wiggle: true),
                    MenuTile('🎡', 'Wheel', () => _push(context, const SpinScreen()), key: const Key('tile_wheel'), badge: s.freeSpinAvailable ? 'FREE' : null),
                    MenuTile('🎯', 'Missions', () => _push(context, const MissionsScreen()), key: const Key('tile_missions'), badge: s.missionsReady > 0 ? '${s.missionsReady}' : null),
                    MenuTile('🏆', 'Trophies', () => _push(context, const AchievementsScreen()), key: const Key('tile_trophies')),
                    MenuTile('🛒', 'Shop', () => _push(context, const ShopScreen()), key: const Key('tile_shop')),
                  ];
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [LevelChip(), CoinBadge()]),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Bob(
                              amplitude: 5,
                              child: ShaderMask(
                                shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Color(0xFFBFE9FF), Color(0xFFFFE0F0)]).createShader(r),
                                child: const Text('SKY STACK',
                                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white, shadows: [Shadow(blurRadius: 20, color: Colors.black54), Shadow(blurRadius: 3, color: Colors.black45)])),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('🏆 Best  ${s.best}', key: const Key('best'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 8, color: Colors.black54)])),
                            const SizedBox(height: 26),
                            PlayButton(onPressed: () => _push(context, const GameScreen())),
                            const SizedBox(height: 34), // breathing room between PLAY and the secondary actions
                            Wrap(
                              spacing: 12,
                              runSpacing: 16,
                              alignment: WrapAlignment.center,
                              children: [for (var i = 0; i < tiles.length; i++) PopIn(delay: Duration(milliseconds: 120 + i * 90), child: tiles[i])],
                            ),
                          ]),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        RoundIconButton(
                          key: const Key('soundBtn'),
                          icon: s.anySound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          tooltip: s.anySound ? 'Sound on' : 'Sound off',
                          onTap: () => s.setAllSound(!s.anySound),
                        ),
                        RoundIconButton(key: const Key('settingsBtn'), icon: Icons.settings_rounded, tooltip: 'Settings', onTap: () => _push(context, const SettingsScreen())),
                      ]),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _claimDaily(BuildContext context) async {
    final reward = app.store.claimDaily();
    app.audio.fanfare();
    final dbl = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('+$reward coins!'),
        content: const Text('Watch a short ad to double your reward?'),
        actions: [
          TextButton(key: const Key('noThanks'), onPressed: () => Navigator.pop(context, false), child: const Text('No thanks')),
          FilledButton(key: const Key('doubleDaily'), onPressed: () => Navigator.pop(context, true), child: const Text('📺 Double it')),
        ],
      ),
    );
    if (dbl == true && context.mounted && await app.rewarded(context, 'daily_double')) {
      app.store.addCoins(reward);
    }
  }
}
