import type { World } from './world';

export type Role = 'tank' | 'healer' | 'dps';
export type DmgType = 'phys' | 'magic';
export interface Vec { x: number; y: number }

export interface Aura {
  id: string;
  name: string;
  t: number;
  dur: number;
  srcId: number;
  debuff?: boolean;
  dispellable?: boolean;
  taken?: number;
  takenPhys?: number;
  done?: number;
  haste?: number;
  absorb?: number;
  tickEvery?: number;
  tickTimer?: number;
  tickDmg?: number;
  tickHeal?: number;
}

export interface AbilityDef {
  id: string;
  name: string;
  desc: string;
  target: 'enemy' | 'ally' | 'self';
  range?: number;
  cost?: number;
  cast?: number;
  cd?: number;
  offGcd?: boolean;
  interrupt?: boolean;
  dispel?: boolean;
  usable?: (w: World, u: Unit) => string | null;
  // t is the caster itself for self-targeted abilities
  fire: (w: World, u: Unit, t: Unit) => void;
}

export interface HeroDef {
  id: string;
  name: string;
  // epithet, such as 'The Lamplighter'
  title: string;
  role: Role;
  sub: string;
  color: string;
  hp: number;
  resName: string;
  resMax: number;
  resStart: number;
  resColor: string;
  regen: number;
  gcd: number;
  auto: { dmg: number; interval: number; range: number };
  threatMult: number;
  howTo: string;
  abilities: AbilityDef[];
}

export interface EnemyAbility {
  id: string;
  name: string;
  cd: number;
  first?: number;
  minLevel?: number;
  cast: number;
  interruptible?: boolean;
  importance?: 1 | 2;
  tankBuster?: boolean;
  hide?: boolean;
  melee?: boolean;
  needsLos?: boolean;
  targeting: 'threat' | 'random' | 'self';
  ready?: (w: World, e: Unit) => boolean;
  start?: (w: World, e: Unit, t: Unit | null, c: Cast) => void;
  tick?: (w: World, e: Unit, c: Cast) => void;
  finish?: (w: World, e: Unit, t: Unit | null) => void;
}

export interface EnemyDef {
  id: string;
  name: string;
  letter: string;
  hp: number;
  boss?: boolean;
  elite?: boolean;
  radius: number;
  range: number;
  auto?: { dmg: number; interval: number; type: DmgType };
  priority: number;
  frontal?: boolean;
  abilities: EnemyAbility[];
  passive?: (w: World, e: Unit) => void;
  onDeath?: (w: World, e: Unit) => void;
}

export interface Cast {
  name: string;
  t: number;
  total: number;
  targetId: number;
  abIdx?: number;
  ab?: EnemyAbility;
  interruptible?: boolean;
  importance?: number;
  assignee?: number;
  assignedAt?: number;
  tickTimer?: number;
  dir?: number;
}

export interface AIState {
  reaction: number;
  escape: Vec | null;
  pos: Vec | null;
  posT: number;
  tankSpot: Vec | null;
  hide: Vec | null;
  // id of the pack whose room the tank has already gone into
  entered: number;
  // walked last tick; goals use it so a hero does not start and stop on a threshold
  moving: boolean;
}

export interface Stats { dmg: number; heal: number; interrupts: number; dispels: number; deaths: number }

export interface Unit {
  id: number;
  team: 'hero' | 'enemy';
  name: string;
  x: number;
  y: number;
  // height off the floor; jumping is cosmetic
  z: number;
  // where the unit was one tick ago, so the renderer can draw between ticks
  px: number;
  py: number;
  pz: number;
  vz: number;
  jumpAt: number;
  facing: number;
  radius: number;
  speed: number;
  hp: number;
  maxHp: number;
  alive: boolean;
  res: number;
  resMax: number;
  combo: number;
  targetId: number;
  cast: Cast | null;
  gcd: number;
  cds: Record<string, number>;
  auras: Aura[];
  autoTimer: number;
  moved: boolean;
  moveDir: number;
  lastMoveT: number;
  stats: Stats;
  path: Vec[] | null;
  pathGoal: Vec | null;
  pathAge: number;
  // hero only
  hero?: HeroDef;
  isPlayer: boolean;
  slot: number;
  ai?: AIState;
  lastInterrupt: number;
  rageGate: number;
  // enemy only
  enemy?: EnemyDef;
  packId: number;
  engaged: boolean;
  spawnX: number;
  spawnY: number;
  threat: Map<number, number>;
  forcedId: number;
  forcedT: number;
  busy: number;
  pending: { ab: string; targetId: number } | null;
  slotAngle: number;
  summoned: boolean;
  aggroT: number;
  flags: Record<string, boolean>;
}
