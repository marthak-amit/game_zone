import 'package:flutter/material.dart';
import '../services/app_services.dart';
import '../game/engine.dart';
import 'game_screen.dart';
import 'missions_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'widgets.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _push(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SkyBackground(
        decorTower: true,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: app.store,
            builder: (context, _) {
              final s = app.store;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const CoinBadge(),
                    Text('Best ${s.best}', key: const Key('best'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ]),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('SKY STACK',
                            style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, letterSpacing: 2, shadows: [Shadow(blurRadius: 18, color: Colors.black54), Shadow(blurRadius: 4, color: Colors.black38)])),
                        const Text('stack · relax · repeat', style: TextStyle(color: Colors.white70, letterSpacing: 3, fontSize: 12)),
                        const SizedBox(height: 16),
                        BigButton('▶  PLAY', () => _push(context, const GameScreen()), color: kGreen),
                        BigButton('🌧  CHILL MODE  (slow · 3 lives)', () => _push(context, const GameScreen(mode: GameMode.chill)), color: const Color(0xFF4F46E5)),
                        if (s.dailyAvailable) BigButton('🎁 Daily reward — Day ${s.nextStreak}: +${s.dailyReward}', () => _claimDaily(context), color: kGold, textColor: Colors.black),
                        BigButton('🎯 Missions${s.missionsReady > 0 ? ' (${s.missionsReady} ready!)' : ''}', () => _push(context, const MissionsScreen())),
                        BigButton('🛒 Shop', () => _push(context, const ShopScreen())),
                        BigButton('📺 Free coins +50', () async {
                          if (await app.rewarded(context, 'free_coins')) s.addCoins(50);
                        }, color: kGrey),
                        BigButton('⚙ Settings & Stats', () => _push(context, const SettingsScreen()), color: kGrey),
                        if (!s.noAds) BigButton('🚫 Remove Ads — ${app.iap.prices['remove_ads'] ?? r'$2.99'}', () => app.buy(context, 'remove_ads'), color: kGold, textColor: Colors.black),
                      ]),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _claimDaily(BuildContext context) async {
    final reward = app.store.claimDaily();
    app.audio.beep(880, .2);
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
