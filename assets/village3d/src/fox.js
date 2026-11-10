// The TutoLys fox, in 3D: a white-and-blue arctic fox with the blue cape
// and gold fleur-de-lys medallion of asset-mascot-welcome.webp.
//
// Built from named joints (rig, head, ear_L/R, eye_L/R, leg_0…3, tail_0…5,
// cape) and animated by four authored clips: idle, walk, wave, hop. The
// clips are keyframes, so they export into fox.glb with the model and play
// back through an AnimationMixer. A replacement fox.glb only has to keep the
// clip names to slot in.
import * as THREE from 'three';
import { MAT } from './palette.js';
import { fleurShapes } from './textures.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
function smooth(a, b, x) { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); }
const std = (color, extra = {}) => new THREE.MeshStandardMaterial({ color, roughness: 0.7, ...extra });
const FM = {
  fur: std(MAT.foxWhite, { roughness: 0.9 }),
  blue: std(MAT.foxBlue, { roughness: 0.78 }),
  deep: std(MAT.foxBlueDeep, { roughness: 0.7 }),
  eye: std(0x14205a, { roughness: 0.2 }),
  iris: std(0x2f6fed, { roughness: 0.15, emissive: 0x2f6fed, emissiveIntensity: 0.18 }),
  glow: new THREE.MeshBasicMaterial({ color: 0x8fc0ff }),
  pupil: std(0x0a1238, { roughness: 0.1 }),
  shine: new THREE.MeshBasicMaterial({ color: 0xffffff }),
  nose: std(0x1b2546, { roughness: 0.25 }),
  mouth: std(0x6e2234, { roughness: 0.6 }),
  inner: std(0xffb9b0, { roughness: 0.85 }),
  tongue: std(0xff8fa3, { roughness: 0.5 }),
  cape: std(0x2346a8, { roughness: 0.6, side: THREE.DoubleSide }),
  capeLining: std(0x3d6fe6, { roughness: 0.65, side: THREE.DoubleSide }),
  gold: new THREE.MeshStandardMaterial({ color: MAT.gold, metalness: 0.8, roughness: 0.3 }),
  tail: std(0xffffff, { roughness: 0.9, vertexColors: true }),
  skull: std(0xffffff, { roughness: 0.9, map: skullTexture() }),
  blush: new THREE.MeshBasicMaterial({ color: 0xffb3c4, transparent: true, opacity: 0.5, depthWrite: false }),
};
for (const [k, mt] of Object.entries(FM)) mt.name = 'fox_' + k;

function m(geo, mat, cast = true) {
  const o = new THREE.Mesh(geo, mat);
  o.castShadow = cast; o.receiveShadow = true;
  return o;
}
const joint = (name, x = 0, y = 0, z = 0) => { const g = new THREE.Group(); g.name = name; g.position.set(x, y, z); return g; };
const V2 = THREE.Vector2;


/**
 * The skull's fur, painted onto the sphere's own UVs: white with the art's
 * blue widow's-peak blaze. Painted per pixel from the direction each texel
 * faces, so its edge is soft and exact instead of a mesh's sawtooth.
 */
function skullTexture() {
  const W = 512, H = 256;
  const c = document.createElement('canvas'); c.width = W; c.height = H;
  const g = c.getContext('2d'); const img = g.createImageData(W, H);
  const white = new THREE.Color(MAT.foxWhite), blue = new THREE.Color(MAT.foxBlue), col = new THREE.Color();
  for (let y = 0; y < H; y++) {
    const th = ((y + 0.5) / H) * Math.PI;
    for (let x = 0; x < W; x++) {
      const ph = ((x + 0.5) / W) * Math.PI * 2;
      const dx = -Math.cos(ph) * Math.sin(th), dy = Math.cos(th), dz = Math.sin(ph) * Math.sin(th);
      const k = 0.6 + 0.4 * smooth(-0.3, 0.3, dz);
      const edge = dy - (0.4 + 1.25 * Math.abs(dx) * k);
      const a = smooth(-0.012, 0.012, edge) * smooth(-0.3, -0.12, dz);
      col.copy(white).lerp(blue, a).convertLinearToSRGB();
      const o = (y * W + x) * 4;
      img.data[o] = col.r * 255; img.data[o + 1] = col.g * 255; img.data[o + 2] = col.b * 255; img.data[o + 3] = 255;
    }
  }
  g.putImageData(img, 0, 0);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4;
  return t;
}

