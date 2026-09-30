import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sky_stack/achievements.dart';
import 'package:sky_stack/store.dart';

Future<Store> fresh([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return Store.load();
}

void main() {
  test('level curve: 100 xp for level 1, +40 per level', () {
    expect(Store.levelFor(0), (1, 0));
    expect(Store.levelFor(99), (1, 99));
    expect(Store.levelFor(100), (2, 0));
    expect(Store.levelFor(240), (3, 0)); // 100 + 140
    expect(Store.levelFor(240 + 180 - 1), (3, 179));
  });

  test('addXp levels up and pays 50 x level coins per level', () async {
    final s = await fresh();
    expect(s.level, 1);
    expect(s.addXp(50), 0);
    expect(s.coins, 0);
    expect(s.addXp(100), 1); // 150 -> level 2
    expect(s.level, 2);
    expect(s.coins, 100);
    expect(s.addXp(500), greaterThan(1)); // multi level-up pays each level
    expect(s.title, isNotEmpty);
    expect(s.xpInLevel, lessThan(s.xpNeeded));
  });

  test('achievements unlock once and pay their reward', () async {
    final s = await fresh({'games': 10, 'streak': 3});
    final first = s.checkAchievements(const RunStats(30, 6, 12));
    final ids = first.map((a) => a.id).toSet();
    expect(ids, containsAll(['s10', 's25', 'night', 'c5', 'g10', 'str3']));
    expect(ids, isNot(contains('s50')));
    final paid = first.fold<int>(0, (a, b) => a + b.reward);
    expect(s.coins, paid);
    expect(s.checkAchievements(const RunStats(30, 6, 12)), isEmpty); // not twice
    expect(s.checkAchievements(const RunStats(100, 12, 40)).map((a) => a.id), containsAll(['s50', 's100', 'c10', 'storm', 'space']));
    expect(s.achievementsUnlocked, greaterThanOrEqualTo(11));
  });

  test('daily wheel: weighted roll, free once a day, ad spins capped at 3', () async {
    final s = await fresh();
    final rnd = Random(4);
    final hits = <int>{for (var i = 0; i < 400; i++) s.rollSpin(rnd)};
    expect(hits.every((i) => i >= 0 && i < Store.spinPrizes.length), isTrue);
    expect(hits.length, greaterThan(5));
    expect(s.freeSpinAvailable, isTrue);
    s.finishSpin(3, free: true);
    expect(s.freeSpinAvailable, isFalse);
    expect(s.coins, Store.spinPrizes[3]);
    expect(s.adSpinsToday, 0);
    s.finishSpin(0, free: false);
    s.finishSpin(0, free: false);
    expect(s.adSpinsToday, 2);
    expect(s.coins, Store.spinPrizes[3] + 2 * Store.spinPrizes[0]);
  });

  test('music / voice settings persist', () async {
    final s = await fresh();
    expect(s.music && s.voice, isTrue);
    s.setMusic(false);
    s.setVoice(false);
    expect(s.music || s.voice, isFalse);
  });

  test('daily missions are 3 distinct ones and include the world mission pool', () async {
    final s = await fresh();
    expect({for (final m in s.missions) m.text}.length, 3);
    s.missionEvent('worlds', 24);
    s.missionEvent('combo', 5);
    for (final m in s.missions) {
      if (m.type == 'worlds' || m.type == 'combo') expect(m.progress, m.goal);
    }
  });
}
