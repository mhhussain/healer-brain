import type { World } from '../sim/world';
import { TIME_LIMIT } from '../sim/world';
import { PAL, TAU, hash, mix, rgba } from './palette';

// The three zones of the Drowned Abbey. Each has its own wall height, stone and backdrop.
export const SEA_GATE = 0, INFIRMARY = 1, NAVE = 2;
export const WALL_H = [3.4, 6, 7.5];
export const PILLAR_H = 3.2;
export const DEPTH = 0.6;
export const LEDGE = 0.7;

const STONE = [
  { wallA: '#7a9596', wallB: '#3f5f68', cap: '#a9c2bc', floorA: '#56767e', floorB: '#2c4853', dark: '#0d2530' },
  { wallA: '#2f4c57', wallB: '#152e38', cap: '#486973', floorA: '#31505b', floorB: '#142933', dark: '#061219' },
  { wallA: '#4d647c', wallB: '#25374d', cap: '#7289a6', floorA: '#41627a', floorB: '#1b3145', dark: '#0a1a2c' },
];
const GLASS = [PAL.glow, PAL.gold, PAL.violet, PAL.danger, '#6fb0e8'];

// What the scenery needs to know about the camera. The renderer implements it.
export interface View {
  ctx: CanvasRenderingContext2D;
  w: number;
  h: number;
  scale: number;
  camX: number;
  oy: number;
  front: number;
  wallAt: number[];
  zoneEnd: number[];
  lampX: number[];
  // 0 to 1: how far each zone's lamp has come alight
  lit: number[];
  // 0 to 1: how hard the great bell is swinging
  toll: number;
  sx(x: number): number;
  sy(y: number, z?: number): number;
  wallFront(x: number): number;
  zoneAt(x: number): number;
  floorSpace(): void;
  screenSpace(): void;
}

const isBack = (v: View, x: number) => {
  const wf = v.wallFront(x);
  return wf < v.front - 8 && v.wallFront(x - 1) === wf && v.wallFront(x + 1) === wf;
};

function glow(g: CanvasRenderingContext2D, x: number, y: number, r: number, color: string, a: number) {
  const grad = g.createRadialGradient(x, y, 0, x, y, r);
  grad.addColorStop(0, rgba(color, a));
  grad.addColorStop(1, rgba(color, 0));
  g.fillStyle = grad;
  g.fillRect(x - r, y - r, r * 2, r * 2);
}

// ---------- backdrops, far behind the walls

export function drawBackdrop(v: View, time: number) {
  const g = v.ctx;
  let start = -1e6;
  for (let k = 0; k < 3; k++) {
    const end = k === 2 ? 1e6 : v.zoneEnd[k];
    const a = Math.max(0, v.sx(start)), b = Math.min(v.w, v.sx(end));
    start = end;
    if (b <= a) continue;
    g.save();
    g.beginPath();
    g.rect(a, 0, b - a, v.h);
    g.clip();
    if (k === SEA_GATE) skyGate(v, time);
    else if (k === INFIRMARY) skyUndercroft(v, time);
    else skyNave(v, time);
    g.restore();
  }
}

// Screen x of a far-away thing at world x, moving at a fraction f of the camera's speed.
const far = (v: View, wx: number, f: number) => (wx - v.camX * f) * v.scale * 0.8 + v.w / 2;
function eachFar(v: View, step: number, f: number, fn: (x: number, i: number) => void) {
  const half = v.w / 2 / (v.scale * 0.8);
  const i0 = Math.floor((v.camX * f - half) / step) - 1, i1 = Math.ceil((v.camX * f + half) / step) + 1;
  for (let i = i0; i <= i1; i++) fn(far(v, i * step, f), i);
}