/** A soft, egg-shaped lathe: rounder and smoother than a scaled sphere. */
function egg(r, h, segs = 28) {
  const pts = [];
  for (let i = 0; i <= 20; i++) {
    const a = (i / 20) * Math.PI;
    const k = 1 + 0.18 * Math.cos(a); // fuller at the bottom
    pts.push(new V2(Math.sin(a) * r * k, -Math.cos(a) * h / 2));
  }
  return new THREE.LatheGeometry(pts, segs);
}

/**
 * A capsule whose two ends have different radii, along +y from 0 to len.
 * Chained end to end, with each joint at a shared sphere, a string of them
 * reads as one smooth, bendable limb, so the tail is one soft shape and not
 * a row of balls.
 */
function capsule2(r0, r1, len, segs = 18) {
  const a = Math.asin(THREE.MathUtils.clamp((r0 - r1) / len, -1, 1));
  const pts = [];
  for (let i = 0; i <= 10; i++) { const p = -Math.PI / 2 + (a + Math.PI / 2) * (i / 10); pts.push(new V2(r0 * Math.cos(p), r0 * Math.sin(p))); }
  // Rings along the straight flank too, so shading and colour gradients
  // interpolate smoothly instead of across one long triangle.
  const p0 = pts[pts.length - 1], p1 = new V2(r1 * Math.cos(a), len + r1 * Math.sin(a));
  for (let i = 1; i < 5; i++) pts.push(p0.clone().lerp(p1, i / 5));
  for (let i = 0; i <= 8; i++) { const p = a + (Math.PI / 2 - a) * (i / 8); pts.push(new V2(Math.max(0, r1 * Math.cos(p)), len + r1 * Math.sin(p))); }
  return new THREE.LatheGeometry(pts, segs);
}
/** A fluffy tuft: rounded at the root, soft point at the tip. */
const tuft = (r, h, tip = 0.22) => capsule2(r, r * tip, h, 14);

