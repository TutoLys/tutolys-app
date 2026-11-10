// Village des Lys 3D — wiring. Owns the scene state (hour, season,
// weather, motion, selection) and runs the frame loop; every module below
// is self-contained so it can be lifted into the app later.
import * as bridge from './bridge.js';
import * as THREE from 'three';
import { quebecNow, quebecSeason } from './strings.js';
import { kindFor, isFresh, calmFor, KINDS } from './realweather.js';
import { createStage, HOME } from './scene.js';
import { buildIsland, applySeason, updateIsland, buildingSpots, plazaY, pathCurves, heightAt } from './island.js';
import { createBuilding, updateBuilding, setWinter, buildingMaterials, plinthGreen, relabelSigns, adoptProp } from './buildings.js';
import { createAtmosphere } from './atmosphere.js';
import { createWeather } from './weather.js';
import { createFox, createFoxController } from './fox.js';
import { loadModels } from './models.js';
import { createPortal, PORTAL_MS, PORTAL_REDUCED_MS } from './portal.js';
import { createUI, hourLabel, PHASE_FR, SEASON_FR, WEATHER_FR } from './ui.js';
import { U } from './fx.js';
import { PLAZA, LEARNER, PROPS } from './data.js';

const params = new URLSearchParams(location.search);
const embedded = bridge.embedded;
// Embedded, the app owns persistence: the scene stores nothing.
const store = embedded ? { get: (k, d) => d, set() {} } : {
  get(k, d) { try { const v = localStorage.getItem('v3d.' + k); return v == null ? d : JSON.parse(v); } catch { return d; } },
  set(k, v) { try { localStorage.setItem('v3d.' + k, JSON.stringify(v)); } catch { /* private mode */ } },
};
const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
if (embedded) document.documentElement.dataset.embed = '1';
// Touch screens get bigger targets. `pointer: coarse` isn't reported inside
// some iframes and emulators, so a touch point count counts too.
if (navigator.maxTouchPoints > 0 || window.matchMedia('(pointer: coarse)').matches) document.documentElement.dataset.touch = '1';
window.addEventListener('error', (e) => bridge.send('error', { message: String(e.message || e.error || 'error').slice(0, 300) }));
window.addEventListener('unhandledrejection', (e) => bridge.send('error', { message: String(e.reason?.message || e.reason || 'rejection').slice(0, 300) }));
const num = (v, d) => (v == null || v === '' || Number.isNaN(parseFloat(v)) ? d : parseFloat(v));

// Time and season follow Québec's real clock and calendar by default
// ("live"); the child (standalone ambience panel, or the app through the
// bridge) can set either, and "Maintenant" / `setTime{hour:null}` returns
// to live. Weather is always manual.
const now = () => quebecNow(params.get('now'));
const nowMs = () => Date.now();
// Live time is daytime only (Hafid, 2026-11-10): before 7:00 the village
// shows 7:00 light, after 20:00 it shows 20:00 light, so a child opening the
// app before school never meets a dark, murky village. Night is still there
// when the child picks it by hand (or the host sends `setTime`).
const LIVE_DAY = [7, 20];
const liveHour = () => Math.min(LIVE_DAY[1], Math.max(LIVE_DAY[0], now().hour));
const fixedHour = params.has('t') ? num(params.get('t'), 10.5) : store.get('hour', null);
const fixedSeason = params.get('season') || store.get('season', null);
const state = {
  hour: fixedHour ?? liveHour(),
  hourLive: fixedHour == null,
  hourTarget: null,
  season: fixedSeason || quebecSeason(now().month),
  seasonLive: !fixedSeason,
  // Weather follows the real observation the host sends (`weather` in
  // init/update); without a fresh one, a calm sky for the season. A hand
  // pick (Ambiance, or the host's setWeather) holds for the visit.
  weather: params.get('weather') || store.get('weather', null) || 'clear',
  weatherMode: params.get('weather') || store.get('weather', null) ? 'manual' : 'auto',
  hostWeather: null,
  reducedPref: params.has('reduced') ? params.get('reduced') === '1' : store.get('reduced', null),
  auto: params.get('auto') === '1',
  selected: null,
  hovered: null,
};
// The host's reduced-motion flag is OR-ed with the OS setting, never replaces it.
const reduced = () => (state.reducedPref == null ? mq.matches : state.reducedPref) || mq.matches;

