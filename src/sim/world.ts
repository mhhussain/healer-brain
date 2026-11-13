import { GameMap } from './map';
import { buildDungeon, type PackDef } from './dungeon';
import { HEROES } from './heroes';
import { ENEMIES } from './enemies';
import { heroAI, newAI } from './heroAI';
import { enemyAI } from './enemyAI';
import type { AbilityDef, Aura, DmgType, EnemyAbility, Unit } from './types';

export const TIME_LIMIT = 14 * 60;
export const DEATH_PENALTY = 5;
export const DT = 1 / 60;
const JUMP_SPEED = 6.6;
const GRAVITY = 22;

export interface RunConfig {
  level: number;
  // tank, healer, dps, dps
  party: string[];
  playerSlot: number;
  seed?: number;
  autoplay?: boolean;
}

export interface Pack {
  def: PackDef;
  units: Unit[];
  engaged: boolean;
  cleared: boolean;
  engagedAt: number;
  tankHitAt: number | null;
}

export interface Zone {
  kind: 'circle' | 'cone';
  x: number;
  y: number;
  r: number;
  dir?: number;
  half?: number;
  t: number;
  delay: number;
  dmg: number;
  type: DmgType;
  ownerId?: number;
  tied?: boolean;
}

export interface Fx {
  kind: 'text' | 'beam' | 'ring';
  x: number;
  y: number;
  x2?: number;
  y2?: number;
  r?: number;
  text?: string;
  color: string;
  t: number;
  life: number;
}

// Things that just happened, for sound and story. The interface drains this; the simulation never reads it.
export interface SimEvent { k: 'hit' | 'heal' | 'death' | 'interrupt' | 'dispel' | 'ability' | 'engage' | 'clear' | 'wipe' | 'boom'; id?: number; src?: number; amt?: number; s?: string }

export interface AbilityState { cd: number; cdMax: number; usable: boolean }

const dist = (a: { x: number; y: number }, b: { x: number; y: number }) => Math.hypot(a.x - b.x, a.y - b.y);

export function inZone(z: Zone, x: number, y: number, margin = 0) {
  const d = Math.hypot(x - z.x, y - z.y);
  if (d > z.r + margin) return false;
  if (z.kind === 'circle' || d < 0.5) return true;
  let a = Math.atan2(y - z.y, x - z.x) - z.dir!;
  a = Math.atan2(Math.sin(a), Math.cos(a));
  return Math.abs(a) <= z.half! + (margin > 0 ? 0.2 : 0);
}

export class World {
  map: GameMap;
  packs: Pack[] = [];
  heroes: Unit[] = [];
  enemies: Unit[] = [];
  zones: Zone[] = [];
  fx: Fx[] = [];
  alerts: { text: string; t: number }[] = [];
  events: SimEvent[] = [];
  error: { text: string; t: number } | null = null;

  level: number;
  scale: number;
  time = 0;
  elapsed = 0;
  deaths = 0;
  started = false;
  finished = false;
  inCombat = false;
  gather: { x: number; y: number; until: number } | null = null;

  player: Unit;
  autoplay: boolean;
  input = { mx: 0, my: 0 };
  hoverAllyId = -1;
  private queued: { idx: number; targetId: number; until: number } | null = null;

  private nextId = 1;
  private seed: number;
  private units = new Map<number, Unit>();

  constructor(public cfg: RunConfig) {
    const d = buildDungeon();
    this.map = d.map;
    this.level = cfg.level;
    this.scale = Math.pow(1.08, cfg.level - 1);
    this.seed = (cfg.seed ?? Date.now()) >>> 0;
    this.autoplay = !!cfg.autoplay;
    cfg.party.forEach((id, i) => {
      const def = HEROES[id];
      const u = this.makeUnit('hero', def.name, d.start.x - i * 1.6, d.start.y + (i % 2 ? 1.2 : -1.2));
      u.hero = def;
      u.slot = i;
      u.maxHp = u.hp = def.hp;
      u.resMax = def.resMax;
      u.res = def.resStart;
      u.speed = 7;
      u.ai = newAI(this);
      this.heroes.push(u);
    });
    this.player = this.heroes[cfg.playerSlot];
    this.player.isPlayer = true;
    for (const def of d.packs) {
      const pack: Pack = { def, units: [], engaged: false, cleared: false, engagedAt: 0, tankHitAt: null };
      this.packs.push(pack);
      def.enemies.forEach((eid, i) => {
        const n = def.enemies.length;
        const a = (i / n) * Math.PI * 2 + 0.6;
        const r = n > 1 ? 3.2 : 0;
        this.spawnEnemy(eid, def.center.x + Math.cos(a) * r, def.center.y + Math.sin(a) * r, def.id, false);
      });
    }
  }

