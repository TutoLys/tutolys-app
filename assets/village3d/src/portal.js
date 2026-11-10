// The portal: what a tap on a building plays before the app opens it. A
// golden whirl opens on the building's door while the camera pushes in,
// spins faster as it grows, and ends in a warm gold flash that fills the
// screen, "like going through a portal to another universe" (Hafid,
// 2026-11-10). Only then does the scene post `open{id}` (BRIDGE.md).
//
// With reduced motion there is no whirl and no camera move: a short, soft
// gold fade instead.
//
// Drawn on its own 2D canvas over the WebGL stage, only while it plays.

export const PORTAL_MS = 2400; // whirl → flash; then `open`
export const PORTAL_REDUCED_MS = 380; // plain fade; then `open`
const HOLD_MS = 500; // gold stays up after `open`, so the app's cut lands on it
const FADE_MS = 900; // and fades back if the app hasn't left the village

const easeIn = (k) => k * k * k;
const easeOut = (k) => 1 - (1 - k) ** 3;
const clamp01 = (k) => Math.max(0, Math.min(1, k));
const span = (t, a, b) => clamp01((t - a) / (b - a));

export function createPortal(host) {
  const canvas = document.createElement('canvas');
  canvas.className = 'portal';
  canvas.setAttribute('aria-hidden', 'true');
  host.appendChild(canvas);
  const ctx = canvas.getContext('2d');
  let w = 0, h = 0;
  let run = null; // { t, reduced, onDone, done, center: () => {x,y} }
  const sparks = Array.from({ length: 46 }, (_, i) => ({ a: (i / 46) * Math.PI * 2 + Math.random(), r: 0.55 + Math.random() * 0.6, s: 0.6 + Math.random() * 0.9, z: 1 + Math.random() * 2.2 }));

  function size() {
    const r = host.getBoundingClientRect();
    // DPR 1 on purpose: a soft glow needs no detail, and it keeps the fill cheap.
    if (r.width !== w || r.height !== h) { w = canvas.width = Math.max(1, Math.round(r.width)); h = canvas.height = Math.max(1, Math.round(r.height)); }
  }

  function drawWhirl(cx, cy, R, rot, glow) {
    // Halo, then six curling arms in alternating gold and cream, then a core.
    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, R);
    g.addColorStop(0, `rgba(255,250,232,${0.95 * glow})`);
    g.addColorStop(0.35, `rgba(255,222,128,${0.75 * glow})`);
    g.addColorStop(0.75, `rgba(212,175,55,${0.35 * glow})`);
    g.addColorStop(1, 'rgba(212,175,55,0)');
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2); ctx.fill();
    const ARMS = 6, N = 26;
    for (let k = 0; k < ARMS; k++) {
      const base = rot + (k / ARMS) * Math.PI * 2;
      ctx.beginPath();
      for (let i = 0; i <= N; i++) { // outer edge, inward
        const u = i / N, a = base + u * 3.4, r = R * 0.92 * u, wdt = R * 0.075 * Math.sin(Math.PI * u);
        const x = cx + Math.cos(a) * r + Math.cos(a + Math.PI / 2) * wdt, y = cy + Math.sin(a) * r + Math.sin(a + Math.PI / 2) * wdt;
        i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
      }
      for (let i = N; i >= 0; i--) { // back along the other edge
        const u = i / N, a = base + u * 3.4, r = R * 0.92 * u, wdt = R * 0.075 * Math.sin(Math.PI * u);
        ctx.lineTo(cx + Math.cos(a) * r - Math.cos(a + Math.PI / 2) * wdt, cy + Math.sin(a) * r - Math.sin(a + Math.PI / 2) * wdt);
      }
      ctx.closePath();
      ctx.fillStyle = k % 2 ? `rgba(255,240,196,${0.85 * glow})` : `rgba(226,186,64,${0.8 * glow})`;
      ctx.fill();
    }
    const c = ctx.createRadialGradient(cx, cy, 0, cx, cy, R * 0.22);
    c.addColorStop(0, `rgba(255,255,248,${glow})`);
    c.addColorStop(1, 'rgba(255,244,210,0)');
    ctx.fillStyle = c;
    ctx.beginPath(); ctx.arc(cx, cy, R * 0.22, 0, Math.PI * 2); ctx.fill();
  }

  function drawSparks(cx, cy, R, t, glow) {
    // Specks of light drawn in towards the door, faster as the whirl grows.
    for (const s of sparks) {
      const k = (s.r - t * s.s * 0.45) % 1.15;
      const rr = R * 1.1 * ((k + 1.15) % 1.15);
      const a = s.a + t * s.z;
      ctx.fillStyle = `rgba(255,248,220,${0.9 * glow})`;
      ctx.beginPath(); ctx.arc(cx + Math.cos(a) * rr, cy + Math.sin(a) * rr, Math.max(1, R * 0.008 * s.z), 0, Math.PI * 2); ctx.fill();
    }
  }

  /** Per frame. Wall-clock timed (not the scene's clamped dt), so `opening.ms`
   *  holds on a slow device too. Returns true while the portal is on screen. */
  function update() {
    if (!run) return false;
    const now = performance.now();
    run.t += Math.min(now - run.last, 250); run.last = now;
    size();
    ctx.clearRect(0, 0, w, h);
    const total = run.reduced ? PORTAL_REDUCED_MS : PORTAL_MS;
    if (!run.done && run.t >= total) { run.done = true; run.onDone(); }
    const after = run.t - total;
    if (after > HOLD_MS + FADE_MS) { stop(); return false; }
    const fadeBack = after > HOLD_MS ? 1 - span(after, HOLD_MS, HOLD_MS + FADE_MS) : 1;
    if (run.reduced) {
      const f = Math.min(span(run.t, 0, total), 1) * fadeBack;
      ctx.fillStyle = `rgba(255,236,170,${0.92 * f})`; ctx.fillRect(0, 0, w, h);
      return true;
    }
    const s = run.t / 1000, k = span(run.t, 250, total);
    const { x, y } = run.center();
    const R = Math.hypot(w, h) * (0.04 + 1.05 * easeIn(k));
    const rot = s * (1.2 + 5.5 * k * k); // turns faster as it opens
    const glow = easeOut(span(run.t, 250, 900)) * fadeBack;
    drawWhirl(x, y, R, rot, glow);
    drawSparks(x, y, R, s, glow);
    const flash = easeIn(span(run.t, total - 650, total)) * fadeBack;
    if (flash > 0) { ctx.fillStyle = `rgba(255,244,206,${flash})`; ctx.fillRect(0, 0, w, h); }
    return true;
  }

  function start({ reduced, center, onDone }) {
    run = { t: 0, last: performance.now(), reduced, center, onDone, done: false };
    canvas.style.display = 'block';
  }
  function stop() {
    run = null;
    ctx.clearRect(0, 0, w, h);
    canvas.style.display = 'none';
  }
  canvas.style.display = 'none';

  return {
    start, stop, update,
    /** True from the tap until `open` is posted (input is ignored meanwhile). */
    get busy() { return !!run && !run.done; },
    get active() { return !!run; },
  };
}
