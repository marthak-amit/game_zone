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

class SkyStackApp extends StatelessWidget {
  const SkyStackApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
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
