import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/app_services.dart';
import 'store.dart';
import 'ui/menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = await Store.load();
  app = AppServices(store: store);
  runApp(const SkyStackApp());
  // Ads/billing initialise in the background so the game opens instantly.
  app.init();
}

class SkyStackApp extends StatefulWidget {
  const SkyStackApp({super.key});
  @override
  State<SkyStackApp> createState() => _SkyStackAppState();
}

class _SkyStackAppState extends State<SkyStackApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Silence music and ambience while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      app.audio.music.resume();
    } else {
      app.audio.music.pause();
      app.audio.setRain(false);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        // Browsers only allow audio after a user gesture; retry music on any touch.
        onPointerDown: (_) => app.audio.music.ensure(),
        child: _buildApp(),
      );

  Widget _buildApp() => MaterialApp(
        title: 'Sky Stack',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF3B82F6),
          scaffoldBackgroundColor: const Color(0xFF0B1020),
        ),
        home: const MenuScreen(),
      );
}
