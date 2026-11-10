// Time of day: the sky dome, sun and moon, hemisphere light, stars and fog.
// A day is a set of keyframes (dawn, day, sunset, dusk, night) blended by
// the hour; weather then dims and greys whatever the hour gave.
import * as THREE from 'three';
import { U } from './fx.js';
import { softDotTexture } from './textures.js';

const C = (h) => new THREE.Color(h);
const KEYS = {
  night: { top: C(0x0b1638), hor: C(0x2a3d78), bot: C(0x16224a), sun: C(0x9fb6ff), sunI: 0.55, hs: C(0x4a5f9e), hg: C(0x1c2440), hI: 0.5, env: 0.12, night: 1, water: C(0x5a6fa8) },
  dawn: { top: C(0x8fb3ec), hor: C(0xffd2b0), bot: C(0xf3d9cc), sun: C(0xffc49a), sunI: 1.6, hs: C(0xcfdcff), hg: C(0xc8a890), hI: 0.6, env: 0.32, night: 0.2, water: C(0xffe2d0) },
  day: { top: C(0x9fd3ff), hor: C(0xeaf6ff), bot: C(0xdcebf8), sun: C(0xfff3df), sunI: 2.3, hs: C(0xdbeeff), hg: C(0x9bbc92), hI: 0.7, env: 0.38, night: 0, water: C(0xffffff) },
  sunset: { top: C(0x5a6fc0), hor: C(0xffb078), bot: C(0xf0c2a8), sun: C(0xff9a5a), sunI: 1.8, hs: C(0xffc6a8), hg: C(0x8a7aa0), hI: 0.55, env: 0.28, night: 0.3, water: C(0xffc9a0) },
  dusk: { top: C(0x1f2a66), hor: C(0x7a5fa0), bot: C(0x34366a), sun: C(0xb0c0ff), sunI: 0.6, hs: C(0x6a6fae), hg: C(0x2a2a50), hI: 0.55, env: 0.22, night: 0.8, water: C(0x8a86c0) },
};
const TIMELINE = [
  [0, 'night'], [5, 'night'], [6.5, 'dawn'], [8.5, 'day'], [16.5, 'day'], [18.5, 'sunset'], [20, 'dusk'], [21.5, 'night'], [24, 'night'],
];

export function phaseName(h) {
  if (h < 5 || h >= 21) return 'night';
  if (h < 8) return 'dawn';
  if (h < 17) return 'day';
  if (h < 19.5) return 'sunset';
  return 'dusk';
}

function sample(h) {
  let i = 0;
  while (i < TIMELINE.length - 2 && h >= TIMELINE[i + 1][0]) i++;
  const [h0, k0] = TIMELINE[i]; const [h1, k1] = TIMELINE[i + 1];
  const t = THREE.MathUtils.smoothstep(h, h0, h1);
  const a = KEYS[k0], b = KEYS[k1];
  const out = {};
  for (const key of Object.keys(a)) {
    out[key] = a[key].isColor ? a[key].clone().lerp(b[key], t) : a[key] + (b[key] - a[key]) * t;
  }
  return out;
}

