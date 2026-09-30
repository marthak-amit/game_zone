// Sky Stack — tap to drop blocks and build the tallest tower.
(function () {
  const M = window.Monetization, S = M.store;
  const cv = document.getElementById("c"), ctx = cv.getContext("2d");
  const $ = id => document.getElementById(id);
  const SKINS = [
    { id: "neon",   name: "Neon",   price: 0,    hue: 190, step: 12 },
    { id: "sunset", name: "Sunset", price: 300,  hue: 10,  step: 9 },
    { id: "candy",  name: "Candy",  price: 600,  hue: 310, step: 14 },
    { id: "forest", name: "Forest", price: 1000, hue: 110, step: 8 },
    { id: "gold",   name: "Gold VIP", price: -1, hue: 45,  step: 4 } // VIP only
  ];
  let W, H, dpr;
  function resize() {
    dpr = window.devicePixelRatio || 1; W = Math.min(innerWidth, 480); H = innerHeight;
    cv.width = W * dpr; cv.height = H * dpr; cv.style.width = W + "px"; cv.style.height = H + "px";
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  addEventListener("resize", resize); resize();

  const BH = 28;
  let st, blocks, cur, score, combo, camY, speed, dir, runCoins, revived, best, state = "menu", particles = [];
  const skin = () => SKINS.find(s => s.id === S.get("skin", "neon")) || SKINS[0];
  const color = i => `hsl(${(skin().hue + i * skin().step) % 360} 80% 58%)`;

  function coins(n) { S.set("coins", S.get("coins", 0) + n); ui(); }
  function ui() {
    $("coins").textContent = "🪙 " + S.get("coins", 0);
    $("best").textContent = "Best " + S.get("best", 0);
    $("noadsBtn").style.display = M.hasNoAds() ? "none" : "";
  }

  function start() {
    blocks = [{ x: (W - 200) / 2, w: 200, i: 0 }];
    score = 0; combo = 0; camY = 0; speed = 2.4; dir = 1; runCoins = 0; revived = false; particles = [];
    spawn(); state = "play"; hideAll(); $("score").style.display = "block"; $("score").textContent = 0;
  }
  function spawn() {
    const top = blocks[blocks.length - 1];
    cur = { x: dir > 0 ? -top.w : W, w: top.w, i: blocks.length };
  }
  function drop() {
    if (state !== "play") return;
    const top = blocks[blocks.length - 1];
    const l = Math.max(cur.x, top.x), r = Math.min(cur.x + cur.w, top.x + top.w), ov = r - l;
    if (ov <= 0) return over();
    const perfect = Math.abs(cur.x - top.x) < 5;
    if (perfect) { combo++; cur.x = top.x; cur.w = top.w; if (combo >= 3) cur.w = Math.min(cur.w + 8, 220); burst(cur.x + cur.w / 2, true); }
    else { combo = 0; burst(cur.x + cur.w / 2, false); cur.x = l; cur.w = ov; }
    blocks.push(cur); score++;
    const gain = perfect ? 2 : 1; runCoins += gain; if (S.get("vip", false)) runCoins += gain;
    $("score").textContent = score;
    speed = Math.min(2.4 + score * 0.06, 7); dir = -dir; spawn();
  }
  function burst(x, big) {
    const y = H - 140 - (blocks.length) * BH + camY;
    for (let i = 0; i < (big ? 18 : 6); i++) particles.push({ x, y, vx: (Math.random() - .5) * 5, vy: -Math.random() * 4, life: 30, c: big ? "#fff" : "#ffd54a" });
  }
  function over() {
    state = "over";
    best = Math.max(S.get("best", 0), score); S.set("best", best);
    $("finalScore").textContent = score; $("finalCoins").textContent = runCoins;
    $("revive").style.display = revived || score < 3 ? "none" : "";
    $("double").disabled = false; $("double").style.display = runCoins > 0 ? "" : "none";
    $("over").style.display = "flex"; $("score").style.display = "none";
    coins(runCoins); ui();
  }

  function frame() {
    ctx.clearRect(0, 0, W, H);
    const g = ctx.createLinearGradient(0, 0, 0, H);
    const h = (skin().hue + (blocks ? blocks.length * 3 : 0)) % 360;
    g.addColorStop(0, `hsl(${h} 50% 14%)`); g.addColorStop(1, `hsl(${(h + 40) % 360} 60% 30%)`);
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    if (blocks) {
      const target = Math.max(0, (blocks.length - 6) * BH);
      camY += (target - camY) * 0.1;
      const y = i => H - 140 - (i + 1) * BH + camY;
      blocks.forEach(b => { ctx.fillStyle = color(b.i); ctx.fillRect(b.x, y(b.i), b.w, BH - 2); });
      if (state === "play") {
        cur.x += speed * dir;
        if (cur.x > W || cur.x < -cur.w - 1) dir = -dir;
        ctx.fillStyle = color(cur.i); ctx.fillRect(cur.x, y(cur.i), cur.w, BH - 2);
        if (combo >= 2) { ctx.fillStyle = "#fff"; ctx.font = "bold 18px sans-serif"; ctx.textAlign = "center"; ctx.fillText("PERFECT x" + combo, W / 2, 130); }
      }
      particles = particles.filter(p => p.life-- > 0);
      particles.forEach(p => { p.x += p.vx; p.y += p.vy; p.vy += .2; ctx.fillStyle = p.c; ctx.fillRect(p.x, p.y, 4, 4); });
    }
    requestAnimationFrame(frame);
  }

  function hideAll() { document.querySelectorAll(".panel").forEach(p => p.style.display = "none"); }
  function shop() {
    const box = $("skins"); box.innerHTML = "";
    SKINS.forEach(sk => {
      const owned = S.get("own_" + sk.id, sk.price === 0) || (sk.id === "gold" && S.get("vip", false));
      const b = document.createElement("button");
      b.className = "skin"; b.style.background = `hsl(${sk.hue} 80% 50%)`;
      b.textContent = sk.name + (owned ? (S.get("skin", "neon") === sk.id ? " ✓" : "") : sk.price > 0 ? ` 🪙${sk.price}` : " 👑VIP");
      b.onclick = async () => {
        if (owned) S.set("skin", sk.id);
        else if (sk.price > 0 && S.get("coins", 0) >= sk.price) { coins(-sk.price); S.set("own_" + sk.id, true); S.set("skin", sk.id); }
        else if (sk.price > 0) { alert("Not enough coins — watch an ad for free coins!"); }
        else await M.purchase("vip_pass");
        shop(); ui();
      };
      box.appendChild(b);
    });
  }
  function daily() {
    const today = new Date().toDateString(), last = S.get("dailyDate", "");
    const btn = $("daily");
    btn.style.display = last === today ? "none" : "";
    btn.onclick = async () => {
      const ok = await M.showRewarded("daily_bonus");
      if (ok) { coins(100); S.set("dailyDate", today); btn.style.display = "none"; }
    };
  }

  function tap(e) { if (e.target.closest("button")) return; e.preventDefault(); drop(); }
  cv.addEventListener("pointerdown", tap);
  addEventListener("keydown", e => { if (e.code === "Space") drop(); });

  $("play").onclick = start;
  $("again").onclick = async () => { $("over").style.display = "none"; await M.maybeInterstitial(); start(); };
  $("revive").onclick = async () => {
    if (await M.showRewarded("revive")) {
      revived = true; coins(-runCoins); state = "play";
      $("over").style.display = "none"; $("score").style.display = "block"; spawn();
    }
  };
  $("double").onclick = async () => {
    if (await M.showRewarded("double_coins")) { coins(runCoins); $("double").disabled = true; $("finalCoins").textContent = runCoins * 2; }
  };
  $("freeCoins").onclick = async () => { if (await M.showRewarded("free_coins")) coins(50); };
  $("shopBtn").onclick = () => { shop(); $("shop").style.display = "flex"; };
  $("closeShop").onclick = () => $("shop").style.display = "none";
  document.querySelectorAll("[data-sku]").forEach(b => b.onclick = () => M.purchase(b.dataset.sku));
  $("noadsBtn").onclick = () => M.purchase("remove_ads");
  window.addEventListener("sk-purchase", () => { ui(); shop(); });

  M.grantFromReturn(); ui(); daily();
  if ("serviceWorker" in navigator) navigator.serviceWorker.register("sw.js").catch(() => {});
  frame();
})();
