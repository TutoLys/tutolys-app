// The village's content: which subject stands where, and the sample learner
// state the prototype shows. Positions are the app's own fractional plots
// (tutolys-app/lib/features/home/village_scene.dart `_plots`), mapped onto
// the island so the 3D village keeps the 2D village's shape: `left` is
// west→east, `top` is back→front.
//
// Progress values are SAMPLE data for the prototype. In the app they come
// from `subjectProgressProvider`; null means « À découvrir », never 0.

// Big enough that every plinth and door-path stays inside the rim with a
// margin (was 20 × 15; Science and Anglais hung over the edge). toWorld()
// is independent of this, so buildings keep their plots.
export const ISLAND = { rx: 25, rz: 19 };

export const toWorld = (left, top) => ({
  x: (left - 0.5) * 34,
  z: (top - 0.5) * 26,
});

export const BUILDINGS = [
  {
    id: 'MATH', kind: 'math', label: 'Mathématique', left: 0.17, top: 0.40,
    art: 'asset-bldg-math.webp', progress: 0.62,
    blurb: 'Nombres, formes, mesures : la tour du π et son télescope.',
    next: 'Additionner jusqu’à 20',
  },
  {
    id: 'FR', kind: 'francais', label: 'Français', left: 0.50, top: 0.22,
    art: 'asset-bldg-francais.webp', progress: 0.45,
    blurb: 'Lire, écrire, communiquer : la maison du grand livre.',
    next: 'Les sons « on » et « an »',
  },
  {
    id: 'SOC', kind: 'social', label: 'Univers social', left: 0.83, top: 0.32,
    art: 'asset-bldg-univers-social.webp', progress: null,
    blurb: 'Le monde, son histoire et ses cartes, sous le grand globe.',
    next: 'Ma famille, hier et aujourd’hui',
  },
  {
    id: 'ESL', kind: 'anglais', label: 'Anglais', left: 0.12, top: 0.76,
    art: 'asset-bldg-anglais.webp', progress: 0.18,
    blurb: 'Hello! Les premiers mots d’anglais, sous la coupole.',
    next: 'Colours and numbers',
  },
  {
    id: 'SCI', kind: 'science', label: 'Science', left: 0.84, top: 0.82,
    art: 'asset-bldg-science.webp', progress: null,
    blurb: 'L’observatoire : vivant, matière, Terre et espace.',
    next: 'Les cinq sens',
  },
  {
    id: 'CCQ', kind: 'ccq', label: 'Culture et citoyenneté', short: 'CCQ', left: 0.37, top: 0.72, small: true,
    art: 'asset-bldg-ccq.webp', progress: null,
    blurb: 'Culture et citoyenneté québécoise : vivre ensemble.',
    next: 'Les règles de ma classe',
  },
  {
    id: 'GALLERY', kind: 'gallery', label: 'Ma galerie', left: 0.67, top: 0.15, small: true,
    art: 'asset-bldg-gallery.webp', progress: undefined, measured: false,
    blurb: 'Tes dessins et tes réussites, accrochés au mur.',
    next: null,
  },
];

// The plaza where the fox greets the child: the design's mascot spot
// (left .46, top .56), nudged to the island's centre.
export const PLAZA = { x: -0.6, z: 1.6, r: 3.4 };

// The three real quests of the app's Quêtes board (ADR 0015).
export const QUESTS = [
  { title: 'Défi du jour : 5 bonnes réponses de suite', done: 3, total: 5, xp: 20, chip: 'c-pink' },
  { title: 'Faire 5 exercices', done: 5, total: 5, xp: 15, chip: 'c-blue' },
  { title: 'Jouer 10 minutes', done: 6, total: 10, xp: 10, chip: 'c-purple' },
];

export const LEARNER = { name: 'Yelhan', grade: '1re année', level: 3, xpInto: 40, xpLevel: 100, streak: 4 };