export function createAtmosphere(scene, renderer) {
  // Sky dome
  const skyMat = new THREE.ShaderMaterial({
    uniforms: {
      uTop: { value: new THREE.Color() }, uHor: { value: new THREE.Color() }, uBot: { value: new THREE.Color() },
      uSunDir: { value: new THREE.Vector3(0, 1, 0) }, uSunCol: { value: new THREE.Color() }, uSunGlow: { value: 1 },
      uFlash: { value: 0 },
    },
    vertexShader: 'varying vec3 vDir; void main(){ vDir = normalize(position); vec4 p = projectionMatrix * modelViewMatrix * vec4(position,1.0); gl_Position = p.xyww; }',
    fragmentShader: `uniform vec3 uTop, uHor, uBot, uSunCol, uSunDir; uniform float uSunGlow, uFlash; varying vec3 vDir;
      void main(){
        float y = vDir.y;
        vec3 col = y > 0.0 ? mix(uHor, uTop, pow(smoothstep(0.0, 0.75, y), 0.8)) : mix(uHor, uBot, smoothstep(0.0, -0.5, y));
        float s = max(dot(normalize(vDir), normalize(uSunDir)), 0.0);
        col += uSunCol * (pow(s, 64.0) * 0.6 + pow(s, 6.0) * 0.18) * uSunGlow;
        col += vec3(0.75, 0.82, 1.0) * uFlash * 0.55;
        gl_FragColor = vec4(col, 1.0);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
    side: THREE.BackSide, depthWrite: false, depthTest: true, fog: false, toneMapped: false,
  });
  const sky = new THREE.Mesh(new THREE.SphereGeometry(600, 32, 16), skyMat);
  sky.renderOrder = -10;
  sky.frustumCulled = false;
  scene.add(sky);

  // Stars
  const N = 1400;
  const sp = new Float32Array(N * 3); const ss = new Float32Array(N);
  for (let i = 0; i < N; i++) {
    const u = Math.random() * 2 - 1, th = Math.random() * Math.PI * 2;
    const y = Math.abs(u) * 0.95 + 0.05; const r = Math.sqrt(1 - y * y);
    sp.set([Math.cos(th) * r * 500, y * 500, Math.sin(th) * r * 500], i * 3);
    ss[i] = Math.random();
  }
  const starGeo = new THREE.BufferGeometry();
  starGeo.setAttribute('position', new THREE.BufferAttribute(sp, 3));
  starGeo.setAttribute('seed', new THREE.BufferAttribute(ss, 1));
  const starMat = new THREE.ShaderMaterial({
    uniforms: { uTime: U.uTime, uOpacity: { value: 0 }, uMap: { value: softDotTexture() } },
    vertexShader: `attribute float seed; varying float vS; uniform float uTime;
      void main(){ vS = seed; vec4 mv = modelViewMatrix * vec4(position,1.0); gl_Position = projectionMatrix * mv;
        gl_PointSize = (1.4 + seed * 2.6) * (0.75 + 0.25 * sin(uTime * (1.0 + seed * 3.0) + seed * 40.0)); }`,
    fragmentShader: `uniform float uOpacity; uniform sampler2D uMap; varying float vS;
      void main(){ vec4 t = texture2D(uMap, gl_PointCoord); gl_FragColor = vec4(mix(vec3(0.8,0.88,1.0), vec3(1.0,0.95,0.8), vS), t.a * uOpacity); }`,
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, fog: false,
  });
  const stars = new THREE.Points(starGeo, starMat);
  stars.frustumCulled = false;
  scene.add(stars);

  // Moon and its halo
  const moon = new THREE.Mesh(new THREE.SphereGeometry(9, 24, 16), new THREE.MeshBasicMaterial({ color: 0xf4f1e2, fog: false, transparent: true }));
  const moonHalo = new THREE.Sprite(new THREE.SpriteMaterial({ map: softDotTexture(), color: 0xaec4ff, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, fog: false }));
  moonHalo.scale.setScalar(60);
  moon.add(moonHalo);
  scene.add(moon);

  // Lights
  const hemi = new THREE.HemisphereLight(0xdbeeff, 0xa8c49e, 1);
  scene.add(hemi);
  const sun = new THREE.DirectionalLight(0xffffff, 2.5);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  const sc = sun.shadow.camera; sc.left = -31; sc.right = 31; sc.top = 26; sc.bottom = -26; sc.near = 1; sc.far = 140;
  sc.updateProjectionMatrix();
  sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.035; sun.shadow.radius = 3;
  scene.add(sun, sun.target);
  // A soft rim fill from the opposite side, so shadowed facades never go flat.
  const fill = new THREE.DirectionalLight(0xbcd4ff, 0.35);
  fill.position.set(-30, 18, -25);
  scene.add(fill);

  scene.fog = new THREE.Fog(0xeaf6ff, 90, 260);

  const state = { hour: 10, cloud: 0, flash: 0, water: new THREE.Color(1, 1, 1), night: 0, phase: 'day' };

  function update(hour, cloud, flash = 0, dark = 0, mist = 0, camDist = 80) {
    state.hour = hour; state.cloud = cloud; state.flash = flash;
    const k = sample(hour);
    const grey = (c, amt) => { const l = c.r * 0.3 + c.g * 0.59 + c.b * 0.11; return c.lerp(new THREE.Color(l, l * 1.02, l * 1.08).multiplyScalar(0.92), amt); };
    const cg = cloud * 0.65;
    const stormTint = new THREE.Color(0x46526c);
    skyMat.uniforms.uTop.value.copy(grey(k.top, cg)).lerp(stormTint, dark * 0.8);
    skyMat.uniforms.uHor.value.copy(grey(k.hor, cg)).lerp(stormTint, dark * 0.65);
    skyMat.uniforms.uBot.value.copy(grey(k.bot, cg)).lerp(stormTint, dark * 0.7);
    skyMat.uniforms.uFlash.value = flash;

    // Sun path: rises at 6 h on the right, crosses the front, sets at 18 h.
    const a = ((hour - 6) / 12) * Math.PI;
    const sunDir = new THREE.Vector3(Math.cos(a) * 0.9, Math.sin(a), 0.55).normalize();
    const am = ((hour - 18) / 12) * Math.PI;
    const moonDir = new THREE.Vector3(Math.cos(am) * 0.8, Math.sin(am) * 0.9 + 0.12, -0.45).normalize();
    const sunUp = sunDir.y > 0.02;
    const lightDir = (sunUp ? sunDir : moonDir).clone();
    lightDir.y = Math.max(lightDir.y, 0.22); lightDir.normalize();
    sun.position.copy(lightDir).multiplyScalar(60);
    sun.target.position.set(0, 0, 0);
    sun.color.copy(k.sun);
    sun.intensity = k.sunI * (1 - cloud * 0.55) * (1 - dark * 0.45) + flash * 2.5;
    skyMat.uniforms.uSunDir.value.copy(sunUp ? sunDir : moonDir);
    skyMat.uniforms.uSunCol.value.copy(k.sun);
    skyMat.uniforms.uSunGlow.value = (sunUp ? 1 : 0.25) * (1 - cloud * 0.85);

    hemi.color.copy(k.hs); hemi.groundColor.copy(k.hg);
    hemi.intensity = k.hI * (1 - cloud * 0.12) * (1 - dark * 0.3) + flash * 1.2;
    fill.intensity = 0.35 * (1 - k.night * 0.6);
    scene.environmentIntensity = k.env * (1 - cloud * 0.3) * (1 - dark * 0.5);

    const fogCol = skyMat.uniforms.uHor.value.clone().lerp(skyMat.uniforms.uBot.value, 0.3);
    scene.fog.color.copy(fogCol);
    scene.fog.near = THREE.MathUtils.lerp(95, 45, cloud);
    scene.fog.far = THREE.MathUtils.lerp(280, 150, cloud);
    // Fog weather: a pale veil measured from the camera, so it reads the
    // same on a phone (closer camera) as on a desktop. The island's middle
    // stays readable; its far side and the sky beyond fade out.
    if (mist > 0.001) {
      const l = fogCol.r * 0.3 + fogCol.g * 0.59 + fogCol.b * 0.11;
      scene.fog.color.lerp(new THREE.Color(l, l * 1.01, l * 1.04).multiplyScalar(1.12), mist * 0.75);
      scene.fog.near = THREE.MathUtils.lerp(scene.fog.near, camDist * 0.5, mist);
      scene.fog.far = THREE.MathUtils.lerp(scene.fog.far, camDist * 1.55, mist);
    }

    starMat.uniforms.uOpacity.value = Math.max(0, k.night - 0.25) * (1 - cloud * 0.95) * 1.2;
    moon.position.copy(moonDir).multiplyScalar(420);
    moon.material.opacity = Math.max(0, k.night - 0.2) * (1 - cloud * 0.8);
    moonHalo.material.opacity = moon.material.opacity * 0.5;
    moon.visible = moon.material.opacity > 0.01 && moonDir.y > 0;

    state.water.copy(k.water).lerp(new THREE.Color(0.75, 0.8, 0.88), cloud * 0.4);
    state.night = k.night;
    state.phase = phaseName(hour);
    U.uNight.value = k.night;
    renderer.toneMappingExposure = (1.0 + k.night * 0.15) * (1 - dark * 0.28);
  }

  return { update, state, sun, hemi, sky, stars, moon };
}