function skyGate(v: View, time: number) {
  const g = v.ctx, s = v.scale;
  const hz = v.oy + 4 * s * DEPTH - 4.7 * s;
  const sky = g.createLinearGradient(0, 0, 0, hz);
  sky.addColorStop(0, '#0f3340');
  sky.addColorStop(0.65, '#2d7a7c');
  sky.addColorStop(1, '#9bd6b9');
  g.fillStyle = sky;
  g.fillRect(0, 0, v.w, hz);
  // low moon
  const mx = far(v, 60, 0.04) + v.w * 0.18, my = hz * 0.42;
  glow(g, mx, my, 5 * s, '#f3e6b8', 0.35);
  g.fillStyle = '#f6ecc6';
  g.beginPath(); g.arc(mx, my, 0.9 * s, 0, TAU); g.fill();
  // long clouds
  g.fillStyle = 'rgba(233,226,207,0.10)';
  eachFar(v, 23, 0.08, (x, i) => {
    g.beginPath();
    g.ellipse(x, hz * (0.25 + 0.4 * hash(i)), (5 + 4 * hash(i + 9)) * s, 0.35 * s, 0, 0, TAU);
    g.fill();
  });
  // the sea
  const sea = g.createLinearGradient(0, hz, 0, hz + 6 * s);
  sea.addColorStop(0, '#2a7480');
  sea.addColorStop(1, '#0e3340');
  g.fillStyle = sea;
  g.fillRect(0, hz, v.w, v.h - hz);
  g.fillStyle = 'rgba(246,236,198,0.5)';
  for (let i = 0; i < 14; i++) {
    const w = (0.4 + hash(i) * 1.4) * s * (0.6 + 0.4 * Math.sin(time * 1.3 + i * 2.1));
    g.fillRect(mx - w / 2 + (hash(i + 3) - 0.5) * 1.2 * s, hz + 3 + i * 0.16 * s, w, 1.5);
  }
  // ruined arches out in the surf
  g.fillStyle = '#1c5260';
  eachFar(v, 13, 0.3, (x, i) => {
    const base = hz + 0.9 * s, hgt = (2.2 + 2 * hash(i)) * s, wid = 2.6 * s;
    g.fillRect(x, base - hgt, 0.7 * s, hgt);
    if (hash(i + 5) > 0.35) {
      g.fillRect(x + wid, base - hgt * 0.8, 0.7 * s, hgt * 0.8);
      g.beginPath();
      g.moveTo(x, base - hgt);
      g.quadraticCurveTo(x + wid / 2 + 0.35 * s, base - hgt - 1.6 * s, x + wid + 0.7 * s, base - hgt * 0.8);
      g.lineTo(x + wid, base - hgt * 0.8);
      g.quadraticCurveTo(x + wid / 2 + 0.35 * s, base - hgt - 0.8 * s, x + 0.7 * s, base - hgt * 0.9);
      g.fill();
    }
  });
  // gulls
  g.strokeStyle = 'rgba(233,226,207,0.7)';
  g.lineWidth = 1.5;
  for (let i = 0; i < 4; i++) {
    const gx = ((time * (12 + i * 5) + i * 400) % (v.w + 200)) - 100, gy = hz * (0.2 + 0.12 * i) + Math.sin(time * 1.5 + i) * 6;
    const flap = Math.sin(time * 7 + i * 2) * 3;
    g.beginPath();
    g.moveTo(gx - 7, gy - flap); g.quadraticCurveTo(gx - 3, gy - 4, gx, gy); g.quadraticCurveTo(gx + 3, gy - 4, gx + 7, gy - flap);
    g.stroke();
  }
}

function skyUndercroft(v: View, time: number) {
  const g = v.ctx, s = v.scale;
  g.fillStyle = '#050f15';
  g.fillRect(0, 0, v.w, v.h);
  const base = v.oy + 6 * s * DEPTH;
  for (const [f, col, step, rise] of [[0.35, '#0a202a', 12, 9], [0.6, '#0f2b37', 9, 7.5]] as const) {
    g.fillStyle = col;
    eachFar(v, step, f, (x) => {
      const wd = step * s * 0.8;
      g.beginPath();
      g.moveTo(x, base);
      g.lineTo(x, base - rise * s * 0.55);
      g.quadraticCurveTo(x + wd / 2, base - rise * s * 1.15, x + wd, base - rise * s * 0.55);
      g.lineTo(x + wd, base);
      g.lineTo(x + wd * 0.88, base);
      g.lineTo(x + wd * 0.88, base - rise * s * 0.5);
      g.quadraticCurveTo(x + wd / 2, base - rise * s * 0.98, x + wd * 0.12, base - rise * s * 0.5);
      g.lineTo(x + wd * 0.12, base);
      g.fill();
    });
  }
  // far egg-light
  eachFar(v, 7, 0.5, (x, i) => {
    const y = base - (2 + 5 * hash(i)) * s;
    glow(g, x, y, (1.2 + hash(i + 2)) * s, PAL.glow, 0.16 + 0.08 * Math.sin(time * 0.9 + i));
  });
}

