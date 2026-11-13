import type { Unit } from '../sim/types';
import type { World } from '../sim/world';
import { drawFigure, lookOf } from './figures';
import { BODY_FONT, DISPLAY_FONT, PAL, TAU, hash, rgba } from './palette';
import { DEPTH, PILLAR_H, drawBackdrop, drawHall, drawPillar, drawWater, type View } from './scenery';

// Belt-scroller view: x runs along the hall, y is depth (drawn squashed), z is height.
const WALL_H = 6;
const BOTTOM = 150;
const HERO_H = 2.6;
// how long a drowned monk takes to turn to light
const REST = 0.9;
const LEAN = 7;

const INK = PAL.ink;

// Per-unit animation state, kept by the renderer only.
// Bubbles, sparks and motes of light. Positions are in world metres.
interface Particle { x: number; y: number; z: number; vx: number; vz: number; t: number; life: number; size: number; color: string; ring?: boolean }
interface Bubble { id: number; text: string; t: number }
const BUBBLE_TIME = 4;

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
  private parts: Particle[] = [];
  private bubbles: Bubble[] = [];
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
    this.parts = [];
    this.bubbles = [];
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
    return u.enemy!.id === 'hatchling' ? 1.2 : u.radius * 3.5;
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
    if (!u.alive && a.gone === 0 && !u.hero) this.burst(u.x, u.y, this.figH(u) * 0.5, 16, '#d8fff4', true);
    a.gone = u.alive ? 0 : a.gone + dt;
    const moved = Math.hypot(u.x - a.x, u.y - a.y);
    a.walking = moved > 1e-4 && moved < 3;
    if (a.walking) a.phase += moved * 2.4;
    a.x = u.x; a.y = u.y;
    const c = Math.cos(u.facing);
    if (c > 0.15) a.dir = 1; else if (c < -0.15) a.dir = -1;
    if (u.autoTimer > a.auto + 0.2 || u.gcd > a.gcd + 0.2) a.atk = 0.22;
    a.auto = u.autoTimer; a.gcd = u.gcd;
    if (u.hp < a.hp - 0.5) {
      a.flash = 0.1;
      if (!u.hero && u.alive) this.burst(u.x, u.y, this.figH(u) * 0.55, 2, PAL.bone, false);
    } else if (u.hero && u.alive && u.hp > a.hp + 25) this.burst(u.x, u.y, 1, 7, '#8fe6b4', false);
    a.hp = u.hp;
    if (a.atk > 0) a.atk -= dt;
    if (a.flash > 0) a.flash -= dt;
    return a;
  }

  // A speech bubble over a unit's head.
  say(id: number, text: string) {
    // one at a time, so bubbles never pile up
    this.bubbles = [{ id, text, t: 0 }];
  }

  private burst(x: number, y: number, z: number, n: number, color: string, ring: boolean) {
    if (this.parts.length > 300) return;
    for (let i = 0; i < n; i++) {
      const r = Math.random;
      this.parts.push({ x: x + (r() - 0.5) * 1.2, y, z: z * (0.3 + r()), vx: (r() - 0.5) * 1.6, vz: 0.8 + r() * 2.2, t: 0, life: 0.7 + r() * 0.9, size: 0.05 + r() * 0.09, color, ring });
    }
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
      if (k.cleared && this.lit[i] === 0) this.burst(this.lampX[i], this.wallFront(Math.floor(this.lampX[i])) + 0.3, 3.2, 40, PAL.gold, false);
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
    this.motes(world.time);

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
      g.fillStyle = rgba(PAL.danger, 0.16);
      g.fill();
      g.strokeStyle = rgba(PAL.danger, 0.75 + 0.25 * Math.sin(world.time * 14));
      g.lineWidth = 3 / s;
      g.stroke();
      shape(z.r * k);
      g.fillStyle = rgba(PAL.danger, 0.2 + 0.25 * k);
      g.fill();
    }
    for (const f of world.fx) {
      if (f.kind !== 'ring') continue;
      g.globalCompositeOperation = 'lighter';
      g.strokeStyle = f.color;
      for (const [wide, al] of [[10, 0.25], [3, 1]]) {
        g.globalAlpha = (1 - f.t / f.life) * al;
        g.lineWidth = wide / s;
        g.beginPath();
        g.arc(f.x, f.y, f.r! * (0.5 + (0.5 * f.t) / f.life), 0, TAU);
        g.stroke();
      }
      g.globalAlpha = 1;
      g.globalCompositeOperation = 'source-over';
    }
    // enemies that were just laid to rest stay for a moment as they fade
    const units = [...world.enemies.filter((e) => e.alive || (this.anims.get(e.id)?.gone ?? 9) < REST), ...world.heroes];
    for (const u of units) {
      if (!u.alive) continue;
      const lift = Math.max(0.5, 1 - u.z * 0.3);
      g.fillStyle = 'rgba(0,0,0,0.38)';
      g.beginPath();
      g.arc(u.x, u.y, u.radius * 0.95 * lift, 0, TAU);
      g.fill();
      const ring = u.id === p.targetId ? PAL.danger : u.id === hoverId ? '#ffffff' : u.isPlayer ? PAL.gold : u.hero ? u.hero.color : '';
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
      // a streak of light that arcs from caster to target
      const x1 = this.sx(f.x), y1 = this.sy(f.y, 1.4), x2 = this.sx(f.x2!), y2 = this.sy(f.y2!, 1.2);
      g.globalCompositeOperation = 'lighter';
      g.strokeStyle = f.color;
      g.lineCap = 'round';
      for (const [wide, al] of [[9, 0.22], [2.5, 1]]) {
        g.globalAlpha = (1 - f.t / f.life) * al;
        g.lineWidth = wide;
        g.beginPath();
        g.moveTo(x1, y1);
        g.quadraticCurveTo((x1 + x2) / 2, Math.min(y1, y2) - Math.abs(x2 - x1) * 0.12 - 10, x2, y2);
        g.stroke();
      }
      g.globalAlpha = 1;
      g.globalCompositeOperation = 'source-over';
    }
    this.drawParticles(dt);

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
      g.font = `700 16px ${BODY_FONT}`;
      g.textAlign = 'center';
      g.lineWidth = 3;
      g.strokeStyle = 'rgba(0,0,0,0.75)';
      const x = this.sx(f.x), y = this.sy(f.y + 0.8, 1.7) - f.t * 38;
      g.strokeText(f.text!, x, y);
      g.fillStyle = f.color;
      g.fillText(f.text!, x, y);
      g.globalAlpha = 1;
    }
    this.drawBubbles(world, dt);

    // the dark closes in at the edges of the screen
    const vg = g.createRadialGradient(this.w / 2, this.h * 0.55, this.h * 0.35, this.w / 2, this.h * 0.55, Math.max(this.w, this.h) * 0.75);
    vg.addColorStop(0, 'rgba(4,9,12,0)');
    vg.addColorStop(1, 'rgba(4,9,12,0.55)');
    g.fillStyle = vg;
    g.fillRect(0, 0, this.w, this.h);
  }

  // Drifting specks of sea-light, purely for atmosphere.
  private motes(time: number) {
    const g = this.ctx;
    g.globalCompositeOperation = 'lighter';
    for (let i = 0; i < 46; i++) {
      const span = this.w + 80;
      const x = (((hash(i) * 3000 - this.camX * this.scale * (0.35 + hash(i * 3) * 0.5) + time * (4 + hash(i * 5) * 9)) % span) + span) % span - 40;
      const y = (((hash(i * 7) * 2000 - time * (5 + hash(i * 11) * 12)) % (this.h * 0.8)) + this.h * 0.8) % (this.h * 0.8);
      g.fillStyle = rgba(i % 5 ? PAL.glow : PAL.gold, 0.1 + 0.16 * (0.5 + 0.5 * Math.sin(time * 1.5 + i)));
      g.beginPath(); g.arc(x, y, 1.2 + hash(i * 13) * 1.8, 0, TAU); g.fill();
    }
    g.globalCompositeOperation = 'source-over';
  }

  private drawParticles(dt: number) {
    const g = this.ctx, s = this.scale;
    g.globalCompositeOperation = 'lighter';
    for (const q of this.parts) {
      q.t += dt;
      q.x += q.vx * dt;
      q.z += q.vz * dt;
      q.vx *= 1 - dt * 1.5;
      const a = Math.max(0, 1 - q.t / q.life);
      const x = this.sx(q.x) + (q.ring ? Math.sin(q.t * 6 + q.z * 3) * 4 : 0), y = this.sy(q.y, q.z);
      g.globalAlpha = a;
      if (q.ring) {
        g.strokeStyle = q.color;
        g.lineWidth = 1.5;
        g.beginPath(); g.arc(x, y, q.size * s * 1.6, 0, TAU); g.stroke();
      } else {
        g.fillStyle = q.color;
        g.beginPath(); g.arc(x, y, q.size * s, 0, TAU); g.fill();
      }
    }
    g.globalAlpha = 1;
    g.globalCompositeOperation = 'source-over';
    this.parts = this.parts.filter((q) => q.t < q.life);
  }

  private drawBubbles(world: World, dt: number) {
    const g = this.ctx;
    for (const b of this.bubbles) {
      b.t += dt;
      const u = world.unit(b.id);
      if (!u || !u.alive) continue;
      // wrap at about 26 characters
      const lines: string[] = [];
      for (const word of b.text.split(' ')) {
        const cur = lines[lines.length - 1];
        if (cur !== undefined && (cur + ' ' + word).length <= 26) lines[lines.length - 1] = cur + ' ' + word;
        else lines.push(word);
      }
      const wide = Math.max(...lines.map((l) => l.length)) * 7.4 + 22, tall = lines.length * 18 + 14;
      const x = Math.max(wide / 2 + 6, Math.min(this.w - wide / 2 - 6, this.sx(u.x)));
      const y = this.sy(u.y, u.z) - this.figH(u) * this.scale - 34 - tall;
      g.globalAlpha = Math.min(1, b.t * 5, (BUBBLE_TIME - b.t) * 2);
      g.fillStyle = '#efe3c2';
      g.strokeStyle = '#8a6d3a';
      g.lineWidth = 2;
      g.beginPath();
      g.roundRect(x - wide / 2, y, wide, tall, 10);
      g.fill(); g.stroke();
      g.beginPath();
      g.moveTo(this.sx(u.x) - 6, y + tall - 1); g.lineTo(this.sx(u.x), y + tall + 9); g.lineTo(this.sx(u.x) + 6, y + tall - 1);
      g.fill();
      g.fillStyle = '#1d2a2e';
      g.font = `italic 15px ${BODY_FONT}`;
      g.textAlign = 'center';
      lines.forEach((l, i) => g.fillText(l, x, y + 22 + i * 18));
      g.globalAlpha = 1;
    }
    this.bubbles = this.bubbles.filter((b) => b.t < BUBBLE_TIME);
  }

  private drawFigure(world: World, u: Unit, a: Anim) {
    const g = this.ctx;
    const H = this.figH(u) * this.scale;
    let rest = 0;
    g.save();
    g.translate(this.sx(u.x), this.sy(u.y, u.z));
    if (!u.alive) {
      if (u.hero) {
        // a fallen hero lies on the flagstones until the fight is over
        const k = Math.min(1, a.gone / 0.18);
        g.globalAlpha = 1 - 0.35 * k;
        g.rotate((-a.dir * Math.PI * k) / 2);
        g.translate(0, -H * 0.12 * k);
      } else {
        // the drowned are laid to rest: they rise, thin and turn to light
        rest = Math.min(1, a.gone / REST);
        g.globalAlpha = 1 - rest;
        g.translate(0, -rest * H * 0.45);
        g.scale(1 - rest * 0.25, 1 + rest * 0.15);
      }
    }
    if (u.alive) this.auraGlow(u, H, world.time);
    drawFigure(g, lookOf(u.hero?.id, u.enemy?.id), {
      H,
      dir: a.dir,
      step: u.alive && a.walking ? Math.sin(a.phase) : 0,
      swing: a.atk > 0 ? Math.sin((1 - a.atk / 0.22) * Math.PI) : 0,
      casting: u.alive && !!u.cast,
      flash: a.flash > 0,
      grey: !u.alive && !!u.hero,
      rest,
      time: world.time,
    });
    if (u.alive && u.auras.some((au) => (au.absorb ?? 0) > 0)) {
      // a shield: a glassy shell around the figure
      g.strokeStyle = rgba(PAL.glow, 0.7);
      g.fillStyle = rgba(PAL.glow, 0.12);
      g.lineWidth = 2;
      g.beginPath(); g.ellipse(0, -H * 0.45, H * 0.42, H * 0.56, 0, 0, TAU); g.fill(); g.stroke();
    }
    g.restore();
  }

  // Light at a figure's feet that shows what is on it. Drawn in the figure's own space, behind it.
  private auraGlow(u: Unit, H: number, time: number) {
    const g = this.ctx;
    let color = '';
    if (u.auras.some((a) => a.dispellable)) color = PAL.violet;
    else if (u.enemy && u.auras.some((a) => a.haste && a.dur > 100)) color = PAL.danger;
    else if (u.auras.some((a) => a.taken || a.takenPhys)) color = PAL.gold;
    else if (u.auras.some((a) => a.tickHeal)) color = '#8fe6b4';
    if (!color) return;
    g.globalCompositeOperation = 'lighter';
    const r = H * (0.5 + 0.04 * Math.sin(time * 5));
    const grad = g.createRadialGradient(0, -H * 0.3, 0, 0, -H * 0.3, r);
    grad.addColorStop(0, rgba(color, 0.4));
    grad.addColorStop(1, rgba(color, 0));
    g.fillStyle = grad;
    g.fillRect(-r, -H * 0.3 - r, r * 2, r * 2);
    g.globalCompositeOperation = 'source-over';
  }

  private heroPlate(h: Unit, x: number, top: number) {
    const g = this.ctx;
    const bw = 46, by = top - 12;
    g.fillStyle = INK;
    g.fillRect(x - bw / 2 - 1, by - 1, bw + 2, 7);
    g.fillStyle = h.hp / h.maxHp < 0.35 ? PAL.danger : '#5fcf8a';
    g.fillRect(x - bw / 2, by, bw * Math.max(0, h.hp / h.maxHp), 5);
    const shield = h.auras.reduce((n, a) => n + (a.absorb ?? 0), 0);
    if (shield > 0) {
      g.fillStyle = PAL.glow;
      g.fillRect(x - bw / 2, by - 3, bw * Math.min(1, shield / h.maxHp), 2);
    }
    if (h.cast) {
      g.fillStyle = INK;
      g.fillRect(x - bw / 2 - 1, by + 7, bw + 2, 5);
      g.fillStyle = PAL.gold;
      g.fillRect(x - bw / 2, by + 8, bw * (h.cast.t / h.cast.total), 3);
    }
    if (h.isPlayer) {
      g.fillStyle = PAL.gold;
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
    g.fillStyle = loose ? PAL.danger : INK;
    g.fillRect(x - bw / 2 - 2, by - 2, bw + 4, 10);
    g.fillStyle = PAL.deep;
    g.fillRect(x - bw / 2, by, bw, 6);
    g.fillStyle = '#c9584f';
    g.fillRect(x - bw / 2, by, bw * Math.max(0, e.hp / e.maxHp), 6);
    g.textAlign = 'center';
    g.strokeStyle = 'rgba(0,0,0,0.8)';
    g.lineWidth = 3;
    const named = targeted || hover || !!def.boss;
    if (named) {
      g.font = `400 14px ${DISPLAY_FONT}`;
      g.strokeText(e.name, x, by - 6);
      g.fillStyle = PAL.bone;
      g.fillText(e.name, x, by - 6);
    }
    const c = e.cast;
    if (!c) return;
    by -= named ? 34 : 17;
    const mine = c.assignee === world.player.id && !world.autoplay;
    g.fillStyle = INK;
    g.fillRect(x - bw / 2 - 2, by - 2, bw + 4, 13);
    g.fillStyle = c.interruptible ? PAL.gold : PAL.stone;
    g.fillRect(x - bw / 2, by, bw * Math.min(1, c.t / c.total), 9);
    g.font = `600 11px ${BODY_FONT}`;
    g.fillStyle = '#fff';
    g.strokeText(c.name, x, by + 8);
    g.fillText(c.name, x, by + 8);
    if (mine) {
      const pulse = 0.6 + 0.4 * Math.sin(world.time * 14);
      g.font = `400 18px ${DISPLAY_FONT}`;
      g.fillStyle = rgba(PAL.gold, pulse);
      g.strokeText('Silence!', x, by - 6);
      g.fillText('Silence!', x, by - 6);
    }
  }
}
