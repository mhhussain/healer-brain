import { PAL, TAU, mix, rgba } from './palette';

// Storybook figures: a bell-shaped body, a big round head, one hat and one prop each.
type Hat = 'hood' | 'helm' | 'kelp' | 'bandana' | 'souwester' | 'brim' | 'mitre' | 'veil' | 'none';
type Prop = 'lantern' | 'shield' | 'crook' | 'cutlass' | 'harpoon' | 'candle' | 'anchor' | 'book' | 'bowl' | 'hooks' | 'banner' | 'keys' | 'eggs' | 'bell' | 'none';

export interface Look {
  robe: string;
  trim?: string;
  skin?: string;
  hat: Hat;
  hatCol?: string;
  // how tall a mitre stands, in head radii
  tall?: number;
  prop: Prop;
  wide?: number;
  // the drowned have sea-pale skin, barnacles and glowing eyes
  drowned?: boolean;
  eye?: string;
  // what the prop glows with while its owner casts
  orb?: string;
  crab?: boolean;
}

export interface Pose {
  // figure height in pixels
  H: number;
  dir: 1 | -1;
  // -1 to 1 through a walking stride, 0 when standing
  step: number;
  // 0 to 1 through an attack
  swing: number;
  casting: boolean;
  flash: boolean;
  // fallen heroes lie grey on the floor
  grey: boolean;
  // 0 to 1: an enemy being laid to rest turns to light
  rest: number;
  time: number;
}

export const HERO_LOOK: Record<string, Look> = {
  warden: { robe: '#5f86ad', trim: PAL.gold, hat: 'helm', hatCol: PAL.steel, prop: 'shield', wide: 1.2 },
  mender: { robe: PAL.bone, trim: PAL.glow, hat: 'hood', hatCol: '#3fb7aa', prop: 'lantern', orb: PAL.glow },
  bloomweaver: { robe: '#5f9a5c', trim: '#c9e08a', skin: '#d9b08c', hat: 'kelp', hatCol: PAL.kelp, prop: 'crook', orb: '#9fe08a' },
  duelist: { robe: '#9a4f78', trim: PAL.bone, hat: 'bandana', hatCol: '#c9485c', prop: 'cutlass', wide: 0.9 },
  ranger: { robe: '#3d6d86', trim: '#e6b93c', skin: '#c99b78', hat: 'souwester', hatCol: '#e6b93c', prop: 'harpoon', wide: 0.9 },
  pyromancer: { robe: '#8a4b3a', trim: PAL.gold, hat: 'brim', hatCol: '#4a2f2a', prop: 'candle', orb: PAL.gold },
};

export const ENEMY_LOOK: Record<string, Look> = {
  brute: { robe: '#3f8f8a', hat: 'hood', hatCol: '#2d6a6a', prop: 'anchor', wide: 1.3, drowned: true },
  hexer: { robe: '#5a4a8a', hat: 'hood', hatCol: '#3d3266', prop: 'book', wide: 0.85, drowned: true, eye: PAL.violet, orb: PAL.violet },
  archer: { robe: '#4a7a6a', hat: 'souwester', hatCol: '#566b5a', prop: 'harpoon', wide: 0.9, drowned: true },
  shaman: { robe: '#7a9a6a', hat: 'hood', hatCol: '#56744c', prop: 'bowl', drowned: true, eye: '#9fe08a', orb: '#9fe08a' },
  berserker: { robe: '#8a4a4a', hat: 'none', prop: 'hooks', wide: 0.95, drowned: true, eye: PAL.danger },
  overseer: { robe: '#3d5f8a', trim: PAL.bone, hat: 'mitre', hatCol: '#2f4a70', tall: 1.1, prop: 'banner', wide: 1.1, drowned: true },
  krogg: { robe: '#3a7f8a', trim: PAL.brass, hat: 'hood', hatCol: '#28585f', prop: 'keys', wide: 1.35, drowned: true },
  velisse: { robe: '#6a8f9a', trim: PAL.bone, hat: 'veil', prop: 'eggs', wide: 1.3, drowned: true, orb: PAL.glow },
  sulmar: { robe: '#4a3f7a', trim: PAL.gold, hat: 'mitre', hatCol: PAL.brass, tall: 1.9, prop: 'bell', drowned: true, eye: PAL.gold, orb: PAL.gold },
  hatchling: { robe: '#4fa3a0', hat: 'none', prop: 'none', crab: true, drowned: true },
};

