// Real weather → village weather. The app sends Environment Canada's
// observation for a coarse region (`GET /me/weather` on the backend:
// condition, temp_c, is_day, observed_at); this maps it onto the scene's
// six kinds and decides when it is too old to trust (BRIDGE.md).
export const KINDS = ['clear', 'clouds', 'rain', 'snow', 'storm', 'fog'];
export const MAX_AGE_MS = 3 * 3600 * 1000;

// Backend conditions first, then the wordings a feed or a later backend
// might send, so a new condition degrades to its nearest look, never breaks.
const MAP = {
  clear: 'clear', sunny: 'clear', mainly_clear: 'clear', mostly_sunny: 'clear', fair: 'clear',
  cloudy: 'clouds', clouds: 'clouds', overcast: 'clouds', partly_cloudy: 'clouds', mostly_cloudy: 'clouds', mainly_cloudy: 'clouds', a_few_clouds: 'clouds',
  rain: 'rain', showers: 'rain', rain_showers: 'rain', drizzle: 'rain', light_rain: 'rain', heavy_rain: 'rain',
  snow: 'snow', flurries: 'snow', snow_showers: 'snow', light_snow: 'snow', heavy_snow: 'snow', blowing_snow: 'snow', snow_squalls: 'snow', ice_crystals: 'snow',
  storm: 'storm', thunderstorm: 'storm', thunderstorms: 'storm', tstorm: 'storm', lightning: 'storm',
  fog: 'fog', mist: 'fog', haze: 'fog', smoke: 'fog', fog_patches: 'fog', ice_fog: 'fog', freezing_fog: 'fog',
};
// Mixed precipitation looks like snow at or below 0 °C, rain above.
const MIXED = new Set(['sleet', 'freezing_rain', 'freezing_drizzle', 'ice_pellets', 'hail', 'rain_and_snow', 'wintry_mix', 'precipitation']);

/** The village kind for an observation's condition, or null if unknown. */
export function kindFor(condition, tempC) {
  const c = String(condition || '').trim().toLowerCase().replace(/[\s-]+/g, '_');
  if (MAP[c]) return MAP[c];
  if (MIXED.has(c)) return Number.isFinite(tempC) && tempC <= 0 ? 'snow' : 'rain';
  return null;
}

/** True when the observation is recent enough to show (≤ 3 h, not from the future). */
export function isFresh(observedAt, nowMs = Date.now()) {
  const t = Date.parse(observedAt);
  if (!Number.isFinite(t)) return false;
  const age = nowMs - t;
  return age <= MAX_AGE_MS && age >= -15 * 60 * 1000;
}

/**
 * A calm sky for the season, for when there's no (fresh) observation: clear
 * in spring, summer and winter (crisp, sunny snow), soft cloud in autumn.
 * Never rain, snowfall, storm or fog.
 */
export function calmFor(season) {
  return season === 'autumn' ? 'clouds' : 'clear';
}
