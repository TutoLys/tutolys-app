// The subject buildings, modelled after the app's own illustrated art
// (assets/images/asset-bldg-*.webp): cream stone, blue slate roofs, gold
// trim, Québec flags, and each subject's sign — π and the armillary for
// math, the open book and quill for français, the globe for univers social,
// the observatory for science, the shield and clock tower for CCQ.
import * as THREE from 'three';
import { mergeGeometries, mergeVertices } from 'three/addons/utils/BufferGeometryUtils.js';
import { MAT } from './palette.js';
import { U, addFlagWave, addSway } from './fx.js';
import { leafyBush, shadeVertices } from './shapes.js';
import { bannerTexture, emblemTexture, fleurShapes, quebecFlagTexture, softDotTexture, stoneTexture, slateTexture, plankTexture } from './textures.js';

const std = (color, extra = {}) => new THREE.MeshStandardMaterial({ color, roughness: 0.78, metalness: 0, ...extra });

const M = {
  stone: std(0xfff3dc, { map: stoneTexture() }),
  stoneShade: std(0xf2e2c4, { map: stoneTexture() }),
  stoneDark: std(0xd9c39b, { map: stoneTexture() }),
  slate: std(0x3f6ae6, { roughness: 0.55, map: slateTexture() }),
  slateDark: std(MAT.slateDark, { roughness: 0.6, flatShading: true }),
  gold: new THREE.MeshStandardMaterial({ color: MAT.gold, metalness: 0.8, roughness: 0.32 }),
  goldBright: new THREE.MeshStandardMaterial({ color: MAT.goldBright, metalness: 0.7, roughness: 0.3 }),
  door: std(0x3058c4, { roughness: 0.55, map: plankTexture() }),
  wood: std(MAT.wood),
  woodDark: std(MAT.woodDark),
  iron: std(MAT.iron, { roughness: 0.5 }),
  window: new THREE.MeshStandardMaterial({ color: 0x9fc6f0, emissive: MAT.windowGlow, emissiveIntensity: 0.05, roughness: 0.25, metalness: 0.1 }),
  snow: std(0xf8fbff, { roughness: 0.65, flatShading: true }),
  grass: std(0x74c46e, { roughness: 0.95 }),
  paper: std(0xfff8e8, { roughness: 0.9, side: THREE.DoubleSide }),
  green: std(0x5fb85a, { flatShading: true }),
  glassGreen: new THREE.MeshStandardMaterial({ color: 0x7ee0b0, emissive: 0x2fb170, emissiveIntensity: 0.25, transparent: true, opacity: 0.85, roughness: 0.2 }),
  bloomPink: std(0xf9a8d4), bloomGold: std(0xfde68a), bloomWhite: std(0xffffff),
};
// World-space UVs for tiled surfaces, so blocks and shingles keep their size
// on every wall and roof (applied when a building is baked, see mergeStatic).
M.stone.userData.planarUV = M.stoneShade.userData.planarUV = M.stoneDark.userData.planarUV = 1.7;
M.slate.userData.planarUV = 1.3;
// Material names are the glTF contract: a model that uses these names gets
// the village's shared materials (night glow, winter snow, season grass).
for (const [k, m] of Object.entries(M)) m.name = k;
for (const k of ['bloomPink', 'bloomGold', 'bloomWhite']) M[k].name = 'bloom';
export const buildingMaterials = M;

function mesh(geo, mat, { cast = true, receive = true } = {}) {
  const m = new THREE.Mesh(geo, mat);
  m.castShadow = cast; m.receiveShadow = receive;
  return m;
}

// ---------- parts ----------
function arch(w, h) {
  const s = new THREE.Shape();
  const r = w / 2;
  s.moveTo(-r, 0); s.lineTo(-r, h - r); s.absarc(0, h - r, r, Math.PI, 0, true); s.lineTo(r, 0); s.closePath();
  return s;
}
function archMesh(w, h, depth, mat) {
  const g = new THREE.ExtrudeGeometry(arch(w, h), { depth, bevelEnabled: false, curveSegments: 12 });
  return mesh(g, mat);
}

function door(w = 0.95, h = 1.5) {
  const g = new THREE.Group();
  const frame = archMesh(w + 0.22, h + 0.11, 0.08, M.gold); frame.position.z = -0.02;
  const leaf = archMesh(w, h, 0.1, M.door);
  const knob = mesh(new THREE.SphereGeometry(0.045, 8, 6), M.gold); knob.position.set(w * 0.22, h * 0.45, 0.12);
  const knob2 = knob.clone(); knob2.position.x = -w * 0.22;
  const split = mesh(new THREE.BoxGeometry(0.03, h * 0.95, 0.02), M.gold); split.position.set(0, h * 0.47, 0.105);
  g.add(frame, leaf, knob, knob2, split);
  return g;
}

function windowPane(w = 0.42, h = 0.7) {
  const g = new THREE.Group();
  const frame = archMesh(w + 0.12, h + 0.06, 0.05, M.gold);
  const glass = archMesh(w, h, 0.07, M.window);
  const bar = mesh(new THREE.BoxGeometry(0.025, h * 0.95, 0.02), M.gold); bar.position.set(0, h * 0.47, 0.075);
  const sill = mesh(new THREE.BoxGeometry(w + 0.22, 0.06, 0.16), M.stoneDark); sill.position.set(0, -0.02, 0.06);
  // A flower box under the window, as in the art.
  const box = mesh(new THREE.BoxGeometry(w + 0.14, 0.12, 0.14), M.wood); box.position.set(0, -0.11, 0.12);
  g.add(frame, glass, bar, sill, box);
  const blooms = [M.bloomPink, M.bloomGold, M.bloomWhite];
  for (let i = 0; i < 4; i++) {
    const f = mesh(bloomGeo, blooms[i % 3], { cast: false });
    f.position.set(-w / 2 + (i + 0.5) * (w / 4) + 0.02, -0.02, 0.13); f.scale.setScalar(0.8);
    g.add(f);
  }
  return g;
}

/** A stone chimney with a gold cap, for the bigger roofs. */
function chimney(h = 0.9) {
  const g = new THREE.Group();
  const stack = mesh(new THREE.BoxGeometry(0.34, h, 0.34), M.stoneShade); stack.position.y = h / 2;
  const cap = mesh(new THREE.BoxGeometry(0.44, 0.08, 0.44), M.gold); cap.position.y = h;
  g.add(stack, cap);
  return g;
}

/** A pyramid roof over a w×d footprint, plus its winter snow cap. */
function hipRoof(w, d, h, snowList, mat = M.slate) {
  const g = new THREE.Group();
  const geo = new THREE.ConeGeometry(Math.SQRT1_2, 1, 4, 1).rotateY(Math.PI / 4);
  const roof = mesh(geo, mat); roof.scale.set(w * 1.12, h, d * 1.12); roof.position.y = h / 2;
  const eave = mesh(new THREE.BoxGeometry(w * 1.16, 0.1, d * 1.16), M.gold); eave.position.y = 0.02;
  const finial = mesh(new THREE.SphereGeometry(0.13, 10, 8), M.gold); finial.position.y = h + 0.08;
  const spike = mesh(new THREE.ConeGeometry(0.05, 0.4, 6), M.gold); spike.position.y = h + 0.3;
  const snow = mesh(new THREE.ConeGeometry(Math.SQRT1_2, 1, 4, 1).rotateY(Math.PI / 4), M.snow);
  snow.scale.set(w * 1.12 * 0.62, h * 0.62, d * 1.12 * 0.62); snow.position.y = h - h * 0.62 / 2 + 0.03;
  snow.scale.multiplyScalar(1.04); snow.visible = false; snow.name = 'snow'; snowList.push(snow);
  g.add(roof, eave, finial, spike, snow);
  return g;
}

/** A gabled roof running along x. */
function gableRoof(w, d, h, snowList) {
  const g = new THREE.Group();
  const s = new THREE.Shape();
  s.moveTo(-d / 2 - 0.15, 0); s.lineTo(0, h); s.lineTo(d / 2 + 0.15, 0); s.closePath();
  const geo = new THREE.ExtrudeGeometry(s, { depth: w + 0.3, bevelEnabled: false }).translate(0, 0, -(w + 0.3) / 2).rotateY(Math.PI / 2);
  const roof = mesh(geo, M.slate);
  const ridge = mesh(new THREE.BoxGeometry(w + 0.36, 0.09, 0.12), M.gold); ridge.position.y = h;
  const sgeo = new THREE.ExtrudeGeometry((() => { const q = new THREE.Shape(); q.moveTo(-d * 0.32, h * 0.36); q.lineTo(0, h + 0.06); q.lineTo(d * 0.32, h * 0.36); q.closePath(); return q; })(),
    { depth: w + 0.34, bevelEnabled: false }).translate(0, 0, -(w + 0.34) / 2).rotateY(Math.PI / 2);
  const snow = mesh(sgeo, M.snow); snow.position.y = 0.03; snow.visible = false; snow.name = 'snow'; snowList.push(snow);
  g.add(roof, ridge, snow);
  return g;
}

function tower(r, h, roofH, snowList, { flag = false, windows = true, roofMat = M.slate } = {}) {
  const g = new THREE.Group();
  const body = mesh(new THREE.CylinderGeometry(r, r * 1.05, h, 16), M.stone); body.position.y = h / 2;
  const band = mesh(new THREE.CylinderGeometry(r * 1.1, r * 1.1, 0.12, 16), M.gold); band.position.y = h;
  const roof = mesh(new THREE.ConeGeometry(r * 1.32, roofH, 10), roofMat); roof.position.y = h + roofH / 2;
  const finial = mesh(new THREE.SphereGeometry(0.1 + r * 0.06, 10, 8), M.gold); finial.position.y = h + roofH + 0.05;
  const snow = mesh(new THREE.ConeGeometry(r * 1.32 * 0.6, roofH * 0.6, 10), M.snow);
  snow.position.y = h + roofH - roofH * 0.3 + 0.02; snow.scale.setScalar(1.04); snow.visible = false; snow.name = 'snow'; snowList.push(snow);
  g.add(body, band, roof, finial, snow);
  if (windows) {
    const w = windowPane(r * 0.55, r * 0.95); w.position.set(0, h * 0.55, r * 0.98); g.add(w);
  }
  if (flag) {
    const f = flagPole(roofH * 0.9 + 0.6); f.position.y = h + roofH + 0.05; g.add(f);
  }
  return g;
}

function dome(r, snowList, mat = M.slate) {
  const g = new THREE.Group();
  const d = mesh(new THREE.SphereGeometry(r, 24, 14, 0, Math.PI * 2, 0, Math.PI / 2), mat);
  for (let k = 0; k < 8; k++) {
    const rib = mesh(new THREE.TorusGeometry(r * 1.005, 0.035, 5, 24, Math.PI / 2), M.gold);
    rib.rotation.y = (k / 8) * Math.PI * 2;
    g.add(rib);
  }
  const ring = mesh(new THREE.TorusGeometry(r * 1.01, 0.08, 6, 32).rotateX(Math.PI / 2), M.gold);
  const lantern = mesh(new THREE.CylinderGeometry(r * 0.16, r * 0.2, r * 0.3, 8), M.gold); lantern.position.y = r + r * 0.12;
  const ball = mesh(new THREE.SphereGeometry(r * 0.11, 10, 8), M.goldBright); ball.position.y = r + r * 0.36;
  const snow = mesh(new THREE.SphereGeometry(r * 1.02, 24, 8, 0, Math.PI * 2, 0, Math.PI / 4), M.snow);
  snow.visible = false; snow.name = 'snow'; snowList.push(snow);
  g.add(d, ring, lantern, ball, snow);
  return g;
}

function flagPole(len = 1.4) {
  const g = new THREE.Group();
  g.name = 'flagpole';
  const pole = mesh(new THREE.CylinderGeometry(0.03, 0.035, len, 6), M.gold); pole.position.y = len / 2;
  const tip = mesh(new THREE.SphereGeometry(0.06, 8, 6), M.gold); tip.position.y = len;
  const L = 0.95;
  const geo = new THREE.PlaneGeometry(L, L * 0.66, 12, 4).translate(L / 2, 0, 0);
  const mat = addFlagWave(new THREE.MeshStandardMaterial({ map: quebecFlagTexture(), roughness: 0.8 }), L);
  const flag = mesh(geo, mat, { cast: true, receive: false });
  flag.userData.noMerge = true;
  flag.name = 'flag';
  flag.position.set(0.03, len - L * 0.33 - 0.05, 0);
  g.add(pole, tip, flag);
  return g;
}

function banner(w = 0.5, h = 1.0) {
  const m = mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshStandardMaterial({ map: bannerTexture(), transparent: true, alphaTest: 0.4, roughness: 0.8, side: THREE.DoubleSide }), { cast: false });
  return m;
}

