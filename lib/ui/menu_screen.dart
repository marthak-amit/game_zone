import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_services.dart';
import 'achievements_screen.dart';
import 'game_screen.dart';
import 'missions_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'spin_screen.dart';
import 'widgets.dart';

const _tips = [
  'Perfect drops make your tower wider!',
  '5 perfects in a row start FEVER — double coins!',
  'The world changes every 12 blocks. How far can you go?',
  'Spin the lucky wheel every day for free coins.',
  'Complete daily missions for bonus coins.',
  'Reach Rain Storm to hear the rain and see lightning ⚡',
  'Level up to earn bigger coin rewards.',
  'Unlock a favourite background in the Shop.',
  'Watch a short ad to continue after a miss.',
  'Keep your daily streak going — Day 7 pays the most!',
  'Something special happens when you beat your best score…',
];

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _tip = DateTime.now().second % _tips.length;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) setState(() => _tip = (_tip + 1) % _tips.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _push(Widget w) => Navigator.push(context, fadeRoute(w));

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
                  return Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [LevelChip(), CoinBadge()]),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            ShaderMask(
                              shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Color(0xFFBFE9FF), Color(0xFFFFE0F0)]).createShader(r),
                              child: const Text('SKY STACK',
                                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.white, shadows: [Shadow(blurRadius: 20, color: Colors.black54), Shadow(blurRadius: 3, color: Colors.black45)])),
                            ),
                            const Text('stack · relax · repeat', style: TextStyle(color: Colors.white70, letterSpacing: 4, fontSize: 12)),
                            const SizedBox(height: 6),
                            Text('🏆 Best  ${s.best}', key: const Key('best'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 8, color: Colors.black54)])),
                            const SizedBox(height: 12),
                            Pulse(child: BigButton('▶   PLAY', () => _push(const GameScreen()), color: kGreen, width: 260, height: 62)),
                            if (s.dailyAvailable)
                              BigButton('🎁 Daily reward — Day ${s.nextStreak}: +${s.dailyReward}', () => _claimDaily(context), color: kGold, textColor: Colors.black),
                            const SizedBox(height: 8),
                            Wrap(spacing: 12, runSpacing: 14, alignment: WrapAlignment.center, children: [
                              MenuCard('🎡', 'Lucky Wheel', () => _push(const SpinScreen()), badge: s.freeSpinAvailable ? 'FREE' : null),
                              MenuCard('🎯', 'Missions', () => _push(const MissionsScreen()), badge: s.missionsReady > 0 ? '${s.missionsReady}' : null),
                              MenuCard('🏆', 'Achievements', () => _push(const AchievementsScreen()), badge: null),
                              MenuCard('🛒', 'Shop', () => _push(const ShopScreen())),
                              MenuCard('📺', 'Free coins', () async {
                                if (await app.rewarded(context, 'free_coins')) s.addCoins(50);
                              }),
                              MenuCard('⚙', 'Settings', () => _push(const SettingsScreen())),
                            ]),
                            const SizedBox(height: 10),
                            if (!s.noAds)
                              BigButton('🚫 Remove Ads ${app.iap.prices['remove_ads'] ?? r'$2.99'}', () => app.buy(context, 'remove_ads'), color: kGold, textColor: Colors.black, width: 200, height: 36),
                          ]),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: Text('💡 ${_tips[_tip]}', key: ValueKey(_tip), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, shadows: [Shadow(blurRadius: 6, color: Colors.black87)])),
                      ),
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
