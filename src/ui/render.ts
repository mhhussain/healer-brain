import type { Unit } from '../sim/types';
import type { World } from '../sim/world';
import { PAL, TAU } from './palette';
import { DEPTH, PILLAR_H, drawBackdrop, drawHall, drawPillar, drawWater, type View } from './scenery';

// Belt-scroller view: x runs along the hall, y is depth (drawn squashed), z is height.
const WALL_H = 6;
const BOTTOM = 150;
const HERO_H = 1.9;
const FALL = 0.45;
const LEAN = 7;

type Hat = 'helm' | 'hood' | 'point' | 'band' | 'crown' | 'horns' | 'none';
type Weapon = 'shield' | 'sword' | 'club' | 'staff' | 'bow' | 'blades' | 'none';
interface Look { hat: Hat; weapon: Weapon; robe?: boolean; wide?: number; orb?: string; blob?: boolean }

const HERO_LOOK: Record<string, Look> = {
  warden: { hat: 'helm', weapon: 'shield', wide: 1.1 },
  mender: { hat: 'hood', weapon: 'staff', robe: true, orb: '#fff3b0' },
  bloomweaver: { hat: 'crown', weapon: 'staff', robe: true, orb: '#8fe38f' },
  duelist: { hat: 'band', weapon: 'blades' },
  ranger: { hat: 'hood', weapon: 'bow' },
  pyromancer: { hat: 'point', weapon: 'staff', robe: true, orb: '#ff8a3c' },
};

const ENEMY_LOOK: Record<string, Look> = {
  brute: { hat: 'horns', weapon: 'club', wide: 1.25 },
  hexer: { hat: 'hood', weapon: 'staff', robe: true, orb: '#b46bff' },
  archer: { hat: 'hood', weapon: 'bow' },
  shaman: { hat: 'crown', weapon: 'staff', robe: true, orb: '#6fe07a' },
  berserker: { hat: 'horns', weapon: 'blades' },
  overseer: { hat: 'helm', weapon: 'sword', wide: 1.2 },
  krogg: { hat: 'horns', weapon: 'club', wide: 1.3 },
  velisse: { hat: 'crown', weapon: 'staff', robe: true, orb: '#c8ff6a' },
  hatchling: { hat: 'none', weapon: 'none', blob: true },
  sulmar: { hat: 'point', weapon: 'staff', robe: true, orb: '#ff5a3c' },
};
const PLAIN: Look = { hat: 'none', weapon: 'none' };

const INK = '#0d0f14';
const STEEL = '#c9d2e0';
const WOOD = '#8a6a45';
void PAL;

const shades = new Map<string, string>();
function shade(hex: string, f: number) {
  const key = hex + f;
  let out = shades.get(key);
  if (!out) {
    const n = parseInt(hex.slice(1), 16);
    const c = (v: number) => Math.max(0, Math.min(255, Math.round(v * f)));
    out = `rgb(${c(n >> 16)},${c((n >> 8) & 255)},${c(n & 255)})`;
    shades.set(key, out);
  }
  return out;
}

// Per-unit animation state, kept by the renderer only.
interface Anim { x: number; y: number; phase: number; walking: boolean; dir: 1 | -1; auto: number; gcd: number; atk: number; hp: number; flash: number; gone: number }

export class Renderer implements View {
  ctx: CanvasRenderingContext2D;
  w = 0;
  h = 0;
  private dpr = 1;
  oy = 0;
  private last = 0;
  private mapOf: World | null = null;
  // per column: depth of the wall's front face, and whether the column has floor
  wallAt: number[] = [];
  front = 0;
  // right-hand edge of each zone, and where each zone's lamp stands
  zoneEnd: number[] = [0, 0, 0];
  lampX: number[] = [0, 0, 0];
  lit: number[] = [0, 0, 0];
  toll = 0;
  private anims = new Map<number, Anim>();
  scale = 30;
  camX = 0;
  private lean = 0;

  constructor(private canvas: HTMLCanvasElement) {
    this.ctx = canvas.getContext('2d')!;
  }

  resize() {
    this.dpr = window.devicePixelRatio || 1;
    this.w = this.canvas.clientWidth;
    this.h = this.canvas.clientHeight;
    this.canvas.width = Math.round(this.w * this.dpr);
    this.canvas.height = Math.round(this.h * this.dpr);
    this.mapOf = null;
  }

