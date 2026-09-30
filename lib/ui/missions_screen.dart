import 'package:flutter/material.dart';
import '../services/app_services.dart';
import "../store.dart";
import "widgets.dart";

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});
  @override
  Widget build(BuildContext context) => SubScreen(
        title: 'Daily Missions',
        child: ListenableBuilder(
          listenable: app.store,
          builder: (_, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < app.store.missions.length; i++) _row(app.store.missions[i], i),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('New missions every day!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      );

  Widget _row(Mission m, int i) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.text, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: (m.progress / m.goal).clamp(0.0, 1.0), color: kGold, backgroundColor: Colors.white24),
              Text('${m.progress.clamp(0, m.goal)}/${m.goal}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
          ),
          const SizedBox(width: 12),
          FilledButton(
            key: Key('claim_$i'),
            style: FilledButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.black, disabledBackgroundColor: Colors.white24, disabledForegroundColor: Colors.white),
            onPressed: m.ready ? () {
              app.store.claimMission(m);
              app.audio.beep(880, .2);
            } : null,
            child: Text(m.claimed ? '✓ Done' : '🪙 ${m.reward}'),
          ),
        ]),
      );
}
