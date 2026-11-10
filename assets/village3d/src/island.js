// The island: terrain, cliffs, river and waterfall, paths, plaza and
// fountain, bridges, trees, bushes, flowers, rocks, lanterns and the little
// floating islets around it. Everything seasonal is recoloured in
// `setSeason`; everything that glows reads `U.uNight`.
import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { ISLAND, BUILDINGS, PLAZA, toWorld } from './data.js';
import { MAT, SEASONS } from './palette.js';
import { U, addSway } from './fx.js';
import { mergeStatic } from './buildings.js';
import { barkTexture, blob, boulder, flowerParts, leafAtlas, leafyBush, pineTier, shadeVertices, streetLamp, stylizedTree } from './shapes.js';
import { cobbleTexture, fleurShapes, mulberry, softDotTexture, stoneTexture, woodTexture } from './textures.js';

const WATER_Y = -0.12;

// ---------- noise ----------
function hash(x, z) {
  const s = Math.sin(x * 127.1 + z * 311.7) * 43758.5453;
  return s - Math.floor(s);
}
function vnoise(x, z) {
  const xi = Math.floor(x), zi = Math.floor(z);
  const xf = x - xi, zf = z - zi;
  const u = xf * xf * (3 - 2 * xf), v = zf * zf * (3 - 2 * zf);
  const a = hash(xi, zi), b = hash(xi + 1, zi), c = hash(xi, zi + 1), d = hash(xi + 1, zi + 1);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
const fbm = (x, z) => vnoise(x, z) * 0.6 + vnoise(x * 2.1, z * 2.1) * 0.28 + vnoise(x * 4.3, z * 4.3) * 0.12;
const sstep = (a, b, x) => { const t = Math.min(Math.max((x - a) / (b - a), 0), 1); return t * t * (3 - 2 * t); };

// ---------- layout ----------
// 3D plots (metres). Solved from the design's 2D plots (toWorld) by pushing
// plinths apart until: ≥1.4 m between plinths, ≥1.1 m clear of the plaza's
// round pavement, ≥0.7 m from the river bank, and plinth + door path inside the
// rim. Most moved < 0.8 m; CCQ (3.9 m, off the plaza) and the gallery (2.2 m,
// off Français) moved more. The 2D village keeps the design's plots.
const PLOT_3D = {
  MATH: [-12.6, -2.6], FR: [0.45, -6.55], SOC: [11.65, -4.05], ESL: [-13.75, 6.8],
  SCI: [11.56, 8.32], CCQ: [-2.05, 9.0], GALLERY: [7.3, -10.95],
};
const PATH_VIA = { GALLERY: [5.6, -3.2], ESL: [-10.75, 10.75] }; // gallery: between Français and Univers social; Anglais: cross the river square-on, below both plinths
export const buildingSpots = BUILDINGS.map((b) => {
  const w = toWorld(b.left, b.top);
  const p3 = PLOT_3D[b.id]; if (p3) { w.x = p3[0]; w.z = p3[1]; }
  return { ...b, x: w.x, z: w.z, r: b.small ? 3.0 : 3.7 };
});

// The river: a spring behind Français, down past Mathématique, out over the
// front edge as a waterfall.
const riverCurve = new THREE.CatmullRomCurve3([
  new THREE.Vector3(-3.2, 0, -13.2),
  new THREE.Vector3(-4.6, 0, -9.5),
  new THREE.Vector3(-6.4, 0, -5.6),
  new THREE.Vector3(-5.9, 0, -1.6),
  new THREE.Vector3(-7.3, 0, 2.6),
  new THREE.Vector3(-7.9, 0, 6.6),
  new THREE.Vector3(-6.9, 0, 10.6),
  new THREE.Vector3(-6.4, 0, 15.6),
  new THREE.Vector3(-6.0, 0, 21.0), // past the rim: the waterfall is where it crosses
], false, 'catmullrom', 0.5);
const riverPts = riverCurve.getSpacedPoints(160);

function distToPolyline(x, z, pts) {
  let best = 1e9;
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i], b = pts[i + 1];
    const abx = b.x - a.x, abz = b.z - a.z;
    const t = Math.max(0, Math.min(1, ((x - a.x) * abx + (z - a.z) * abz) / (abx * abx + abz * abz)));
    const dx = a.x + abx * t - x, dz = a.z + abz * t - z;
    const d = dx * dx + dz * dz;
    if (d < best) best = d;
  }
  return Math.sqrt(best);
}
const riverDist = (x, z) => distToPolyline(x, z, riverPts);

const ellipseR = (x, z) => Math.sqrt((x / ISLAND.rx) ** 2 + (z / ISLAND.rz) ** 2);
// The rim isn't a perfect ellipse: it wobbles ±3.5 % with the angle.
const edgeWobble = (a) => 1 + (vnoise(Math.cos(a) * 2.2 + 5, Math.sin(a) * 2.2 + 5) - 0.5) * 0.07;
/** True rim factor at (x, z): the island's edge in this direction, in ellipse units. */
const rimAt = (x, z) => edgeWobble(Math.atan2(z / ISLAND.rz, x / ISLAND.rx));

function rawHeight(x, z) {
  let h = (fbm(x * 0.12 + 3, z * 0.12 - 1) - 0.5) * 0.9;
  h += 1.5 * sstep(-5, -13, z); // the back rises toward the spring
  h += 0.7 * Math.exp(-(((x - 15) ** 2) / 18 + ((z + 6) ** 2) / 14)); // knoll behind Univers social
  return h;
}

// Each building sits on a level pad.
for (const s of buildingSpots) s.y = rawHeight(s.x, s.z) + 0.1;
export const plazaY = rawHeight(PLAZA.x, PLAZA.z) * 0.4 + 0.05;

export function heightAt(x, z) {
  let h = rawHeight(x, z);
  for (const s of buildingSpots) {
    const d = Math.hypot(x - s.x, z - s.z);
    const w = 1 - sstep(s.r, s.r + 2.6, d);
    h = h * (1 - w) + s.y * w;
  }
  {
    const d = Math.hypot(x - PLAZA.x, z - PLAZA.z);
    const w = 1 - sstep(PLAZA.r + 0.4, PLAZA.r + 3.5, d);
    h = h * (1 - w) + plazaY * w;
  }
  const rd = riverDist(x, z);
  const carve = 1 - sstep(0.8, 2.3, rd);
  h = h * (1 - carve) + (WATER_Y - 0.45) * carve;
  const e = ellipseR(x, z);
  h -= sstep(0.88, 1.0, e) * 0.45;
  return h;
}

// Path from the plaza's rim to each building's front steps.
function buildPathCurves() {
  const curves = [];
  for (const s of buildingSpots) {
    const fx = s.x, fz = s.z + s.r * 0.95;
    const dx = fx - PLAZA.x, dz = fz - PLAZA.z;
    const len = Math.hypot(dx, dz);
    const sx = PLAZA.x + (dx / len) * (PLAZA.r - 0.3), sz = PLAZA.z + (dz / len) * (PLAZA.r - 0.3);
    let mx = (sx + fx) / 2 + (-dz / len) * 1.2 * (s.x < 0 ? 1 : -1);
    let mz = (sz + fz) / 2 + (dx / len) * 1.2 * (s.x < 0 ? 1 : -1);
    // Some paths take a detour through open ground so their bridge has room
    // (Anglais: the river is squeezed between its plinth and CCQ's further up).
    if (PATH_VIA[s.id]) [mx, mz] = PATH_VIA[s.id];
    // A door that faces away from the plaza: walk round the building's side
    // (the side nearer the plaza) instead of straight through it.
    const crossesOwn = (ax, az, bx, bz) => {
      for (let k = 0; k <= 20; k++) { const t = k / 20; if (Math.hypot(ax + (bx - ax) * t - s.x, az + (bz - az) * t - s.z) < s.r * 0.8) return true; }
      return false;
    };
    if (!PATH_VIA[s.id] && (crossesOwn(sx, sz, mx, mz) || crossesOwn(mx, mz, fx, fz + 1.1))) {
      const side = PLAZA.x < s.x ? -1 : 1;
      mx = s.x + side * (s.r + 1.1); mz = s.z + s.r * 0.35;
    }
    const approach = new THREE.Vector3(fx, 0, fz + 1.1);
    const curve = new THREE.CatmullRomCurve3([
      new THREE.Vector3(sx, 0, sz), new THREE.Vector3(mx, 0, mz), approach, new THREE.Vector3(fx, 0, fz),
    ]);
    curves.push({ id: s.id, curve });
  }
  return curves;
}
export const pathCurves = buildPathCurves();
const pathPts = pathCurves.map((p) => p.curve.getSpacedPoints(60));
const pathDist = (x, z) => Math.min(...pathPts.map((pts) => distToPolyline(x, z, pts)));

