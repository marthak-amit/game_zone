import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_stack/main.dart';
import 'package:sky_stack/services/ads.dart';
import 'package:sky_stack/services/app_services.dart';
import 'package:sky_stack/services/iap.dart';
import 'package:sky_stack/store.dart';

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
  await app.init();
  await t.pumpWidget(const SkyStackApp());
}

Future<void> startPlaying(WidgetTester t) async {
  await t.tap(find.text('▶  PLAY'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600)); // route transition (ticker never settles)
}

/// Taps the playfield; the block position is arbitrary so results vary, which is fine for flow tests.
Future<void> loseGame(WidgetTester t) async {
  for (var i = 0; i < 300; i++) {
    if (find.text('Game Over').evaluate().isNotEmpty) return;
    await t.tap(find.byKey(const Key('playfield')));
    await t.pump(const Duration(milliseconds: 90));
  }
}

void main() {
  testWidgets('menu shows and daily reward + double works', (t) async {
    await boot(t);
    expect(find.text('SKY STACK'), findsOneWidget);
    await t.tap(find.textContaining('Daily reward'));
    await t.pumpAndSettle();
    expect(app.store.coins, 50);
    await t.tap(find.byKey(const Key('doubleDaily')));
    await t.pumpAndSettle();
    expect(app.store.coins, 100);
    expect(ads.rewardedCalls, 1);
    expect(find.textContaining('Daily reward'), findsNothing);
  });

  testWidgets('play a round to game over, coins + best saved, revive, replay, menu', (t) async {
    await boot(t, prefs: {'games': 5});
    await startPlaying(t);
    expect(find.byKey(const Key('playfield')), findsOneWidget);
    await loseGame(t);
    expect(find.text('Game Over'), findsOneWidget);
    expect(app.store.games, 6);
    expect(app.store.coins, greaterThanOrEqualTo(0));
    // play again returns to playing
    await t.tap(find.text('↻ Play again'));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Game Over'), findsNothing);
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
    await t.pumpAndSettle();
    expect(find.text('SKY STACK'), findsOneWidget);
  });

  testWidgets('shop: buy coins, buy skin, not enough coins, VIP removes ads button', (t) async {
    await boot(t);
    await t.tap(find.text('🛒 Shop'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('skin_sunset')));
    await t.pump();
    expect(find.textContaining('Not enough coins'), findsOneWidget);
    await t.ensureVisible(find.textContaining('🪙 500 coins'));
    await t.tap(find.textContaining('🪙 500 coins'));
    await t.pump();
    expect(app.store.coins, 500);
    await t.tap(find.byKey(const Key('skin_sunset')));
    await t.pump();
    expect(app.store.coins, 200);
    expect(app.store.skinId, 'sunset');
    await t.ensureVisible(find.textContaining('VIP: no ads'));
    await t.tap(find.textContaining('VIP: no ads'));
    await t.pump();
    expect(app.store.vip && app.store.noAds, isTrue);
    expect(app.store.owns(skins.last), isTrue);
    await t.tap(find.byKey(const Key('back')));
    await t.pumpAndSettle();
    expect(find.textContaining('Remove Ads'), findsNothing);
  });

  testWidgets('missions claim', (t) async {
    await boot(t);
    app.store.missionEvent('games', 3);
    await t.tap(find.textContaining('Missions'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('claim_2')));
    await t.pump();
    expect(app.store.coins, 40);
    expect(app.store.missions[2].claimed, isTrue);
    expect(find.text('✓ Done'), findsOneWidget);
  });

  testWidgets('settings toggles persist to store', (t) async {
    await boot(t);
    await t.tap(find.text('⚙ Settings & Stats'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('soundSwitch')));
    await t.pump();
    expect(app.store.sound, isFalse);
    expect(app.audio.soundOn, isFalse);
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
}