// ---------- build ----------
// Canvas textures (π, signposts) are drawn in Baloo 2: wait for it, briefly.
try {
  await Promise.race([
    Promise.all(['800 40px "Baloo 2"', '700 30px "Baloo 2"'].map((f) => document.fonts.load(f))),
    new Promise((r) => setTimeout(r, 1500)),
  ]);
} catch { /* fall back to the system face */ }
// No WebGL (blocked GPU, old device): say so kindly and offer the 2D village.
function webglOK() {
  try { const c = document.createElement('canvas'); return !!(c.getContext('webgl2') || c.getContext('webgl')); } catch { return false; }
}
let stage;
try { if (!webglOK()) throw new Error('no webgl'); stage = createStage(document.getElementById('stage')); } catch (e) {
  bridge.send('unavailable', { reason: e.message === 'no webgl' ? 'webgl' : 'setup', message: String(e.message).slice(0, 300) });
  const l = document.getElementById('loading');
  // Stop here without throwing (a throw would also post `error`); the app
  // swaps in its 2D village.
  if (embedded) { l.hidden = true; await new Promise(() => {}); }
  l.innerHTML = `<img src="assets/img/asset-mascot-welcome.webp" alt=""><strong>Le village 3D ne peut pas s’afficher sur cet appareil.</strong>
    <span class="nogl-sub">La 3D n’est pas disponible ici. Le village habituel, lui, fonctionne.</span>
    <a class="btn-gold" href="index.html#classique" target="_top">Aller au village actuel</a>`;
  l.classList.add('nogl');
  document.querySelectorAll('.hud-top, .quest-panel, .ambience, .cam-controls, .recommend-bar, .hint').forEach((n) => { n.hidden = true; });
  console.info('Village 3D: WebGL unavailable, showing the fallback.', e.message);
  throw e;
}
const { scene, camera, renderer, controls } = stage;
let frameNo = 0;
const atmo = createAtmosphere(scene, renderer);
// Quality level drives the sun's shadow-map size too (phones start at level 1).
stage.perf.onLevel = (lvl) => {
  const sz = lvl === 2 ? 2048 : lvl === 1 ? 1024 : 768;
  const sh = atmo.sun.shadow;
  if (sh.mapSize.x !== sz) { sh.mapSize.set(sz, sz); if (sh.map) { sh.map.dispose(); sh.map = null; } }
};
stage.perf.onLevel(stage.perf.level);
const island = buildIsland();
scene.add(island.root);

const [models, init] = await Promise.all([
  loadModels({ enabled: params.get('models') !== '0' }),
  embedded && params.get('demo') !== '1' ? bridge.waitInit() : Promise.resolve(null),
]);
// Which buildings stand, with the host's labels and progress. An English-
// language school's EN and FLS take ESL's and FR's plots (as the app's own
// `_plots` does); the first building sent for a plot wins it.
const PLOT_ALIAS = { EN: 'ESL', FLS: 'FR' };
function spotsFrom(list) {
  if (!list) return buildingSpots.map((s) => ({ ...s, live: true }));
  const used = new Set(); const out = [];
  for (const h of list) {
    const base = buildingSpots.find((s) => s.id === (PLOT_ALIAS[h.id] || h.id));
    if (!base || used.has(base.id)) continue;
    used.add(base.id);
    out.push({ ...base, id: h.id, label: h.label ?? base.label, short: h.label ? undefined : base.short,
      progress: h.progress === undefined ? base.progress : h.progress, live: h.live !== false, soon: h.soon === true });
  }
  return out;
}
const spots = spotsFrom(init?.buildings);
const buildings = spots.map((s) => createBuilding(s, buildingSpots.findIndex((b) => b.id === s.id || b.x === s.x), models.buildings[s.kind] || null));
for (const b of buildings) scene.add(b.root);
// Props stand on the ground at their spot; on the plaza they sit on its paving.
const props = [];
for (const p of PROPS) {
  const m = models.props?.[p.name];
  if (!m) continue;
  const pr = adoptProp(m);
  const onPlaza = Math.hypot(p.x - PLAZA.x, p.z - PLAZA.z) < PLAZA.r;
  pr.root.position.set(p.x, onPlaza ? plazaY + 0.1 : heightAt(p.x, p.z), p.z);
  pr.root.rotation.y = p.rot || 0;
  pr.root.name = `prop-${p.name}`;
  scene.add(pr.root);
  props.push(pr);
}
const hitTargets = buildings.map((b) => b.hit);
const byId = new Map(buildings.map((b) => [b.id, b]));
// A building the host marks not live is drawn greyed and can't be tapped.
const GREY = new THREE.Color(0xb9c1cc);
function setLive(b, live) {
  b.spot.live = live;
  b.hit.userData.buildingId = live ? b.id : null;
  b.root.traverse((o) => {
    if (!o.isMesh || !o.material || Array.isArray(o.material)) return;
    if (!o.userData.liveMat) o.userData.liveMat = o.material;
    if (live) { o.material = o.userData.liveMat; return; }
    if (!o.userData.greyMat) {
      const g = o.userData.liveMat.clone();
      // Vertex colours dominate a tint, so wash out with grey light instead.
      if (g.color) g.color.lerp(GREY, 0.55).multiplyScalar(0.7);
      if (g.emissive) { g.emissive.copy(GREY); g.emissiveIntensity = 0.42; }
      o.userData.greyMat = g;
    }
    o.material = o.userData.greyMat;
  });
}
for (const b of buildings) if (b.spot.live === false) setLive(b, false);
const greeting = { text: init?.greeting ?? null };
if (init?.lang) document.documentElement.lang = init.lang;
if (init && typeof init.reduced === 'boolean') state.reducedPref = init.reduced;