export function createFox({ scale = 1, cape = true } = {}) {
  const fox = new THREE.Group();
  fox.name = 'fox';
  const rig = joint('rig');
  fox.add(rig);

  // Body: a pear with a round chest.
  const body = m(egg(0.4, 0.95), FM.fur); body.position.set(0, 0.66, -0.02); body.rotation.x = -0.12;
  const chest = m(new THREE.SphereGeometry(0.29, 24, 16), FM.fur); chest.position.set(0, 0.78, 0.2);
  rig.add(body, chest);
  // Legs: four joints the walk swings; white legs into blue socks and paws.
  for (const [i, x, z] of [[0, -0.19, 0.2], [1, 0.19, 0.2], [2, -0.2, -0.26], [3, 0.2, -0.26]]) {
    const leg = joint(`leg_${i}`, x, 0.44, z);
    const thigh = m(capsule2(0.105, 0.08, 0.26, 16), FM.fur); thigh.rotation.x = Math.PI; thigh.position.y = 0.0;
    const sock = m(capsule2(0.085, 0.09, 0.1, 16), FM.blue); sock.rotation.x = Math.PI; sock.position.y = -0.26;
    const paw = m(new THREE.SphereGeometry(0.115, 18, 12), FM.blue); paw.scale.set(1, 0.62, 1.3); paw.position.set(0, -0.39, 0.05);
    leg.add(thigh, sock, paw);
    leg.userData.rest = leg.position.clone();
    rig.add(leg);
  }

  // Head: big and round, a blue widow's-peak blaze, cheek fluff, a snout
  // with an open, happy mouth, and big glossy eyes with a lash line.
  const head = joint('head', 0, 1.3, 0.1);
  const SK = [1.1, 0.94, 0.96];
  const skull = m(new THREE.SphereGeometry(0.5, 34, 24), FM.skull); skull.scale.set(...SK);
  head.add(skull);
  for (const sx of [-1, 1]) {
    for (let k = 0; k < 3; k++) {
      const t = m(tuft(0.1 - k * 0.012, 0.2 - k * 0.025, 0.3), FM.fur);
      t.position.set(sx * (0.44 - k * 0.04), -0.15 - k * 0.08, 0.1 - k * 0.07);
      t.rotation.set(0, sx * 0.2, -sx * (Math.PI / 2 + 0.5 + k * 0.32));
      head.add(t);
    }
  }
  const muzzle = m(new THREE.SphereGeometry(0.21, 24, 16), FM.fur); muzzle.scale.set(1.2, 0.8, 1.2); muzzle.position.set(0, -0.14, 0.45);
  const nose = m(new THREE.SphereGeometry(0.066, 16, 12), FM.nose); nose.scale.set(1.35, 0.9, 1); nose.position.set(0, -0.07, 0.69);
  const noseShine = m(new THREE.SphereGeometry(0.018, 8, 6), FM.shine, false); noseShine.position.set(0.022, -0.045, 0.745);
  const mouth = m(new THREE.SphereGeometry(0.085, 18, 12), FM.mouth, false); mouth.scale.set(1.15, 0.75, 0.5); mouth.position.set(0, -0.235, 0.63);
  const tongue = m(new THREE.SphereGeometry(0.055, 14, 10), FM.tongue, false); tongue.scale.set(1.1, 0.55, 0.6); tongue.position.set(0, -0.268, 0.648);
  const fang = m(new THREE.ConeGeometry(0.017, 0.04, 8), FM.shine, false); fang.rotation.x = Math.PI; fang.position.set(0.045, -0.2, 0.665);
  const crest = m(tuft(0.06, 0.15, 0.3), FM.blue); crest.position.set(0.03, 0.43, 0.06); crest.rotation.set(0.3, 0, -0.5);
  head.add(muzzle, nose, noseShine, mouth, tongue, fang, crest);
  for (const sx of [-1, 1]) {
    const side = sx < 0 ? 'L' : 'R';
    // Eyes sit on the skull's surface, turned to its normal.
    const eye = joint(`eye_${side}`, sx * 0.19, 0.0, 0.425);
    eye.rotation.set(-0.02, sx * 0.32, 0);
    const outline = m(new THREE.SphereGeometry(0.128, 20, 12), FM.eye, false); outline.scale.set(0.84, 1.06, 0.34);
    const iris = m(new THREE.SphereGeometry(0.11, 20, 12), FM.iris, false); iris.scale.set(0.82, 1.0, 0.36); iris.position.z = 0.008;
    const glow = m(new THREE.SphereGeometry(0.06, 16, 10), FM.glow, false); glow.scale.set(0.95, 0.55, 0.3); glow.position.set(0, -0.055, 0.035);
    const pupil = m(new THREE.SphereGeometry(0.058, 16, 12), FM.pupil, false); pupil.scale.set(0.85, 1.05, 0.3); pupil.position.set(0, 0.012, 0.035);
    const s1 = m(new THREE.SphereGeometry(0.034, 12, 8), FM.shine, false); s1.scale.z = 0.4; s1.position.set(sx * 0.028, 0.05, 0.05);
    const s2 = m(new THREE.SphereGeometry(0.016, 8, 6), FM.shine, false); s2.scale.z = 0.4; s2.position.set(-sx * 0.03, -0.04, 0.05);
    // Lash line over the top, flicking out at the outer corner.
    const lash = m(new THREE.TorusGeometry(0.104, 0.016, 6, 20, Math.PI * 0.82), FM.eye, false);
    lash.scale.set(0.9, 1.06, 1); lash.rotation.z = Math.PI * 0.09; lash.position.z = 0.03;
    if (sx < 0) lash.rotation.y = Math.PI;
    const flick = m(tuft(0.016, 0.06), FM.eye, false); flick.position.set(sx * 0.09, 0.05, 0.03); flick.rotation.z = -sx * 1.0;
    eye.add(outline, iris, glow, pupil, s1, s2, lash, flick);
    const brow = m(new THREE.TorusGeometry(0.065, 0.012, 5, 12, Math.PI * 0.55), FM.deep, false);
    brow.position.set(sx * 0.2, 0.19, 0.42); brow.rotation.set(-0.35, sx * 0.3, Math.PI / 2 - Math.PI * 0.275 + sx * -0.15);
    const blush = m(new THREE.CircleGeometry(0.068, 18), FM.blush, false); blush.position.set(sx * 0.33, -0.15, 0.405); blush.rotation.y = sx * 0.62;
    head.add(eye, brow, blush);
    // Ears: tall and rounded, blue backs, white rims, peach inside with fluff.
    const ear = joint(`ear_${side}`, sx * 0.3, 0.33, -0.02); ear.rotation.z = sx * -0.36;
    const shell = m(capsule2(0.21, 0.035, 0.46), FM.blue); shell.scale.z = 0.5;
    const rim = m(capsule2(0.18, 0.03, 0.4), FM.fur, false); rim.scale.z = 0.4; rim.position.set(0, 0.0, 0.035);
    const innerE = m(capsule2(0.12, 0.02, 0.32, 16), FM.inner, false); innerE.scale.z = 0.3; innerE.position.set(0, 0.02, 0.07);
    const fluff = m(tuft(0.05, 0.17), FM.fur, false); fluff.position.set(-sx * 0.03, -0.02, 0.1); fluff.rotation.z = sx * 0.3;
    ear.add(shell, rim, innerE, fluff);
    head.add(ear);
  }
  rig.add(head);

  // Tail: six joints curling up behind, each a tapered capsule to the next,
  // so it bends as one plume: white at the root, the art's blue, a white tip.
  let parent = joint('tail_root', 0, 0.55, -0.42);
  rig.add(parent);
  const radii = [0.15, 0.22, 0.28, 0.3, 0.25, 0.15, 0.03];
  const step = new THREE.Vector3(0, 0.17, -0.13); const segLen = step.length(); const segTilt = Math.atan2(step.z, step.y);
  const lens = [segLen, segLen, segLen, segLen, segLen, 0.3];
  const total = lens.reduce((a, b) => a + b, 0);
  const tw = new THREE.Color(MAT.foxWhite), tb = new THREE.Color(MAT.foxBlue), tc = new THREE.Color();
  // White root, the art's blue plume, a white tip: one gradient along the
  // whole tail, so neighbouring pieces agree where they overlap.
  const tailColour = (s) => tc.copy(tw).lerp(tb, smooth(0.16, 0.36, s) * (1 - smooth(0.8, 0.93, s)));
  let cum = 0;
  radii.slice(0, 6).forEach((r, i) => {
    const seg = joint(`tail_${i}`, 0, i === 0 ? 0 : step.y, i === 0 ? 0 : step.z);
    seg.rotation.x = -0.3;
    const len = lens[i];
    const g = capsule2(r, radii[i + 1], len, 20);
    const gp = g.attributes.position; const cols = new Float32Array(gp.count * 3);
    for (let v = 0; v < gp.count; v++) {
      // Clamped, so both pieces paint the sphere they share at a joint alike.
      const s = (cum + THREE.MathUtils.clamp(gp.getY(v) / len, 0, 1) * len) / total;
      tailColour(s); cols[v * 3] = tc.r; cols[v * 3 + 1] = tc.g; cols[v * 3 + 2] = tc.b;
    }
    g.setAttribute('color', new THREE.BufferAttribute(cols, 3));
    cum += len;
    const piece = m(g, FM.tail);
    piece.rotation.x = segTilt;
    seg.add(piece);
    parent.add(seg); parent = seg;
  });

  // Cape: open at the front, closed at the neck by the gold fleur-de-lys
  // clasp, flaring back over the shoulders, hemmed and edged in gold.
  if (cape) {
    const capeJ = joint('cape', 0, 0.98, 0.02);
    const L = 0.6;
    const at = (u, v, out = 0) => {
      const open = 0.3 + 1.05 * v;
      const phi = open + u * (2 * Math.PI - 2 * open);
      const r = 0.3 + 0.27 * v + out;
      const y = -v * L + (v > 0.85 ? Math.sin(phi * 7) * 0.02 * (v - 0.85) / 0.15 : 0);
      return new THREE.Vector3(Math.sin(phi) * r, y, Math.cos(phi) * r - v * v * 0.2 - 0.02);
    };
    const NU = 32, NV = 8;
    const pos = []; const idx = [];
    for (let j = 0; j <= NV; j++) for (let i = 0; i <= NU; i++) { const p = at(i / NU, j / NV); pos.push(p.x, p.y, p.z); }
    for (let j = 0; j < NV; j++) for (let i = 0; i < NU; i++) { const a = j * (NU + 1) + i, b = a + 1, c = a + NU + 1, d = c + 1; idx.push(a, c, b, b, c, d); }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); geo.setIndex(idx); geo.computeVertexNormals();
    const outer = m(geo, FM.cape);
    const lining = m(geo.clone().scale(0.97, 0.995, 0.97), FM.capeLining, false);
    // Gold piping along the open edges and the hem.
    const edge = [];
    for (let j = 1; j <= 20; j++) edge.push(at(0, j / 20, 0.004));
    for (let i = 1; i < 40; i++) edge.push(at(i / 40, 1, 0.004));
    for (let j = 20; j >= 1; j--) edge.push(at(1, j / 20, 0.004));
    const trim = m(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(edge), 110, 0.018, 5, false), FM.gold, false);
    capeJ.add(outer, lining, trim);
    // Clasp: a gold medallion with the fleur-de-lys, at the throat.
    const medal = m(new THREE.CylinderGeometry(0.105, 0.105, 0.035, 28).rotateX(Math.PI / 2), FM.gold); medal.position.set(0, 0.84, 0.5); medal.rotation.x = -0.3;
    const rimG = m(new THREE.TorusGeometry(0.105, 0.016, 8, 28), FM.gold, false); rimG.position.copy(medal.position); rimG.rotation.x = -0.3;
    const fl = new THREE.Mesh(new THREE.ExtrudeGeometry(fleurShapes(), { depth: 0.02, bevelEnabled: false, curveSegments: 6 }), FM.deep);
    fl.geometry.center(); fl.scale.setScalar(0.15); fl.position.set(0, 0.845, 0.52); fl.rotation.x = -0.3;
    rig.add(capeJ, medal, rimG, fl);
    // Gold cords from the clasp to each edge of the cape.
    for (const u of [0, 1]) {
      const end = at(u, 0.12, 0.01).add(capeJ.position);
      const mid = new THREE.Vector3((end.x) * 0.5, 0.8, 0.52);
      const cord = m(new THREE.TubeGeometry(new THREE.QuadraticBezierCurve3(new THREE.Vector3(0, 0.84, 0.5), mid, end), 12, 0.014, 5, false), FM.gold, false);
      rig.add(cord);
    }
  }

  mergeJoints(fox);
  fox.scale.setScalar(scale);
  fox.animations = buildFoxClips(fox);
  return fox;
}

