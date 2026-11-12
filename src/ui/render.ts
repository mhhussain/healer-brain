import type { Unit } from '../sim/types';
import type { World } from '../sim/world';

const CELL = 10;

export class Renderer {
  private ctx: CanvasRenderingContext2D;
  private mapCanvas = document.createElement('canvas');
  private mapVersion = -1;
  private mapOf: World | null = null;
  private w = 0;
  private h = 0;
  private dpr = 1;
  scale = 16;
  camX = 0;
  camY = 0;

  constructor(private canvas: HTMLCanvasElement) {
    this.ctx = canvas.getContext('2d')!;
  }

  resize() {
    this.dpr = window.devicePixelRatio || 1;
    this.w = this.canvas.clientWidth;
    this.h = this.canvas.clientHeight;
    this.canvas.width = Math.round(this.w * this.dpr);
    this.canvas.height = Math.round(this.h * this.dpr);
    this.scale = Math.max(11, this.h / 46);
  }

  toWorld(px: number, py: number) {
    return { x: (px - this.w / 2) / this.scale + this.camX, y: (py - this.h / 2) / this.scale + this.camY };
  }

  private sx(x: number) { return (x - this.camX) * this.scale + this.w / 2; }
  private sy(y: number) { return (y - this.camY) * this.scale + this.h / 2; }

  private renderMap(world: World) {
    const m = world.map;
    const c = this.mapCanvas;
    c.width = m.w * CELL;
    c.height = m.h * CELL;
    const g = c.getContext('2d')!;
    g.fillStyle = '#0c0d11';
    g.fillRect(0, 0, c.width, c.height);
    for (let y = 0; y < m.h; y++) for (let x = 0; x < m.w; x++) {
      if (!m.wall(x, y)) {
        g.fillStyle = (x + y) % 2 ? '#262a33' : '#292d37';
        g.fillRect(x * CELL, y * CELL, CELL, CELL);
      } else if (!m.wall(x - 1, y) || !m.wall(x + 1, y) || !m.wall(x, y - 1) || !m.wall(x, y + 1) ||
        !m.wall(x - 1, y - 1) || !m.wall(x + 1, y + 1) || !m.wall(x - 1, y + 1) || !m.wall(x + 1, y - 1)) {
        g.fillStyle = m.pillarAt[y * m.w + x] >= 0 ? '#5a6172' : '#3d4352';
        g.fillRect(x * CELL, y * CELL, CELL, CELL);
      }
    }
    this.mapVersion = m.version;
    this.mapOf = world;
  }

  draw(world: World, hoverId: number) {
    const g = this.ctx;
    const s = this.scale;
    const p = world.player;
    this.camX = p.x;
    this.camY = p.y;
    if (this.mapOf !== world || this.mapVersion !== world.map.version) this.renderMap(world);

    g.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    g.fillStyle = '#0c0d11';
    g.fillRect(0, 0, this.w, this.h);
    g.imageSmoothingEnabled = false;
    g.drawImage(this.mapCanvas, this.sx(0), this.sy(0), world.map.w * s, world.map.h * s);

    // telegraphs
    for (const z of world.zones) {
      const k = Math.min(1, z.t / z.delay);
      const x = this.sx(z.x), y = this.sy(z.y);
      const shape = (r: number) => {
        g.beginPath();
        if (z.kind === 'circle') g.arc(x, y, r * s, 0, Math.PI * 2);
        else { g.moveTo(x, y); g.arc(x, y, r * s, z.dir! - z.half!, z.dir! + z.half!); g.closePath(); }
      };
      shape(z.r);
      g.fillStyle = 'rgba(255,70,50,0.16)';
      g.fill();
      g.strokeStyle = 'rgba(255,110,80,0.9)';
      g.lineWidth = 2;
      g.stroke();
      shape(z.r * k);
      g.fillStyle = 'rgba(255,70,50,0.32)';
      g.fill();
    }

    for (const f of world.fx) {
      if (f.kind !== 'ring') continue;
      g.globalAlpha = 1 - f.t / f.life;
      g.strokeStyle = f.color;
      g.lineWidth = 3;
      g.beginPath();
      g.arc(this.sx(f.x), this.sy(f.y), f.r! * s * (0.5 + (0.5 * f.t) / f.life), 0, Math.PI * 2);
      g.stroke();
      g.globalAlpha = 1;
    }

    const tank = world.heroes[0];
    for (const e of world.enemies) if (e.alive) this.drawEnemy(world, e, e.id === p.targetId, e.id === hoverId, tank);
    for (const h of world.heroes) this.drawHero(world, h, h.id === hoverId);

    for (const f of world.fx) {
      const a = 1 - f.t / f.life;
      if (f.kind === 'beam') {
        g.globalAlpha = a;
        g.strokeStyle = f.color;
        g.lineWidth = 2.5;
        g.beginPath();
        g.moveTo(this.sx(f.x), this.sy(f.y));
        g.lineTo(this.sx(f.x2!), this.sy(f.y2!));
        g.stroke();
      } else if (f.kind === 'text') {
        g.globalAlpha = Math.min(1, a * 1.6);
        g.font = '600 13px system-ui, sans-serif';
        g.textAlign = 'center';
        g.lineWidth = 3;
        g.strokeStyle = 'rgba(0,0,0,0.7)';
        const y = this.sy(f.y) - f.t * 34;
        g.strokeText(f.text!, this.sx(f.x), y);
        g.fillStyle = f.color;
        g.fillText(f.text!, this.sx(f.x), y);
      }
      g.globalAlpha = 1;
    }
  }

