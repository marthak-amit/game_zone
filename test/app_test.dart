import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_stack/achievements.dart';
import 'package:sky_stack/main.dart';
import 'package:sky_stack/services/ads.dart';
import 'package:sky_stack/services/audio.dart';
import 'package:sky_stack/services/music.dart';
import 'package:sky_stack/ui/level_screen.dart';
import 'package:sky_stack/ui/widgets.dart';
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

/// Records which sounds the game asks for (no real playback).
class RecordingAudio extends Audio {
  final log = <String>[];
  @override
  void thud({bool perfect = false}) => log.add(perfect ? 'thudP' : 'thud');
  @override
  void chime(int step) => log.add('chime');
  @override
  void gameOver() => log.add('gameOver');
  @override
  void startRound() => log.add('start');
  @override
  void applause({bool long = true}) => log.add(long ? 'applause' : 'applauseS');
  @override
  void fanfare() => log.add('fanfare');
  @override
  void sparkle() => log.add('sparkle');
  @override
  void whoosh() => log.add('whoosh');
  @override
  void ding() => log.add('ding');
  @override
  void click() => log.add('click');
}

late RecordingAudio rec;
late FakeAds ads;

Future<void> boot(WidgetTester t, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  t.view.physicalSize = const Size(400 * 3, 800 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  ads = FakeAds();
  final iap = FakeIap();
  rec = RecordingAudio();
  app = AppServices(store: await Store.load(), ads: ads, iap: iap, audio: rec);
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
    await t.tap(find.byKey(const Key('tile_daily')));
    await settle(t);
    expect(app.store.coins, 50);
    await t.tap(find.byKey(const Key('doubleDaily')));
    await settle(t);
    expect(app.store.coins, 100);
    expect(ads.rewardedCalls, 1);
    expect(find.byKey(const Key('tile_daily')), findsNothing);
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
    await t.tap(find.text('Resume'));
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
    await t.tap(find.byKey(const Key('settingsBtn')));
    await settle(t);
    await t.tap(find.byKey(const Key('soundSwitch')));
    await t.pump();
    expect(app.store.sound, isFalse);
    expect(app.audio.soundOn, isFalse);
    await t.tap(find.byKey(const Key('musicSwitch')));
    await t.pump();
    expect(app.store.music, isFalse);
    expect(app.audio.music.enabled, isFalse);
  });

  testWidgets('home screen is simple: one big PLAY, one row of 5 tiles, two corner buttons - nothing else', (t) async {
    await boot(t);
    await settle(t);
    expect(find.byKey(const Key('levelChip')), findsOneWidget);
    expect(find.text('Rookie'), findsOneWidget);
    expect(find.byKey(const Key('playButton')), findsOneWidget);
    for (final k in ['tile_daily', 'tile_wheel', 'tile_missions', 'tile_trophies', 'tile_shop', 'soundBtn', 'settingsBtn']) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    expect(find.text('FREE'), findsOneWidget); // free daily spin badge
    // clutter that used to be on the home screen now lives in the Shop / Settings
    expect(find.textContaining('Remove Ads'), findsNothing);
    expect(find.textContaining('Free coins'), findsNothing);
    expect(find.byKey(const Key('tip')), findsNothing);
  });

  testWidgets('there is clear space between PLAY and the secondary tiles, and nothing overlaps', (t) async {
    await boot(t);
    await settle(t);
    final play = t.getRect(find.byKey(const Key('playButton')));
    final tile = t.getRect(find.byKey(const Key('tile_wheel')));
    expect(tile.top - play.bottom, greaterThanOrEqualTo(24), reason: 'breathing room under the PLAY button');
    final best = t.getRect(find.byKey(const Key('best')));
    expect(play.top - best.bottom, greaterThanOrEqualTo(16));
  });

  testWidgets('home layout never moves (no shifting content)', (t) async {
    await boot(t);
    await settle(t);
    final p0 = t.getCenter(find.byKey(const Key('playButton')));
    final w0 = t.getCenter(find.byKey(const Key('tile_wheel')));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(seconds: 7));
      expect((t.getCenter(find.byKey(const Key('playButton'))) - p0).distance, lessThan(.5));
      expect((t.getCenter(find.byKey(const Key('tile_wheel'))) - w0).distance, lessThan(.5));
    }
  });

  testWidgets('sound button mutes everything (music + effects) and unmutes', (t) async {
    await boot(t);
    expect(app.store.anySound, isTrue);
    await t.tap(find.byKey(const Key('soundBtn')));
    await t.pump();
    expect(app.store.music, isFalse);
    expect(app.store.sound, isFalse);
    expect(app.audio.music.enabled, isFalse);
    expect(app.audio.soundOn, isFalse);
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    await t.tap(find.byKey(const Key('soundBtn')));
    await t.pump();
    expect(app.store.music && app.store.sound, isTrue);
    expect(app.audio.music.enabled, isTrue);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('settings Music switch really turns the music engine off', (t) async {
    await boot(t);
    await t.tap(find.byKey(const Key('settingsBtn')));
    await settle(t);
    expect(app.audio.music.enabled, isTrue);
    await t.tap(find.byKey(const Key('musicSwitch')));
    await t.pump();
    expect(app.audio.music.enabled, isFalse);
    expect(app.store.music, isFalse);
    await t.tap(find.byKey(const Key('musicSwitch')));
    await t.pump();
    expect(app.audio.music.enabled, isTrue);
  });

  testWidgets('coin badge has a spinning coin and counts up when coins are earned', (t) async {
    await boot(t, prefs: {'coins': 100});
    await settle(t);
    expect(find.byType(SpinningCoin), findsWidgets);
    expect(find.text('100'), findsOneWidget);
    app.store.addCoins(250);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    final mid = int.parse((t.widget(find.byKey(const Key('coins'))) as Text).data!);
    expect(mid, inExclusiveRange(100, 350), reason: 'number is animating between old and new value');
    await t.pump(const Duration(seconds: 1));
    expect(find.text('350'), findsOneWidget);
  });

  testWidgets('lucky wheel: free spin pays a prize once a day', (t) async {
    await boot(t);
    await t.tap(find.byKey(const Key('tile_wheel')));
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
    await t.tap(find.byKey(const Key('tile_trophies')));
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
    await t.tap(find.text('Resume'));
    await t.pump();
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('level badge is tappable and explains levels, XP and rewards', (t) async {
    await boot(t, prefs: {'xp': 100 + 140 + 180 + 220 + 30}); // level 5 (Stacker), 30 xp in
    expect(find.text('Stacker'), findsOneWidget);
    await t.tap(find.byKey(const Key('levelChip')));
    await settle(t);
    expect(find.byType(LevelScreen), findsOneWidget);
    expect(find.byKey(const Key('levelTitle')), findsOneWidget);
    expect(find.text('Stacker'), findsWidgets);
    expect(find.text('How do I earn XP?'), findsOneWidget);
    expect(find.text('What do I get for leveling up?'), findsOneWidget);
    expect(find.textContaining('XP to reach Level 6'), findsOneWidget);
    await t.dragUntilVisible(find.text('Titles'), find.byType(ListView), const Offset(0, -150));
    expect(find.text('Titles'), findsOneWidget);
    await t.dragUntilVisible(find.text('Architect'), find.byType(ListView), const Offset(0, -150));
    expect(find.text('Architect'), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget); // marks the player's current title
    await t.dragUntilVisible(find.byKey(const Key('back')), find.byType(ListView), const Offset(0, 300));
    await t.tap(find.byKey(const Key('back')));
    await settle(t);
    expect(find.byType(LevelScreen), findsNothing);
  });

  testWidgets('menus play the home music; the game plays a world track; back to menu returns to home', (t) async {
    await boot(t);
    await t.pump(const Duration(milliseconds: 200));
    expect(app.audio.music.current, homeTrack);
    await startPlaying(t);
    await t.pump(const Duration(milliseconds: 300));
    expect(app.audio.music.current, isNot(homeTrack));
    expect(app.audio.music.current, lessThan(6));
    await t.pump(const Duration(milliseconds: 900));
    await t.binding.handlePopRoute(); // pause
    await t.pump();
    await t.tap(find.text('🏠 Quit to menu'));
    await settle(t);
    await t.pump(const Duration(milliseconds: 200));
    expect(app.audio.music.current, homeTrack);
  });

  testWidgets('sound design: start sting, landing thuds, game-over sound, then applause for a new high score', (t) async {
    await boot(t, prefs: {'games': 5});
    await startPlaying(t);
    expect(rec.log, contains('start'));
    await t.pump(const Duration(milliseconds: 1000));
    final e = (t.state(find.byType(GameScreen)) as dynamic).engine;
    e.cur.x = e.top.x; // perfect
    await t.tap(find.byKey(const Key('playfield')));
    await t.pump(const Duration(milliseconds: 50));
    expect(rec.log, containsAll(['thudP', 'chime']));
    e.cur.x = e.top.x + 40; // good, not perfect
    await t.tap(find.byKey(const Key('playfield')));
    await t.pump(const Duration(milliseconds: 50));
    expect(rec.log, contains('thud'));
    expect(rec.log, isNot(contains('gameOver')));
    e.cur.x = e.top.x + 999; // miss
    await t.tap(find.byKey(const Key('playfield')));
    await t.pump(const Duration(milliseconds: 100));
    expect(rec.log, contains('gameOver'));
    expect(rec.log, isNot(contains('applause')), reason: 'applause waits for the result card');
    await t.pump(const Duration(milliseconds: 900));
    expect(rec.log, containsAll(['fanfare', 'applause'])); // first score ever => new best
  });

  testWidgets('no new-best applause when the score does not beat the best', (t) async {
    await boot(t, prefs: {'games': 5, 'best': 50});
    await startPlaying(t);
    await t.pump(const Duration(milliseconds: 1000));
    final e = (t.state(find.byType(GameScreen)) as dynamic).engine;
    e.cur.x = e.top.x + 999;
    await t.tap(find.byKey(const Key('playfield')));
    await t.pump(const Duration(seconds: 1));
    expect(rec.log, contains('gameOver'));
    expect(rec.log, isNot(contains('applause')));
  });
}