  // ---------- basics

  rng() {
    let t = (this.seed += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  private makeUnit(team: 'hero' | 'enemy', name: string, x: number, y: number): Unit {
    const u: Unit = {
      id: this.nextId++, team, name, x, y, z: 0, vz: 0, jumpAt: -1, facing: 0, radius: 0.6, speed: 5.5,
      hp: 1, maxHp: 1, alive: true, res: 0, resMax: 0, combo: 0, targetId: -1,
      cast: null, gcd: 0, cds: {}, auras: [], autoTimer: 0, moved: false, moveDir: 0, lastMoveT: -9,
      stats: { dmg: 0, heal: 0, interrupts: 0, dispels: 0, deaths: 0 },
      path: null, pathGoal: null, pathAge: 0,
      isPlayer: false, slot: 0, lastInterrupt: -99, rageGate: -9,
      packId: -1, engaged: false, spawnX: x, spawnY: y, threat: new Map(), forcedId: -1, forcedT: 0,
      busy: 0, pending: null, slotAngle: 0, summoned: false, aggroT: 0, flags: {},
    };
    this.units.set(u.id, u);
    return u;
  }

  spawnEnemy(defId: string, x: number, y: number, packId: number, summoned: boolean) {
    const def = ENEMIES[defId];
    const pack = this.packs[packId];
    const u = this.makeUnit('enemy', def.name, x, y);
    u.enemy = def;
    u.radius = def.radius;
    u.maxHp = u.hp = Math.round(def.hp * this.scale);
    u.packId = packId;
    u.summoned = summoned;
    u.slotAngle = pack.units.length * 2.4;
    pack.units.push(u);
    this.enemies.push(u);
    if (summoned && pack.engaged) this.wake(u);
    return u;
  }

  unit(id: number) { return this.units.get(id) ?? null; }
  aliveHeroes() { return this.heroes.filter((h) => h.alive); }
  engagedEnemies() { return this.enemies.filter((e) => e.alive && e.engaged); }
  enemiesNear(x: number, y: number, r: number) {
    return this.enemies.filter((e) => e.alive && Math.hypot(e.x - x, e.y - y) <= r + e.radius * 0.5);
  }
  randomHero() {
    const a = this.aliveHeroes();
    return a.length ? a[Math.floor(this.rng() * a.length)] : null;
  }
  randomHeroes(n: number) {
    const a = this.aliveHeroes();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(this.rng() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a.slice(0, n);
  }
  nextPack() { return this.packs.find((p) => !p.cleared) ?? null; }
  totalTime() { return this.elapsed + this.deaths * DEATH_PENALTY; }
  timed() { return this.finished && this.totalTime() <= TIME_LIMIT; }

  // ---------- effects

  text(x: number, y: number, text: string, color: string) {
    this.fx.push({ kind: 'text', x: x + (this.rng() - 0.5) * 1.2, y: y - 0.8, text, color, t: 0, life: 0.9 });
  }
  beam(a: Unit, b: Unit, color: string) {
    this.fx.push({ kind: 'beam', x: a.x, y: a.y, x2: b.x, y2: b.y, color, t: 0, life: 0.16 });
  }
  ring(x: number, y: number, r: number, color: string) {
    this.fx.push({ kind: 'ring', x, y, r, color, t: 0, life: 0.3 });
  }
  alert(text: string) { this.alerts.push({ text, t: 0 }); }
  private emit(e: SimEvent) { if (this.events.length < 400) this.events.push(e); }
  zone(z: Omit<Zone, 't'>) { this.zones.push({ ...z, t: 0 }); }

  hasAura(u: Unit, id: string) { return u.auras.some((a) => a.id === id); }

  addAura(u: Unit, a: Omit<Aura, 't'>) {
    if (!u.alive) return;
    u.auras = u.auras.filter((o) => o.id !== a.id);
    u.auras.push({ ...a, t: a.dur, tickTimer: a.tickEvery });
  }

  gain(u: Unit, n: number) { u.res = Math.max(0, Math.min(u.resMax, u.res + n)); }

  // ---------- damage, healing, threat

  damage(src: Unit | null, tgt: Unit, amount: number, type: DmgType, o: { raw?: boolean; noBeam?: boolean; scaled?: boolean } = {}) {
    if (!tgt.alive) return 0;
    let a = amount;
    if (!o.raw) {
      if (src) {
        for (const au of src.auras) if (au.done) a *= au.done;
        if (src.team === 'enemy') a *= this.scale * this.enemyBonus(src);
      } else if (o.scaled) a *= this.scale;
      for (const au of tgt.auras) {
        if (au.taken) a *= au.taken;
        if (type === 'phys' && au.takenPhys) a *= au.takenPhys;
      }
    }
    for (const au of tgt.auras) {
      if (!au.absorb || a <= 0) continue;
      const ab = Math.min(au.absorb, a);
      au.absorb -= ab;
      a -= ab;
      const s = this.unit(au.srcId);
      if (s) s.stats.heal += ab;
      if (au.absorb <= 0) au.t = 0;
    }
    a = Math.round(a);
    tgt.hp -= a;
    this.emit({ k: 'hit', id: tgt.id, src: src ? src.id : -1, amt: a, s: type });
    if (src && !o.noBeam && dist(src, tgt) > 4) this.beam(src, tgt, src.hero ? src.hero.color : '#b58cf0');
    if (tgt.team === 'enemy') {
      if (src && src.hero) {
        src.stats.dmg += a;
        this.engageFrom(src, tgt);
        this.addThreat(tgt, src.id, a * src.hero.threatMult);
      }
      if (a > 0) this.text(tgt.x, tgt.y, String(a), src && src.isPlayer ? '#f0b54a' : '#d9d3c2');
    } else {
      if (tgt.hero!.id === 'warden' && src && a > 0 && this.time - tgt.rageGate >= 1) {
        tgt.rageGate = this.time;
        this.gain(tgt, 1);
      }
      this.text(tgt.x, tgt.y, a > 0 ? '-' + a : 'absorbed', '#ef5d4a');
    }
    if (tgt.hp <= 0) this.kill(tgt);
    return a;
  }

  private enemyBonus(e: Unit) {
    let m = 1;
    if (e.enemy!.boss) return m;
    if (this.level >= 3 && this.enemies.some((o) => o.alive && o.engaged && o !== e && o.enemy!.id === 'overseer' && dist(o, e) <= 15)) m *= 1.15;
    if (this.level >= 9 && e.hp / e.maxHp < 0.25) m *= 1.25;
    return m;
  }

  heal(src: Unit, tgt: Unit, amount: number) {
    if (!tgt.alive) return 0;
    const eff = Math.round(Math.min(tgt.maxHp - tgt.hp, amount));
    tgt.hp += eff;
    if (eff > 0) {
      src.stats.heal += eff;
      this.emit({ k: 'heal', id: tgt.id, src: src.id, amt: eff });
      this.text(tgt.x, tgt.y, '+' + eff, '#8fe6b4');
      const es = this.engagedEnemies();
      for (const e of es) this.addThreat(e, src.id, (eff * 0.5) / es.length);
    }
    return eff;
  }

  private kill(u: Unit) {
    u.alive = false;
    u.hp = 0;
    u.cast = null;
    this.emit({ k: 'death', id: u.id });
    u.auras = [];
    u.path = null;
    if (u.team === 'hero') {
      u.stats.deaths++;
      this.deaths++;
      this.text(u.x, u.y, u.name + ' falls', '#ef5d4a');
    } else {
      u.enemy!.onDeath?.(this, u);
    }
  }

  addThreat(e: Unit, heroId: number, amt: number) {
    e.threat.set(heroId, (e.threat.get(heroId) ?? 0) + amt);
  }

  private wake(u: Unit) {
    u.engaged = true;
    for (const ab of u.enemy!.abilities) u.cds[ab.id] = ab.first ?? ab.cd * (0.3 + 0.7 * this.rng());
  }

  engage(pack: Pack, hero: Unit) {
    if (pack.engaged || pack.cleared) return;
    pack.engaged = true;
    pack.engagedAt = this.time;
    pack.tankHitAt = null;
    this.started = true;
    this.inCombat = true;
    this.emit({ k: 'engage', id: pack.def.id });
    for (const u of pack.units) {
      if (!u.alive) continue;
      this.wake(u);
      this.addThreat(u, hero.id, 1);
    }
  }

  // A hero did something hostile to an enemy.
  engageFrom(hero: Unit, e: Unit) {
    const pack = this.packs[e.packId];
    this.engage(pack, hero);
    if (hero.hero!.role === 'tank' && pack.tankHitAt == null) pack.tankHitAt = this.time;
    if (!e.threat.has(hero.id)) this.addThreat(e, hero.id, 1);
  }

  taunt(u: Unit, e: Unit) {
    this.engageFrom(u, e);
    let max = 0;
    for (const v of e.threat.values()) max = Math.max(max, v);
    e.threat.set(u.id, max * 1.1 + 100);
    e.forcedId = u.id;
    e.forcedT = this.time + 4;
    this.beam(u, e, u.hero!.color);
  }

  interrupt(u: Unit, e: Unit) {
    this.engageFrom(u, e);
    const c = e.cast;
    if (!c || !c.interruptible) {
      this.text(e.x, e.y, 'Nothing to silence', '#9fb0b1');
      return;
    }
    e.cast = null;
    e.busy = 0.6;
    e.cds[c.ab!.id] = Math.max(c.ab!.cd, 3);
    u.stats.interrupts++;
    this.emit({ k: 'interrupt', id: e.id, src: u.id });
    u.lastInterrupt = this.time;
    this.text(e.x, e.y, 'Silenced', '#f0b54a');
    if (dist(u, e) > 4) this.beam(u, e, u.hero!.color);
  }

  dispel(u: Unit, t: Unit) {
    const before = t.auras.length;
    t.auras = t.auras.filter((a) => !a.dispellable);
    if (t.auras.length < before) {
      u.stats.dispels++;
      this.emit({ k: 'dispel', id: t.id });
      this.text(t.x, t.y, 'Cleansed', '#c9a2ff');
    }
  }

  pickThreatTarget(e: Unit): Unit | null {
    if (e.forcedT > this.time) {
      const f = this.unit(e.forcedId);
      if (f && f.alive) return f;
    }
    let best: Unit | null = null, bestV = -1;
    for (const [id, v] of e.threat) {
      const h = this.unit(id);
      if (h && h.alive && v > bestV) { best = h; bestV = v; }
    }
    if (!best) {
      for (const h of this.heroes) if (h.alive && (!best || dist(h, e) < dist(best, e))) best = h;
      if (best) this.addThreat(e, best.id, 1);
      return best;
    }
    const cur = this.unit(e.targetId);
    if (!cur || !cur.alive || cur.team !== 'hero' || !e.threat.has(cur.id) || cur === best) return best;
    const mult = dist(best, e) <= 4 ? 1.1 : 1.3;
    return bestV > e.threat.get(cur.id)! * mult ? best : cur;
  }

  startEnemyCast(e: Unit, ab: EnemyAbility, t: Unit | null) {
    e.cds[ab.id] = ab.cd + ab.cast;
    e.pending = null;
    if (ab.cast <= 0) {
      e.busy = 0.3;
      ab.finish?.(this, e, t);
      return;
    }
    e.cast = {
      name: ab.name, t: 0, total: ab.cast, targetId: t ? t.id : -1, ab,
      interruptible: !!ab.interruptible, importance: ab.importance ?? 1, tickTimer: 1,
    };
    ab.start?.(this, e, t, e.cast);
  }

  hideCaster() {
    return this.enemies.find((e) => e.alive && e.cast && e.cast.ab!.hide) ?? null;
  }

  // DPS and healers hold their damage until the tank has had a moment to take threat.
  canAttack() {
    if (this.gather) return false;
    const pack = this.packs.find((p) => p.engaged && !p.cleared);
    if (!pack) return false;
    if (!this.heroes[0].alive) return true;
    if (pack.tankHitAt == null) return this.time - pack.engagedAt > 4;
    return this.time - pack.tankHitAt > 1.5;
  }

  // ---------- hero abilities

  castTime(u: Unit, ab: AbilityDef) {
    const c = ab.cast ?? 0;
    return ab.id === 'firebolt' && this.hasAura(u, 'kindled') ? c / 2 : c;
  }

  private checkTarget(u: Unit, ab: AbilityDef, t: Unit | null, leeway = 0): string | null {
    if (ab.target === 'self') return null;
    if (!t || !t.alive) return ab.target === 'enemy' ? 'No target' : 'Target is dead';
    if (t === u) return null;
    const range = ab.range ?? 30;
    if (dist(u, t) > range + t.radius * 0.5 + leeway) return 'Out of range';
    if (range > 5 && !this.map.los(u.x, u.y, t.x, t.y)) return 'No line of sight';
    return null;
  }

  // Returns null on success, or the reason it could not be used.
  useAbility(u: Unit, idx: number, target: Unit | null): string | null {
    const ab = u.hero!.abilities[idx];
    if (!u.alive) return 'You are dead';
    if ((u.cds[ab.id] ?? 0) > 0) return 'cd';
    if (!ab.offGcd && (u.gcd > 0 || u.cast)) return 'gcd';
    let t: Unit | null = u;
    if (ab.target === 'enemy') t = target && target.team === 'enemy' ? target : null;
    else if (ab.target === 'ally') t = target && target.team === 'hero' ? target : u;
    const bad = this.checkTarget(u, ab, t);
    if (bad) return bad;
    if (ab.cost && u.res < ab.cost) return 'Not enough ' + u.hero!.resName.toLowerCase();
    const no = ab.usable?.(this, u);
    if (no) return no;
    const ct = this.castTime(u, ab);
    if (ct > 0) {
      if (u.moved) return 'Cannot cast while moving';
      u.cast = { name: ab.name, t: 0, total: ct, targetId: t!.id, abIdx: idx };
      u.gcd = Math.min(u.hero!.gcd, Math.max(1, ct));
      this.face(u, t!);
      return null;
    }
    this.fire(u, ab, t!);
    return null;
  }

  private fire(u: Unit, ab: AbilityDef, t: Unit) {
    if (ab.cost) u.res -= ab.cost;
    if (ab.cd) u.cds[ab.id] = ab.cd;
    if (!ab.offGcd && !ab.cast) u.gcd = u.hero!.gcd;
    this.face(u, t);
    this.emit({ k: 'ability', id: u.id, s: ab.id });
    ab.fire(this, u, t);
  }

  private face(u: Unit, t: Unit) {
    if (t !== u) u.facing = Math.atan2(t.y - u.y, t.x - u.x);
  }

  abilityState(u: Unit, idx: number): AbilityState {
    const ab = u.hero!.abilities[idx];
    const cd = Math.max(u.cds[ab.id] ?? 0, ab.offGcd ? 0 : u.gcd);
    const cdMax = (u.cds[ab.id] ?? 0) > u.gcd || ab.offGcd ? ab.cd ?? 1 : u.hero!.gcd;
    let usable = u.alive && !(ab.cost && u.res < ab.cost) && !ab.usable?.(this, u);
    if (usable && ab.target === 'enemy') {
      const t = this.unit(u.targetId);
      if (t && t.alive) usable = !this.checkTarget(u, ab, t);
    }
    return { cd, cdMax, usable };
  }

  // ---------- player

  // Called by the interface. allyId is the party member a click-cast landed on.
  press(idx: number, allyId = -1) {
    const p = this.player;
    const ab = p.hero!.abilities[idx];
    let targetId = -1;
    if (ab.target === 'enemy') {
      let t = this.unit(p.targetId);
      if (!t || !t.alive || t.team !== 'enemy') {
        const tt = this.unit(this.heroes[0].targetId);
        if (tt && tt.alive && tt.team === 'enemy') { t = tt; p.targetId = tt.id; }
      }
      targetId = t ? t.id : -1;
    } else if (ab.target === 'ally') {
      targetId = allyId >= 0 ? allyId : this.hoverAllyId >= 0 ? this.hoverAllyId : p.id;
    }
    this.queued = { idx, targetId, until: this.time + 0.5 };
  }

  tabTarget() {
    const p = this.player;
    const list = this.enemies
      .filter((e) => e.alive && dist(e, p) <= 45 && this.map.los(p.x, p.y, e.x, e.y))
      .sort((a, b) => (a.engaged === b.engaged ? dist(a, p) - dist(b, p) : a.engaged ? -1 : 1));
    if (!list.length) return;
    const i = list.findIndex((e) => e.id === p.targetId);
    p.targetId = list[(i + 1) % list.length].id;
  }

  // Cosmetic: it changes nothing about combat.
  jump(u: Unit = this.player) {
    if (u.alive && u.z === 0) u.vz = JUMP_SPEED;
  }

  private fail(text: string) { this.error = { text, t: 0 }; }

  private updatePlayer(dt: number) {
    const p = this.player;
    if (!p.alive) { this.queued = null; return; }
    let { mx, my } = this.input;
    const len = Math.hypot(mx, my);
    if (len > 0) {
      mx /= len; my /= len;
      if (this.map.move(p, mx * p.speed * dt, my * p.speed * dt)) {
        p.moved = true;
        p.moveDir = Math.atan2(my, mx);
        p.lastMoveT = this.time;
        p.facing = p.moveDir;
      }
    }
    const t = this.unit(p.targetId);
    if (t && t.alive && t.team === 'enemy') p.facing = Math.atan2(t.y - p.y, t.x - p.x);
    const q = this.queued;
    if (!q) return;
    const r = this.useAbility(p, q.idx, this.unit(q.targetId));
    if (r === null) { this.queued = null; return; }
    const ab = p.hero!.abilities[q.idx];
    const waiting = r === 'gcd' || (r === 'cd' && (p.cds[ab.id] ?? 0) < 0.5);
    if (waiting && this.time < q.until) return;
    this.queued = null;
    if (r === 'cd') this.fail(ab.name + ' is not ready');
    else if (r !== 'gcd') this.fail(r);
  }

  // ---------- movement

  navigate(u: Unit, gx: number, gy: number, dt: number) {
    const d = Math.hypot(gx - u.x, gy - u.y);
    if (d < 0.05) return false;
    let tx = gx, ty = gy;
    if (!this.map.clearWalk(u.x, u.y, gx, gy)) {
      u.pathAge += dt;
      if (!u.path || !u.pathGoal || dist(u.pathGoal, { x: gx, y: gy }) > 1.5 || u.pathAge > 1) {
        u.path = this.map.findPath(u.x, u.y, gx, gy);
        u.pathGoal = { x: gx, y: gy };
        u.pathAge = 0;
      }
      const path = u.path;
      if (path && path.length) {
        while (path.length > 1 && this.map.clearWalk(u.x, u.y, path[1].x, path[1].y)) path.shift();
        if (path.length > 1 && dist(u, path[0]) < 0.3) path.shift();
        tx = path[0].x; ty = path[0].y;
      }
    } else {
      u.path = null;
    }
    const td = Math.hypot(tx - u.x, ty - u.y);
    if (td < 1e-6) return false;
    const step = Math.min(u.speed * dt, td);
    const moved = this.map.move(u, ((tx - u.x) / td) * step, ((ty - u.y) / td) * step);
    if (moved) {
      u.moved = true;
      u.moveDir = Math.atan2(ty - u.y, tx - u.x);
      u.lastMoveT = this.time;
      u.facing = u.moveDir;
    }
    return moved;
  }

  // ---------- tick

  tick(dt: number) {
    if (this.finished) return;
    this.time += dt;
    if (this.started) this.elapsed += dt;
    for (const h of this.heroes) h.moved = false;
    this.updatePlayer(dt);
    for (const h of this.heroes) if (h.alive && (!h.isPlayer || this.autoplay)) heroAI(this, h, dt);
    for (const e of this.enemies) if (e.alive) enemyAI(this, e, dt);
    for (const u of this.heroes) this.updateUnit(u, dt);
    for (const u of this.enemies) this.updateUnit(u, dt);
    this.updateZones(dt);
    this.assignInterrupts();
    this.updateCombat();
    for (const f of this.fx) f.t += dt;
    this.fx = this.fx.filter((f) => f.t < f.life);
    for (const a of this.alerts) a.t += dt;
    this.alerts = this.alerts.filter((a) => a.t < 3.5);
    if (this.error && (this.error.t += dt) > 1.5) this.error = null;
  }

  private updateUnit(u: Unit, dt: number) {
    if (u.z > 0 || u.vz > 0) {
      u.z += u.vz * dt;
      u.vz -= GRAVITY * dt;
      if (u.z <= 0) { u.z = 0; u.vz = 0; }
    }
    if (!u.alive) return;
    if (u.jumpAt >= 0 && this.time >= u.jumpAt) { u.jumpAt = -1; this.jump(u); }
    if (u.gcd > 0) u.gcd -= dt;
    for (const k in u.cds) if (u.cds[k] > 0) u.cds[k] -= dt;

    for (const a of u.auras) {
      a.t -= dt;
      if (!a.tickEvery) continue;
      const src = this.unit(a.srcId);
      const rate = a.id === 'vine' && src && this.hasAura(src, 'tide') ? 2 : 1;
      a.tickTimer! -= dt * rate;
      if (a.tickTimer! > 0) continue;
      a.tickTimer! += a.tickEvery;
      if (a.tickDmg) this.damage(src, u, a.tickDmg, 'magic', { noBeam: true, scaled: true });
      if (a.tickHeal && src) this.heal(src, u, a.tickHeal);
      if (!u.alive) return;
    }
    u.auras = u.auras.filter((a) => a.t > 0);

    if (!u.hero) return;
    const def = u.hero;
    const c = u.cast;
    if (c) {
      if (u.moved) u.cast = null;
      else if ((c.t += dt) >= c.total) {
        u.cast = null;
        const ab = def.abilities[c.abIdx!];
        const t = this.unit(c.targetId);
        if (!this.checkTarget(u, ab, t, 5) && !(ab.cost && u.res < ab.cost)) this.fire(u, ab, t!);
      }
    }

    if (this.inCombat) {
      if (def.regen) this.gain(u, def.regen * dt * (this.hasAura(u, 'bloodrush') ? 2 : 1));
    } else {
      u.hp = Math.min(u.maxHp, u.hp + u.maxHp * 0.1 * dt);
      if (def.regen) this.gain(u, u.resMax * 0.1 * dt);
      else this.gain(u, -8 * dt);
    }

    const t = this.unit(u.targetId);
    if (u.autoTimer > 0) {
      let haste = 1;
      for (const a of u.auras) if (a.haste) haste *= a.haste;
      u.autoTimer -= dt * haste;
    }
    const free = def.role === 'tank' || (u.isPlayer && !this.autoplay) || this.canAttack();
    if (t && t.alive && t.team === 'enemy' && t.engaged && !u.cast && u.autoTimer <= 0 && free) {
      const range = def.auto.range;
      if (dist(u, t) <= range + t.radius * 0.5 && (range < 5 || this.map.los(u.x, u.y, t.x, t.y))) {
        u.autoTimer = def.auto.interval;
        this.damage(u, t, def.auto.dmg, 'phys');
        if (def.id === 'warden') this.gain(u, 2);
      }
    }
  }

  private updateZones(dt: number) {
    const keep: Zone[] = [];
    for (const z of this.zones) {
      z.t += dt;
      const owner = z.ownerId != null ? this.unit(z.ownerId) : null;
      if (z.t >= z.delay) {
        this.emit({ k: 'boom', id: z.ownerId ?? -1 });
        for (const h of this.heroes) {
          if (h.alive && inZone(z, h.x, h.y)) this.damage(owner, h, z.dmg, z.type, { noBeam: true, scaled: true });
        }
        continue;
      }
      if (z.tied && (!owner || !owner.alive || !owner.cast)) continue;
      keep.push(z);
    }
    this.zones = keep;
  }

  // Hand each interruptible enemy cast to one party member.
  private assignInterrupts() {
    const casting = this.enemies.filter((e) => e.alive && e.cast && e.cast.interruptible);
    if (!casting.length) return;
    const busy = new Set<number>();
    for (const e of casting) if (e.cast!.assignee != null) busy.add(e.cast!.assignee);
    const kickers = this.heroes.filter((h) => {
      const ab = h.hero!.abilities.find((a) => a.interrupt);
      return h.alive && ab && (h.cds[ab.id] ?? 0) <= 0;
    });
    const mustExists = this.enemies.some(
      (e) => e.alive && e.engaged && e.enemy!.abilities.some((a) => a.importance === 2 && this.level >= (a.minLevel ?? 0)),
    );
    casting.sort((a, b) => b.cast!.importance! - a.cast!.importance!);
    for (const e of casting) {
      const c = e.cast!;
      if (c.assignee != null || c.total - c.t < 0.4) continue;
      const free = kickers.filter((h) => !busy.has(h.id));
      if (c.importance === 1 && mustExists && free.length < 2) continue;
      let best: Unit | null = null;
      for (const h of free) {
        const ab = h.hero!.abilities.find((a) => a.interrupt)!;
        const range = ab.range ?? 30;
        if (dist(h, e) > range + e.radius * 0.5) continue;
        if (range > 5 && !this.map.los(h.x, h.y, e.x, e.y)) continue;
        if (!best || h.lastInterrupt < best.lastInterrupt) best = h;
      }
      if (best) {
        c.assignee = best.id;
        c.assignedAt = this.time;
        busy.add(best.id);
      }
    }
  }

  private updateCombat() {
    for (const p of this.packs) {
      if (!p.engaged || p.cleared || p.units.some((u) => u.alive)) continue;
      p.cleared = true;
      this.emit({ k: 'clear', id: p.def.id });
      if (p.def.boss) {
        this.alert(p.def.lamp ?? p.def.name + ' is at rest');
        for (const h of this.heroes) if (!h.isPlayer || this.autoplay) h.jumpAt = this.time + 0.3 + h.slot * 0.15;
      }
    }
    this.inCombat = this.packs.some((p) => p.engaged && !p.cleared);
    if (this.packs.every((p) => p.cleared)) { this.finished = true; return; }
    if (!this.inCombat) {
      this.gather = null;
      for (const h of this.heroes) {
        if (h.alive) continue;
        h.alive = true;
        h.hp = h.maxHp * 0.4;
      }
    } else if (this.heroes.every((h) => !h.alive)) {
      this.wipe();
    }
  }

  private wipe() {
    this.alert('Driven back. The keepers return to their posts.');
    this.emit({ k: 'wipe' });
    this.zones = [];
    this.gather = null;
    this.map.restorePillars();
    let entry = this.packs[0].def.entry;
    for (const p of this.packs) {
      if (!p.engaged || p.cleared) continue;
      entry = p.def.entry;
      for (const u of p.units) if (u.summoned) { u.alive = false; this.units.delete(u.id); }
      this.enemies = this.enemies.filter((e) => !(e.summoned && e.packId === p.def.id));
      p.units = p.units.filter((u) => !u.summoned);
      for (const u of p.units) {
        u.alive = true; u.hp = u.maxHp; u.x = u.spawnX; u.y = u.spawnY;
        u.engaged = false; u.cast = null; u.auras = []; u.threat.clear(); u.cds = {};
        u.forcedT = 0; u.pending = null; u.flags = {}; u.targetId = -1; u.path = null;
      }
      p.engaged = false;
    }
    this.inCombat = false;
    this.heroes.forEach((h, i) => {
      h.alive = true; h.hp = h.maxHp; h.auras = []; h.cast = null; h.path = null;
      h.res = h.hero!.resStart; h.combo = 0; h.targetId = -1;
      h.x = entry.x - 2 + (i % 2) * 1.5; h.y = entry.y - 1.5 + Math.floor(i / 2) * 1.5;
    });
  }
}
