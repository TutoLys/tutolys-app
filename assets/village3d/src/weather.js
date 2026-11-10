// Weather: drifting clouds, rain, snow, storms with soft lightning, plus the
// seasonal particles (spring petals, autumn leaves, summer fireflies) and
// the mist under the waterfall. Particles run on the GPU from one clock, so
// reduced motion stops them where they are rather than hiding them.
import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { U } from './fx.js';
import { blob, shadeVertices } from './shapes.js';
import { softDotTexture, mulberry } from './textures.js';

export const WEATHER = {
  clear: { cloud: 0.0, clouds: 7, dark: 0, rain: 0, snow: 0, wind: 0.3 },
  clouds: { cloud: 0.5, clouds: 18, dark: 0.25, rain: 0, snow: 0, wind: 0.45 },
  rain: { cloud: 0.75, clouds: 20, dark: 0.55, rain: 0.6, snow: 0, wind: 0.6 },
  snow: { cloud: 0.6, clouds: 18, dark: 0.3, rain: 0, snow: 1, wind: 0.35 },
  storm: { cloud: 1.0, clouds: 22, dark: 0.85, rain: 1, snow: 0, wind: 1.0 },
};

const BOX = { w: 56, h: 34, d: 46, top: 26 };

function particleMaterial({ color, size, kind }) {
  return new THREE.ShaderMaterial({
    uniforms: {
      uTime: U.uTime, uWind: U.uWind, uNight: U.uNight,
      uColor: { value: new THREE.Color(color) }, uSize: { value: size }, uOpacity: { value: 1 },
      uMap: { value: softDotTexture() }, uPixel: { value: 1 },
      uLight: { value: new THREE.Color(1, 1, 1) },
    },
    vertexShader: `
      attribute vec4 seed; attribute vec3 tint;
      uniform float uTime, uWind, uSize, uPixel;
      varying vec3 vTint; varying float vSpin; varying float vSeed;
      void main(){
        vTint = tint; vSeed = seed.w;
        float H = ${BOX.h.toFixed(1)};
        vec3 p;
        ${kind === 'snow' ? `
          float fall = mod(seed.y * H - uTime * (0.9 + seed.w * 0.8), H);
          p = vec3(seed.x + sin(uTime * 0.6 + seed.w * 20.0) * 0.8 + uWind * (H - fall) * 0.35, ${BOX.top.toFixed(1)} - H + fall, seed.z + cos(uTime * 0.5 + seed.w * 12.0) * 0.6);
        ` : kind === 'leaf' ? `
          float fall = mod(seed.y * H - uTime * (0.7 + seed.w * 0.5), H);
          p = vec3(seed.x + sin(uTime * 1.1 + seed.w * 30.0) * 1.4 + uWind * (H - fall) * 0.5, ${BOX.top.toFixed(1)} - H + fall - 10.0, seed.z + cos(uTime * 0.9 + seed.w * 9.0) * 1.0);
          vSpin = uTime * (1.5 + seed.w * 2.0) + seed.w * 6.28;
        ` : kind === 'firefly' ? `
          p = vec3(seed.x + sin(uTime * 0.4 + seed.w * 50.0) * 1.5, 0.6 + seed.y * 2.6 + sin(uTime * 0.9 + seed.w * 20.0) * 0.4, seed.z + cos(uTime * 0.35 + seed.w * 30.0) * 1.5);
        ` : `
          float life = fract(uTime * 0.35 + seed.w);
          p = vec3(seed.x + (seed.y - 0.5) * life * 3.0, seed.z * 0.0 + life * 2.2, (seed.y - 0.5) * 1.5 + life * 1.6);
          p += vec3(0.0, 0.0, 0.0);
          vSpin = life;
        `}
        vec4 mv = modelViewMatrix * vec4(p, 1.0);
        gl_Position = projectionMatrix * mv;
        gl_PointSize = uSize * uPixel * (0.6 + seed.w * 0.8) * (600.0 / -mv.z)${kind === 'mist' ? ' * (0.6 + vSpin * 1.6)' : ''};
      }`,
    fragmentShader: `
      uniform vec3 uColor, uLight; uniform float uOpacity, uNight, uTime; uniform sampler2D uMap;
      varying vec3 vTint; varying float vSpin; varying float vSeed;
      void main(){
        vec2 c = gl_PointCoord - 0.5;
        float a;
        ${kind === 'leaf' ? `
          float s = sin(vSpin), co = cos(vSpin);
          vec2 r = vec2(c.x * co - c.y * s, c.x * s + c.y * co);
          r.x *= 0.9 + 0.5 * abs(sin(vSpin * 0.7));
          a = smoothstep(0.5, 0.42, length(vec2(r.x * 1.9, r.y)));
          vec3 col = vTint * uLight;
        ` : kind === 'firefly' ? `
          a = texture2D(uMap, gl_PointCoord).a * (0.5 + 0.5 * sin(uTime * 3.0 + vSeed * 40.0));
          vec3 col = vec3(1.0, 0.9, 0.45);
        ` : kind === 'mist' ? `
          a = texture2D(uMap, gl_PointCoord).a * (1.0 - vSpin) * 0.5;
          vec3 col = vec3(1.0) * uLight;
        ` : `
          a = smoothstep(0.5, 0.2, length(c));
          vec3 col = uColor * uLight;
        `}
        if (a < 0.02) discard;
        gl_FragColor = vec4(col, a * uOpacity);
      }`,
    transparent: true, depthWrite: false,
    blending: kind === 'firefly' ? THREE.AdditiveBlending : THREE.NormalBlending,
  });
}

