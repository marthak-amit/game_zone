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
    { id: "ocean",  name: "Ocean",  price: 1500, hue: 220, step: 10 },
    { id: "gold",   name: "Gold VIP", price: -1, hue: 45,  step: 4 }
  ];
  const BH = 28, BASE = 140;
  let W, H, dpr;
  function resize() {
    dpr = window.devicePixelRatio || 1; W = Math.min(innerWidth, 480); H = innerHeight;
    cv.width = W * dpr; cv.height = H * dpr; cv.style.width = W + "px"; cv.style.height = H + "px";
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  addEventListener("resize", resize); resize();

  let blocks, cur, score = 0, combo = 0, camY = 0, speed, dir, runCoins, runPerfects, revived, state = "menu";
  let particles = [], falling = [], popups = [];
  const skin = () => SKINS.find(s => s.id === S.get("skin", "neon")) || SKINS[0];
  const color = i => `hsl(${(skin().hue + i * skin().step) % 360} 80% 58%)`;
  const today = () => new Date().toDateString();

  // ---------- audio / haptics ----------
  let actx;
  function beep(f, d) {
    if (!S.get("sound", true)) return;
    try {
      actx = actx || new (window.AudioContext || window.webkitAudioContext)();
      const o = actx.createOscillator(), v = actx.createGain();
      o.frequency.value = f; o.type = "triangle"; v.gain.value = 0.08;
      o.connect(v); v.connect(actx.destination); o.start();
      v.gain.exponentialRampToValueAtTime(0.0001, actx.currentTime + d); o.stop(actx.currentTime + d);
    } catch (e) {}
  }
  function buzz(ms) { if (S.get("vibe", true) && navigator.vibrate) try { navigator.vibrate(ms); } catch (e) {} }

  // ---------- wallet / ui ----------
  function coins(n) { S.set("coins", S.get("coins", 0) + n); ui(); }
  function ui() {
    $("coins").textContent = "🪙 " + S.get("coins", 0);
    $("best").textContent = "Best " + S.get("best", 0);
    $("noadsBtn").style.display = M.hasNoAds() ? "none" : "";
    $("soundBtn").textContent = "Sound: " + (S.get("sound", true) ? "ON" : "OFF");
    $("vibeBtn").textContent = "Vibration: " + (S.get("vibe", true) ? "ON" : "OFF");
    const done = missions().filter(m => m.progress >= m.goal && !m.claimed).length;
    $("missionsBtn").textContent = "🎯 Missions" + (done ? " (" + done + " ready!)" : "");
  }
  function show(id) { hideAll(); $(id).style.display = "flex"; }
  function hideAll() { document.querySelectorAll(".panel").forEach(p => p.style.display = "none"); }

  // ---------- missions ----------
  function missions() {
    let m = S.get("missions", null);
    if (!m || m.date !== today()) {
      m = { date: today(), list: [
        { type: "score",   goal: 10, reward: 50, progress: 0, claimed: false, text: "Reach score 10 in one game" },
        { type: "perfect", goal: 15, reward: 60, progress: 0, claimed: false, text: "Land 15 perfect drops" },
        { type: "games",   goal: 3,  reward: 40, progress: 0, claimed: false, text: "Play 3 games" }
      ] };
      S.set("missions", m);
    }
    return m.list;
  }
  function missionEvent(type, val) {
    const list = missions();
    list.forEach(m => {
      if (m.type !== type) return;
      m.progress = type === "score" ? Math.max(m.progress, val) : m.progress + val;
    });
    S.set("missions", { date: today(), list });
  }
  function renderMissions() {
    const box = $("missionList"); box.innerHTML = "";
    missions().forEach((m, i) => {
      const row = document.createElement("div"); row.className = "mrow";
      const ready = m.progress >= m.goal;
      row.innerHTML = `<div style="flex:1;text-align:left">${m.text}<br><small>${Math.min(m.progress, m.goal)}/${m.goal}</small></div>`;
      const b = document.createElement("button"); b.style.minWidth = "90px"; b.style.padding = "10px";
      b.textContent = m.claimed ? "✓ Done" : "🪙 " + m.reward; b.disabled = m.claimed || !ready;
      if (ready && !m.claimed) b.className = "gold";
      b.onclick = () => {
        const l = missions(); l[i].claimed = true; S.set("missions", { date: today(), list: l });
        coins(m.reward); beep(880, .2); renderMissions();
      };
      row.appendChild(b); box.appendChild(row);
    });
  }

  // ---------- daily streak reward ----------
  function daily() {
    const btn = $("daily"), dbl = $("dailyDouble");
    const last = S.get("dailyDate", "");
    dbl.style.display = "none";
    if (last === today()) { btn.style.display = "none"; return; }
    const y = new Date(Date.now() - 864e5).toDateString();
    const streak = last === y ? S.get("streak", 0) + 1 : 1;
    const reward = 50 * Math.min(streak, 7);
    btn.style.display = "";
    btn.textContent = `🎁 Daily reward — Day ${streak}: +${reward}`;
    btn.onclick = () => {
      S.set("dailyDate", today()); S.set("streak", streak); coins(reward); beep(880, .2);
      btn.style.display = "none"; dbl.style.display = "";
      dbl.textContent = `📺 Double it (+${reward})`;
      dbl.onclick = async () => { if (await M.showRewarded("daily_double")) { coins(reward); dbl.style.display = "none"; } };
    };
  }

  // ---------- gameplay ----------
  function start() {
    blocks = [{ x: (W - 200) / 2, w: 200, i: 0 }];
    score = 0; combo = 0; camY = 0; speed = 2.4; dir = 1; runCoins = 0; runPerfects = 0; revived = false;
    particles = []; falling = []; popups = [];
    spawn(); state = "play"; hideAll();
    $("score").style.display = "block"; $("score").textContent = 0; $("pauseBtn").style.display = "";
  }
  function spawn() {
    const top = blocks[blocks.length - 1];
    cur = { x: dir > 0 ? -top.w : W, w: top.w, i: blocks.length };
  }
  const yOf = i => H - BASE - (i + 1) * BH + camY;
  function drop() {
    if (state !== "play") return;
    const top = blocks[blocks.length - 1];
    const l = Math.max(cur.x, top.x), r = Math.min(cur.x + cur.w, top.x + top.w), ov = r - l;
    if (ov <= 0) { falling.push({ x: cur.x, w: cur.w, i: cur.i, dy: 0, vy: 0, c: color(cur.i) }); return over(); }
    const perfect = Math.abs(cur.x - top.x) < 5;
    if (perfect) {
      combo++; runPerfects++; cur.x = top.x; cur.w = top.w;
      if (combo >= 3) cur.w = Math.min(cur.w + 8, 220);
      burst(cur.x + cur.w / 2, true); buzz(15);
      addPopup(cur.x + cur.w / 2, cur.i, combo >= 2 ? "PERFECT x" + combo : "PERFECT");
    } else {
      combo = 0;
      if (cur.x < l) falling.push({ x: cur.x, w: l - cur.x, i: cur.i, dy: 0, vy: 0, c: color(cur.i) });
      if (cur.x + cur.w > r) falling.push({ x: r, w: cur.x + cur.w - r, i: cur.i, dy: 0, vy: 0, c: color(cur.i) });
      burst(cur.x + cur.w / 2, false); cur.x = l; cur.w = ov; buzz(8);
    }
    beep(perfect ? 520 + Math.min(combo, 10) * 60 : 300, .12);
    blocks.push(cur); score++;
    const gain = (perfect ? 2 : 1) * (S.get("vip", false) ? 2 : 1); runCoins += gain;
    $("score").textContent = score;
    speed = Math.min(2.4 + score * 0.06, 7); dir = -dir; spawn();
  }
  function addPopup(x, i, text) { popups.push({ x, i, text, life: 45 }); }
  function burst(x, big) {
    const y = yOf(blocks.length);
    for (let i = 0; i < (big ? 18 : 6); i++) particles.push({ x, y, vx: (Math.random() - .5) * 5, vy: -Math.random() * 4, life: 30, c: big ? "#fff" : "#ffd54a" });
  }
  function over() {
    state = "over"; beep(120, .4); buzz(60);
    const newBest = score > S.get("best", 0);
    if (newBest) S.set("best", score);
    S.set("games", S.get("games", 0) + 1); S.set("blocks", S.get("blocks", 0) + score);
    missionEvent("score", score); missionEvent("perfect", runPerfects); missionEvent("games", 1);
    $("finalScore").textContent = score; $("finalCoins").textContent = runCoins;
    $("newBest").style.display = newBest && score > 0 ? "block" : "none";
    $("revive").style.display = revived || score < 3 ? "none" : "";
    $("double").disabled = false; $("double").style.display = runCoins > 0 ? "" : "none";
    show("over"); $("score").style.display = "none"; $("pauseBtn").style.display = "none";
    coins(runCoins); ui();
  }

  function frame() {
    ctx.clearRect(0, 0, W, H);
    const n = blocks ? blocks.length : 0, h = (skin().hue + n * 3) % 360;
    const g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, `hsl(${h} 50% 14%)`); g.addColorStop(1, `hsl(${(h + 40) % 360} 60% 30%)`);
    ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    if (blocks) {
      const target = Math.max(0, (n - 6) * BH);
      camY += (target - camY) * 0.1;
      blocks.forEach(b => { ctx.fillStyle = color(b.i); ctx.fillRect(b.x, yOf(b.i), b.w, BH - 2); });
      if (state === "play") {
        cur.x += speed * dir;
        if (cur.x > W) dir = -1; else if (cur.x < -cur.w - 1) dir = 1;
        ctx.fillStyle = color(cur.i); ctx.fillRect(cur.x, yOf(cur.i), cur.w, BH - 2);
        if (score === 0 && S.get("games", 0) < 2) {
          ctx.fillStyle = "#fff"; ctx.font = "bold 22px sans-serif"; ctx.textAlign = "center";
          ctx.fillText("TAP to drop the block", W / 2, H / 2);
          ctx.font = "16px sans-serif"; ctx.fillText("Line it up for PERFECT bonuses", W / 2, H / 2 + 28);
        }
      }
      falling = falling.filter(f => f.dy < H);
      falling.forEach(f => { if (state !== "pause") { f.vy += .6; f.dy += f.vy; } ctx.globalAlpha = .85; ctx.fillStyle = f.c; ctx.fillRect(f.x, yOf(f.i) + f.dy, f.w, BH - 2); ctx.globalAlpha = 1; });
      particles = particles.filter(p => p.life > 0);
      particles.forEach(p => { if (state !== "pause") { p.life--; p.x += p.vx; p.y += p.vy; p.vy += .2; } ctx.fillStyle = p.c; ctx.fillRect(p.x, p.y, 4, 4); });
      popups = popups.filter(p => p.life > 0);
      popups.forEach(p => { if (state !== "pause") p.life--; ctx.globalAlpha = Math.min(1, p.life / 20); ctx.fillStyle = "#fff"; ctx.font = "bold 18px sans-serif"; ctx.textAlign = "center"; ctx.fillText(p.text, p.x, yOf(p.i) - (45 - p.life) - 6); ctx.globalAlpha = 1; });
    }
    requestAnimationFrame(frame);
  }

  // ---------- shop ----------
  function shop() {
    const box = $("skins"); box.innerHTML = "";
    SKINS.forEach(sk => {
      const owned = S.get("own_" + sk.id, sk.price === 0) || (sk.id === "gold" && S.get("vip", false));
      const b = document.createElement("button");
      b.className = "skin"; b.style.background = `hsl(${sk.hue} 80% 40%)`;
      b.textContent = sk.name + (owned ? (S.get("skin", "neon") === sk.id ? " ✓" : "") : sk.price > 0 ? ` 🪙${sk.price}` : " 👑VIP");
      b.onclick = async () => {
        if (owned) S.set("skin", sk.id);
        else if (sk.price > 0 && S.get("coins", 0) >= sk.price) { coins(-sk.price); S.set("own_" + sk.id, true); S.set("skin", sk.id); beep(880, .2); }
        else if (sk.price > 0) { $("shopMsg").textContent = "Not enough coins — watch an ad for free coins!"; }
        else await M.purchase("vip_pass");
        shop(); ui();
      };
      box.appendChild(b);
    });
  }
  let shopReturn = "menu";
  function openShop(from) { shopReturn = from; shop(); $("shopMsg").textContent = ""; show("shop"); }

  // ---------- pause ----------
  function pause() { if (state === "play") { state = "pause"; show("pausePanel"); } }
  function resume() { if (state === "pause") { state = "play"; hideAll(); } }
  function toMenu() { state = "menu"; hideAll(); $("score").style.display = "none"; $("pauseBtn").style.display = "none"; show("menu"); daily(); ui(); }

  // ---------- input ----------
  cv.addEventListener("pointerdown", e => { e.preventDefault(); drop(); });
  addEventListener("keydown", e => {
    if (e.code === "Space") { e.preventDefault(); drop(); }
    if (e.code === "Escape") state === "pause" ? resume() : pause();
  });
  document.addEventListener("visibilitychange", () => { if (document.hidden) pause(); });

  $("play").onclick = start;
  $("again").onclick = async () => { $("over").style.display = "none"; await M.maybeInterstitial(); start(); };
  $("home").onclick = toMenu;
  $("pauseBtn").onclick = pause;
  $("resume").onclick = resume;
  $("quit").onclick = toMenu;
  $("revive").onclick = async () => {
    if (await M.showRewarded("revive")) {
      revived = true; coins(-runCoins); state = "play"; hideAll();
      $("score").style.display = "block"; $("pauseBtn").style.display = ""; spawn();
    }
  };
  $("double").onclick = async () => {
    if (await M.showRewarded("double_coins")) { coins(runCoins); $("double").disabled = true; $("finalCoins").textContent = runCoins * 2; }
  };
  $("freeCoins").onclick = async () => { if (await M.showRewarded("free_coins")) { coins(50); beep(880, .2); } };
  $("shopBtn").onclick = () => openShop("menu");
  $("shopBtn2").onclick = () => openShop("over");
  $("closeShop").onclick = () => show(shopReturn);
  $("missionsBtn").onclick = () => { renderMissions(); show("missions"); };
  $("closeMissions").onclick = () => { ui(); show("menu"); };
  $("settingsBtn").onclick = () => { renderStats(); ui(); show("settings"); };
  $("closeSettings").onclick = () => show("menu");
  $("soundBtn").onclick = () => { S.set("sound", !S.get("sound", true)); ui(); };
  $("vibeBtn").onclick = () => { S.set("vibe", !S.get("vibe", true)); ui(); };
  $("shareBtn").onclick = async () => {
    const text = `I stacked ${score} blocks in Sky Stack! Can you beat me?`;
    try { if (navigator.share) await navigator.share({ text, url: location.href }); else { await navigator.clipboard.writeText(text + " " + location.href); alert("Copied to clipboard!"); } } catch (e) {}
  };
  function renderStats() {
    $("stats").innerHTML = `Games played: <b>${S.get("games", 0)}</b><br>Blocks stacked: <b>${S.get("blocks", 0)}</b><br>Best score: <b>${S.get("best", 0)}</b><br>Login streak: <b>${S.get("streak", 0)}</b> days`;
  }
  document.querySelectorAll("[data-sku]").forEach(b => b.onclick = () => M.purchase(b.dataset.sku));
  $("noadsBtn").onclick = () => M.purchase("remove_ads");
  window.addEventListener("sk-purchase", () => { ui(); if ($("shop").style.display === "flex") shop(); });

  window.__sky = { get cur() { return cur; }, get top() { return blocks && blocks[blocks.length - 1]; }, get state() { return state; }, get score() { return score; }, get combo() { return combo; } };
  M.grantFromReturn(); ui(); daily();
  if ("serviceWorker" in navigator && location.protocol.startsWith("http")) navigator.serviceWorker.register("sw.js").catch(() => {});
  frame();
})();