// ---------- materials ----------
const std = (color, extra = {}) => new THREE.MeshStandardMaterial({ color, roughness: 0.85, metalness: 0, ...extra });

function waterMaterial({ flow = 0.35, fall = 0 } = {}) {
  // UniformsUtils.merge CLONES every uniform, so the shared clock is wired back
  // in after it (or the water stays frozen at t = 0, which it did until 2026-11-09).
  const uniforms = THREE.UniformsUtils.merge([
      THREE.UniformsLib.fog,
      {
        uLight: { value: new THREE.Color(1, 1, 1) },
        uIce: { value: 0 },
        uFlow: { value: flow }, uFall: { value: fall },
        uEnd: { value: 0 }, uRiverSp: { value: flow * 3 }, uWrap: { value: 0 }, uVeil: { value: 0 },
        uShallow: { value: new THREE.Color(0x7fd3f0) },
        uDeep: { value: new THREE.Color(0x2f8fd0) },
      },
    ]);
  uniforms.uTime = U.uTime;
  uniforms.uNight = U.uNight;
  return new THREE.ShaderMaterial({
    uniforms,
    vertexShader: `
      varying vec2 vUv; varying vec3 vWorld;
      #include <fog_pars_vertex>
      void main(){
        vUv = uv;
        vec4 wp = modelMatrix * vec4(position,1.0);
        vWorld = wp.xyz;
        vec4 mvPosition = viewMatrix * wp;
        gl_Position = projectionMatrix * mvPosition;
        #include <fog_vertex>
      }`,
    fragmentShader: `
      uniform float uTime, uNight, uIce, uFlow, uFall, uEnd, uRiverSp, uWrap, uVeil;
      uniform vec3 uLight, uShallow, uDeep;
      varying vec2 vUv; varying vec3 vWorld;
      #include <fog_pars_fragment>
      float h(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
      float n(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
        return mix(mix(h(i),h(i+vec2(1,0)),f.x), mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x), f.y); }
      float fbm(vec2 p){ return n(p)*0.55 + n(p*2.03+7.1)*0.3 + n(p*4.11+3.3)*0.15; }
      vec3 riverColor(vec2 uv, float t, float sp){
        vec3 col;
        float across = abs(uv.x - 0.5) * 2.0;
        vec2 q = vec2(uv.x * 2.0, uv.y * 10.0);   // ~1 unit per metre along
        float warp = (fbm(vec2(q.x * 1.3, q.y * 0.25 - t * sp * 0.4)) - 0.5) * 0.9;
        float rip = n(vec2((q.x + warp) * 2.5, q.y * 1.2 - t * sp));
        col = mix(uDeep, uShallow, smoothstep(0.1, 1.0, across) * 0.85 + 0.1);
        col *= 0.9 + 0.2 * fbm(vec2(q.x * 0.8, q.y * 0.5 - t * sp * 0.8));
        // Ripple crests ACROSS the stream, broken up, rolling downstream: motion
        // across a pattern's short side is what reads as running water.
        float phase = (q.y + warp * 1.5) * 2.6 - t * sp * 2.6 + n(vec2(q.x * 2.0, q.y * 0.4)) * 3.0;
        float crest = smoothstep(0.55, 0.95, sin(phase));
        crest *= smoothstep(0.35, 0.65, n(vec2(q.x * 3.0, q.y * 0.9 - t * sp)));
        col = mix(col, vec3(0.9, 0.97, 1.0), crest * 0.7);
        // Round foam clumps carried by the current.
        vec2 fq = vec2((q.x + warp * 0.6) * 3.2, q.y * 1.3 - t * sp * 1.3);
        float fleck = smoothstep(0.74, 0.86, n(fq) * 0.7 + n(fq * 2.3 + 5.0) * 0.3);
        fleck *= 1.0 - smoothstep(0.75, 0.95, across);
        col = mix(col, vec3(1.0), fleck * 0.9);
        col *= 1.0 - 0.14 * smoothstep(0.3, 0.05, rip);
        float bank = across + (n(vec2(uv.x * 5.0, q.y * 1.4 - t * sp * 1.2)) - 0.5) * 0.25;
        col = mix(col, vec3(1.0), smoothstep(0.8, 0.97, bank) * 0.65);
        // Glints that ride the current; moonlight at night.
        float sp2 = step(0.975, n(vec2(vWorld.x * 3.0, q.y * 2.0 - t * sp * 1.2)));
        col += sp2 * mix(vec3(0.55), vec3(0.3, 0.4, 0.7), uNight);
        return col;
      }
      void main(){
        float t = uTime * (1.0 - uIce);
        float alpha = 0.94;
        vec3 col;
        if (uFall > 1.5) {
          // Pool: rings rippling out from the centre (where the fountain's
          // water lands), over a soft light-to-deep gradient.
          vec2 c = vUv - 0.5; float d = length(c) * 2.0;
          col = mix(uShallow, uDeep, 0.25 + 0.45 * smoothstep(1.0, 0.0, d));
          float wob = (n(vUv * 9.0 + t * 0.4) - 0.5) * 0.6;
          float rings = 0.5 + 0.5 * sin(d * 30.0 - t * 4.5 + wob);
          col = mix(col, vec3(0.92, 0.98, 1.0), smoothstep(0.82, 0.98, rings) * 0.55 * (1.0 - smoothstep(0.75, 1.0, d)));
          col = mix(col, vec3(1.0), smoothstep(0.12, 0.0, d) * 0.7);           // churn where it lands
          col = mix(col, vec3(1.0), smoothstep(0.9, 1.0, d) * 0.35);           // lap at the rim
          col += step(0.982, n(vUv * 40.0 + t * 0.8)) * mix(vec3(0.5), vec3(0.3, 0.4, 0.7), uNight);
        } else if (uFall > 0.5) {
          // Waterfall. Its top continues the river exactly (same pattern, picked
          // up at the river's last v), then blends into the falling clumps, so
          // there is no seam where the river tips over the edge.
          float v = vUv.y;                       // 0 at the lip … 1 at the bottom
          vec3 riverTop = riverColor(vec2(vUv.x, uEnd + v * 0.9), t, uRiverSp);
          // Water drops ~6 m/s. Clumps are about as tall as they are wide, so the
          // eye can follow them down (long vertical streaks look frozen).
          float drop = v * 8.5 - t * uFlow * 8.0;
          float body = n(vec2(vUv.x * 5.0, drop * 0.35));
          float clump = n(vec2(vUv.x * 7.0 + 2.0, drop * 1.1)) * 0.65 + n(vec2(vUv.x * 13.0, drop * 2.2)) * 0.35;
          float streak = body * 0.5 + clump * 0.5;
          col = mix(uDeep, uShallow, 0.2 + body * 0.6);
          float foam = smoothstep(0.58, 0.72, clump) * 0.9;
          foam += smoothstep(0.72, 1.0, v) * 0.7;             // churning at the base
          col = mix(col, vec3(1.0), clamp(foam, 0.0, 1.0));
          float k = smoothstep(0.02, 0.2, v);
          col = mix(riverTop, col, k);
          float edge = uWrap > 0.5 ? 1.0 : smoothstep(0.0, 0.14, vUv.x) * smoothstep(1.0, 0.86, vUv.x);
          float sheet = edge * (1.0 - smoothstep(0.78, 1.0, v)) * 0.97 * (0.86 + 0.14 * streak);
          alpha = mix(0.94, sheet, k);
          // Veil (fountain overflow): a thin, broken sheet of rivulets you can see through.
          if (uVeil > 0.5) alpha = (0.25 + 0.5 * smoothstep(0.45, 0.75, streak)) * smoothstep(0.0, 0.06, v) * (1.0 - smoothstep(0.85, 1.0, v));
        } else {
          col = riverColor(vUv, t, uFlow * 3.0);
        }
        // Ice: pale, cracked, still.
        vec3 ice = mix(vec3(0.84,0.93,1.0), vec3(0.95,0.98,1.0), n(vWorld.xz * 1.7));
        ice -= step(0.94, n(vWorld.xz * 6.0)) * 0.08;
        col = mix(col, ice, uIce);
        col *= uLight;
        gl_FragColor = vec4(col, alpha);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
        #include <fog_fragment>
      }`,
    transparent: true,
    fog: true,
    depthWrite: !fall,
    side: fall ? THREE.DoubleSide : THREE.FrontSide,
  });
}

