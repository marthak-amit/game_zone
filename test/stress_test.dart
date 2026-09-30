import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_stack/main.dart';
import 'package:sky_stack/services/ads.dart';
import 'package:sky_stack/services/app_services.dart';
import 'package:sky_stack/services/audio.dart';
import 'package:sky_stack/services/iap.dart';
import 'package:sky_stack/services/music.dart';
import 'package:sky_stack/services/sfx_player.dart';
import 'package:sky_stack/store.dart';
import 'package:sky_stack/ui/game_screen.dart';

class InstantAds implements AdService {
  int interstitials = 0;
  @override
  Future<void> init() async {}
  @override
  Future<bool> showRewarded(BuildContext c, String r) async => true;
  @override
  Future<void> showInterstitial(BuildContext c) async => interstitials++;
}

/// An ad SDK that never calls back (the worst case that used to freeze "Play again").
class HangingAds implements AdService {
  @override
  Future<void> init() async {}
  @override
  Future<bool> showRewarded(BuildContext c, String r) => Completer<bool>().future;
  @override
  Future<void> showInterstitial(BuildContext c) => Completer<void>().future;
}

class _NoIap implements IapService {
  @override
  Map<String, String> get prices => const {};
  @override
  Future<void> init(GrantCallback g) async {}
  @override
  Future<void> restore() async {}
  @override
  Future<void> buy(BuildContext c, String sku) async {}
}

class _Pool implements SfxPool {
  final void Function() hit;
  _Pool(this.hit);
  @override
  Future<void> start(double v) async => hit();
}

class _Shot implements OneShot {
  @override
  Future<void> play(Uint8List b, double v) async {}
}

class _MusicPlayer implements TrackPlayer {
  @override
  Future<void> play(Uint8List wav, double volume) async {}
  @override
  Future<void> setVolume(double v) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

int pools = 0, shared = 0, sfxStarts = 0;

Future<void> boot(WidgetTester t, AdService ads) async {
  SharedPreferences.setMockInitialValues({'games': 10});
  t.view.physicalSize = const Size(400 * 3, 800 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  pools = shared = sfxStarts = 0;
  final audio = Audio(
    sfx: SfxPlayer(
      minGap: Duration.zero,
      poolFactory: (b) async {
        pools++;
        return _Pool(() => sfxStarts++);
      },
      oneShotFactory: () {
        shared++;
        return _Shot();
      },
    ),
    music: Music(fadeStep: Duration.zero, playerFactory: _MusicPlayer.new, trackBuilder: (t) async => Uint8List(8)),
  );
  app = AppServices(store: await Store.load(), ads: ads, iap: _NoIap(), audio: audio);
  await t.pumpWidget(const SkyStackApp());
}

Future<void> playOneGame(WidgetTester t, {int perfects = 8}) async {
  await t.pump(const Duration(milliseconds: 1000)); // get-ready grace
  final e = (t.state(find.byType(GameScreen)) as dynamic).engine;
  for (var k = 0; k < perfects; k++) {
    e.cur.x = e.top.x;
    await t.tap(find.byKey(const Key('playfield')));
    await t.pump(const Duration(milliseconds: 60));
  }
  e.cur.x = e.top.x + 999;
  await t.tap(find.byKey(const Key('playfield')));
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 900)); // result card
  expect(find.byKey(const Key('finalScore')), findsOneWidget);
}

void main() {
  testWidgets('12 games in a row with REAL sound code: stays responsive, native players stay bounded', (t) async {
    final ads = InstantAds();
    await boot(t, ads);
    await t.tap(find.byKey(const Key('playButton')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    for (var g = 1; g <= 12; g++) {
      await playOneGame(t);
      await t.tap(find.text('↻ Play again'));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('finalScore')), findsNothing, reason: 'game $g: next round must start');
    }
    expect(ads.interstitials, greaterThanOrEqualTo(1), reason: 'interstitials still appear (capped)');
    expect(sfxStarts, greaterThan(100), reason: 'sounds were actually triggered');
    // The old code created ~2 native players per tap (hundreds by now). Now it is a small constant.
    expect(pools, lessThanOrEqualTo(16), reason: 'preloaded sound pools must not grow with play time');
    expect(shared, lessThanOrEqualTo(3));
  });

  testWidgets('an ad that never responds cannot freeze "Play again"', (t) async {
    await boot(t, HangingAds());
    // make the interstitial due immediately
    await t.tap(find.byKey(const Key('playButton')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    for (var g = 1; g <= 4; g++) {
      await playOneGame(t, perfects: 3);
      await t.tap(find.text('↻ Play again'));
      await t.pump(const Duration(milliseconds: 200));
      // wait out any ad timeout (45 s) in realistic frames
      for (var i = 0; i < 50 && find.byKey(const Key('finalScore')).evaluate().isNotEmpty; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      expect(find.byKey(const Key('finalScore')), findsNothing, reason: 'game $g: Play again must always start a new round');
    }
  });

  testWidgets('rapid repeated taps on Play again start exactly one new round (one interstitial)', (t) async {
    final ads = InstantAds();
    await boot(t, ads);
    await t.tap(find.byKey(const Key('playButton')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    for (var g = 1; g <= 2; g++) {
      await playOneGame(t, perfects: 3);
      await t.tap(find.text('↻ Play again'));
      await t.pump(const Duration(milliseconds: 300));
    }
    await playOneGame(t, perfects: 4); // the 3rd game is when the interstitial is due
    final spot = t.getCenter(find.text('↻ Play again'));
    final before = ads.interstitials;
    for (var i = 0; i < 5; i++) {
      await t.tapAt(spot); // mash the button
      await t.pump(const Duration(milliseconds: 5));
    }
    await t.pump(const Duration(milliseconds: 400));
    expect(ads.interstitials - before, lessThanOrEqualTo(1), reason: 'mashing must not stack several ads');
    expect(find.byKey(const Key('finalScore')), findsNothing);
    final state = t.state(find.byType(GameScreen)) as dynamic;
    expect(state.engine.blocks.length, lessThan(3), reason: 'a fresh round started (taps on the field are ignored during get-ready)');
  });
}
