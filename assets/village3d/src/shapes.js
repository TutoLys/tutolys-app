// Soft organic shapes for foliage and clouds: smooth lumpy blobs and
// vertex-colour shading (darker underneath, lighter on top), so trees and
// clouds read as round and painted rather than faceted.
import * as THREE from 'three';
import { mergeGeometries, mergeVertices } from 'three/addons/utils/BufferGeometryUtils.js';

// Small deterministic 3D value noise (no dependency, same result every load).
function h3(x, y, z) {
  const s = Math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453;
  return s - Math.floor(s);
}
export function noise3(x, y, z) {
  const xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z);
  const xf = x - xi, yf = y - yi, zf = z - zi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf), w = zf * zf * (3 - 2 * zf);
  const L = (a, b, t) => a + (b - a) * t;
  const c = (dx, dy, dz) => h3(xi + dx, yi + dy, zi + dz);
  return L(
    L(L(c(0, 0, 0), c(1, 0, 0), u), L(c(0, 1, 0), c(1, 1, 0), u), v),
    L(L(c(0, 0, 1), c(1, 0, 1), u), L(c(0, 1, 1), c(1, 1, 1), u), v),
    w,
  );
}

/** A smooth sphere with gentle lumps, indexed so normals stay smooth. */
export function blob(r, { detail = 2, lump = 0.14, freq = 1.6, seed = 0, flatBottom = null } = {}) {
  let g = new THREE.IcosahedronGeometry(r, detail);
  g.deleteAttribute('normal'); g.deleteAttribute('uv');
  g = mergeVertices(g);
  const p = g.attributes.position;
  const v = new THREE.Vector3();
  for (let i = 0; i < p.count; i++) {
    v.fromBufferAttribute(p, i);
    const n = noise3(v.x * freq / r + seed, v.y * freq / r + seed * 1.7, v.z * freq / r - seed);
    v.multiplyScalar(1 + (n - 0.5) * 2 * lump);
    if (flatBottom !== null && v.y < -r * flatBottom) v.y = -r * flatBottom + (v.y + r * flatBottom) * 0.25;
    p.setXYZ(i, v.x, v.y, v.z);
  }
  g.computeVertexNormals();
  return g;
}

/**
 * Bake a soft light into vertex colours: darker toward the bottom and on
 * faces that point down, lighter on top. Instance colours multiply this,
 * so seasons still recolour the foliage.
 */
export function shadeVertices(g, { low = 0.62, high = 1.08, under = 0.2, yMin = null, yMax = null } = {}) {
  g.computeBoundingBox();
  const y0 = yMin ?? g.boundingBox.min.y, y1 = yMax ?? g.boundingBox.max.y;
  const p = g.attributes.position, n = g.attributes.normal;
  const col = new Float32Array(p.count * 3);
  for (let i = 0; i < p.count; i++) {
    const t = THREE.MathUtils.clamp((p.getY(i) - y0) / (y1 - y0 || 1), 0, 1);
    const ny = n ? n.getY(i) : 0;
    let k = THREE.MathUtils.lerp(low, high, t * t * (3 - 2 * t));
    k *= 1 - under * Math.max(0, -ny);
    col[i * 3] = col[i * 3 + 1] = col[i * 3 + 2] = k;
  }
  g.setAttribute('color', new THREE.BufferAttribute(col, 3));
  return g;
}

/**
 * One pine tier: a cone whose bottom rim is scalloped into soft points, so
 * the tree reads as drooping boughs rather than a plain cone.
 */
