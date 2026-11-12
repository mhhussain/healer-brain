import type { EnemyAbility, EnemyDef, Unit } from './types';
import type { World } from './world';

const dist = (a: Unit, b: Unit) => Math.hypot(a.x - b.x, a.y - b.y);

function cone(name: string, id: string, cd: number, first: number, cast: number, half: number, range: number, dmg: number): EnemyAbility {
  return {
    id, name, cd, first, cast, targeting: 'threat',
    start: (w, e, t, c) => {
      c.dir = t ? Math.atan2(t.y - e.y, t.x - e.x) : e.facing;
      w.zone({ kind: 'cone', x: e.x, y: e.y, r: range, dir: c.dir, half, delay: cast, dmg, type: 'phys', ownerId: e.id, tied: true });
    },
  };
}

function buster(name: string, id: string, cd: number, first: number, dmg: number, minLevel?: number): EnemyAbility {
  return {
    id, name, cd, first, cast: 1.5, minLevel, targeting: 'threat', tankBuster: true, melee: true,
    finish: (w, e, t) => { if (t && dist(e, t) <= 5) w.damage(e, t, dmg, 'phys'); },
  };
}

function circlesUnder(w: World, e: Unit, targets: Unit[], r: number, delay: number, dmg: number) {
  for (const h of targets) w.zone({ kind: 'circle', x: h.x, y: h.y, r, delay, dmg, type: 'magic', ownerId: e.id });
}

function enrage(below: (w: World) => number) {
  return (w: World, e: Unit) => {
    if (e.hp / e.maxHp < below(w) && !w.hasAura(e, 'enrage')) {
      w.addAura(e, { id: 'enrage', name: 'Fervour', dur: 9999, srcId: e.id, done: 1.25, haste: 1.5 });
      w.text(e.x, e.y, 'Fervour', '#ef5d4a');
    }
  };
}

