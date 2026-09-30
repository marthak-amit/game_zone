import 'package:flutter/material.dart';
import '../services/app_services.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => SubScreen(
        title: 'Settings & Stats',
        child: ListenableBuilder(
          listenable: app.store,
          builder: (_, _) {
            final s = app.store;
            return ListView(padding: const EdgeInsets.all(16), children: [
              CardBox(child: Column(children: [
              SwitchListTile(key: const Key('musicSwitch'), title: const Text('🎵 Music'), value: s.music, onChanged: s.setMusic),
              SwitchListTile(key: const Key('soundSwitch'), title: const Text('🔊 Sound effects'), value: s.sound, onChanged: s.setSound),
              SwitchListTile(key: const Key('vibeSwitch'), title: const Text('📳 Vibration'), value: s.vibe, onChanged: s.setVibe),
              ])),
              const SizedBox(height: 12),
              CardBox(child: Column(children: [
              ListTile(title: const Text('Level'), trailing: Text('${s.level} · ${s.title}')),
              ListTile(title: const Text('Games played'), trailing: Text('${s.games}')),
              ListTile(title: const Text('Blocks stacked'), trailing: Text('${s.blocksTotal}')),
              ListTile(title: const Text('Best score'), trailing: Text('${s.best}')),
              ListTile(title: const Text('Login streak'), trailing: Text('${s.streak} days')),
              ListTile(title: const Text('Achievements'), trailing: Text('${s.achievementsUnlocked}')),
              ])),
              Center(child: TextButton(onPressed: app.iap.restore, child: const Text('Restore purchases'))),
            ]);
          },
        ),
      );
}