function skyNave(v: View, time: number) {
  const g = v.ctx, s = v.scale;
  const grad = g.createLinearGradient(0, 0, 0, v.h * 0.6);
  grad.addColorStop(0, '#060f1c');
  grad.addColorStop(1, '#122c44');
  g.fillStyle = grad;
  g.fillRect(0, 0, v.w, v.h);
  const base = v.oy + 6 * s * DEPTH;
  // distant windows between distant columns
  eachFar(v, 10, 0.4, (x, i) => {
    const col = GLASS[((i % 5) + 5) % 5];
    const wx = x + 3.4 * s, top = base - 11 * s, wd = 1.6 * s;
    g.fillStyle = rgba(col, 0.2 + 0.05 * Math.sin(time * 0.5 + i));
    g.beginPath();
    g.moveTo(wx, base - 2 * s); g.lineTo(wx, top + wd); g.quadraticCurveTo(wx + wd / 2, top - wd * 0.4, wx + wd, top + wd); g.lineTo(wx + wd, base - 2 * s);
    g.fill();
    g.fillStyle = '#0d2136';
    g.fillRect(x, 0, 1.3 * s, base);
  });
  // slanting light
  for (let i = 0; i < 3; i++) {
    const x = far(v, v.zoneEnd[1] + 20 + i * 34, 0.55);
    const shaft = g.createLinearGradient(0, 0, 0, base);
    shaft.addColorStop(0, rgba(GLASS[i], 0.14));
    shaft.addColorStop(1, rgba(GLASS[i], 0));
    g.fillStyle = shaft;
    g.beginPath();
    g.moveTo(x, 0); g.lineTo(x + 2.5 * s, 0); g.lineTo(x + 9 * s, base); g.lineTo(x + 3 * s, base);
    g.fill();
  }
}

// ---------- walls and floor, one run of equal columns at a time

export function drawHall(v: View, world: World, time: number) {
  const g = v.ctx, s = v.scale;
  const x0 = Math.floor(v.camX - v.w / 2 / s) - 1, x1 = Math.ceil(v.camX + v.w / 2 / s) + 1;
  const frontY = v.sy(v.front);
  let run = x0;
  for (let x = x0; x <= x1; x++) {
    if (x < x1 && v.wallFront(x + 1) === v.wallFront(run) && v.zoneAt(x + 1) === v.zoneAt(run)) continue;
    const wf = v.wallFront(run), zone = v.zoneAt(run), st = STONE[zone], wh = WALL_H[zone];
    const left = Math.floor(v.sx(run)), wide = Math.ceil(v.sx(x + 1)) - left;
    const faceBottom = v.sy(wf), faceTop = faceBottom - wh * s;
    const grad = g.createLinearGradient(0, faceTop, 0, faceBottom);
    grad.addColorStop(0, st.wallA);
    grad.addColorStop(1, st.wallB);
    g.fillStyle = grad;
    g.fillRect(left, faceTop, wide, faceBottom - faceTop);
    // the Sea Gate is a ruin: its wall tops are broken and uneven
    if (zone === SEA_GATE) {
      for (let cx = run; cx <= x; cx++) {
        const up = Math.floor(hash(cx * 3.1) * 3) * 0.3 * s;
        if (up <= 0) continue;
        g.fillStyle = st.wallA;
        g.fillRect(Math.floor(v.sx(cx)), faceTop - up, Math.ceil(s) + 1, up + 1);
        g.fillStyle = st.cap;
        g.fillRect(Math.floor(v.sx(cx)), faceTop - up, Math.ceil(s) + 1, 2);
      }
    }
    // courses of stone
    g.strokeStyle = 'rgba(4,9,12,0.2)';
    g.lineWidth = 1;
    g.beginPath();
    for (let k = 1; k < wh; k++) {
      const y = Math.round(faceBottom - k * s) + 0.5;
      g.moveTo(left, y); g.lineTo(left + wide, y);
    }
    for (let cx = run; cx <= x; cx++) {
      if (cx % 2) continue;
      for (let k = 0; k < wh; k++) {
        const bx = Math.round(v.sx(cx + (k % 2))) + 0.5;
        g.moveTo(bx, faceBottom - k * s); g.lineTo(bx, Math.max(faceTop, faceBottom - (k + 1) * s));
      }
    }
    g.stroke();
    g.fillStyle = st.cap;
    g.fillRect(left, faceTop - 2, wide, 3);
    // tide line: the bottom of every wall is darker and greener
    const damp = g.createLinearGradient(0, faceBottom - 1.3 * s, 0, faceBottom);
    damp.addColorStop(0, 'rgba(10,50,48,0)');
    damp.addColorStop(1, 'rgba(10,50,48,0.55)');
    g.fillStyle = damp;
    g.fillRect(left, faceBottom - 1.3 * s, wide, 1.3 * s);
    if (wf < v.front) {
      const fl = g.createLinearGradient(0, faceBottom, 0, frontY);
      fl.addColorStop(0, st.floorB);
      fl.addColorStop(1, st.floorA);
      g.fillStyle = fl;
      g.fillRect(left, faceBottom, wide, frontY - faceBottom);
      g.fillStyle = mix(st.floorB, PAL.ink, 0.45);
      g.fillRect(left, frontY, wide, v.h - frontY);
      g.fillStyle = st.cap;
      g.fillRect(left, frontY - 1, wide, 2);
      const sh = g.createLinearGradient(0, faceBottom, 0, faceBottom + 0.9 * s);
      sh.addColorStop(0, 'rgba(0,0,0,0.42)');
      sh.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = sh;
      g.fillRect(left, faceBottom, wide, 0.9 * s);
    } else {
      g.fillStyle = mix(st.wallB, PAL.ink, 0.5);
      g.fillRect(left, faceBottom, wide, v.h - faceBottom);
    }
    // the near corner of a wall that stands in front of its neighbour
    for (const [edge, other] of [[run, run - 1], [x + 1, x + 1]] as const) {
      if (v.wallFront(other) >= wf) continue;
      g.fillStyle = st.cap;
      g.fillRect(Math.round(v.sx(edge)) - 1, faceTop, 2, faceBottom - faceTop);
    }
    run = x + 1;
  }

  drawFloorDetail(v, world, x0, x1, time);
  drawWallDecor(v, x0, x1, time);
}