function emblem(kind, r = 0.55) {
  const g = new THREE.Group();
  const disc = mesh(new THREE.CircleGeometry(r, 40), new THREE.MeshStandardMaterial({ map: emblemTexture(kind), roughness: 0.45, metalness: 0.15 }), { cast: false });
  disc.position.z = 0.05;
  const rim = mesh(new THREE.TorusGeometry(r, 0.06, 8, 40), M.gold);
  rim.position.z = 0.05;
  g.add(disc, rim);
  return g;
}

function goldFleur(size = 0.6) {
  const geo = new THREE.ExtrudeGeometry(fleurShapes(), { depth: 0.08, bevelEnabled: true, bevelThickness: 0.02, bevelSize: 0.01, bevelSegments: 1, curveSegments: 8 });
  geo.center();
  const m = mesh(geo, M.gold); m.scale.setScalar(size);
  return m;
}

function wallLamp() {
  const g = new THREE.Group();
  const arm = mesh(new THREE.BoxGeometry(0.04, 0.04, 0.2), M.iron); arm.position.z = 0.1;
  const lamp = mesh(new THREE.CylinderGeometry(0.08, 0.06, 0.2, 6), M.window); lamp.position.set(0, -0.06, 0.2);
  const cap = mesh(new THREE.ConeGeometry(0.11, 0.1, 6), M.iron); cap.position.set(0, 0.07, 0.2);
  g.add(arm, lamp, cap);
  return g;
}

function stairs(width, steps = 4, depth = 0.32, rise = 0.12) {
  const g = new THREE.Group();
  for (let i = 0; i < steps; i++) {
    const s = mesh(new THREE.BoxGeometry(width - i * 0.08, rise, depth * (steps - i)), i % 2 ? M.stone : M.stoneShade);
    s.position.set(0, rise * (i + 0.5), (depth * (steps - i)) / 2);
    g.add(s);
  }
  return g;
}

/** The round base every building stands on, like the art's little islands. */
function plinth(r) {
  const g = new THREE.Group();
  const base = mesh(new THREE.CylinderGeometry(r, r + 0.18, 0.42, 48), [M.stoneShade, M.grass, M.stoneShade]); base.position.y = -0.05;
  const lip = mesh(new THREE.TorusGeometry(r + 0.02, 0.09, 6, 64).rotateX(Math.PI / 2), M.stoneDark); lip.position.y = 0.15;
  // A paved court in front of the door.
  const court = mesh(new THREE.CylinderGeometry(r * 0.62, r * 0.62, 0.05, 40), M.stone); court.position.set(0, 0.17, r * 0.18); court.scale.z = 0.8;
  g.add(base, lip, court);
  return g;
}

/** Bushes and blooms around a building's base, swaying with the island's. */
const bushGeo = leafyBush(11, { R: 0.38, clumps: 6, clumpDetail: 0 }).leaves; // same painted leafy mound as the island's bushes
const bushMat = addSway(std(0x5fb85a, { vertexColors: true }), { amount: 0.04, heightRef: 0.6 });
bushMat.name = 'bush';
const bloomGeo = new THREE.IcosahedronGeometry(0.09, 0);
export const plinthGreen = { bushMat, blooms: [M.bloomPink, M.bloomGold, M.bloomWhite], grass: M.grass };
function shrubs(r, seed, avoidFront = 1.2) {
  const g = new THREE.Group();
  let s = seed;
  const rnd = () => { s = (s * 16807) % 2147483647; return s / 2147483647; };
  for (let k = 0; k < 14; k++) {
    const a = rnd() * Math.PI * 2;
    const x = Math.sin(a) * (r - 0.35), z = Math.cos(a) * (r - 0.35);
    if (z > 0 && Math.abs(x) < avoidFront) continue;
    const b = mesh(bushGeo, bushMat); b.position.set(x, 0.17, z); b.scale.setScalar(0.7 + rnd() * 0.7);
    g.add(b);
    if (rnd() < 0.6) {
      const bloomMat = std([0xffffff, 0xf9a8d4, 0x93c5fd, 0xfde68a][Math.floor(rnd() * 4)]);
      bloomMat.name = 'bloom';
      plinthGreen.blooms.push(bloomMat);
      for (let j = 0; j < 3; j++) {
        const f = mesh(bloomGeo, bloomMat, { cast: false }); f.position.set(x + (rnd() - 0.5) * 0.4, 0.45 + rnd() * 0.15, z + (rnd() - 0.5) * 0.4); g.add(f);
      }
    }
  }
  return g;
}

// ---------- subject props ----------
function armillary(r = 0.55) {
  const g = new THREE.Group();
  for (const [rx, ry] of [[Math.PI / 2, 0], [Math.PI / 2, Math.PI / 3], [0.4, 0], [Math.PI / 2, -Math.PI / 3]]) {
    const t = mesh(new THREE.TorusGeometry(r, 0.035, 6, 40), M.gold); t.rotation.set(rx, ry, 0); g.add(t);
  }
  const core = mesh(new THREE.IcosahedronGeometry(r * 0.32, 0), M.goldBright); g.add(core);
  return g;
}
function telescope(len = 1.6, r = 0.16) {
  const g = new THREE.Group();
  const tube = mesh(new THREE.CylinderGeometry(r, r * 0.7, len, 14).rotateZ(Math.PI / 2), M.slateDark);
  const ring1 = mesh(new THREE.TorusGeometry(r * 1.02, 0.03, 6, 16).rotateY(Math.PI / 2), M.gold); ring1.position.x = len / 2;
  const ring2 = ring1.clone(); ring2.position.x = 0;
  const lens = mesh(new THREE.CircleGeometry(r * 0.9, 16).rotateY(Math.PI / 2), new THREE.MeshStandardMaterial({ color: 0x0b1d4a, emissive: 0x2f6fed, emissiveIntensity: 0.4 })); lens.position.x = len / 2 + 0.01;
  g.add(tube, ring1, ring2, lens);
  return g;
}
function bookStack(n = 3) {
  const g = new THREE.Group();
  const colors = [0x2f55c9, 0x3dbe7a, 0xd4af37, 0xf2994a, 0x8b5cf6];
  for (let i = 0; i < n; i++) {
    const b = mesh(new THREE.BoxGeometry(0.72 - i * 0.05, 0.16, 0.5), std(colors[i % colors.length]));
    b.position.y = 0.08 + i * 0.16; b.rotation.y = (i % 2 ? 0.2 : -0.12); g.add(b);
    const pages = mesh(new THREE.BoxGeometry(0.66 - i * 0.05, 0.12, 0.46), M.paper); pages.position.set(0.02, 0.08 + i * 0.16, 0); pages.rotation.y = b.rotation.y; g.add(pages);
  }
  return g;
}
function openBook(w = 1.4) {
  const g = new THREE.Group();
  for (const side of [-1, 1]) {
    const geo = new THREE.PlaneGeometry(w / 2, w * 0.68, 8, 1).translate(w / 4, 0, 0);
    const p = geo.attributes.position;
    for (let i = 0; i < p.count; i++) { const x = p.getX(i); p.setZ(i, Math.sin((x / (w / 2)) * Math.PI) * 0.08); }
    geo.computeVertexNormals();
    const page = mesh(geo, M.paper); page.scale.x = side; page.rotation.y = side * -0.25; g.add(page);
    const cover = mesh(new THREE.BoxGeometry(w / 2 + 0.06, w * 0.72, 0.04).translate(w / 4, 0, -0.04), std(0x2346a8));
    cover.scale.x = side; cover.rotation.y = side * -0.25; g.add(cover);
    for (let k = 0; k < 5; k++) {
      const line = mesh(new THREE.BoxGeometry(w * 0.32, 0.018, 0.005), std(0xb7c6e6), { cast: false });
      line.position.set(side * w * 0.25, w * 0.2 - k * w * 0.1, 0.08); line.rotation.y = side * -0.25; g.add(line);
    }
  }
  return g;
}
function quill() {
  const g = new THREE.Group();
  const vane = mesh(new THREE.SphereGeometry(0.5, 12, 8), std(0xffffff, { roughness: 0.6 }));
  vane.scale.set(0.24, 1.2, 0.06);
  const shaft = mesh(new THREE.CylinderGeometry(0.02, 0.03, 1.4, 6), M.gold); shaft.position.y = -0.4;
  g.add(vane, shaft);
  return g;
}
let _globeTex;
// Rough continent outlines (lon, lat), enough to read as Earth at a glance.
const LANDS = [
  [[-168, 66], [-140, 70], [-95, 72], [-80, 62], [-62, 56], [-55, 48], [-70, 43], [-76, 35], [-81, 25], [-97, 26], [-97, 18], [-88, 15], [-83, 9], [-78, 8], [-92, 15], [-105, 20], [-112, 25], [-117, 32], [-124, 40], [-125, 49], [-135, 58], [-152, 60], [-165, 61]],
  [[-55, 60], [-43, 60], [-22, 70], [-18, 80], [-45, 83], [-68, 79]],
  [[-79, 9], [-62, 11], [-50, 1], [-35, -6], [-39, -15], [-48, -26], [-57, -37], [-66, -55], [-73, -48], [-73, -35], [-71, -18], [-81, -5]],
  [[-10, 36], [-2, 43], [-5, 48], [1, 50], [8, 54], [5, 58], [11, 63], [20, 70], [32, 70], [42, 66], [46, 55], [40, 46], [28, 41], [22, 38], [14, 38], [10, 44], [3, 43]],
  [[-6, 50], [2, 51], [0, 55], [-3, 58.5], [-6, 56]],
  [[-17, 21], [-10, 30], [-1, 36], [10, 37], [20, 32], [32, 31], [35, 27], [43, 12], [51, 12], [41, -2], [40, -15], [33, -27], [20, -35], [15, -27], [12, -14], [9, 1], [-5, 5], [-16, 11]],
  [[44, -13], [50, -16], [48, -25], [44, -24]],
  [[35, 28], [43, 13], [53, 16], [59, 22], [50, 30]],
  [[30, 70], [70, 74], [110, 77], [140, 72], [180, 68], [172, 60], [160, 54], [142, 50], [132, 42], [122, 31], [121, 23], [109, 20], [105, 10], [100, 13], [98, 8], [92, 22], [86, 22], [80, 15], [77, 8], [72, 20], [62, 25], [52, 28], [48, 38], [42, 44], [46, 55], [42, 66]],
  [[130, 33], [136, 34], [142, 40], [141, 44], [137, 37]],
  [[95, 5], [105, -6], [116, -8], [120, -2], [112, 2], [104, 2]],
  [[131, -2], [141, -3], [150, -8], [141, -9], [135, -5]],
  [[114, -22], [122, -18], [130, -12], [137, -12], [142, -11], [146, -18], [153, -28], [150, -37], [140, -38], [130, -32], [115, -34]],
  [[167, -46], [174, -41], [178, -38], [172, -35]],
];
function globeTexture() {
  if (_globeTex) return _globeTex;
  const W = 1024, H = 512;
  const c = document.createElement('canvas'); c.width = W; c.height = H;
  const x = c.getContext('2d');
  const P = (lon, lat) => [((lon + 180) / 360) * W, ((90 - lat) / 180) * H];
  const sea = x.createLinearGradient(0, 0, 0, H);
  sea.addColorStop(0, '#5fb3e8'); sea.addColorStop(0.5, '#2f86d0'); sea.addColorStop(1, '#5fb3e8');
  x.fillStyle = sea; x.fillRect(0, 0, W, H);
  // Shallow-water halo under every coast, then the land in two greens.
  for (const [pass, col, lw] of [[0, '#8fd3f4', 14], [1, '#6cc463', 0], [2, '#8ad66f', 0]]) {
    for (const poly of LANDS) {
      x.beginPath(); poly.forEach(([lo, la], i) => { const [px, py] = P(lo, la); i ? x.lineTo(px, py) : x.moveTo(px, py); }); x.closePath();
      if (pass === 0) { x.strokeStyle = col; x.lineWidth = lw; x.lineJoin = 'round'; x.stroke(); }
      else if (pass === 1) { x.fillStyle = col; x.fill(); }
      else { x.save(); x.clip(); x.fillStyle = col; x.globalAlpha = 0.55; for (let k = 0; k < 40; k++) { x.beginPath(); x.arc(Math.random() * W, Math.random() * H, 10 + Math.random() * 26, 0, 7); x.fill(); } x.restore(); }
    }
  }
  // Deserts and ice.
  x.fillStyle = '#e9cf8e'; for (const [lo, la, rx, ry] of [[15, 23, 26, 9], [45, 23, 9, 7], [133, -25, 12, 6]]) { const [px, py] = P(lo, la); x.beginPath(); x.ellipse(px, py, rx * W / 360, ry * H / 180, 0, 0, 7); x.fill(); }
  x.fillStyle = '#f4f8ff'; x.fillRect(0, 0, W, H * 0.045); x.fillRect(0, H * 0.9, W, H * 0.1);
  // Faint graticule.
  x.strokeStyle = 'rgba(255,255,255,0.28)'; x.lineWidth = 1.5;
  for (let lo = -180; lo <= 180; lo += 30) { const [px] = P(lo, 0); x.beginPath(); x.moveTo(px, 0); x.lineTo(px, H); x.stroke(); }
  for (let la = -60; la <= 60; la += 30) { const [, py] = P(0, la); x.beginPath(); x.moveTo(0, py); x.lineTo(W, py); x.stroke(); }
  x.strokeStyle = 'rgba(242,201,76,0.6)'; x.lineWidth = 2.5; { const [, py] = P(0, 0); x.beginPath(); x.moveTo(0, py); x.lineTo(W, py); x.stroke(); }
  _globeTex = new THREE.CanvasTexture(c); _globeTex.colorSpace = THREE.SRGBColorSpace;
  return _globeTex;
}
/** A desk globe: world map on a 23.5° axis (it spins about that axis), a full
 *  gold meridian ring with axis pins, on a turned gold-and-wood stand. */
