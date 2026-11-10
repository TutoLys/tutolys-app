// Canvas-drawn textures and shapes: the Québec flag, the fleur-de-lys
// (the app's own `FleurDeLys` path, lib/core/widgets/fleur_de_lys.dart),
// and the gold emblems the building art carries (π, atom, open book…).
import * as THREE from 'three';

// Right half of the app's fleur-de-lys, in its 100×108 box. Mirrored at x=50.
const FLEUR_HALF = [
  'M50 2 C58 14 66 26 64 42 C63 54 56 62 54 70 L50 70 Z',
  'M53 70 C58 54 70 40 84 42 C96 44 100 58 93 68 C89 74 81 73 80 67 C79 62 84 59 87 62 C88 56 82 52 75 55 C67 59 61 66 59 72 Z',
  'M50 80 L54 80 C55 90 58 98 63 104 C57 105 52 101 50 96 Z',
  'M56 80 C66 81 74 87 75 98 C71 93 65 91 60 93 C59 88 58 84 56 80 Z',
  'M50 69 L68 69 Q72 69 72 73 L72 76 Q72 80 68 80 L50 80 Z',
];

export function drawFleur(ctx, cx, cy, h, fill, stroke) {
  const s = h / 108;
  ctx.save();
  ctx.translate(cx - 50 * s, cy - 54 * s);
  ctx.scale(s, s);
  for (const mirror of [false, true]) {
    ctx.save();
    if (mirror) { ctx.translate(100, 0); ctx.scale(-1, 1); }
    for (const d of FLEUR_HALF) {
      const p = new Path2D(d);
      if (stroke) { ctx.lineWidth = 6; ctx.lineJoin = 'round'; ctx.strokeStyle = stroke; ctx.stroke(p); }
      ctx.fillStyle = fill; ctx.fill(p);
    }
    ctx.restore();
  }
  ctx.restore();
}

/** THREE.Shapes for an extruded fleur-de-lys, centred, 1 unit tall. */
export function fleurShapes() {
  const shapes = [];
  const parse = (d, mirror) => {
    const t = d.match(/[MLCQZ]|-?\d+(\.\d+)?/g);
    let i = 0; let shape = null;
    const X = (v) => ((mirror ? 100 - v : v) - 50) / 108;
    const Y = (v) => (54 - v) / 108;
    const num = () => parseFloat(t[i++]);
    while (i < t.length) {
      const c = t[i++];
      if (c === 'M') { shape = new THREE.Shape(); shape.moveTo(X(num()), Y(num())); }
      else if (c === 'L') shape.lineTo(X(num()), Y(num()));
      else if (c === 'C') { const a = [num(), num(), num(), num(), num(), num()]; shape.bezierCurveTo(X(a[0]), Y(a[1]), X(a[2]), Y(a[3]), X(a[4]), Y(a[5])); }
      else if (c === 'Q') { const a = [num(), num(), num(), num()]; shape.quadraticCurveTo(X(a[0]), Y(a[1]), X(a[2]), Y(a[3])); }
      else if (c === 'Z') { shapes.push(shape); }
    }
  };
  for (const d of FLEUR_HALF) { parse(d, false); parse(d, true); }
  // Mirrored shapes wind the other way; ExtrudeGeometry handles both, but
  // keep them consistent so normals agree.
  for (const s of shapes) {
    const pts = s.getPoints();
    if (THREE.ShapeUtils.isClockWise(pts)) {
      const r = new THREE.Shape(pts.reverse());
      s.curves = r.curves; s.currentPoint = r.currentPoint;
    }
  }
  return shapes;
}

function canvasTexture(w, h, draw, { srgb = true } = {}) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  const ctx = c.getContext('2d');
  draw(ctx, w, h);
  const tex = new THREE.CanvasTexture(c);
  if (srgb) tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 4;
  return tex;
}

let _flag;
/** Le fleurdelisé: blue field, white cross, four white fleurs-de-lys. */
export function quebecFlagTexture() {
  if (_flag) return _flag;
  _flag = canvasTexture(384, 256, (ctx, w, h) => {
    ctx.fillStyle = '#0B4AB8';
    ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = '#ffffff';
    const bar = h * 0.19;
    ctx.fillRect(w / 2 - bar / 2, 0, bar, h);
    ctx.fillRect(0, h / 2 - bar / 2, w, bar);
    const fh = h * 0.27;
    for (const [fx, fy] of [[0.25, 0.25], [0.75, 0.25], [0.25, 0.75], [0.75, 0.75]]) {
      drawFleur(ctx, w * fx, h * fy, fh, '#ffffff');
    }
  });
  return _flag;
}

