// The host bridge: how the app (Flutter, through an iframe or a WebView)
// drives the village and hears back from it. The contract is BRIDGE.md.
//
// Every message is `{ v: 1, type, ...fields }`. Messages in are accepted
// only from this page's own origin. Messages out go to the parent window
// (iframe) and, when the host injected one, to `window.VillageHost`
// (a WebView JavaScript channel, which takes a JSON string).
//
// The listener is installed when this module is imported, before the scene
// is built, so an `init` sent early is buffered rather than lost.
export const BRIDGE_VERSION = 1;
export const SCENE_VERSION = 'village3d-2026.11.10.11';

const params = new URLSearchParams(location.search);
export const embedded = params.get('embed') === '1';

const handlers = new Map();
const early = [];
let initMsg = null;
let initWaiters = [];

function onMessage(e) {
  if (e.origin !== location.origin && !(e.origin === 'null' && location.origin === 'null')) return;
  const m = typeof e.data === 'string' ? safeParse(e.data) : e.data;
  if (!m || typeof m !== 'object' || m.v !== BRIDGE_VERSION || typeof m.type !== 'string') return;
  receive(m);
}
function safeParse(s) { try { return JSON.parse(s); } catch { return null; } }

/** Deliver one message (also the entry point for a WebView that evaluates JS). */
export function receive(m) {
  if (m.type === 'init') {
    initMsg = m;
    const w = initWaiters; initWaiters = [];
    w.forEach((r) => r(m));
  }
  const h = handlers.get(m.type);
  if (h) h(m); else if (m.type !== 'init') early.push(m);
}
window.addEventListener('message', onMessage);
// A WebView host can call this directly instead of posting.
window.villageReceive = (m) => receive(typeof m === 'string' ? safeParse(m) : m);

/** Register handlers for incoming types; buffered messages are replayed. */
export function on(map) {
  for (const [k, fn] of Object.entries(map)) handlers.set(k, fn);
  for (let i = 0; i < early.length;) {
    const h = handlers.get(early[i].type);
    if (h) { const [m] = early.splice(i, 1); h(m); } else i++;
  }
}

/** Resolves with the host's `init` (immediately if it already came). */
export function waitInit() {
  return initMsg ? Promise.resolve(initMsg) : new Promise((r) => initWaiters.push(r));
}

/** Send a message to the host, if there is one. */
export function send(type, fields = {}) {
  const m = { v: BRIDGE_VERSION, type, ...fields };
  try { if (window.parent && window.parent !== window) window.parent.postMessage(m, location.origin === 'null' ? '*' : location.origin); } catch { /* detached */ }
  try { if (window.VillageHost?.postMessage) window.VillageHost.postMessage(JSON.stringify(m)); } catch { /* no channel */ }
  if (window.__villageOut) window.__villageOut.push(m); // tests and the dev host page
}

// Tell the host we're listening: it sends `init` in reply (an `init` sent
// earlier is buffered anyway).
queueMicrotask(() => send('loading', { version: SCENE_VERSION, bridge: BRIDGE_VERSION }));

/** `{name}` placeholders filled from `vars`. */
export function fill(str, vars = {}) {
  return String(str).replace(/\{(\w+)\}/g, (_, k) => (vars[k] ?? `{${k}}`));
}