function makePoints(n, kind, { color = 0xffffff, size = 1, tints, area = BOX, seedRnd = 1, origin } = {}) {
  const rnd = mulberry(seedRnd);
  const seed = new Float32Array(n * 4); const tint = new Float32Array(n * 3);
  const c = new THREE.Color();
  for (let i = 0; i < n; i++) {
    if (kind === 'firefly') {
      const a = rnd() * Math.PI * 2, r = Math.sqrt(rnd()) * 0.85;
      seed.set([Math.cos(a) * 20 * r, rnd(), Math.sin(a) * 15 * r, rnd()], i * 4);
    } else if (kind === 'mist') {
      seed.set([(rnd() - 0.5) * 2.4, rnd(), 0, rnd()], i * 4);
    } else {
      seed.set([(rnd() - 0.5) * area.w, rnd(), (rnd() - 0.5) * area.d, rnd()], i * 4);
    }
    c.setHex(tints ? tints[Math.floor(rnd() * tints.length)] : color);
    tint.set([c.r, c.g, c.b], i * 3);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(n * 3), 3));
  g.setAttribute('seed', new THREE.BufferAttribute(seed, 4));
  g.setAttribute('tint', new THREE.BufferAttribute(tint, 3));
  const mat = particleMaterial({ color, size, kind });
  const pts = new THREE.Points(g, mat);
  pts.frustumCulled = false;
  if (origin) pts.position.copy(origin);
  return pts;
}

function makeRain(n) {
  const rnd = mulberry(9);
  const seed = new Float32Array(n * 2 * 4); const end = new Float32Array(n * 2);
  for (let i = 0; i < n; i++) {
    const s = [(rnd() - 0.5) * BOX.w, rnd(), (rnd() - 0.5) * BOX.d, rnd()];
    seed.set(s, i * 8); seed.set(s, i * 8 + 4);
    end[i * 2] = 0; end[i * 2 + 1] = 1;
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(n * 6), 3));
  g.setAttribute('seed', new THREE.BufferAttribute(seed, 4));
  g.setAttribute('endp', new THREE.BufferAttribute(end, 1));
  const mat = new THREE.ShaderMaterial({
    uniforms: { uTime: U.uTime, uWind: U.uWind, uOpacity: { value: 0.5 }, uLight: { value: new THREE.Color(1, 1, 1) } },
    vertexShader: `attribute vec4 seed; attribute float endp; uniform float uTime, uWind; varying float vE;
      void main(){
        float H = ${BOX.h.toFixed(1)};
        float sp = 22.0 + seed.w * 10.0;
        float fall = mod(seed.y * H - uTime * sp, H);
        vec3 p = vec3(seed.x + uWind * fall * 0.35, ${BOX.top.toFixed(1)} - H + fall, seed.z);
        p += endp * vec3(uWind * 0.55, 1.3, 0.0);
        vE = endp;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(p, 1.0);
      }`,
    fragmentShader: 'uniform float uOpacity; uniform vec3 uLight; varying float vE; void main(){ gl_FragColor = vec4(vec3(0.62,0.72,0.86) * uLight, uOpacity * (0.25 + (1.0 - vE) * 0.75)); }',
    transparent: true, depthWrite: false,
  });
  const lines = new THREE.LineSegments(g, mat);
  lines.frustumCulled = false;
  return lines;
}

