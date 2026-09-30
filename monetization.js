// Ad + IAP abstraction. Game code only calls Monetization.*; swap providers here.
(function () {
  const C = window.CONFIG;
  const store = {
    get(k, d) { try { const v = localStorage.getItem("sk_" + k); return v === null ? d : JSON.parse(v); } catch (e) { return d; } },
    set(k, v) { try { localStorage.setItem("sk_" + k, JSON.stringify(v)); } catch (e) {} }
  };
  let lastInterstitial = 0, gamesSince = 0;
  const native = !!(window.Capacitor && window.Capacitor.isNativePlatform && window.Capacitor.isNativePlatform());
  const AdMob = native ? window.Capacitor.Plugins.AdMob : null;
  const N = C.native || {};
  const testing = C.mode !== "live";
  if (AdMob) AdMob.initialize({ initializeForTesting: testing }).catch(() => {});
  // In-app purchases via cordova-plugin-purchase (Google Play / App Store); initialised lazily
  let iapReady = false;
  function initIAP() {
    if (iapReady || !native || !window.CdvPurchase) return iapReady;
    iapReady = true;
    const { store: P, ProductType, Platform } = window.CdvPurchase;
    const plat = window.Capacitor.getPlatform() === "ios" ? Platform.APPLE_APPSTORE : Platform.GOOGLE_PLAY;
    P.register(Object.entries(C.products).map(([sku, id]) => ({ id, type: sku.startsWith("coins") ? ProductType.CONSUMABLE : ProductType.NON_CONSUMABLE, platform: plat })));
    P.when().approved(t => t.verify()).verified(r => {
      const sku = Object.keys(C.products).find(k => C.products[k] === r.products[0].id);
      if (sku) grant(sku);
      r.finish();
    });
    P.initialize([plat]);
    return true;
  }
  document.addEventListener("deviceready", initIAP);
  setTimeout(initIAP, 1500);


  function demoAd(label, seconds) {
    return new Promise(res => {
      const o = document.getElementById("adOverlay");
      const t = document.getElementById("adText");
      const b = document.getElementById("adClose");
      o.style.display = "flex"; b.disabled = true; b.textContent = "Please wait…";
      let s = seconds;
      const tick = () => { t.textContent = label + " (demo ad) — " + s + "s"; if (s-- <= 0) { b.disabled = false; b.textContent = "Close ✕"; } else setTimeout(tick, 1000); };
      tick();
      b.onclick = () => { o.style.display = "none"; res(s <= 0); };
    });
  }

  window.Monetization = {
    store,
    hasNoAds() { return store.get("noAds", false); },
    // Rewarded ad: resolves true only if user finished watching.
    async showRewarded(reason) {
      if (AdMob) {
        try {
          await AdMob.prepareRewardVideoAd({ adId: N.rewardedId, isTesting: testing });
          let rewarded = false;
          const h = await AdMob.addListener("onRewardedVideoAdReward", () => { rewarded = true; });
          await AdMob.showRewardVideoAd(); h.remove();
          return rewarded;
        } catch (e) { return false; }
      }
      if (C.mode === "demo") return demoAd("Rewarded: " + reason, 3);
      // LIVE (web): AdSense H5 Games Ads API
      if (window.adBreak) {
        return new Promise(res => {
          window.adBreak({
            type: "reward", name: reason,
            beforeReward: (show) => show(),
            adDismissed: () => res(false),
            adViewed: () => res(true),
            adBreakDone: (info) => { if (info.breakStatus !== "viewed") res(false); }
          });
        });
      }
      return false; // no ad available
    },
    // Interstitial between rounds, frequency-capped. Skipped for paying users.
    async maybeInterstitial() {
      gamesSince++;
      if (this.hasNoAds()) return;
      const now = Date.now();
      if (gamesSince < C.interstitialEveryNGames || now - lastInterstitial < C.interstitialMinSeconds * 1000) return;
      gamesSince = 0; lastInterstitial = now;
      if (AdMob) { try { await AdMob.prepareInterstitial({ adId: N.interstitialId, isTesting: testing }); await AdMob.showInterstitial(); } catch (e) {} return; }
      if (C.mode === "demo") return demoAd("Interstitial", 2);
      if (window.adBreak) return new Promise(res => window.adBreak({ type: "next", name: "gameover", adBreakDone: res }));
    },
    // Purchases. Returns true when granted.
    async purchase(sku) {
      if (native && initIAP()) {
        const P = window.CdvPurchase.store, id = C.products[sku];
        const offer = P.get(id) && P.get(id).getOffer();
        if (offer) offer.order();
        return false; // granted asynchronously in the 'verified' handler
      }
      if (C.mode === "demo") { grant(sku); return true; }
      const url = C.paymentLinks[sku];
      if (!url) return false;
      // Web flow: Stripe Payment Link; success redirect returns with ?paid=<sku> (verify server-side in production!)
      window.location.href = url + "?client_reference_id=" + encodeURIComponent(sku);
      return false;
    },
    grantFromReturn() {
      const p = new URLSearchParams(location.search).get("paid");
      if (p) { grant(p); history.replaceState({}, "", location.pathname); }
    }
  };

  function grant(sku) {
    if (sku === "remove_ads") store.set("noAds", true);
    if (sku === "coins_500") store.set("coins", store.get("coins", 0) + 500);
    if (sku === "coins_2500") store.set("coins", store.get("coins", 0) + 2500);
    if (sku === "vip_pass") { store.set("noAds", true); store.set("vip", true); }
    window.dispatchEvent(new Event("sk-purchase"));
  }
})();
