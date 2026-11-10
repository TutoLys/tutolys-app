// Renderer, camera and controls: orbit/zoom/pan with damping, limits that
// keep the island framed, smooth camera flights to a building, picking,
// keyboard control, and an adaptive quality step if the frame rate sags.
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/addons/RoomEnvironment.js';
import { ease } from './fx.js';

export const HOME = { target: new THREE.Vector3(0, 0.6, 1.2), azimuth: 0.0, polar: 1.0, distance: 72 };

export function createStage(container) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance', preserveDrawingBuffer: false });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.NeutralToneMapping;
  renderer.toneMappingExposure = 1.0;
  container.appendChild(renderer.domElement);
  renderer.domElement.setAttribute('aria-hidden', 'true');

  const scene = new THREE.Scene();
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;

  const camera = new THREE.PerspectiveCamera(30, 1, 0.5, 1500);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.07;
  controls.minDistance = 20;
  controls.maxDistance = 125;
  controls.minPolarAngle = 0.32;
  controls.maxPolarAngle = 1.3;
  controls.rotateSpeed = 0.6;
  controls.zoomSpeed = 0.9;
  controls.panSpeed = 0.8;
  controls.screenSpacePanning = false;
  controls.zoomToCursor = true;

  function placeCamera({ target, azimuth, polar, distance }) {
    controls.target.copy(target);
    camera.position.set(
      target.x + distance * Math.sin(polar) * Math.sin(azimuth),
      target.y + distance * Math.cos(polar),
      target.z + distance * Math.sin(polar) * Math.cos(azimuth),
    );
    camera.lookAt(target);
    controls.update();
  }
  // Keep the target over the island.
  controls.addEventListener('change', () => {
    const t = controls.target;
    const r = Math.hypot(t.x / 16, t.z / 12);
    if (r > 1) { t.x /= r; t.z /= r; }
    t.y = THREE.MathUtils.clamp(t.y, -2, 6);
  });

  // --- camera flights ---
  let flight = null;
  function flyTo(dest, { duration = 1100, instant = false } = {}) {
    const from = {
      target: controls.target.clone(),
      offset: camera.position.clone().sub(controls.target),
    };
    const sph = new THREE.Spherical().setFromVector3(from.offset);
    const to = {
      target: dest.target.clone(),
      azimuth: dest.azimuth ?? sph.theta,
      polar: dest.polar ?? sph.phi,
      distance: dest.distance ?? sph.radius,
    };
    // Shortest way round.
    let dAz = to.azimuth - sph.theta;
    dAz = Math.atan2(Math.sin(dAz), Math.cos(dAz));
    flight = { t: 0, duration: instant ? 1 : duration, from, sph, to, dAz };
    if (instant) stepFlight(1000);
  }
  function stepFlight(dtMs) {
    if (!flight) return false;
    flight.t = Math.min(1, flight.t + dtMs / flight.duration);
    const k = ease.inOutCubic(flight.t);
    const { from, sph, to, dAz } = flight;
    const target = from.target.clone().lerp(to.target, k);
    const az = sph.theta + dAz * k;
    const polar = sph.phi + (to.polar - sph.phi) * k;
    const dist = sph.radius + (to.distance - sph.radius) * k;
    controls.target.copy(target);
    camera.position.set(
      target.x + dist * Math.sin(polar) * Math.sin(az),
      target.y + dist * Math.cos(polar),
      target.z + dist * Math.sin(polar) * Math.cos(az),
    );
    camera.lookAt(target);
    if (flight.t >= 1) flight = null;
    return true;
  }
  controls.addEventListener('start', () => { flight = null; });

  /** Nudge the orbit from the keyboard or the on-screen buttons. */
  function nudge({ az = 0, polar = 0, zoom = 1 }, instant = false) {
    const off = camera.position.clone().sub(controls.target);
    const sph = new THREE.Spherical().setFromVector3(off);
    flyTo({
      target: controls.target,
      azimuth: sph.theta + az,
      polar: THREE.MathUtils.clamp(sph.phi + polar, controls.minPolarAngle, controls.maxPolarAngle),
      distance: THREE.MathUtils.clamp(sph.radius * zoom, controls.minDistance, controls.maxDistance),
    }, { duration: 420, instant });
  }

  // --- picking ---
  const ray = new THREE.Raycaster();
  const ndc = new THREE.Vector2();
  function pick(clientX, clientY, objects) {
    const r = renderer.domElement.getBoundingClientRect();
    ndc.set(((clientX - r.left) / r.width) * 2 - 1, -((clientY - r.top) / r.height) * 2 + 1);
    ray.setFromCamera(ndc, camera);
    const hits = ray.intersectObjects(objects, true);
    return hits[0] || null;
  }

  function resize() {
    const w = container.clientWidth, h = container.clientHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    // Narrow screens: widen the view so the whole island still fits.
    camera.fov = w / h < 0.8 ? 50 : w / h < 1.25 ? 36 : 30;
    // Lift the island a little: the bottom of the screen holds the
    // ambience and recommendation cards, the top only the sign.
    const lift = w > 720 ? Math.round(h * 0.06) : -Math.round(h * 0.02);
    const a = w / h;
    // Fit the island to the screen, whatever its shape: the distance at which
    // the island's width (and its height, seen at this tilt) fits the view.
    HOME.polar = a < 0.8 ? 0.78 : a < 1.25 ? 0.9 : 1.0;
    const tv = Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)), th = tv * a;
    const halfW = a < 0.8 ? 21.5 : 27.5;                     // phones crop a sliver of rim
    const halfH = 19 * Math.cos(HOME.polar) + 6.5 * Math.sin(HOME.polar) + 4;
    HOME.distance = THREE.MathUtils.clamp(Math.max(halfW / th, halfH / tv) * 1.02, 55, 150);
    controls.maxDistance = Math.max(125, HOME.distance * 1.3);
    camera.setViewOffset(w, h, 0, lift, w, h);
    camera.updateProjectionMatrix();
  }
  window.addEventListener('resize', resize);
  resize();
  placeCamera(HOME);

  // --- adaptive quality ---
  // Phones and tablets start one step lighter (pixel ratio ≤ 1.5, smaller
  // shadow map); any device steps down after ~1.5 s under 45 fps.
  const touch = window.matchMedia('(pointer: coarse)').matches;
  const perf = { fps: 60, samples: [], low: 0, level: 2, onLevel: null };
  function applyLevel() {
    const dpr = window.devicePixelRatio || 1;
    renderer.setPixelRatio(perf.level === 2 ? Math.min(dpr, 2) : perf.level === 1 ? Math.min(dpr, 1.5) : Math.min(dpr, 1));
    const type = perf.level === 0 ? THREE.PCFShadowMap : THREE.PCFSoftShadowMap;
    if (renderer.shadowMap.type !== type) {
      renderer.shadowMap.type = type;
      scene.traverse((o) => { if (o.material) [].concat(o.material).forEach((m) => { m.needsUpdate = true; }); }); // recompile, or the change does nothing
    }
    perf.onLevel?.(perf.level);
    resize();
  }
  if (touch) { perf.level = 1; applyLevel(); }
  function trackPerf(dt) {
    perf.samples.push(dt);
    if (perf.samples.length > 40) perf.samples.shift();
    const avg = perf.samples.reduce((a, b) => a + b, 0) / perf.samples.length;
    perf.fps = 1 / Math.max(avg, 1e-4);
    if (perf.samples.length === 40 && perf.fps < 45 && perf.level > 0) {
      perf.low += dt;
      if (perf.low > 1.5) { perf.level -= 1; perf.low = 0; perf.samples.length = 0; applyLevel(); }
    } else perf.low = 0;
  }

  return { renderer, scene, camera, controls, placeCamera, flyTo, stepFlight, nudge, pick, resize, perf, trackPerf, applyLevel, touch };
}