// A cumulus, built the way real ones look: puffs scattered over an oval
// footprint (not a row, which read as a croissant), stacked into an
// off-centre tower, all sharing ONE flat base. Shapes vary from wide and
// flat to tall and billowing. `detail` 3 keeps the silhouette round; shadow
// clouds pass 1 since only the sun's shadow map sees them.
function cloudGeometry(rnd, { shade = true, detail = 3, flat = false } = {}) {
  const parts = [];
  const tall = flat ? 0 : rnd();                     // 0 flat stratocumulus … 1 towering
  const W = 4.5 + rnd() * 4.5, D = 2.2 + rnd() * 1.8;
  const towerX = (rnd() - 0.5) * W * 0.8, towerZ = (rnd() - 0.5) * D * 0.4;
  const puff = (r, x, y, z) => parts.push(blob(r, { detail, seed: rnd() * 90, lump: 0.08, freq: 1.3 }).translate(x, y, z));
  // Base layer: wide, overlapping, spread over the oval.
  const nBase = 6 + Math.floor(rnd() * 4);
  for (let i = 0; i < nBase; i++) {
    const a = rnd() * Math.PI * 2, k = Math.sqrt(rnd());
    puff(1.1 + rnd() * 0.8, Math.cos(a) * W * 0.5 * k, 0.2 + rnd() * 0.3, Math.sin(a) * D * 0.5 * k);
  }
  // Middle layer, pulled toward the tower so the top is lopsided.
  const nMid = 3 + Math.floor(rnd() * 3);
  for (let i = 0; i < nMid; i++) {
    const x = THREE.MathUtils.lerp((rnd() - 0.5) * W * 0.7, towerX, 0.45), z = (rnd() - 0.5) * D * 0.5;
    puff(1.4 + rnd() * 0.9, x, 1.0 + rnd() * 0.5 + tall * 0.4, z);
  }
  // Crown: one to three puffs over the tower, higher on tall clouds.
  const nTop = 1 + Math.floor(tall * 2.5);
  for (let i = 0; i < nTop; i++) {
    puff(1.1 + rnd() * 0.7 + tall * 0.4, towerX + (rnd() - 0.5) * 1.6, 1.9 + tall * 1.4 + i * 0.6, towerZ + (rnd() - 0.5) * 0.8);
  }
  // A small trailing puff or two on the far side, low.
  for (let i = 0; i < 2; i++) puff(0.7 + rnd() * 0.4, -Math.sign(towerX || 1) * W * (0.45 + rnd() * 0.15), 0.1, (rnd() - 0.5) * D * 0.4);

  const g = mergeGeometries(parts);
  // One flat base for the whole cloud: squash everything below the floor.
  const floor = 0.05, p = g.attributes.position;
  for (let i = 0; i < p.count; i++) { const y = p.getY(i); if (y < floor) p.setY(i, floor + (y - floor) * 0.12); }
  g.computeVertexNormals();
  g.computeBoundingBox();
  g.translate(-(g.boundingBox.min.x + g.boundingBox.max.x) / 2, -g.boundingBox.min.y - 1.0, 0);
  if (shade) shadeVertices(g, { low: 0.78, high: 1.04, under: 0.1 });
  return g;
}