const PLAIN: Look = { robe: PAL.stone, hat: 'none', prop: 'none' };
export const lookOf = (hero: string | undefined, enemy: string | undefined) => (hero ? HERO_LOOK[hero] : ENEMY_LOOK[enemy ?? '']) ?? PLAIN;

const GREY = '#6f7d82';

function orb(g: CanvasRenderingContext2D, x: number, y: number, r: number, color: string, power = 1) {
  const grad = g.createRadialGradient(x, y, 0, x, y, r * 3.2);
  grad.addColorStop(0, rgba(color, 0.55 * power));
  grad.addColorStop(1, rgba(color, 0));
  g.fillStyle = grad;
  g.fillRect(x - r * 3.2, y - r * 3.2, r * 6.4, r * 6.4);
  g.fillStyle = color;
  g.beginPath(); g.arc(x, y, r, 0, TAU); g.fill();
}

// Drawn with the feet at the origin. The caller has already moved there.
export function drawFigure(g: CanvasRenderingContext2D, look: Look, p: Pose) {
  const H = p.H;
  // colour with the pose's state applied: struck, fallen, or turning to light
  const c = (col: string) => {
    if (p.grey) return mix(col, GREY, 0.75);
    if (p.rest > 0) return mix(col, '#d8fff4', Math.min(1, p.rest * 1.1));
    return p.flash ? mix(col, '#ffffff', 0.45) : col;
  };
  const soft = (col: string, y0: number, y1: number) => {
    const grad = g.createLinearGradient(0, y0, 0, y1);
    grad.addColorStop(0, mix(c(col), '#ffffff', 0.2));
    grad.addColorStop(1, mix(c(col), PAL.ink, 0.38));
    return grad;
  };
  const edge = (col: string) => { g.strokeStyle = mix(c(col), PAL.ink, 0.6); g.lineWidth = Math.max(1, H * 0.022); g.stroke(); };

  g.save();
  g.scale(p.dir, 1);
  g.lineJoin = 'round';
  g.lineCap = 'round';

  if (look.crab) { crab(g, look, p, c, soft); g.restore(); return; }

  const breathe = Math.sin(p.time * 2.2 + H) * 0.008 * H;
  const bob = -Math.abs(p.step) * 0.035 * H + breathe;
  const w = 0.2 * H * (look.wide ?? 1), bh = 0.5 * H, r = 0.185 * H;
  const cy = -bh - r * 0.7 + bob;
  const sway = p.step * 0.03 * H;
  const hx = w * 0.95, hy = -bh * 0.52 + bob;
  const trim = look.trim ?? mix(look.robe, PAL.ink, 0.35);
  const eye = look.eye ?? PAL.glow;
  const power = p.casting ? 1.6 + 0.4 * Math.sin(p.time * 16) : 1;
  g.translate(p.swing * H * 0.07, 0);

  // feet
  g.fillStyle = mix(c(look.robe), PAL.ink, 0.7);
  for (const k of [-1, 1]) {
    g.beginPath();
    g.ellipse(k * w * 0.45 + k * p.step * H * 0.05, -Math.max(0, k * p.step) * H * 0.05, H * 0.085, H * 0.042, 0, 0, TAU);
    g.fill();
  }

  // the back hand's share of a two-handed kit
  if (look.prop === 'shield') {
    g.save();
    g.translate(-hx, hy);
    g.rotate(-0.5 + p.swing * 1.7);
    g.strokeStyle = c(PAL.wood); g.lineWidth = H * 0.05;
    g.beginPath(); g.moveTo(0, 0); g.lineTo(0, -H * 0.42); g.stroke();
    g.fillStyle = soft(PAL.steel, -H * 0.52, -H * 0.36);
    g.beginPath(); g.arc(0, -H * 0.44, H * 0.085, 0, TAU); g.fill(); edge(PAL.steel);
    g.restore();
  }
  if (look.prop === 'hooks') hook(g, -hx, hy, -1, p, H, c);

  // staves stand behind the body
  if (look.prop === 'lantern' || look.prop === 'crook' || look.prop === 'candle' || look.prop === 'bell' || look.prop === 'banner') {
    g.save();
    g.translate(hx + H * 0.03, hy);
    g.rotate(p.swing * 0.45);
    const top = look.prop === 'bell' || look.prop === 'banner' ? -H * 0.78 : -H * 0.62, foot = bh * 0.52 - bob;
    g.strokeStyle = c(look.prop === 'crook' ? '#4f7d4a' : PAL.wood);
    g.lineWidth = H * 0.05;
    g.beginPath(); g.moveTo(0, foot); g.lineTo(0, top); g.stroke();
    if (look.prop === 'lantern') {
      g.fillStyle = c(PAL.brass);
      g.fillRect(-H * 0.075, top - H * 0.17, H * 0.15, H * 0.19);
      orb(g, 0, top - H * 0.075, H * 0.05 * power, look.orb ?? PAL.glow, power);
    } else if (look.prop === 'crook') {
      g.beginPath(); g.arc(-H * 0.09, top, H * 0.09, Math.PI, 0); g.stroke();
      orb(g, -H * 0.18, top + H * 0.03, H * 0.04 * power, look.orb ?? '#9fe08a', power);
    } else if (look.prop === 'candle') {
      g.fillStyle = c(PAL.bone);
      g.fillRect(-H * 0.045, top - H * 0.13, H * 0.09, H * 0.14);
      orb(g, 0, top - H * 0.2, H * 0.05 * power, look.orb ?? PAL.gold, power);
    } else if (look.prop === 'bell') {
      g.fillStyle = soft(PAL.brass, top - H * 0.2, top + H * 0.08);
      g.beginPath();
      g.moveTo(-H * 0.14, top + H * 0.08);
      g.quadraticCurveTo(-H * 0.02, top - H * 0.34, H * 0.14, top + H * 0.08);
      g.closePath(); g.fill(); edge(PAL.brass);
      orb(g, 0, top + H * 0.1, H * 0.03 * power, look.orb ?? PAL.gold, power);
    } else {
      g.fillStyle = c(mix(PAL.danger, PAL.ink, 0.35));
      const fl = Math.sin(p.time * 3) * H * 0.02;
      g.beginPath();
      g.moveTo(0, top); g.lineTo(-H * 0.3, top + H * 0.05 + fl); g.lineTo(-H * 0.22, top + H * 0.16);
      g.lineTo(-H * 0.3, top + H * 0.27 - fl); g.lineTo(0, top + H * 0.3);
      g.fill();
    }
    g.restore();
  }

  // body
  const body = () => {
    g.beginPath();
    g.moveTo(-w * 0.62, -bh + bob);
    g.quadraticCurveTo(-w * 1.28, -bh * 0.3, -w * 1.06 + sway, 0);
    g.lineTo(w * 1.06 + sway, 0);
    g.quadraticCurveTo(w * 1.28, -bh * 0.3, w * 0.62, -bh + bob);
    g.closePath();
  };
  body();
  g.fillStyle = soft(look.robe, -bh, 0);
  g.fill(); edge(look.robe);
  g.save();
  body(); g.clip();
  g.fillStyle = c(trim);
  g.fillRect(-w * 1.4, -bh * 0.2, w * 2.8, bh * 0.085);
  if (look.drowned) {
    g.fillStyle = c(PAL.bone);
    for (const [bx, by] of [[-0.45, 0.55], [0.4, 0.68], [0.1, 0.36], [-0.2, 0.8]]) {
      g.beginPath(); g.arc(w * bx, -bh * by, H * 0.022, 0, TAU); g.fill();
    }
  }
  g.restore();
  if (look.prop === 'eggs') {
    const pulse = 0.8 + 0.2 * Math.sin(p.time * 2);
    for (const [ex, ey, er] of [[-1.15, 0.08, 0.07], [-0.5, 0.04, 0.055], [0.45, 0.06, 0.065], [1.15, 0.1, 0.055]]) {
      orb(g, w * ex, -H * ey, H * er * pulse, rgba(PAL.glow, 0.85), 0.7 * power);
    }
  }

  // head
  g.fillStyle = soft(look.drowned ? '#8fb8b0' : look.skin ?? '#e8c6a4', cy - r, cy + r * 1.8);
  g.beginPath(); g.arc(0, cy, r, 0, TAU); g.fill();
  edge(look.drowned ? '#8fb8b0' : look.skin ?? '#e8c6a4');
  if (look.drowned && !p.grey) {
    orb(g, r * 0.12, cy + r * 0.08, r * 0.14, eye, 0.6);
    orb(g, r * 0.62, cy + r * 0.08, r * 0.14, eye, 0.6);
  } else {
    g.fillStyle = PAL.ink;
    g.beginPath(); g.arc(r * 0.12, cy + r * 0.08, r * 0.13, 0, TAU); g.arc(r * 0.62, cy + r * 0.08, r * 0.13, 0, TAU); g.fill();
    if (!p.grey) {
      g.fillStyle = 'rgba(230,120,110,0.4)';
      g.beginPath(); g.arc(r * 0.74, cy + r * 0.42, r * 0.2, 0, TAU); g.fill();
    }
  }

  // hat
  const hc = look.hatCol ?? look.robe;
  g.fillStyle = soft(hc, cy - r * 1.8, cy + r * 0.4);
  if (look.hat === 'hood') {
    g.beginPath();
    g.arc(-r * 0.12, cy, r * 1.2, Math.PI * 0.86, Math.PI * 2.05);
    g.quadraticCurveTo(r * 0.3, cy - r * 0.5, -r * 0.75, cy + r * 0.7);
    g.closePath(); g.fill(); edge(hc);
  } else if (look.hat === 'helm') {
    g.beginPath(); g.arc(0, cy - r * 0.08, r * 1.08, Math.PI, 0); g.closePath(); g.fill(); edge(hc);
    g.fillStyle = c(hc);
    g.fillRect(r * 0.3, cy - r * 0.12, r * 0.18, r * 0.6);
    g.fillStyle = c(PAL.gold);
    g.beginPath(); g.arc(0, cy - r * 1.18, r * 0.2, 0, TAU); g.fill();
  } else if (look.hat === 'kelp') {
    for (const a of [-0.7, 0, 0.7]) {
      g.save();
      g.translate(a * r * 0.6, cy - r * 0.85);
      g.rotate(a * 0.6 + Math.sin(p.time * 2 + a) * 0.06);
      g.beginPath(); g.ellipse(0, -r * 0.45, r * 0.28, r * 0.7, 0, 0, TAU); g.fill();
      g.restore();
    }
  } else if (look.hat === 'bandana') {
    g.beginPath(); g.arc(0, cy, r * 1.05, Math.PI * 1.06, Math.PI * 1.94); g.closePath(); g.fill(); edge(hc);
    g.beginPath();
    g.moveTo(-r * 0.95, cy - r * 0.4); g.lineTo(-r * 1.8, cy - r * 0.1 + Math.sin(p.time * 5) * r * 0.1); g.lineTo(-r * 1.2, cy + r * 0.2);
    g.fill();
  } else if (look.hat === 'souwester') {
    g.beginPath(); g.arc(0, cy - r * 0.25, r * 1.02, Math.PI, 0); g.fill();
    g.beginPath(); g.ellipse(-r * 0.2, cy - r * 0.25, r * 1.75, r * 0.34, 0.1, 0, TAU); g.fill(); edge(hc);
  } else if (look.hat === 'brim') {
    g.beginPath(); g.ellipse(0, cy - r * 0.72, r * 1.6, r * 0.3, 0, 0, TAU); g.fill();
    g.fillRect(-r * 0.62, cy - r * 1.45, r * 1.24, r * 0.75);
    g.fillStyle = c(PAL.bone);
    g.fillRect(-r * 0.14, cy - r * 1.95, r * 0.28, r * 0.5);
    orb(g, 0, cy - r * 2.15, r * 0.18, PAL.gold, power);
  } else if (look.hat === 'mitre') {
    const t = look.tall ?? 1;
    g.beginPath();
    g.moveTo(-r * 0.95, cy - r * 0.45); g.lineTo(0, cy - r * (1.1 + t)); g.lineTo(r * 0.95, cy - r * 0.45);
    g.closePath(); g.fill(); edge(hc);
    g.fillStyle = c(PAL.gold);
    g.fillRect(-r * 0.9, cy - r * 0.62, r * 1.8, r * 0.2);
  } else if (look.hat === 'veil') {
    g.fillStyle = soft(PAL.bone, cy - r, cy + r * 1.6);
    g.beginPath();
    g.arc(0, cy, r * 1.14, Math.PI, 0);
    g.lineTo(r * 1.5, cy + r * 1.5); g.lineTo(r * 0.7, cy + r * 0.2); g.lineTo(-r * 0.2, cy - r * 0.3);
    g.lineTo(-r * 1.0, cy + r * 0.3); g.lineTo(-r * 1.6, cy + r * 1.5);
    g.closePath(); g.fill(); edge(PAL.bone);
  }

  // the front hand and what it holds
  const hand = () => { g.fillStyle = c(look.drowned ? '#8fb8b0' : look.skin ?? '#e8c6a4'); g.beginPath(); g.arc(0, 0, H * 0.045, 0, TAU); g.fill(); };
  if (look.prop === 'shield') {
    g.save();
    g.translate(hx + p.swing * H * 0.06, hy);
    g.fillStyle = soft(PAL.steel, -H * 0.2, H * 0.22);
    g.beginPath();
    g.moveTo(-H * 0.13, -H * 0.2); g.lineTo(H * 0.13, -H * 0.2); g.lineTo(H * 0.13, H * 0.04);
    g.quadraticCurveTo(H * 0.1, H * 0.2, 0, H * 0.25);
    g.quadraticCurveTo(-H * 0.1, H * 0.2, -H * 0.13, H * 0.04);
    g.closePath(); g.fill(); edge(PAL.steel);
    g.fillStyle = c(PAL.gold);
    g.beginPath(); g.arc(0, -H * 0.02, H * 0.045, 0, TAU); g.fill();
    g.restore();
  } else if (look.prop === 'cutlass') {
    g.save();
    g.translate(hx, hy);
    g.rotate(0.5 + p.swing * 1.7);
    g.strokeStyle = c(PAL.steel); g.lineWidth = H * 0.055;
    g.beginPath(); g.moveTo(0, 0); g.quadraticCurveTo(H * 0.14, -H * 0.24, 0, -H * 0.46); g.stroke();
    g.fillStyle = c(PAL.gold);
    g.fillRect(-H * 0.07, -H * 0.02, H * 0.14, H * 0.04);
    hand();
    g.restore();
  } else if (look.prop === 'harpoon') {
    g.save();
    g.translate(hx - H * 0.1 + p.swing * H * 0.22, hy);
    g.rotate(-0.42);
    g.strokeStyle = c(PAL.wood); g.lineWidth = H * 0.04;
    g.beginPath(); g.moveTo(-H * 0.34, 0); g.lineTo(H * 0.44, 0); g.stroke();
    g.fillStyle = c(PAL.steel);
    g.beginPath(); g.moveTo(H * 0.58, 0); g.lineTo(H * 0.4, -H * 0.07); g.lineTo(H * 0.45, 0); g.lineTo(H * 0.4, H * 0.07); g.closePath(); g.fill();
    g.translate(H * 0.1, 0); hand();
    g.restore();
  } else if (look.prop === 'anchor' || look.prop === 'keys') {
    g.save();
    g.translate(hx, hy);
    g.rotate(0.45 + p.swing * 1.6);
    const len = H * 0.5, metal = look.prop === 'keys' ? PAL.brass : PAL.steel;
    g.strokeStyle = c(look.prop === 'keys' ? PAL.brass : PAL.wood); g.lineWidth = H * 0.05;
    g.beginPath(); g.moveTo(0, H * 0.06); g.lineTo(0, -len); g.stroke();
    g.strokeStyle = c(metal);
    g.lineWidth = H * 0.05;
    g.beginPath();
    if (look.prop === 'anchor') { g.arc(0, -len + H * 0.02, H * 0.13, Math.PI * 1.05, Math.PI * 1.95, true); }
    else { g.arc(0, H * 0.12, H * 0.07, 0, TAU); g.moveTo(0, -len); g.lineTo(H * 0.11, -len); g.moveTo(0, -len + H * 0.09); g.lineTo(H * 0.09, -len + H * 0.09); }
    g.stroke();
    hand();
    g.restore();
  } else if (look.prop === 'hooks') {
    hook(g, hx, hy, 1, p, H, c);
  } else if (look.prop === 'book') {
    g.save();
    g.translate(hx, hy);
    g.fillStyle = c(PAL.bone);
    g.beginPath(); g.moveTo(-H * 0.12, -H * 0.04); g.lineTo(0, 0); g.lineTo(H * 0.12, -H * 0.04); g.lineTo(H * 0.12, H * 0.06); g.lineTo(0, H * 0.1); g.lineTo(-H * 0.12, H * 0.06); g.closePath(); g.fill();
    orb(g, 0, -H * 0.14 - Math.sin(p.time * 3) * H * 0.02, H * 0.04 * power, look.orb ?? PAL.violet, power);
    g.restore();
  } else if (look.prop === 'bowl') {
    g.save();
    g.translate(hx, hy);
    g.fillStyle = c(PAL.wood);
    g.beginPath(); g.arc(0, 0, H * 0.1, 0, Math.PI); g.fill();
    orb(g, 0, -H * 0.04, H * 0.045 * power, look.orb ?? '#9fe08a', power);
    g.restore();
  } else if (look.prop !== 'eggs' && look.prop !== 'none') {
    g.save(); g.translate(hx + H * 0.03, hy); hand(); g.restore();
  }
  g.restore();
}