/**
 * Each joint's own pieces (not its child joints) never move against each
 * other, so merge them per material: one draw call per material per joint
 * instead of one per piece. The fox keeps every joint and clip.
 */
function mergeJoints(root) {
  const joints = [];
  root.traverse((o) => { if (!o.isMesh) joints.push(o); });
  for (const j of joints) {
    const byMat = new Map();
    for (const c of j.children) if (c.isMesh) { if (!byMat.has(c.material)) byMat.set(c.material, []); byMat.get(c.material).push(c); }
    for (const [mat, list] of byMat) {
      if (list.length < 2) continue;
      const geos = list.map((c) => {
        c.updateMatrix();
        let g = c.geometry.clone().applyMatrix4(c.matrix);
        if (!g.attributes.uv) g.setAttribute('uv', new THREE.Float32BufferAttribute(new Float32Array(g.attributes.position.count * 2), 2));
        for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv', 'color'].includes(k)) g.deleteAttribute(k);
        return g;
      });
      const indexed = geos.every((g) => g.index);
      const merged = mergeGeometries(indexed ? geos : geos.map((g) => (g.index ? g.toNonIndexed() : g)));
      if (!merged) continue;
      const mesh = new THREE.Mesh(merged, mat);
      mesh.castShadow = list.some((c) => c.castShadow); mesh.receiveShadow = true;
      mesh.name = `${j.name}_${mat.name.replace('fox_', '')}`;
      for (const c of list) j.remove(c);
      j.add(mesh);
    }
  }
  // Untextured pieces don't need UVs; dropping them trims fox.glb.
  root.traverse((o) => { if (o.isMesh && !o.material.map && o.geometry.attributes.uv) o.geometry.deleteAttribute('uv'); });
}