// ---------- geometry helpers ----------
function ribbon(points, width, yFn) {
  const pos = [], uv = [], idx = [];
  let acc = 0;
  for (let i = 0; i < points.length; i++) {
    const p = points[i];
    const q = points[Math.min(i + 1, points.length - 1)];
    const o = points[Math.max(i - 1, 0)];
    const tx = q.x - o.x, tz = q.z - o.z; const tl = Math.hypot(tx, tz) || 1;
    const nx = -tz / tl, nz = tx / tl;
    if (i > 0) acc += Math.hypot(p.x - points[i - 1].x, p.z - points[i - 1].z);
    for (const side of [-1, 1]) {
      const x = p.x + nx * side * width / 2, z = p.z + nz * side * width / 2;
      pos.push(x, yFn(x, z, i / (points.length - 1)), z);
      uv.push(side < 0 ? 0 : 1, acc / 10);
    }
    if (i < points.length - 1) {
      const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(idx);
  g.computeVertexNormals();
  return g;
}

// ---------- build ----------
export function buildIsland() {
  const root = new THREE.Group();
  root.name = 'island';
  const rnd = mulberry(42);
  const seasonal = { instanced: [], grassMat: null, water: [], snowCaps: [], flowers: null, leafy: [] };

  // --- grass top ---
  const RINGS = 64, SEG = 180;
  const topPos = [], topCol = [], topIdx = [];
  for (let r = 0; r <= RINGS; r++) {
    for (let s = 0; s < SEG; s++) {
      const a = (s / SEG) * Math.PI * 2;
      const t = r / RINGS;
      const k = t * edgeWobble(a);
      const x = Math.cos(a) * ISLAND.rx * k, z = Math.sin(a) * ISLAND.rz * k;
      let y = heightAt(x, z);
      if (r === RINGS) y -= 0.35; // grass lip
      topPos.push(x, y, z);
      // Brightness and a little hue drift: sunny patches and cooler shade.
      const v = 0.88 + fbm(x * 0.5, z * 0.5) * 0.2;
      const hue = fbm(x * 0.09 + 11, z * 0.09 - 4) - 0.5;
      topCol.push(v * (1 + hue * 0.16), v, v * (1 - hue * 0.2));
    }
  }
  for (let r = 0; r < RINGS; r++) for (let s = 0; s < SEG; s++) {
    const a = r * SEG + s, b = r * SEG + ((s + 1) % SEG), c = (r + 1) * SEG + s, d = (r + 1) * SEG + ((s + 1) % SEG);
    topIdx.push(a, b, c, b, d, c);
  }
  const topGeo = new THREE.BufferGeometry();
  topGeo.setAttribute('position', new THREE.Float32BufferAttribute(topPos, 3));
  topGeo.setAttribute('color', new THREE.Float32BufferAttribute(topCol, 3));
  topGeo.setIndex(topIdx);
  topGeo.computeVertexNormals();
  const grassMat = std(SEASONS.summer.grass, { vertexColors: true, roughness: 0.95 });
  seasonal.grassMat = grassMat;
  const top = new THREE.Mesh(topGeo, grassMat);
  top.receiveShadow = true;
  top.name = 'terrain';
  root.add(top);

  // --- cliffs: earth then stone strata, tapering to a rocky point ---
  {
    const LV = 9; const pos = [], col = [], idx = [];
    const strata = [0xa8754a, 0xc4925f, 0xdcbf94, 0xd6c3a4, 0xc9bcab, 0xbfb8b2, 0xb3b2b6, 0xa9acb8, 0x9fa5b5, 0x98a0b2];
    for (let l = 0; l <= LV; l++) {
      for (let s = 0; s < SEG; s++) {
        const a = (s / SEG) * Math.PI * 2;
        const f = l === 0 ? 1 : (1 - Math.pow(l / LV, 1.35) * 0.93) * (0.94 + vnoise(a * 4 + l * 1.7, l) * 0.12);
        const k = edgeWobble(a) * f;
        const x = Math.cos(a) * ISLAND.rx * k, z = Math.sin(a) * ISLAND.rz * k;
        const y = l === 0 ? heightAt(x, z) - 0.35 : -0.45 - l * 1.05 - vnoise(a * 6, l * 3) * 0.6 - (l === LV ? 1.5 : 0);
        pos.push(x, y, z);
        const c = new THREE.Color(strata[Math.min(l, strata.length - 1)]).multiplyScalar(0.92 + hash(s, l) * 0.16);
        col.push(c.r, c.g, c.b);
      }
    }
    for (let l = 0; l < LV; l++) for (let s = 0; s < SEG; s++) {
      const a = l * SEG + s, b = l * SEG + ((s + 1) % SEG), c = (l + 1) * SEG + s, d = (l + 1) * SEG + ((s + 1) % SEG);
      idx.push(a, b, c, b, d, c);
    }
    let g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
    g.setIndex(idx);
    if (g.index) g = g.toNonIndexed(); g.computeVertexNormals();
    const cliff = new THREE.Mesh(g, std(0xffffff, { vertexColors: true, flatShading: true, roughness: 1 }));
    cliff.receiveShadow = true; cliff.castShadow = true;
    root.add(cliff);
  }

  // --- river, waterfall ---
  {
    // Run the river right to the real (wobbling) rim, a hair past it, so the
    // waterfall starts outside the cliff wall instead of inside it.
    const pts = riverCurve.getSpacedPoints(400).filter((p) => ellipseR(p.x, p.z) < rimAt(p.x, p.z) + 0.004);
    const mat = waterMaterial({ flow: 0.7 });
    seasonal.water.push(mat);
    const river = new THREE.Mesh(ribbon(pts, 2.7, () => WATER_Y), mat);
    river.receiveShadow = false;
    river.renderOrder = 1;
    root.add(river);
    // Spring pool at the source. Its UVs are laid in the river's own frame
    // (across = 0…1 over the river's width, v = metres/10 from the first point),
    // so the pattern flows out of the pool into the river with no edge. A
    // single constant UV made the whole disc one flickering flat colour.
    const pool = new THREE.Mesh(new THREE.CircleGeometry(1.7, 48).rotateX(-Math.PI / 2), mat);
    pool.position.set(-3.2, WATER_Y + 0.005, -13.0);
    {
      const p0 = pts[0], d = new THREE.Vector3(pts[3].x - p0.x, 0, pts[3].z - p0.z).normalize();
      const pp = pool.geometry.attributes.position;
      const puv = new Float32Array(pp.count * 2);
      for (let i = 0; i < pp.count; i++) {
        const wx = pp.getX(i) + pool.position.x - p0.x, wz = pp.getZ(i) + pool.position.z - p0.z;
        puv[i * 2] = 0.5 + (-d.z * wx + d.x * wz) / 2.7;
        puv[i * 2 + 1] = (d.x * wx + d.z * wz) / 10;
      }
      pool.geometry.setAttribute('uv', new THREE.BufferAttribute(puv, 2));
    }
    root.add(pool);

    // Waterfall: one sheet that starts exactly at the river's last edge and
    // arcs out and down like a real pour (out ∝ √drop), widening a little.
    const last = pts[pts.length - 1], prev = pts[pts.length - 6];
    const dir = new THREE.Vector3(last.x - prev.x, 0, last.z - prev.z).normalize();
    const side = new THREE.Vector3(-dir.z, 0, dir.x);
    const fallMat = waterMaterial({ flow: 0.75, fall: 1 });
    // Hand the fall the river's last v and speed so its top continues the river.
    const ruv = river.geometry.attributes.uv;
    fallMat.uniforms.uEnd.value = ruv.getY(ruv.count - 1);
    fallMat.uniforms.uRiverSp.value = mat.uniforms.uFlow.value * 3;
    seasonal.water.push(fallMat);
    const fallH = 8.5, ROWS = 40;
    const fpos = [], fuv = [], fidx = [];
    for (let i = 0; i <= ROWS; i++) {
      const v = i / ROWS;
      const out = 2.2 * Math.sqrt(v);
      const y = WATER_Y - fallH * v;
      const w = (2.7 + v * 0.7) / 2;
      for (const sd of [-1, 1]) {
        fpos.push(last.x + dir.x * out + side.x * sd * w, y, last.z + dir.z * out + side.z * sd * w);
        fuv.push(sd < 0 ? 0 : 1, v);
      }
      if (i < ROWS) { const k = i * 2; fidx.push(k, k + 2, k + 1, k + 1, k + 2, k + 3); }
    }
    const fallGeo = new THREE.BufferGeometry();
    fallGeo.setAttribute('position', new THREE.Float32BufferAttribute(fpos, 3));
    fallGeo.setAttribute('uv', new THREE.Float32BufferAttribute(fuv, 2));
    fallGeo.setIndex(fidx);
    fallGeo.computeVertexNormals();
    const fall = new THREE.Mesh(fallGeo, fallMat);
    fall.renderOrder = 2;
    root.add(fall);
    seasonal.fall = { pos: new THREE.Vector3(last.x + dir.x * 2.4, WATER_Y - fallH * 0.8, last.z + dir.z * 2.4) };
  }

  // --- paths ---
  const pathMat = std(MAT.path, { roughness: 0.9 });
  const pathEdgeMat = std(MAT.pathEdge, { roughness: 0.95 });
  for (const { curve } of pathCurves) {
    const pts = curve.getSpacedPoints(90);
    const y = (x, z) => Math.max(heightAt(x, z), WATER_Y + 0.03) + 0.045;
    const edge = new THREE.Mesh(ribbon(pts, 1.75, (x, z) => y(x, z) - 0.015), pathEdgeMat);
    const road = new THREE.Mesh(ribbon(pts, 1.35, y), pathMat);
    edge.receiveShadow = road.receiveShadow = true;
    root.add(edge, road);
  }

  // --- bridges where paths cross the river ---
  const bridges = [];
  for (const { curve } of pathCurves) {
    const pts = curve.getSpacedPoints(200);
    let best = { d: 1e9 };
    pts.forEach((p, i) => { const d = riverDist(p.x, p.z); if (d < best.d) best = { d, i, p }; });
    if (best.d < 0.6) {
      const a = pts[Math.max(best.i - 4, 0)], b = pts[Math.min(best.i + 4, pts.length - 1)];
      const ax = new THREE.Vector3(b.x - a.x, 0, b.z - a.z).normalize();
      // Slide the bridge along its path (max 0.3 m) so the free ground to the
      // nearest plinth is the same at both ends.
      const free = (dir) => {
        for (let d = 0; d < 6; d += 0.05) {
          const x = best.p.x + ax.x * d * dir, z = best.p.z + ax.z * d * dir;
          if (buildingSpots.some((sp) => Math.hypot(x - sp.x, z - sp.z) < sp.r + 1.0)) return d;
          if (Math.hypot(x - PLAZA.x, z - PLAZA.z) < PLAZA.r + 1.0) return d; // nor the plaza's pavement
        }
        return 6;
      };
      // Slide toward the balanced position, but only as far as both deck ends
      // still land on the banks (deck half-length 1.7 m, river half-width 1.35 m).
      const onBank = (sh) => [-1, 1].every((e) => riverDist(best.p.x + ax.x * (sh + e * 1.7), best.p.z + ax.z * (sh + e * 1.7)) > 1.4);
      let shift = THREE.MathUtils.clamp((free(1) - free(-1)) / 2, -1.2, 1.2);
      while (Math.abs(shift) > 0.01 && !onBank(shift)) shift *= 0.85;
      const p = best.p.clone().addScaledVector(ax, shift);
      bridges.push({ p, angle: Math.atan2(ax.x, ax.z) });
    }
  }
  // A village footbridge: stone abutments on both banks, two arched beams
  // with cross-braces under a hand-laid deck (planks vary in width, tilt and
  // tone, with grain), square posts, top and lower rails, gold finials, and a
  // lantern on two corner posts. Snow lies on the deck in winter.
  const grain = woodTexture();
  const woodTones = [MAT.wood, 0xb0773f, 0x9a6232].map((c) => std(c, { roughness: 0.82, map: grain }));
  const woodMat = woodTones[0]; // also the benches
  const woodDarkMat = std(MAT.woodDark, { roughness: 0.8, map: grain });
  const bridgeStone = std(0xffffff, { roughness: 0.9, map: stoneTexture() });
  const bridgeStoneCap = std(MAT.stoneShade, { roughness: 0.85 });
  const finialMat = new THREE.MeshStandardMaterial({ color: MAT.gold, metalness: 0.8, roughness: 0.32 });
  const bridgeSnowMat = std(0xf7fbff, { roughness: 0.7 });
  const bridgeLamps = [];
  const brnd = mulberry(77);
  // Sized to the river (2.7 m) rather than overshooting it: a 4.4 m deck ran
  // its ends onto neighbouring building plinths (Anglais, CCQ, Mathématique).
  const L = 3.4, N = 11;
  const archY = (t) => 0.28 + Math.cos(t * Math.PI) * 0.36;     // t in [-0.5, 0.5]
  const archTilt = (t) => -Math.sin(t * Math.PI) * 0.36;
  const tubeAlong = (x, dy, r, seg = 6) => new THREE.TubeGeometry(new THREE.CatmullRomCurve3(
    [-0.5, -0.3, -0.1, 0.1, 0.3, 0.5].map((t) => new THREE.Vector3(x, archY(t) + dy, t * L * 0.97))), 24, r, seg);
  const add = (g, geo, mat, x = 0, y = 0, z = 0, cast = true) => {
    const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.castShadow = cast; m.receiveShadow = true; g.add(m); return m;
  };
  for (const br of bridges) {
    const g = new THREE.Group();
    const lampStart = bridgeLamps.length;
    // Abutments: dressed stone blocks the deck lands on, with a darker cap.
    for (const end of [-1, 1]) {
      const z = end * (L / 2 + 0.18);
      add(g, new THREE.BoxGeometry(1.85, 0.9, 0.6), bridgeStone, 0, -0.2, z);
      add(g, new THREE.BoxGeometry(1.96, 0.1, 0.68), bridgeStoneCap, 0, 0.27, z);
    }
    // Arched beams and cross-braces underneath.
    for (const x of [-0.52, 0.52]) add(g, tubeAlong(x, -0.16, 0.085, 4), woodDarkMat);
    for (const t of [-0.3, 0, 0.3]) {
      const m = add(g, new THREE.BoxGeometry(1.2, 0.08, 0.1), woodDarkMat, 0, archY(t) - 0.2, t * L);
      m.rotation.x = archTilt(t);
    }
    // Deck: hand-laid planks.
    for (let i = 0; i < N; i++) {
      const t = i / (N - 1) - 0.5;
      const w = 1.4 + (brnd() - 0.5) * 0.12;
      const m = add(g, new THREE.BoxGeometry(w, 0.1, L / N * (0.82 + brnd() * 0.08)), woodTones[Math.floor(brnd() * 3)],
        (brnd() - 0.5) * 0.05, archY(t) + (brnd() - 0.5) * 0.015, t * L);
      m.rotation.set(archTilt(t), (brnd() - 0.5) * 0.06, (brnd() - 0.5) * 0.03);
    }
    // Railings: square posts with little caps, two rails, gold finials at the ends.
    for (const side of [-1, 1]) {
      const x = side * 0.74;
      for (const t of [-0.5, -0.17, 0.17, 0.5]) {
        const end = Math.abs(t) === 0.5, h = end ? 1.0 : 0.8;
        const y = archY(t);
        add(g, new THREE.BoxGeometry(0.13, h, 0.13), woodDarkMat, x, y + h / 2 - 0.05, t * L * 0.97);
        add(g, new THREE.ConeGeometry(0.11, 0.1, 4).rotateY(Math.PI / 4), woodDarkMat, x, y + h, t * L * 0.97);
        if (end) {
          // Lanterns on two opposite corners, gold balls on the other two.
          if ((t > 0) === (side > 0)) bridgeLamps.push(new THREE.Vector3(x, y + h + 0.2, t * L * 0.97));
          else add(g, new THREE.SphereGeometry(0.085, 12, 8), finialMat, x, y + h + 0.1, t * L * 0.97);
        }
      }
      add(g, tubeAlong(x, 0.82, 0.055), woodTones[0]);
      add(g, tubeAlong(x, 0.42, 0.035), woodDarkMat);
    }
    // Winter: a soft layer of snow on the deck (kept out of the static merge).
    const snowParts = [];
    for (let i = 0; i < N; i++) {
      const t = i / (N - 1) - 0.5;
      snowParts.push(new THREE.BoxGeometry(1.3, 0.05, L / N * 1.02).rotateX(archTilt(t)).translate(0, archY(t) + 0.07, t * L));
    }
    const snow = add(g, mergeGeometries(snowParts), bridgeSnowMat, 0, 0, 0, false);
    snow.visible = false;
    mergeStatic(g);
    g.position.set(br.p.x, WATER_Y, br.p.z);
    g.rotation.y = br.angle;
    root.add(g);
    seasonal.snowCaps.push(snow);
    g.updateMatrixWorld(true);
    for (let k = lampStart; k < bridgeLamps.length; k++) g.localToWorld(bridgeLamps[k]);
    // Footprint corners (abutment caps, the widest part) for layout checks.
    root.userData.bridgeFootprints = root.userData.bridgeFootprints || [];
    root.userData.bridgeFootprints.push([[-0.98, -1], [0.98, -1], [-0.98, 1], [0.98, 1]]
      .map(([x, e]) => g.localToWorld(new THREE.Vector3(x, 0, e * (L / 2 + 0.18 + 0.34))).toArray()));
  }

  // --- plaza and fountain ---
  {
    const cob = cobbleTexture();
    const plaza = new THREE.Mesh(new THREE.CylinderGeometry(PLAZA.r, PLAZA.r + 0.15, 0.4, 64),
      [std(MAT.stoneShade), std(0xffffff, { map: cob, roughness: 0.9 }), std(MAT.stoneShade)]);
    plaza.position.set(PLAZA.x, plazaY - 0.1, PLAZA.z);
    plaza.receiveShadow = true;
    root.add(plaza);
    // A two-tier town fountain: a 16-sided basin in dressed stone with a wide
    // moulded cap and a gold band; a fluted column carrying an upper bowl whose
    // water spills all round in a thin curtain; four little jets arcing from
    // under the gold fleur-de-lys; rings rippling across the basin pool.
    const fountain = new THREE.Group();
    const fStone = std(0xffffff, { roughness: 0.9, map: stoneTexture() });
    const fCap = std(MAT.stoneShade, { roughness: 0.8 });
    const goldMat = new THREE.MeshStandardMaterial({ color: MAT.gold, metalness: 0.85, roughness: 0.3 });
    const put = (geo, mat, y = 0, cast = true) => { const m = new THREE.Mesh(geo, mat); m.position.y = y; m.castShadow = cast; m.receiveShadow = true; fountain.add(m); return m; };
    // Basin wall (outer, textured) and inner face, then the cap and the gold band.
    put(new THREE.CylinderGeometry(1.36, 1.44, 0.5, 16, 1, true), fStone, 0.25);
    put(new THREE.CylinderGeometry(1.18, 1.18, 0.5, 16, 1, true), std(MAT.stoneShade, { side: THREE.BackSide }), 0.25, false);
    put(new THREE.LatheGeometry([[1.14, 0], [1.42, 0], [1.5, 0.06], [1.48, 0.13], [1.14, 0.13]].map(([x, y]) => new THREE.Vector2(x, y)), 16), fCap, 0.5);
    put(new THREE.TorusGeometry(1.44, 0.025, 6, 48).rotateX(Math.PI / 2), goldMat, 0.36, false);
    put(new THREE.CylinderGeometry(1.5, 1.55, 0.08, 16), fCap, 0.04);                     // footing
    // Pool with outward ripples.
    const fmat = waterMaterial({ flow: 0.2, fall: 2 });
    seasonal.water.push(fmat);
    put(new THREE.CircleGeometry(1.18, 48).rotateX(-Math.PI / 2), fmat, 0.42, false);
    // Fluted column, upper bowl (lathe) with a gold rim, and its water.
    const flutes = new THREE.CylinderGeometry(0.2, 0.26, 0.95, 16);
    { const p = flutes.attributes.position; for (let i = 0; i < p.count; i++) { const x = p.getX(i), z = p.getZ(i); const a = Math.atan2(z, x); const k = 1 + 0.06 * Math.cos(a * 8); p.setX(i, x * k); p.setZ(i, z * k); } flutes.computeVertexNormals(); }
    put(flutes, std(MAT.stone, { roughness: 0.85 }), 0.4 + 0.475);
    put(new THREE.CylinderGeometry(0.34, 0.3, 0.12, 16), fCap, 0.46);                        // column base
    const bowl = new THREE.LatheGeometry([[0.06, 0], [0.3, 0.02], [0.55, 0.12], [0.72, 0.28], [0.74, 0.33], [0.66, 0.33], [0.5, 0.2], [0.06, 0.16]].map(([x, y]) => new THREE.Vector2(x, y)), 24);
    put(bowl, fCap, 1.32);
    put(new THREE.TorusGeometry(0.72, 0.022, 6, 40).rotateX(Math.PI / 2), goldMat, 1.32 + 0.33, false);
    const upperMat = waterMaterial({ flow: 0.2, fall: 2 });
    seasonal.water.push(upperMat);
    put(new THREE.CircleGeometry(0.66, 32).rotateX(-Math.PI / 2), upperMat, 1.32 + 0.3, false);
    // The curtain spilling over the bowl's lip down into the basin.
    const curtainMat = waterMaterial({ flow: 0.6, fall: 1 });
    curtainMat.uniforms.uWrap.value = 1;
    curtainMat.uniforms.uVeil.value = 1;
    seasonal.water.push(curtainMat);
    const cPts = [];
    for (let i = 0; i <= 14; i++) { const v = i / 14; cPts.push(new THREE.Vector2(0.75 + 0.2 * Math.sqrt(v), 1.32 + 0.33 - v * (1.32 + 0.33 - 0.44))); }
    put(new THREE.LatheGeometry(cPts, 40), curtainMat, 0, false).renderOrder = 2;
    // Finial: a short stone stem under the gold fleur, and four jets arcing into the bowl.
    put(new THREE.CylinderGeometry(0.07, 0.1, 0.42, 10), fCap, 1.32 + 0.33 + 0.21);
    const jetMat = new THREE.MeshStandardMaterial({ color: 0xbfe8fb, roughness: 0.15, metalness: 0, transparent: true, opacity: 0.75, emissive: 0x7fd3f0, emissiveIntensity: 0.25 });
    for (let k = 0; k < 4; k++) {
      const a = k / 4 * Math.PI * 2 + Math.PI / 4;
      const pts = [];
      for (let i = 0; i <= 10; i++) { const t = i / 10; pts.push(new THREE.Vector3(Math.cos(a) * (0.08 + 0.42 * t), 2.02 + 0.18 * t - 0.55 * t * t, Math.sin(a) * (0.08 + 0.42 * t))); }
      (seasonal.fountainJets = seasonal.fountainJets || []).push(put(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 16, 0.022, 6), jetMat, 0, false));
    }
    const fleur = new THREE.Mesh(new THREE.ExtrudeGeometry(fleurShapes(), { depth: 0.12, bevelEnabled: true, bevelThickness: 0.03, bevelSize: 0.015, bevelSegments: 2, curveSegments: 10 }), goldMat);
    fleur.geometry.center();
    fleur.scale.setScalar(1.1);
    fleur.position.y = 2.45; fleur.castShadow = true;
    fountain.add(fleur);
    fountain.position.set(PLAZA.x, plazaY + 0.1, PLAZA.z - 0.6);
    root.add(fountain);
    seasonal.fountainFleur = fleur;
    // Benches
    for (const a of [-0.55, 0.55]) {
      const bench = new THREE.Group();
      const seat = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.1, 0.42), woodMat);
      seat.position.y = 0.42;
      const back = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.36, 0.08), woodMat);
      back.position.set(0, 0.68, -0.18);
      for (const lx of [-0.55, 0.55]) {
        const leg = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.42, 0.36), std(MAT.iron));
        leg.position.set(lx, 0.21, 0); bench.add(leg);
      }
      bench.add(seat, back);
      bench.traverse((m) => { if (m.isMesh) m.castShadow = true; });
      mergeStatic(bench);
      const ang = Math.PI + a * 1.4;
      bench.position.set(PLAZA.x + Math.sin(ang) * 2.75, plazaY + 0.1, PLAZA.z - 0.6 + Math.cos(ang) * 2.75);
      bench.lookAt(PLAZA.x, bench.position.y, PLAZA.z - 0.6);
      root.add(bench);
    }
  }

  // --- vegetation (instanced, seasonal, swaying) ---
  const avoid = (x, z, pad = 0) => {
    if (ellipseR(x, z) > 0.92) return true;
    for (const s of buildingSpots) {
      const d = Math.hypot(x - s.x, z - s.z);
      if (d < s.r + 0.9 + pad) return true;
      // keep the view of each facade open
      if (z > s.z && z < s.z + 7 && Math.abs(x - s.x) < 2.6) return true;
    }
    if (Math.hypot(x - PLAZA.x, z - PLAZA.z) < PLAZA.r + 1.2 + pad) return true;
    if (riverDist(x, z) < 1.9 + pad * 0.5) return true;
    if (pathDist(x, z) < 1.3 + pad * 0.5) return true;
    return false;
  };
  // Everything scattered (trees, bushes) shares one record of what's already
  // placed, each with a footprint radius sized to its real crown, so a pine
  // can't grow inside a leafy tree and crowns keep a little air between them.
  const occupied = [];
  const GAP = 0.3;
  const scatter = (n, pad, bias, radius = 0) => {
    const out = []; let tries = 0;
    while (out.length < n && tries < n * 80) {
      tries++;
      const a = rnd() * Math.PI * 2, r = Math.sqrt(rnd());
      const x = Math.cos(a) * ISLAND.rx * r, z = Math.sin(a) * ISLAND.rz * r;
      if (bias && !bias(x, z)) continue;
      if (avoid(x, z, pad)) continue;
      if (out.some((p) => Math.hypot(p.x - x, p.z - z) < 1.15 + pad)) continue;
      // The whole footprint (crown), not just the trunk, stays inside the rim.
      if (radius && ellipseR(x, z) + radius / Math.min(ISLAND.rx, ISLAND.rz) > 0.94) continue;
      if (radius && occupied.some((o) => Math.hypot(o.x - x, o.z - z) < o.r + radius + GAP)) continue;
      out.push({ x, z, y: heightAt(x, z) });
      if (radius) occupied.push({ x, z, r: radius });
    }
    return out;
  };

  const dummy = new THREE.Object3D();
  const makeInstanced = (geo, mat, list, setup) => {
    const m = new THREE.InstancedMesh(geo, mat, list.length);
    list.forEach((p, i) => { setup(dummy, p, i); dummy.updateMatrix(); m.setMatrixAt(i, dummy.matrix); });
    m.castShadow = true; m.receiveShadow = true;
    m.instanceMatrix.needsUpdate = true;
    root.add(m);
    return m;
  };

  // Pines: more of them toward the back and the rim.
  // Leafy trees claim their space first (they're the wider crowns); pines fill around them.
  const rounds = scatter(24, 0.25, (x, z) => (z > -6 || rnd() < 0.4) && !(z > 3 && Math.abs(x) < 9 && rnd() < 0.6), 1.3);
  const pines = scatter(32, 0.2, (x, z) => z < -2 || ellipseR(x, z) > 0.72 || rnd() < 0.25, 0.95);
  // Four scalloped tiers, shaded dark at the skirt and light at the tip.
  const PINE_TIERS = [[1.12, 1.25, 1.2, 0], [0.92, 1.1, 1.85, 1.3], [0.7, 0.95, 2.45, 2.1], [0.45, 0.85, 3.0, 0.7]];
  const pineGeo = shadeVertices(mergeGeometries(PINE_TIERS.map(([r, h, y, s]) => pineTier(r, h, y, { seed: s }))),
    { low: 0.58, high: 1.12, under: 0.35, yMin: 0.5 });
  const pineMat = addSway(std(0xffffff, { roughness: 0.82, vertexColors: true }), { amount: 0.05, heightRef: 3 });
  // Islet pines aren't instanced, so they get their own seasonal colour.
  const isletPineMat = addSway(std(0xffffff, { roughness: 0.82, vertexColors: true }), { amount: 0.05, heightRef: 3 });
  seasonal.isletPineMat = isletPineMat;
  const pineMesh = makeInstanced(pineGeo, pineMat, pines, (d, p) => {
    const s = 0.62 + hash(p.x, p.z) * 0.45;
    d.position.set(p.x, p.y, p.z); d.scale.set(s, s * (0.95 + hash(p.z, p.x) * 0.3), s); d.rotation.set(0, hash(p.x * 3, p.z) * 6.28, 0);
  });
  const trunkGeo = new THREE.CylinderGeometry(0.12, 0.18, 1.0, 6).translate(0, 0.5, 0);
  const trunkMat = std(0x8a5a36);
  makeInstanced(trunkGeo, trunkMat, pines, (d, p) => {
    const s = 0.62 + hash(p.x, p.z) * 0.45; d.position.set(p.x, p.y, p.z); d.scale.set(s, s, s); d.rotation.set(0, 0, 0);
  });
  // Snow sits on the upper half of each tier, slightly proud of it.
  const pineSnowGeo = mergeGeometries(PINE_TIERS.map(([r, h, y, s]) => {
    const g = pineTier(r * 0.62, h * 0.55, y + h * 0.24, { seed: s, droop: 0.3 });
    g.scale(1.04, 1, 1.04);
    return g;
  }));
  const snowMat = addSway(std(0xf7fbff, { roughness: 0.7 }), { amount: 0.05, heightRef: 3 });
  const pineSnow = makeInstanced(pineSnowGeo, snowMat, pines, (d, p) => {
    const s = 0.62 + hash(p.x, p.z) * 0.45;
    d.position.set(p.x, p.y + 0.03, p.z); d.scale.set(s * 1.02, s * (0.95 + hash(p.z, p.x) * 0.3), s * 1.02); d.rotation.set(0, hash(p.x * 3, p.z) * 6.28, 0);
  });
  pineSnow.visible = false;
  seasonal.snowCaps.push(pineSnow);

  // Round leafy trees.
  // Stylised leafy trees (see `stylizedTree`): crowns of leaf clumps shingled
  // with alpha-cut leaf cards over dark cores, on tapered, bent trunks with
  // roots and branches into each clump. Three kinds × three seeds, spread
  // over the instances so neighbours never look like copies. The leaf cut-outs
  // also drive the shadow map, so the shade under each tree is dappled.
  const canopyMat = addSway(std(0xffffff, { roughness: 0.82, vertexColors: true, map: leafAtlas(), alphaTest: 0.5, alphaToCoverage: true, side: THREE.DoubleSide }), { amount: 0.05, heightRef: 2.6 });
  const barkMat = std(0x9a6a44, { roughness: 0.9, map: barkTexture() });
  seasonal.canopyMat = canopyMat;
  const VARIANTS = [['oak', 3], ['round', 5], ['broad', 7], ['oak', 11], ['broad', 13], ['round', 17], ['oak', 19], ['broad', 23], ['round', 29]];
  const roundMeshes = [], trunkMeshes = [];
  VARIANTS.forEach(([kind, seed], vi) => {
    const list = rounds.filter((_, i) => i % VARIANTS.length === vi);
    if (!list.length) return;
    const place = (d, p) => {
      const s = 0.72 + hash(p.x + 1, p.z) * 0.32;
      d.position.set(p.x, p.y - 0.02, p.z); d.scale.set(s, s * (0.95 + hash(p.z, 4) * 0.12), s); d.rotation.set(0, hash(p.x, p.z * 2) * 6.28, 0);
    };
    const t = stylizedTree(kind, seed);
    roundMeshes.push(makeInstanced(t.crown, canopyMat, list, place));
    trunkMeshes.push(makeInstanced(t.trunk, barkMat, list, place));
  });
  // Bushes along the paths and around the plaza.
  const bushes = scatter(56, -0.5, (x, z) => pathDist(x, z) < 2.4 || Math.hypot(x - PLAZA.x, z - PLAZA.z) < PLAZA.r + 2.4, 0.55);
  // Leafy mounds in the trees' painted style; every other one blossoms in the
  // seasons that have flowers (blossoms take the season's flower colours).
  const bushMat = addSway(std(0xffffff, { roughness: 0.8, vertexColors: true }), { amount: 0.04, heightRef: 1 });
  const blossomMat = addSway(std(0xffffff, { roughness: 0.55 }), { amount: 0.04, heightRef: 1 });
  const BUSHES = [leafyBush(21), leafyBush(34, { blossoms: 16 })];
  const bushMeshes = [], blossomMeshes = [];
  BUSHES.forEach((v, vi) => {
    const list = bushes.filter((_, i) => i % BUSHES.length === vi);
    if (!list.length) return;
    const place = (d, p) => {
      const s = 0.6 + hash(p.x, p.z + 3) * 0.6; d.position.set(p.x, p.y - 0.02, p.z); d.scale.set(s * 1.15, s * (0.85 + hash(p.x, 6) * 0.3), s); d.rotation.set(0, hash(p.z, p.x) * 6.28, 0);
    };
    bushMeshes.push(makeInstanced(v.leaves, bushMat, list, place));
    if (v.blossoms) { const m = makeInstanced(v.blossoms, blossomMat, list, place); m.name = 'bushBlossoms'; m.castShadow = false; blossomMeshes.push(m); }
  });

  // Flowers: tiny bright blooms in meadow patches.
  const flowers = [];
  for (let k = 0; k < 34; k++) {
    const c = scatter(1, -0.6)[0]; if (!c) continue;
    for (let j = 0; j < 9; j++) {
      const x = c.x + (rnd() - 0.5) * 2.2, z = c.z + (rnd() - 0.5) * 2.2;
      if (avoid(x, z, -0.9)) continue;
      flowers.push({ x, z, y: heightAt(x, z) });
    }
  }
  // Real little flowers: daisies (petals open to the sky) and tulips (cups),
  // each in three instanced parts (petals tinted per season, yellow heart,
  // green stem with two leaves) that sway together.
  const flowerMeshes = [], flowerExtras = [];
  const petalMat = addSway(std(0xffffff, { roughness: 0.55 }), { amount: 0.08, heightRef: 0.3 });
  const heartMat = addSway(std(0xf6c445, { roughness: 0.5 }), { amount: 0.08, heightRef: 0.3 });
  const stemMat = addSway(std(0x5aa64e, { roughness: 0.7 }), { amount: 0.08, heightRef: 0.3 });
  [0, 1].forEach((kind) => {
    const list = flowers.filter((_, i) => (hash(i * 0.37, 5) < 0.68 ? 0 : 1) === kind);
    if (!list.length) return;
    const parts = flowerParts(kind);
    const place = (d, p) => {
      d.position.set(p.x, p.y, p.z); d.scale.setScalar(0.85 + hash(p.x, p.z) * 0.6);
      d.rotation.set((hash(p.z, 7) - 0.5) * 0.25, hash(p.x, 3) * 6.28, (hash(p.x, 9) - 0.5) * 0.25);
    };
    const pm = makeInstanced(parts.petals, petalMat, list, place);
    const hm = makeInstanced(parts.heart, heartMat, list, place);
    const sm = makeInstanced(parts.stem, stemMat, list, place);
    for (const m of [pm, hm, sm]) m.castShadow = false;
    flowerMeshes.push(pm); flowerExtras.push(hm, sm);
  });
  seasonal.flowerExtras = flowerExtras;

  // Rocks on the rim and along the river.
  const rocks = [];
  for (let k = 0; k < 50; k++) {
    const a = rnd() * Math.PI * 2; const r = 0.86 + rnd() * 0.05; // outer edge stays on the rim
    const x = Math.cos(a) * ISLAND.rx * r, z = Math.sin(a) * ISLAND.rz * r;
    if (Math.abs(x + 6.5) < 2 && z > 10) continue;
    rocks.push({ x, z, y: heightAt(x, z), s: 0.35 + rnd() * 0.6 });
  }
  for (const p of riverCurve.getSpacedPoints(30)) {
    if (rnd() < 0.5 || ellipseR(p.x, p.z) > 0.9) continue;
    const side = rnd() < 0.5 ? -1 : 1;
    const x = p.x + side * (1.5 + rnd() * 0.4), z = p.z + (rnd() - 0.5);
    if (pathDist(x, z) < 1.2) continue;
    rocks.push({ x, z, y: heightAt(x, z), s: 0.25 + rnd() * 0.35 });
  }
  // Weathered boulders: three shapes, one with pebbles at its foot.
  const rockMat = std(0xbdbab2, { roughness: 0.95, vertexColors: true });
  const ROCKS = [boulder(1), boulder(2), boulder(3, { pebbles: 2 })];
  ROCKS.forEach((geo, vi) => {
    const list = rocks.filter((_, i) => i % ROCKS.length === vi);
    if (list.length) makeInstanced(geo, rockMat, list, (d, p) => {
      d.position.set(p.x, p.y - 0.03, p.z); d.scale.set(p.s * 1.15, p.s * (0.9 + hash(p.x, 4) * 0.3), p.s); d.rotation.set(0, hash(p.z, 2) * 6.28, 0);
    });
  });

  // Seasonal colouring targets.
  seasonal.instanced.push(
    { mesh: pineMesh, kind: 'pine' },
    ...roundMeshes.map((mesh, i) => ({ mesh, kind: 'canopy', trunks: trunkMeshes[i] })),
    ...bushMeshes.map((mesh) => ({ mesh, kind: 'bush' })),
    ...blossomMeshes.map((mesh) => ({ mesh, kind: 'flower' })),
    ...flowerMeshes.map((mesh) => ({ mesh, kind: 'flower' })),
  );
  seasonal.leafy = rounds;

  // --- lanterns along the paths ---
  const lanternSpots = [];
  for (const { curve } of pathCurves) {
    const len = curve.getLength(); const n = Math.max(1, Math.floor(len / 5.5));
    for (let k = 1; k <= n; k++) {
      const t = k / (n + 1); const p = curve.getPointAt(t); const tg = curve.getTangentAt(t);
      const side = k % 2 ? 1 : -1;
      const x = p.x + -tg.z * 1.05 * side, z = p.z + tg.x * 1.05 * side;
      if (riverDist(x, z) < 1.6) continue;
      // Never on the plaza's pavement or a building's plinth (paths start and end there).
      if (Math.hypot(x - PLAZA.x, z - PLAZA.z) < PLAZA.r + 0.6) continue;
      if (buildingSpots.some((sp) => Math.hypot(x - sp.x, z - sp.z) < sp.r + 0.5)) continue;
      lanternSpots.push({ x, z, y: heightAt(x, z) });
    }
  }
  // Street lamps: stepped base, iron post with collars, a caged lantern with
  // glowing glass, pyramid roof and a gold finial (see `streetLamp`).
  const lampMat = new THREE.MeshStandardMaterial({ color: 0xfff1cf, emissive: 0xffc35a, emissiveIntensity: 0.2, roughness: 0.4 });
  const lampIronMat = std(MAT.iron, { roughness: 0.5, metalness: 0.3 });
  const lampGoldMat = new THREE.MeshStandardMaterial({ color: MAT.gold, metalness: 0.8, roughness: 0.32 });
  const upright = (d, p) => { d.position.set(p.x, p.y, p.z); d.scale.setScalar(1); d.rotation.set(0, (p.x * 7.3 + p.z * 3.1) % 1.57, 0); };
  const lamp = streetLamp();
  makeInstanced(lamp.iron, lampIronMat, lanternSpots, upright);
  makeInstanced(lamp.glass, lampMat, lanternSpots, upright).castShadow = false;
  makeInstanced(lamp.gold, lampGoldMat, lanternSpots, upright);
  seasonal.lampMat = lampMat;
  seasonal.lanterns = lanternSpots;
  // The bridges' corner lanterns are the same lantern head, a bit smaller.
  if (bridgeLamps.length) {
    const head = streetLamp({ head: true });
    const small = (d, p) => { d.position.copy(p); d.scale.setScalar(0.72); d.rotation.set(0, 0, 0); };
    makeInstanced(head.iron, lampIronMat, bridgeLamps, small);
    makeInstanced(head.glass, lampMat, bridgeLamps, small).castShadow = false;
    makeInstanced(head.gold, lampGoldMat, bridgeLamps, small);
  }
  // Warm halos that bloom around each lamp after dusk.
  {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute([
      ...lanternSpots.flatMap((p) => [p.x, p.y + 1.92, p.z]),
      ...bridgeLamps.flatMap((p) => [p.x, p.y, p.z]),
    ], 3));
    const glowMat = new THREE.PointsMaterial({ map: softDotTexture(), color: 0xffc56b, size: 3.2, sizeAttenuation: true, transparent: true, opacity: 0, depthWrite: false, blending: THREE.AdditiveBlending });
    const glow = new THREE.Points(g, glowMat);
    root.add(glow);
    seasonal.lampGlow = glowMat;
  }

  // --- floating islets ---
  const islets = [];
  for (const [x, y, z, s] of [[-33, -3.5, -10, 1.6], [32, -1.5, -14, 1.25], [30, -6, 15, 1.0], [-30, -7.5, 16, 0.9]]) {
    const g = new THREE.Group();
    const rock = new THREE.Mesh(new THREE.ConeGeometry(1.6, 3.2, 7, 2).rotateX(Math.PI).translate(0, -1.55, 0), std(0xa9a59c, { flatShading: true, roughness: 1 }));
    const cap = new THREE.Mesh(new THREE.CylinderGeometry(1.65, 1.6, 0.35, 7), seasonal.capMat || (seasonal.capMat = std(SEASONS.summer.grass, { flatShading: true })));
    cap.position.y = 0.0;
    const tree = new THREE.Mesh(pineGeo, isletPineMat); tree.position.y = 0.15; tree.scale.setScalar(0.6);
    const trunk = new THREE.Mesh(trunkGeo, trunkMat); trunk.position.y = 0.15; trunk.scale.setScalar(0.6);
    g.add(rock, cap, tree, trunk);
    g.traverse((m) => { if (m.isMesh) { m.castShadow = true; m.receiveShadow = true; } });
    g.position.set(x, y, z); g.scale.setScalar(s);
    g.userData.base = y; g.userData.phase = x;
    root.add(g); islets.push(g);
  }
  seasonal.islets = islets;
  seasonal.isletTrees = islets.map((g) => g.children[2]);

  return { root, seasonal, heightAt, WATER_Y };
}

