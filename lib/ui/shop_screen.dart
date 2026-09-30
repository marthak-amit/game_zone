import 'package:flutter/material.dart';
import '../config.dart';
import '../game/engine.dart';
import '../game/worlds.dart';
import '../services/app_services.dart';
import '../store.dart';
import 'widgets.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String msg = '';

  Future<void> _tapSkin(Skin s) async {
    final st = app.store;
    if (st.owns(s)) {
      st.equip(s);
    } else if (s.price > 0) {
      if (st.spend(s.price)) {
        st.buySkin(s);
        st.equip(s);
        app.audio.beep(880, .2);
      } else {
        setState(() => msg = 'Not enough coins — watch an ad for free coins!');
      }
    } else {
      await app.buy(context, Sku.vip);
    }
  }

  static const worldPrice = 250;

  Future<void> _tapWorld(World w) async {
    final st = app.store;
    if (st.ownsWorld(w.id)) {
      st.setWorld(w.id);
    } else if (st.spend(worldPrice)) {
      st.buyWorld(w.id);
      st.setWorld(w.id);
      app.audio.beep(880, .2);
    } else {
      setState(() => msg = 'Not enough coins — watch an ad for free coins!');
    }
  }

  Widget _worlds() {
    final st = app.store;
    Widget chip(String id, String label, Color a, Color b) {
      final owned = st.ownsWorld(id);
      final sel = st.worldPref == id;
      return SizedBox(
        height: 52,
        child: FilledButton(
          key: Key('world_$id'),
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: sel ? const BorderSide(color: Colors.white, width: 3) : null,
          ),
          onPressed: () => id == 'auto' ? st.setWorld('auto') : _tapWorld(worlds.firstWhere((w) => w.id == id)),
          child: Ink(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(colors: [a, b], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label + (owned ? (sel ? ' ✓' : '') : '  🪙$worldPrice'),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black87)])),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.6,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        chip('auto', '🌍 Auto (all worlds)', const Color(0xFF4C9BE8), const Color(0xFF3A1170)),
        for (final w in worlds) chip(w.id, w.name, w.top, w.bottom),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = app.iap.prices;
    return SubScreen(
      title: 'Shop',
      child: ListenableBuilder(
        listenable: app.store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Block skins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final s in skins)
                  FilledButton(
                    key: Key('skin_${s.id}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: HSLColor.fromAHSL(1, s.hue, .8, .4).toColor(),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: app.store.skinId == s.id ? const BorderSide(color: Colors.white, width: 3) : null,
                    ),
                    onPressed: () => _tapSkin(s),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 14, height: 14, margin: const EdgeInsets.only(right: 8), color: GameEngine.colorFor(s, 3)),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(s.name + (app.store.owns(s) ? (app.store.skinId == s.id ? ' ✓' : '') : s.price > 0 ? '  🪙${s.price}' : '  👑VIP')),
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: Text('Backgrounds', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            _worlds(),
            SizedBox(height: 24, child: Center(child: Text(msg, style: const TextStyle(color: Colors.amber)))),
            Center(child: Column(children: [
              BigButton('🪙 500 coins — ${p[Sku.coins500] ?? r'$0.99'}', () => app.buy(context, Sku.coins500), color: kGold, textColor: Colors.black),
              BigButton('🪙 2500 coins — ${p[Sku.coins2500] ?? r'$3.99'}', () => app.buy(context, Sku.coins2500), color: kGold, textColor: Colors.black),
              BigButton('👑 VIP: no ads, 2x coins — ${p[Sku.vip] ?? r'$4.99'}', app.store.vip ? null : () => app.buy(context, Sku.vip), color: kGreen),
              if (!app.store.noAds) BigButton('🚫 Remove Ads — ${p[Sku.removeAds] ?? r'$2.99'}', () => app.buy(context, Sku.removeAds), color: kGold, textColor: Colors.black),
              BigButton('📺 Free coins +50', () async {
                if (await app.rewarded(context, 'free_coins')) app.store.addCoins(50);
              }, color: kGrey),
              TextButton(onPressed: app.iap.restore, child: const Text('Restore purchases')),
            ])),
          ],
        ),
      ),
    );
  }
}