  private drawHero(world: World, h: Unit, hover: boolean) {
    const g = this.ctx, s = this.scale;
    const x = this.sx(h.x), y = this.sy(h.y), r = 0.62 * s;
    g.globalAlpha = h.alive ? 1 : 0.35;
    g.beginPath();
    g.arc(x, y, r, 0, Math.PI * 2);
    g.fillStyle = h.alive ? h.hero!.color : '#666';
    g.fill();
    g.lineWidth = h.isPlayer ? 3 : 1.5;
    g.strokeStyle = h.isPlayer ? '#fff' : hover ? '#fff' : '#101216';
    g.stroke();
    if (h.alive) {
      g.beginPath();
      g.moveTo(x + Math.cos(h.facing) * r, y + Math.sin(h.facing) * r);
      g.lineTo(x + Math.cos(h.facing) * (r + 5), y + Math.sin(h.facing) * (r + 5));
      g.strokeStyle = '#fff';
      g.lineWidth = 2;
      g.stroke();
    }
    g.fillStyle = '#101216';
    g.font = `700 ${Math.round(r)}px system-ui, sans-serif`;
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.fillText(h.alive ? h.hero!.name[0] : '✕', x, y + 1);
    g.textBaseline = 'alphabetic';
    if (h.alive) {
      const bw = 40, by = y - r - 10;
      g.fillStyle = '#15171c';
      g.fillRect(x - bw / 2 - 1, by - 1, bw + 2, 6);
      g.fillStyle = h.hp / h.maxHp < 0.35 ? '#e0563f' : '#4fbf68';
      g.fillRect(x - bw / 2, by, bw * Math.max(0, h.hp / h.maxHp), 4);
      const shield = h.auras.reduce((n, a) => n + (a.absorb ?? 0), 0);
      if (shield > 0) {
        g.fillStyle = '#e8f1ff';
        g.fillRect(x - bw / 2, by - 2, bw * Math.min(1, shield / h.maxHp), 2);
      }
      if (h.cast) {
        g.fillStyle = '#15171c';
        g.fillRect(x - bw / 2 - 1, by + 6, bw + 2, 4);
        g.fillStyle = '#e9c46a';
        g.fillRect(x - bw / 2, by + 7, bw * (h.cast.t / h.cast.total), 2);
      }
    }
    g.globalAlpha = 1;
  }

  private drawEnemy(world: World, e: Unit, targeted: boolean, hover: boolean, tank: Unit) {
    const g = this.ctx, s = this.scale;
    const def = e.enemy!;
    const x = this.sx(e.x), y = this.sy(e.y), r = e.radius * s * 1.1;
    g.beginPath();
    g.moveTo(x, y - r); g.lineTo(x + r, y); g.lineTo(x, y + r); g.lineTo(x - r, y);
    g.closePath();
    g.fillStyle = def.boss ? '#8e3fb0' : def.elite ? '#c2622d' : def.range > 5 ? '#b0486e' : '#a63d3d';
    if (!e.engaged) g.globalAlpha = 0.8;
    g.fill();
    g.globalAlpha = 1;
    g.lineWidth = targeted ? 3 : 1.5;
    g.strokeStyle = targeted ? '#fff' : hover ? '#ffe9a8' : '#101216';
    g.stroke();
    g.beginPath();
    g.moveTo(x + Math.cos(e.facing) * r * 0.7, y + Math.sin(e.facing) * r * 0.7);
    g.lineTo(x + Math.cos(e.facing) * (r + 4), y + Math.sin(e.facing) * (r + 4));
    g.strokeStyle = '#ffd0c0';
    g.lineWidth = 2;
    g.stroke();
    g.fillStyle = '#fff';
    g.font = `700 ${Math.round(Math.min(r, 16))}px system-ui, sans-serif`;
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.fillText(def.letter, x, y + 1);
    g.textBaseline = 'alphabetic';

    // nameplate
    const bw = def.boss ? 120 : def.elite ? 72 : 54;
    let by = y - r - 14;
    const loose = e.engaged && tank.alive && e.targetId !== tank.id && e.targetId >= 0;
    g.fillStyle = loose ? '#e0392b' : '#15171c';
    g.fillRect(x - bw / 2 - 2, by - 2, bw + 4, 9);
    g.fillStyle = '#15171c';
    g.fillRect(x - bw / 2, by, bw, 5);
    g.fillStyle = '#d9534f';
    g.fillRect(x - bw / 2, by, bw * Math.max(0, e.hp / e.maxHp), 5);
    if (targeted || hover || def.boss) {
      g.font = '600 11px system-ui, sans-serif';
      g.fillStyle = '#e8e8ea';
      g.fillText(e.name, x, by - 5);
    }
    const c = e.cast;
    if (c) {
      by -= targeted || hover || def.boss ? 30 : 16;
      const mine = c.assignee === world.player.id && !world.autoplay;
      g.fillStyle = '#15171c';
      g.fillRect(x - bw / 2 - 2, by - 2, bw + 4, 12);
      g.fillStyle = c.interruptible ? '#e9b949' : '#8a8f9c';
      g.fillRect(x - bw / 2, by, bw * Math.min(1, c.t / c.total), 8);
      g.font = '600 10px system-ui, sans-serif';
      g.fillStyle = '#fff';
      g.strokeStyle = 'rgba(0,0,0,0.8)';
      g.lineWidth = 3;
      g.strokeText(c.name, x, by + 8);
      g.fillText(c.name, x, by + 8);
      if (mine) {
        const pulse = 0.6 + 0.4 * Math.sin(world.time * 14);
        g.font = '800 14px system-ui, sans-serif';
        g.fillStyle = `rgba(255,230,90,${pulse})`;
        g.strokeText('KICK', x, by - 6);
        g.fillText('KICK', x, by - 6);
      }
    }
  }
}