function globe(r = 0.8) {
  const g = new THREE.Group();
  const tilt = new THREE.Group(); tilt.rotation.z = 0.41;
  const s = mesh(new THREE.SphereGeometry(r, 40, 24), new THREE.MeshStandardMaterial({ map: globeTexture(), roughness: 0.45 }));
  s.name = 'spin'; tilt.add(s);
  const ring = mesh(new THREE.TorusGeometry(r * 1.1, 0.04, 8, 64), M.gold); tilt.add(ring);
  for (const sy of [-1, 1]) { const pin = mesh(new THREE.CylinderGeometry(0.03, 0.03, r * 0.25, 8), M.gold); pin.position.y = sy * r * 1.04; tilt.add(pin); }
  g.add(tilt);
  const yoke = mesh(new THREE.TorusGeometry(r * 1.1, 0.03, 6, 32, Math.PI), M.gold); yoke.rotation.set(0, Math.PI / 2, Math.PI); g.add(yoke);
  const stem = mesh(new THREE.CylinderGeometry(0.06, 0.09, 0.35, 10), M.gold); stem.position.y = -r * 1.1 - 0.17; g.add(stem);
  const foot = mesh(new THREE.CylinderGeometry(0.2, 0.32, 0.12, 16), M.woodDark); foot.position.y = -r * 1.1 - 0.4; g.add(foot);
  const footRing = mesh(new THREE.TorusGeometry(0.31, 0.025, 6, 24).rotateX(Math.PI / 2), M.gold); footRing.position.y = -r * 1.1 - 0.35; g.add(footRing);
  return g;
}
/** One painted signboard face: white Baloo 2 on wood, shrunk to fit. */
function signTexture(t) {
  const c = document.createElement('canvas'); c.width = 256; c.height = 64;
  const x = c.getContext('2d');
  x.fillStyle = '#C9904F'; x.fillRect(0, 0, 256, 64);
  x.strokeStyle = '#8B5A2B'; x.lineWidth = 6; x.strokeRect(3, 3, 250, 58);
  x.fillStyle = '#ffffff'; x.textAlign = 'center'; x.textBaseline = 'middle';
  let px = 34;
  do { x.font = `700 ${px}px "Baloo 2", sans-serif`; } while (x.measureText(t).width > 226 && --px > 14);
  x.fillText(t, 128, 35);
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 4;
  return tex;
}
/**
 * Signposts carry words, so each board is named `signboard_<kind>_<i>` and
 * the host's strings (`sign.<kind>.<i>`) repaint it at runtime, on the
 * procedural build and on a baked .glb alike (BRIDGE.md).
 */
function signpost(labels, seed = 1, key = 'sign') {
  const g = new THREE.Group();
  const post = mesh(new THREE.CylinderGeometry(0.06, 0.07, 1.8, 6), M.woodDark); post.position.y = 0.9; g.add(post);
  labels.forEach((t, i) => {
    const tex = signTexture(t);
    const board = mesh(new THREE.BoxGeometry(0.85, 0.22, 0.05), [M.wood, M.wood, M.wood, M.wood, std(0xffffff, { map: tex }), std(0xffffff, { map: tex })]);
    board.name = `signboard_${key}_${i}`; board.userData.signText = t;
    board.position.set(i % 2 ? -0.3 : 0.3, 1.55 - i * 0.28, 0); board.rotation.y = (i % 2 ? -1 : 1) * (0.15 + seed * 0.05);
    g.add(board);
  });
  return g;
}
function easel(kind = 'frame') {
  const g = new THREE.Group();
  for (const s of [-1, 1]) { const leg = mesh(new THREE.BoxGeometry(0.05, 1.3, 0.05), M.wood); leg.position.set(s * 0.25, 0.62, 0); leg.rotation.z = s * -0.12; g.add(leg); }
  const back = mesh(new THREE.BoxGeometry(0.05, 1.2, 0.05), M.wood); back.position.set(0, 0.58, -0.25); back.rotation.x = 0.35; g.add(back);
  const board = mesh(new THREE.BoxGeometry(0.75, 0.6, 0.04), kind === 'chalk' ? std(0x2b4a3a) : M.gold); board.position.set(0, 0.95, 0.05); board.rotation.x = -0.1; g.add(board);
  const inner = mesh(new THREE.PlaneGeometry(0.62, 0.48), new THREE.MeshStandardMaterial({ map: emblemTexture(kind === 'chalk' ? 'pi' : 'frame') }), { cast: false });
  inner.position.set(0, 0.95, 0.075); inner.rotation.x = -0.1; g.add(inner);
  return g;
}
function statue() {
  const g = new THREE.Group();
  const ped = mesh(new THREE.BoxGeometry(0.6, 0.7, 0.6), M.stoneShade); ped.position.y = 0.35;
  const bronze = new THREE.MeshStandardMaterial({ color: 0x4a5a6a, metalness: 0.6, roughness: 0.45 });
  const body = mesh(new THREE.CylinderGeometry(0.16, 0.22, 0.75, 8), bronze); body.position.y = 1.1;
  const head = mesh(new THREE.SphereGeometry(0.13, 10, 8), bronze); head.position.y = 1.6;
  const arm = mesh(new THREE.CylinderGeometry(0.05, 0.05, 0.5, 6), bronze); arm.position.set(0.2, 1.38, 0); arm.rotation.z = -0.9;
  g.add(ped, body, head, arm);
  return g;
}
function dish() {
  const g = new THREE.Group();
  const bowl = mesh(new THREE.SphereGeometry(0.4, 16, 8, 0, Math.PI * 2, 0, Math.PI / 3), std(0xf4f8ff, { side: THREE.DoubleSide }));
  bowl.rotation.x = Math.PI + 0.7;
  const stem = mesh(new THREE.CylinderGeometry(0.04, 0.06, 0.5, 6), M.gold); stem.position.y = -0.3;
  g.add(bowl, stem);
  return g;
}
function windmill() {
  const g = new THREE.Group();
  const mast = mesh(new THREE.CylinderGeometry(0.04, 0.05, 1.1, 6), M.stone); mast.position.y = 0.55; g.add(mast);
  const hub = new THREE.Group(); hub.position.set(0, 1.12, 0.06); hub.name = 'spin';
  for (let k = 0; k < 3; k++) {
    const blade = mesh(new THREE.BoxGeometry(0.1, 0.55, 0.02).translate(0, 0.3, 0), std(0xf4f8ff)); blade.rotation.z = (k / 3) * Math.PI * 2; hub.add(blade);
  }
  g.add(hub);
  return g;
}
function flask() {
  const g = new THREE.Group();
  const bulb = mesh(new THREE.SphereGeometry(0.28, 16, 12), M.glassGreen); bulb.position.y = 0.28;
  const neck = mesh(new THREE.CylinderGeometry(0.07, 0.09, 0.3, 10), M.glassGreen); neck.position.y = 0.62;
  g.add(bulb, neck);
  return g;
}
function solarPanel() {
  const g = new THREE.Group();
  const p = mesh(new THREE.BoxGeometry(0.9, 0.04, 0.6), new THREE.MeshStandardMaterial({ color: 0x1f3c88, metalness: 0.5, roughness: 0.3 }));
  p.rotation.x = -0.5;
  const frame = mesh(new THREE.BoxGeometry(0.95, 0.03, 0.65), M.gold); frame.rotation.x = -0.5; frame.position.y = -0.02;
  g.add(frame, p);
  return g;
}
function clockFace() {
  const c = document.createElement('canvas'); c.width = 128; c.height = 128;
  const x = c.getContext('2d');
  x.fillStyle = '#FFF8E8'; x.beginPath(); x.arc(64, 64, 60, 0, 7); x.fill();
  x.strokeStyle = '#D4AF37'; x.lineWidth = 8; x.stroke();
  x.fillStyle = '#1F3C88';
  for (let k = 0; k < 12; k++) { const a = (k / 12) * Math.PI * 2; x.fillRect(64 + Math.sin(a) * 46 - 3, 64 - Math.cos(a) * 46 - 3, 6, 6); }
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace;
  const g = new THREE.Group();
  g.userData.noMerge = true;
  g.name = 'clock';
  g.add(mesh(new THREE.CircleGeometry(0.34, 24), new THREE.MeshStandardMaterial({ map: tex, emissive: 0xffe2a0, emissiveMap: tex, emissiveIntensity: 0 }), { cast: false }));
  const hand = mesh(new THREE.BoxGeometry(0.03, 0.24, 0.01).translate(0, 0.1, 0), M.slateDark, { cast: false }); hand.position.z = 0.01; hand.name = 'hour';
  const hand2 = mesh(new THREE.BoxGeometry(0.02, 0.3, 0.01).translate(0, 0.13, 0), M.slateDark, { cast: false }); hand2.position.z = 0.015; hand2.name = 'minute';
  g.add(hand, hand2);
  return g;
}

/**
 * Bake every static mesh of a building into one mesh per material, so a
 * building costs a handful of draw calls instead of ~100. Anything that
 * moves on its own (spinners, flags, clock hands) is left alone.
 */
function planarUV(g, tile) {
  const p = g.attributes.position, n = g.attributes.normal, uv = g.attributes.uv;
  for (let i = 0; i < p.count; i++) {
    const nx = Math.abs(n.getX(i)), ny = Math.abs(n.getY(i)), nz = Math.abs(n.getZ(i));
    const x = p.getX(i), y = p.getY(i), z = p.getZ(i);
    if (ny > 0.9) uv.setXY(i, x / tile, z / tile);
    else if (nx > nz) uv.setXY(i, z / tile, y / tile);
    else uv.setXY(i, x / tile, y / tile);
  }
  uv.needsUpdate = true;
}

// Plain, opaque, untextured, non-glowing materials with the same finish are
// collapsed into ONE vertex-coloured material per finish: dozens of paints,
// woods and metals become a handful of draw calls. Seasonal and glowing
// materials keep their own (they change at runtime).
const KEEP_OWN = new Set(['grass', 'bloom', 'window', 'snow', 'bush']);
const _plain = new Map();
function plainFinish(m) {
  if (!m.isMeshStandardMaterial || m.map || m.transparent || m.vertexColors || KEEP_OWN.has(m.name)) return null;
  if (m.isMeshPhysicalMaterial) return null; // a delivered model's clearcoat or transmission stays its own
  if (m.emissive && m.emissive.getHex() !== 0) return null;
  if (m.onBeforeCompile !== THREE.Material.prototype.onBeforeCompile) return null;
  const key = `plain|${m.metalness.toFixed(2)}|${m.roughness.toFixed(2)}|${m.side}`;
  if (!_plain.has(key)) {
    const pm = new THREE.MeshStandardMaterial({ color: 0xffffff, vertexColors: true, metalness: m.metalness, roughness: m.roughness, side: m.side });
    pm.name = 'plain'; _plain.set(key, pm);
  }
  return _plain.get(key);
}
/**
 * Repaint every signboard under `root` from `text(kind, i)`; a board whose
 * text is unchanged (or null) is left alone. Works on the baked .glb too:
 * the loader turns a two-material board into a group of primitives, and
 * any textured primitive is the painted face.
 */
export function relabelSigns(root, text) {
  root.traverse((o) => {
    const m = /^signboard_(\w+?)_(\d+)$/.exec(o.name);
    if (!m) return;
    const t = text(m[1], +m[2]);
    if (t == null || t === o.userData.signShown) return;
    o.userData.signShown = t;
    const tex = signTexture(t);
    o.traverse((c) => {
      if (!c.isMesh) return;
      const mats = Array.isArray(c.material) ? c.material : [c.material];
      const next = mats.map((mt) => {
        if (!mt.map) return mt;
        if (mt.userData.signOwn) { mt.map.dispose(); mt.map = tex; mt.needsUpdate = true; return mt; }
        const own = mt.clone(); own.userData.signOwn = true; own.map = tex; return own;
      });
      c.material = Array.isArray(c.material) ? next : next[0];
    });
  });
}

