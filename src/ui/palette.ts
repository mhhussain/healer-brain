// Tidelight: sea-teal glow against candle gold, coral for danger.
export const PAL = {
  deep: '#071821',
  mid: '#12384a',
  stone: '#5f7680',
  glow: '#45d3c2',
  gold: '#f0b54a',
  danger: '#ef5d4a',
  bone: '#e9e2cf',
  ink: '#04090c',
  wood: '#7a5a3c',
  steel: '#aebcc4',
  brass: '#c9a23c',
  kelp: '#3f7a45',
  violet: '#b58cf0',
};

export const TAU = Math.PI * 2;

const rgbOf = (hex: string) => {
  const n = parseInt(hex.slice(1), 16);
  return [n >> 16, (n >> 8) & 255, n & 255];
};

const mixes = new Map<string, string>();
// Blend two hex colours; t = 0 gives a, t = 1 gives b.
export function mix(a: string, b: string, t: number) {
  const key = a + b + t;
  let out = mixes.get(key);
  if (!out) {
    const x = rgbOf(a), y = rgbOf(b);
    out = '#' + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join('');
    mixes.set(key, out);
  }
  return out;
}

export function rgba(hex: string, a: number) {
  const [r, g, b] = rgbOf(hex);
  return `rgba(${r},${g},${b},${a})`;
}

// Stable pseudo-random number in [0, 1) for scenery that must not flicker.
export function hash(n: number) {
  const v = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return v - Math.floor(v);
}

export const DISPLAY_FONT = '"IM Fell English SC", "Iowan Old Style", Georgia, serif';
export const BODY_FONT = '"Spectral", Georgia, "Times New Roman", serif';
