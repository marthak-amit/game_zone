import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_stack/services/app_services.dart';
import 'package:sky_stack/store.dart';
import 'package:sky_stack/ui/achievements_screen.dart';
import 'package:sky_stack/ui/game_screen.dart';
import 'package:sky_stack/ui/menu_screen.dart';
import 'package:sky_stack/ui/settings_screen.dart';
import 'package:sky_stack/ui/shop_screen.dart';
import 'package:sky_stack/ui/spin_screen.dart';

/// Renders the real screens (with the real Roboto font) to PNGs for visual review.
/// Set RENDER_DIR. Skipped unless RENDER_UI=1 so normal test runs stay fast.
void main() {
  final enabled = Platform.environment['RENDER_UI'] == '1';
  testWidgets('render screens', (t) async {
    final dir = Directory(Platform.environment['RENDER_DIR'] ?? 'build/ui')..createSync(recursive: true);
    final font = File('/opt/sdk/flutter/bin/cache/artifacts/material_fonts/Roboto-Bold.ttf').readAsBytesSync();
    final loader = FontLoader('Roboto')..addFont(Future.value(ByteData.view(font.buffer)));
    await loader.load();
    t.view.physicalSize = const Size(400 * 2, 800 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);

    Future<void> shot(String name) async {
      final key = GlobalKey();
      await t.runAsync(() async {
        final b = t.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
        final data = await (await b.toImage(pixelRatio: 1)).toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
      expect(key, isNotNull);
    }

    Future<void> show(Widget home, Map<String, Object> prefs, String name, {int pumpMs = 1500, Future<void> Function()? act}) async {
      SharedPreferences.setMockInitialValues(prefs);
      app = AppServices(store: await Store.load());
      app.audio.available = false;
      await t.pumpWidget(RepaintBoundary(
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto', useMaterial3: true), home: home),
      ));
      await t.pump(const Duration(milliseconds: 400));
      if (act != null) await act();
      await t.pump(Duration(milliseconds: pumpMs));
      await shot(name);
    }

    final prefs = <String, Object>{'coins': 1240, 'best': 37, 'games': 14, 'xp': 420, 'streak': 3, 'ach_s10': true, 'ach_c5': true};
    await show(const MenuScreen(), prefs, 'ui_menu');
    await show(const SpinScreen(), prefs, 'ui_spin');
    await show(const AchievementsScreen(), prefs, 'ui_achievements');
    await show(const ShopScreen(), prefs, 'ui_shop');
    await show(const SettingsScreen(), prefs, 'ui_settings');
    await show(const GameScreen(), {'games': 5}, 'ui_gameover_newbest', pumpMs: 2200, act: () async {
      final st = t.state(find.byType(GameScreen)) as dynamic;
      for (var i = 0; i < 9; i++) {
        st.engine.cur.x = st.engine.top.x; // perfect drop
        await t.tap(find.byKey(const Key('playfield')));
        await t.pump(const Duration(milliseconds: 120));
      }
      st.engine.cur.x = st.engine.top.x + 999; // then miss
      await t.tap(find.byKey(const Key('playfield')));
      for (var i = 0; i < 25; i++) {
        await t.pump(const Duration(milliseconds: 100)); // let count-up + confetti animate
      }
    });
  }, skip: !enabled);
}
