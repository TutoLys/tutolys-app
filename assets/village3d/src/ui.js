// The HTML layer over the scene, in TutoLys's own components: scene pills
// that follow their buildings, the info card, the quest panel, the
// ambience controls, the fox's speech bubble, toasts. No game state lives
// here; it reports intent to `main.js` through callbacks.
import * as THREE from 'three';
import { QUESTS, LEARNER } from './data.js';
import { DEFAULT_STRINGS, makeStrings } from './strings.js';
import { fill } from './bridge.js';

const $ = (s) => document.querySelector(s);
const ICONS = {
  check: '<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
  go: '<svg viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></svg>',
  target: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="2.5"/></svg>',
  book: '<svg viewBox="0 0 24 24"><path d="M4 6c3-1 5-1 8 1 3-2 5-2 8-1v12c-3-1-5-1-8 1-3-2-5-2-8-1z"/></svg>',
  clock: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8"/><path d="M12 8v4l3 2"/></svg>',
};

const esc = (t) => String(t).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

export function hourLabel(h) {
  const hh = Math.floor(h) % 24, mm = Math.round((h - Math.floor(h)) * 60);
  return `${hh} h ${String(mm === 60 ? 0 : mm).padStart(2, '0')}`;
}
export const PHASE_FR = { night: 'Nuit', dawn: 'Aube', day: 'Jour', sunset: 'Coucher du soleil', dusk: 'Crépuscule' };
export const SEASON_FR = { spring: 'Printemps', summer: 'Été', autumn: 'Automne', winter: 'Hiver' };
export const WEATHER_FR = { clear: 'Dégagé', clouds: 'Nuageux', rain: 'Pluie', snow: 'Neige', storm: 'Orage' };

