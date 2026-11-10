// TutoLys design tokens, copied from the `:root` block of
// tutolys-app/docs/design/02-clickable-prototype.html, plus the material
// colours read off the real building art (asset-bldg-*.webp): cream stone,
// blue slate, gold trim. Everything in the scene takes its colour from here.

export const TOKENS = {
  skyTop: '#BFE3FF',
  skyBottom: '#EAF6FF',
  quebecBlue: '#1F3C88',
  quebecBlueBright: '#2F6FED',
  gold: '#D4AF37',
  goldLight: '#FBBF24',
  goldPale: '#FDE68A',
  ink: '#223047',
  inkMuted: '#7C8AA3',
  surface: '#FFFFFF',
  line: '#E4ECF7',
  track: '#E1E9F7',
  success: '#2FB170',
  retry: '#F2994A',
};

// Materials of the illustrated village.
export const MAT = {
  stone: 0xf3e4c8, // cream walls
  stoneShade: 0xe2cfae,
  stoneDark: 0xcdb48c,
  slate: 0x2f55c9, // blue roofs
  slateDark: 0x1f3c88,
  gold: 0xd4af37,
  goldBright: 0xf2c94c,
  door: 0x2346a8,
  wood: 0xa66b33,
  woodDark: 0x7b4a22,
  glass: 0x9fd0ff,
  windowGlow: 0xffd27a,
  path: 0xeadcc2,
  pathEdge: 0xd8c39f,
  iron: 0x2b3550,
  white: 0xffffff,
  foxWhite: 0xf7fbff,
  foxBlue: 0x2f6fed,
  foxBlueDeep: 0x1f3c88,
};

// Season palettes for the living things on the island.
export const SEASONS = {
  spring: {
    grass: 0xa2d894, grassAlt: 0xb5e0a6,
    canopy: [0x7cc95e, 0xe98bb4, 0x93d36a, 0xf2a3c4], // mid tones: lighting lifts them, pastels clipped to white
    pine: 0x3f9a6b,
    bush: 0x7cc576,
    flowers: [0xf9a8d4, 0xffffff, 0xfde68a, 0xc4b5fd],
    snow: 0, leafless: 0,
  },
  summer: {
    grass: 0x8fcc82, grassAlt: 0x9fd590,
    canopy: [0x5fb85a, 0x6cc463, 0x4fa852, 0x7ccf68],
    pine: 0x2f8a5c,
    bush: 0x5aae55,
    flowers: [0xfde68a, 0xffffff, 0x93c5fd, 0xfbbf24],
    snow: 0, leafless: 0,
  },
  autumn: {
    grass: 0xc2c983, grassAlt: 0xd2c77a,
    canopy: [0xf2994a, 0xe8b33a, 0xd9662b, 0xf5c04a],
    pine: 0x2f7d58,
    bush: 0xc9a043,
    flowers: [0xf2994a, 0xfde68a],
    snow: 0, leafless: 0,
  },
  winter: {
    grass: 0xf4f8ff, grassAlt: 0xe8f1fc,
    canopy: [0xeaf2fb, 0xf6faff, 0xdfeaf7, 0xf1f6fd],
    pine: 0x3a7a62,
    bush: 0xe6eef8,
    flowers: [],
    snow: 1, leafless: 1,
  },
};

export const hex = (c) => '#' + c.toString(16).padStart(6, '0');