function drawFloorDetail(v: View, world: World, x0: number, x1: number, time: number) {
  const g = v.ctx, m = world.map;
  v.floorSpace();
  const a = Math.max(0, x0), b = Math.min(m.w - 1, x1);
  // flagstones, two metres square, every other row offset
  g.fillStyle = 'rgba(4,9,12,0.16)';
  for (let x = a; x <= b; x++) {
    const back = v.wallAt[x];
    if (back < 0) continue;
    for (let y = back; y < v.front; y++) {
      if (y % 2 === 0) g.fillRect(x, y, 1, 0.07);
      if ((x + (y >> 1 & 1)) % 2 === 0) g.fillRect(x, y, 0.045, 1);
    }
  }
  // standing water and its shimmer
  for (let x = a; x <= b; x++) {
    const back = v.wallAt[x];
    if (back < 0 || hash(x * 1.7) < 0.8) continue;
    const y = back + 1.5 + hash(x * 2.3) * (v.front - back - 3), r = 0.9 + hash(x * 5.1) * 1.3;
    g.fillStyle = 'rgba(4,20,28,0.22)';
    g.beginPath(); g.ellipse(x + 0.5, y, r, r * 0.6, 0, 0, TAU); g.fill();
    g.fillStyle = rgba(PAL.glow, 0.1 + 0.06 * Math.sin(time * 1.4 + x));
    g.beginPath(); g.ellipse(x + 0.5 - r * 0.2, y - r * 0.1, r * 0.5, r * 0.16, 0, 0, TAU); g.fill();
  }
  g.fillStyle = rgba(PAL.glow, 0.09);
  for (let x = a; x <= b; x++) {
    const back = v.wallAt[x];
    if (back < 0) continue;
    const y = back + 0.5 + hash(x * 7.7) * (v.front - back - 1);
    g.fillRect(x, y, 0.8 + hash(x) * 1.4, 0.06);
  }
  // what is left of a pillar the bell has shattered
  for (const pl of m.pillars) {
    if (pl.alive) continue;
    g.fillStyle = '#62788a';
    for (let i = 0; i < 7; i++) {
      const an = i * 2.4 + pl.id;
      g.beginPath();
      g.arc(pl.x + pl.w / 2 + Math.cos(an) * pl.w * 0.38, pl.y + pl.h / 2 + Math.sin(an) * pl.h * 0.38, 0.26 + (i % 3) * 0.13, 0, TAU);
      g.fill();
    }
  }
  v.screenSpace();
}

// ---------- things on and against the back wall

