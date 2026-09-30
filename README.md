# Sky Stack (Flutter)

One-tap arcade stacker for **Android, iOS and Web**, built with Flutter and designed to earn from
rewarded ads, interstitials and in-app purchases.

## Features
**Worlds:** six animated backgrounds that blend as your tower grows — Morning Sky, Golden Hour, Starry Night (moon, shooting stars),
Rain Storm (rain, lightning, rain sound), Aurora, Deep Space (planet). Parallax city skyline with lit windows.
**Modes:** Classic (speed rises smoothly with score *and* time) and Chill (slower, capped speed, 3 lives).
**Feel:** glossy blocks, pentatonic chime melody on perfect streaks, FEVER (x2 coins at 5x combo), milestone banners, screen shake.
**Shop:** block skins + unlockable fixed backgrounds. **Missions:** 3 of 6 rotate daily.

Perfect-drop combos · falling-piece physics · tutorial · pause (auto-pause on app switch) · 6 skins ·
daily login streak (up to Day 7, doubled by ad) · 3 daily missions · stats · share score · sound/haptics · saved progress.

## Monetization
| Stream | Implementation |
|---|---|
| Rewarded ads: continue, double coins, double daily, free coins | `lib/services/ads_platform_io.dart` (AdMob + GDPR consent) |
| Interstitial every 3 games, ≥60s apart, never for payers | `AppServices.maybeInterstitial` |
| IAP: Remove Ads, 500 / 2500 coins, VIP (no ads + 2× coins + gold skin) | `lib/services/iap_platform_io.dart` (Play Billing / StoreKit) |

On **web/desktop** (and tests) the app uses demo ads/purchases. On **Android/iOS** it uses real AdMob & store billing,
currently with Google's **test** ad units so nothing is charged/paid until you swap IDs.

## Run / test / build
```
flutter pub get
flutter test                 # engine + full UI flow tests
flutter run                  # device or emulator
flutter build apk --release  # Android
flutter build appbundle      # Play Store upload
flutter build web --no-web-resources-cdn
```
GitHub Actions (`.github/workflows/flutter.yml`) runs analyze + tests and produces an APK and web build on every push.

## Go-live checklist
1. Pick your final id: change `applicationId`/`namespace` in `android/app/build.gradle.kts` (currently `com.amit.sky_stack`) and the iOS bundle id.
2. AdMob: create app + rewarded + interstitial units. Put IDs in `lib/config.dart` and the App ID in
   `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist` (`GADApplicationIdentifier`).
3. Play Console: create products `remove_ads`, `coins_500`, `coins_2500`, `vip_pass` (see `lib/config.dart`, `STORE_LISTING.md`).
4. Host `docs/privacy.html` (GitHub Pages) and add the URL to the store listing.
5. Create a signing key, add `android/key.properties`, build `flutter build appbundle`.

## Revenue reality
$10K/month needs roughly 50–150K daily players. Drive traffic with daily TikTok/Reels/Shorts gameplay clips,
test paid installs with $200–500 (scale only if CPI < ~$0.40 and day-1 retention > 35%), and reuse this
monetization layer for more small games. No result is guaranteed.

## Release signing (Play Store)
```
keytool -genkey -v -keystore ~/upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Create `android/key.properties` (git-ignored):
```
storeFile=/home/you/upload.jks
storePassword=****
keyPassword=****
keyAlias=upload
```
Then `flutter build appbundle --release` and upload `build/app/outputs/bundle/release/app-release.aab`.
Keep the .jks file and passwords safe — losing them means you can't update the app.