  private prepare(world: World) {
    const m = world.map;
    this.front = 0;
    this.wallAt = [];
    let deepest = 0;
    for (let x = 0; x < m.w; x++) {
      let back = -1, front = -1;
      for (let y = 0; y < m.h; y++) {
        if (m.wall(x, y) && m.pillarAt[y * m.w + x] < 0) continue;
        if (back < 0) back = y;
        front = y + 1;
      }
      this.wallAt.push(back);
      this.front = Math.max(this.front, front);
      if (back >= 0) deepest = Math.max(deepest, front - back);
    }
    this.scale = Math.max(14, Math.min(48, this.w / 50, (this.h - BOTTOM - 70) / (deepest * DEPTH + WALL_H)));
    this.oy = this.h - BOTTOM - this.front * this.scale * DEPTH;
    const bosses = world.packs.filter((p) => p.def.boss);
    this.lampX = bosses.map((p) => p.def.center.x);
    this.zoneEnd = bosses.map((p) => p.def.center.x + 17);
    this.lit = bosses.map((p) => (p.cleared ? 1 : 0));
    this.toll = 0;
    this.camX = world.player.x;
    this.lean = 0;
    this.anims.clear();
    this.mapOf = world;
  }

  zoneAt(x: number) { return x < this.zoneEnd[0] ? 0 : x < this.zoneEnd[1] ? 1 : 2; }

  sx(x: number) { return (x - this.camX) * this.scale + this.w / 2; }
  sy(y: number, z = 0) { return this.oy + y * this.scale * DEPTH - z * this.scale; }

  wallFront(x: number) {
    const b = x >= 0 && x < this.wallAt.length ? this.wallAt[x] : -1;
    return b < 0 ? this.front : b;
  }