function drawWallDecor(v: View, x0: number, x1: number, time: number) {
  const g = v.ctx, s = v.scale;
  for (let x = x0 - 2; x <= x1 + 2; x++) {
    if (!isBack(v, x)) continue;
    const zone = v.zoneAt(x), wf = v.wallFront(x), foot = v.sy(wf), cx = v.sx(x + 0.5);
    const lit = v.lit[zone];
    if (zone === SEA_GATE) {
      if (((x % 8) + 8) % 8 === 4 && isBack(v, x - 2) && isBack(v, x + 2)) archOpening(v, cx, foot);
      if (hash(x * 9.3) > 0.55) kelp(v, v.sx(x + hash(x)), foot - WALL_H[0] * s, (0.9 + hash(x * 4.4) * 1.6) * s, time + x);
      if (((x % 12) + 12) % 12 === 0) lantern(v, cx, foot, lit, time + x);
    } else if (zone === INFIRMARY) {
      if (((x % 6) + 6) % 6 === 3) pilaster(v, cx, foot, WALL_H[1] * s, '#1d3742');
      if (((x % 12) + 12) % 12 === 6) eggs(v, cx, foot - 2.4 * s, time + x, x);
      if (((x % 12) + 12) % 12 === 0) cot(v, cx, foot);
      if (hash(x * 3.3) > 0.7) {
        g.fillStyle = rgba(PAL.glow, 0.1);
        g.fillRect(cx, foot - WALL_H[1] * s, 2, WALL_H[1] * s * (0.4 + 0.5 * hash(x * 8.8)));
      }
    } else {
      if (((x % 8) + 8) % 8 === 4 && isBack(v, x - 1) && isBack(v, x + 1)) glassWindow(v, cx, foot, x, lit, time);
      if (((x % 8) + 8) % 8 === 0) candles(v, cx, foot, time + x, 0.7 + 0.3 * lit);
    }
  }
  for (let k = 0; k < 3; k++) {
    const lx = v.lampX[k];
    if (lx < x0 - 12 || lx > x1 + 12) continue;
    if (k === NAVE) greatBell(v, lx, time);
    sanctuaryLamp(v, v.sx(lx), v.sy(v.wallFront(Math.floor(lx))), v.lit[k], time);
  }
  // warm light floods back through a zone once its lamp burns
  let start = -1e6;
  g.globalCompositeOperation = 'lighter';
  for (let k = 0; k < 3; k++) {
    const end = k === 2 ? 1e6 : v.zoneEnd[k];
    const a = Math.max(0, v.sx(start)), b = Math.min(v.w, v.sx(end));
    start = end;
    if (b <= a || v.lit[k] <= 0) continue;
    g.fillStyle = rgba(PAL.gold, 0.1 * v.lit[k]);
    g.fillRect(a, 0, b - a, v.h);
  }
  g.globalCompositeOperation = 'source-over';
}

function archOpening(v: View, cx: number, foot: number) {
  const g = v.ctx, s = v.scale, hw = 1.2 * s, base = foot - 0.5 * s, top = foot - 2.9 * s;
  const sea = g.createLinearGradient(0, top, 0, base);
  sea.addColorStop(0, '#5fb0a4');
  sea.addColorStop(0.55, '#2a7480');
  sea.addColorStop(1, '#134452');
  g.fillStyle = sea;
  g.beginPath();
  g.moveTo(cx - hw, base); g.lineTo(cx - hw, top + hw * 0.8);
  g.quadraticCurveTo(cx, top - hw * 0.5, cx + hw, top + hw * 0.8);
  g.lineTo(cx + hw, base); g.closePath();
  g.fill();
  g.strokeStyle = '#2f4d56';
  g.lineWidth = Math.max(2, 0.14 * s);
  g.stroke();
  g.fillStyle = '#a9c2bc';
  g.fillRect(cx - hw - 0.1 * s, base, hw * 2 + 0.2 * s, 0.14 * s);
}

function kelp(v: View, x: number, top: number, len: number, t: number) {
  const g = v.ctx, s = v.scale, sway = Math.sin(t * 1.1) * 0.18 * s;
  g.strokeStyle = PAL.kelp;
  g.lineWidth = Math.max(2, 0.13 * s);
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(x, top);
  g.quadraticCurveTo(x + sway * 1.6, top + len * 0.5, x + sway, top + len);
  g.stroke();
  g.fillStyle = '#5f9a5c';
  for (let i = 1; i <= 3; i++) {
    const k = i / 3.4;
    g.beginPath();
    g.ellipse(x + sway * 1.2 * k + (i % 2 ? 1 : -1) * 0.12 * s, top + len * k, 0.16 * s, 0.07 * s, i % 2 ? 0.6 : -0.6, 0, TAU);
    g.fill();
  }
}

function lantern(v: View, cx: number, foot: number, lit: number, t: number) {
  const g = v.ctx, s = v.scale, y = foot - 2.3 * s;
  const col = lit > 0.5 ? PAL.gold : PAL.glow;
  g.globalCompositeOperation = 'lighter';
  glow(g, cx, y, 4 * s, col, (0.16 + 0.1 * lit) * (0.9 + 0.1 * Math.sin(t * 5)));
  g.globalCompositeOperation = 'source-over';
  g.fillStyle = '#1d2f36';
  g.fillRect(cx - 0.05 * s, y, 0.1 * s, 2.3 * s);
  g.fillRect(cx - 0.22 * s, y - 0.36 * s, 0.44 * s, 0.08 * s);
  g.fillRect(cx - 0.22 * s, y + 0.1 * s, 0.44 * s, 0.08 * s);
  g.fillStyle = col;
  g.beginPath(); g.ellipse(cx, y - 0.1 * s, 0.13 * s, 0.2 * s, 0, 0, TAU); g.fill();
}

