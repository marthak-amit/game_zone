import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int get games => _p.getInt('games') ?? 0;
  int get blocksTotal => _p.getInt('blocks') ?? 0;
  int get streak => _p.getInt('streak') ?? 0;
  String get dailyDate => _p.getString('dailyDate') ?? '';
  bool get sound => _p.getBool('sound') ?? true;
  bool get vibe => _p.getBool('vibe') ?? true;
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
    missions = [
      Mission('score', 'Reach score 10 in one game', 10, 50),
      Mission('perfect', 'Land 15 perfect drops', 15, 60),
      Mission('games', 'Play 3 games', 3, 40),
    ];
    _saveMissions();
  }

  void _saveMissions() =>
      _p.setString('missions', jsonEncode({'date': todayKey, 'list': missions.map((m) => m.toJson()).toList()}));

  void missionEvent(String type, int v) {
    _ensureMissions();
    for (final m in missions) {
      if (m.type != type) continue;
      m.progress = type == 'score' ? (v > m.progress ? v : m.progress) : m.progress + v;
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
}