export function createUI({ buildings, strings = DEFAULT_STRINGS, onHover, onSelect, onCamera, onTime, onAuto, onNow, onSeason, onWeather, onReduced, onCta }) {
  let S = makeStrings(strings);
  let insetTop = null; // px the host draws over the top of the scene (embed)
  const applyStrings = () => {
    $('#stage').setAttribute('aria-label', S['stage.aria']);
    $('#labels').setAttribute('aria-label', S['labels.aria']);
    const ld = $('#loading span'); if (ld) ld.textContent = S.loading;
    const cam = $('.cam-controls'); cam.setAttribute('aria-label', S['cam.aria']);
    cam.querySelectorAll('[data-cam]').forEach((b) => b.setAttribute('aria-label', S[`cam.${b.dataset.cam}`] || b.getAttribute('aria-label')));
  };
  applyStrings();

  // --- header ---
  $('#sign-sub').textContent = `${LEARNER.name} · ${LEARNER.grade}`;
  $('#lvl').textContent = `Niv. ${LEARNER.level}`;
  $('#xp-fill').style.width = `${(LEARNER.xpInto / LEARNER.xpLevel) * 100}%`;
  $('#streak').textContent = `${LEARNER.streak} jours`;

  // --- quests ---
  const chips = [ICONS.target, ICONS.book, ICONS.clock];
  $('#quest-list').innerHTML = QUESTS.map((q, i) => {
    const done = q.done >= q.total;
    return `<div class="quest-row">
      <div class="q-chip ${q.chip}">${chips[i]}</div>
      <div class="qr-meta"><div class="qr-title">${q.title}</div>
        <div class="qr-frac">${q.done} / ${q.total}</div>
        <div class="track ${done ? 'done' : ''}"><span style="width:${(q.done / q.total) * 100}%"></span></div></div>
      <div class="qr-side"><span class="qr-xp"><img src="assets/img/asset-xpstar.webp" alt="">+${q.xp} XP</span>
        <span class="qr-status ${done ? 'done' : 'go'}" aria-label="${done ? 'Réussie' : 'À faire'}">${done ? ICONS.check : ICONS.go}</span></div>
    </div>`;
  }).join('');
  $('#quest-count').textContent = `${QUESTS.filter((q) => q.done >= q.total).length}/${QUESTS.length}`;
  $('#quest-chip-count').textContent = $('#quest-count').textContent;
  // Phones and tablets: the quest panel is a sheet the chip opens.
  const questChip = $('#quest-chip');
  const setQuests = (open) => { $('#quests').classList.toggle('is-open', open); questChip.setAttribute('aria-expanded', String(open)); };
  questChip.addEventListener('click', () => setQuests(!$('#quests').classList.contains('is-open')));
  $('#quests-close').addEventListener('click', () => { setQuests(false); questChip.focus(); });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && $('#quests').classList.contains('is-open')) setQuests(false); });

  // --- scene pills (one real button per building: the keyboard path) ---
  const labels = $('#labels');
  const pills = new Map();
  const sizes = new Map();
  // A pill shows the label and, for a subject, its progress: a bar and
  // "62/100", « À découvrir » when nothing is measured yet (never 0), or
  // « Bientôt » for a building the host marks not live (greyed, no tap).
  function renderPill(el, s) {
    let extra = '';
    let aria;
    const label = s.short || s.label;
    if (s.live === false) { extra = `<span class="sp-new">${esc(S['pill.locked'])}</span>`; aria = fill(S['pill.aria.locked'], { label: s.label }); }
    else if (s.soon) { extra = `<span class="sp-new">${esc(S['pill.soon'])}</span>`; aria = fill(S['pill.aria.soon'], { label: s.label }); }
    else if (s.measured === false) { extra = '<span class="sp-dot" aria-hidden="true"></span>'; aria = fill(S['pill.aria.place'], { label: s.label }); }
    else if (s.progress == null) { extra = `<span class="sp-new">${esc(S['pill.new'])}</span>`; aria = fill(S['pill.aria.new'], { label: s.label }); }
    else {
      const pct = Math.round(Math.min(1, Math.max(0, s.progress)) * 100);
      extra = `<span class="sp-track" aria-hidden="true"><span style="width:${pct}%"></span></span><span class="sp-num">${esc(fill(S['pill.progress'], { pct }))}</span>`;
      aria = fill(S['pill.aria.progress'], { label: s.label, pct });
    }
    el.innerHTML = `<span class="sp-name">${esc(label)}</span>${extra}`;
    el.setAttribute('aria-label', aria);
    el.classList.toggle('is-locked', s.live === false);
    if (s.live === false) el.setAttribute('aria-disabled', 'true'); else el.removeAttribute('aria-disabled');
    sizes.delete(el);
  }
  for (const b of buildings) {
    const s = b.spot;
    const el = document.createElement('button');
    el.className = 'scene-pill';
    el.dataset.id = s.id;
    el.addEventListener('pointerenter', () => onHover(s.id, true));
    el.addEventListener('pointerleave', () => onHover(s.id, false));
    el.addEventListener('focus', () => onHover(s.id, true));
    el.addEventListener('blur', () => onHover(s.id, false));
    el.addEventListener('click', () => { if (b.spot.live !== false) onSelect(s.id, { from: 'pill' }); });
    labels.appendChild(el);
    pills.set(s.id, el);
  }

  const v = new THREE.Vector3();
  window.addEventListener('resize', () => sizes.clear());
  function placeLabels(camera, canvas, foxHead) {
    const w = canvas.clientWidth, h = canvas.clientHeight;
    const items = [];
    for (const b of buildings) {
      const el = pills.get(b.id);
      b.root.localToWorld(v.set(0, (b.height + 0.9) / b.root.scale.y + b.art.position.y, 0));
      v.project(camera);
      const behind = v.z > 1;
      const x = (v.x * 0.5 + 0.5) * w, y = (-v.y * 0.5 + 0.5) * h;
      if (!sizes.has(el)) sizes.set(el, [el.offsetWidth || 120, el.offsetHeight || 30]);
      const [pw, ph] = sizes.get(el);
      items.push({ el, x, y, z: v.z, pw, ph, hidden: behind || x < -60 || x > w + 60 || y < -40 || y > h + 40, dy: 0 });
    }
    // The fox's bubble stays put; labels make room for it.
    if (foxHead) {
      foxHead.project(camera);
      const bubble = $('#fox-bubble');
      const bx = (foxHead.x * 0.5 + 0.5) * w, by = (-foxHead.y * 0.5 + 0.5) * h;
      bubble.style.left = `${bx.toFixed(1)}px`;
      bubble.style.top = `${by.toFixed(1)}px`;
      const bw = bubble.offsetWidth, bh = bubble.offsetHeight;
      items.push({ fixed: true, x: bx, y: by - bh / 2, z: -2, pw: bw, ph: bh, dy: 0 });
    }
    // Nearest labels keep their place; farther ones step up out of the way.
    items.sort((a, b) => a.z - b.z);
    for (let i = 1; i < items.length; i++) {
      const a = items[i];
      if (a.fixed) continue;
      for (let pass = 0; pass < 3; pass++) {
        let moved = false;
        for (let j = 0; j < i; j++) {
          const o = items[j];
          if (o.hidden || a.hidden) continue;
          const ox = (a.pw + o.pw) / 2 + 6 - Math.abs(a.x - o.x);
          const ay = a.y + a.dy, oy = o.y + o.dy;
          const oyv = (a.ph + o.ph) / 2 + 4 - Math.abs(ay - oy);
          if (ox > 0 && oyv > 0) { a.dy += ay <= oy ? -oyv : -(oyv + (ay - oy) * 2); moved = true; }
        }
        if (!moved) break;
      }
    }
    // Keep every label fully on screen and clear of the top HUD.
    const topLimit = insetTop != null ? insetTop + 6 : (document.querySelector('.hud-top')?.getBoundingClientRect().bottom || 60) + 4;
    for (const it of items) {
      if (it.fixed || it.hidden) continue;
      it.x = Math.min(Math.max(it.x, it.pw / 2 + 6), w - it.pw / 2 - 6);
      const yy = it.y + it.dy;
      if (yy - it.ph / 2 < topLimit) it.dy += topLimit - (yy - it.ph / 2);
    }
    // Clamping can stack labels at the top edge: cascade overlaps downward.
    const vis = items.filter((it) => !it.hidden).sort((p, q) => (p.y + p.dy) - (q.y + q.dy));
    for (let i = 1; i < vis.length; i++) {
      const a = vis[i]; if (a.fixed) continue;
      for (let j = 0; j < i; j++) {
        const o = vis[j];
        const ox = (a.pw + o.pw) / 2 + 6 - Math.abs(a.x - o.x);
        const oyv = (a.ph + o.ph) / 2 + 4 - ((a.y + a.dy) - (o.y + o.dy));
        if (ox > 0 && oyv > 0) a.dy += oyv;
      }
    }
    // The cascade never moves the fixed bubble, so a pill can end up under
    // it: lift such a pill above the bubble, or drop it below if there's no
    // room above.
    const fixedIt = items.find((it) => it.fixed);
    if (fixedIt) {
      for (const it of vis) {
        if (it.fixed) continue;
        const ox = (it.pw + fixedIt.pw) / 2 + 4 - Math.abs(it.x - fixedIt.x);
        const yy = it.y + it.dy;
        if (ox <= 0 || Math.abs(yy - fixedIt.y) >= (it.ph + fixedIt.ph) / 2 + 4) continue;
        const above = fixedIt.y - fixedIt.ph / 2 - 4 - it.ph / 2;
        it.dy = (above - it.ph / 2 >= topLimit ? above : fixedIt.y + fixedIt.ph / 2 + 4 + it.ph / 2) - it.y;
      }
    }
    items.filter((it) => !it.fixed).forEach((it, i) => {
      const el = it.el;
      el._dy = el._dy == null ? it.dy : el._dy + (it.dy - el._dy) * 0.25;
      el.classList.toggle('is-hidden', it.hidden);
      el.style.transform = `translate3d(${it.x.toFixed(1)}px, ${(it.y + el._dy).toFixed(1)}px, 0) translate(-50%, -50%)`;
      el.style.zIndex = String(20 - i);
    });
  }

  function setPillState(id, { hover, selected }) {
    const el = pills.get(id); if (!el) return;
    if (hover !== undefined) el.classList.toggle('is-hover', hover);
    if (selected !== undefined) { el.classList.toggle('is-selected', selected); el.setAttribute('aria-pressed', selected ? 'true' : 'false'); }
  }

  // --- info card ---
  const info = $('#info');
  let current = null;
  function showInfo(spot) {
    current = spot;
    info.classList.remove('is-leaving');
    info.hidden = false;
    // Restart the entrance animation.
    info.style.animation = 'none'; void info.offsetWidth; info.style.animation = '';
    const img = $('#info-art'); img.src = `assets/img/${spot.art}`; img.alt = `Illustration : ${spot.label}`;
    img.style.animation = 'none'; void img.offsetWidth; img.style.animation = '';
    $('#info-eyebrow').textContent = spot.measured === false ? 'Lieu du village' : 'Matière';
    $('#info-title').textContent = spot.label;
    $('#info-blurb').textContent = spot.blurb;
    const prog = $('#info-progress');
    if (spot.measured === false) prog.innerHTML = '';
    else if (spot.progress == null) prog.innerHTML = '<span class="new">À découvrir</span>';
    else {
      const pct = Math.round(spot.progress * 100);
      prog.innerHTML = `<div class="track"><span style="width:${pct}%"></span></div><span class="num">${pct}/100</span>`;
    }
    $('#info-next').innerHTML = spot.next ? `Prochaine activité : <b>${spot.next}</b>` : '';
    $('#info-cta').textContent = spot.measured === false ? 'Ouvrir ma galerie' : spot.progress == null ? 'Découvrir' : 'Continuer';
    $('#quests').classList.add('is-away');
  }
  function hideInfo() {
    if (info.hidden) return;
    current = null;
    info.classList.add('is-leaving');
    setTimeout(() => { if (!current) { info.hidden = true; info.classList.remove('is-leaving'); } }, 220);
    $('#quests').classList.remove('is-away');
  }
  $('#info-close').addEventListener('click', () => onSelect(null, { from: 'close' }));
  $('#info-dismiss').addEventListener('click', () => onSelect(null, { from: 'close' }));
  $('#info-cta').addEventListener('click', () => current && onCta(current));

  // --- fox bubble ---
  const bubble = $('#fox-bubble');
  function say(text) {
    if (bubble.textContent === text) return;
    bubble.textContent = text;
    bubble.classList.remove('pop'); void bubble.offsetWidth; bubble.classList.add('pop');
  }

  // --- toast ---
  let toastTimer;
  function toast(text) {
    const t = $('#toast');
    t.textContent = text; t.classList.add('is-on');
    clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove('is-on'), 3200);
  }

  // --- ambience controls ---
  const time = $('#time');
  time.addEventListener('input', () => onTime(parseFloat(time.value), { user: true }));
  document.querySelectorAll('[data-hour]').forEach((b) => b.addEventListener('click', () => onTime(parseFloat(b.dataset.hour), { user: true, animate: true })));
  $('#auto').addEventListener('click', (e) => { const on = e.currentTarget.getAttribute('aria-pressed') !== 'true'; onAuto(on); });
  document.querySelectorAll('input[name="season"]').forEach((r) => r.addEventListener('change', () => r.checked && onSeason(r.value)));
  document.querySelectorAll('input[name="weather"]').forEach((r) => r.addEventListener('change', () => r.checked && onWeather(r.value)));
  $('#reduced').addEventListener('change', (e) => onReduced(e.currentTarget.checked));
  const ambToggle = $('#amb-toggle');
  ambToggle.addEventListener('click', () => {
    const open = ambToggle.getAttribute('aria-expanded') !== 'true';
    ambToggle.setAttribute('aria-expanded', String(open));
    $('#amb-body').hidden = !open;
  });
  // Phones (and short landscape screens) start with the ambience collapsed.
  if (window.matchMedia('(max-width: 720px), (max-height: 520px)').matches) { ambToggle.setAttribute('aria-expanded', 'false'); $('#amb-body').hidden = true; }

  document.querySelectorAll('[data-cam]').forEach((b) => b.addEventListener('click', () => onCamera(b.dataset.cam)));

  function syncControls({ hour, season, weather, reduced, auto, live, phase, systemReduced }) {
    if (document.activeElement !== time) time.value = String(hour);
    const lbl = `${hourLabel(hour)} · ${PHASE_FR[phase]}`;
    $('#time-out').textContent = lbl;
    time.setAttribute('aria-valuetext', lbl);
    document.querySelectorAll('[data-hour]').forEach((b) => {
      const ph = { 6.5: 'dawn', 12: 'day', 18.6: 'sunset', 22.5: 'night' }[b.dataset.hour];
      b.classList.toggle('is-on', ph === phase || (ph === 'night' && phase === 'dusk'));
    });
    $('#auto').setAttribute('aria-pressed', String(auto));
    const nb = $('#now'); if (nb) nb.setAttribute('aria-pressed', String(!!live));
    const sr = document.querySelector(`input[name="season"][value="${season}"]`); if (sr && !sr.checked) sr.checked = true;
    const wr = document.querySelector(`input[name="weather"][value="${weather}"]`); if (wr && !wr.checked) wr.checked = true;
    $('#reduced').checked = reduced;
    $('#reduced-note').textContent = systemReduced ? 'Réglage de l’appareil : activé' : '';
    $('#amb-summary').textContent = `${PHASE_FR[phase]} · ${SEASON_FR[season]} · ${WEATHER_FR[weather]}`;
    document.documentElement.dataset.reduced = reduced ? '1' : '0';
  }

  for (const b of buildings) renderPill(pills.get(b.id), b.spot);
  const nowBtn = $('#now'); if (nowBtn && onNow) nowBtn.addEventListener('click', () => onNow());

  return {
    placeLabels, setPillState, showInfo, hideInfo, say, toast, syncControls, pills,
    /** New host strings: re-render everything the scene writes. */
    setStrings(over) { S = makeStrings(over); applyStrings(); for (const b of buildings) renderPill(pills.get(b.id), b.spot); },
    refreshPill(id) { const b = buildings.find((x) => x.id === id); if (b) renderPill(pills.get(id), b.spot); },
    setInsetTop(px) { insetTop = Number.isFinite(px) ? px : null; },
    get strings() { return S; },
  };
}