function hook(g: CanvasRenderingContext2D, x: number, y: number, side: number, p: Pose, H: number, c: (col: string) => string) {
  g.save();
  g.translate(x, y);
  g.rotate(side * 0.4 + p.swing * (side > 0 ? 1.5 : 1.1));
  g.strokeStyle = c(PAL.wood); g.lineWidth = H * 0.045;
  g.beginPath(); g.moveTo(0, 0); g.lineTo(0, -H * 0.24); g.stroke();
  g.strokeStyle = c(PAL.steel);
  g.beginPath(); g.arc(H * 0.07, -H * 0.24, H * 0.07, Math.PI, Math.PI * 2.2); g.stroke();
  g.restore();
}

function crab(g: CanvasRenderingContext2D, look: Look, p: Pose, c: (col: string) => string, soft: (col: string, y0: number, y1: number) => CanvasGradient) {
  const H = p.H, bob = Math.sin(p.time * 9 + H) * H * 0.03;
  g.strokeStyle = mix(c(look.robe), PAL.ink, 0.35);
  g.lineWidth = H * 0.08;
  for (const k of [-1, 1]) for (const a of [0.25, 0.42, 0.6]) {
    const lift = Math.sin(p.time * 14 + a * 20 + k) * H * 0.04 * (p.step ? 1 : 0.2);
    g.beginPath(); g.moveTo(k * H * a * 0.8, -H * 0.3 + bob); g.lineTo(k * H * (a + 0.22), -lift); g.stroke();
  }
  // claws
  for (const k of [-1, 1]) {
    g.fillStyle = c(look.robe);
    g.beginPath(); g.arc(k * H * 0.55, -H * 0.62 + bob - p.swing * H * 0.2, H * 0.15, 0, TAU); g.fill();
  }
  g.fillStyle = soft(look.robe, -H * 0.85, 0);
  g.beginPath(); g.ellipse(0, -H * 0.42 + bob, H * 0.5, H * 0.36, 0, 0, TAU); g.fill();
  g.fillStyle = c(PAL.bone);
  for (const [bx, by] of [[-0.25, 0.6], [0.2, 0.66], [0, 0.3]]) { g.beginPath(); g.arc(H * bx, -H * by + bob, H * 0.035, 0, TAU); g.fill(); }
  if (p.grey) return;
  orb(g, H * 0.08, -H * 0.5 + bob, H * 0.06, PAL.danger, 0.6);
  orb(g, H * 0.3, -H * 0.5 + bob, H * 0.06, PAL.danger, 0.6);
}