export function pineTier(r, h, y, { seg = 14, droop = 0.22, seed = 0 } = {}) {
  let g = new THREE.ConeGeometry(r, h, seg, 3, false);
  g.deleteAttribute('uv'); g.deleteAttribute('normal');
  g = mergeVertices(g);
  const p = g.attributes.position;
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i), yy = p.getY(i), z = p.getZ(i);
    const rad = Math.hypot(x, z);
    if (rad < 1e-4) continue;
    const a = Math.atan2(z, x);
    const k = (yy + h / 2) / h; // 0 bottom … 1 top
    // Scallop strongest at the rim, fading up the tier.
    const wave = 0.5 + 0.5 * Math.cos(a * (seg / 2) + seed);
    const rim = Math.pow(1 - k, 3);
    p.setY(i, yy - wave * droop * h * rim);
    const wob = 1 + (noise3(x * 2 + seed, yy * 2, z * 2) - 0.5) * 0.12;
    p.setX(i, x * wob); p.setZ(i, z * wob);
  }
  g.translate(0, y, 0);
  g.computeVertexNormals();
  return g;
}

/**
 * A painterly leafy canopy: a core plus leaf clumps around its shell. Normals
 * are bent toward the canopy centre ("spherical normals"), so the whole crown
 * shades like one soft ball while the clumps still give a leafy silhouette and
 * the low-poly facets disappear. Vertex colours carry depth: darker inside and
 * underneath, each clump a touch lighter or darker than its neighbours.
 * Returns geometry in tree space (ground at y = 0); `center` is the crown centre.
 */
export function leafyCanopy(seed, { center = new THREE.Vector3(0, 2.2, 0), R = 1.15, clumps = 11, squash = 0.88, coreDetail = 2, low = -0.45, clumpDetail = 1 } = {}) {
  const rnd = (() => { let s = (seed * 9301 + 49297) % 233280; return () => (s = (s * 9301 + 49297) % 233280) / 233280; })();
  const parts = [], tone = [];
  const add = (g, k) => { parts.push(g); tone.push(k); };
  add(blob(R * 0.82, { detail: coreDetail, seed: seed * 3.1, lump: 0.08 }).translate(center.x, center.y, center.z), 0.92);
  // Clumps on a slightly flattened shell, denser on top, none dead underneath.
  for (let i = 0; i < clumps; i++) {
    const u = rnd(), v = rnd();
    const theta = u * Math.PI * 2;
    const y = THREE.MathUtils.lerp(low, 1.0, Math.sqrt(v)); // bias upward
    const rr = Math.sqrt(1 - y * y);
    const r = R * (0.36 + rnd() * 0.18) * (1 - Math.max(0, -y) * 0.3);
    const d = R * (0.7 + rnd() * 0.12);
    add(blob(r, { detail: clumpDetail, seed: seed * 7 + i, lump: 0.06 })
      .translate(center.x + Math.cos(theta) * rr * d, center.y + y * d * squash, center.z + Math.sin(theta) * rr * d),
      0.93 + rnd() * 0.16);
  }
  // Per-part tone as a colour attribute before merging.
  parts.forEach((g, i) => {
    const n = g.attributes.position.count;
    g.setAttribute('color', new THREE.BufferAttribute(new Float32Array(n * 3).fill(tone[i]), 3));
  });
  const g = mergeGeometries(parts);
  const p = g.attributes.position, nrm = g.attributes.normal, col = g.attributes.color;
  const v = new THREE.Vector3(), sn = new THREE.Vector3(), tn = new THREE.Vector3();
  for (let i = 0; i < p.count; i++) {
    v.fromBufferAttribute(p, i);
    sn.copy(v).sub(center); sn.y /= squash; const dist = sn.length(); sn.normalize();
    tn.fromBufferAttribute(nrm, i);
    tn.lerp(sn, 0.62).normalize();
    nrm.setXYZ(i, tn.x, tn.y, tn.z);
    // Depth: inner (occluded) vertices darker, the underside darker, top lighter.
    const outer = THREE.MathUtils.clamp((dist / R - 0.55) / 0.5, 0, 1);
    const up = (sn.y + 1) / 2;
    const k = (0.48 + 0.52 * outer) * (0.64 + 0.44 * up);
    col.setXYZ(i, col.getX(i) * k, col.getY(i) * k, col.getZ(i) * k);
  }
  return g;
}

const strip = (g) => { for (const k of Object.keys(g.attributes)) if (k !== 'position' && k !== 'normal') g.deleteAttribute(k); return g; };

