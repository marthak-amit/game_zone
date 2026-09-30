import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_stack/achievements.dart';
import 'package:sky_stack/main.dart';
import 'package:sky_stack/services/ads.dart';
import 'package:sky_stack/services/app_services.dart';
import 'package:sky_stack/services/iap.dart';
import 'package:sky_stack/store.dart';
import 'package:sky_stack/ui/confetti.dart';
import 'package:sky_stack/ui/game_screen.dart';

class FakeAds implements AdService {
  int rewardedCalls = 0, interstitials = 0;
  bool grant = true;
  @override
  Future<void> init() async {}
  @override
  Future<bool> showRewarded(BuildContext c, String r) async {
    rewardedCalls++;
    return grant;
  }

  @override
  Future<void> showInterstitial(BuildContext c) async => interstitials++;
}

class FakeIap implements IapService {
  late GrantCallback g;
  @override
  Map<String, String> get prices => const {};
  @override
  Future<void> init(GrantCallback onGrant) async => g = onGrant;
  @override
  Future<void> restore() async {}
  @override
  Future<void> buy(BuildContext c, String sku) async => g(sku);
}

late FakeAds ads;

Future<void> boot(WidgetTester t, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  t.view.physicalSize = const Size(400 * 3, 800 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  ads = FakeAds();
  final iap = FakeIap();
  app = AppServices(store: await Store.load(), ads: ads, iap: iap);
  app.audio.available = false; // no real sound plugins in tests
  await app.init();
  await t.pumpWidget(const SkyStackApp());
}

/// The animated background never stops ticking, so pumpAndSettle would time out.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> startPlaying(WidgetTester t) async {
  await t.tap(find.textContaining('PLAY'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600)); // route transition (ticker never settles)
}

/// Taps the playfield; the block position is arbitrary so results vary, which is fine for flow tests.
Future<void> loseGame(WidgetTester t) async {
  for (var i = 0; i < 300; i++) {
    if (find.byKey(const Key('finalScore')).evaluate().isNotEmpty) return;
    await t.tap(find.byKey(const Key('playfield')));
    await t.pump(const Duration(milliseconds: 90));
  }
}