/** Recolour every living thing for a season. */
export function applySeason(seasonal, season) {
  const P = SEASONS[season];
  seasonal.grassMat.color.setHex(P.grass);
  if (seasonal.capMat) seasonal.capMat.color.setHex(P.grass);
  if (seasonal.plinthGrass) seasonal.plinthGrass.color.setHex(P.grass);
  const c = new THREE.Color();
  for (const { mesh, kind, trunks } of seasonal.instanced) {
    const n = mesh.count;
    for (let i = 0; i < n; i++) {
      const r = hash(i * 1.3, i * 0.7);
      if (kind === 'pine') {
        c.setHex(P.pine).multiplyScalar(0.85 + r * 0.3);
      } else if (kind === 'canopy') {
        c.setHex(P.canopy[Math.floor(r * P.canopy.length) % P.canopy.length]).multiplyScalar(0.92 + hash(i, 9) * 0.16);
      } else if (kind === 'bush') {
        c.setHex(P.bush).multiplyScalar(0.85 + r * 0.3);
      } else if (kind === 'flower') {
        const list = P.flowers.length ? P.flowers : [0xffffff];
        c.setHex(list[Math.floor(r * list.length) % list.length]);
      }
      mesh.setColorAt(i, c);
    }
    mesh.instanceColor.needsUpdate = true;
    if (kind === 'flower') mesh.visible = P.flowers.length > 0;
    for (const m of seasonal.flowerExtras || []) m.visible = P.flowers.length > 0;
    if (trunks) trunks.visible = true;
  }
  if (seasonal.isletPineMat) seasonal.isletPineMat.color.setHex(P.pine);
  // Winter crowns read as snow-dusted, not grey: a soft cool lift.
  if (seasonal.canopyMat) { seasonal.canopyMat.emissive.setHex(P.snow ? 0xb8c6dc : 0x000000); seasonal.canopyMat.emissiveIntensity = P.snow ? 0.45 : 0; }
  for (const j of seasonal.fountainJets || []) j.visible = !P.snow; // the jets stop when the fountain freezes
  for (const s of seasonal.snowCaps) s.visible = !!P.snow;
  for (const w of seasonal.water) w.uniforms.uIce.value = P.snow ? (w.uniforms.uFall.value === 1 ? 0.55 : 1) : 0; // falling water half-freezes, pools freeze
}

/** Per-frame: islets bob, lamps light up at night. */
export function updateIsland(seasonal, t, light, night) {
  for (const g of seasonal.islets) g.position.y = g.userData.base + Math.sin(t * 0.5 + g.userData.phase) * 0.25;
  seasonal.lampMat.emissiveIntensity = 0.15 + night * 3.2;
  seasonal.lampGlow.opacity = Math.max(0, night - 0.2) * 0.9;
  for (const w of seasonal.water) w.uniforms.uLight.value.copy(light);
}
