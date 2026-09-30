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
              SwitchListTile(key: const Key('soundSwitch'), title: const Text('Sound'), value: s.sound, onChanged: s.setSound),
              SwitchListTile(key: const Key('vibeSwitch'), title: const Text('Vibration'), value: s.vibe, onChanged: s.setVibe),
              const Divider(),
              ListTile(title: const Text('Games played'), trailing: Text('${s.games}')),
              ListTile(title: const Text('Blocks stacked'), trailing: Text('${s.blocksTotal}')),
              ListTile(title: const Text('Best score'), trailing: Text('${s.best}')),
              ListTile(title: const Text('Login streak'), trailing: Text('${s.streak} days')),
              const Divider(),
              Center(child: TextButton(onPressed: app.iap.restore, child: const Text('Restore purchases'))),
            ]);
          },
        ),
      );
}
