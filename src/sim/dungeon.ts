import { GameMap } from './map';
import type { Vec } from './types';

export interface PackDef {
  id: number;
  name: string;
  boss: boolean;
  enemies: string[];
  // 0 Sea Gate, 1 Infirmary, 2 Nave
  zone: number;
  // boss rooms: the line shown when the lamp is lit
  lamp?: string;
  center: Vec;
  entry: Vec;
  pullFrom: Vec;
  // where the tank plants its feet: well inside the room, so the whole party follows it in
  stand: Vec;
  // the doorway into the room runs from doorX to roomLeft
  doorX: number;
  roomLeft: number;
}

interface Encounter {
  name: string;
  boss?: boolean;
  lamp?: string;
  enemies: string[];
  // [dx, dy, size] relative to the room centre
  pillars?: [number, number, number][];
}

const ENCOUNTERS: Encounter[] = [
  { name: 'The Cloister Walk', enemies: ['brute', 'brute', 'brute', 'hexer'] },
  { name: 'The Wet Stair', enemies: ['brute', 'brute', 'archer', 'shaman'] },
  { name: 'Brother Krogg', boss: true, lamp: 'The Gate Lamp burns. Brother Krogg sets down his keys.', enemies: ['krogg'] },
  { name: 'The Undercroft', enemies: ['brute', 'brute', 'hexer', 'hexer'], pillars: [[-8, -4, 2], [8, -4, 2], [-8, 4, 2], [8, 4, 2]] },
  { name: 'The Dispensary', enemies: ['overseer', 'archer', 'archer', 'shaman'] },
  { name: 'Sister Velisse', boss: true, lamp: 'The Ward Lamp burns. Sister Velisse\'s little ones are quiet.', enemies: ['velisse'] },
  { name: 'The Choir Stalls', enemies: ['berserker', 'berserker', 'hexer', 'shaman'], pillars: [[-9, 0, 2], [9, 0, 2]] },
  { name: 'The Bell Stair', enemies: ['overseer', 'berserker', 'archer', 'archer'] },
  { name: 'Abbot Sulmar', boss: true, lamp: 'The Bell Lamp burns. The Abbot lets go of the rope.', enemies: ['sulmar'], pillars: [[-9, -5, 3], [9, -5, 3], [-9, 5, 3], [9, 5, 3]] },
];

// One straight hall, left to right. x runs along it, y is depth: small y is the back wall,
// FRONT is the open front edge. Rooms are split by walls that jut out from the back and
// leave a doorway along the front.
export const FRONT = 24;
export const DOOR_DEPTH = 6;
const ROOM_DEPTH = 16;
const BOSS_DEPTH = 20;
const WALL = 3;
const DOOR = DOOR_DEPTH;

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
      zone: Math.floor(id / 3),
      lamp: enc.lamp,
      center: { x: cx, y: cy },
      entry: { x: right - 3, y: FRONT - DOOR / 2 },
      pullFrom: { x: right + WALL / 2, y: FRONT - DOOR / 2 },
      stand: { x: left + (enc.boss ? 10 : 8), y: cy + 1 },
      doorX: right,
      roomLeft: left,
    });
    right = left + rw;
  });
  return { map, packs, start };
}
