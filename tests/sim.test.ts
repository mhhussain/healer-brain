import { describe, expect, test } from 'vitest';
import { buildDungeon } from '../src/sim/dungeon';
import { DT, World } from '../src/sim/world';

function run(party: string[], level: number, minutes = 30, seed = 1) {
  const w = new World({ level, party, playerSlot: 0, seed, autoplay: true });
  while (!w.finished && w.time < minutes * 60) w.tick(DT);
  return w;
}

describe('map', () => {
  const { map, packs, start } = buildDungeon();
  test('every pack is reachable from the start', () => {
    for (const p of packs) expect(map.findPath(start.x, start.y, p.center.x, p.center.y)).not.toBeNull();
  });
  test('pillars block line of sight until destroyed', () => {
    const p = map.pillars[map.pillars.length - 1];
    const cx = p.x + p.w / 2, cy = p.y + p.h / 2;
    expect(map.los(cx - 4, cy, cx + 4, cy)).toBe(false);
    expect(map.pillarBlocking(cx - 4, cy, cx + 4, cy)).toBe(p.id);
    map.destroyPillar(p.id);
    expect(map.los(cx - 4, cy, cx + 4, cy)).toBe(true);
  });
  test('the tank has somewhere to stand inside every room', () => {
    for (const p of packs) {
      expect(map.canStand(p.stand.x, p.stand.y)).toBe(true);
      expect(p.stand.x).toBeGreaterThan(p.roomLeft + 5);
    }
  });
});

describe('all-AI runs', () => {
  const healers = ['mender', 'bloomweaver'];
  const dps = [['duelist', 'ranger'], ['duelist', 'pyromancer'], ['ranger', 'pyromancer'], ['pyromancer', 'pyromancer']];
  for (const h of healers) for (const d of dps) {
    test(`warden + ${h} + ${d.join(' + ')} times level 1`, () => {
      const w = run(['warden', h, ...d], 1);
      expect(w.finished).toBe(true);
      expect(w.timed()).toBe(true);
      expect(w.deaths).toBeLessThanOrEqual(1);
    });
  }
  test('interrupts and dispels are used', () => {
    const w = run(['warden', 'mender', 'duelist', 'ranger'], 3);
    expect(w.heroes.reduce((n, h) => n + h.stats.interrupts, 0)).toBeGreaterThan(10);
    expect(w.heroes[1].stats.dispels).toBeGreaterThan(0);
  });
  test('a hopeless level wipes and resets without breaking', () => {
    const w = run(['warden', 'mender', 'duelist', 'ranger'], 40, 6);
    expect(w.finished).toBe(false);
    expect(w.deaths).toBeGreaterThan(3);
    expect(w.packs[0].units.every((u) => u.hp > 0 || !u.alive)).toBe(true);
    expect(w.totalTime()).toBeGreaterThan(w.elapsed);
  });
});

describe('going in', () => {
  test('the whole party fights inside the room, not on its threshold', () => {
    const w = new World({ level: 1, party: ['warden', 'mender', 'ranger', 'pyromancer'], playerSlot: 0, seed: 4, autoplay: true });
    let ticks = 0, outside = 0;
    while (!w.finished && w.time < 30 * 60) {
      w.tick(DT);
      const p = w.packs.find((k) => k.engaged && !k.cleared);
      if (!p || w.time - p.engagedAt < 6) continue;
      for (const h of w.heroes) { ticks++; if (h.alive && h.x < p.def.roomLeft) outside++; }
    }
    expect(w.finished).toBe(true);
    expect(outside / ticks).toBeLessThan(0.02);
  });

  test('a taunt shows on the enemy as a timed debuff', () => {
    const w = new World({ level: 1, party: ['warden', 'mender', 'duelist', 'ranger'], playerSlot: 0, seed: 1 });
    const e = w.enemies[0];
    w.player.x = e.x - 10; w.player.y = e.y;
    w.player.targetId = e.id;
    w.press(2);
    w.tick(DT);
    const a = e.auras.find((k) => k.id === 'taunt')!;
    expect(a.debuff).toBe(true);
    expect(a.srcId).toBe(w.player.id);
    for (let i = 0; i < 60 * 4 + 2; i++) w.tick(DT);
    expect(w.hasAura(e, 'taunt')).toBe(false);
  });
});

describe('player input', () => {
  test('abilities with no target use the tank\'s target, and moving cancels a cast', () => {
    const w = new World({ level: 1, party: ['warden', 'mender', 'duelist', 'pyromancer'], playerSlot: 3, seed: 3, autoplay: true });
    const p = w.player;
    // let the AI walk the hero into the first fight, then take over
    const inReach = () => {
      const t = w.unit(w.heroes[0].targetId);
      return !!t && t.alive && t.team === 'enemy' && Math.hypot(t.x - p.x, t.y - p.y) < 26 && w.map.los(p.x, p.y, t.x, t.y);
    };
    while (!(w.inCombat && w.canAttack() && inReach() && !p.cast && p.gcd <= 0 && !p.moved) && w.time < 120) w.tick(DT);
    w.autoplay = false;
    p.targetId = -1;
    w.press(0);
    for (let i = 0; i < 10; i++) w.tick(DT);
    expect(w.error?.text).toBeUndefined();
    expect(p.cast?.name).toBe('Wickfire');
    expect(p.targetId).toBe(w.heroes[0].targetId);
    w.input.my = 1;
    w.tick(DT); w.tick(DT);
    w.input.my = 0;
    expect(p.cast).toBeNull();
  });

  test('jumping is cosmetic and lands again', () => {
    const w = new World({ level: 1, party: ['warden', 'mender', 'duelist', 'ranger'], playerSlot: 2, seed: 2 });
    const p = w.player;
    const { x, y } = p;
    w.jump();
    w.tick(DT);
    expect(p.z).toBeGreaterThan(0);
    w.jump();
    for (let i = 0; i < 60; i++) w.tick(DT);
    expect(p.z).toBe(0);
    expect([p.x, p.y]).toEqual([x, y]);
  });

  test('a healer ability lands on the ally under the mouse', () => {
    const w = new World({ level: 1, party: ['warden', 'bloomweaver', 'duelist', 'ranger'], playerSlot: 1, seed: 2 });
    const tank = w.heroes[0];
    w.hoverAllyId = tank.id;
    w.press(0);
    w.tick(DT);
    expect(w.hasAura(tank, 'vine')).toBe(true);
    w.hoverAllyId = -1;
    for (let i = 0; i < 100; i++) w.tick(DT);
    w.press(0);
    w.tick(DT);
    expect(w.hasAura(w.player, 'vine')).toBe(true);
  });
});