const weather = createWeather(scene, { fallPos: island.seasonal.fall?.pos });

// Night lights: a few real point lights near the plaza and doors; every
// other lamp only glows.
const nightLights = [];
for (const spot of [{ x: PLAZA.x, z: PLAZA.z + 0.5, y: plazaY + 3 }, ...buildingSpots.filter((s) => !s.small).map((s) => ({ x: s.x, z: s.z + s.r + 0.6, y: s.y + 1.8 }))]) {
  const l = new THREE.PointLight(0xffc56b, 0, 11, 1.6);
  l.position.set(spot.x, spot.y, spot.z);
  scene.add(l); nightLights.push(l);
}

// Foxes
// A fox from fox.glb when it loaded, else the procedural one; same clips.
function makeFox(scale) {
  if (models.fox) {
    const obj = models.fox.scene.clone(true);
    obj.traverse((o) => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
    obj.scale.setScalar(scale);
    return { obj, clips: models.fox.animations };
  }
  const obj = createFox({ scale });
  return { obj, clips: obj.animations };
}
const foxMade = makeFox(1.55);
const fox = foxMade.obj;
const foxCtl = createFoxController(fox, foxMade.clips);
fox.position.set(PLAZA.x + 0.9, plazaY + 0.12, PLAZA.z + 1.9);
scene.add(fox);
fox.traverse((o) => { if (o.isMesh) o.userData.fox = true; });
const kitMade = makeFox(0.75);
const kit = kitMade.obj;
const kitCtl = createFoxController(kit, kitMade.clips);
scene.add(kit);
const walker = { path: 0, t: 0, dir: 1, pause: 1.5, yaw: 0 };

const foxHeadNode = fox.getObjectByName('head') || fox;
const foxState = { yaw: 0, wave: 0, waveT: 2.0, hop: 0, hopping: false, look: 0 };
const foxHitGeo = new THREE.Mesh(new THREE.CylinderGeometry(0.9, 0.9, 2.4, 10), new THREE.MeshBasicMaterial({ visible: false }));
foxHitGeo.position.y = 1.2; foxHitGeo.userData.fox = true;
fox.add(foxHitGeo);

// ---------- UI ----------
const ui = createUI({
  buildings,
  strings: init?.strings,
  onNow: () => { goLive(); },
  onHover: (id, on) => setHover(on ? id : (state.hovered === id ? null : state.hovered)),
  onSelect: (id, opts) => select(id, opts),
  onCamera: (cmd) => camera_(cmd),
  onTime: (h, { animate } = {}) => {
    state.auto = false; state.hourLive = false;
    if (animate && !reduced()) state.hourTarget = h; else { state.hour = h; state.hourTarget = null; }
    store.set('hour', h);
  },
  onAuto: (on) => { state.auto = on; if (on) state.hourLive = false; },
  onSeason: (s) => setSeason(s),
  onWeather: (w) => setWeather(w),
  onReduced: (on) => { state.reducedPref = on; store.set('reduced', on); },
  onCta: (spot) => open(spot.id, { onOpen: () => ui.toast(spot.measured === false
    ? 'Prototype : ici, l’app ouvrirait ta galerie.'
    : `Prototype : ici, l’app ouvrirait la Carte · ${spot.label}.`) }),
});

// The words on the 3D signposts come from the strings too.
const relabel = () => { for (const b of buildings) relabelSigns(b.root, (kind, i) => ui.strings[`sign.${kind}.${i}`]); };
relabel();

function setHover(id) {
  if (state.hovered === id) return;
  if (state.hovered) { const b = byId.get(state.hovered); if (b) b.state.hoverT = 0; ui.setPillState(state.hovered, { hover: false }); }
  state.hovered = id;
  if (id) { const b = byId.get(id); if (b) b.state.hoverT = 1; ui.setPillState(id, { hover: true }); }
  renderer.domElement.style.cursor = id ? 'pointer' : '';
}

/** Embedded: a tap opens the subject in the app straight away. */
// ---------- the portal: tap → golden whirl on the door → `open` ----------
// Hafid (2026-11-10): "like going on a portal to another universe … a bit
// slower". The scene posts `opening{id, ms}` at the tap and `open{id}` only
// once the gold has filled the screen, so the app can't cut the effect short.
const portal = createPortal(document.getElementById('app'));
let portalB = null;
const doorWorld = (b) => b.root.localToWorld(new THREE.Vector3(0, 1.15, b.spot.r * 0.45));
function doorScreen(b) {
  const v = doorWorld(b).project(camera);
  const r = renderer.domElement.getBoundingClientRect();
  return { x: (v.x * 0.5 + 0.5) * r.width, y: (-v.y * 0.5 + 0.5) * r.height };
}
function open(id, { onOpen } = {}) {
  const b = byId.get(id);
  if (!b || b.spot.live === false || portal.busy) return;
  const red = reduced();
  bridge.send('opening', { id, ms: red ? PORTAL_REDUCED_MS : PORTAL_MS });
  if (portalB && portalB !== b) portalB.state.selT = state.selected === portalB.id ? 1 : 0;
  portalB = b;
  b.state.selT = 1; b.state.press = 1; // ring, halo, light column, doors swing open
  if (!red) {
    foxCtl.wave();
    // Push in on the door, still moving when the flash covers the screen.
    stage.flyTo({ target: doorWorld(b), azimuth: 0, polar: 0.98, distance: b.spot.small ? 9 : 10.5 }, { duration: 2100 });
  }
  portal.start({ reduced: red, center: () => doorScreen(b), onDone: () => { bridge.send('open', { id }); onOpen?.(); } });
}
// After the gold fades (the app stayed on the village) or on `resume` (it
// left and came back): back to the village as it was.
function portalEnded({ instant = false } = {}) {
  const b = portalB; portalB = null;
  if (!b) return;
  if (state.selected !== b.id) b.state.selT = 0;
  if (state.selected) select(state.selected, { from: 'pill' }); // standalone: back to the card's view
  else stage.flyTo(HOME, { instant: instant || reduced(), duration: 1400 });
}

function select(id, { from } = {}) {
  if (portal.busy) return;
  if (embedded && from !== 'host') { if (id) open(id); return; }
  if (id && state.selected === id && from !== 'pill') return;
  if (state.selected) { byId.get(state.selected).state.selT = 0; ui.setPillState(state.selected, { selected: false }); }
  state.selected = id;
  if (!id) {
    ui.hideInfo();
    if (from === 'close' || from === 'key') stage.flyTo(HOME, { instant: reduced() });
    sayDefault();
    return;
  }
  const b = byId.get(id);
  b.state.selT = 1; b.state.press = 1;
  ui.setPillState(id, { selected: true });
  if (!embedded) ui.showInfo(b.spot);
  const s = b.spot;
  stage.flyTo({
    target: new THREE.Vector3(s.x + (window.innerWidth > 900 ? 4.2 : 0), s.y + 1.4, s.z + 0.5),
    azimuth: THREE.MathUtils.clamp(s.x / 34, -0.45, 0.45),
    polar: 0.84,
    distance: window.innerWidth > 900 ? (s.small ? 38 : 44) : (s.small ? 46 : 52),
  }, { instant: reduced(), duration: 1200 });
  if (!embedded) ui.say(s.measured === false ? 'Ta galerie ! Tes dessins t’attendent.' : s.progress == null ? `On découvre ${s.label} ?` : `On continue ${s.label} ?`);
  if (!reduced()) foxCtl.wave();
}

function sayDefault() {
  // Embedded, the fox says only what the app gives it (`greeting`).
  if (embedded) { ui.say(greeting.text || ''); return; }
  const ph = atmo.state.phase;
  const w = state.weather;
  let line = `Salut ${LEARNER.name} ! Choisis un bâtiment.`;
  if (w === 'storm') line = 'Quel orage ! On reste au chaud et on apprend ?';
  else if (w === 'rain') line = 'Il pleut… parfait pour lire !';
  else if (w === 'fog') line = 'Quel brouillard ! Reste près de moi.';
  else if (w === 'snow' || state.season === 'winter') line = 'Brr ! Il fait froid au village.';
  else if (ph === 'night') line = 'Bonne nuit, petit génie !';
  else if (ph === 'dawn') line = `Bon matin ${LEARNER.name} !`;
  else if (ph === 'sunset') line = 'Quel beau coucher de soleil !';
  if (!state.selected) ui.say(line);
}

function goLive() {
  const n = now();
  state.hourLive = true; state.seasonLive = true; state.auto = false;
  store.set('hour', null); store.set('season', null);
  const h = liveHour();
  if (reduced()) { state.hour = h; state.hourTarget = null; } else state.hourTarget = h;
  setSeason(quebecSeason(n.month), { live: true });
  state.weatherMode = 'auto'; store.set('weather', null); autoWeather();
}
/** In auto mode: the host's observation if it's fresh, else calm for the season. */
function autoWeather() {
  if (state.weatherMode === 'manual') return;
  const o = state.hostWeather;
  const kind = o && isFresh(o.observed_at, nowMs()) ? kindFor(o.condition, o.temp_c) : null;
  showWeather(kind || calmFor(state.season), kind ? 'live' : 'calm');
}
function showWeather(w, source) {
  state.weatherSource = source;
  if (state.weather === w) return;
  state.weather = w;
  weather.set(w, state.season);
  sayDefault();
}
function setSeason(s, { live = false } = {}) {
  if (!['spring', 'summer', 'autumn', 'winter'].includes(s)) return;
  state.season = s; state.seasonLive = live; if (!live) store.set('season', s);
  applySeason(island.seasonal, s);
  setWinter(buildings, s === 'winter');
  for (const p of props) for (const o of p.snow) o.visible = s === 'winter';
  for (const m of plinthGreen.blooms) m.visible = s !== 'winter' && s !== 'autumn';
  plinthGreen.grass.color.setHex({ spring: 0xa2d894, summer: 0x8fcc82, autumn: 0xc2c983, winter: 0xf4f8ff }[s]);
  plinthGreen.bushMat.color.setHex(s === 'winter' ? 0xe6eef8 : s === 'autumn' ? 0xc9a043 : s === 'spring' ? 0x7cc576 : 0x5fb85a);
  weather.set(state.weather, s);
  if (state.weatherMode !== 'manual') autoWeather(); // calm depends on the season
  sayDefault();
}
/** A hand pick (holds for the visit); 'live' or null returns to the real weather. */
function setWeather(w) {
  if (w == null || w === 'live') { state.weatherMode = 'auto'; store.set('weather', null); autoWeather(); return; }
  if (!KINDS.includes(w)) return;
  state.weatherMode = 'manual'; store.set('weather', w);
  showWeather(w, 'manual');
}

function camera_(cmd) {
  const inst = reduced();
  if (cmd === 'in') stage.nudge({ zoom: 0.8 }, inst);
  else if (cmd === 'out') stage.nudge({ zoom: 1.25 }, inst);
  else if (cmd === 'left') stage.nudge({ az: -0.4 }, inst);
  else if (cmd === 'right') stage.nudge({ az: 0.4 }, inst);
  else if (cmd === 'up') stage.nudge({ polar: -0.12 }, inst);
  else if (cmd === 'down') stage.nudge({ polar: 0.12 }, inst);
  else if (cmd === 'home') { select(null); stage.flyTo(HOME, { instant: inst }); }
}

// ---------- input ----------
const el = renderer.domElement;
// What a pointer is over. Buildings have generous invisible hit volumes,
// and from the default view CCQ's stands in front of the plaza fox, so the
// fox wins whenever the ray meets it before the building's real art.
const artOwner = new Map(buildings.map((b) => [b.art, b]));
function pickAt(x, y) {
  const fh = stage.pick(x, y, [foxHitGeo]);
  // Drawn art first: the building really under the finger wins, so a tall
  // neighbour's invisible hit volume can't steal the tap (found with the
  // sand3d Anglais, whose volume covered Math's door from the home view).
  const ah = stage.pickAll(x, y, buildings.map((b) => b.art))[0];
  if (ah) {
    if (fh && fh.distance < ah.distance) return { fox: true };
    let o = ah.object; while (o && !artOwner.has(o)) o = o.parent;
    if (o) return { id: artOwner.get(o).hit.userData.buildingId || null, onBuilding: true };
  }
  const bh = stage.pick(x, y, hitTargets);
  const bid = bh?.object.userData.buildingId || null;
  if (fh && (!bh || fh.distance < bh.distance)) return { fox: true };
  if (fh && bh) {
    const art = stage.pick(x, y, [bh.object.parent]);
    const real = art && art.object !== bh.object && art.object.visible !== false && !art.object.material?.transparent ? art : null;
    if (!real || real.distance > fh.distance) return { fox: true };
  }
  return bh ? { id: bid, onBuilding: true } : null;
}
let down = null;
el.addEventListener('pointerdown', (e) => { down = { x: e.clientX, y: e.clientY, t: performance.now() }; });
el.addEventListener('pointermove', (e) => {
  if (e.pointerType === 'touch') return;
  const hit = pickAt(e.clientX, e.clientY);
  const id = hit?.id || null;
  setHover(id);
  if (hit?.fox) el.style.cursor = 'pointer';
});
el.addEventListener('pointerleave', () => setHover(null));
el.addEventListener('pointerup', (e) => {
  if (!down) return;
  const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y);
  down = null;
  if (moved > 6) return;
  const hit = pickAt(e.clientX, e.clientY);
  if (hit?.fox) foxTap();
  else if (hit?.id) select(hit.id);
  else if (hit?.onBuilding) { /* a greyed building: nothing */ }
  else if (state.selected) select(null, { from: 'empty' });
});

