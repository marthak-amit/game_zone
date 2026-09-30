import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'achievements.dart';
import 'game/worlds.dart';

class Skin {
  final String id, name;
  final int price; // -1 = VIP only
  final double hue, step;
  const Skin(this.id, this.name, this.price, this.hue, this.step);
}

const skins = <Skin>[
  Skin('neon', 'Neon', 0, 190, 12),
  Skin('sunset', 'Sunset', 300, 10, 9),
  Skin('candy', 'Candy', 600, 310, 14),
  Skin('forest', 'Forest', 1000, 110, 8),
  Skin('ocean', 'Ocean', 1500, 220, 10),
  Skin('gold', 'Gold VIP', -1, 45, 4),
];

class Mission {
  final String type, text;
  final int goal, reward;
  int progress;
  bool claimed;
  Mission(this.type, this.text, this.goal, this.reward, {this.progress = 0, this.claimed = false});
  bool get ready => progress >= goal && !claimed;
  Map<String, dynamic> toJson() => {'t': type, 'x': text, 'g': goal, 'r': reward, 'p': progress, 'c': claimed};
  factory Mission.fromJson(Map<String, dynamic> j) =>
      Mission(j['t'], j['x'], j['g'], j['r'], progress: j['p'], claimed: j['c']);
}

/// All persisted player data. Listen to it to rebuild UI.
class Store extends ChangeNotifier {
  final SharedPreferences _p;
  Store(this._p) {
    _ensureMissions();
  }

  static Future<Store> load() async => Store(await SharedPreferences.getInstance());

  int get coins => _p.getInt('coins') ?? 0;
  int get best => _p.getInt('best') ?? 0;
  String get worldPref => _p.getString('world') ?? 'auto';
  bool ownsWorld(String id) => id == 'auto' || vip || (_p.getBool('own_w_$id') ?? false);
  void buyWorld(String id) => _set('own_w_$id', true);
  void setWorld(String id) => _set('world', id);
  /// World index to lock the background to, or null for the automatic cycle.
  int? get fixedWorldIndex {
    final i = worlds.indexWhere((w) => w.id == worldPref);
    return i < 0 || !ownsWorld(worldPref) ? null : i;
  }
  int get games => _p.getInt('games') ?? 0;
  int get blocksTotal => _p.getInt('blocks') ?? 0;
  int get streak => _p.getInt('streak') ?? 0;
  String get dailyDate => _p.getString('dailyDate') ?? '';
  bool get sound => _p.getBool('sound') ?? true;
  bool get vibe => _p.getBool('vibe') ?? true;
  bool get music => _p.getBool('music') ?? true;
  bool get noAds => _p.getBool('noAds') ?? false;
  bool get vip => _p.getBool('vip') ?? false;
  String get skinId => _p.getString('skin') ?? 'neon';
  Skin get skin => skins.firstWhere((s) => s.id == skinId, orElse: () => skins.first);

  bool owns(Skin s) => s.price == 0 || (s.id == 'gold' && vip) || (_p.getBool('own_${s.id}') ?? false);

  void _set(String k, Object v) {
    if (v is int) _p.setInt(k, v);
    if (v is bool) _p.setBool(k, v);
    if (v is String) _p.setString(k, v);
    notifyListeners();
  }

  void addCoins(int n) => _set('coins', (coins + n).clamp(0, 1 << 30));
  bool spend(int n) {
    if (coins < n) return false;
    addCoins(-n);
    return true;
  }

  void setSound(bool v) => _set('sound', v);
  void setVibe(bool v) => _set('vibe', v);
  void setMusic(bool v) => _set('music', v);
  void setNoAds() => _set('noAds', true);
  void setVip() {
    _p.setBool('vip', true);
    _set('noAds', true);
  }

  void buySkin(Skin s) => _set('own_${s.id}', true);
  void equip(Skin s) => _set('skin', s.id);

  /// Records a finished game; returns true if it is a new best.
  bool recordGame(int score) {
    final isBest = score > best;
    if (isBest) _p.setInt('best', score);
    _p.setInt('games', games + 1);
    _p.setInt('blocks', blocksTotal + score);
    notifyListeners();
    return isBest && score > 0;
  }

  // ---- daily reward ----
  static String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
  String get todayKey => dayKey(DateTime.now());
  bool get dailyAvailable => dailyDate != todayKey;
  int get nextStreak =>
      dailyDate == dayKey(DateTime.now().subtract(const Duration(days: 1))) ? streak + 1 : 1;
  int get dailyReward => 50 * nextStreak.clamp(1, 7);

  /// Claims the daily reward and returns the amount.
  int claimDaily() {
    final reward = dailyReward, s = nextStreak;
    _p.setInt('streak', s);
    _p.setString('dailyDate', todayKey);
    addCoins(reward);
    return reward;
  }