export function mergeStatic(root) {
  root.updateMatrixWorld(true);
  const inv = new THREE.Matrix4().copy(root.matrixWorld).invert();
  const buckets = new Map();
  const victims = [];
  root.traverse((o) => {
    if (!o.isMesh || Array.isArray(o.material) || !o.visible || o.material === M.snow) return;
    for (let p = o; p && p !== root; p = p.parent) if (p.name === 'spin' || p.userData.noMerge) return;
    const g = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry.clone();
    const plain = plainFinish(o.material);
    // Keep vertex colours for materials that use them (the leafy bushes'
    // baked shading); without them such a material renders black.
    const keep = o.material.vertexColors ? ['position', 'normal', 'uv', 'color'] : ['position', 'normal', 'uv'];
    for (const k of Object.keys(g.attributes)) if (!keep.includes(k)) g.deleteAttribute(k);
    if (!g.attributes.uv) g.setAttribute('uv', new THREE.Float32BufferAttribute(new Float32Array(g.attributes.position.count * 2), 2));
    if (o.material.vertexColors && !g.attributes.color) g.setAttribute('color', new THREE.Float32BufferAttribute(new Float32Array(g.attributes.position.count * 3).fill(1), 3));
    if (plain) { // bake the material's colour into the vertices
      // 8-bit RGBA (normalised): a quarter of the bytes of float RGB in the .glb.
      const c = o.material.color, n = g.attributes.position.count, arr = new Uint8Array(n * 4);
      const r = Math.round(c.r * 255), gg = Math.round(c.g * 255), bb = Math.round(c.b * 255);
      for (let i = 0; i < n; i++) { arr[i * 4] = r; arr[i * 4 + 1] = gg; arr[i * 4 + 2] = bb; arr[i * 4 + 3] = 255; }
      g.setAttribute('color', new THREE.BufferAttribute(arr, 4, true));
    }
    g.applyMatrix4(new THREE.Matrix4().multiplyMatrices(inv, o.matrixWorld));
    if (o.material.userData.planarUV) planarUV(g, o.material.userData.planarUV);
    const mat = plain || o.material;
    const key = mat.uuid + (o.castShadow ? 'c' : 'n');
    if (!buckets.has(key)) buckets.set(key, { mat, cast: o.castShadow, geos: [] });
    buckets.get(key).geos.push(g);
    victims.push(o);
  });
  for (const o of victims) o.parent.remove(o);
  for (const { mat, cast, geos } of buckets.values()) {
    let merged = mergeGeometries(geos, false);
    if (!merged) continue;
    merged = mergeVertices(merged); // shared vertices: smaller files, less memory
    const m = new THREE.Mesh(merged, mat);
    m.castShadow = cast; m.receiveShadow = true;
    root.add(m);
  }
}

// ---------- building recipes ----------
function facade(g, { w, h, d, snow }) {
  const body = mesh(new THREE.BoxGeometry(w, h, d), M.stone); body.position.y = h / 2; g.add(body);
  const base = mesh(new THREE.BoxGeometry(w + 0.12, 0.35, d + 0.12), M.stoneShade); base.position.y = 0.17; g.add(base);
  const cornice = mesh(new THREE.BoxGeometry(w + 0.16, 0.12, d + 0.16), M.gold); cornice.position.y = h; g.add(cornice);
  // Corner pilasters.
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    const p = mesh(new THREE.BoxGeometry(0.22, h, 0.22), M.stoneShade); p.position.set(sx * w / 2, h / 2, sz * d / 2); g.add(p);
  }
  return body;
}

function addWindows(g, xs, y, z, w = 0.42, h = 0.7) {
  for (const x of xs) { const win = windowPane(w, h); win.position.set(x, y, z); g.add(win); }
}

function addBanners(g, xs, y, z) {
  for (const x of xs) { const b = banner(); b.position.set(x, y, z + 0.02); g.add(b); }
}

// ---------- subject heroes ----------
// Each building carries one big silhouette you can read from the overview
// without its label (Hafid, 2026-11-09), plus props from its design art.
// Props use a small set of cheerful paint colours, like the design's books;
// the buildings themselves stay blue and gold.
const PAINT = {};
for (const [k, c] of Object.entries({ red: 0xe8574f, yellow: 0xf6c445, green: 0x4fbf73, blue: 0x3f7fe6, purple: 0x9b72e8, orange: 0xf39a3d, white: 0xfdfbf6, navy: 0x1f3c88 })) {
  PAINT[k] = std(c, { roughness: 0.55 }); PAINT[k].name = 'paint_' + k;
}
const COPPER = std(0x5fb59a, { roughness: 0.6, map: slateTexture() }); COPPER.name = 'copper';
COPPER.userData.planarUV = 1.3;

function letterTexture(ch, bg) {
  const c = document.createElement('canvas'); c.width = c.height = 128;
  const x = c.getContext('2d');
  x.fillStyle = bg; x.fillRect(0, 0, 128, 128);
  x.strokeStyle = 'rgba(255,255,255,0.65)'; x.lineWidth = 8; x.strokeRect(6, 6, 116, 116);
  x.fillStyle = '#ffffff'; x.font = '800 92px "Baloo 2", Georgia, sans-serif'; x.textAlign = 'center'; x.textBaseline = 'middle';
  x.fillText(ch, 64, 70);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
function letterBlock(ch, color, size = 0.5) {
  const m = std(0xffffff, { map: letterTexture(ch, color), roughness: 0.6 });
  return mesh(new THREE.BoxGeometry(size, size, size), m);
}
/** A big gold π: top bar with curled ends, a slanted left leg, a right leg with a foot. */
function bigPi(h = 1.5) {
  const g = new THREE.Group();
  const t = h * 0.17, d = t * 1.4;
  const bar = mesh(new THREE.BoxGeometry(h * 0.98, t, d), M.gold); bar.position.y = h - t / 2;
  const curlL = mesh(new THREE.SphereGeometry(t * 0.62, 12, 8), M.gold); curlL.position.set(-h * 0.49, h - t * 0.75, 0);
  const l1 = mesh(new THREE.BoxGeometry(t, h * 0.95, d), M.gold); l1.position.set(-h * 0.2, h * 0.5, 0); l1.rotation.z = -0.08;
  const l2 = mesh(new THREE.BoxGeometry(t, h * 0.82, d), M.gold); l2.position.set(h * 0.22, h * 0.56, 0);
  const foot = mesh(new THREE.BoxGeometry(t * 1.8, t * 0.8, d), M.gold); foot.position.set(h * 0.3, h * 0.17, 0); foot.rotation.z = 0.5;
  g.add(bar, curlL, l1, l2, foot);
  return g;
}
function setSquare(size = 1.4, mat = PAINT.yellow) {
  const s = new THREE.Shape(); s.moveTo(0, 0); s.lineTo(size, 0); s.lineTo(0, size * 0.75); s.closePath();
  const hole = new THREE.Path(); const k = 0.22 * size; hole.moveTo(k, k * 0.6); hole.lineTo(size - k * 2.4, k * 0.6); hole.lineTo(k, size * 0.75 - k * 1.8); hole.closePath();
  s.holes.push(hole);
  return mesh(new THREE.ExtrudeGeometry(s, { depth: 0.07, bevelEnabled: true, bevelSize: 0.015, bevelThickness: 0.015, bevelSegments: 1 }), mat);
}
function dividers(len = 1.5) {
  const g = new THREE.Group();
  for (const sgn of [-1, 1]) {
    const leg = mesh(new THREE.CylinderGeometry(0.035, 0.02, len, 8).translate(0, -len / 2, 0), std(0xc9d2e3, { metalness: 0.7, roughness: 0.3 }));
    leg.rotation.z = sgn * 0.28; g.add(leg);
  }
  const hinge = mesh(new THREE.SphereGeometry(0.08, 10, 8), M.gold); g.add(hinge);
  const knob = mesh(new THREE.CylinderGeometry(0.035, 0.035, 0.18, 8), M.gold); knob.position.y = 0.12; g.add(knob);
  return g;
}
function mathSolids() {
  const g = new THREE.Group();
  const cube = mesh(new THREE.BoxGeometry(0.62, 0.62, 0.62), PAINT.blue); cube.position.set(0, 0.31, 0); cube.rotation.y = 0.4;
  const pyr = mesh(new THREE.ConeGeometry(0.42, 0.62, 4), PAINT.red); pyr.position.set(0, 0.93, 0); pyr.rotation.y = 0.4 + Math.PI / 4;
  const ball = mesh(new THREE.SphereGeometry(0.27, 16, 12), PAINT.yellow); ball.position.set(0.62, 0.27, 0.22);
  const cyl = mesh(new THREE.CylinderGeometry(0.22, 0.22, 0.5, 16), PAINT.green); cyl.position.set(-0.55, 0.25, 0.25);
  const ico = mesh(new THREE.IcosahedronGeometry(0.22, 0), PAINT.purple); ico.position.set(0.5, 0.2, -0.45);
  g.add(cube, pyr, ball, cyl, ico);
  return g;
}
function abacus() {
  const g = new THREE.Group();
  const W = 1.3, H = 1.05;
  for (const sx of [-1, 1]) { const p = mesh(new THREE.BoxGeometry(0.1, H, 0.12), M.wood); p.position.set(sx * W / 2, H / 2, 0); g.add(p); }
  for (const y of [0.08, H - 0.05]) { const b = mesh(new THREE.BoxGeometry(W + 0.1, 0.1, 0.14), M.woodDark); b.position.y = y; g.add(b); }
  const rows = [PAINT.red, PAINT.yellow, PAINT.green, PAINT.blue];
  rows.forEach((mat, r) => {
    const y = 0.28 + r * 0.21;
    const rod = mesh(new THREE.CylinderGeometry(0.015, 0.015, W, 6).rotateZ(Math.PI / 2), M.iron, { cast: false }); rod.position.y = y; g.add(rod);
    const n = 5, off = (r * 2) % 4;
    for (let k = 0; k < n; k++) {
      const bead = mesh(new THREE.SphereGeometry(0.085, 12, 8), mat); bead.scale.set(0.75, 1, 1);
      bead.position.set(-W / 2 + 0.16 + (k + (k >= n - off ? 2 : 0)) * 0.15, y, 0); g.add(bead);
    }
  });
  return g;
}
function inkwell() {
  const g = new THREE.Group();
  const pot = mesh(new THREE.CylinderGeometry(0.32, 0.4, 0.42, 16), PAINT.navy); pot.position.y = 0.21;
  const rim = mesh(new THREE.TorusGeometry(0.2, 0.05, 6, 16).rotateX(Math.PI / 2), M.gold); rim.position.y = 0.44;
  const neck = mesh(new THREE.CylinderGeometry(0.2, 0.26, 0.12, 16), PAINT.navy); neck.position.y = 0.46;
  g.add(pot, neck, rim);
  return g;
}
/** Parchment map: coastline, dashed route and a red cross. */
function mapTexture() {
  const c = document.createElement('canvas'); c.width = 256; c.height = 192;
  const x = c.getContext('2d');
  x.fillStyle = '#f3e3bf'; x.fillRect(0, 0, 256, 192);
  x.fillStyle = '#8fd0f2'; x.fillRect(0, 0, 256, 192);
  x.fillStyle = '#9ccf7e';
  x.beginPath(); x.moveTo(30, 150); x.bezierCurveTo(20, 60, 90, 20, 140, 40); x.bezierCurveTo(200, 60, 240, 110, 210, 160); x.bezierCurveTo(150, 185, 70, 180, 30, 150); x.fill();
  x.fillStyle = '#c8b27a'; x.beginPath(); x.ellipse(120, 95, 30, 18, 0.4, 0, 7); x.fill();
  x.strokeStyle = '#b5482f'; x.lineWidth = 4; x.setLineDash([8, 7]);
  x.beginPath(); x.moveTo(55, 140); x.bezierCurveTo(90, 120, 110, 70, 170, 80); x.stroke(); x.setLineDash([]);
  x.lineWidth = 6; x.beginPath(); x.moveTo(162, 72); x.lineTo(178, 88); x.moveTo(178, 72); x.lineTo(162, 88); x.stroke();
  x.strokeStyle = '#8a6a35'; x.lineWidth = 6; x.strokeRect(3, 3, 250, 186);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
function mapScroll(w = 1.3) {
  const g = new THREE.Group();
  const sheet = mesh(new THREE.PlaneGeometry(w, w * 0.75), std(0xffffff, { map: mapTexture(), side: THREE.DoubleSide, roughness: 0.85 }));
  sheet.position.y = w * 0.375; g.add(sheet);
  for (const y of [0, w * 0.75]) { const r = mesh(new THREE.CylinderGeometry(0.06, 0.06, w + 0.16, 10).rotateZ(Math.PI / 2), M.paper); r.position.y = y; g.add(r);
    for (const sx of [-1, 1]) { const cap = mesh(new THREE.SphereGeometry(0.07, 8, 6), M.gold); cap.position.set(sx * (w / 2 + 0.1), y, 0); g.add(cap); } }
  for (const sx of [-1, 1]) { const leg = mesh(new THREE.CylinderGeometry(0.035, 0.04, w * 0.75 + 0.6, 6), M.woodDark); leg.position.set(sx * (w / 2 + 0.02), w * 0.375 - 0.28, -0.05); g.add(leg); }
  return g;
}
function canoe(len = 1.6) {
  const g = new THREE.Group();
  const hull = mesh(new THREE.SphereGeometry(1, 20, 10, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), std(0xc2783f, { side: THREE.DoubleSide, roughness: 0.7 }));
  hull.scale.set(len / 2, 0.28, 0.3); hull.position.y = 0.28; g.add(hull);
  const trim = mesh(new THREE.TorusGeometry(1, 0.03, 4, 32).rotateX(Math.PI / 2), M.woodDark); trim.scale.set(len / 2, 1, 0.3); trim.position.y = 0.28; g.add(trim);
  const paddle = mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.0, 6), M.wood); paddle.position.set(0.15, 0.42, 0.18); paddle.rotation.set(0.2, 0, 1.25); g.add(paddle);
  const blade = mesh(new THREE.SphereGeometry(0.1, 8, 6), M.wood); blade.scale.set(1.6, 0.25, 0.8); blade.position.set(0.62, 0.3, 0.26); g.add(blade);
  return g;
}
function speechBubble(w, h, mat, dotMat) {
  const g = new THREE.Group();
  const r = h * 0.42, s = new THREE.Shape();
  s.moveTo(-w / 2 + r, -h / 2); s.lineTo(-w * 0.1, -h / 2); s.lineTo(-w * 0.3, -h / 2 - h * 0.38); s.lineTo(w * 0.08, -h / 2);
  s.lineTo(w / 2 - r, -h / 2); s.quadraticCurveTo(w / 2, -h / 2, w / 2, -h / 2 + r); s.lineTo(w / 2, h / 2 - r);
  s.quadraticCurveTo(w / 2, h / 2, w / 2 - r, h / 2); s.lineTo(-w / 2 + r, h / 2); s.quadraticCurveTo(-w / 2, h / 2, -w / 2, h / 2 - r);
  s.lineTo(-w / 2, -h / 2 + r); s.quadraticCurveTo(-w / 2, -h / 2, -w / 2 + r, -h / 2);
  const b = mesh(new THREE.ExtrudeGeometry(s, { depth: 0.16, bevelEnabled: true, bevelSize: 0.05, bevelThickness: 0.05, bevelSegments: 3, curveSegments: 10 }), mat);
  b.position.z = -0.08; g.add(b);
  for (let k = -1; k <= 1; k++) { const d = mesh(new THREE.SphereGeometry(h * 0.1, 12, 8), dotMat); d.position.set(k * w * 0.22, 0, 0.14); d.scale.z = 0.5; g.add(d); }
  return g;
}
function bigAtom(r = 0.9) {
  // A packed nucleus (red protons, blue neutrons, a warm inner glow) and three
  // tilted circular orbits whose electrons really travel round: each orbit's
  // inner group is a spinner (spinSpeed in userData, kept by glTF as extras).
  const g = new THREE.Group();
  const glowCore = new THREE.MeshStandardMaterial({ color: 0xffe6a8, emissive: 0xffc35a, emissiveIntensity: 0.9, roughness: 0.4 }); glowCore.name = 'paint_nucleusglow';
  const core = mesh(new THREE.SphereGeometry(r * 0.16, 16, 12), glowCore); g.add(core);
  const N = 13;
  for (let i = 0; i < N; i++) {
    const y = 1 - (i + 0.5) * 2 / N, rr = Math.sqrt(1 - y * y), a = i * 2.39996;
    const p = mesh(new THREE.SphereGeometry(r * 0.105, 14, 10), i % 2 ? PAINT.blue : PAINT.red);
    p.position.set(Math.cos(a) * rr * r * 0.17, y * r * 0.17, Math.sin(a) * rr * r * 0.17); g.add(p);
  }
  const elec = new THREE.MeshStandardMaterial({ color: 0xbfeaff, emissive: 0x4fb8ff, emissiveIntensity: 0.9, roughness: 0.25 }); elec.name = 'paint_electron';
  const halo = new THREE.MeshStandardMaterial({ color: 0x9fd8ff, emissive: 0x4fa8ff, emissiveIntensity: 0.6, transparent: true, opacity: 0.28, depthWrite: false }); halo.name = 'paint_electronhalo';
  const tilts = [[0.35, 0, 0], [0.35, 2.09, 1.15], [0.35, 4.19, -1.15]];
  tilts.forEach(([tx, ty, tz], k) => {
    const tilt = new THREE.Group(); tilt.rotation.set(tx + (k ? 1.05 : 0), ty, tz);
    const ring = mesh(new THREE.TorusGeometry(r, 0.028, 8, 72).rotateX(Math.PI / 2), M.goldBright); tilt.add(ring);
    const run = new THREE.Group(); run.name = 'spin'; run.userData.spinSpeed = 1.6 + k * 0.45; run.rotation.y = k * 2.1;
    const e = mesh(new THREE.SphereGeometry(r * 0.075, 14, 10), elec); e.position.x = r; run.add(e);
    const eh = mesh(new THREE.SphereGeometry(r * 0.13, 14, 10), halo, { cast: false }); eh.position.x = r; run.add(eh);
    tilt.add(run); g.add(tilt);
  });
  return g;
}
function paintPalette(size = 1.6) {
  const g = new THREE.Group();
  const s = new THREE.Shape();
  s.absellipse(0, 0, size * 0.5, size * 0.36, 0, Math.PI * 2, false, 0);
  const hole = new THREE.Path(); hole.absellipse(-size * 0.22, -size * 0.12, size * 0.07, size * 0.06, 0, Math.PI * 2, false, 0); s.holes.push(hole);
  const pal = mesh(new THREE.ExtrudeGeometry(s, { depth: 0.07, bevelEnabled: true, bevelSize: 0.03, bevelThickness: 0.02, bevelSegments: 2, curveSegments: 24 }), std(0xd9a066, { roughness: 0.6 }));
  g.add(pal);
  const blobs = [PAINT.red, PAINT.yellow, PAINT.green, PAINT.blue, PAINT.purple, PAINT.white];
  blobs.forEach((m, i) => {
    const a = 0.5 + i * 0.62;
    const d = mesh(new THREE.SphereGeometry(size * 0.075, 12, 8), m); d.scale.z = 0.45;
    d.position.set(Math.cos(a) * size * 0.32, Math.sin(a) * size * 0.22, 0.09); g.add(d);
  });
  const brush = new THREE.Group();
  const handle = mesh(new THREE.CylinderGeometry(0.035, 0.05, size * 0.9, 8), PAINT.red); brush.add(handle);
  const ferrule = mesh(new THREE.CylinderGeometry(0.05, 0.05, 0.12, 8), M.gold); ferrule.position.y = size * 0.45 + 0.06; brush.add(ferrule);
  const tip = mesh(new THREE.ConeGeometry(0.06, 0.2, 8), PAINT.blue); tip.position.y = size * 0.45 + 0.22; brush.add(tip);
  brush.position.set(size * 0.12, 0.05, 0.16); brush.rotation.z = -0.9; g.add(brush);
  return g;
}

