// ====== MONETIZATION CONFIG — edit these before launch ======
window.CONFIG = {
  // "demo" shows fake ad screens & instant purchases so you can test. Set to "live" for production.
  mode: "demo",
  // Google AdSense / AdSense for Games (H5 Games Ads) — web
  adsensePublisherId: "ca-pub-XXXXXXXXXXXXXXXX",
  // Stripe Payment Links (create in Stripe dashboard, paste URLs) — web purchases
  paymentLinks: {
    remove_ads: "https://buy.stripe.com/REPLACE_ME_remove_ads",
    coins_500:  "https://buy.stripe.com/REPLACE_ME_coins_500",
    coins_2500: "https://buy.stripe.com/REPLACE_ME_coins_2500",
    vip_pass:   "https://buy.stripe.com/REPLACE_ME_vip"
  },
  // Native mobile (AdMob). These are Google's TEST ids — replace with yours from admob.google.com
  native: {
    androidAppId: "ca-app-pub-3940256099942544~3347511713",
    rewardedId: "ca-app-pub-3940256099942544/5224354917",
    interstitialId: "ca-app-pub-3940256099942544/1033173712"
  },
  // Product ids you create in Google Play Console / App Store Connect
  products: { remove_ads: "remove_ads", coins_500: "coins_500", coins_2500: "coins_2500", vip_pass: "vip_pass" },
  interstitialEveryNGames: 3,
  interstitialMinSeconds: 60
};