function foxTap() {
  if (!reduced()) foxCtl.hop();
  if (embedded) { ui.showBubble(); bridge.send('mascot'); return; }
  const lines = ['Hihi ! Ça chatouille !', 'Prêt pour une quête ?', '⚜ Vive le Village des Lys !', 'Tu es super !'];
  ui.say(lines[Math.floor(Math.random() * lines.length)]);
}

const stageEl = document.getElementById('stage');
window.addEventListener('keydown', (e) => {
  const tag = (document.activeElement?.tagName || '').toLowerCase();
  const inControl = ['input', 'select', 'textarea'].includes(tag);
  if (e.key === 'Escape') { if (state.selected) { select(null, { from: 'key' }); e.preventDefault(); } return; }
  if (e.key.toLowerCase() === 'd' && e.shiftKey) { document.getElementById('debug').hidden ^= true; return; }
  // Camera keys apply on the scene itself or a scene pill.
  const onScene = document.activeElement === stageEl || document.activeElement?.classList?.contains('scene-pill') || document.activeElement === document.body;
  if (inControl || !onScene) return;
  const map = { ArrowLeft: 'left', ArrowRight: 'right', ArrowUp: 'up', ArrowDown: 'down', '+': 'in', '=': 'in', '-': 'out', _: 'out', 0: 'home', Home: 'home' };
  const cmd = map[e.key];
  if (cmd) { camera_(cmd); e.preventDefault(); }
});

