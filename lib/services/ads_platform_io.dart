import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config.dart';
import 'ads_demo.dart';

AdService createAdService() =>
    (Platform.isAndroid || Platform.isIOS) ? AdMobService() : DemoAdService();

/// Real AdMob ads (Android/iOS). Uses Google's TEST ad units until you put yours in config.dart.
class AdMobService implements AdService {
  bool _ready = false;
  String get _rewardedId => Platform.isIOS ? AppConfig.iosRewardedId : AppConfig.androidRewardedId;
  String get _interstitialId => Platform.isIOS ? AppConfig.iosInterstitialId : AppConfig.androidInterstitialId;

  @override
  Future<void> init() async {
    try {
      // GDPR / UMP consent (required for EEA & UK users)
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) => done.complete());
        },
        (_) => done.complete(),
      );
      await done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
    } catch (_) {}
    try {
      await MobileAds.instance.initialize();
      _ready = true;
    } catch (_) {}
  }

  @override
  Future<bool> showRewarded(BuildContext context, String reason) async {
    if (!_ready) return false;
    final loaded = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (_) => loaded.complete(null),
      ),
    );
    final ad = await loaded.future.timeout(const Duration(seconds: 10), onTimeout: () => null);
    if (ad == null) return false;
    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!result.isCompleted) result.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!result.isCompleted) result.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }

  @override
  Future<void> showInterstitial(BuildContext context) async {
    if (!_ready) return;
    final loaded = Completer<InterstitialAd?>();
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (_) => loaded.complete(null),
      ),
    );
    final ad = await loaded.future.timeout(const Duration(seconds: 6), onTimeout: () => null);
    if (ad == null) return;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        done.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        done.complete();
      },
    );
    ad.show();
    await done.future;
  }
}
