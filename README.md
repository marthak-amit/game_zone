# Sky Stack — hyper-casual game built for revenue

Tap to drop blocks, build the tallest tower. Runs as a web game (PWA) and as an Android/iOS app (Capacitor).

## Monetization built in
| Stream | Where |
|---|---|
| Rewarded ads (revive, double coins, daily bonus, free coins) | `monetization.js` → AdMob (native) / AdSense H5 (web) |
| Interstitials (every 3 games, 60s cap, skipped for payers) | same |
| IAP: Remove Ads $2.99, Coins $0.99/$3.99, VIP $4.99 | Play Billing / StoreKit via `cordova-plugin-purchase` |
| Retention: daily bonus, skins, best score | `game.js` |

## Run locally (demo mode: fake ads, instant purchases)
Open `index.html` or `python3 -m http.server`.

## Build the mobile app
```
npm install
npm run android:add     # creates android/ (needs Android Studio + JDK17)
npm run ios:add         # macOS + Xcode only
npm run android:apk     # debug APK  (or run the GitHub Action "Build Android")
```
After `cap add android`, add to `android/app/src/main/AndroidManifest.xml` inside `<application>`:
`<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="YOUR_ADMOB_APP_ID"/>`

## Go-live checklist (things only you can do)
1. Change `appId` in `capacitor.config.json`; set `mode: "live"` in `config.js`.
2. Create AdMob account → app + Rewarded + Interstitial units → paste ids in `config.js` (currently Google TEST ids).
3. Google Play Console ($25 one-time) → create IAP products with ids in `config.products` → upload signed AAB (`npm run android:aab`). Apple: $99/yr.
4. Add a privacy policy URL + consent (UMP/GDPR) before live ads.
5. Add app icon/splash (`npx @capacitor/assets generate`).

## Honest revenue math for $10K/month
Rewarded+interstitial ad revenue ≈ $10–30 per 1,000 daily-active-user sessions-heavy players; IAP adds ~1–3% payers.
Realistically you need roughly **50–150K daily active users**. The game is the easy part — **user acquisition is the work**:
- Post short gameplay clips daily on TikTok/Reels/Shorts (free traffic, the main channel for hyper-casual).
- Test with $200–500 of ads (Unity/AppLovin/Meta): only scale if cost-per-install < ~$0.40 and day-1 retention > 35%.
- Ship 3–5 more small games reusing this monetization layer; portfolio beats a single title.
- Publish the web version on CrazyGames/Poki/GameDistribution for extra ad revenue.
No one can guarantee $10K/month; expect months to reach it.
