import { GameMap } from './map';
import type { Vec } from './types';

export interface PackDef {
  id: number;
  name: string;
  boss: boolean;
  enemies: string[];
  center: Vec;
  entry: Vec;
  pullFrom: Vec;
  losSpot?: Vec;
}

interface Encounter {
  name: string;
  boss?: boolean;
  enemies: string[];
  off: number;
  // [dx, dy, size] relative to the room centre
  pillars?: [number, number, number][];
  los?: boolean;
}

const ENCOUNTERS: Encounter[] = [
  { name: 'Pack 1', enemies: ['brute', 'brute', 'brute', 'hexer'], off: -9 },
  { name: 'Pack 2', enemies: ['brute', 'brute', 'archer', 'shaman'], off: 8 },
  { name: 'Krogg the Gatebreaker', boss: true, enemies: ['krogg'], off: 0 },
  { name: 'Pack 3', enemies: ['brute', 'brute', 'hexer', 'hexer'], off: -10, pillars: [[-8, -7, 2], [8, -7, 2], [-8, 7, 2], [8, 7, 2]], los: true },
  { name: 'Pack 4', enemies: ['overseer', 'archer', 'archer', 'shaman'], off: 9 },
  { name: 'Matron Velisse', boss: true, enemies: ['velisse'], off: 0 },
  { name: 'Pack 5', enemies: ['berserker', 'berserker', 'hexer', 'shaman'], off: 10, pillars: [[-9, 0, 2], [9, 0, 2]] },
  { name: 'Pack 6', enemies: ['overseer', 'berserker', 'archer', 'archer'], off: -8 },
  { name: 'Archon Sulmar', boss: true, enemies: ['sulmar'], off: 0, pillars: [[-9, -8, 3], [9, -8, 3], [-9, 8, 3], [9, 8, 3]] },
];

const MID = 42;
const CORRIDOR = 12;

export function buildDungeon(): { map: GameMap; packs: PackDef[]; start: Vec } {
  const width = 4 + 14 + ENCOUNTERS.reduce((n, e) => n + CORRIDOR + (e.boss ? 34 : 28), 0) + 4;
  const map = new GameMap(width, 84);
  map.carve(4, MID - 7, 18, MID + 7);
  const start = { x: 11, y: MID };
  const packs: PackDef[] = [];
  let right = 18, prevCy = MID;
  ENCOUNTERS.forEach((enc, id) => {
    const rw = enc.boss ? 34 : 28, rh = enc.boss ? 32 : 24;
    const cy = MID + enc.off;
    const left = right + CORRIDOR;
    const bend = right + CORRIDOR / 2;
    // corridor: out of the previous room, along the bend, into this room
    map.carve(right, prevCy - 3, bend + 3, prevCy + 3);
    map.carve(bend - 3, Math.min(prevCy, cy) - 3, bend + 3, Math.max(prevCy, cy) + 3);
    map.carve(bend - 3, cy - 3, left, cy + 3);
    map.carve(left, cy - rh / 2, left + rw, cy + rh / 2);
    const cx = left + rw / 2;
    for (const [dx, dy, s] of enc.pillars ?? []) map.addPillar(Math.round(cx + dx - s / 2), Math.round(cy + dy - s / 2), s, s);
    packs.push({
      id,
      name: enc.name,
      boss: !!enc.boss,
      enemies: enc.enemies,
      center: { x: cx, y: cy },
      entry: { x: bend, y: cy },
      pullFrom: { x: left - 2, y: cy },
      losSpot: enc.los ? { x: bend, y: prevCy } : undefined,
    });
    right = left + rw;
    prevCy = cy;
  });
  return { map, packs, start };
}