// Français: the house IS a book. A big book opened and laid face-down over
// the house, so its covers are the roof slopes, its spine the ridge, and the
// fanned page edges fill the front gable; a red ribbon bookmark hangs from the
// spine. Beside it, a tower built of giant books.
function pageEdgeTexture() {
  const c = document.createElement('canvas'); c.width = 256; c.height = 128;
  const x = c.getContext('2d');
  x.fillStyle = '#fbf3e0'; x.fillRect(0, 0, 256, 128);
  for (let k = 1; k < 18; k++) {
    const s = k * 7;
    x.strokeStyle = k % 4 === 0 ? 'rgba(170,140,95,0.55)' : 'rgba(190,165,120,0.35)'; x.lineWidth = k % 4 === 0 ? 2 : 1.2;
    x.beginPath(); x.moveTo(s, 128); x.lineTo(128, s); x.lineTo(256 - s, 128); x.stroke();
  }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
const BOOK_COVER = std(0x2346a8, { roughness: 0.6 }); BOOK_COVER.name = 'paint_bookcover';
function bookRoof(w, d, rise, snowList) {
  const g = new THREE.Group();
  const W = w / 2 + 0.25, D = d + 0.5;
  // Page block: a triangular prism under the covers, page lines on its ends.
  const tri = new THREE.Shape(); tri.moveTo(-W, 0); tri.lineTo(W, 0); tri.lineTo(0, rise - 0.1); tri.closePath();
  const pg = new THREE.ExtrudeGeometry(tri, { depth: D - 0.2, bevelEnabled: false });
  { const uv = pg.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, (uv.getX(i) + W) / (2 * W), uv.getY(i) / (rise - 0.1)); }
  pg.translate(0, 0, -(D - 0.2) / 2);
  const pages = mesh(pg, std(0xffffff, { map: pageEdgeTexture(), roughness: 0.85 })); pages.material.name = 'paint_pages'; g.add(pages);
  // Covers (roof slopes) hinged at the spine.
  const run = W + 0.18, ang = Math.atan2(rise, run), Ls = Math.hypot(run, rise) + 0.08;
  for (const side of [-1, 1]) {
    const cv = new THREE.Group();
    const slab = mesh(new THREE.BoxGeometry(Ls, 0.13, D), BOOK_COVER); slab.position.x = side * Ls / 2; cv.add(slab);
    for (const ez of [-1, 1]) {
      const band = mesh(new THREE.BoxGeometry(Ls * 0.96, 0.14, 0.09), M.gold); band.position.set(side * Ls * 0.5, 0.01, ez * (D / 2 - 0.22)); cv.add(band);
      const corner = mesh(new THREE.BoxGeometry(0.34, 0.15, 0.34), M.gold); corner.position.set(side * (Ls - 0.17), 0.005, ez * (D / 2 - 0.17)); cv.add(corner);
    }
    const fl = goldFleur(0.7); fl.rotation.x = -Math.PI / 2; fl.position.set(side * Ls * 0.55, 0.09, 0); cv.add(fl);
    const sn = mesh(new THREE.BoxGeometry(Ls * 0.95, 0.06, D * 0.96), M.snow); sn.position.set(side * Ls / 2, 0.1, 0); sn.visible = false; sn.name = 'snow'; snowList.push(sn); cv.add(sn);
    cv.rotation.z = side * -ang; cv.position.y = rise + 0.02;
    g.add(cv);
  }
  // Spine along the ridge, with gold bands.
  const spine = mesh(new THREE.CylinderGeometry(0.16, 0.16, D, 16).rotateX(Math.PI / 2), BOOK_COVER); spine.position.y = rise + 0.06; g.add(spine);
  for (const ez of [-1, 1]) { const r = mesh(new THREE.TorusGeometry(0.165, 0.03, 6, 16), M.gold); r.position.set(0, rise + 0.06, ez * (D / 2 - 0.22)); g.add(r); }
  // Ribbon bookmark hanging over the front pages.
  const rib = mesh(new THREE.BoxGeometry(0.18, rise * 0.95, 0.025).translate(0, -rise * 0.475, 0), PAINT.red); rib.position.set(0.35, rise + 0.02, D / 2 - 0.08); rib.rotation.z = 0.12; g.add(rib);
  const tip = mesh(new THREE.ConeGeometry(0.13, 0.22, 3).rotateZ(Math.PI), PAINT.red); tip.position.set(0.35 + Math.sin(0.12) * rise * 0.95, rise + 0.02 - rise * 0.95 - 0.06, D / 2 - 0.08); g.add(tip);
  return g;
}
function bookTower(snowList) {
  const g = new THREE.Group();
  const base = mesh(new THREE.CylinderGeometry(0.62, 0.68, 0.4, 16), M.stoneShade); base.position.y = 0.2; g.add(base);
  const cols = [PAINT.red, PAINT.blue, PAINT.green, PAINT.yellow, PAINT.purple];
  let y = 0.4;
  cols.forEach((m, i) => {
    const bw = 1.35 - i * 0.08, bt = 0.42, bd = 1.0 - i * 0.05;
    const bk = new THREE.Group(); bk.position.y = y + bt / 2; bk.rotation.y = [0.2, -0.25, 0.4, -0.1, 0.3][i];
    const cover = mesh(new THREE.BoxGeometry(bw, bt, bd), m); bk.add(cover);
    const pages = mesh(new THREE.BoxGeometry(bw - 0.1, bt - 0.1, 0.06), M.paper); pages.position.z = bd / 2 + 0.005; bk.add(pages);
    const band = mesh(new THREE.BoxGeometry(0.08, bt + 0.01, bd + 0.01), M.gold); band.position.x = -bw / 2 + 0.18; bk.add(band);
    g.add(bk); y += bt;
  });
  const roof = mesh(new THREE.ConeGeometry(0.72, 1.0, 10), M.slate); roof.position.y = y + 0.5; g.add(roof);
  const fin = mesh(new THREE.SphereGeometry(0.11, 10, 8), M.gold); fin.position.y = y + 1.05; g.add(fin);
  const sn = mesh(new THREE.ConeGeometry(0.45, 0.6, 10), M.snow); sn.position.y = y + 0.72; sn.scale.setScalar(1.04); sn.visible = false; sn.name = 'snow'; snowList.push(sn); g.add(sn);
  const f = flagPole(1.4); f.position.y = y + 1.05; g.add(f);
  return g;
}

