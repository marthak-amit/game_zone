import 'package:flutter/material.dart';
import '../services/app_services.dart';
import '../store.dart';
import 'widgets.dart';

/// Explains the level system: what a level is, how to earn XP, and the rewards.
class LevelScreen extends StatelessWidget {
  const LevelScreen({super.key});

  // First level of each title (matches Store.title: a new title every 4 levels).
  static const _titles = [
    ('Rookie', 1),
    ('Stacker', 5),
    ('Builder', 9),
    ('Architect', 13),
    ('Skyline Master', 17),
    ('Sky Legend', 21),
  ];

  @override
  Widget build(BuildContext context) => SubScreen(
        title: 'Your Level',
        child: ListenableBuilder(
          listenable: app.store,
          builder: (_, _) {
            final s = app.store;
            final left = s.xpNeeded - s.xpInLevel;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(border: const Color(0xFFF59E0B)),
                child: Column(children: [
                  LevelBadge(level: s.level, size: 92),
                  const SizedBox(height: 10),
                  Text(s.title, key: const Key('levelTitle'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  Text('Level ${s.level}', style: const TextStyle(fontSize: 15, color: Colors.white70)),
                  const SizedBox(height: 14),
                  XpBar(value: s.xpInLevel / s.xpNeeded, height: 14),
                  const SizedBox(height: 6),
                  Text('${s.xpInLevel} / ${s.xpNeeded} XP', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('$left XP to reach Level ${s.level + 1}  ·  reward 🪙${50 * (s.level + 1)}',
                      key: const Key('xpLeft'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF5BE7A9), fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 14),
              _section('How do I earn XP?', [
                _row(Icons.videogame_asset_rounded, 'Finish any game', '+10 XP'),
                _row(Icons.layers_rounded, 'Every block you stack', '+10 XP each'),
                _row(Icons.stars_rounded, 'Every PERFECT drop', '+5 XP bonus'),
              ]),
              const SizedBox(height: 14),
              _section('What do I get for leveling up?', [
                _row(Icons.monetization_on_rounded, 'Bonus coins, every level', '🪙 50 × new level'),
                _row(Icons.military_tech_rounded, 'A new title every 4 levels', 'see below'),
              ]),
              const SizedBox(height: 14),
              _section('Titles', [
                for (var i = 0; i < _titles.length; i++)
                  _titleRow(_titles[i].$1, _titles[i].$2, i + 1 < _titles.length ? _titles[i + 1].$2 - 1 : null, s),
              ]),
            ]);
          },
        ),
      );

  Widget _section(String title, List<Widget> kids) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...kids,
        ]),
      );

  Widget _row(IconData icon, String text, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, color: const Color(0xFFFFC145), size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5BE7A9))),
        ]),
      );

  Widget _titleRow(String name, int from, int? to, Store s) {
    final current = s.title == name;
    final reached = s.level >= from;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(reached ? Icons.check_circle_rounded : Icons.lock_rounded, size: 20, color: reached ? const Color(0xFF5BE7A9) : Colors.white38),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name, style: TextStyle(fontWeight: current ? FontWeight.w900 : FontWeight.w500, color: reached ? Colors.white : Colors.white54)),
        ),
        Text(to == null ? 'Level $from+' : 'Level $from–$to', style: TextStyle(color: reached ? Colors.white70 : Colors.white38)),
        if (current) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(10)), child: const Text('YOU', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900))),
      ]),
    );
  }
}
