/// Central configuration. Change [liveMode] to true (or build with
/// `--dart-define=LIVE=true`) once real AdMob / store IDs are in place.
class AppConfig {
  /// Diagnostic build variant (CI only): 'full' (normal), 'noaudio' (all sound off), 'noanim' (looping animations off).
  static const String variant = String.fromEnvironment('VARIANT', defaultValue: 'full');
  static bool get noAudio => variant == 'noaudio';
  static bool get noAnim => variant == 'noanim';
  /// Background scenery frozen (variants: noscenery, noanim).
  static bool get staticScenery => variant == 'noscenery' || noAnim;
  /// Looping widget animations (title, PLAY shine/pulse, badges, coin) frozen (variants: noloops, noanim).
  static bool get noLoops => variant == 'noloops' || noAnim;
  /// Only the spinning coin frozen (variant: nocoin).
  static bool get noCoin => variant == 'nocoin';

  static const bool liveMode = bool.fromEnvironment('LIVE', defaultValue: false);

  // Google's official TEST ad units. Replace with your own from admob.google.com.
  static const String androidRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String iosRewardedId = 'ca-app-pub-3940256099942544/1712485313';
  static const String iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  static const int interstitialEveryNGames = 3;
  static const Duration interstitialMinGap = Duration(seconds: 60);

  static const String privacyUrl = 'https://REPLACE_ME/privacy.html';
}

/// In-app products. IDs must match the products created in Play Console / App Store Connect.
class Sku {
  static const removeAds = 'remove_ads';
  static const coins500 = 'coins_500';
  static const coins2500 = 'coins_2500';
  static const vip = 'vip_pass';
  static const all = {removeAds, coins500, coins2500, vip};
}
