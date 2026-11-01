// Browser port of the Snaptrap SwiftUI app, for previewing the fold animations.
// The math mirrors Snaptrap/Views/TrapRenderer.swift, CoverView.swift and Game/GameModel.swift.
(() => {
  const canvas = document.getElementById('c');
  const ctx = canvas.getContext('2d');
  const DPR = 2;
  const W = canvas.width / DPR, H = canvas.height / DPR;

  const T = {
    bgInner: '#17331f', bgOuter: '#050f0a', rim: '#336b21', leaf: '#73bd3d', blush: '#db4d3d',
    crimson: '#9e0f29', tooth: '#d4eb8c', toothTip: '#faffd9', pollen: '#ffe673', gold: '#ffcc33',
    danger: '#ff5c4d', catchable: '#b3ff8c',
  };
  const ARM = 145, SNAP = 105;
  const clamp = (v, a, b) => Math.min(Math.max(v, a), b);
  const Ease = {
    outCubic: t => 1 - Math.pow(1 - clamp(t, 0, 1), 3),
    inCubic: t => Math.pow(clamp(t, 0, 1), 3),
    inOut: t => { t = clamp(t, 0, 1); return t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; },
    outBack: (t, o = 1.9) => { t = clamp(t, 0, 1); const c3 = o + 1; return 1 + c3 * Math.pow(t - 1, 3) + o * Math.pow(t - 1, 2); },
  };
  const rand = (a, b) => a + Math.random() * (b - a);
  const pick = a => a[Math.floor(Math.random() * a.length)];
  const norm = (x, y) => { const l = Math.hypot(x, y); return l > 1e-4 ? [x / l, y / l] : [0, 0]; };
  const rgba = (hex, a) => { const n = parseInt(hex.slice(1), 16); return `rgba(${n >> 16},${(n >> 8) & 255},${n & 255},${a})`; };

  // ---------- Hinge ----------
  const hinge = { degrees: 180, closed: false, anim: null };
  const slider = document.getElementById('hinge'), degLabel = document.getElementById('deg');
  function animateHinge(steps) {
    const start = performance.now();
    hinge.anim = { steps, start };
  }
  function stepHinge(now) {
    if (!hinge.anim) return;
    let t0 = hinge.anim.start;
    for (const s of hinge.anim.steps) {
      const end = t0 + s.d * 1000;
      if (now < end) {
        if (s.to !== undefined) hinge.degrees = s.from + (s.to - s.from) * Ease.inOut((now - t0) / (s.d * 1000));
        return;
      }
      if (s.to !== undefined) hinge.degrees = s.to;
      if (s.then) { s.then(); s.then = null; }
      t0 = end;
    }
    hinge.anim = null;
  }
  const reading = () => ({ degrees: hinge.closed ? 0 : hinge.degrees, closed: hinge.closed });
  const closureOf = r => clamp((180 - r.degrees) / (180 - SNAP), 0, 1);
  let armed = false;
  function detect(r) {
    if (r.degrees >= ARM && !r.closed) { armed = true; return false; }
    if (armed && (r.degrees <= SNAP || r.closed)) { armed = false; return true; }
    return false;
  }

  document.getElementById('snap').onclick = () => { hinge.closed = false; animateHinge([{ from: 180, to: 72, d: .11 }, { d: .12 }, { from: 72, to: 180, d: .42 }]); };
  document.getElementById('close').onclick = () => animateHinge([{ from: hinge.degrees, to: 60, d: .25, then: () => { hinge.closed = true; } }]);
  document.getElementById('open').onclick = () => { hinge.closed = false; hinge.degrees = 30; animateHinge([{ from: 30, to: 180, d: .6 }]); };
  slider.oninput = () => { hinge.anim = null; hinge.closed = false; hinge.degrees = +slider.value; };
  addEventListener('keydown', e => { if (e.code === 'Space') { e.preventDefault(); document.getElementById('snap').click(); } });

  // ---------- Game ----------
  const KINDS = {
    fly: { emoji: '🪰', points: 10, size: 30, speed: 170, rest: [1.3, 2.3] },
    butterfly: { emoji: '🦋', points: 25, size: 38, speed: 95, rest: [1.8, 2.8] },
    goldfly: { emoji: '🪰', points: 50, size: 32, speed: 240, rest: [.75, 1.1] },
    bee: { emoji: '🐝', points: 0, size: 34, speed: 125, rest: [1.6, 2.6] },
  };
  const L = { size: { w: W, h: H }, foldX: W / 2, gap: 6 };
  L.left = { x: 0, y: 0, w: L.foldX - L.gap, h: H };
  L.right = { x: L.foldX + L.gap, y: 0, w: W - L.foldX - L.gap, h: H };
  const stageTeeth = 15;

  const g = {
    phase: 'ready', bugs: [], texts: [], particles: [], score: 0, hearts: 3, timeLeft: 60, best: 0,
    lifetime: 0, belly: [], roundEaten: [], time: 0, snapTime: -10, bloomTime: 0, overTime: -10,
    closed: false, nextSpawn: .8, elapsed: 0, needsBurst: true, id: 0,
  };
  const bloom = () => clamp((g.time - g.bloomTime) / 1.5, 0, 1);
  const snapFlash = () => { const t = (g.time - g.snapTime) / .38; return t < 1 ? t : null; };
  const say = (text, x, y, color, size = 28) => g.texts.push({ text, x, y, color, size, birth: g.time });

  function landingSpot() {
    for (let i = 0; i < 24; i++) {
      const left = Math.random() < .5, lobe = left ? L.left : L.right;
      const a = rand(.18, .78), b = rand(-.62, .62);
      if (a * a + b * b >= .62) continue;
      return [left ? lobe.x + lobe.w - a * lobe.w : lobe.x + a * lobe.w, lobe.y + lobe.h / 2 + b * lobe.h / 2];
    }
    return [L.left.w / 2, H / 2];
  }
  const wander = () => [rand(W * .08, W * .92), rand(H * .1, H * .9)];
  function offscreen() {
    const m = 50;
    switch (Math.floor(Math.random() * 4)) {
      case 0: return [rand(0, W), -m];
      case 1: return [rand(0, W), H + m];
      case 2: return [-m, rand(0, H)];
      default: return [W + m, rand(0, H)];
    }
  }
  function escape(b, panic) {
    b.state = 'escaping'; b.stateTime = g.time;
    const [dx, dy] = norm(b.x < L.foldX ? -1 : 1, rand(-.7, .7));
    b.vx = dx * KINDS[b.kind].speed * panic; b.vy = dy * KINDS[b.kind].speed * panic;
  }
  function start() {
    Object.assign(g, { phase: 'playing', score: 0, hearts: 3, timeLeft: 60, elapsed: 0, nextSpawn: g.time + .6, roundEaten: [] });
    say('Hunt!', L.foldX, H * .42, T.catchable, 40);
  }
  function scatterAll() { g.bugs.forEach(b => { if (b.state === 'flying' || b.state === 'landed') escape(b, 1.5); }); }
  function endRound() {
    if (g.phase !== 'playing') return;
    g.phase = 'over'; g.overTime = g.time;
    if (g.score > g.best) g.best = g.score;
    scatterAll();
  }
  function snap() {
    g.snapTime = g.time;
    if (g.phase === 'ready' || (g.phase === 'over' && g.time - g.overTime > 1)) { scatterAll(); start(); return; }
    if (g.phase !== 'playing') return;
    const caught = []; let stung = false;
    for (const b of g.bugs) {
      if (b.state === 'landed' && b.kind === 'bee') { stung = true; say('Ouch! 🐝', b.x, b.y, T.danger, 30); escape(b, 1.8); }
      else if (b.state === 'landed') { caught.push(b); b.state = 'caught'; b.from = [b.x, b.y]; b.stateTime = g.time; }
      else if (b.state === 'flying') escape(b, 1.6);
    }
    if (stung) g.hearts--;
    if (!caught.length) { if (!stung) say('Whiff!', L.foldX, H * .42, 'rgba(255,255,255,.8)', 24); }
    else {
      const n = caught.length, pts = caught.reduce((s, b) => s + KINDS[b.kind].points, 0) * n;
      g.score += pts; g.belly.push(...caught.map(b => b.kind)); g.roundEaten.push(...caught.map(b => b.kind)); g.lifetime += n;
      const ax = caught.reduce((s, b) => s + b.x, 0) / n, ay = caught.reduce((s, b) => s + b.y, 0) / n;
      say('+' + pts, ax, ay, T.pollen, 34);
      if (n > 1) say(`×${n} COMBO!`, ax, ay - 44, T.catchable, 26);
      if (caught.some(b => b.kind === 'goldfly')) { g.timeLeft += 5; say('+5s ⏱', ax, ay + 40, T.gold, 24); }
      for (const b of caught) for (let i = 0; i < 14; i++) {
        const a = rand(0, Math.PI * 2), s = rand(80, 320);
        g.particles.push({ x: L.foldX, y: b.y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, color: pick([T.pollen, T.catchable, '#ffffff', T.blush]), r: rand(1.5, 4), birth: g.time, life: rand(.4, .9), drag: 3 });
      }
    }
    if (g.hearts <= 0) endRound();
  }
  function didOpen() { g.closed = false; g.belly = []; g.bloomTime = g.time; g.needsBurst = true; }

  function burst() {
    for (let i = 0; i < 60; i++) {
      const d = Math.random() < .5 ? 1 : -1;
      g.particles.push({ x: L.foldX, y: rand(0, H), vx: d * rand(60, 420), vy: rand(-80, 80), color: pick([T.pollen, T.catchable, '#ffffff']), r: rand(1.5, 3.5), birth: g.time + rand(0, .3), life: rand(1, 2.2), drag: 1.4 });
    }
    say('*yaaawn*', L.foldX, H * .2, 'rgba(255,255,255,.85)', 22);
  }

  function tick(dt) {
    g.time += dt;
    if (g.needsBurst) { g.needsBurst = false; burst(); }
    g.particles = g.particles.filter(p => g.time - p.birth <= p.life);
    for (const p of g.particles) if (p.birth <= g.time) { p.x += p.vx * dt; p.y += p.vy * dt; const k = Math.max(0, 1 - p.drag * dt); p.vx *= k; p.vy *= k; }
    g.texts = g.texts.filter(t => g.time - t.birth <= 1.15);
    if (g.closed) return;
    if (g.phase === 'playing') { g.elapsed += dt; g.timeLeft -= dt; if (g.timeLeft <= 0) { g.timeLeft = 0; endRound(); } }
    // spawn
    const maxBugs = g.phase === 'playing' ? Math.min(4 + Math.floor(g.elapsed / 12), 8) : 3;
    const active = g.bugs.filter(b => b.state === 'flying' || b.state === 'landed').length;
    if (g.time >= g.nextSpawn && active < maxBugs && g.phase !== 'over') {
      const interval = g.phase === 'playing' ? Math.max(.55, 1.35 - g.elapsed * .012) : 2;
      g.nextSpawn = g.time + interval * rand(.7, 1.3);
      let kind = 'fly';
      if (g.phase !== 'ready') {
        const r = Math.random(), bee = .16 + g.elapsed * .003;
        kind = r < .05 ? 'goldfly' : r < .17 ? 'butterfly' : r < .17 + bee ? 'bee' : 'fly';
      }
      const [x, y] = offscreen(), [tx, ty] = wander();
      g.bugs.push({ id: ++g.id, kind, x, y, vx: 0, vy: 0, tx, ty, wantsToLand: false, state: 'flying', stateTime: g.time, next: g.time + rand(.6, 1.6), landings: kind === 'goldfly' ? 1 : 1 + Math.floor(Math.random() * 3), seed: rand(0, 1000) });
    }
    for (const b of g.bugs) {
      const k = KINDS[b.kind];
      if (b.state === 'flying') {
        if (g.time >= b.next && !b.wantsToLand) { b.wantsToLand = true; [b.tx, b.ty] = landingSpot(); }
        const dx = b.tx - b.x, dy = b.ty - b.y, dist = Math.hypot(dx, dy);
        if (dist < 10) {
          if (b.wantsToLand) { b.state = 'landed'; b.stateTime = g.time; b.vx = b.vy = 0; b.x = b.tx; b.y = b.ty; b.next = g.time + rand(...k.rest); }
          else[b.tx, b.ty] = wander();
        } else {
          const speed = k.speed * (b.wantsToLand ? Math.min(1, dist / 90 + .35) : 1);
          const [nx, ny] = norm(dx, dy), w = Math.sin(g.time * 9 + b.seed) * .9;
          const [ddx, ddy] = norm(nx - ny * w, ny + nx * w);
          const steer = Math.min(1, 4 * dt);
          b.vx += (ddx * speed - b.vx) * steer; b.vy += (ddy * speed - b.vy) * steer;
          b.x += b.vx * dt; b.y += b.vy * dt;
        }
      } else if (b.state === 'landed') {
        if (g.time >= b.next) {
          b.landings--; b.wantsToLand = false; b.stateTime = g.time;
          if (b.landings <= 0) escape(b, 1);
          else { b.state = 'flying'; [b.tx, b.ty] = wander(); b.next = g.time + rand(.8, 2); }
        }
      } else if (b.state === 'caught') {
        const t = Ease.inCubic((g.time - b.stateTime) / .45);
        b.x = b.from[0] + (L.foldX - b.from[0]) * t;
      } else { b.x += b.vx * dt; b.y += b.vy * dt; }
    }
    g.bugs = g.bugs.filter(b => b.state === 'caught' ? g.time - b.stateTime <= .6 : b.state === 'escaping' ? !(b.x < -120 || b.y < -120 || b.x > W + 120 || b.y > H + 120) : true);
  }

  // ---------- Trap renderer ----------
  const toothLength = Math.min(W / 2, H) * .075;
  function lobeCurve(left) {
    const r = left ? L.left : L.right, w = r.w, h = r.h, m = toothLength * 1.7;
    const maxX = r.x + r.w, minX = r.x, minY = r.y, maxY = r.y + r.h, midY = r.y + r.h / 2;
    let p = [[maxX, minY + h * .05], [maxX - w * .32, minY - h * .01], [minX + m, minY + h * .17], [minX + m, midY], [minX + m, maxY - h * .17], [maxX - w * .32, maxY + h * .01], [maxX, maxY - h * .05]];
    if (!left) p = p.map(([x, y]) => [minX + maxX - x, y]);
    const foldMid = [left ? maxX : minX, midY];
    return {
      p, r, left,
      sample(s) {
        const seg = s < .5 ? 0 : 3, t = s < .5 ? s * 2 : (s - .5) * 2;
        const [a, b, c, d] = [p[seg], p[seg + 1], p[seg + 2], p[seg + 3]], mt = 1 - t;
        const w0 = mt * mt * mt, w1 = 3 * mt * mt * t, w2 = 3 * mt * t * t, w3 = t * t * t;
        const d0 = 3 * mt * mt, d1 = 6 * mt * t, d2 = 3 * t * t;
        return [[w0 * a[0] + w1 * b[0] + w2 * c[0] + w3 * d[0], w0 * a[1] + w1 * b[1] + w2 * c[1] + w3 * d[1]],
          [d0 * (b[0] - a[0]) + d1 * (c[0] - b[0]) + d2 * (d[0] - c[0]), d0 * (b[1] - a[1]) + d1 * (c[1] - b[1]) + d2 * (d[1] - c[1])]];
      },
      normal(pt, tan) {
        const [tx, ty] = norm(tan[0], tan[1]); let n = [-ty, tx];
        if (n[0] * (pt[0] - foldMid[0]) + n[1] * (pt[1] - foldMid[1]) < 0) n = [-n[0], -n[1]];
        return n;
      },
      path() {
        const P = new Path2D(); P.moveTo(...p[0]);
        P.bezierCurveTo(...p[1], ...p[2], ...p[3]); P.bezierCurveTo(...p[4], ...p[5], ...p[6]); P.closePath(); return P;
      },
    };
  }

  function drawTrap(closure) {
    const t = g.time, b = bloom();
    const bg = ctx.createRadialGradient(L.foldX, H / 2, 0, L.foldX, H / 2, Math.max(W, H) * .75);
    bg.addColorStop(0, T.bgInner); bg.addColorStop(1, T.bgOuter);
    ctx.fillStyle = bg; ctx.fillRect(0, 0, W, H);
    for (let i = 0; i < 30; i++) {
      let x = (i * .618 * W + t * (6 + (i % 5) * 3)) % W, y = (i * .377 * H - t * (4 + ((i * 7) % 6) * 2)) % H;
      if (y < 0) y += H;
      const r = 1.2 + (i % 3);
      ctx.fillStyle = rgba(T.pollen, .12 + .12 * Math.sin(t * 1.3 + i));
      ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
    }
    for (const left of [true, false]) drawLobe(left, b, closure);
    // throat
    const half = L.gap + 18 + 50 * closure;
    const tg = ctx.createLinearGradient(L.foldX - half, 0, L.foldX + half, 0);
    tg.addColorStop(0, 'rgba(0,0,0,0)'); tg.addColorStop(.5, `rgba(0,0,0,${.3 + .4 * closure})`); tg.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = tg; ctx.fillRect(L.foldX - half, 0, half * 2, H);
    drawBugs(closure);
    for (const p of g.particles) {
      const age = g.time - p.birth; if (age < 0) continue;
      const k = age / p.life, r = p.r * (1 - .4 * k);
      ctx.globalAlpha = Math.max(0, 1 - k); ctx.fillStyle = p.color;
      ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, Math.PI * 2); ctx.fill();
    }
    ctx.globalAlpha = 1;
    drawSnapFlash();
    for (const tx of g.texts) {
      const age = g.time - tx.birth, k = age / 1.15, pop = Ease.outBack(age / .18, 2.5);
      const alpha = k < .6 ? 1 : 1 - (k - .6) / .4;
      ctx.save(); ctx.translate(tx.x, tx.y - 60 * Ease.outCubic(k)); ctx.scale(pop, pop); ctx.globalAlpha = Math.max(0, alpha);
      ctx.font = `900 ${tx.size}px ui-rounded, system-ui, sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillStyle = 'rgba(0,0,0,.7)'; ctx.fillText(tx.text, 2, 2); ctx.fillStyle = tx.color; ctx.fillText(tx.text, 0, 0);
      ctx.restore();
    }
  }

  function drawLobe(left, b, closure) {
    const c = lobeCurve(left), r = c.r, foldEdge = left ? r.x + r.w : r.x, midY = r.y + r.h / 2;
    ctx.save();
    const sx = Math.max(Ease.outBack(b / .62, 1.4), .001), sy = .72 + .28 * Ease.outCubic(b / .5);
    ctx.translate(foldEdge, midY); ctx.scale(sx, sy); ctx.translate(-foldEdge, -midY);
    // teeth
    for (let i = 0; i < stageTeeth; i++) {
      const s = .05 + .9 * i / (stageTeeth - 1);
      const [p, tan] = c.sample(s), n = c.normal(p, tan);
      const delay = .3 + Math.abs(s - .5) * .9, grow = Ease.outBack((b - delay) / .28, 2.2);
      if (grow <= .01) continue;
      const jitter = .85 + .15 * Math.sin(i * 1.7);
      const shiver = closure > .2 ? Math.sin(g.time * 30 + i) * .05 * closure : 0;
      const wiggle = Math.sin(g.time * 2.6 + i * .9) * .06 + shiver;
      const len = toothLength * jitter * (1 + .55 * closure) * grow;
      const toward = (midY - p[1]) / (r.h / 2), curl = toward * (.15 + .75 * closure);
      const [tnx, tny] = norm(tan[0], tan[1]);
      const [dx, dy] = norm(n[0] + tnx * wiggle, n[1] + curl + tny * wiggle);
      const sxv = -dy, syv = dx, wdt = toothLength * .17;
      const tip = [p[0] + dx * len, p[1] + dy * len];
      ctx.beginPath();
      ctx.moveTo(p[0] + sxv * wdt, p[1] + syv * wdt);
      ctx.quadraticCurveTo(p[0] + dx * len * .55 + sxv * wdt * .35, p[1] + dy * len * .55 + syv * wdt * .35, tip[0], tip[1]);
      ctx.quadraticCurveTo(p[0] + dx * len * .55 - sxv * wdt * .35, p[1] + dy * len * .55 - syv * wdt * .35, p[0] - sxv * wdt, p[1] - syv * wdt);
      ctx.closePath();
      const tg = ctx.createLinearGradient(p[0], p[1], tip[0], tip[1]); tg.addColorStop(0, T.tooth); tg.addColorStop(1, T.toothTip);
      ctx.fillStyle = tg; ctx.fill();
    }
    const path = c.path(), outerX = left ? r.x : r.x + r.w;
    const blush = .74 - .36 * closure;
    const lg = ctx.createLinearGradient(outerX, midY, foldEdge, midY);
    lg.addColorStop(0, T.rim); lg.addColorStop(.12, T.leaf); lg.addColorStop(Math.max(blush - .2, .13), T.leaf); lg.addColorStop(blush, T.blush); lg.addColorStop(1, T.crimson);
    ctx.fillStyle = lg; ctx.fill(path);
    ctx.beginPath();
    for (let k = 0; k < 7; k++) {
      const s = .12 + .76 * k / 6, [rp] = c.sample(s);
      const st = [foldEdge, midY + (rp[1] - midY) * .55], cp = [(foldEdge + rp[0]) / 2, midY + (rp[1] - midY) * .95];
      ctx.moveTo(...st); ctx.quadraticCurveTo(...cp, st[0] + (rp[0] - st[0]) * .88, st[1] + (rp[1] - st[1]) * .88);
    }
    ctx.strokeStyle = rgba(T.crimson, .28); ctx.lineWidth = 1.5; ctx.stroke();
    const gc = [outerX + (foldEdge - outerX) * .35, r.y + r.h * .3], gr = Math.min(r.w, r.h) * .35;
    const gg = ctx.createRadialGradient(gc[0], gc[1], 0, gc[0], gc[1], gr); gg.addColorStop(0, 'rgba(255,255,255,.13)'); gg.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = gg; ctx.beginPath(); ctx.arc(gc[0], gc[1], gr, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = T.rim; ctx.lineWidth = 3; ctx.stroke(path);
    // trigger hairs
    const appear = Ease.outCubic((b - .7) / .3);
    if (appear > 0) {
      const landed = g.bugs.filter(x => x.state === 'landed');
      for (const along of [-.28, 0, .28]) {
        const bx = left ? r.x + r.w - r.w * .33 : r.x + r.w * .33, by = midY + along * r.h / 2;
        const dist = landed.some(x => Math.hypot(x.x - bx, x.y - by) < 80);
        const tw = dist ? Math.sin(g.time * 40 + along * 10) * .45 : Math.sin(g.time * 1.5 + along * 4) * .1;
        const hl = 16 * appear, tip = [bx + Math.sin(tw) * hl, by - Math.cos(tw) * hl];
        ctx.strokeStyle = rgba(T.toothTip, .75); ctx.lineWidth = 1.6; ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(...tip); ctx.stroke();
        ctx.fillStyle = dist ? T.pollen : rgba(T.toothTip, .9); ctx.beginPath(); ctx.arc(tip[0], tip[1], 2.5, 0, Math.PI * 2); ctx.fill();
      }
    }
    ctx.restore();
  }

  function emoji(e, x, y, size, scale = 1, rot = 0) {
    if (scale <= .01) return;
    ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.scale(scale, scale);
    ctx.font = `${size}px "Apple Color Emoji","Noto Color Emoji",sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(e, 0, 0); ctx.restore();
  }

  function drawBugs(closure) {
    for (const b of g.bugs) {
      const k = KINDS[b.kind];
      let x = b.x, y = b.y, scale = 1, rot = 0;
      if (b.state === 'flying' || b.state === 'escaping') { y -= Math.sin(g.time * 14 + b.seed) * 3; rot = clamp(b.vx / 500, -.35, .35); }
      else if (b.state === 'landed') {
        const s = k.size, age = g.time - b.stateTime, pulse = .5 + .5 * Math.sin(g.time * 6 + b.seed);
        const color = b.kind === 'bee' ? T.danger : T.catchable;
        ctx.fillStyle = 'rgba(0,0,0,.3)'; ctx.beginPath(); ctx.ellipse(x, y + s * .35, s * .45, s * .15, 0, 0, Math.PI * 2); ctx.fill();
        const r = s * (.78 + .08 * pulse) * (.4 + .6 * Ease.outCubic(age / .25));
        ctx.strokeStyle = rgba(color, .25 + .3 * pulse); ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.stroke();
        const rem = clamp((b.next - g.time) / Math.max(b.next - b.stateTime, .01), 0, 1);
        ctx.strokeStyle = rgba(color, .9); ctx.lineWidth = 3; ctx.lineCap = 'round';
        ctx.beginPath(); ctx.arc(x, y, r + 4, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * rem); ctx.stroke();
      } else if (b.state === 'caught') {
        const t = (g.time - b.stateTime) / .45; scale = Math.max(0, 1 - Ease.inCubic(t)); rot = t * 8;
      }
      if (b.kind === 'goldfly') {
        const r = k.size * 1.1 * scale, gg = ctx.createRadialGradient(x, y, 0, x, y, Math.max(r, .1));
        gg.addColorStop(0, rgba(T.gold, .75)); gg.addColorStop(1, rgba(T.gold, 0)); ctx.fillStyle = gg; ctx.fillRect(x - r, y - r, r * 2, r * 2);
      }
      emoji(k.emoji, x, y, k.size, scale, rot);
      if (b.state === 'landed' && closure > .3) emoji('❗️', x + 16, y - 24, 16, .6 + closure * .6);
    }
  }

  function drawSnapFlash() {
    const t = snapFlash(); if (t === null) return;
    const fade = 1 - t;
    ctx.fillStyle = `rgba(255,255,255,${.32 * fade * fade})`; ctx.fillRect(0, 0, W, H);
    const k = Ease.outCubic(t / .45), step = 34, amp = 16;
    for (const left of [true, false]) {
      const x = left ? L.foldX * k : W - (W - L.foldX) * k;
      ctx.beginPath(); let y = left ? 0 : -step / 2, out = true; ctx.moveTo(x, y);
      while (y < H + step) { y += step / 2; ctx.lineTo(x + (out ? (left ? amp : -amp) : 0), y); out = !out; }
      ctx.save(); ctx.filter = 'blur(8px)'; ctx.strokeStyle = rgba(T.toothTip, .9 * fade); ctx.lineWidth = 10; ctx.stroke(); ctx.restore();
      ctx.strokeStyle = `rgba(255,255,255,${fade})`; ctx.lineJoin = 'round'; ctx.lineWidth = 3 + 3 * fade; ctx.stroke();
    }
  }

  function card(x, y, w, h) {
    ctx.fillStyle = 'rgba(0,0,0,.5)'; ctx.strokeStyle = rgba(T.catchable, .35); ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.roundRect(x, y, w, h, 22); ctx.fill(); ctx.stroke();
  }
  function text(s, x, y, size, color = '#fff', weight = 800, align = 'center') {
    ctx.font = `${weight} ${size}px ui-rounded, system-ui, sans-serif`; ctx.textAlign = align; ctx.textBaseline = 'middle'; ctx.fillStyle = color; ctx.fillText(s, x, y);
  }

  function drawHUD(r) {
    const lw = L.left.w, rx = L.right.x, rw = L.right.w;
    if (g.phase !== 'ready') { text(String(g.score), 24 + 2, 52 + 2, 50, 'rgba(0,0,0,.6)', 900, 'left'); text(String(g.score), 24, 52, 50, '#fff', 900, 'left'); }
    if (g.phase === 'playing') {
      for (let i = 0; i < 3; i++) text(i < g.hearts ? '❤️' : '🤍', W - 24 - (2 - i) * 30, 40, 22, '#fff', 400, 'right');
      const secs = Math.ceil(g.timeLeft);
      ctx.fillStyle = secs <= 10 ? rgba(T.danger, .85) : 'rgba(0,0,0,.45)'; ctx.beginPath(); ctx.roundRect(W - 100, 62, 76, 30, 15); ctx.fill();
      text('⏱ ' + secs, W - 62, 78, 17, '#fff', 800);
    }
    if (g.phase === 'ready') {
      card(lw / 2 - 150, H / 2 - 80, 300, 150);
      text('Snaptrap', lw / 2 + 3, H / 2 - 30 + 3, 50, T.crimson, 900); text('Snaptrap', lw / 2, H / 2 - 30, 50, '#fff', 900);
      text('A hungry flytrap', lw / 2, H / 2 + 20, 18, 'rgba(255,255,255,.8)', 600); text('for iPhone Duo', lw / 2, H / 2 + 44, 18, 'rgba(255,255,255,.8)', 600);
      const cx = rx + rw / 2; card(cx - 160, H / 2 - 110, 320, 220);
      [['🪰', 'Bugs land on the leaves.'], ['🫳', 'Snap the phone shut to eat.'], ['🐝', 'Never eat a bee!'], ['📕', 'Close fully to digest.']].forEach(([e, s], i) => {
        text(e, cx - 136, H / 2 - 76 + i * 34, 18, '#fff', 400, 'left'); text(s, cx - 104, H / 2 - 76 + i * 34, 15, '#fff', 600, 'left');
      });
      text('Press Snap! to start', cx, H / 2 + 80, 16, T.catchable, 900);
    }
    if (g.phase === 'over') {
      card(lw / 2 - 140, H / 2 - 80, 280, 160);
      text(g.score >= g.best && g.score > 0 ? 'New best!' : "Time's up", lw / 2, H / 2 - 45, 26, g.score >= g.best && g.score > 0 ? T.gold : '#fff', 900);
      text(String(g.score), lw / 2, H / 2 + 5, 56, '#fff', 900); text('Best ' + g.best, lw / 2, H / 2 + 50, 15, 'rgba(255,255,255,.7)', 700);
      const cx = rx + rw / 2; card(cx - 150, H / 2 - 60, 300, 120);
      text('Snap! to play again', cx, H / 2, 17, T.catchable, 900);
    }
    // hinge meter
    const mx = W - 200, my = H - 50;
    ctx.fillStyle = 'rgba(0,0,0,.4)'; ctx.beginPath(); ctx.roundRect(mx - 12, my - 26, 188, 46, 14); ctx.fill();
    text((armed ? '● Ready to bite ' : '○ Open wider ') + Math.round(r.degrees) + '°', mx + 82, my - 12, 12, armed ? T.catchable : '#fff', 800);
    ctx.fillStyle = 'rgba(255,255,255,.15)'; ctx.beginPath(); ctx.roundRect(mx, my, 164, 8, 4); ctx.fill();
    const mg = ctx.createLinearGradient(mx, 0, mx + 164, 0); mg.addColorStop(0, T.crimson); mg.addColorStop(1, T.leaf);
    ctx.fillStyle = mg; ctx.beginPath(); ctx.roundRect(mx, my, 164 * clamp(r.degrees / 180, 0, 1), 8, 4); ctx.fill();
    ctx.fillStyle = T.danger; ctx.fillRect(mx + 164 * SNAP / 180 - 1, my - 3, 2, 14);
    ctx.fillStyle = T.catchable; ctx.fillRect(mx + 164 * ARM / 180 - 1, my - 3, 2, 14);
  }

  // ---------- Cover (closed) ----------
  let coverAppeared = 0;
  function drawCover(now) {
    const t = (now - coverAppeared) / 1000;
    ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H);
    const cw = 300, cx0 = (W - cw) / 2;
    ctx.save(); ctx.beginPath(); ctx.roundRect(cx0, 0, cw, H, 26); ctx.clip();
    const bg = ctx.createRadialGradient(W / 2, H / 2, 0, W / 2, H / 2, 500); bg.addColorStop(0, T.bgInner); bg.addColorStop(1, T.bgOuter);
    ctx.fillStyle = bg; ctx.fillRect(cx0, 0, cw, H);
    const mood = g.belly.length ? 'chewing' : g.phase === 'playing' ? 'waiting' : 'sleeping';
    text(g.phase === 'playing' ? 'Snack break' : '🪴 Snapper', W / 2, 46, 22, '#fff', 900);
    text(g.phase === 'playing' ? "The round is paused while I'm shut" : 'Snaptrap', W / 2, 72, 12, 'rgba(255,255,255,.6)', 600);
    // pod area
    ctx.save(); ctx.translate(cx0, 90); drawPod(t, mood, cw, 300); ctx.restore();
    text(g.belly.length ? `Digesting ${g.belly.length} bug${g.belly.length === 1 ? '' : 's'}` : mood === 'sleeping' ? 'Zzz… nothing in my belly' : 'Still hungry…', W / 2, 410, 15, '#fff', 700);
    if (g.belly.length) text(g.belly.slice(-8).map(k => KINDS[k].emoji).join(''), W / 2, 438, 22, '#fff', 400);
    ctx.fillStyle = 'rgba(0,0,0,.35)'; ctx.beginPath(); ctx.roundRect(cx0 + 20, 462, cw - 40, 56, 16); ctx.fill();
    [['Score', g.score], ['Best', g.best], ['Eaten', g.lifetime]].forEach(([l, v], i) => {
      const x = cx0 + 20 + (cw - 40) * (i + .5) / 3; text(String(v), x, 482, 20, '#fff', 900); text(l, x, 505, 11, 'rgba(255,255,255,.6)', 600);
    });
    ctx.globalAlpha = .55 + .45 * Math.sin(t * 2.4); text('📖 Unfold to hunt', W / 2, 545, 15, T.catchable, 900); ctx.globalAlpha = 1;
    ctx.restore();
  }

  function drawPod(t, mood, w, h) {
    const c = [w / 2, h * .47], hw = Math.min(w * .32, 110), hh = Math.min(h * .32, 110);
    const spring = 1 - Math.exp(-7 * t) * Math.cos(13 * t), together = Math.min(spring, 1), squash = Math.max(spring - 1, 0);
    const spread = (1 - together) * w * .6, tilt = (1 - together) * 32 * Math.PI / 180;
    const settled = Ease.outCubic((t - .5) / .4);
    let chewX = 1, chewY = 1, grind = 0;
    if (mood === 'chewing') { chewY = 1 + .045 * Math.sin(t * 9) * settled; chewX = 1 - .025 * Math.sin(t * 9) * settled; grind = 4 * Math.sin(t * 9) * settled; }
    else if (mood === 'sleeping') chewY = 1 + .018 * Math.sin(t * 1.6) * settled;
    else chewY = 1 + .012 * Math.sin(t * 3) * settled;
    // pot
    const potTop = h * .88, bottom = c[1] + hh;
    ctx.strokeStyle = T.rim; ctx.lineWidth = 8; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(w / 2, bottom - 10); ctx.quadraticCurveTo(w / 2 + 14 * Math.sin(t * 1.2), (bottom + potTop) / 2, w / 2, potTop); ctx.stroke();
    ctx.fillStyle = '#b8613d'; ctx.beginPath(); ctx.moveTo(w / 2 - 60, potTop); ctx.lineTo(w / 2 + 60, potTop); ctx.lineTo(w / 2 + 46, h); ctx.lineTo(w / 2 - 46, h); ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#d1754d'; ctx.beginPath(); ctx.roundRect(w / 2 - 66, potTop - 4, 132, 14, 4); ctx.fill();

    ctx.save();
    ctx.translate(c[0], bottom); ctx.scale((1 - .6 * squash) * chewX, (1 + .5 * squash) * chewY); ctx.translate(-c[0], -bottom);
    const halfT = left => {
      ctx.translate((left ? -1 : 1) * spread, left ? grind : -grind);
      ctx.translate(c[0], bottom); ctx.rotate(left ? -tilt : tilt); ctx.translate(-c[0], -bottom);
    };
    for (const left of [true, false]) {
      ctx.save(); halfT(left);
      const s = left ? -1 : 1;
      const body = new Path2D();
      body.moveTo(c[0], c[1] - hh);
      body.bezierCurveTo(c[0] + s * hw * .6, c[1] - hh, c[0] + s * hw, c[1] - hh * .55, c[0] + s * hw, c[1]);
      body.bezierCurveTo(c[0] + s * hw, c[1] + hh * .55, c[0] + s * hw * .6, c[1] + hh, c[0], c[1] + hh);
      body.closePath();
      const lg = ctx.createLinearGradient(c[0] + s * hw, c[1], c[0], c[1]);
      lg.addColorStop(0, T.rim); lg.addColorStop(.3, T.leaf); lg.addColorStop(.72, T.leaf); lg.addColorStop(1, T.blush);
      ctx.fillStyle = lg; ctx.fill(body); ctx.strokeStyle = T.rim; ctx.lineWidth = 3; ctx.stroke(body);
      ctx.restore();
    }
    for (const left of [true, false]) {
      ctx.save(); halfT(left);
      const s = left ? -1 : 1;
      for (let k = 0; k < stageTeeth; k++) {
        if ((k % 2 === 0) !== left) continue;
        const y = c[1] - hh * .82 + k * (hh * 1.64 / (stageTeeth - 1)), q = Math.abs(y - c[1]) / hh, edge = 10 * q * q;
        ctx.beginPath(); ctx.moveTo(c[0], y - 6);
        ctx.quadraticCurveTo(c[0] - s * 10, y - 4, c[0] - s * (20 - edge), y);
        ctx.quadraticCurveTo(c[0] - s * 10, y + 4, c[0], y + 6); ctx.closePath();
        ctx.fillStyle = T.tooth; ctx.fill();
      }
      ctx.restore();
    }
    if (together > .95) {
      const eyeY = c[1] - hh * .38, blink = mood === 'waiting' && (t % 3.2) > 3.05;
      for (const s of [-1, 1]) {
        const ex = c[0] + s * hw * .42;
        ctx.lineWidth = 4; ctx.lineCap = 'round'; ctx.strokeStyle = 'rgba(0,0,0,.8)';
        if (mood === 'waiting' && !blink) {
          ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.ellipse(ex, eyeY, 12, 14, 0, 0, Math.PI * 2); ctx.fill();
          ctx.fillStyle = '#000'; ctx.beginPath(); ctx.ellipse(ex + Math.sin(t * .9) * 5, eyeY + 3, 6, 7, 0, 0, Math.PI * 2); ctx.fill();
        } else if (mood === 'chewing') {
          ctx.beginPath(); ctx.moveTo(ex - 11, eyeY + 5); ctx.quadraticCurveTo(ex, eyeY - 12, ex + 11, eyeY + 5); ctx.stroke();
        } else {
          ctx.beginPath(); ctx.moveTo(ex - 11, eyeY); ctx.quadraticCurveTo(ex, eyeY + 10, ex + 11, eyeY); ctx.stroke();
        }
        ctx.fillStyle = rgba(T.blush, .55); ctx.beginPath(); ctx.ellipse(c[0] + s * hw * .55, eyeY + 28, 12, 6, 0, 0, Math.PI * 2); ctx.fill();
      }
    }
    ctx.restore();
    if (t > .8 && mood !== 'waiting') {
      for (let i = 0; i < 3; i++) {
        const per = 2.4, ph = ((t + i * per / 3) % per) / per;
        ctx.globalAlpha = ph < .8 ? 1 : (1 - ph) / .2;
        text(mood === 'chewing' ? (i === 0 ? 'burp!' : '•') : 'z', c[0] + 40 + i * 12 + Math.sin(ph * 6 + i) * 8, c[1] - hh - ph * 55, mood === 'chewing' ? 14 + i * 2 : 16 + i * 6, '#fff', 800);
      }
      ctx.globalAlpha = 1;
    }
  }

  // ---------- Loop ----------
  let last = performance.now(), prev = reading();
  function frame(now) {
    stepHinge(now);
    const r = reading();
    slider.value = Math.round(r.degrees); degLabel.textContent = Math.round(r.degrees) + '°';
    if (detect(r)) snap();
    if (prev.closed !== r.closed) { if (r.closed) { g.closed = true; coverAppeared = now; } else didOpen(); }
    prev = r;
    tick(Math.min((now - last) / 1000, .05)); last = now;
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    if (r.closed) drawCover(now);
    else {
      const sh = snapFlash(); ctx.save();
      if (sh !== null) ctx.translate(12 * (1 - sh) * Math.sin(sh * 60), 0);
      drawTrap(closureOf(r)); ctx.restore(); drawHUD(r);
    }
    requestAnimationFrame(frame);
  }
  detect(reading());
  // Expose for automated screenshots.
  window.snaptrap = { g, hinge, reading };
  requestAnimationFrame(frame);
})();
