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
  test('the pull spot for the pillared pack is out of sight of the room', () => {
    const p = packs.find((k) => k.losSpot)!;
    expect(map.los(p.losSpot!.x, p.losSpot!.y, p.center.x, p.center.y)).toBe(false);
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