// Mathématique: the entrance is a π. Its legs are the portico's columns and
// its bar, curled at one end, is the lintel over the door.
function piPortico(span = 1.9, hgt = 2.4) {
  const g = new THREE.Group();
  const col = (x, h, tilt) => {
    const c = mesh(new THREE.BoxGeometry(0.34, h, 0.42), BOOK_COVER); c.position.set(x, h / 2, 0); c.rotation.z = tilt; g.add(c);
    const cap = mesh(new THREE.BoxGeometry(0.44, 0.08, 0.5), M.gold); cap.position.set(x + Math.sin(-tilt) * h * 0.02, h - 0.02, 0); g.add(cap);
  };
  col(-span / 2, hgt, -0.05);                          // left leg, a little slanted
  col(span / 2, hgt * 0.94, 0);                        // right leg
  const foot = mesh(new THREE.BoxGeometry(0.5, 0.2, 0.44), BOOK_COVER); foot.position.set(span / 2 + 0.2, 0.12, 0); foot.rotation.z = 0.35; g.add(foot);
  const bar = mesh(new THREE.BoxGeometry(span + 1.0, 0.36, 0.52), BOOK_COVER); bar.position.set(0.05, hgt + 0.18, 0); g.add(bar);
  const curl = mesh(new THREE.CylinderGeometry(0.24, 0.24, 0.52, 18).rotateX(Math.PI / 2), BOOK_COVER); curl.position.set(-span / 2 - 0.5, hgt + 0.06, 0); g.add(curl);
  for (const y of [hgt + 0.01, hgt + 0.36]) { const t = mesh(new THREE.BoxGeometry(span + 1.0, 0.05, 0.56), M.gold); t.position.set(0.05, y, 0); g.add(t); }
  const pm = emblem('pi', 0.3); pm.position.set(0.05, hgt + 0.18, 0.27); g.add(pm);
  return g;
}
// Anglais: towers built of alphabet blocks, a speech-bubble shop sign hanging
// from a wrought-iron bracket, and a red telephone box by the door.
function blockTower(letters, colors, snowList, size = 0.78) {
  const g = new THREE.Group();
  let y = 0;
  letters.forEach((ch, i) => {
    const b = letterBlock(ch, colors[i], size); b.position.y = y + size / 2; b.rotation.y = [0.12, -0.18, 0.08][i % 3]; g.add(b); y += size;
  });
  const roof = mesh(new THREE.ConeGeometry(size * 0.8, size * 1.05, 4).rotateY(Math.PI / 4), M.slate); roof.position.y = y + size * 0.52; g.add(roof);
  const fin = mesh(new THREE.SphereGeometry(0.08, 10, 8), M.gold); fin.position.y = y + size * 1.08; g.add(fin);
  const sn = mesh(new THREE.ConeGeometry(size * 0.5, size * 0.6, 4).rotateY(Math.PI / 4), M.snow); sn.position.y = y + size * 0.78; sn.visible = false; sn.name = 'snow'; snowList.push(sn); g.add(sn);
  return g;
}
function phoneBox() {
  const g = new THREE.Group();
  const c = document.createElement('canvas'); c.width = 128; c.height = 256;
  const x = c.getContext('2d');
  x.fillStyle = '#d93a32'; x.fillRect(0, 0, 128, 256);
  x.fillStyle = '#cfe7f7';
  for (let r = 0; r < 6; r++) for (let k = 0; k < 3; k++) x.fillRect(18 + k * 32, 40 + r * 30, 26, 24);
  x.fillStyle = '#1b1b1b'; x.fillRect(10, 8, 108, 22);
  x.fillStyle = '#ffffff'; x.font = '700 15px sans-serif'; x.textAlign = 'center'; x.fillText('TELEPHONE', 64, 25);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  const side = std(0xffffff, { map: t, roughness: 0.5 }); side.name = 'paint_phonebox';
  const body = mesh(new THREE.BoxGeometry(0.62, 1.55, 0.62), [side, side, PAINT.red, PAINT.red, side, side]); body.position.y = 0.95; g.add(body);
  const plinthB = mesh(new THREE.BoxGeometry(0.72, 0.16, 0.72), PAINT.red); plinthB.position.y = 0.08; g.add(plinthB);
  const crown = mesh(new THREE.CylinderGeometry(0.36, 0.36, 0.62, 16, 1, false, 0, Math.PI).rotateZ(Math.PI / 2).rotateY(Math.PI / 2), PAINT.red); crown.scale.set(1, 0.4, 1); crown.position.y = 1.73; g.add(crown);
  const capB = mesh(new THREE.BoxGeometry(0.7, 0.08, 0.7), PAINT.red); capB.position.y = 1.74; g.add(capB);
  return g;
}
function bubbleSign() {
  // Bracket reaches sideways (+x) from the tower; the bubble hangs facing the village.
  const g = new THREE.Group();
  const arm = mesh(new THREE.BoxGeometry(1.25, 0.06, 0.06), M.iron); arm.position.set(0.62, 0, 0); g.add(arm);
  const brace = mesh(new THREE.BoxGeometry(0.8, 0.05, 0.05), M.iron); brace.position.set(0.3, -0.28, 0); brace.rotation.z = 0.62; g.add(brace);
  const scroll = mesh(new THREE.TorusGeometry(0.12, 0.025, 6, 16, Math.PI * 1.5), M.iron); scroll.position.set(0.22, -0.15, 0); g.add(scroll);
  for (const x of [0.45, 1.05]) { const ch = mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.22, 4), M.gold); ch.position.set(x, -0.11, 0); g.add(ch); }
  const b = speechBubble(1.15, 0.72, PAINT.white, PAINT.navy); b.position.set(0.75, -0.6, 0); g.add(b);
  return g;
}

// Science: an observatory refractor. White tube with gold bands, a navy dew
// shield, a glowing objective with a star glint, a finder scope and an eyepiece.
function observatoryScope(len = 2.5) {
  const g = new THREE.Group();
  const tube = mesh(new THREE.CylinderGeometry(0.27, 0.22, len, 24).rotateZ(-Math.PI / 2), PAINT.white); g.add(tube);
  for (const x of [-len * 0.38, 0, len * 0.3]) { const b = mesh(new THREE.TorusGeometry(0.255, 0.035, 8, 24).rotateY(Math.PI / 2), M.gold); b.position.x = x; g.add(b); }
  const dew = mesh(new THREE.CylinderGeometry(0.33, 0.3, 0.5, 24, 1, true).rotateZ(-Math.PI / 2), std(0x1f3c88, { side: THREE.DoubleSide, roughness: 0.5 })); dew.position.x = len / 2 + 0.22; g.add(dew);
  const lip = mesh(new THREE.TorusGeometry(0.33, 0.035, 8, 24).rotateY(Math.PI / 2), M.gold); lip.position.x = len / 2 + 0.47; g.add(lip);
  const glass = new THREE.MeshStandardMaterial({ color: 0x0b1d4a, emissive: 0x2f6fed, emissiveIntensity: 0.65, roughness: 0.1, metalness: 0.2 }); glass.name = 'paint_lens';
  const lens = mesh(new THREE.CircleGeometry(0.29, 24).rotateY(Math.PI / 2), glass, { cast: false }); lens.position.x = len / 2 + 0.2; g.add(lens);
  const glint = std(0xffffff); glint.emissive = new THREE.Color(0xffffff); glint.emissiveIntensity = 0.8; glint.name = 'paint_glint';
  for (const rz of [0, Math.PI / 2]) { const st = mesh(new THREE.BoxGeometry(0.005, 0.2, 0.025), glint, { cast: false }); st.position.set(len / 2 + 0.21, 0.08, -0.08); st.rotation.x = rz; g.add(st); }
  const finder = mesh(new THREE.CylinderGeometry(0.06, 0.05, 0.7, 12).rotateZ(-Math.PI / 2), BOOK_COVER); finder.position.set(len * 0.12, 0.38, 0); g.add(finder);
  for (const x of [-0.15, 0.4]) { const m = mesh(new THREE.BoxGeometry(0.05, 0.14, 0.05), M.gold); m.position.set(len * 0.12 + x, 0.3, 0); g.add(m); }
  const focuser = mesh(new THREE.CylinderGeometry(0.11, 0.13, 0.35, 16).rotateZ(-Math.PI / 2), M.gold); focuser.position.x = -len / 2 - 0.15; g.add(focuser);
  const eye = mesh(new THREE.CylinderGeometry(0.06, 0.08, 0.3, 12), PAINT.navy); eye.position.set(-len / 2 - 0.22, 0.17, 0); eye.rotation.z = 0.5; g.add(eye);
  for (const sz of [-1, 1]) { const knob = mesh(new THREE.CylinderGeometry(0.05, 0.05, 0.08, 10).rotateX(Math.PI / 2), M.gold); knob.position.set(-len / 2 - 0.1, -0.05, sz * 0.16); g.add(knob); }
  return g;
}
/** The dome's observing slit: a recessed dark band from the rim to near the top, edged in gold. */
function domeSlit(radius, phiCenter, width = 0.3) {
  const g = new THREE.Group();
  const dark = std(0x0b1d4a, { roughness: 0.6, side: THREE.DoubleSide }); dark.name = 'paint_slit';
  const band = mesh(new THREE.SphereGeometry(radius * 1.004, 8, 20, phiCenter - width / 2, width, 0.08, Math.PI / 2 - 0.08), dark, { cast: false }); g.add(band);
  for (const e of [-1, 1]) {
    const rail = mesh(new THREE.SphereGeometry(radius * 1.012, 2, 20, phiCenter + e * width / 2 - 0.02, 0.04, 0.06, Math.PI / 2 - 0.06), M.gold, { cast: false }); g.add(rail);
  }
  return g;
}