// ---------- loop ----------
const clock = new THREE.Clock();
const light = new THREE.Color();
const nightTint = new THREE.Color(0.42, 0.48, 0.72);
const foxHead = new THREE.Vector3();
let lastPhase = null; let lastSync = 0; let frames = 0; let fpsAcc = 0; let fpsShown = 0;
const debugEl = document.getElementById('debug');
if (params.get('debug') === '1') debugEl.hidden = false;

// The loop runs only while `running`: `pause` (tab hidden, app backgrounded)
// stops requesting frames entirely, `resume` restarts them.
let perfSent = false; let perfSeg = { t: 0, n: 0, last: null };
let running = true; let disposed = false; let rafId = null; let framesDrawn = 0; let liveCheck = 0;
function frame() {
  rafId = null;
  if (!running || disposed) return;
  framesDrawn++;
  const dt = Math.min(clock.getDelta(), 0.1);
  // Live time and season: re-read Québec's clock every 20 s.
  liveCheck -= dt;
  if (liveCheck <= 0 && (state.hourLive || state.seasonLive)) {
    liveCheck = 20;
    const n = now();
    if (state.hourLive && !state.auto && state.hourTarget == null) state.hour = liveHour();
    if (state.seasonLive && quebecSeason(n.month) !== state.season) setSeason(quebecSeason(n.month), { live: true });
    autoWeather(); // an observation older than 3 h falls back to calm
  }
  const motion = reduced() ? 0 : 1;
  U.uTime.value += dt * motion;
  const t = U.uTime.value;

  // Time of day
  if (state.auto && motion) state.hour = (state.hour + dt * (24 / 90)) % 24;
  if (state.hourTarget != null) {
    const d = state.hourTarget - state.hour;
    state.hour += d * Math.min(1, dt * 3.2);
    if (Math.abs(d) < 0.02) { state.hour = state.hourTarget; state.hourTarget = null; }
  }

  const flash = weather.update(dt, t, { light, night: atmo.state.night, motion, pixel: renderer.getPixelRatio() });
  atmo.update(state.hour, weather.state.mix.cloud, flash, weather.state.mix.dark, weather.state.mix.mist, camera.position.distanceTo(controls.target));
  const night = atmo.state.night;
  light.setRGB(1, 1, 1).lerp(nightTint, night).multiplyScalar(1 - weather.state.mix.cloud * 0.22);
  if (atmo.state.phase === 'sunset' || atmo.state.phase === 'dawn') light.lerp(new THREE.Color(1, 0.86, 0.75), 0.4);
  updateIsland(island.seasonal, t, atmo.state.water, night);
  buildingMaterials.window.emissiveIntensity = 0.04 + night * 2.6;
  for (const l of nightLights) l.intensity = Math.max(0, night - 0.25) * 14;
  document.documentElement.dataset.night = night > 0.5 ? '1' : '0';

  for (const b of buildings) updateBuilding(b, dt, t, motion);
  if (portal.active && !portal.update()) portalEnded();
  if (motion) for (const p of props) for (const o of p.spinners) o.rotation.y += dt * (o.userData.spinSpeed ?? 0.3);

  // Plaza fox: turn toward the selected building, wave now and then, hop on tap.
  const sel = state.selected ? byId.get(state.selected).spot : null;
  const wantYaw = sel ? Math.atan2(sel.x - fox.position.x, sel.z - fox.position.z) : 0;
  let dy = wantYaw - foxState.yaw; dy = Math.atan2(Math.sin(dy), Math.cos(dy));
  foxState.yaw += dy * Math.min(1, dt * (motion ? 4 : 100));
  fox.rotation.y = foxState.yaw;
  foxState.waveT -= dt * motion;
  if (foxState.waveT < 0) { foxCtl.wave(); foxState.waveT = 7 + Math.random() * 5; }
  foxCtl.update(dt, { motion });

  // Strolling kit
  if (motion) {
    const cur = pathCurves[walker.path].curve;
    if (walker.pause > 0) walker.pause -= dt;
    else {
      const len = cur.getLength();
      walker.t += (dt * 1.5 / len) * walker.dir;
      if (walker.t >= 1) { walker.t = 1; walker.dir = -1; walker.pause = 2.2; }
      if (walker.t <= 0) { walker.t = 0; walker.dir = 1; walker.pause = 1.2; walker.path = (walker.path + 1 + Math.floor(Math.random() * (pathCurves.length - 1))) % pathCurves.length; }
    }
  }
  {
    const cur = pathCurves[walker.path].curve;
    const p = cur.getPointAt(THREE.MathUtils.clamp(walker.t, 0, 1));
    const tg = cur.getTangentAt(THREE.MathUtils.clamp(walker.t, 0.001, 0.999)).multiplyScalar(walker.dir);
    const offset = 0.35;
    const x = p.x + -tg.z * offset, z = p.z + tg.x * offset;
    kit.position.set(x, Math.max(heightAt(x, z), island.WATER_Y + 0.42, Math.hypot(x - PLAZA.x, z - PLAZA.z) < PLAZA.r ? plazaY + 0.1 : -9) + 0.05, z);
    const want = Math.atan2(tg.x, tg.z);
    let d = want - walker.yaw; d = Math.atan2(Math.sin(d), Math.cos(d));
    walker.yaw += d * Math.min(1, dt * 6);
    kit.rotation.y = walker.yaw;
    kitCtl.update(dt, { walk: walker.pause <= 0 ? 1 : 0, motion });
  }

  if (!stage.stepFlight(dt * 1000)) controls.update();

  foxHeadNode.getWorldPosition(foxHead);
  foxHead.y += 1.3;
  ui.placeLabels(camera, renderer.domElement, foxHead);

  // Lighter quality levels re-render the shadow map every third frame only:
  // shadows barely move (sway, the strolling kit), so it halves the draw calls.
  frameNo++;
  if (stage.perf.level < 2) { renderer.shadowMap.autoUpdate = false; if (frameNo % 3 === 0) renderer.shadowMap.needsUpdate = true; }
  else renderer.shadowMap.autoUpdate = true;
  renderer.render(scene, camera);
  stage.trackPerf(dt);

  // UI sync (cheap, throttled)
  lastSync += dt;
  if (lastSync > 0.12 || atmo.state.phase !== lastPhase) {
    lastSync = 0;
    if (!embedded) ui.syncControls({ hour: state.hour, season: state.season, weather: state.weather, reduced: reduced(), auto: state.auto, live: state.hourLive && state.seasonLive, phase: atmo.state.phase, systemReduced: mq.matches });
    else document.documentElement.dataset.reduced = reduced() ? '1' : '0';
    if (atmo.state.phase !== lastPhase) { lastPhase = atmo.state.phase; sayDefault(); }
  }
  frames++; fpsAcc += dt;
  if (fpsAcc > 0.5) { fpsShown = frames / fpsAcc; frames = 0; fpsAcc = 0; }
  // One `perf` reading, taken over 4 s of *unbroken* running (wall clock,
  // not the clamped dt). A pause restarts the window, so a scene the host
  // pauses at once never reports a false low reading (found live by the app,
  // 2026-11-10).
  // It skips the first second (shader warm-up), and starts over whenever the
  // quality steps down, so it measures the village the child will get.
  if (!perfSent) {
    const tNow = performance.now();
    if (perfSeg.last != null) { const d = (tNow - perfSeg.last) / 1000; if ((perfSeg.warm = (perfSeg.warm || 0) + d) > 1) { perfSeg.t += d; perfSeg.n++; } }
    perfSeg.last = tNow;
    if (perfSeg.t >= 4) { stage.perf.fast = false; perfSent = true; bridge.send('perf', { ...statsNow(), fps: Math.round((perfSeg.n / perfSeg.t) * 10) / 10, window: Math.round(perfSeg.t * 10) / 10 }); }
  }
  if (!debugEl.hidden) {
    const i = renderer.info.render;
    debugEl.textContent = `${fpsShown.toFixed(0)} i/s · ${i.calls} appels · ${(i.triangles / 1000).toFixed(0)} k triangles · ${hourLabel(state.hour)} · qualité ${stage.perf.level}`;
  }
  rafId = requestAnimationFrame(frame);
}
function pause() { perfSeg = { t: 0, n: 0, last: null }; running = false; if (rafId != null) { cancelAnimationFrame(rafId); rafId = null; } }
function resume() {
  if (running || disposed) return;
  running = true; clock.getDelta();
  perfSeg = { t: 0, n: 0, last: null }; frames = 0; fpsAcc = 0; // no stale reading across a pause
  // The greeting's step-aside timer ran on during the pause (say, the app's
  // parent-PIN dialog at first pairing): show it again now the child can see it.
  if (embedded && greeting.text) ui.showBubble();
  // The app left and came back: clear the portal, finished or not. A portal
  // still running is cancelled and never posts its `open` (the child left).
  if (portal.active) { portal.stop(); portalEnded({ instant: true }); }
  rafId = requestAnimationFrame(frame);
}