/**
 * A weathered boulder: a lumpy, rounded stone sitting flat on the ground,
 * shaded darker underneath with a hint of moss on top (vertex colour, so the
 * material stays one grey and the moss reads greenish). Optional pebbles.
 */
export function boulder(seed, { pebbles = 0 } = {}) {
  const rnd = (() => { let s = (seed * 7919 + 13) % 233280; return () => (s = (s * 9301 + 49297) % 233280) / 233280; })();
  const parts = [];
  const stone = (r, x, z, sq) => {
    let g = new THREE.IcosahedronGeometry(r, 2);
    g.deleteAttribute('normal'); g.deleteAttribute('uv');
    g = mergeVertices(g);
    const p = g.attributes.position, v = new THREE.Vector3();
    const s = rnd() * 40;
    for (let i = 0; i < p.count; i++) {
      v.fromBufferAttribute(p, i);
      // Two octaves: broad lumps plus a few flatter "chipped" planes.
      const n1 = noise3(v.x * 1.4 / r + s, v.y * 1.4 / r, v.z * 1.4 / r - s);
      const n2 = noise3(v.x * 3.1 / r - s, v.y * 3.1 / r + s, v.z * 3.1 / r);
      // Quantised second octave = flat chiselled planes, so it reads as rock.
      const chip = Math.round((n2 - 0.5) * 4) / 4;
      v.multiplyScalar(1 + (n1 - 0.5) * 0.45 + chip * 0.16);
      v.y *= sq;
      if (v.y < -r * 0.25) v.y = -r * 0.25 + (v.y + r * 0.25) * 0.15; // sits flat
      p.setXYZ(i, v.x + x, v.y + r * 0.22, v.z + z);
    }
    g.computeVertexNormals();
    parts.push(g);
  };
  stone(0.6, 0, 0, 0.62 + rnd() * 0.2);
  for (let i = 0; i < pebbles; i++) {
    const a = rnd() * Math.PI * 2;
    stone(0.18 + rnd() * 0.12, Math.cos(a) * 0.72, Math.sin(a) * 0.62, 0.6);
  }
  const g = mergeGeometries(parts);
  const p = g.attributes.position, n = g.attributes.normal;
  g.computeBoundingBox();
  const top = g.boundingBox.max.y;
  const col = new Float32Array(p.count * 3);
  for (let i = 0; i < p.count; i++) {
    const t = THREE.MathUtils.clamp(p.getY(i) / top, 0, 1);
    // Crevices darker, grain lighter, so the stone has some surface.
    const grain = noise3(p.getX(i) * 6 + seed, p.getY(i) * 6, p.getZ(i) * 6);
    let k = (0.58 + 0.48 * t) * (0.84 + 0.3 * grain);
    const moss = THREE.MathUtils.clamp((n.getY(i) - 0.6) * 3.5, 0, 1) * (noise3(p.getX(i) * 3 + seed, 0, p.getZ(i) * 3) > 0.42 ? 1 : 0.15);
    col[i * 3] = k * (1 - moss * 0.45);
    col[i * 3 + 1] = k * (1 - moss * 0.08);
    col[i * 3 + 2] = k * (1 - moss * 0.55);
  }
  g.setAttribute('color', new THREE.BufferAttribute(col, 3));
  return g;
}

/**
 * A small flower in three instanced parts so each can keep its own colour:
 * `petals` (tinted per instance), `heart` (yellow), `stem` (green, with two
 * leaves). `kind` 0 = daisy (5 petals open to the sky), 1 = tulip (cup).
 */