let _banner;
/** The blue pennant hanging on the facades, gold fleur and trim. */
export function bannerTexture() {
  if (_banner) return _banner;
  _banner = canvasTexture(128, 256, (ctx, w, h) => {
    const g = ctx.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, '#2F55C9'); g.addColorStop(1, '#1F3C88');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(0, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.86); ctx.lineTo(w / 2, h); ctx.lineTo(0, h * 0.86); ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = '#D4AF37'; ctx.lineWidth = 8; ctx.stroke();
    drawFleur(ctx, w / 2, h * 0.42, h * 0.32, '#F2C94C', '#9C7A1E');
  });
  return _banner;
}

const EMBLEMS = {
  pi(ctx, w) {
    ctx.fillStyle = '#F2C94C';
    ctx.font = `800 ${w * 0.62}px "Baloo 2", Georgia, serif`;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText('π', w / 2, w * 0.54);
  },
  atom(ctx, w) {
    ctx.strokeStyle = '#F2C94C'; ctx.lineWidth = w * 0.045;
    for (let k = 0; k < 3; k++) {
      ctx.save(); ctx.translate(w / 2, w / 2); ctx.rotate((k * Math.PI) / 3);
      ctx.beginPath(); ctx.ellipse(0, 0, w * 0.34, w * 0.13, 0, 0, Math.PI * 2); ctx.stroke();
      ctx.restore();
    }
    ctx.fillStyle = '#F2C94C'; ctx.beginPath(); ctx.arc(w / 2, w / 2, w * 0.07, 0, Math.PI * 2); ctx.fill();
  },
  fleur(ctx, w) { drawFleur(ctx, w / 2, w / 2, w * 0.66, '#F2C94C', '#9C7A1E'); },
  compass(ctx, w) {
    ctx.fillStyle = '#F2C94C';
    ctx.translate(w / 2, w / 2);
    for (let k = 0; k < 8; k++) {
      const r = k % 2 ? w * 0.22 : w * 0.38;
      ctx.beginPath(); ctx.moveTo(0, -r); ctx.lineTo(w * 0.06, 0); ctx.lineTo(-w * 0.06, 0); ctx.closePath(); ctx.fill();
      ctx.rotate(Math.PI / 4);
    }
  },
  book(ctx, w) {
    ctx.fillStyle = '#FFF8E8'; ctx.strokeStyle = '#F2C94C'; ctx.lineWidth = w * 0.03;
    for (const side of [-1, 1]) {
      ctx.beginPath();
      ctx.moveTo(w / 2, w * 0.36);
      ctx.quadraticCurveTo(w / 2 + side * w * 0.18, w * 0.28, w / 2 + side * w * 0.34, w * 0.34);
      ctx.lineTo(w / 2 + side * w * 0.34, w * 0.68);
      ctx.quadraticCurveTo(w / 2 + side * w * 0.18, w * 0.62, w / 2, w * 0.70);
      ctx.closePath(); ctx.fill(); ctx.stroke();
    }
    ctx.strokeStyle = '#B7C6E6'; ctx.lineWidth = w * 0.015;
    for (let k = 0; k < 4; k++) for (const side of [-1, 1]) {
      const y = w * (0.42 + k * 0.06);
      ctx.beginPath(); ctx.moveTo(w / 2 + side * w * 0.06, y); ctx.lineTo(w / 2 + side * w * 0.28, y - w * 0.02); ctx.stroke();
    }
  },
  abc(ctx, w) {
    ctx.fillStyle = '#F2C94C';
    ctx.font = `800 ${w * 0.34}px "Baloo 2", Georgia, serif`;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText('ABC', w / 2, w * 0.54);
  },
  frame(ctx, w) {
    ctx.fillStyle = '#F2C94C'; ctx.fillRect(w * 0.2, w * 0.22, w * 0.6, w * 0.56);
    ctx.fillStyle = '#9FD0FF'; ctx.fillRect(w * 0.27, w * 0.29, w * 0.46, w * 0.42);
    ctx.fillStyle = '#74C46E'; ctx.beginPath(); ctx.moveTo(w * 0.27, w * 0.71); ctx.lineTo(w * 0.45, w * 0.47); ctx.lineTo(w * 0.58, w * 0.62); ctx.lineTo(w * 0.73, w * 0.5); ctx.lineTo(w * 0.73, w * 0.71); ctx.fill();
    ctx.fillStyle = '#FBBF24'; ctx.beginPath(); ctx.arc(w * 0.62, w * 0.38, w * 0.05, 0, 7); ctx.fill();
  },
};