// ---------- start ----------
setSeason(state.season, { live: state.seasonLive });
weather.set(state.weather, state.season);
if (init) applyHost(init);
autoWeather();
weather.state.mix = { ...weather.state.mix, ...(await import('./weather.js')).WEATHER[state.weather] };
// Compile every shader before the first frame, so the child's first seconds
// (and `perf`) don't stall on compilation. Optional: older drivers just skip it.
try { await renderer.compileAsync?.(scene, camera); } catch { /* compiled on first draw instead */ }
// Until `perf` is posted, step quality down quickly (pixel ratio, shadows):
// a device that can run a lighter village keeps 3D.
stage.perf.fast = true;
{ const prev = stage.perf.onLevel; stage.perf.onLevel = (l) => { prev?.(l); if (!perfSent) perfSeg = { t: 0, n: 0, last: null }; }; }
rafId = requestAnimationFrame(() => {
  // The first frame is drawn even if the host paused us already, so
  // `ready` always follows a real frame.
  const was = running; running = true; frame(); if (!was) pause();
  bridge.send('ready', { version: bridge.SCENE_VERSION, bridge: bridge.BRIDGE_VERSION, buildings: buildings.map((b) => b.id) });
  setTimeout(() => document.getElementById('loading').classList.add('is-done'), 150);
  setTimeout(() => document.getElementById('hint').classList.add('is-faded'), 9000);
});
const pre = params.get('select');
if (pre && byId.has(pre)) setTimeout(() => select(pre), 50);

