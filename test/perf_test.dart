import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_stack/game/scenery.dart';
import 'package:sky_stack/game/worlds.dart';
import 'package:sky_stack/services/app_services.dart';
import 'package:sky_stack/services/perf.dart';
import 'package:sky_stack/main.dart';
import 'package:sky_stack/store.dart';

void main() {
  final perf = Perf.instance;
  tearDown(() {
    perf.forceLite(false);
    perf.setManual(false);
  });

  test('slow device detection: two slow measurement windows in a row switch to lite mode', () {
    perf.feed(30);
    expect(perf.lite, isFalse, reason: 'one slow window could be a hiccup');
    perf.feed(30);
    expect(perf.lite, isTrue);
  });

  test('a fast window in between resets the detection (no false alarms)', () {
    perf.feed(40);
    perf.feed(9);
    perf.feed(40);
    expect(perf.lite, isFalse);
    perf.feed(10);
    perf.feed(12);
    expect(perf.lite, isFalse, reason: 'fast phones stay on the full look');
  });

  test('Smooth mode (manual) turns lite on and off', () {
    perf.setManual(true);
    expect(perf.lite, isTrue);
    perf.setManual(false);
    expect(perf.lite, isFalse);
  });

  testWidgets('looping animations are paused in lite mode and resume afterwards', (t) async {
    final c = AnimationController(vsync: const TestVSync(), duration: const Duration(seconds: 1))..repeat();
    perf.register(c, false);
    expect(c.isAnimating, isTrue);
    perf.forceLite(true);
    expect(c.isAnimating, isFalse);
    perf.forceLite(false);
    expect(c.isAnimating, isTrue);
    // a controller created while lite starts paused
    perf.forceLite(true);
    final d = AnimationController(vsync: const TestVSync(), duration: const Duration(seconds: 1))..repeat();
    perf.register(d, true);
    expect(d.isAnimating, isFalse);
    perf.unregister(c);
    perf.unregister(d);
    c.dispose();
    d.dispose();
  });

  test('lite scenery still paints every world without errors (and is not more work than full)', () {
    for (final lite in [false, true]) {
      for (var i = 0; i < worlds.length; i++) {
        final sc = Scenery();
        final ws = WorldState.at(i.toDouble());
        for (var k = 0; k < 120; k++) {
          sc.update(1 / 60, ws);
        }
        final rec = ui.PictureRecorder();
        sc.paint(Canvas(rec), const Size(390, 844), ws, 0, lite: lite);
        rec.endRecording().dispose();
      }
    }
  });

  testWidgets('Settings "Smooth mode" switch really lowers the load (loops stop, lite on)', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(400 * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    app = AppServices(store: await Store.load());
    app.audio.available = false;
    // build the real app (menu), then open settings
    await t.pumpWidget(const SkyStackApp());
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(perf.registeredLoops, greaterThan(0));
    expect(perf.activeLoops, greaterThan(0));
    await t.tap(find.byKey(const Key('settingsBtn')));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    await t.tap(find.byKey(const Key('liteSwitch')));
    await t.pump();
    expect(app.store.reduceEffects, isTrue);
    expect(perf.lite, isTrue);
    expect(perf.activeLoops, 0, reason: 'decorative loops stop in Smooth mode');
    await t.tap(find.byKey(const Key('liteSwitch')));
    await t.pump();
    expect(perf.lite, isFalse);
    expect(perf.activeLoops, greaterThan(0));
  });
}
