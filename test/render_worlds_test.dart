import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_stack/game/engine.dart';
import 'package:sky_stack/game/scenery.dart';
import 'package:sky_stack/game/worlds.dart';
import 'package:sky_stack/services/app_services.dart';
import 'package:sky_stack/store.dart';
import 'package:sky_stack/ui/game_screen.dart';

/// Renders every world with a tower to PNG files (for visual review). Set RENDER_DIR to choose the folder.
void main() {
  testWidgets('render each world to PNG', (t) async {
    SharedPreferences.setMockInitialValues({});
    app = AppServices(store: await Store.load());
    final dir = Directory(Platform.environment['RENDER_DIR'] ?? 'build/worlds')..createSync(recursive: true);
    t.view.physicalSize = const Size(400, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (var i = 0; i < worlds.length; i++) {
      final key = GlobalKey();
      final engine = GameEngine()..reset(400, 780);
      for (var k = 0; k < 16 + i; k++) {
        engine.cur.x = k % 3 == 0 ? engine.top.x + 20 : engine.top.x;
        engine.drop();
        engine.update(30);
      }
      engine.update(400);
      engine.worldPos = i.toDouble();
      final scenery = Scenery();
      final ws = WorldState.at(i.toDouble());
      for (var k = 0; k < 400; k++) {
        scenery.update(1 / 60, ws);
      }
      scenery.flash = i == 3 ? .9 : 0;
      await t.pumpWidget(RepaintBoundary(
        key: key,
        child: SizedBox(width: 400, height: 780, child: CustomPaint(painter: GamePainter(engine, scenery, () => ws, ValueNotifier(0), () => false))),
      ));
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage();
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/world_${i}_${worlds[i].id}.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
    expect(dir.listSync().where((f) => f.path.contains('world_')).length, greaterThanOrEqualTo(worlds.length));
  });

  testWidgets('render menu background + early game', (t) async {
    SharedPreferences.setMockInitialValues({});
    app = AppServices(store: await Store.load());
    final dir = Directory(Platform.environment['RENDER_DIR'] ?? 'build/worlds')..createSync(recursive: true);
    t.view.physicalSize = const Size(400, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final i in [1, 2, 3]) {
      final key = GlobalKey();
      await t.pumpWidget(RepaintBoundary(key: key, child: Directionality(textDirection: TextDirection.ltr, child: SceneryView(fixed: i.toDouble(), decorTower: true))));
      await t.pump(const Duration(seconds: 3));
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final data = await (await b.toImage()).toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/menu_$i.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
    final key = GlobalKey();
    final engine = GameEngine()..reset(400, 780);
    for (var k = 0; k < 3; k++) {
      engine.cur.x = engine.top.x;
      engine.drop();
      engine.update(30);
    }
    engine.worldPos = 2;
    final scenery = Scenery();
    final ws = WorldState.at(2);
    await t.pumpWidget(RepaintBoundary(key: key, child: SizedBox(width: 400, height: 780, child: CustomPaint(painter: GamePainter(engine, scenery, () => ws, ValueNotifier(0), () => false)))));
    await t.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final data = await (await b.toImage()).toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/early_night.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