export function flowerParts(kind = 0) {
  const H = 0.34;
  const petals = [];
  if (kind === 0) {
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * Math.PI * 2;
      const g = new THREE.SphereGeometry(1, 6, 3);
      g.scale(0.075, 0.022, 0.045).translate(0.075, 0, 0).rotateZ(0.22).rotateY(a).translate(0, H, 0);
      petals.push(strip(g));
    }
  } else {
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * Math.PI * 2;
      const g = new THREE.SphereGeometry(1, 6, 3);
      g.scale(0.035, 0.085, 0.05).translate(0.04, 0.06, 0).rotateZ(-0.18).rotateY(a).translate(0, H - 0.02, 0);
      petals.push(strip(g));
    }
  }
  const heart = strip(new THREE.SphereGeometry(kind === 0 ? 0.035 : 0.03, 6, 3).scale(1, 0.7, 1).translate(0, H + (kind === 0 ? 0.012 : 0.02), 0));
  const leaf = (a, y, len) => strip(new THREE.SphereGeometry(1, 5, 2).scale(len, 0.012, len * 0.38).translate(len, 0, 0).rotateZ(0.5).rotateY(a).translate(0, y, 0));
  const stem = mergeGeometries([
    strip(new THREE.CylinderGeometry(0.009, 0.013, H, 4).translate(0, H / 2, 0)),
    leaf(0.4, 0.07, 0.07),
    leaf(0.4 + Math.PI * 0.9, 0.13, 0.06),
  ]);
  return { petals: mergeGeometries(petals), heart, stem };
}

/**
 * A garden bush: a low, wide leafy mound (same painted look as the trees)
 * that sits on the ground. With `blossoms`, also returns small flower dots
 * scattered over its upper surface, as a separate geometry to tint by season.
 */
export function leafyBush(seed, { R = 0.55, blossoms = 0, clumps = 8, clumpDetail = 1 } = {}) {
  const center = new THREE.Vector3(0, R * 0.42, 0);
  const g = leafyCanopy(seed, { center, R, clumps, squash: 0.68, coreDetail: 1, low: -0.1, clumpDetail });
  // Flatten anything below ground into the ground plane.
  const p = g.attributes.position;
  for (let i = 0; i < p.count; i++) if (p.getY(i) < 0) p.setY(i, p.getY(i) * 0.1);
  if (!blossoms) return { leaves: g };
  const rnd = (() => { let s = (seed * 4241 + 7) % 233280; return () => (s = (s * 9301 + 49297) % 233280) / 233280; })();
  const dots = [];
  for (let i = 0; i < blossoms; i++) {
    const a = rnd() * Math.PI * 2, el = 0.25 + rnd() * 1.0; // upper surface only
    const d = new THREE.Vector3(Math.cos(a) * Math.cos(el), Math.sin(el) * 0.68, Math.sin(a) * Math.cos(el)).multiplyScalar(R * 1.13);
    dots.push(strip(new THREE.SphereGeometry(0.045 + rnd() * 0.02, 5, 3)).scale(1, 0.75, 1).translate(center.x + d.x, center.y + d.y, center.z + d.z));
  }
  return { leaves: g, blossoms: mergeGeometries(dots) };
}

/**
 * A village street lamp in three parts so each keeps its own material:
 * `iron` (base, post, collars, cage, roof), `glass` (the glowing panes) and
 * `gold` (finial). Ground at y = 0 and the glass centred at y = 1.92, where
 * the night glow halos sit. `head` builds only the lantern, glass centred at 0.
 */
export function streetLamp({ head = false } = {}) {
  const Y = head ? 0 : 1.92;
  const iron = [];
  const cyl = (rt, rb, h, y, seg = 8) => iron.push(strip(new THREE.CylinderGeometry(rt, rb, h, seg).translate(0, y, 0)));
  if (!head) {
    cyl(0.2, 0.24, 0.14, 0.07);                     // stepped octagonal base
    cyl(0.13, 0.16, 0.1, 0.19);
    cyl(0.05, 0.075, 1.48, 0.24 + 0.74);              // post
    for (const y of [0.52, 1.66]) iron.push(strip(new THREE.TorusGeometry(0.075, 0.022, 6, 12).rotateX(Math.PI / 2).translate(0, y, 0)));
  }
  cyl(0.17, 0.11, 0.05, Y - 0.19);                  // tray under the lamp
  for (const [x, z] of [[1, 1], [1, -1], [-1, 1], [-1, -1]]) {
    iron.push(strip(new THREE.BoxGeometry(0.028, 0.37, 0.028).translate(x * 0.118, Y, z * 0.118)));
  }
  cyl(0.19, 0.19, 0.03, Y + 0.19);                  // top plate
  iron.push(strip(new THREE.ConeGeometry(0.22, 0.2, 4).rotateY(Math.PI / 4).translate(0, Y + 0.3, 0)));
  const glass = strip(new THREE.BoxGeometry(0.21, 0.33, 0.21).translate(0, Y, 0));
  const gold = mergeGeometries([
    strip(new THREE.SphereGeometry(0.045, 10, 8).translate(0, Y + 0.44, 0)),
    strip(new THREE.ConeGeometry(0.02, 0.08, 6).translate(0, Y + 0.51, 0)),
  ]);
  return { iron: mergeGeometries(iron), glass, gold };
}

