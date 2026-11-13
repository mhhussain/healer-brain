import { PAL, TAU, hash, rgba } from './palette';
import { DEPTH, type View } from './scenery';

// Weather by zone: rain and gusts at the Sea Gate, which is open to the sky; drips from the vault
// of the Infirmary; dust and candle smoke in the Nave. Nothing here is kept between frames:
// every drop is worked out from the clock, so it costs no memory and cannot drift.

const smooth = (t: number) => { const k = Math.max(0, Math.min(1, t)); return k * k * (3 - 2 * k); };

// How far into the open air and into the Nave the camera is; each fades across the wall between zones.
const openSky = (v: View) => smooth((v.zoneEnd[0] - v.camX + 6) / 12);
const inNave = (v: View) => smooth((v.camX - v.zoneEnd[1] + 6) / 12);

// How hard the rain leans: sideways travel per unit of fall. It swells and drops as the wind gusts.
const gust = (time: number) => 0.24 + 0.16 * Math.sin(time * 0.37) + 0.09 * Math.sin(time * 1.13 + 2);

const hasFloor = (v: View, x: number) => x >= 0 && x < v.wallAt.length && v.wallAt[Math.floor(x)] >= 0;

// A ring spreading on the flagstones where a drop landed; k runs 0 to 1 over its life.
function ripple(v: View, x: number, y: number, k: number, size: number, color: string, alpha: number) {
  const g = v.ctx, r = (0.08 + size * k) * v.scale;
  g.strokeStyle = rgba(color, alpha * (1 - k));
  g.lineWidth = 1;
  g.beginPath();
  g.ellipse(v.sx(x), v.sy(y), r, r * DEPTH, 0, 0, TAU);
  g.stroke();
}

// Leaking joints in the Infirmary vault, one every few metres, each on its own slow clock.
function eachDrip(v: View, time: number, fn: (x: number, y: number, t: number) => void) {
  const half = v.w / v.scale / 2 + 2;
  for (let c = Math.floor((v.camX - half) / 5); c <= (v.camX + half) / 5; c++) {
    const x = c * 5 + hash(c * 1.7) * 5;
    if (x < v.zoneEnd[0] || x >= v.zoneEnd[1] || !hasFloor(v, x)) continue;
    const wf = v.wallFront(Math.floor(x)), every = 2.2 + hash(c * 5.3) * 3.5;
    fn(x, wf + 0.6 + hash(c * 3.9) * (v.front - wf - 1.2), (time + hash(c * 7.1) * every) % every);
  }
}
const DRIP_FALL = 0.6, DRIP_FROM = 5.6;

// On the flagstones and against the back wall: drawn before the figures.
export function drawWeatherGround(v: View, time: number) {
  const g = v.ctx, s = v.scale;
  const rain = openSky(v);
  if (rain > 0.01) {
    const span = v.w / s + 24, left = Math.floor(v.camX / 20) * 20 - span / 2;
    for (let j = 0; j < 26; j++) {
      const tt = time * (1.5 + hash(j * 3) * 0.9) + hash(j) * 9, n = Math.floor(tt);
      const x = left + hash(n * 12.9 + j * 7.7) * span;
      if (x >= v.zoneEnd[0] || !hasFloor(v, x)) continue;
      const wf = v.wallFront(Math.floor(x));
      ripple(v, x, wf + 0.3 + hash(n * 5.1 + j) * (v.front - wf - 0.5), tt - n, 0.32, PAL.bone, 0.4 * rain);
    }
  }
  eachDrip(v, time, (x, y, t) => {
    if (t >= DRIP_FALL && t < DRIP_FALL + 0.9) ripple(v, x, y, (t - DRIP_FALL) / 0.9, 0.55, PAL.glow, 0.55);
  });
  // smoke off the candle stands along the Nave wall
  const half = v.w / s / 2 + 2;
  for (let x = Math.ceil((v.camX - half) / 8) * 8; x <= v.camX + half; x += 8) {
    if (x < v.zoneEnd[1] || !hasFloor(v, x)) continue;
    const wf = v.wallFront(x);
    for (let j = 0; j < 6; j++) {
      const k = (time * 0.2 + j / 6 + hash(x)) % 1;
      const sway = Math.sin(time * 0.9 + k * 5 + x) * 0.3 * k;
      g.fillStyle = rgba(PAL.bone, 0.09 * (1 - k) * Math.min(1, k * 6));
      g.beginPath();
      g.arc(v.sx(x + 0.5 + sway), v.sy(wf, 1.8 + k * 3.4), (0.1 + 0.38 * k) * s, 0, TAU);
      g.fill();
    }
  }
}

// In the air: drawn over the figures.
export function drawWeatherAir(v: View, time: number) {
  const g = v.ctx, s = v.scale;
  const rain = openSky(v);
  if (rain > 0.01) {
    const wind = gust(time), spanY = v.h + 80, spanX = v.w + 400;
    g.strokeStyle = PAL.bone;
    // far rain first, then the nearer, faster, longer streaks
    for (const near of [false, true]) {
      const len = near ? 26 : 15, par = near ? 1.1 : 0.6;
      g.globalAlpha = rain * (near ? 0.3 : 0.18);
      g.lineWidth = near ? 1.4 : 1;
      g.beginPath();
      for (let i = near ? 0 : 1; i < 150; i += near ? 3 : 1) {
        if (!near && i % 3 === 0) continue;
        const y = ((hash(i) * spanY + time * (near ? 1250 : 850) * (0.85 + hash(i * 3) * 0.3)) % spanY) - 40;
        const x = ((((hash(i * 7.3) * spanX - v.camX * s * par + y * wind) % spanX) + spanX) % spanX) - 200;
        g.moveTo(x, y);
        g.lineTo(x - wind * len, y - len);
      }
      g.stroke();
    }
    g.globalAlpha = 1;
  }
  eachDrip(v, time, (x, y, t) => {
    if (t >= DRIP_FALL) return;
    const z = DRIP_FROM * (1 - (t / DRIP_FALL) ** 2);
    g.strokeStyle = rgba(PAL.glow, 0.75);
    g.lineWidth = 1.5;
    g.beginPath();
    g.moveTo(v.sx(x), v.sy(y, z));
    g.lineTo(v.sx(x), v.sy(y, z + 0.32));
    g.stroke();
  });
  const dust = inNave(v);
  if (dust > 0.01) {
    // dust sifting down through the window light
    const spanX = v.w + 80, spanY = v.h * 0.72;
    g.globalCompositeOperation = 'lighter';
    for (let i = 0; i < 38; i++) {
      const x = ((((hash(i * 7) * 3000 - v.camX * s * (0.5 + hash(i * 3) * 0.5) + Math.sin(time * 0.5 + i) * 16) % spanX) + spanX) % spanX) - 40;
      const y = (hash(i) * 2000 + time * (6 + hash(i * 11) * 10)) % spanY;
      g.fillStyle = rgba(PAL.gold, dust * (0.1 + 0.16 * (0.5 + 0.5 * Math.sin(time * 1.3 + i * 2))));
      g.beginPath();
      g.arc(x, y, 1 + hash(i * 13) * 1.3, 0, TAU);
      g.fill();
    }
    g.globalCompositeOperation = 'source-over';
  }
}