const RECIPES = {
  math(g, snow) {
    const w = 3.6, h = 2.5, d = 2.6;
    facade(g, { w, h, d, snow });
    const roof = hipRoof(w, d, 1.5, snow); roof.position.y = h; g.add(roof);
    const ch = chimney(1.1); ch.position.set(0.9, h + 0.2, -0.6); g.add(ch);
    const dr = door(); dr.position.set(0, 0.35, d / 2 + 0.01); g.add(dr);
    addWindows(g, [-1.15, 1.15], 1.0, d / 2 + 0.01);
    // Hero: the entrance is a big π portico (its legs are the columns).
    const por = piPortico(1.95, 2.35); por.position.set(0, 0, d / 2 + 0.6); g.add(por);
    // Towers crowned with solids: a pyramid roof under the armillary, a gold dodecahedron.
    const tl = tower(0.62, 3.3, 1.3, snow, { roofMat: M.slate }); tl.position.set(-w / 2 - 0.15, 0, -0.4); g.add(tl);
    tl.children.find((o) => o.geometry?.type === 'ConeGeometry' && !o.name).geometry = new THREE.ConeGeometry(0.62 * 1.35, 1.3, 4).rotateY(Math.PI / 4);
    const arm = armillary(0.42); arm.position.set(-w / 2 - 0.15, 3.3 + 1.3 + 0.55, -0.4); arm.name = 'spin'; g.add(arm);
    const tr = tower(0.5, 2.7, 0.01, snow); tr.position.set(w / 2 + 0.1, 0, -0.5); g.add(tr);
    const gem = mesh(new THREE.DodecahedronGeometry(0.5, 0), M.goldBright); gem.position.set(w / 2 + 0.1, 2.7 + 0.5, -0.5); gem.rotation.set(0.3, 0.4, 0); g.add(gem);
    // Tools and shapes: set-square, dividers, a pile of solids, a bead abacus.
    const sq = setSquare(1.25); sq.position.set(w / 2 + 0.25, 0.2, 1.15); sq.rotation.y = -0.55; g.add(sq);
    const dv = dividers(1.35); dv.position.set(w / 2 + 0.95, 1.55, 0.25); dv.rotation.y = -0.4; g.add(dv);
    const solids = mathSolids(); solids.position.set(-2.35, 0.2, 1.35); g.add(solids);
    const ab = abacus(); ab.position.set(2.3, 0.2, 2.15); ab.rotation.y = -0.45; g.add(ab);
    return { h: h + 2.6 };
  },
  francais(g, snow) {
    const w = 3.4, h = 2.4, d = 2.5;
    facade(g, { w, h, d, snow });
    // Hero: the roof is a giant book laid open over the house.
    const roof = bookRoof(w, d, 1.55, snow); roof.position.y = h; g.add(roof);
    const dr = door(1.0, 1.55); dr.position.set(0, 0.35, d / 2 + 0.01); g.add(dr);
    addWindows(g, [-1.15, 1.15], 1.0, d / 2 + 0.01);
    addBanners(g, [-0.75, 0.75], 1.6, d / 2);
    const tl = bookTower(snow); tl.position.set(-w / 2 - 0.25, 0, -0.45); g.add(tl);
    // A big quill dipped in an inkwell, and a tall stack of books.
    const ink = inkwell(); ink.position.set(2.15, 0.2, 1.65); g.add(ink);
    const q = quill(); q.scale.setScalar(1.6); q.position.set(2.3, 2.2, 1.6); q.rotation.z = -0.32; g.add(q);
    const sp = signpost(['Lire', 'Écrire', 'Créer'], 1, 'francais'); sp.position.set(-2.25, 0.2, 1.75); sp.rotation.y = 0.5; g.add(sp);
    const books = bookStack(5); books.position.set(-1.45, 0.2, 2.15); g.add(books);
    return { h: h + 2.4 };
  },
  social(g, snow) {
    const w = 3.8, h = 2.4, d = 2.6;
    facade(g, { w, h, d, snow });
    const roof = hipRoof(w, d, 1.0, snow); roof.position.y = h; g.add(roof);
    const dm = dome(0.95, snow); dm.position.set(0, h + 0.6, 0); g.add(dm);
    // Hero: a big spinning globe on the dome.
    const gl = globe(0.76); gl.position.set(0, h + 2.8, 0); g.add(gl); // sized to the building (Hafid: 0.98 was too big)
    const dr = door(); dr.position.set(0, 0.35, d / 2 + 0.01); g.add(dr);
    addWindows(g, [-1.3, 1.3], 1.0, d / 2 + 0.01);
    addBanners(g, [-0.7, 0.7], 1.55, d / 2);
    const em = emblem('compass', 0.55); em.position.set(0, 2.05, d / 2 + 0.02); g.add(em);
    const fp = flagPole(1.6); fp.position.set(w / 2 - 0.2, h + 0.2, -0.6); g.add(fp);
    // A fallen column and a scroll.
    const col = mesh(new THREE.CylinderGeometry(0.22, 0.22, 1.2, 10), M.stone); col.position.set(2.2, 0.75, 1.5); g.add(col);
    const cap = mesh(new THREE.BoxGeometry(0.6, 0.15, 0.6), M.stone); cap.position.set(2.2, 1.4, 1.5); g.add(cap);
    // An unrolled map on a stand, and a canoe (Québec's first roads were rivers).
    const map = mapScroll(1.35); map.position.set(-2.2, 0.75, 1.55); map.rotation.y = 0.45; g.add(map);
    const cn = canoe(1.8); cn.position.set(1.0, 0.2, 2.35); cn.rotation.y = -0.15; g.add(cn);
    return { h: h + 3.4 };
  },
  anglais(g, snow) {
    const w = 3.4, h = 2.3, d = 2.4;
    facade(g, { w, h, d, snow });
    const roof = hipRoof(w, d, 0.8, snow); roof.position.y = h; g.add(roof);
    const drum = mesh(new THREE.CylinderGeometry(0.85, 0.9, 0.6, 20), M.stone); drum.position.y = h + 0.5; g.add(drum);
    const dm = dome(0.85, snow); dm.position.set(0, h + 0.8, 0); g.add(dm);
    const fp = flagPole(1.1); fp.position.set(0, h + 2.0, 0); g.add(fp);
    // Hero: towers built of alphabet blocks, A-B-C and H-I-! ("HI!").
    const tL = blockTower(['C', 'B', 'A'], ['#f2b632', '#3f7fe6', '#e8574f'], snow, 0.86); tL.position.set(-w / 2 - 0.55, 0, 0.35); g.add(tL);
    const tR = blockTower(['!', 'I', 'H'], ['#4fbf73', '#9b72e8', '#f39a3d'], snow, 0.86); tR.position.set(w / 2 + 0.55, 0, 0.35); g.add(tR);
    const dr = door(0.9, 1.45); dr.position.set(0, 0.35, d / 2 + 0.01); g.add(dr);
    addWindows(g, [-1.0, 1.0], 1.0, d / 2 + 0.01, 0.38, 0.62);
    const em = emblem('abc', 0.42); em.position.set(0, 1.95, d / 2 + 0.02); g.add(em);
    // A speech-bubble shop sign on a wrought-iron bracket, and a red phone box.
    const sign = bubbleSign(); sign.position.set(w / 2 + 0.98, 2.05, 0.35); g.add(sign);
    const pb = phoneBox(); pb.position.set(-1.75, 0.2, 2.05); pb.rotation.y = 0.35; g.add(pb);
    const sp = signpost(['Hello', 'Read'], 1, 'anglais'); sp.position.set(1.85, 0.2, 2.2); sp.rotation.y = -0.5; g.add(sp);
    return { h: h + 3.0 };
  },
  science(g, snow) {
    const r = 1.6, h = 1.8;
    const drum = mesh(new THREE.CylinderGeometry(r, r * 1.05, h, 24), M.stone); drum.position.y = h / 2; g.add(drum);
    const band = mesh(new THREE.CylinderGeometry(r * 1.07, r * 1.07, 0.14, 24), M.gold); band.position.y = h; g.add(band);
    const dm = dome(r * 1.05, snow); dm.position.y = h; g.add(dm);
    // The telescope points out of a real observing slit (both face front-right).
    const slit = domeSlit(r * 1.05, 2.24); slit.position.y = h; g.add(slit);
    const tel = observatoryScope(2.5); tel.position.set(0.42, h + 1.25, 0.52); tel.rotation.set(0, -0.9, 0.55); tel.name = 'scope'; g.add(tel);
    const dr = door(0.85, 1.35); dr.position.set(0, 0.35, r - 0.02); g.add(dr);
    addWindows(g, [-0.95, 0.95], 0.95, r - 0.25, 0.36, 0.6);
    g.children.slice(-2).forEach((wn, i) => { wn.rotation.y = i ? 0.6 : -0.6; wn.position.z = r * 0.82; });
    const em = emblem('atom', 0.38); em.position.set(0, 1.55, r - 0.02); g.add(em);
    const d1 = dish(); d1.position.set(-1.9, 0.9, -0.4); g.add(d1);
    const sp = solarPanel(); sp.position.set(1.9, 0.6, -0.6); g.add(sp);
    const wm = windmill(); wm.position.set(-1.6, 0.2, 1.2); g.add(wm);
    const fl = flask(); fl.scale.setScalar(2.0); fl.position.set(1.75, 0.2, 1.55); g.add(fl);
    // Hero: a big atom spinning above the dome.
    const pole = mesh(new THREE.CylinderGeometry(0.04, 0.06, 0.9, 8), M.gold); pole.position.set(0, h + r * 1.05 + 0.45, 0); g.add(pole);
    const at = bigAtom(1.05); at.position.set(0, h + r * 1.05 + 1.4, 0); at.name = 'spin'; at.userData.spinSpeed = 0.18; g.add(at);
    const fp = flagPole(1.3); fp.position.set(-0.9, h + 0.5, -0.9); g.add(fp);
    return { h: h + 2.4 };
  },
  ccq(g, snow) {
    const w = 3.0, h = 2.2, d = 2.2;
    facade(g, { w, h, d, snow });
    // Hero: a château silhouette, copper-green roofs like Québec's old capital,
    // with a tall clock tower flying the flag.
    const roof = hipRoof(w, d, 1.3, snow, COPPER); roof.position.y = h; g.add(roof);
    const ct = tower(0.62, 4.7, 1.9, snow, { flag: true, windows: false, roofMat: COPPER }); ct.position.set(-w / 2 + 0.1, 0, -0.3); g.add(ct);
    for (const sx of [-1, 1]) { const dm = tower(0.22, 0.5, 0.55, snow, { windows: false, roofMat: COPPER }); dm.position.set(sx * 0.75 + 0.3, h + 0.15, d / 2 - 0.35); g.add(dm); }
    const cf = clockFace(); cf.position.set(-w / 2 + 0.1, 4.0, 0.33); g.add(cf);
    g.userData.clock = cf;
    // Shield with a fleur-de-lys.
    const sh = new THREE.Shape(); sh.moveTo(-0.5, 0.5); sh.lineTo(0.5, 0.5); sh.lineTo(0.5, 0); sh.quadraticCurveTo(0.45, -0.45, 0, -0.62); sh.quadraticCurveTo(-0.45, -0.45, -0.5, 0); sh.closePath();
    const shield = mesh(new THREE.ExtrudeGeometry(sh, { depth: 0.08, bevelEnabled: true, bevelSize: 0.04, bevelThickness: 0.03, bevelSegments: 2 }), M.slate);
    shield.scale.setScalar(1.3); shield.position.set(0.15, 1.95, d / 2 + 0.02); g.add(shield);
    const sf = goldFleur(0.8); sf.position.set(0.15, 1.92, d / 2 + 0.2); g.add(sf);
    const dr = door(0.85, 1.35); dr.position.set(0.15, 0.35, d / 2 + 0.01); g.add(dr);
    addWindows(g, [1.05], 1.0, d / 2 + 0.01, 0.36, 0.6);
    const st = statue(); st.scale.setScalar(1.35); st.position.set(-1.85, 0.2, 1.35); g.add(st);
    const sp = signpost(['Vivre', 'ensemble'], 1, 'ccq'); sp.position.set(1.8, 0.2, 1.5); sp.rotation.y = -0.4; g.add(sp);
    return { h: h + 3.4 };
  },
  gallery(g, snow) {
    const w = 3.0, h = 2.2, d = 2.2;
    facade(g, { w, h, d, snow });
    const roof = hipRoof(w, d, 1.05, snow); roof.position.y = h; g.add(roof);
    // Hero: a giant painter's palette with its brush, standing on the roof.
    const pal = paintPalette(1.9); pal.position.set(0, h + 1.55, 0.2); pal.rotation.x = -0.22; g.add(pal);
    const dr = door(0.85, 1.35); dr.position.set(0, 0.35, d / 2 + 0.01); g.add(dr);
    const em = emblem('frame', 0.36); em.position.set(0, 1.9, d / 2 + 0.02); g.add(em);
    // Big framed pictures on the facade.
    for (const sx of [-1, 1]) {
      const fr = mesh(new THREE.BoxGeometry(0.7, 0.6, 0.06), M.gold); fr.position.set(sx * 0.95, 1.15, d / 2 + 0.03); g.add(fr);
      const pic = mesh(new THREE.PlaneGeometry(0.56, 0.46), new THREE.MeshStandardMaterial({ map: emblemTexture('frame') }), { cast: false }); pic.position.set(sx * 0.95, 1.15, d / 2 + 0.065); g.add(pic);
    }
    const carpet = mesh(new THREE.BoxGeometry(0.7, 0.02, 1.4), std(0x2f55c9)); carpet.position.set(0, 0.22, d / 2 + 0.75); g.add(carpet);
    const e1 = easel('frame'); e1.scale.setScalar(1.6); e1.position.set(1.75, 0.2, 1.25); e1.rotation.y = -0.5; g.add(e1);
    return { h: h + 2.2 };
  },
};

/**
 * Build one subject building on its plinth. Returns the group plus the
 * handles the interaction layer animates.
 */
/** The procedural art for one building, baked to one mesh per material. */
const FLAG_KINDS = new Set(['francais', 'ccq']);
// Where each worded signpost stands on a delivered model's plot (beside the
// hall, clear of the model's own props), for models that lack one.
const SIGNS = {
  francais: { labels: ['Lire', 'Écrire', 'Créer'], at: [-2.6, 0.38, 1.15], rot: 0.5 },
  anglais: { labels: ['Hello', 'Read'], at: [2.45, 0.38, 1.45], rot: -0.5 },
  ccq: { labels: ['Vivre', 'ensemble'], at: [2.05, 0.38, 0.85], rot: -0.4 },
};