// Soft fluffy edge: brighten where the surface turns away from the camera.
function addCloudRim(mat) {
  mat.onBeforeCompile = (sh) => {
    // The glow follows the baked shading too, so clouds can stay bright
    // without going flat.
    sh.fragmentShader = sh.fragmentShader.replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
      totalEmissiveRadiance *= vColor;`);
    sh.fragmentShader = sh.fragmentShader.replace('#include <dithering_fragment>', `#include <dithering_fragment>
      {
        float rim = 1.0 - max(dot(normalize(normal), normalize(vViewPosition)), 0.0);
        gl_FragColor.rgb = mix(gl_FragColor.rgb, diffuse * 1.08, pow(rim, 2.2) * 0.55);
      }`);
  };
  mat.customProgramCacheKey = () => 'cloudRim';
  return mat;
}

const CLOUD_SEA_CEIL = -13.2; // just under the island's lowest point

export function createWeather(scene, { fallPos } = {}) {
  const group = new THREE.Group();
  group.name = 'weather';
  scene.add(group);
  const rnd = mulberry(5);

  // Clouds: above and below the island, circling slowly.
  const cloudMat = addCloudRim(new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 1, vertexColors: true, emissive: 0xffffff, emissiveIntensity: 0.4 }));
  const clouds = [];
  // Upper clouds drift across the back and the far sides only, so they
  // never sit between the camera and the village; lower ones circle under
  // the island like a sea of cloud.
  for (let i = 0; i < 24; i++) {
    const below = i % 4 === 3;
    // The sea under the island is flat stratocumulus: towers would poke up
    // through the soil and rise in front of the village.
    const geo = cloudGeometry(rnd, { flat: below });
    geo.computeBoundingBox();
    const m = new THREE.Mesh(geo, cloudMat);
    m.userData = below
      ? { below, top: geo.boundingBox.max.y, ang: rnd() * Math.PI * 2, rad: 12 + rnd() * 30, y: -15 - rnd() * 5, speed: 0.01 + rnd() * 0.015, s: 1.6 + rnd() * 1.2, order: 0 }
      : { below, x: (rnd() - 0.5) * 130, z: -30 - rnd() * 34, y: 6 + rnd() * 14, speed: 0.6 + rnd() * 0.8, s: 1.0 + rnd() * 1.1, order: rnd() };
    m.castShadow = false; m.receiveShadow = false;
    group.add(m); clouds.push(m);
  }

  // Cloud shadows: puffs high over the island that only the sun's shadow
  // map sees (no colour, no depth), so they dapple the village without
  // ever hiding it from the camera.
  const shadowMat = new THREE.MeshBasicMaterial({ colorWrite: false, depthWrite: false });
  const shadowClouds = [];
  for (let i = 0; i < 9; i++) {
    const m = new THREE.Mesh(cloudGeometry(rnd, { shade: false, detail: 1 }), shadowMat);
    m.castShadow = true; m.receiveShadow = false;
    m.userData = { x: (rnd() - 0.5) * 70, z: (rnd() - 0.5) * 36, order: i / 9, s: 1.6 + rnd() * 1.4, speed: 0.8 + rnd() * 0.6 };
    m.position.y = 24;
    group.add(m); shadowClouds.push(m);
  }

  const rain = makeRain(2600);
  const snow = makePoints(2600, 'snow', { color: 0xffffff, size: 0.55, seedRnd: 3 });
  const petals = makePoints(200, 'leaf', { size: 0.6, tints: [0xf9a8d4, 0xfbcfe8, 0xffffff], seedRnd: 4 });
  const leaves = makePoints(200, 'leaf', { size: 0.8, tints: [0xf2994a, 0xe8b33a, 0xd9662b, 0xf5c04a], seedRnd: 6 });
  const fireflies = makePoints(140, 'firefly', { size: 0.9, seedRnd: 7 });
  const mist = fallPos ? makePoints(90, 'mist', { size: 3.5, seedRnd: 8, origin: fallPos }) : null;
  group.add(rain, snow, petals, leaves, fireflies);
  if (mist) group.add(mist);

  // Lightning bolt: a jagged line far behind the island.
  const boltGeo = new THREE.BufferGeometry();
  const boltMat = new THREE.LineBasicMaterial({ color: 0xeaf2ff, transparent: true, opacity: 0, fog: false });
  const bolt = new THREE.Line(boltGeo, boltMat);
  bolt.frustumCulled = false;
  group.add(bolt);
  function regenBolt() {
    const pts = []; const a = (rnd() - 0.5) * 2.2;
    let x = Math.sin(a) * 70, z = -Math.cos(a) * 70 - 10, y = 45;
    for (let i = 0; i < 14; i++) { pts.push(new THREE.Vector3(x, y, z)); x += (rnd() - 0.5) * 5; y -= 4.5; z += (rnd() - 0.5) * 3; }
    boltGeo.setFromPoints(pts);
  }

  const state = { kind: 'clear', season: 'summer', mix: { ...WEATHER.clear }, flash: 0, nextFlash: 3 };

  function set(kind, season) {
    state.kind = kind; state.season = season;
  }

  function update(dt, t, { light, night, motion, pixel }) {
    const target = WEATHER[state.kind];
    for (const key of Object.keys(target)) state.mix[key] = THREE.MathUtils.damp(state.mix[key], target[key], motion ? 1.6 : 50, dt);
    const w = state.mix;
    U.uWind.value = w.wind;

    // Clouds
    const grey = new THREE.Color(0xffffff).lerp(new THREE.Color(0x8d97ab), w.dark);
    cloudMat.color.copy(grey).multiply(light);
    cloudMat.emissive.copy(light).lerp(new THREE.Color(1, 1, 1), 0.2).multiplyScalar(0.72);
    cloudMat.emissiveIntensity = 0.85 * (1 - w.dark * 0.6);
    clouds.forEach((c) => {
      const u = c.userData;
      if (u.below) {
        if (motion) u.ang += dt * u.speed;
        // Keep the whole cloud under the island's rocky tip (~y -12), measured
        // from its real top at its current size, so it can never touch the soil.
        const y = Math.min(u.y, CLOUD_SEA_CEIL - u.top * (c.scale.x || 1));
        c.position.set(Math.cos(u.ang) * u.rad, y, Math.sin(u.ang) * u.rad * 0.8);
        c.rotation.y = -u.ang;
      } else {
        if (motion) u.x += dt * u.speed * (0.4 + w.wind * 1.6);
        if (u.x > 70) u.x -= 140;
        c.position.set(u.x, u.y, u.z);
      }
      const shown = u.below || u.order * 18 < w.clouds;
      const s = u.s * (1 + w.dark * 0.35);
      c.scale.setScalar(THREE.MathUtils.damp(c.scale.x || 0.001, shown ? s : 0.001, motion ? 2 : 50, dt));
      c.visible = c.scale.x > 0.01;
    });

    const shadowCount = state.kind === 'clear' ? 0.12 : w.cloud * 1.0;
    for (const c of shadowClouds) {
      const u = c.userData;
      if (motion) u.x += dt * u.speed * (0.5 + w.wind * 1.5);
      if (u.x > 40) u.x -= 80;
      c.position.set(u.x, 24, u.z);
      const on = u.order < shadowCount;
      const sc = THREE.MathUtils.damp(c.scale.x || 0.001, on ? u.s : 0.001, motion ? 2 : 50, dt);
      c.scale.set(sc, sc * 0.5, sc);
      c.visible = sc > 0.02;
    }
    const lightOnly = light;
    rain.material.uniforms.uOpacity.value = w.rain * 0.85;
    rain.material.uniforms.uLight.value.copy(lightOnly);
    rain.visible = w.rain > 0.02;
    rain.geometry.setDrawRange(0, Math.floor(2600 * 2 * Math.min(1, w.rain)));

    snow.material.uniforms.uOpacity.value = Math.min(1, w.snow * 1.2);
    snow.material.uniforms.uLight.value.copy(light);
    snow.material.uniforms.uPixel.value = pixel;
    snow.visible = w.snow > 0.02;

    const sp = state.season;
    const calm = 1 - Math.min(1, w.rain + w.snow);
    petals.visible = sp === 'spring' && calm > 0.2;
    petals.material.uniforms.uOpacity.value = calm;
    leaves.visible = sp === 'autumn' && calm > 0.2;
    leaves.material.uniforms.uOpacity.value = calm;
    for (const p of [petals, leaves]) { p.material.uniforms.uLight.value.copy(light); p.material.uniforms.uPixel.value = pixel; }
    fireflies.visible = (sp === 'summer' || sp === 'spring') && night > 0.4 && w.rain < 0.3;
    fireflies.material.uniforms.uOpacity.value = Math.min(1, (night - 0.4) * 2) * (1 - w.rain);
    fireflies.material.uniforms.uPixel.value = pixel;
    if (mist) {
      mist.material.uniforms.uLight.value.copy(light);
      mist.material.uniforms.uPixel.value = pixel;
      mist.visible = state.season !== 'winter';
    }

    // Lightning: only in a storm, only with motion allowed, and never a
    // strobe — one soft swell every several seconds.
    if (state.kind === 'storm' && motion) {
      state.nextFlash -= dt;
      if (state.nextFlash <= 0) { state.flash = 1; state.nextFlash = 5 + rnd() * 6; regenBolt(); }
    }
    state.flash = Math.max(0, state.flash - dt * 2.2);
    boltMat.opacity = state.flash > 0.55 ? (state.flash - 0.55) * 2.2 : 0;
    bolt.visible = boltMat.opacity > 0.01;
    return state.flash * 0.6;
  }

  return { group, set, update, state };
}
