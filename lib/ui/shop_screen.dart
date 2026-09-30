import 'package:flutter/material.dart';
import '../config.dart';
import '../game/engine.dart';
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