// ---------- stylised leafy trees ----------
// A crown of leaf clumps. Each clump is a dark core plus a shingle of
// alpha-cut "leaf cards" (quads showing a cluster of leaves), with normals
// bent toward the crown centre so the whole tree shades as one soft volume.
// One texture atlas: left half = leaf cluster (alpha), right half = solid
// (the cores sample it), so cores and cards share a single material.
let _leafTex;
export function leafAtlas() {
  if (_leafTex) return _leafTex;
  const c = document.createElement('canvas'); c.width = 512; c.height = 256;
  const x = c.getContext('2d');
  x.clearRect(0, 0, 512, 256);
  let s = 7; const rnd = () => (s = (s * 16807) % 2147483647) / 2147483647;
  const leaf = (cx, cy, ang, len, wid, shade) => {
    x.save(); x.translate(cx, cy); x.rotate(ang);
    x.fillStyle = `rgb(${shade},${shade},${shade})`;
    x.beginPath(); x.moveTo(0, 0);
    x.quadraticCurveTo(len * 0.45, -wid, len, 0); x.quadraticCurveTo(len * 0.45, wid, 0, 0); x.fill();
    x.strokeStyle = `rgba(0,0,0,0.12)`; x.lineWidth = 2; x.beginPath(); x.moveTo(len * 0.1, 0); x.lineTo(len * 0.85, 0); x.stroke();
    x.restore();
  };
  // A rosette of leaves: an inner ring and an outer ring, varied shades.
  // A dense round tuft of many small leaves (reads as foliage, not a starburst).
  for (let k = 0; k < 38; k++) {
    const a = rnd() * Math.PI * 2, r0 = Math.sqrt(rnd()) * 70;
    const cx = 128 + Math.cos(a) * r0, cy = 128 + Math.sin(a) * r0;
    leaf(cx, cy, a + (rnd() - 0.5) * 1.4, 38 + rnd() * 18, 13 + rnd() * 6, Math.round(208 + rnd() * 47));
  }
  // Fill the tuft's heart so it never reads as a hole at a distance.
  x.fillStyle = 'rgb(214,214,214)'; x.beginPath(); x.arc(128, 128, 46, 0, 7); x.fill();
  x.fillStyle = 'rgb(176,176,176)'; x.fillRect(272, 16, 224, 224); // solid patch for the cores
  _leafTex = new THREE.CanvasTexture(c); _leafTex.colorSpace = THREE.SRGBColorSpace;
  _leafTex.anisotropy = 4;
  return _leafTex;
}
let _barkTex;
export function barkTexture() {
  if (_barkTex) return _barkTex;
  const c = document.createElement('canvas'); c.width = 128; c.height = 256;
  const x = c.getContext('2d');
  x.fillStyle = '#e4d6c6'; x.fillRect(0, 0, 128, 256);
  let s = 11; const rnd = () => (s = (s * 16807) % 2147483647) / 2147483647;
  for (let k = 0; k < 26; k++) {
    const x0 = rnd() * 128; x.strokeStyle = `rgba(90,55,30,${0.18 + rnd() * 0.25})`; x.lineWidth = 2 + rnd() * 4;
    x.beginPath(); x.moveTo(x0, 0); for (let y = 0; y <= 256; y += 32) x.lineTo(x0 + Math.sin(y * 0.05 + k) * 5, y); x.stroke();
  }
  _barkTex = new THREE.CanvasTexture(c); _barkTex.colorSpace = THREE.SRGBColorSpace; _barkTex.wrapS = _barkTex.wrapT = THREE.RepeatWrapping;
  return _barkTex;
}