function pilaster(v: View, cx: number, foot: number, hgt: number, col: string) {
  const g = v.ctx, s = v.scale;
  g.fillStyle = col;
  g.fillRect(cx - 0.3 * s, foot - hgt, 0.6 * s, hgt);
  g.fillStyle = '#3a5a66';
  g.fillRect(cx - 0.42 * s, foot - hgt, 0.84 * s, 0.25 * s);
  g.fillRect(cx - 0.42 * s, foot - 0.3 * s, 0.84 * s, 0.3 * s);
}

function eggs(v: View, cx: number, cy: number, t: number, seed: number) {
  const g = v.ctx, s = v.scale, pulse = 0.75 + 0.25 * Math.sin(t * 1.6);
  g.globalCompositeOperation = 'lighter';
  glow(g, cx, cy, 4.5 * s, PAL.glow, 0.2 * pulse);
  g.globalCompositeOperation = 'source-over';
  for (let i = 0; i < 6; i++) {
    const ex = cx + (hash(seed + i) - 0.5) * 1.5 * s, ey = cy + (hash(seed + i * 3) - 0.5) * 1.1 * s, r = (0.2 + hash(seed + i * 7) * 0.2) * s;
    const grad = g.createRadialGradient(ex - r * 0.3, ey - r * 0.3, 0, ex, ey, r);
    grad.addColorStop(0, '#d8fff4');
    grad.addColorStop(0.5, rgba(PAL.glow, 0.9 * pulse));
    grad.addColorStop(1, '#1f6a70');
    g.fillStyle = grad;
    g.beginPath(); g.arc(ex, ey, r, 0, TAU); g.fill();
  }
}

function cot(v: View, cx: number, foot: number) {
  const g = v.ctx, s = v.scale, y = foot + 0.25 * s;
  g.fillStyle = PAL.wood;
  g.fillRect(cx - 1.1 * s, y - 0.5 * s, 2.2 * s, 0.14 * s);
  g.fillRect(cx - 1.1 * s, y - 1.0 * s, 0.12 * s, 1.0 * s);
  g.fillRect(cx + 0.98 * s, y - 0.7 * s, 0.12 * s, 0.7 * s);
  g.fillStyle = mix(PAL.bone, PAL.mid, 0.35);
  g.beginPath();
  g.moveTo(cx - 0.98 * s, y - 0.5 * s);
  g.quadraticCurveTo(cx - 0.2 * s, y - 1.0 * s, cx + 0.98 * s, y - 0.5 * s);
  g.fill();
}

function glassWindow(v: View, cx: number, foot: number, seed: number, lit: number, time: number) {
  const g = v.ctx, s = v.scale, hw = 0.95 * s, base = foot - 1.5 * s, top = foot - 6.6 * s;
  const tint = GLASS[((seed >> 3) % 5 + 5) % 5];
  const shape = () => {
    g.beginPath();
    g.moveTo(cx - hw, base); g.lineTo(cx - hw, top + hw);
    g.quadraticCurveTo(cx, top - hw * 0.9, cx + hw, top + hw);
    g.lineTo(cx + hw, base); g.closePath();
  };
  g.save();
  shape();
  g.clip();
  const rows = 8, a = 0.5 + 0.35 * lit + 0.05 * Math.sin(time * 0.7 + seed);
  for (let r = 0; r < rows; r++) for (let c = 0; c < 3; c++) {
    g.fillStyle = rgba(GLASS[Math.floor(hash(seed * 13 + r * 3 + c) * 5)], a);
    g.fillRect(cx - hw + (c * hw * 2) / 3, top - hw + (r * (base - top + hw)) / rows, (hw * 2) / 3 + 1, (base - top + hw) / rows + 1);
  }
  g.strokeStyle = PAL.ink;
  g.lineWidth = Math.max(1, 0.05 * s);
  g.beginPath();
  for (let c = 1; c < 3; c++) { g.moveTo(cx - hw + (c * hw * 2) / 3, top - hw); g.lineTo(cx - hw + (c * hw * 2) / 3, base); }
  for (let r = 1; r < rows; r++) { const y = top - hw + (r * (base - top + hw)) / rows; g.moveTo(cx - hw, y); g.lineTo(cx + hw, y); }
  g.stroke();
  g.restore();
  shape();
  g.strokeStyle = '#1a2a3e';
  g.lineWidth = Math.max(2, 0.16 * s);
  g.stroke();
  // coloured light on the floor
  g.globalCompositeOperation = 'lighter';
  g.fillStyle = rgba(tint, 0.07 + 0.08 * lit);
  g.beginPath(); g.ellipse(cx + 0.8 * s, foot + 2.2 * s, 2.2 * s, 1.1 * s, 0, 0, TAU); g.fill();
  g.globalCompositeOperation = 'source-over';
}

