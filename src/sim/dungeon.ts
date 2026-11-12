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
  // [dx, dy, size] relative to the room centre
  pillars?: [number, number, number][];
  los?: boolean;
}

const ENCOUNTERS: Encounter[] = [
  { name: 'Pack 1', enemies: ['brute', 'brute', 'brute', 'hexer'] },
  { name: 'Pack 2', enemies: ['brute', 'brute', 'archer', 'shaman'] },
  { name: 'Krogg the Gatebreaker', boss: true, enemies: ['krogg'] },
  { name: 'Pack 3', enemies: ['brute', 'brute', 'hexer', 'hexer'], pillars: [[-8, -4, 2], [8, -4, 2], [-8, 4, 2], [8, 4, 2]], los: true },
  { name: 'Pack 4', enemies: ['overseer', 'archer', 'archer', 'shaman'] },
  { name: 'Matron Velisse', boss: true, enemies: ['velisse'] },
  { name: 'Pack 5', enemies: ['berserker', 'berserker', 'hexer', 'shaman'], pillars: [[-9, 0, 2], [9, 0, 2]] },
  { name: 'Pack 6', enemies: ['overseer', 'berserker', 'archer', 'archer'] },
  { name: 'Archon Sulmar', boss: true, enemies: ['sulmar'], pillars: [[-9, -5, 3], [9, -5, 3], [-9, 5, 3], [9, 5, 3]] },
];

// One straight hall, left to right. x runs along it, y is depth: small y is the back wall,
// FRONT is the open front edge. Rooms are split by walls that jut out from the back and
// leave a doorway along the front.
export const FRONT = 24;
const ROOM_DEPTH = 16;
const BOSS_DEPTH = 20;
const WALL = 3;
const DOOR = 6;

export function buildDungeon(): { map: GameMap; packs: PackDef[]; start: Vec } {
  const width = 4 + 14 + ENCOUNTERS.reduce((n, e) => n + WALL + (e.boss ? 34 : 28), 0) + 4;
  const map = new GameMap(width, FRONT + 2);
  map.carve(4, FRONT - ROOM_DEPTH, 18, FRONT);
  const start = { x: 11, y: FRONT - ROOM_DEPTH / 2 };
  const packs: PackDef[] = [];
  let right = 18;
  ENCOUNTERS.forEach((enc, id) => {
    const rw = enc.boss ? 34 : 28, rd = enc.boss ? BOSS_DEPTH : ROOM_DEPTH;
    const left = right + WALL;
    map.carve(right, FRONT - DOOR, left, FRONT);
    map.carve(left, FRONT - rd, left + rw, FRONT);
    const cx = left + rw / 2, cy = FRONT - rd / 2;
    for (const [dx, dy, s] of enc.pillars ?? []) map.addPillar(Math.round(cx + dx - s / 2), Math.round(cy + dy - s / 2), s, s);
    packs.push({
      id,
      name: enc.name,
      boss: !!enc.boss,
      enemies: enc.enemies,
      center: { x: cx, y: cy },
      entry: { x: right - 3, y: FRONT - DOOR / 2 },
      pullFrom: { x: right + WALL / 2, y: FRONT - DOOR / 2 },
      // behind the dividing wall, on the near side
      losSpot: enc.los ? { x: right - 1.5, y: FRONT - DOOR - 3.5 } : undefined,
    });
    right = left + rw;
  });
  return { map, packs, start };
}
