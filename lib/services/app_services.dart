import 'package:flutter/material.dart';
import '../config.dart';
import '../store.dart';
import 'ads.dart';
import 'audio.dart';
import 'iap.dart';

/// Ties together storage, ads, purchases and audio. One instance for the whole app.
class AppServices {
  final Store store;
  final AdService ads;
  final IapService iap;
  final Audio audio;

  int _gamesSinceInterstitial = 0;
  DateTime _lastInterstitial = DateTime.fromMillisecondsSinceEpoch(0);

  AppServices({required this.store, AdService? ads, IapService? iap, Audio? audio})
      : audio = audio ?? Audio(),
        ads = ads ?? createAdService(),
        iap = iap ?? createIapService() {
    store.addListener(_syncAudio);
    _syncAudio();
  }

  void _syncAudio() {
    audio.soundOn = store.sound;
    audio.vibeOn = store.vibe;
    audio.music.setEnabled(store.music);
    if (!store.sound) audio.setRain(false);
  }

  Future<void> init() async {
    await ads.init();
    await iap.init(grant);
  }

  /// Watch a rewarded ad; true if the reward was earned.
  Future<bool> rewarded(BuildContext context, String reason) => ads.showRewarded(context, reason);

  /// Called when a round ends and the player starts another. Frequency-capped; skipped for payers.
  Future<void> maybeInterstitial(BuildContext context) async {
    _gamesSinceInterstitial++;
    if (store.noAds) return;
    final now = DateTime.now();
    if (_gamesSinceInterstitial < AppConfig.interstitialEveryNGames ||
        now.difference(_lastInterstitial) < AppConfig.interstitialMinGap) {
      return;
    }
    _gamesSinceInterstitial = 0;
    _lastInterstitial = now;
    await ads.showInterstitial(context);
  }

  Future<void> buy(BuildContext context, String sku) => iap.buy(context, sku);

  void grant(String sku) {
    switch (sku) {
      case Sku.removeAds:
        store.setNoAds();
      case Sku.coins500:
        store.addCoins(500);
      case Sku.coins2500:
        store.addCoins(2500);
      case Sku.vip:
        store.setVip();
    }
  }
}

/// Global access (set in main / tests).
late AppServices app;
