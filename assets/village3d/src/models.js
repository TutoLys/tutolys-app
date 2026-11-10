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

export async function loadModels({ enabled = true, timeoutMs = 8000 } = {}) {
  const out = { buildings: {}, fox: null, report: {} };
  if (!enabled) { for (const k of Object.keys(SLOTS)) out.report[k] = 'procedural (models=0)'; return out; }
  const loader = new GLTFLoader();
  const one = (file) => Promise.race([
    loader.loadAsync(MODEL_DIR + file),
    new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), timeoutMs)),
  ]);
  const entries = Object.entries(SLOTS);
  const results = await Promise.allSettled(entries.map(([, f]) => one(f)));
  results.forEach((r, i) => {
    const [kind, file] = entries[i];
    if (r.status === 'fulfilled') {
      if (kind === 'fox') out.fox = { scene: r.value.scene, animations: r.value.animations };
      else out.buildings[kind] = r.value.scene;
      out.report[kind] = `gltf ${file}`;
    } else {
      out.report[kind] = `procedural (${r.reason?.message?.slice(0, 60) || 'missing'})`;
    }
  });
  return out;
}
