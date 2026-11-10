// glTF models for the village. Each building kind and the fox has a slot
// in assets/models/. A slot that loads is used; one that is missing or
// broken falls back to the procedural build, so the village never fails
// because of a model. `?models=0` forces the procedural build (to compare).
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

export const MODEL_DIR = 'assets/models/';
export const SLOTS = {
  math: 'bldg-math.glb',
  francais: 'bldg-francais.glb',
  social: 'bldg-univers-social.glb',
  anglais: 'bldg-anglais.glb',
  science: 'bldg-science.glb',
  ccq: 'bldg-ccq.glb',
  gallery: 'bldg-gallery.glb',
  fox: 'fox.glb',
};

// Small props, placed by data.js PROPS. Optional like everything else: a
// prop that fails to load is simply not drawn.
export const PROP_FILES = ['bench', 'lamp-post', 'fence-gate', 'well', 'weathervane'];

export async function loadModels({ enabled = true, timeoutMs = 8000 } = {}) {
  const out = { buildings: {}, fox: null, props: {}, report: {} };
  if (!enabled) { for (const k of Object.keys(SLOTS)) out.report[k] = 'procedural (models=0)'; return out; }
  const loader = new GLTFLoader();
  const one = (file) => Promise.race([
    loader.loadAsync(MODEL_DIR + file),
    new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), timeoutMs)),
  ]);
  // Review only: `?trial=science` loads assets/models/trial/<slot file> for
  // that slot, to compare a candidate model in the live scene. dist/ never
  // ships trial/.
  const trial = new URLSearchParams(location.search).get('trial');
  const slots = trial && SLOTS[trial] ? { ...SLOTS, [trial]: 'trial/' + SLOTS[trial] } : SLOTS;
  const entries = Object.entries(slots);
  // A model may come with `<name>.joints.json` (sand3d export: drive nodes,
  // axes, limits). Optional: a missing file just means no joints to animate.
  const joints = (file) => fetch(MODEL_DIR + file.replace(/\.glb$/, '.joints.json')).then((r) => (r.ok ? r.json() : null)).catch(() => null);
  const [results, jointData, propResults] = await Promise.all([
    Promise.allSettled(entries.map(([, f]) => one(f))),
    Promise.all(entries.map(([k, f]) => (k === 'fox' ? null : joints(f)))),
    Promise.allSettled(PROP_FILES.map((n) => one(`props/prop-${n}.glb`))),
  ]);
  propResults.forEach((r, i) => { if (r.status === 'fulfilled') out.props[PROP_FILES[i]] = r.value.scene; });
  out.report.props = `${Object.keys(out.props).length}/${PROP_FILES.length}`;
  results.forEach((r, i) => {
    const [kind, file] = entries[i];
    if (r.status === 'fulfilled') {
      if (kind === 'fox') out.fox = { scene: r.value.scene, animations: r.value.animations };
      else { out.buildings[kind] = r.value.scene; if (jointData[i]?.joints) r.value.scene.userData.joints = jointData[i].joints; }
      out.report[kind] = `gltf ${file}`;
    } else {
      out.report[kind] = `procedural (${r.reason?.message?.slice(0, 60) || 'missing'})`;
    }
  });
  return out;
}