// ---------- animation ----------
// Each clip is a periodic pose function, sampled into keyframes. All its
// frequencies are whole multiples of the clip's own period, so it loops
// without a seam.
const CLIPS = {
  idle: { T: 4.0, loop: true },
  walk: { T: 0.72, loop: true },
  wave: { T: 1.6, loop: false },
  hop: { T: 0.7, loop: false },
};

function pose(nodes, name, t, T) {
  const w = (n) => (2 * Math.PI * n * t) / T; // n cycles per clip
  const { rig, head, legs, ears, eyes, tail, cape } = nodes;
  // Rest
  rig.position.set(0, 0, 0); rig.rotation.set(0, 0, 0);
  head.rotation.set(0, 0, 0);
  legs.forEach((l) => { l.rotation.set(0, 0, 0); if (l.userData.rest) l.position.copy(l.userData.rest); });
  ears.forEach((e, i) => e.rotation.set(0, 0, i ? -0.36 : 0.36));
  eyes.forEach((e) => e.scale.set(1, 1, 1));
  tail.forEach((s) => s.rotation.set(-0.3, 0, 0));
  if (cape) cape.rotation.set(0, 0, 0);

  if (name === 'idle') {
    rig.position.y = Math.sin(w(2)) * 0.015;
    head.rotation.y = Math.sin(w(1)) * 0.14;
    head.rotation.z = Math.sin(w(1) + 1) * 0.05;
    head.rotation.x = Math.sin(w(2)) * 0.03;
    tail.forEach((s, i) => { s.rotation.y = Math.sin(w(2) - i * 0.6) * 0.2; });
    const tw = Math.max(0, Math.sin(w(1) * 1 + 0.5) - 0.9) * 8; ears[0].rotation.x = -tw * 0.2;
    const blink = t > T * 0.86 && t < T * 0.9 ? 0.1 : 1; eyes.forEach((e) => { e.scale.y = blink; });
    if (cape) cape.rotation.x = Math.sin(w(1)) * 0.03;
  } else if (name === 'walk') {
    const s = w(1);
    rig.position.y = Math.abs(Math.sin(s)) * 0.07;
    rig.rotation.z = Math.sin(s) * 0.04;
    legs.forEach((l, i) => { l.rotation.x = Math.sin(s + (i === 0 || i === 3 ? 0 : Math.PI)) * 0.7; });
    head.rotation.x = -0.06 + Math.sin(s * 2) * 0.03;
    tail.forEach((sg, i) => { sg.rotation.y = Math.sin(s - i * 0.6) * 0.28; });
    if (cape) cape.rotation.x = -0.12 - Math.abs(Math.sin(s)) * 0.06;
  } else if (name === 'wave') {
    const up = Math.sin(Math.min(1, t / (T * 0.2)) * Math.PI / 2) * (t > T * 0.8 ? Math.max(0, 1 - (t - T * 0.8) / (T * 0.2)) : 1);
    // The paw comes up beside the face: the shoulder lifts, the body leans
    // back a touch, and the forearm waves from side to side.
    rig.rotation.x = -up * 0.08;
    legs[1].position.y += up * 0.3; legs[1].position.z += up * 0.06;
    legs[1].rotation.x = -up * 2.5;
    legs[1].rotation.z = up * (0.45 + Math.sin(w(3)) * 0.4);
    head.rotation.z = up * 0.14;
    head.rotation.y = up * -0.1;
    tail.forEach((sg, i) => { sg.rotation.y = Math.sin(w(3) - i * 0.6) * 0.3 * up; });
  } else if (name === 'hop') {
    const k = t / T;
    rig.position.y = Math.sin(k * Math.PI) * 0.9;
    rig.rotation.y = k * Math.PI * 2;
    legs.forEach((l, i) => { l.rotation.x = Math.sin(k * Math.PI) * (i < 2 ? -0.6 : 0.6); });
    ears.forEach((e) => { e.rotation.x = Math.sin(k * Math.PI) * 0.5; });
    tail.forEach((sg) => { sg.rotation.x = -0.3 - Math.sin(k * Math.PI) * 0.25; });
  }
}