export function buildBuildingArt(spot, index) {
  const art = new THREE.Group();
  art.name = `art-${spot.kind}`;
  const snow = [];
  art.add(plinth(spot.r));
  const body = new THREE.Group();
  body.position.y = 0.18;
  RECIPES[spot.kind](body, snow);
  const st = stairs(1.5, 3); st.position.set(0, 0.18, spot.kind === 'science' ? 1.5 : (spot.kind === 'math' || spot.kind === 'social' ? 1.3 : 1.2)); body.add(st);
  art.add(body);
  art.add(shrubs(spot.r, 1000 + index * 77));
  // The Québec flag flies only over Français and Culture et citoyenneté
  // québécoise (Hafid, 2026-11-09). Drop the whole pole elsewhere, not just the
  // cloth, so no bare gold pole is left behind.
  if (!FLAG_KINDS.has(spot.kind)) {
    const poles = [];
    art.traverse((o) => { if (o.name === 'flagpole') poles.push(o); });
    for (const o of poles) o.parent.remove(o);
  }
  mergeStatic(art);
  return art;
}

/**
 * Make a loaded glTF scene into a building's art. The naming contract
 * (docs in MODELS.md): materials named like `buildingMaterials` keys share
 * the village's materials; nodes named `snow` show only in winter, `flag`
 * ripples, `spin` turns, `clock` holds `hour`/`minute` hands. A model larger
 * than its plot is scaled down to fit; its lowest point sits on the plot.
 */
// Older bakes store bushes as faceted, unindexed shapes. Weld them so they
// shade smooth, and darken their undersides like the procedural ones.
function softenBush(geo) {
  if (geo.attributes.color) return geo;
  let g = new THREE.BufferGeometry();
  g.setAttribute('position', geo.attributes.position.clone());
  if (geo.index) g.setIndex(geo.index.clone());
  g = mergeVertices(g, 1e-3);
  g.computeVertexNormals();
  return shadeVertices(g, { low: 1, high: 1, under: 0.3 });
}

export function adoptModel(model, spot) {
  const art = model;
  art.traverse((o) => {
    if (!o.isMesh) return;
    o.castShadow = true; o.receiveShadow = true;
    const name = o.material?.name;
    if (name && M[name] && name !== 'bloom') o.material = M[name];
    else if (name === 'bush') { o.material = bushMat; o.geometry = softenBush(o.geometry); }
    else if (name === 'bloom') plinthGreen.blooms.push(o.material);
    // `flag*` is the cloth; `flagpole*` is the pole (sand3d names both).
    const isFlag = /^flag(?!pole)/.test(o.name);
    if (isFlag && !FLAG_KINDS.has(spot.kind)) { o.visible = false; return; }
    if (isFlag) {
      o.geometry.computeBoundingBox();
      o.material = addFlagWave(new THREE.MeshStandardMaterial({ map: o.material.map || quebecFlagTexture(), roughness: 0.8 }), o.geometry.boundingBox.max.x || 1);
    }
  });
  // Exporters may suffix duplicate names (snow_1…), so match on the prefix.
  art.traverse((o) => { if (/^snow/.test(o.name)) o.visible = false; });
  // A room behind the door (an `interior*` node, or Science's `paint_room`
  // drum), noted before the merge below folds those nodes away.
  art.traverse((o) => { if (/^interior/i.test(o.name) || o.material?.name === 'paint_room') art.userData.hasInterior = true; });
  const box = new THREE.Box3().setFromObject(art);
  const size = box.getSize(new THREE.Vector3());
  const fit = Math.min(1, (spot.r * 2.1) / Math.max(size.x, size.z, 1e-3));
  art.scale.multiplyScalar(fit);
  art.position.y -= box.min.y * fit;
  // Delivered models arrive as dozens of small meshes; bake the static ones
  // into one per material like the procedural build. Whatever moves or
  // changes keeps its node: joints, spinners, flags, the clock, snow, signs.
  art.traverse((o) => { if (/^(drive_|spin|flag|clock|snow|signboard|door_hinge)/.test(o.name)) o.userData.noMerge = true; });
  mergeStatic(art);
  return art;
}

/**
 * A small delivered prop (bench, well, lamp post…): the village's shared
 * materials by name, shadows, winter-only `snow*`, and its `spin_*` nodes.
 */
export function adoptProp(model) {
  const snow = [], spinners = [];
  model.traverse((o) => {
    if (/^snow/.test(o.name)) { o.visible = false; snow.push(o); }
    if (/^spin/.test(o.name)) spinners.push(o);
    if (!o.isMesh) return;
    o.castShadow = true; o.receiveShadow = true;
    const name = o.material?.name;
    if (name && M[name] && name !== 'bloom') o.material = M[name];
  });
  return { root: model, snow, spinners };
}

/**
 * One subject building: its art (a glTF model when one loaded, else the
 * procedural build) plus the interaction dressing: ring, halo, light
 * column and an invisible hit volume.
 */
export function createBuilding(spot, index, model = null) {
  const root = new THREE.Group();
  root.name = `building-${spot.id}`;
  const art = model ? adoptModel(model, spot) : buildBuildingArt(spot, index);
  art.userData.source = model ? 'gltf' : 'procedural';
  // `art` lifts and scales on hover, so wrap the model's own transform.
  const holder = new THREE.Group();
  holder.add(art);
  root.add(holder);
  // The signposts carry words the host translates, which a delivered model
  // can't paint: when a model has no `signboard_*` of its own, the village
  // plants the same post the procedural build has, on the plot.
  if (model && SIGNS[spot.kind]) {
    let has = false; art.traverse((o) => { if (/^signboard_/.test(o.name)) has = true; });
    if (!has) {
      const { labels, at, rot } = SIGNS[spot.kind];
      const sp = signpost(labels, 1, spot.kind); sp.position.set(...at); sp.rotation.y = rot; sp.name = 'signpost';
      holder.add(sp);
    }
  }
  const r = spot.r;
  const snow = [];
  let clock = null;
  holder.traverse((o) => { if (/^snow/.test(o.name)) snow.push(o); if (/^clock/.test(o.name)) clock = o; });
  holder.updateMatrixWorld(true);
  const h = new THREE.Box3().setFromObject(holder).max.y;

  // Selection ring and soft halo under the building.
  const ringMat = new THREE.MeshBasicMaterial({ color: MAT.goldBright, transparent: true, opacity: 0, depthWrite: false });
  const ring = new THREE.Mesh(new THREE.TorusGeometry(r + 0.35, 0.09, 8, 72).rotateX(Math.PI / 2), ringMat);
  ring.position.y = 0.2;
  const haloMat = new THREE.MeshBasicMaterial({ map: softDotTexture(), color: MAT.goldLight || 0xfbbf24, transparent: true, opacity: 0, depthWrite: false, blending: THREE.AdditiveBlending });
  const halo = new THREE.Mesh(new THREE.PlaneGeometry((r + 1.6) * 2, (r + 1.6) * 2).rotateX(-Math.PI / 2), haloMat);
  halo.position.y = 0.22;
  // A light column that rises from a selected building.
  const beamMat = new THREE.ShaderMaterial({
    uniforms: { uOpacity: { value: 0 }, uTime: U.uTime, uColor: { value: new THREE.Color(0xfde68a) } },
    vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
    fragmentShader: `uniform float uOpacity, uTime; uniform vec3 uColor; varying vec2 vUv;
      void main(){ float f = pow(1.0 - vUv.y, 1.6) * (0.75 + 0.25 * sin(vUv.y * 18.0 - uTime * 3.0));
      gl_FragColor = vec4(uColor, f * uOpacity * 0.38); }`,
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
  });
  const beam = new THREE.Mesh(new THREE.CylinderGeometry(r * 0.75, r * 0.95, 9, 32, 1, true), beamMat);
  beam.position.y = 4.6;
  beam.renderOrder = 5;
  root.add(ring, halo, beam);

  // Invisible hit volume for robust picking.
  const hit = new THREE.Mesh(new THREE.CylinderGeometry(r, r, h + 1, 12), new THREE.MeshBasicMaterial({ visible: false }));
  hit.position.y = (h + 1) / 2;
  hit.userData.buildingId = spot.id;
  root.add(hit);

  const spinners = [];
  holder.traverse((o) => { if (/^spin/.test(o.name)) spinners.push(o); });
  // Revolute joints from the model's joints.json (sand3d): each drives an
  // identity node about its local axis within its limits. A door opens while
  // the building is hovered, selected or tapped; a scope, dish or arm sweeps
  // slowly. Other joints keep their rest value.
  const joints = [];
  // A door only opens onto a real interior: until the model carries an
  // `interior*` node, door joints stay shut (Hafid, 2026-11-10).
  const hasInterior = !!art.userData.hasInterior;
  for (const j of (model?.userData.joints || [])) {
    if (j.type !== 'revolute' || !j.drive_node) continue;
    const node = art.getObjectByName(j.drive_node);
    if (!node) continue;
    if (/door|gate|hatch/.test(j.name) && !hasInterior) continue;
    const role = /door|gate|hatch/.test(j.name) ? 'door' : /scope|dish|pan|pitch|arm|crane|vane|divider|compass/.test(j.name) ? 'sweep' : null;
    if (!role) continue;
    joints.push({ node, role, axis: new THREE.Vector3(...j.axis_local).normalize(), lower: j.lower, upper: j.upper, rest: j.value ?? 0, angle: j.value ?? 0, phase: joints.length * 1.7 });
  }

  root.position.set(spot.x, spot.y - 0.05, spot.z);
  root.scale.setScalar(spot.small ? 0.9 : 1.08);
  root.traverse((o) => { if (o.isMesh && o !== hit && o !== ring && o !== halo && o !== beam) { o.castShadow = o.castShadow !== false; o.receiveShadow = true; } });
  ring.castShadow = halo.castShadow = beam.castShadow = false;

  return {
    id: spot.id, spot, root, art: holder, model: art, ring, ringMat, haloMat, beamMat, hit, snow, spinners, joints,
    height: h * (spot.small ? 0.9 : 1.08),
    clock,
    state: { hover: 0, sel: 0, hoverT: 0, selT: 0, press: 0 },
  };
}

/** Per-frame: hover lift, selection pulse, little props that turn. */
export function updateBuilding(b, dt, t, motion) {
  const s = b.state;
  const k = motion ? 10 : 1000;
  s.hover = THREE.MathUtils.damp(s.hover, s.hoverT, k, dt);
  s.sel = THREE.MathUtils.damp(s.sel, s.selT, motion ? 6 : 1000, dt);
  s.press = THREE.MathUtils.damp(s.press, 0, 12, dt);
  const lift = Math.max(s.hover, s.sel) * 0.32;
  const bob = motion ? Math.sin(t * 2.2) * 0.06 * s.sel : 0;
  b.art.position.y = lift + bob;
  const sc = 1 + Math.max(s.hover * 0.035, s.sel * 0.05) - s.press * 0.04;
  b.art.scale.setScalar(sc);
  b.ringMat.opacity = Math.max(s.hover * 0.75, s.sel * (0.8 + (motion ? 0.2 * Math.sin(t * 3) : 0)));
  b.ring.scale.setScalar(1 + s.sel * (motion ? 0.03 * Math.sin(t * 3) : 0));
  b.haloMat.opacity = Math.max(s.hover * 0.35, s.sel * 0.6);
  b.beamMat.uniforms.uOpacity.value = s.sel;
  for (const sp of b.spinners) sp.rotation.y += dt * (sp.userData.spinSpeed ?? 0.35) * (motion ? 1 : 0); // per-spinner speed (glTF extras)
  for (const j of b.joints) {
    let want = j.rest;
    if (j.role === 'door') {
      const open = s.hoverT > 0 || s.selT > 0 || s.press > 0.05;
      want = open ? Math.min(j.upper, 1.25) : Math.max(j.lower, 0);
    } else if (motion) { // a slow look-around; with reduced motion it rests
      const k01 = 0.5 + 0.5 * Math.sin(t * 0.22 + j.phase);
      want = THREE.MathUtils.lerp(j.lower * 0.8, j.upper * 0.8, k01);
    }
    j.angle = motion ? THREE.MathUtils.damp(j.angle, want, j.role === 'door' ? 5 : 2, dt) : want;
    j.node.quaternion.setFromAxisAngle(j.axis, j.angle);
  }
  if (b.clock) {
    const now = new Date();
    let hr, mn; b.clock.traverse((o) => { if (/^hour/.test(o.name)) hr = o; if (/^minute/.test(o.name)) mn = o; });
    if (hr) hr.rotation.z = -((now.getHours() % 12) / 12) * Math.PI * 2;
    if (mn) mn.rotation.z = -(now.getMinutes() / 60) * Math.PI * 2;
  }
}

export function setWinter(buildings, on) {
  for (const b of buildings) for (const s of b.snow) s.visible = on;
}