  screenSpace() { this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0); }
  // Draw in floor coordinates: world metres in, squashed for depth.
  floorSpace() {
    const s = this.scale, d = this.dpr;
    this.ctx.setTransform(d * s, 0, 0, d * s * DEPTH, d * (this.w / 2 - this.camX * s), d * this.oy);
  }

  private figH(u: Unit) {
    if (u.hero) return HERO_H;
    return u.enemy!.id === 'hatchling' ? 1 : u.radius * 3;
  }

  // Screen position of the middle of a unit's figure.
  anchor(u: Unit) {
    return { x: this.sx(u.x), y: this.sy(u.y, u.z) - (this.figH(u) * this.scale) / 2 };
  }

  // The unit whose figure is under a screen point; nearest to the camera wins.
  pick(world: World, px: number, py: number) {
    let best = -1, by = -1e9;
    for (const u of [...world.enemies, ...world.heroes]) {
      if (!u.alive) continue;
      const H = this.figH(u) * this.scale;
      const x = this.sx(u.x), foot = this.sy(u.y, u.z);
      if (Math.abs(px - x) > H * 0.3 + 8 || py > foot + 8 || py < foot - H - 8) continue;
      if (u.y > by) { by = u.y; best = u.id; }
    }
    return best;
  }

  private anim(u: Unit, dt: number) {
    let a = this.anims.get(u.id);
    if (!a) {
      a = { x: u.x, y: u.y, phase: u.id * 1.7, walking: false, dir: Math.cos(u.facing) >= 0 ? 1 : -1, auto: u.autoTimer, gcd: u.gcd, atk: 0, hp: u.hp, flash: 0, gone: u.alive ? 0 : 9 };
      this.anims.set(u.id, a);
    }
    a.gone = u.alive ? 0 : a.gone + dt;
    const moved = Math.hypot(u.x - a.x, u.y - a.y);
    a.walking = moved > 1e-4 && moved < 3;
    if (a.walking) a.phase += moved * 2.4;
    a.x = u.x; a.y = u.y;
    const c = Math.cos(u.facing);
    if (c > 0.15) a.dir = 1; else if (c < -0.15) a.dir = -1;
    if (u.autoTimer > a.auto + 0.2 || u.gcd > a.gcd + 0.2) a.atk = 0.22;
    a.auto = u.autoTimer; a.gcd = u.gcd;
    if (u.hp < a.hp - 0.5) a.flash = 0.1;
    a.hp = u.hp;
    if (a.atk > 0) a.atk -= dt;
    if (a.flash > 0) a.flash -= dt;
    return a;
  }

  draw(world: World, hoverId: number) {
    const g = this.ctx;
    const now = performance.now();
    const dt = Math.min(0.1, Math.max(0, (now - this.last) / 1000));
    this.last = now;
    if (this.mapOf !== world) this.prepare(world);
    const s = this.scale;
    const p = world.player;
    // The camera follows the hero and leans a little towards the fight, so it stays on screen.
    const foes = world.enemies.filter((e) => e.alive && e.engaged);
    const fight = foes.length ? foes.reduce((n, e) => n + e.x, 0) / foes.length : p.x;
    const lean = Math.max(-LEAN, Math.min(LEAN, (fight - p.x) * 0.5));
    this.lean += (lean - this.lean) * (1 - Math.exp(-dt * 2.5));
    const want = p.x + this.lean;
    this.camX += (want - this.camX) * (1 - Math.exp(-dt * 9));
    if (Math.abs(want - this.camX) > 40) this.camX = want;

    // lamps come alight over a few seconds; the great bell swings while the Abbot tolls it
    world.packs.filter((k) => k.def.boss).forEach((k, i) => {
      this.lit[i] = k.cleared ? Math.min(1, this.lit[i] + dt / 2.5) : 0;
    });
    const tolling = world.enemies.some((e) => e.alive && !!e.cast?.ab?.hide);
    this.toll += ((tolling ? 1 : 0) - this.toll) * (1 - Math.exp(-dt * 2));

    this.screenSpace();
    g.fillStyle = PAL.deep;
    g.fillRect(0, 0, this.w, this.h);
    drawBackdrop(this, world.time);
    drawHall(this, world, world.time);
    drawWater(this, world, world.time);

    // floor decals: telegraphs, rings, selection, shadows
    this.floorSpace();
    for (const z of world.zones) {
      const k = Math.min(1, z.t / z.delay);
      const shape = (r: number) => {
        g.beginPath();
        if (z.kind === 'circle') g.arc(z.x, z.y, r, 0, TAU);
        else { g.moveTo(z.x, z.y); g.arc(z.x, z.y, r, z.dir! - z.half!, z.dir! + z.half!); g.closePath(); }
      };
      shape(z.r);
      g.fillStyle = 'rgba(255,70,50,0.18)';
      g.fill();
      g.strokeStyle = 'rgba(255,120,90,0.95)';
      g.lineWidth = 2.5 / s;
      g.stroke();
      shape(z.r * k);
      g.fillStyle = 'rgba(255,70,50,0.34)';
      g.fill();
    }
    for (const f of world.fx) {
      if (f.kind !== 'ring') continue;
      g.globalAlpha = 1 - f.t / f.life;
      g.strokeStyle = f.color;
      g.lineWidth = 3 / s;
      g.beginPath();
      g.arc(f.x, f.y, f.r! * (0.5 + (0.5 * f.t) / f.life), 0, TAU);
      g.stroke();
      g.globalAlpha = 1;
    }
    // enemies that just died stay for a moment as they fall
    const units = [...world.enemies.filter((e) => e.alive || (this.anims.get(e.id)?.gone ?? 9) < FALL), ...world.heroes];
    for (const u of units) {
      if (!u.alive) continue;
      const lift = Math.max(0.5, 1 - u.z * 0.3);
      g.fillStyle = 'rgba(0,0,0,0.38)';
      g.beginPath();
      g.arc(u.x, u.y, u.radius * 0.95 * lift, 0, TAU);
      g.fill();
      const ring = u.id === p.targetId ? '#ff5d4d' : u.id === hoverId ? '#ffffff' : u.isPlayer ? '#ffe27a' : u.hero ? u.hero.color : '';
      if (!ring) continue;
      g.strokeStyle = ring;
      g.globalAlpha = u.hero && !u.isPlayer && u.id !== hoverId ? 0.55 : 1;
      g.lineWidth = (u.id === p.targetId || u.isPlayer ? 3 : 2) / s;
      g.beginPath();
      g.arc(u.x, u.y, u.radius + 0.3, 0, TAU);
      g.stroke();
      g.globalAlpha = 1;
    }
    this.screenSpace();

    // pillars and figures, back to front
    const items: { y: number; draw: () => void }[] = [];
    for (const pl of world.map.pillars) {
      if (pl.alive) items.push({
        y: pl.y + pl.h - 0.01,
        // see-through while someone stands behind it
        draw: () => drawPillar(this, pl.x, pl.y, pl.w, pl.h, units.some((u) => u.alive && u.y < pl.y + pl.h && u.y > pl.y - PILLAR_H / DEPTH && u.x > pl.x - 0.7 && u.x < pl.x + pl.w + 0.7)),
      });
    }
    for (const u of units) {
      const a = this.anim(u, dt);
      items.push({ y: u.y, draw: () => this.drawFigure(world, u, a) });
    }
    items.sort((a, b) => a.y - b.y);
    for (const it of items) it.draw();

    for (const f of world.fx) {
      if (f.kind !== 'beam') continue;
      g.globalAlpha = 1 - f.t / f.life;
      g.strokeStyle = f.color;
      g.lineWidth = 3;
      g.lineCap = 'round';
      g.beginPath();
      g.moveTo(this.sx(f.x), this.sy(f.y, 1.1));
      g.lineTo(this.sx(f.x2!), this.sy(f.y2!, 1.1));
      g.stroke();
      g.globalAlpha = 1;
    }

    const tank = world.heroes[0];
    for (const u of units) {
      if (!u.alive) continue;
      const top = this.sy(u.y, u.z) - this.figH(u) * s;
      if (u.hero) this.heroPlate(u, this.sx(u.x), top);
      else this.enemyPlate(world, u, this.sx(u.x), top, u.id === p.targetId, u.id === hoverId, tank);
    }

    for (const f of world.fx) {
      if (f.kind !== 'text') continue;
      const a = 1 - f.t / f.life;
      g.globalAlpha = Math.min(1, a * 1.6);
      g.font = '700 14px system-ui, sans-serif';
      g.textAlign = 'center';
      g.lineWidth = 3;
      g.strokeStyle = 'rgba(0,0,0,0.75)';
      const x = this.sx(f.x), y = this.sy(f.y + 0.8, 1.7) - f.t * 38;
      g.strokeText(f.text!, x, y);
      g.fillStyle = f.color;
      g.fillText(f.text!, x, y);
      g.globalAlpha = 1;
    }
  }

  private drawFigure(world: World, u: Unit, a: Anim) {
    const g = this.ctx, s = this.scale;
    const look = (u.hero ? HERO_LOOK[u.hero.id] : ENEMY_LOOK[u.enemy!.id]) ?? PLAIN;
    const def = u.enemy;
    const base = u.hero ? u.hero.color : def!.boss ? '#8e3fb0' : def!.elite ? '#c2622d' : def!.range > 5 ? '#b0486e' : '#a63d3d';
    const H = this.figH(u) * s;
    const dir = a.dir;
    const x = this.sx(u.x), y = this.sy(u.y, u.z);
    g.save();
    g.translate(x, y);
    g.lineJoin = 'round';
    g.lineCap = 'round';
    if (!u.alive) {
      // fallen: lying on the floor, greyed out
      const k = Math.min(1, a.gone / 0.18);
      g.globalAlpha = u.hero ? 1 - 0.4 * k : Math.max(0, 1 - a.gone / FALL);
      g.rotate((-dir * Math.PI * k) / 2);
      g.translate(0, -H * 0.12 * k);
    }
    const body = !u.alive ? '#6b6f7a' : a.flash > 0 ? shade(base, 1.45) : base;
    const dark = !u.alive ? '#4c4f58' : shade(base, 0.62);
    const skin = !u.alive ? '#8d8f96' : u.hero ? '#f0d2b0' : '#a9b78c';
    const wide = look.wide ?? 1;
    const swing = a.atk > 0 ? Math.sin((1 - a.atk / 0.22) * Math.PI) : 0;
    const step = u.alive && a.walking ? Math.sin(a.phase) : 0;
    const bob = (u.alive && a.walking ? -Math.abs(Math.cos(a.phase)) * 0.03 : 0) * H;
    const casting = u.alive && !!u.cast;
    g.translate(dir * swing * H * 0.1, 0);
    g.lineWidth = Math.max(1.5, H * 0.03);
    g.strokeStyle = INK;

    if (look.blob) {
      g.fillStyle = body;
      g.beginPath();
      g.ellipse(0, -H * 0.45 + bob, H * 0.5, H * 0.45, 0, 0, TAU);
      g.fill(); g.stroke();
      g.fillStyle = '#ffe27a';
      for (const e of [0.08, 0.3]) { g.beginPath(); g.arc(dir * H * e, -H * 0.55 + bob, H * 0.07, 0, TAU); g.fill(); }
      g.restore();
      return;
    }

    const bw = H * 0.4 * wide;
    if (!look.robe) {
      g.fillStyle = dark;
      for (const k of [-1, 1]) {
        const lx = k * bw * 0.24 + k * step * H * 0.07;
        g.beginPath();
        g.rect(lx - H * 0.06, -H * 0.26, H * 0.12, H * 0.26);
        g.fill(); g.stroke();
      }
    }
    // weapon behind the body for the off hand
    if (look.weapon === 'shield') this.weapon('sword', -dir, bw, H, bob, swing, look, body, casting, world.time);
    g.fillStyle = body;
    g.beginPath();
    if (look.robe) {
      const sway = step * H * 0.02;
      g.moveTo(-bw * 0.42, -H * 0.7 + bob);
      g.lineTo(bw * 0.42, -H * 0.7 + bob);
      g.lineTo(bw * 0.62 + sway, -H * 0.02);
      g.lineTo(-bw * 0.62 + sway, -H * 0.02);
      g.closePath();
    } else {
      g.roundRect(-bw / 2, -H * 0.7 + bob, bw, H * 0.48, H * 0.07);
    }
    g.fill(); g.stroke();
    // belt
    g.fillStyle = dark;
    g.fillRect(-bw / 2, -H * 0.42 + bob, bw, H * 0.045);

    const hy = -H * 0.83 + bob, hr = H * 0.16;
    if (look.hat === 'hood') {
      g.fillStyle = dark;
      g.beginPath();
      g.arc(-dir * hr * 0.2, hy, hr * 1.22, 0, TAU);
      g.fill(); g.stroke();
    }
    if (look.hat === 'horns') {
      g.fillStyle = '#e6dcc4';
      for (const k of [-1, 1]) {
        g.beginPath();
        g.moveTo(k * hr * 0.55, hy - hr * 0.6);
        g.lineTo(k * hr * 1.5, hy - hr * 1.5);
        g.lineTo(k * hr * 0.95, hy - hr * 0.1);
        g.closePath();
        g.fill(); g.stroke();
      }
    }
    g.fillStyle = skin;
    g.beginPath();
    g.arc(0, hy, hr, 0, TAU);
    g.fill(); g.stroke();
    g.fillStyle = u.hero || !u.alive ? INK : '#ffe27a';
    for (const e of [0.2, 0.68]) { g.beginPath(); g.arc(dir * hr * e, hy - hr * 0.05, hr * 0.13, 0, TAU); g.fill(); }
    if (look.hat === 'helm') {
      g.fillStyle = STEEL;
      g.beginPath();
      g.arc(0, hy, hr * 1.06, Math.PI, TAU);
      g.closePath();
      g.fill(); g.stroke();
      g.fillRect(dir * hr * 0.42 - hr * 0.08, hy - hr * 0.1, hr * 0.16, hr * 0.5);
    } else if (look.hat === 'point') {
      g.fillStyle = body;
      g.beginPath();
      g.moveTo(-hr * 1.3, hy - hr * 0.55);
      g.lineTo(hr * 1.3, hy - hr * 0.55);
      g.lineTo(-dir * hr * 0.4, hy - hr * 2.6);
      g.closePath();
      g.fill(); g.stroke();
    } else if (look.hat === 'band') {
      g.fillStyle = body;
      g.fillRect(-hr, hy - hr * 0.62, hr * 2, hr * 0.34);
      g.fillRect(-dir * hr * 1.5, hy - hr * 0.55, hr * 0.6, hr * 0.2);
    } else if (look.hat === 'crown') {
      g.fillStyle = look.orb ?? '#e9c46a';
      g.beginPath();
      for (const k of [-1, 0, 1]) {
        g.moveTo(k * hr * 0.6 - hr * 0.3, hy - hr * 0.8);
        g.lineTo(k * hr * 0.6, hy - hr * 1.55);
        g.lineTo(k * hr * 0.6 + hr * 0.3, hy - hr * 0.8);
      }
      g.closePath();
      g.fill(); g.stroke();
    }
    this.weapon(look.weapon, dir, bw, H, bob, swing, look, body, casting, world.time);
    g.restore();
  }

  // Drawn in the figure's own space, feet at the origin.
  private weapon(kind: Weapon, dir: number, bw: number, H: number, bob: number, swing: number, look: Look, body: string, casting: boolean, time: number) {
    const g = this.ctx;
    if (kind === 'none') return;
    const hx = dir * (bw * 0.5 + H * 0.05), hy = -H * 0.46 + bob;
    g.save();
    g.translate(hx, hy);
    if (kind === 'shield') {
      g.fillStyle = STEEL;
      g.beginPath();
      g.roundRect(-H * 0.11 + dir * swing * H * 0.05, -H * 0.2, H * 0.22, H * 0.36, H * 0.06);
      g.fill(); g.stroke();
      g.fillStyle = body;
      g.beginPath();
      g.arc(dir * swing * H * 0.05, -H * 0.02, H * 0.05, 0, TAU);
      g.fill();
    } else if (kind === 'staff') {
      g.strokeStyle = INK;
      g.lineWidth = H * 0.075;
      g.beginPath(); g.moveTo(0, H * 0.42); g.lineTo(dir * swing * H * 0.08, -H * 0.5); g.stroke();
      g.strokeStyle = WOOD;
      g.lineWidth = H * 0.04;
      g.beginPath(); g.moveTo(0, H * 0.42); g.lineTo(dir * swing * H * 0.08, -H * 0.5); g.stroke();
      const ox = dir * swing * H * 0.08, oy = -H * 0.54;
      if (casting) {
        const r = H * (0.2 + 0.05 * Math.sin(time * 16));
        const glow = g.createRadialGradient(ox, oy, 0, ox, oy, r);
        glow.addColorStop(0, look.orb ?? '#ffffff');
        glow.addColorStop(1, 'rgba(255,255,255,0)');
        g.fillStyle = glow;
        g.globalAlpha *= 0.8;
        g.fillRect(ox - r, oy - r, r * 2, r * 2);
        g.globalAlpha /= 0.8;
      }
      g.strokeStyle = INK;
      g.lineWidth = Math.max(1.5, H * 0.03);
      g.fillStyle = look.orb ?? '#ffffff';
      g.beginPath(); g.arc(ox, oy, H * 0.07, 0, TAU); g.fill(); g.stroke();
    } else if (kind === 'bow') {
      g.strokeStyle = INK;
      g.lineWidth = H * 0.06;
      g.beginPath(); g.arc(-dir * H * 0.05, 0, H * 0.3, dir > 0 ? -1.1 : Math.PI - 1.1, dir > 0 ? 1.1 : Math.PI + 1.1); g.stroke();
      g.strokeStyle = WOOD;
      g.lineWidth = H * 0.032;
      g.beginPath(); g.arc(-dir * H * 0.05, 0, H * 0.3, dir > 0 ? -1.1 : Math.PI - 1.1, dir > 0 ? 1.1 : Math.PI + 1.1); g.stroke();
      g.strokeStyle = '#e8e8ea';
      g.lineWidth = 1;
      const bx = -dir * H * 0.05 + dir * Math.cos(1.1) * H * 0.3, pull = -dir * swing * H * 0.08;
      g.beginPath(); g.moveTo(bx, -Math.sin(1.1) * H * 0.3); g.lineTo(bx + pull, 0); g.lineTo(bx, Math.sin(1.1) * H * 0.3); g.stroke();
    } else {
      // sword, club, blades: a swung line from the hand
      const len = kind === 'blades' ? 0.3 : kind === 'club' ? 0.5 : 0.52;
      const thick = kind === 'club' ? 0.1 : 0.05;
      const draw = (rot: number) => {
        g.save();
        g.rotate(rot);
        g.strokeStyle = INK;
        g.lineWidth = H * (thick + 0.035);
        g.beginPath(); g.moveTo(0, 0); g.lineTo(0, -H * len); g.stroke();
        g.strokeStyle = kind === 'club' ? WOOD : STEEL;
        g.lineWidth = H * thick;
        g.beginPath(); g.moveTo(0, 0); g.lineTo(0, -H * len); g.stroke();
        if (kind === 'club') {
          g.fillStyle = WOOD;
          g.strokeStyle = INK;
          g.lineWidth = Math.max(1.5, H * 0.03);
          g.beginPath(); g.arc(0, -H * len, H * 0.09, 0, TAU); g.fill(); g.stroke();
        }
        g.restore();
      };
      draw(dir * (0.35 + swing * 1.5));
      if (kind === 'blades') {
        g.translate(-dir * (bw + H * 0.1), 0);
        draw(dir * (-0.5 + swing * 1.2));
      }
    }
    g.restore();
  }

  private heroPlate(h: Unit, x: number, top: number) {
    const g = this.ctx;
    const bw = 46, by = top - 12;
    g.fillStyle = INK;
    g.fillRect(x - bw / 2 - 1, by - 1, bw + 2, 7);
    g.fillStyle = h.hp / h.maxHp < 0.35 ? '#e0563f' : '#4fbf68';
    g.fillRect(x - bw / 2, by, bw * Math.max(0, h.hp / h.maxHp), 5);
    const shield = h.auras.reduce((n, a) => n + (a.absorb ?? 0), 0);
    if (shield > 0) {
      g.fillStyle = '#e8f1ff';
      g.fillRect(x - bw / 2, by - 3, bw * Math.min(1, shield / h.maxHp), 2);
    }
    if (h.cast) {
      g.fillStyle = INK;
      g.fillRect(x - bw / 2 - 1, by + 7, bw + 2, 5);
      g.fillStyle = '#e9c46a';
      g.fillRect(x - bw / 2, by + 8, bw * (h.cast.t / h.cast.total), 3);
    }
    if (h.isPlayer) {
      g.fillStyle = '#ffe27a';
      g.strokeStyle = INK;
      g.lineWidth = 1.5;
      g.beginPath();
      g.moveTo(x - 6, by - 14); g.lineTo(x + 6, by - 14); g.lineTo(x, by - 6);
      g.closePath();
      g.fill(); g.stroke();
    }
  }

  private enemyPlate(world: World, e: Unit, x: number, top: number, targeted: boolean, hover: boolean, tank: Unit) {
    const g = this.ctx;
    const def = e.enemy!;
    const bw = def.boss ? 130 : def.elite ? 76 : 56;
    let by = top - 14;
    const loose = e.engaged && tank.alive && e.targetId !== tank.id && e.targetId >= 0;
    g.fillStyle = loose ? '#e0392b' : INK;
    g.fillRect(x - bw / 2 - 2, by - 2, bw + 4, 10);
    g.fillStyle = '#15171c';
    g.fillRect(x - bw / 2, by, bw, 6);
    g.fillStyle = '#d9534f';
    g.fillRect(x - bw / 2, by, bw * Math.max(0, e.hp / e.maxHp), 6);
    g.textAlign = 'center';
    g.strokeStyle = 'rgba(0,0,0,0.8)';
    g.lineWidth = 3;
    const named = targeted || hover || !!def.boss;
    if (named) {
      g.font = '600 11px system-ui, sans-serif';
      g.strokeText(e.name, x, by - 6);
      g.fillStyle = '#e8e8ea';
      g.fillText(e.name, x, by - 6);
    }
    const c = e.cast;
    if (!c) return;
    by -= named ? 32 : 17;
    const mine = c.assignee === world.player.id && !world.autoplay;
    g.fillStyle = INK;
    g.fillRect(x - bw / 2 - 2, by - 2, bw + 4, 13);
    g.fillStyle = c.interruptible ? '#e9b949' : '#8a8f9c';
    g.fillRect(x - bw / 2, by, bw * Math.min(1, c.t / c.total), 9);
    g.font = '600 10px system-ui, sans-serif';
    g.fillStyle = '#fff';
    g.strokeText(c.name, x, by + 8);
    g.fillText(c.name, x, by + 8);
    if (mine) {
      const pulse = 0.6 + 0.4 * Math.sin(world.time * 14);
      g.font = '800 15px system-ui, sans-serif';
      g.fillStyle = `rgba(255,230,90,${pulse})`;
      g.strokeText('KICK', x, by - 6);
      g.fillText('KICK', x, by - 6);
    }
  }
}