function candles(v: View, cx: number, foot: number, t: number, power: number) {
  const g = v.ctx, s = v.scale;
  g.globalCompositeOperation = 'lighter';
  glow(g, cx, foot - 1.5 * s, 4.2 * s, PAL.gold, 0.2 * power * (0.88 + 0.12 * Math.sin(t * 9)));
  g.globalCompositeOperation = 'source-over';
  g.fillStyle = '#2a2f3a';
  g.fillRect(cx - 0.04 * s, foot - 1.1 * s, 0.08 * s, 1.1 * s);
  g.fillRect(cx - 0.4 * s, foot - 1.12 * s, 0.8 * s, 0.07 * s);
  for (const [dx, hgt] of [[-0.34, 0.3], [0, 0.42], [0.34, 0.24]]) {
    g.fillStyle = PAL.bone;
    g.fillRect(cx + dx * s - 0.05 * s, foot - 1.12 * s - hgt * s, 0.1 * s, hgt * s);
    g.fillStyle = PAL.gold;
    g.beginPath();
    g.ellipse(cx + dx * s, foot - 1.2 * s - hgt * s, 0.06 * s, (0.13 + 0.03 * Math.sin(t * 11 + dx * 9)) * s, 0, 0, TAU);
    g.fill();
  }
}

// One of the three lamps the run is about. Dark until its keeper is at rest.
function sanctuaryLamp(v: View, cx: number, foot: number, lit: number, time: number) {
  const g = v.ctx, s = v.scale, y = foot - 3.1 * s;
  g.globalCompositeOperation = 'lighter';
  if (lit > 0) {
    glow(g, cx, y, 11 * s, PAL.gold, 0.34 * lit * (0.93 + 0.07 * Math.sin(time * 6)));
    glow(g, cx, y, 2.2 * s, '#fff3c8', 0.6 * lit);
  } else {
    glow(g, cx, y, 2.4 * s, PAL.glow, 0.1 + 0.05 * Math.sin(time * 2));
  }
  g.globalCompositeOperation = 'source-over';
  g.fillStyle = PAL.brass;
  g.fillRect(cx - 0.07 * s, y + 0.5 * s, 0.14 * s, 2.6 * s);
  g.beginPath();
  g.moveTo(cx - 0.6 * s, foot); g.lineTo(cx + 0.6 * s, foot); g.lineTo(cx + 0.14 * s, foot - 0.4 * s); g.lineTo(cx - 0.14 * s, foot - 0.4 * s);
  g.fill();
  g.fillRect(cx - 0.5 * s, y + 0.42 * s, s, 0.12 * s);
  g.beginPath();
  g.moveTo(cx - 0.55 * s, y - 0.45 * s); g.lineTo(cx, y - 0.95 * s); g.lineTo(cx + 0.55 * s, y - 0.45 * s);
  g.fill();
  g.fillStyle = lit > 0 ? rgba('#fff3c8', 0.35 + 0.5 * lit) : 'rgba(18,56,74,0.9)';
  g.fillRect(cx - 0.4 * s, y - 0.45 * s, 0.8 * s, 0.88 * s);
  g.strokeStyle = PAL.brass;
  g.lineWidth = Math.max(1.5, 0.07 * s);
  g.strokeRect(cx - 0.4 * s, y - 0.45 * s, 0.8 * s, 0.88 * s);
  g.beginPath(); g.moveTo(cx, y - 0.45 * s); g.lineTo(cx, y + 0.43 * s); g.stroke();
  if (lit > 0) {
    g.fillStyle = PAL.gold;
    g.beginPath();
    g.ellipse(cx, y + 0.05 * s, 0.14 * s * lit, (0.3 + 0.05 * Math.sin(time * 12)) * s * lit, 0, 0, TAU);
    g.fill();
  }
}

