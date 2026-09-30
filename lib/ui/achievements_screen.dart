import 'package:flutter/material.dart';
import '../achievements.dart';
import '../services/app_services.dart';
import 'widgets.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});
  @override
  Widget build(BuildContext context) => SubScreen(
        title: 'Achievements',
        child: ListenableBuilder(
          listenable: app.store,
          builder: (_, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('${app.store.achievementsUnlocked} / ${achievements.length} unlocked',
                      key: const Key('achCount'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              for (final a in achievements) _row(a),
            ],
          ),
        ),
      );

  Widget _row(Achievement a) {
    final done = app.store.hasAchievement(a.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(color: done ? const Color(0xE6103A25) : kCardColor, border: done ? const Color(0xFF5BE7A9) : null),
      child: Row(children: [
        Opacity(opacity: done ? 1 : .35, child: Text(a.icon, style: const TextStyle(fontSize: 30))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(a.desc, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ),
        Text(done ? '✓' : '🪙${a.reward}', style: TextStyle(fontWeight: FontWeight.w800, color: done ? const Color(0xFF5BE7A9) : Colors.amber)),
      ]),
    );
  }
}