const _emblems = {};
/** A round gold-rimmed medallion with the subject's sign. */
export function emblemTexture(kind) {
  if (_emblems[kind]) return _emblems[kind];
  _emblems[kind] = canvasTexture(256, 256, (ctx, w) => {
    const g = ctx.createRadialGradient(w * 0.42, w * 0.38, w * 0.05, w / 2, w / 2, w * 0.5);
    g.addColorStop(0, '#3E6BE0'); g.addColorStop(1, '#1F3C88');
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(w / 2, w / 2, w * 0.47, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#D4AF37'; ctx.lineWidth = w * 0.06; ctx.stroke();
    ctx.save(); EMBLEMS[kind](ctx, w); ctx.restore();
  });
  return _emblems[kind];
}

let _soft;
/** A soft round sprite, for particles and glows. */
export function softDotTexture() {
  if (_soft) return _soft;
  _soft = canvasTexture(64, 64, (ctx, w) => {
    const g = ctx.createRadialGradient(w / 2, w / 2, 0, w / 2, w / 2, w / 2);
    g.addColorStop(0, 'rgba(255,255,255,1)');
    g.addColorStop(0.35, 'rgba(255,255,255,0.65)');
    g.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.fillStyle = g; ctx.fillRect(0, 0, w, w);
  });
  return _soft;
}

let _cobble;
/** Plaza paving: concentric cream stones. */
export function cobbleTexture() {
  if (_cobble) return _cobble;
  _cobble = canvasTexture(512, 512, (ctx, w) => {
    ctx.fillStyle = '#E6D5B6'; ctx.fillRect(0, 0, w, w);
    const rnd = mulberry(7);
    for (let ring = 0; ring < 9; ring++) {
      const r0 = ring * 28 + 14; const n = Math.max(6, Math.round((2 * Math.PI * r0) / 34));
      for (let k = 0; k < n; k++) {
        const a0 = (k / n) * Math.PI * 2 + ring * 0.3; const a1 = ((k + 1) / n) * Math.PI * 2 + ring * 0.3;
        const l = 90 + rnd() * 8;
        ctx.fillStyle = `hsl(${38 + rnd() * 6}, ${38 + rnd() * 10}%, ${l - 4}%)`;
        ctx.beginPath();
        ctx.arc(w / 2, w / 2, r0 + 12, a0 + 0.03, a1 - 0.03);
        ctx.arc(w / 2, w / 2, Math.max(r0 - 12, 2), a1 - 0.03, a0 + 0.03, true);
        ctx.closePath(); ctx.fill();
      }
    }
    // A gold fleur-de-lys inlaid at the centre.
    drawFleur(ctx, w / 2, w / 2, 70, '#D4AF37', '#9C7A1E');
  });
  return _cobble;
}

export function mulberry(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------- surface textures for the art pass ----------
// Near-white and neutral, so each material's colour tints them: one stone
// texture serves cream walls and darker trims alike.
function tiled(w, h, draw) {
  const t = canvasTexture(w, h, draw);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.userData.mimeType = 'image/jpeg'; // opaque: JPEG keeps the .glb small
  return t;
}

let _stone;
/** Dressed stone blocks in running bond, soft mortar, a little wear. */
export function stoneTexture() {
  if (_stone) return _stone;
  _stone = tiled(512, 512, (ctx, w) => {
    const rnd = mulberry(11);
    ctx.fillStyle = '#d9d2c6'; ctx.fillRect(0, 0, w, w);
    const rows = 8, bh = w / rows;
    for (let r = 0; r < rows; r++) {
      const bw = w / 4; const off = r % 2 ? bw / 2 : 0;
      for (let c = -1; c < 5; c++) {
        const x = c * bw + off, y = r * bh;
        const l = 93 + rnd() * 6;
        ctx.fillStyle = `hsl(36, ${10 + rnd() * 10}%, ${l}%)`;
        const g = 5;
        ctx.beginPath(); ctx.roundRect(x + g / 2, y + g / 2, bw - g, bh - g, 7); ctx.fill();
        // top light, bottom shade: blocks read as carved
        ctx.fillStyle = 'rgba(255,255,255,0.35)'; ctx.fillRect(x + 6, y + 4, bw - 12, 3);
        ctx.fillStyle = 'rgba(120,100,70,0.10)'; ctx.fillRect(x + 6, y + bh - 9, bw - 12, 4);
        for (let k = 0; k < 6; k++) { ctx.fillStyle = `rgba(140,120,90,${0.05 + rnd() * 0.06})`; ctx.beginPath(); ctx.arc(x + rnd() * bw, y + rnd() * bh, 1 + rnd() * 3, 0, 7); ctx.fill(); }
      }
    }
  });
  return _stone;
}

let _slate;
/** Rounded slate shingles in staggered rows: the art's scalloped roofs. */
export function slateTexture() {
  if (_slate) return _slate;
  _slate = tiled(512, 512, (ctx, w) => {
    const rnd = mulberry(23);
    ctx.fillStyle = '#9aa3b5'; ctx.fillRect(0, 0, w, w);
    const rows = 10, sh = w / rows, sw = w / 8;
    for (let r = rows; r >= -1; r--) {
      const off = r % 2 ? sw / 2 : 0;
      for (let c = -1; c < 9; c++) {
        const x = c * sw + off, y = r * sh;
        const l = 86 + rnd() * 12;
        ctx.fillStyle = `hsl(222, 12%, ${l}%)`;
        ctx.beginPath();
        ctx.moveTo(x + 2, y);
        ctx.lineTo(x + 2, y + sh * 0.95);
        ctx.quadraticCurveTo(x + sw / 2, y + sh * 1.45, x + sw - 2, y + sh * 0.95);
        ctx.lineTo(x + sw - 2, y);
        ctx.closePath(); ctx.fill();
        ctx.strokeStyle = 'rgba(40,50,80,0.28)'; ctx.lineWidth = 2.5; ctx.stroke();
        ctx.fillStyle = 'rgba(255,255,255,0.25)'; ctx.fillRect(x + 6, y + 3, sw - 12, 2);
      }
    }
  });
  return _slate;
}

let _planks;
/** Vertical boards with iron studs, for doors. */
export function plankTexture() {
  if (_planks) return _planks;
  _planks = tiled(256, 256, (ctx, w) => {
    const rnd = mulberry(31);
    for (let k = 0; k < 5; k++) {
      ctx.fillStyle = `hsl(222, 10%, ${84 + rnd() * 10}%)`;
      ctx.fillRect(k * w / 5, 0, w / 5, w);
      ctx.fillStyle = 'rgba(20,30,70,0.35)'; ctx.fillRect(k * w / 5, 0, 3, w);
      for (let y = 0; y < w; y += 9) { ctx.fillStyle = `rgba(255,255,255,${rnd() * 0.08})`; ctx.fillRect(k * w / 5 + 4, y, w / 5 - 8, 2); }
    }
    ctx.fillStyle = 'rgba(30,40,80,0.5)';
    for (const y of [0.22, 0.78]) { ctx.fillRect(0, w * y - 6, w, 12); }
  });
  return _planks;
}

let _wood;
/** Warm wood grain (light, near-white so the material colour tints it):
 *  long wavy grain lines along u, a few knots. */
export function woodTexture() {
  if (_wood) return _wood;
  _wood = tiled(256, 256, (ctx, w) => {
    const rnd = mulberry(47);
    ctx.fillStyle = '#efe6dc'; ctx.fillRect(0, 0, w, w);
    for (let i = 0; i < 46; i++) {
      const y0 = rnd() * w, amp = 2 + rnd() * 5, ph = rnd() * 6.28, lw = 0.8 + rnd() * 1.8;
      ctx.strokeStyle = `rgba(90,55,25,${0.07 + rnd() * 0.12})`; ctx.lineWidth = lw;
      ctx.beginPath();
      for (let x = 0; x <= w; x += 8) { const y = y0 + Math.sin(x / w * 6.28 * 2 + ph) * amp; x ? ctx.lineTo(x, y) : ctx.moveTo(x, y); }
      ctx.stroke();
    }
    for (let k = 0; k < 3; k++) {
      const x = rnd() * w, y = rnd() * w, r = 3 + rnd() * 4;
      ctx.fillStyle = 'rgba(80,45,20,0.28)'; ctx.beginPath(); ctx.ellipse(x, y, r * 1.8, r, 0, 0, 6.28); ctx.fill();
    }
  });
  return _wood;
}