const TREE_KINDS = {
  oak: { trunkH: 1.55, clumps: [[0, 2.55, 0, 0.85], [0.78, 2.2, 0.3, 0.6], [-0.72, 2.25, -0.2, 0.62], [0.12, 2.15, -0.78, 0.55], [-0.22, 2.12, 0.72, 0.55], [0.2, 3.2, 0.1, 0.5]] },
  round: { trunkH: 1.45, clumps: [[0, 2.55, 0, 0.92], [0.62, 2.25, 0.35, 0.58], [-0.6, 2.3, -0.3, 0.6], [0.35, 2.3, -0.62, 0.55], [-0.4, 2.25, 0.6, 0.55], [0.05, 3.25, 0.05, 0.55]] },
  broad: { trunkH: 1.3, clumps: [[0, 2.35, 0, 0.78], [1.02, 2.02, 0.05, 0.6], [-1.0, 2.08, 0.12, 0.6], [0.3, 2.12, 0.92, 0.56], [-0.42, 2.12, -0.86, 0.56], [0.12, 2.85, 0.12, 0.55], [-0.6, 2.6, 0.55, 0.42]] },
};

/** Returns { crown, trunk } geometries (ground at y = 0) for one tree kind. */
export function stylizedTree(kind = 'oak', seed = 1) {
  let s = seed * 9973 % 2147483647 || 1; const rnd = () => (s = (s * 16807) % 2147483647) / 2147483647;
  const K = TREE_KINDS[kind];
  const clumps = K.clumps.map(([x, y, z, r]) => [x * (0.9 + rnd() * 0.2), y * (0.95 + rnd() * 0.1), z * (0.9 + rnd() * 0.2), r * (0.9 + rnd() * 0.2)]);
  const centre = new THREE.Vector3(); clumps.forEach(([x, y, z]) => centre.add(new THREE.Vector3(x, y, z))); centre.divideScalar(clumps.length);
  let crownR = 0; clumps.forEach(([x, y, z, r]) => { crownR = Math.max(crownR, new THREE.Vector3(x, y, z).distanceTo(centre) + r); });
  const pos = [], nor = [], uv = [], col = [];
  const n = new THREE.Vector3(), sph = new THREE.Vector3(), t1 = new THREE.Vector3(), t2 = new THREE.Vector3(), p = new THREE.Vector3();
  const shade = (q, extra = 0) => {
    const d = q.distanceTo(centre) / crownR, up = THREE.MathUtils.clamp((q.y - centre.y) / crownR * 0.5 + 0.5, 0, 1);
    return (0.64 + 0.36 * THREE.MathUtils.smoothstep(d, 0.3, 1.0)) * (0.8 + 0.3 * up) + extra;
  };
  const pushV = (q, normal, u, v, k) => { pos.push(q.x, q.y, q.z); nor.push(normal.x, normal.y, normal.z); uv.push(u, v); col.push(k, k, k); };
  // Cores: low-poly spheres sampling the atlas' solid patch, darker.
  for (const [cx, cy, cz, r] of clumps) {
    const g = new THREE.IcosahedronGeometry(r * 0.78, 1); // already non-indexed
    const P = g.attributes.position;
    for (let i = 0; i < P.count; i++) {
      p.set(P.getX(i) + cx, P.getY(i) + cy, P.getZ(i) + cz);
      sph.copy(p).sub(centre).normalize();
      pushV(p, sph, 0.75, 0.5, shade(p, -0.06));
    }
  }
  // Leaf cards, shingled over each clump, facing roughly outward.
  for (const [cx, cy, cz, r] of clumps) {
    const count = Math.round(16 + r * 30);
    for (let k = 0; k < count; k++) {
      // even-ish spread on the sphere, fewer underneath
      const yy = 1 - (k + 0.5) * 1.75 / count, rr = Math.sqrt(Math.max(0, 1 - yy * yy)), a = k * 2.39996 + rnd() * 0.5;
      n.set(Math.cos(a) * rr, yy, Math.sin(a) * rr).normalize();
      const c0 = new THREE.Vector3(cx, cy, cz).addScaledVector(n, r * (0.9 + rnd() * 0.22));
      const facing = n.clone().lerp(new THREE.Vector3(rnd() - 0.5, rnd() - 0.2, rnd() - 0.5).normalize(), 0.45).normalize();
      t1.set(0, 1, 0); if (Math.abs(facing.y) > 0.9) t1.set(1, 0, 0);
      t1.cross(facing).normalize(); t2.copy(facing).cross(t1).normalize();
      const rot = rnd() * Math.PI * 2, cs = Math.cos(rot), sn = Math.sin(rot);
      const a1 = t1.clone().multiplyScalar(cs).addScaledVector(t2, sn), a2 = t1.clone().multiplyScalar(-sn).addScaledVector(t2, cs);
      const half = r * (0.46 + rnd() * 0.16);
      const tint = (rnd() - 0.5) * 0.14;
      const corner = (su, sv) => c0.clone().addScaledVector(a1, su * half).addScaledVector(a2, sv * half);
      const q00 = corner(-1, -1), q10 = corner(1, -1), q11 = corner(1, 1), q01 = corner(-1, 1);
      for (const [q, u, v] of [[q00, 0, 0], [q10, 0.5, 0], [q11, 0.5, 1], [q00, 0, 0], [q11, 0.5, 1], [q01, 0, 1]]) {
        sph.copy(q).sub(centre).normalize().lerp(facing, 0.15).normalize();
        pushV(q, sph, u, v, shade(q, tint));
      }
    }
  }
  const crown = new THREE.BufferGeometry();
  crown.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  crown.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
  crown.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  crown.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));

  // Trunk: tapered, gently bent, flaring into roots, branches into each clump.
  const parts = [];
  const H = K.trunkH;
  const trunk = new THREE.CylinderGeometry(0.13, 0.24, H, 9, 8).translate(0, H / 2, 0);
  { const P = trunk.attributes.position; const bend = (rnd() - 0.5) * 0.18, ph = rnd() * 6;
    for (let i = 0; i < P.count; i++) { const y = P.getY(i); const f = 1 + Math.max(0, 0.3 - y) * 2.0;
      P.setXYZ(i, P.getX(i) * f + Math.sin(y * 1.6 + ph) * bend, y, P.getZ(i) * f); } }
  parts.push(trunk);
  for (let k = 0; k < 4; k++) {
    const a = k * Math.PI / 2 + rnd() * 0.6;
    parts.push(new THREE.ConeGeometry(0.09, 0.6, 6).rotateZ(-(Math.PI / 2 + 0.2)).translate(0.3, 0.08, 0).rotateY(a)); // tip outward, dipping into the ground
  }
  for (const [cx, cy, cz, r] of clumps) {
    const from = new THREE.Vector3(0, H * (0.75 + rnd() * 0.2), 0), to = new THREE.Vector3(cx, cy, cz).multiplyScalar(0.92);
    const len = from.distanceTo(to); if (len < 0.25) continue;
    const b = new THREE.CylinderGeometry(0.035, 0.085, len, 6).translate(0, len / 2, 0);
    b.applyQuaternion(new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), to.clone().sub(from).normalize()));
    b.translate(from.x, from.y, from.z); parts.push(b);
  }
  for (const g of parts) { for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(k)) g.deleteAttribute(k); }
  const trunkGeo = mergeGeometries(parts.map((g) => (g.index ? g.toNonIndexed() : g)));
  trunkGeo.computeVertexNormals();
  return { crown, trunk: trunkGeo, crownR, centre };
}