// The bell that drowned the abbey, hanging over the Abbot's room.
function greatBell(v: View, wx: number, time: number) {
  const g = v.ctx, s = v.scale;
  const cx = v.sx(wx), foot = v.sy(v.wallFront(Math.floor(wx)));
  const hang = foot - (WALL_H[2] + 2.8) * s, len = 4.2 * s;
  const swing = Math.sin(time * 0.6) * 0.03 + Math.sin(time * 5.2) * 0.22 * v.toll;
  g.save();
  g.translate(cx, hang);
  g.rotate(swing);
  g.strokeStyle = PAL.wood;
  g.lineWidth = Math.max(3, 0.18 * s);
  g.beginPath(); g.moveTo(0, -v.h); g.lineTo(0, len * 0.2); g.stroke();
  const grad = g.createLinearGradient(-2.2 * s, 0, 2.2 * s, 0);
  grad.addColorStop(0, '#8a6d24');
  grad.addColorStop(0.4, '#e6c765');
  grad.addColorStop(1, '#6f5518');
  g.fillStyle = grad;
  g.beginPath();
  g.moveTo(-2.3 * s, len);
  g.quadraticCurveTo(-1.5 * s, len * 0.75, -1.3 * s, len * 0.4);
  g.quadraticCurveTo(-1.1 * s, len * 0.08, 0, len * 0.08);
  g.quadraticCurveTo(1.1 * s, len * 0.08, 1.3 * s, len * 0.4);
  g.quadraticCurveTo(1.5 * s, len * 0.75, 2.3 * s, len);
  g.closePath();
  g.fill();
  g.fillStyle = 'rgba(4,9,12,0.25)';
  g.fillRect(-2.1 * s, len * 0.86, 4.2 * s, 0.14 * s);
  g.fillStyle = '#5a4514';
  g.beginPath(); g.arc(Math.sin(time * 5.2) * 0.9 * s * v.toll, len * 1.02, 0.36 * s, 0, TAU); g.fill();
  g.restore();
  if (v.toll > 0.05) {
    g.globalCompositeOperation = 'lighter';
    glow(g, cx, hang + len * 0.7, 9 * s, PAL.gold, 0.22 * v.toll);
    g.globalCompositeOperation = 'source-over';
  }
}

// ---------- the sea, lapping at the open front edge and rising as the tide turns

export function drawWater(v: View, world: World, time: number) {
  const g = v.ctx, s = v.scale;
  const p = Math.min(1.15, world.totalTime() / TIME_LIMIT);
  const frontY = v.sy(v.front);
  const top = frontY + LEDGE * s * (1.7 - 1.6 * Math.min(1, p)) + Math.sin(time * 0.8) * 2;
  const grad = g.createLinearGradient(0, top, 0, v.h);
  grad.addColorStop(0, 'rgba(38,128,134,0.92)');
  grad.addColorStop(1, 'rgba(7,24,33,0.97)');
  g.fillStyle = grad;
  g.fillRect(0, top, v.w, v.h - top);
  g.fillStyle = rgba(PAL.bone, 0.5);
  g.fillRect(0, top, v.w, 1.5);
  g.fillStyle = rgba(PAL.glow, 0.22);
  for (let i = 0; i < 26; i++) {
    const y = top + 6 + hash(i) * (v.h - top - 6);
    const x = ((hash(i * 3) * 2000 - v.camX * s * (1 + hash(i) * 0.3) + time * (8 + hash(i * 5) * 14)) % (v.w + 200) + v.w + 200) % (v.w + 200) - 100;
    g.fillRect(x, y, 30 + hash(i * 7) * 70, 1.5);
  }
  // past the deadline the water is over the flagstones
  if (p > 1) {
    v.floorSpace();
    g.fillStyle = rgba(PAL.glow, Math.min(0.16, (p - 1) * 1.2));
    g.fillRect(v.camX - v.w / s, 0, (v.w / s) * 2, v.front);
    v.screenSpace();
  }
}

// ---------- pillars

export function drawPillar(v: View, px: number, py: number, pw: number, ph: number, hides: boolean) {
  const g = v.ctx, s = v.scale;
  const st = STONE[v.zoneAt(px)];
  const left = v.sx(px), wide = pw * s;
  const base = v.sy(py + ph), top = base - PILLAR_H * s, capTop = v.sy(py) - PILLAR_H * s;
  g.globalAlpha = hides ? 0.45 : 1;
  const grad = g.createLinearGradient(left, 0, left + wide, 0);
  grad.addColorStop(0, mix(st.cap, '#ffffff', 0.08));
  grad.addColorStop(0.5, st.wallA);
  grad.addColorStop(1, st.wallB);
  g.fillStyle = grad;
  g.fillRect(left, top, wide, base - top);
  g.fillStyle = st.cap;
  g.fillRect(left - 0.12 * s, capTop, wide + 0.24 * s, top - capTop + 0.22 * s);
  g.fillStyle = st.wallB;
  g.fillRect(left - 0.12 * s, base - 0.3 * s, wide + 0.24 * s, 0.3 * s);
  // fluting, and the green of the tide line
  g.fillStyle = 'rgba(4,9,12,0.16)';
  for (let i = 1; i < 4; i++) g.fillRect(left + (wide * i) / 4 - 1, top + 0.25 * s, 2, base - top - 0.6 * s);
  const damp = g.createLinearGradient(0, base - 1.1 * s, 0, base);
  damp.addColorStop(0, 'rgba(10,50,48,0)');
  damp.addColorStop(1, 'rgba(10,50,48,0.5)');
  g.fillStyle = damp;
  g.fillRect(left, base - 1.1 * s, wide, 1.1 * s);
  g.globalAlpha = 1;
}