function foxNodes(fox) {
  const n = (name) => fox.getObjectByName(name);
  return {
    rig: n('rig'), head: n('head'), cape: n('cape'),
    legs: [0, 1, 2, 3].map((i) => n(`leg_${i}`)),
    ears: ['L', 'R'].map((s) => n(`ear_${s}`)),
    eyes: ['L', 'R'].map((s) => n(`eye_${s}`)),
    tail: [0, 1, 2, 3, 4, 5].map((i) => n(`tail_${i}`)),
  };
}

export function buildFoxClips(fox) {
  const nodes = foxNodes(fox);
  const animated = [nodes.rig, nodes.head, nodes.cape, ...nodes.legs, ...nodes.ears, ...nodes.eyes, ...nodes.tail].filter(Boolean);
  const clips = [];
  for (const [name, { T }] of Object.entries(CLIPS)) {
    const fps = 30; const frames = Math.round(T * fps);
    const times = [];
    const data = new Map(animated.map((o) => [o, { p: [], q: [], s: [] }]));
    for (let f = 0; f <= frames; f++) {
      const t = (f / frames) * T;
      times.push(t);
      pose(nodes, name, t, T);
      for (const o of animated) {
        const d = data.get(o);
        d.p.push(o.position.x, o.position.y, o.position.z);
        o.quaternion.setFromEuler(o.rotation);
        d.q.push(o.quaternion.x, o.quaternion.y, o.quaternion.z, o.quaternion.w);
        d.s.push(o.scale.x, o.scale.y, o.scale.z);
      }
    }
    const tracks = [];
    for (const o of animated) {
      const d = data.get(o);
      if (o === nodes.rig || nodes.legs.includes(o)) tracks.push(new THREE.VectorKeyframeTrack(`${o.name}.position`, times, d.p));
      tracks.push(new THREE.QuaternionKeyframeTrack(`${o.name}.quaternion`, times, d.q));
      if (o.name.startsWith('eye')) tracks.push(new THREE.VectorKeyframeTrack(`${o.name}.scale`, times, d.s));
    }
    clips.push(new THREE.AnimationClip(name, T, tracks));
  }
  pose(nodes, 'rest', 0, 1);
  return clips;
}