function statsNow() {
  return { weather: state.weather, weatherSource: state.weatherSource, fps: Math.round(fpsShown * 10) / 10, calls: renderer.info.render.calls, triangles: renderer.info.render.triangles, quality: stage.perf.level, pixelRatio: renderer.getPixelRatio() };
}

// Host fields shared by `init` and `update`.
function applyHost(m) {
  if (m.strings) { ui.setStrings(m.strings); relabel(); }
  if (Array.isArray(m.buildings)) {
    for (const h of m.buildings) {
      const b = byId.get(h.id); if (!b) continue; // the set of buildings is fixed at init
      if (h.label !== undefined) { b.spot.label = h.label; b.spot.short = undefined; }
      if (h.progress !== undefined) b.spot.progress = h.progress;
      if (h.soon !== undefined) b.spot.soon = h.soon === true;
      if (h.live !== undefined && (h.live !== false) !== (b.spot.live !== false)) setLive(b, h.live !== false);
      ui.refreshPill(h.id);
    }
  }
  if (m.greeting !== undefined) { greeting.text = m.greeting; sayDefault(); }
  if (m.weather !== undefined) { state.hostWeather = m.weather && typeof m.weather === 'object' ? m.weather : null; autoWeather(); }
  if (typeof m.reduced === 'boolean') state.reducedPref = m.reduced;
  if (m.lang) document.documentElement.lang = m.lang;
  if (m.insets && Number.isFinite(m.insets.top)) ui.setInsetTop(m.insets.top);
}