  // ---- missions ----
  late List<Mission> missions;
  void _ensureMissions() {
    final raw = _p.getString('missions');
    if (raw != null) {
      final j = jsonDecode(raw);
      if (j['date'] == todayKey) {
        missions = (j['list'] as List).map((e) => Mission.fromJson(e)).toList();
        return;
      }
    }
    // 3 different missions per day from a pool, picked deterministically from the date.
    final pool = <Mission Function()>[
      () => Mission('score', 'Reach score 10 in one game', 10, 50),
      () => Mission('score', 'Reach score 25 in one game', 25, 110),
      () => Mission('perfect', 'Land 15 perfect drops', 15, 60),
      () => Mission('games', 'Play 3 games', 3, 40),
      () => Mission('combo', 'Reach a 5x perfect combo', 5, 70),
      () => Mission('worlds', 'Reach the Starry Night world (score 24)', 24, 90),
    ];
    final now = DateTime.now();
    final seed = now.year * 1000 + now.month * 50 + now.day;
    final idx = List<int>.generate(pool.length, (i) => i)..shuffle(Random(seed));
    missions = [for (final i in idx.take(3)) pool[i]()];
    _saveMissions();
  }

  void _saveMissions() =>
      _p.setString('missions', jsonEncode({'date': todayKey, 'list': missions.map((m) => m.toJson()).toList()}));

  void missionEvent(String type, int v) {
    _ensureMissions();
    for (final m in missions) {
      if (m.type != type) continue;
      m.progress = (type == 'score' || type == 'combo' || type == 'worlds') ? (v > m.progress ? v : m.progress) : m.progress + v;
    }
    _saveMissions();
    notifyListeners();
  }

  void claimMission(Mission m) {
    if (!m.ready) return;
    m.claimed = true;
    addCoins(m.reward);
    _saveMissions();
  }

  int get missionsReady => missions.where((m) => m.ready).length;

  // ---- XP & levels ----
  int get xp => _p.getInt('xp') ?? 0;
  static int xpToNext(int level) => 100 + 40 * (level - 1);

  /// Current level (starts at 1).
  int get level => levelFor(xp).$1;

  /// XP earned inside the current level.
  int get xpInLevel => levelFor(xp).$2;
  int get xpNeeded => xpToNext(level);
  static const _titles = ['Rookie', 'Stacker', 'Builder', 'Architect', 'Skyline Master', 'Sky Legend'];
  String get title => _titles[((level - 1) ~/ 4).clamp(0, _titles.length - 1)];

  static (int, int) levelFor(int xp) {
    var l = 1, rest = xp;
    while (rest >= xpToNext(l)) {
      rest -= xpToNext(l);
      l++;
    }
    return (l, rest);
  }

  /// Adds XP; returns the number of levels gained (each pays 50 x new level coins).
  int addXp(int n) {
    final before = level;
    _p.setInt('xp', xp + n);
    final after = level;
    for (var l = before + 1; l <= after; l++) {
      addCoins(50 * l);
    }
    notifyListeners();
    return after - before;
  }

  // ---- achievements ----
  bool hasAchievement(String id) => _p.getBool('ach_$id') ?? false;
  int get achievementsUnlocked => achievements.where((a) => hasAchievement(a.id)).length;

  /// Unlocks (and pays) every achievement whose condition is now met.
  List<Achievement> checkAchievements(RunStats r) {
    final got = <Achievement>[];
    for (final a in achievements) {
      if (!hasAchievement(a.id) && a.test(this, r)) {
        _p.setBool('ach_${a.id}', true);
        addCoins(a.reward);
        got.add(a);
      }
    }
    if (got.isNotEmpty) notifyListeners();
    return got;
  }

  // ---- daily lucky wheel ----
  static const spinPrizes = [25, 50, 30, 100, 40, 250, 60, 500];
  static const _spinWeights = [20, 18, 18, 10, 16, 3, 12, 3];
  bool get freeSpinAvailable => (_p.getString('spinDate') ?? '') != todayKey;
  int get adSpinsToday => (_p.getString('adSpinDate') ?? '') == todayKey ? (_p.getInt('adSpins') ?? 0) : 0;
  static const maxAdSpins = 3;

  /// Picks a prize index (weighted). Call [finishSpin] once the wheel animation ends.
  int rollSpin([Random? rnd]) {
    final r = (rnd ?? Random()).nextInt(_spinWeights.reduce((a, b) => a + b));
    var acc = 0;
    for (var i = 0; i < _spinWeights.length; i++) {
      acc += _spinWeights[i];
      if (r < acc) return i;
    }
    return 0;
  }

  void finishSpin(int prizeIndex, {required bool free}) {
    if (free) {
      _p.setString('spinDate', todayKey);
    } else {
      _p.setString('adSpinDate', todayKey);
      _p.setInt('adSpins', adSpinsToday + 1);
    }
    addCoins(spinPrizes[prizeIndex]);
  }
}