/**
 * Drive a fox (procedural or loaded from fox.glb) with its clips: idle
 * underneath, walk blended by speed, wave and hop played once on top.
 */
export function createFoxController(fox, clips) {
  const mixer = new THREE.AnimationMixer(fox);
  const get = (n) => { const c = THREE.AnimationClip.findByName(clips, n); return c ? mixer.clipAction(c) : null; };
  const idle = get('idle'), walk = get('walk'), wave = get('wave'), hop = get('hop');
  for (const a of [idle, walk]) if (a) { a.play(); a.setEffectiveWeight(0); }
  if (idle) idle.setEffectiveWeight(1);
  for (const a of [wave, hop]) if (a) { a.setLoop(THREE.LoopOnce, 1); a.clampWhenFinished = false; }
  let walking = 0;
  return {
    mixer,
    update(dt, { walk: wantWalk = 0, motion = 1 } = {}) {
      walking = THREE.MathUtils.damp(walking, wantWalk, 8, dt);
      // A one-shot (wave, hop) mostly takes over from idle while it plays.
      const busy = (wave && wave.isRunning()) || (hop && hop.isRunning());
      if (idle) idle.setEffectiveWeight((1 - walking) * (busy ? 0.15 : 1));
      if (walk) walk.setEffectiveWeight(walking);
      mixer.update(dt * motion);
    },
    wave() { if (wave && !wave.isRunning()) { wave.reset().fadeIn(0.15).play(); } },
    hop() { if (hop) { hop.reset().play(); } },
  };
}