void main() {
  testWidgets('menu shows and daily reward + double works', (t) async {
    await boot(t);
    expect(find.text('SKY STACK'), findsOneWidget);
    await t.tap(find.textContaining('Daily reward'));
    await settle(t);
    expect(app.store.coins, 50);
    await t.tap(find.byKey(const Key('doubleDaily')));
    await settle(t);
    expect(app.store.coins, 100);
    expect(ads.rewardedCalls, 1);
    expect(find.textContaining('Daily reward'), findsNothing);
  });

  testWidgets('play a round to game over, coins + best saved, revive, replay, menu', (t) async {
    await boot(t, prefs: {'games': 5});
    await startPlaying(t);
    expect(find.byKey(const Key('playfield')), findsOneWidget);
    await loseGame(t);
    expect(find.byKey(const Key('finalScore')), findsOneWidget);
    expect(app.store.games, 6);
    expect(app.store.coins, greaterThanOrEqualTo(0));
    // play again returns to playing
    await t.tap(find.text('↻ Play again'));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('finalScore')), findsNothing);
    expect(find.byKey(const Key('pauseBtn')), findsOneWidget);
  });

  testWidgets('pause, resume, quit', (t) async {
    await boot(t);
    await startPlaying(t);
    await t.tap(find.byKey(const Key('pauseBtn')));
    await t.pump();
    expect(find.text('Paused'), findsOneWidget);
    await t.tap(find.text('▶ Resume'));
    await t.pump();
    expect(find.text('Paused'), findsNothing);
    await t.tap(find.byKey(const Key('pauseBtn')));
    await t.pump();
    await t.tap(find.text('🏠 Quit to menu'));
    await settle(t);
    expect(find.text('SKY STACK'), findsOneWidget);
  });

  testWidgets('shop: buy coins, buy skin, not enough coins, VIP removes ads button', (t) async {
    await boot(t);
    await t.tap(find.text('Shop'));
    await settle(t);
    await t.ensureVisible(find.byKey(const Key('skin_sunset')));
    await t.pump();
    await t.tap(find.byKey(const Key('skin_sunset')));
    await t.pump();
    expect(find.textContaining('Not enough coins'), findsOneWidget);
    await t.ensureVisible(find.textContaining('🪙 500 coins'));
    await t.pump();
    await t.tap(find.textContaining('🪙 500 coins'));
    await t.pump();
    expect(app.store.coins, 500);
    await t.drag(find.byType(ListView), const Offset(0, 3000)); // back to the top (list is virtualised)
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('skin_sunset')));
    await t.pump();
    await t.tap(find.byKey(const Key('skin_sunset')));
    await t.pump();
    expect(app.store.coins, 200);
    expect(app.store.skinId, 'sunset');
    await t.ensureVisible(find.textContaining('VIP: no ads'));
    await t.pump();
    await t.tap(find.textContaining('VIP: no ads'));
    await t.pump();
    expect(app.store.vip && app.store.noAds, isTrue);
    expect(app.store.owns(skins.last), isTrue);
    await t.tap(find.byKey(const Key('back')));
    await settle(t);
    expect(find.textContaining('Remove Ads'), findsNothing);
  });

  testWidgets('missions: 3 distinct daily missions, claim pays reward', (t) async {
    await boot(t);
    final ms = app.store.missions;
    expect(ms.length, 3);
    expect({for (final m in ms) m.text}.length, 3);
    app.store.missionEvent(ms[0].type, ms[0].goal);
    final reward = app.store.missions[0].reward;
    await t.tap(find.text('Missions'));
    await settle(t);
    await t.tap(find.byKey(const Key('claim_0')));
    await t.pump();
    expect(app.store.coins, reward);
    expect(app.store.missions[0].claimed, isTrue);
    expect(find.text('✓ Done'), findsOneWidget);
  });

  testWidgets('backgrounds: buy and select a world, VIP owns all', (t) async {
    await boot(t, prefs: {'coins': 300});
    await t.tap(find.text('Shop'));
    await settle(t);
    await t.ensureVisible(find.byKey(const Key('world_storm')));
    await t.pump();
    await t.tap(find.byKey(const Key('world_storm')));
    await t.pump();
    expect(app.store.coins, 50);
    expect(app.store.worldPref, 'storm');
    expect(app.store.fixedWorldIndex, 3);
    await t.ensureVisible(find.byKey(const Key('world_auto')));
    await t.pump();
    await t.tap(find.byKey(const Key('world_auto')));
    await t.pump();
    expect(app.store.fixedWorldIndex, isNull);
    // not enough coins for another
    await t.ensureVisible(find.byKey(const Key('world_space')));
    await t.pump();
    await t.tap(find.byKey(const Key('world_space')));
    await t.pump();
    expect(app.store.ownsWorld('space'), isFalse);
    app.store.setVip();
    expect(app.store.ownsWorld('space'), isTrue);
  });

  testWidgets('settings toggles persist to store', (t) async {
    await boot(t);
    await t.tap(find.text('Settings'));
    await settle(t);
    await t.tap(find.byKey(const Key('soundSwitch')));
    await t.pump();
    expect(app.store.sound, isFalse);
    expect(app.audio.soundOn, isFalse);
    await t.tap(find.byKey(const Key('musicSwitch')));
    await t.tap(find.byKey(const Key('voiceSwitch')));
    await t.pump();
    expect(app.store.music, isFalse);
    expect(app.store.voice, isFalse);
    expect(app.audio.voice.enabled, isFalse);
    expect(app.audio.music.enabled, isFalse);
  });

  testWidgets('menu shows level chip, best score and all feature tiles', (t) async {
    await boot(t);
    expect(find.byKey(const Key('levelChip')), findsOneWidget);
    expect(find.textContaining('Lv 1'), findsOneWidget);
    for (final label in ['Lucky Wheel', 'Missions', 'Achievements', 'Shop', 'Free coins', 'Settings']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('FREE'), findsOneWidget); // free daily spin badge
  });

  testWidgets('lucky wheel: free spin pays a prize once a day', (t) async {
    await boot(t);
    await t.tap(find.text('Lucky Wheel'));
    await settle(t);
    expect(app.store.freeSpinAvailable, isTrue);
    await t.tap(find.textContaining('SPIN (free)'));
    await t.pump(const Duration(seconds: 6));
    expect(Store.spinPrizes, contains(app.store.coins));
    expect(app.store.freeSpinAvailable, isFalse);
    expect(find.textContaining('You won'), findsOneWidget);
    // a second free spin is not possible; extra spin needs an ad
    final before = app.store.coins;
    await t.tap(find.textContaining('Extra spin'));
    await t.pump(const Duration(seconds: 6));
    expect(app.store.coins, greaterThan(before));
    expect(ads.rewardedCalls, 1);
    expect(app.store.adSpinsToday, 1);
  });

  testWidgets('achievements screen lists all and reflects unlocks', (t) async {
    await boot(t);
    app.store.checkAchievements(const RunStats(30, 6, 12));
    await t.tap(find.text('Achievements'));
    await settle(t);
    expect(find.byKey(const Key('achCount')), findsOneWidget);
    expect(app.store.achievementsUnlocked, greaterThanOrEqualTo(4));
    expect(find.textContaining('unlocked'), findsOneWidget);
  });

  testWidgets('game over gives XP, and beating the best shows the NEW BEST celebration', (t) async {
    await boot(t, prefs: {'games': 5});
    await startPlaying(t);
    for (var i = 0; i < 4; i++) {
      await t.tap(find.byKey(const Key('playfield')));
      await t.pump(const Duration(milliseconds: 400));
    }
    await loseGame(t);
    expect(find.byKey(const Key('finalScore')), findsOneWidget);
    expect(app.store.xp, greaterThanOrEqualTo(10));
    expect(app.store.games, 6);
  });

  testWidgets('interstitial after 3 games for free users, never for payers', (t) async {
    await boot(t);
    final ctx = t.element(find.text('SKY STACK'));
    for (var i = 0; i < 3; i++) {
      await app.maybeInterstitial(ctx);
    }
    expect(ads.interstitials, 1);
    app.store.setNoAds();
    for (var i = 0; i < 10; i++) {
      await app.maybeInterstitial(ctx);
    }
    expect(ads.interstitials, 1);
  });

  test('store: streak logic and mission reset', () async {
    SharedPreferences.setMockInitialValues({
      'dailyDate': Store.dayKey(DateTime.now().subtract(const Duration(days: 1))),
      'streak': 3,
    });
    final s = await Store.load();
    expect(s.nextStreak, 4);
    expect(s.claimDaily(), 200);
    expect(s.dailyAvailable, isFalse);
    SharedPreferences.setMockInitialValues({
      'dailyDate': Store.dayKey(DateTime.now().subtract(const Duration(days: 3))),
      'streak': 6,
    });
    expect((await Store.load()).nextStreak, 1);
  });

  testWidgets('confetti is quick: the whole effect is over in under 4 seconds', (t) async {
    final c = ConfettiController();
    await t.pumpWidget(MaterialApp(home: Confetti(controller: c)));
    c.fire(); // default is short
    await t.pump();
    var ms = 0;
    while (ms < 12000) {
      await t.pump(const Duration(milliseconds: 16)); // realistic 60 fps frames
      ms += 16;
      if (!t.binding.hasScheduledFrame) break;
    }
    expect(ms, greaterThan(500), reason: 'it should actually play');
    expect(ms, lessThan(4000), reason: 'confetti should be finished within 4 s');
  });

  testWidgets('game start has a short "get ready" grace; then the block moves and taps count', (t) async {
    await boot(t, prefs: {'games': 5});
    await startPlaying(t);
    final e = (t.state(find.byType(GameScreen)) as dynamic).engine;
    final x0 = e.cur.x;
    await t.tap(find.byKey(const Key('playfield'))); // too early: ignored
    await t.pump();
    expect(e.score, 0);
    expect(e.cur.x, x0);
    await t.pump(const Duration(milliseconds: 1200));
    expect(e.cur.x, isNot(x0), reason: 'block should be moving after the grace period');
  });

  testWidgets('a miss lets the block fall first; the result card appears shortly after', (t) async {
    await boot(t, prefs: {'games': 5});
    await startPlaying(t);
    await t.pump(const Duration(milliseconds: 1000));
    final e = (t.state(find.byType(GameScreen)) as dynamic).engine;
    e.cur.x = e.top.x + 999;
    await t.tap(find.byKey(const Key('playfield')));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('finalScore')), findsNothing, reason: 'still showing the fall');
    expect(e.over, isTrue);
    await t.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const Key('finalScore')), findsOneWidget);
  });

  testWidgets('Android back pauses the game instead of leaving it', (t) async {
    await boot(t, prefs: {'games': 5});
    await startPlaying(t);
    await t.pump(const Duration(milliseconds: 900));
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.byKey(const Key('playfield')), findsOneWidget); // still on the game screen
    await t.tap(find.text('▶ Resume'));
    await t.pump();
    expect(find.text('Paused'), findsNothing);
  });
}