export const ENEMIES: Record<string, EnemyDef> = {
  brute: {
    id: 'brute', name: 'Drowned Porter', letter: 'B', hp: 2300, radius: 0.7, range: 2.3, priority: 1,
    auto: { dmg: 46, interval: 1.5, type: 'phys' },
    abilities: [buster('Heavy Load', 'crush', 10, 5, 240, 3)],
  },
  hexer: {
    id: 'hexer', name: 'Brine Cantor', letter: 'H', hp: 1700, radius: 0.6, range: 24, priority: 2,
    abilities: [
      {
        id: 'wither', name: 'Withering Verse', cd: 12, first: 6, cast: 2.5, minLevel: 3, interruptible: true, importance: 2,
        targeting: 'random', needsLos: true,
        finish: (w, e, t) => {
          if (t) w.addAura(t, { id: 'wither', name: 'Withering Verse', dur: 10, srcId: e.id, debuff: true, dispellable: true, tickEvery: 1, tickDmg: 38 });
        },
      },
      {
        id: 'darkbolt', name: 'Sour Note', cd: 2, cast: 2.5, interruptible: true, importance: 1,
        targeting: 'random', needsLos: true,
        finish: (w, e, t) => { if (t) w.damage(e, t, 165, 'magic'); },
      },
    ],
  },
  archer: {
    id: 'archer', name: 'Net-Brother', letter: 'A', hp: 1700, radius: 0.6, range: 24, priority: 1,
    auto: { dmg: 58, interval: 2, type: 'phys' },
    abilities: [
      {
        id: 'arrowrain', name: 'Rain of Hooks', cd: 9, cast: 0, minLevel: 3, targeting: 'random',
        finish: (w, e, t) => { if (t) circlesUnder(w, e, [t], 3.5, 1.6, 210); },
      },
    ],
  },
  shaman: {
    id: 'shaman', name: 'Tide Almoner', letter: 'S', hp: 1500, radius: 0.6, range: 24, priority: 3,
    auto: { dmg: 34, interval: 2, type: 'magic' },
    abilities: [
      {
        id: 'restore', name: 'Alms', cd: 8, first: 5, cast: 2.5, interruptible: true, importance: 2, targeting: 'self',
        ready: (w, e) => w.engagedEnemies().some((o) => o.hp < o.maxHp * 0.85),
        finish: (w, e) => {
          let best: Unit | null = null;
          for (const o of w.engagedEnemies()) if (!best || o.hp / o.maxHp < best.hp / best.maxHp) best = o;
          if (best) {
            const amt = Math.min(best.maxHp - best.hp, best.maxHp * (w.level >= 3 ? 0.35 : 0.2));
            best.hp += amt;
            w.text(best.x, best.y, '+' + Math.round(amt), '#8fe6b4');
            w.beam(e, best, '#8fe6b4');
          }
        },
      },
    ],
  },
  berserker: {
    id: 'berserker', name: 'Penitent', letter: 'Z', hp: 2100, radius: 0.7, range: 2.3, priority: 1,
    auto: { dmg: 38, interval: 1, type: 'phys' },
    abilities: [],
    passive: enrage((w) => (w.level >= 3 ? 0.5 : 0.3)),
  },
  overseer: {
    id: 'overseer', name: 'The Prior', letter: 'O', hp: 4600, elite: true, radius: 0.95, range: 2.3, priority: 1, frontal: true,
    auto: { dmg: 68, interval: 1.6, type: 'phys' },
    abilities: [cone('Banner Sweep', 'sweepcut', 9, 5, 2, 0.87, 9, 380)],
  },

  krogg: {
    id: 'krogg', name: 'Brother Krogg', letter: 'K', hp: 27000, boss: true, radius: 1.5, range: 2.6, priority: 0, frontal: true,
    auto: { dmg: 100, interval: 1.6, type: 'phys' },
    abilities: [
      buster('The Great Key', 'skullcrack', 12, 6, 700),
      cone('Chain Sweep', 'rendingsweep', 15, 10, 2.2, 1.05, 11, 480),
      {
        id: 'tremor', name: 'Falling Stones', cd: 10, first: 4, cast: 0, minLevel: 6, targeting: 'self',
        finish: (w, e) => circlesUnder(w, e, w.randomHeroes(2), 4, 1.6, 300),
      },
    ],
    passive: (w, e) => {
      if (e.hp / e.maxHp < 0.3 && !w.hasAura(e, 'frenzy')) {
        w.addAura(e, { id: 'frenzy', name: 'None Shall Pass', dur: 9999, srcId: e.id, haste: 1.3 });
        w.alert('Brother Krogg bars the gate. None shall pass!');
      }
    },
  },

  velisse: {
    id: 'velisse', name: 'Sister Velisse', letter: 'V', hp: 23000, boss: true, radius: 1.4, range: 2.6, priority: 0,
    auto: { dmg: 82, interval: 1.6, type: 'phys' },
    abilities: [
      {
        id: 'broodmending', name: 'Bedside Manner', cd: 20, first: 14, cast: 3, interruptible: true, importance: 2, targeting: 'self',
        finish: (w, e) => {
          const amt = Math.min(e.maxHp - e.hp, e.maxHp * 0.1);
          e.hp += amt;
          w.text(e.x, e.y, '+' + Math.round(amt), '#8fe6b4');
        },
      },
      {
        id: 'brood', name: 'Wake the Ward', cd: 25, first: 8, cast: 0, targeting: 'self',
        finish: (w, e) => {
          w.alert('The brinelings wake');
          for (let i = 0; i < 3; i++) {
            const a = w.rng() * Math.PI * 2;
            let x = e.x + Math.cos(a) * 4, y = e.y + Math.sin(a) * 4;
            if (!w.map.canStand(x, y)) { x = e.x; y = e.y; }
            const h = w.spawnEnemy('hatchling', x, y, e.packId, true);
            const t = w.randomHero();
            if (t) w.addThreat(h, t.id, 30);
          }
        },
      },
    ],
  },
  hatchling: {
    id: 'hatchling', name: 'Brineling', letter: 'h', hp: 480, radius: 0.5, range: 2.3, priority: 4,
    auto: { dmg: 28, interval: 1.2, type: 'phys' },
    abilities: [
      {
        id: 'venombolt', name: 'Brine Spit', cd: 2.5, cast: 2, interruptible: true, importance: 1, targeting: 'random', needsLos: true,
        finish: (w, e, t) => { if (t) w.damage(e, t, 90, 'magic'); },
      },
    ],
    onDeath: (w, e) => {
      if (w.level >= 6) w.zone({ kind: 'circle', x: e.x, y: e.y, r: 3.5, delay: 1.5, dmg: 250, type: 'magic' });
    },
  },

  sulmar: {
    id: 'sulmar', name: 'Abbot Sulmar', letter: 'A', hp: 28000, boss: true, radius: 1.5, range: 2.6, priority: 0,
    auto: { dmg: 88, interval: 1.7, type: 'phys' },
    abilities: [
      {
        id: 'annihilation', name: 'The Last Toll', cd: 1, cast: 5, hide: true, targeting: 'self',
        ready: (_w, e) => (e.hp / e.maxHp <= 0.66 && !e.flags.a1) || (e.hp / e.maxHp <= 0.33 && !e.flags.a2),
        start: (w, e) => {
          if (!e.flags.a1) e.flags.a1 = true; else e.flags.a2 = true;
          w.alert('The Last Toll. Hide behind a pillar!');
        },
        finish: (w, e) => {
          const used = new Set<number>();
          for (const h of w.heroes) {
            if (!h.alive) continue;
            const p = w.map.pillarBlocking(e.x, e.y, h.x, h.y);
            if (w.map.los(e.x, e.y, h.x, h.y)) w.damage(e, h, h.maxHp * 0.9, 'magic', { raw: true });
            else if (p >= 0) used.add(p);
          }
          w.ring(e.x, e.y, 30, '#f0b54a');
          if (w.level >= 6) for (const p of used) w.map.destroyPillar(p);
        },
      },
      {
        id: 'dirge', name: 'Dirge', cd: 20, first: 10, cast: 5, targeting: 'self',
        tick: (w, e) => { for (const h of w.aliveHeroes()) w.damage(e, h, 58, 'magic', { noBeam: true }); },
      },
      {
        id: 'ashfall', name: 'Saltfall', cd: 11, first: 5, cast: 0, targeting: 'self',
        finish: (w, e) => circlesUnder(w, e, w.aliveHeroes(), 3.5, 1.6, 320),
      },
      {
        id: 'brand', name: 'Brine Brand', cd: 17, first: 8, cast: 0, targeting: 'self',
        finish: (w, e) => {
          for (const h of w.randomHeroes(2)) {
            w.addAura(h, { id: 'brand', name: 'Brine Brand', dur: 12, srcId: e.id, debuff: true, dispellable: true, tickEvery: 1, tickDmg: 42 });
          }
        },
      },
    ],
  },
};
