// Every string the scene itself shows in embed mode, keyed. The host sends
// its own (`init.strings`, any subset); these French defaults fill the rest,
// and the standalone prototype uses them as they are. BRIDGE.md lists them.
// `{name}` is a placeholder the scene fills.
export const DEFAULT_STRINGS = {
  'stage.aria': 'Village des Lys en 3D. Flèches : tourner et incliner. Plus et moins : zoomer. Zéro : recentrer. Tab : passer d’un bâtiment à l’autre.',
  'labels.aria': 'Bâtiments du village',
  'loading': 'Le village se prépare…',
  'pill.new': 'À découvrir',
  'pill.progress': '{pct}/100',
  'pill.locked': 'Bientôt',
  'pill.aria.new': '{label}, à découvrir',
  'pill.aria.progress': '{label}, {pct} sur 100',
  'pill.aria.locked': '{label}, bientôt disponible',
  'pill.soon': 'Bientôt',
  'pill.aria.soon': '{label}, leçons bientôt',
  'pill.aria.place': '{label}',
  'cam.aria': 'Caméra',
  'cam.in': 'Zoomer',
  'cam.out': 'Dézoomer',
  'cam.left': 'Tourner à gauche',
  'cam.right': 'Tourner à droite',
  'cam.home': 'Recentrer le village',
  // Words painted on the 3D signposts, one key per board (top to bottom).
  'sign.francais.0': 'Lire',
  'sign.francais.1': 'Écrire',
  'sign.francais.2': 'Créer',
  'sign.anglais.0': 'Hello',
  'sign.anglais.1': 'Read',
  'sign.ccq.0': 'Vivre',
  'sign.ccq.1': 'ensemble',
};

export function makeStrings(over = {}) {
  const S = { ...DEFAULT_STRINGS };
  for (const [k, v] of Object.entries(over || {})) if (typeof v === 'string') S[k] = v;
  return S;
}

// ---------- Québec date and clock (the default season and time) ----------
// Québec runs on Eastern time (America/Toronto covers Montréal and Québec
// City). `?now=2026-01-15T08:30` overrides the clock for tests and review.
export function quebecNow(override) {
  if (override) {
    const m = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{1,2}):(\d{2}))?/.exec(override);
    if (m) return { month: +m[2], day: +m[3], hour: (+(m[4] || 12)) + (+(m[5] || 0)) / 60 };
  }
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Toronto', month: 'numeric', day: 'numeric', hour: 'numeric', minute: 'numeric', hourCycle: 'h23',
  }).formatToParts(new Date()).map((p) => [p.type, p.value]));
  return { month: +parts.month, day: +parts.day, hour: (+parts.hour % 24) + (+parts.minute) / 60 };
}

/**
 * The season a Québec child sees out the window, not the astronomical one:
 * snow from December through March, a short spring in April–May, summer
 * June–August, autumn September–November.
 */
export function quebecSeason(month) {
  if (month === 12 || month <= 3) return 'winter';
  if (month <= 5) return 'spring';
  if (month <= 8) return 'summer';
  return 'autumn';
}
