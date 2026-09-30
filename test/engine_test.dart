import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_stack/game/engine.dart';

GameEngine fresh({bool vip = false}) => GameEngine(rnd: Random(1))..reset(360, 640, isVip: vip);

void main() {
  test('perfect drop keeps width, scores, combos', () {
    final e = fresh();
    e.cur.x = e.top.x + 1; // within tolerance
    expect(e.drop(), DropResult.perfect);
    expect(e.score, 1);
    expect(e.combo, 1);
    expect(e.blocks.last.w, GameEngine.startWidth);
    expect(e.runCoins, 2);
  });

  test('imperfect drop trims block and spawns falling piece', () {
    final e = fresh();
    e.cur.x = e.top.x + 40;
    expect(e.drop(), DropResult.good);
    expect(e.blocks.last.w, closeTo(GameEngine.startWidth - 40, .001));
    expect(e.falling, isNotEmpty);
    expect(e.combo, 0);
    expect(e.runCoins, 1);
  });

  test('complete miss ends game; no further drops', () {
    final e = fresh();
    e.cur.x = e.top.x + e.top.w + 50;
    expect(e.drop(), DropResult.miss);
    expect(e.over, isTrue);
    expect(e.drop(), DropResult.none);
    expect(e.score, 0);
  });

  test('combo of 3+ grows the block back (capped)', () {
    final e = fresh();
    e.cur.x = e.top.x + 30;
    e.drop(); // width 170
    for (var i = 0; i < 20; i++) {
      e.cur.x = e.top.x;
      e.drop();
    }
    expect(e.blocks.last.w, 220);
    expect(e.combo, 20);
  });

  test('vip doubles coins', () {
    final e = fresh(vip: true);
    e.cur.x = e.top.x;
    e.drop();
    expect(e.runCoins, 4);
  });

  test('speed ramps but caps', () {
    final e = fresh();
    for (var i = 0; i < 200; i++) {
      e.cur.x = e.top.x;
      e.drop();
    }
    expect(e.speed, 7);
  });

  test('revive respawns and allows play', () {
    final e = fresh();
    e.cur.x = e.top.x;
    e.drop();
    e.cur.x = e.top.x + 999;
    e.drop();
    expect(e.over, isTrue);
    e.revive();
    expect(e.over, isFalse);
    e.cur.x = e.top.x;
    expect(e.drop(), DropResult.perfect);
    expect(e.score, 2);
  });

  test('block bounces at edges', () {
    final e = fresh();
    for (var i = 0; i < 1000; i++) {
      e.update(1);
      expect(e.cur.x, inInclusiveRange(-e.cur.w - 10, e.width + 10));
    }
  });
}