function dispose() {
  if (disposed) return;
  pause(); disposed = true;
  renderer.setAnimationLoop?.(null);
  scene.traverse((o) => { o.geometry?.dispose?.(); });
  renderer.dispose(); renderer.forceContextLoss?.();
  renderer.domElement.remove();
}

bridge.on({
  update: (m) => applyHost(m),
  pause: () => pause(),
  resume: () => resume(),
  reduced: (m) => { state.reducedPref = !!m.on; },
  select: (m) => select(m.id && byId.has(m.id) ? m.id : null, { from: m.id ? 'host' : 'close' }),
  setTime: (m) => {
    if (m.hour == null) { goLive(); return; }
    const h = Number(m.hour); if (!Number.isFinite(h)) return;
    state.auto = false; state.hourLive = false;
    if (m.animate && !reduced()) state.hourTarget = ((h % 24) + 24) % 24; else { state.hour = ((h % 24) + 24) % 24; state.hourTarget = null; }
  },
  setSeason: (m) => { if (m.season == null || m.season === 'live') { const n = now(); state.seasonLive = true; setSeason(quebecSeason(n.month), { live: true }); } else setSeason(m.season); },
  setWeather: (m) => setWeather(m.weather),
  getStats: (m) => bridge.send('stats', { ...statsNow(), ...(m.id !== undefined ? { id: m.id } : {}) }),
  dispose: () => dispose(),
});

// A small API, for the switch page, tests and screenshots.
window.village = {
  setTime: (h) => { state.hour = h; state.hourTarget = null; state.auto = false; },
  setSeason, setWeather, select: (id) => select(id),
  setReduced: (on) => { state.reducedPref = on; },
  foxScreen: () => { const v = new THREE.Vector3(); fox.getWorldPosition(v); v.y += 1.2; v.project(camera); const r = renderer.domElement.getBoundingClientRect(); return { x: (v.x * 0.5 + 0.5) * r.width, y: (-v.y * 0.5 + 0.5) * r.height }; },
  stats: () => ({ fps: fpsShown, calls: renderer.info.render.calls, triangles: renderer.info.render.triangles, quality: stage.perf.level, pixelRatio: renderer.getPixelRatio(), frames: framesDrawn, running }),
  buildingScreen: (id) => { const b = byId.get(id); if (!b) return null; const v = new THREE.Vector3(); b.hit.getWorldPosition(v); v.project(camera); const r = renderer.domElement.getBoundingClientRect(); return { x: r.left + (v.x * 0.5 + 0.5) * r.width, y: r.top + (-v.y * 0.5 + 0.5) * r.height }; },
  state, labels: { PHASE_FR, SEASON_FR, WEATHER_FR },
  _debug: { scene, camera, renderer, controls, stage },
  models: models.report,
  buildings: buildings.map((b) => b.id),
};
