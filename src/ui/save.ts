import { HEROES } from '../sim/heroes';

const KEY = 'fourfold-save-v1';

export interface Save {
  unlocked: number;
  bests: Record<string, { level: number; time: number }>;
  // hero id -> ability id -> click combo on a party frame, such as "L" or "S+R"
  bindings: Record<string, Record<string, string>>;
  // hero id -> ability id -> two key slots holding KeyboardEvent codes; '' is an empty slot
  keys: Record<string, Record<string, string[]>>;
  // hero id -> ability id -> a mouse button that casts it wherever the pointer is: 'M', 'X1' or 'X2'
  mouse: Record<string, Record<string, string>>;
  party: string[];
  slot: number;
  level: number;
  // sound: 0 to 1, and whether it is switched off
  volume: number;
  muted: boolean;
}

const BUTTONS = ['L', 'R', 'M', 'X1', 'X2'];
export const COMBOS = ['', 'S+', 'C+', 'A+'].flatMap((mod) => BUTTONS.map((b) => mod + b));
export const MOUSE = ['M', 'X1', 'X2'];

export function comboLabel(c: string) {
  const names: Record<string, string> = { L: 'Left click', R: 'Right click', M: 'Middle click', X1: 'Side back', X2: 'Side forward', S: 'Shift', C: 'Ctrl', A: 'Alt' };
  return c.split('+').map((p) => names[p]).join(' + ');
}

const buttonOf = (e: MouseEvent) => BUTTONS[[0, 2, 1, 3, 4][e.button] ?? 2];

export function comboOf(e: MouseEvent) {
  return (e.shiftKey ? 'S+' : e.ctrlKey ? 'C+' : e.altKey ? 'A+' : '') + buttonOf(e);
}

// The middle or side button an event came from, or '' for left and right.
export function mouseOf(e: MouseEvent) {
  const b = buttonOf(e);
  return MOUSE.includes(b) ? b : '';
}

// Keys the game itself uses; abilities cannot take them.
export const MOVE_KEYS = { left: ['KeyA', 'KeyQ'], right: ['KeyD', 'KeyE'], up: ['KeyW'], down: ['KeyS'] };
export const RESERVED: Record<string, string> = {
  KeyA: 'moving', KeyQ: 'moving', KeyD: 'moving', KeyE: 'moving', KeyW: 'moving', KeyS: 'moving',
  Space: 'jumping', Tab: 'targeting', Escape: 'the menu', KeyP: 'pausing', KeyM: 'sound',
};

export function keyLabel(code: string) {
  const names: Record<string, string> = {
    Backquote: '`', Minus: '-', Equal: '=', BracketLeft: '[', BracketRight: ']', Backslash: '\\', Semicolon: ';', Quote: '\'',
    Comma: ',', Period: '.', Slash: '/', Enter: 'Enter', ShiftLeft: 'Shift', ShiftRight: 'R Shift', ControlLeft: 'Ctrl', ControlRight: 'R Ctrl',
    AltLeft: 'Alt', AltRight: 'R Alt', CapsLock: 'Caps', ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→',
  };
  return names[code] ?? code.replace(/^Key|^Digit/, '').replace(/^Numpad/, 'Num ');
}

const MOUSE_SHORT: Record<string, string> = { M: 'Mid', X1: 'Mb4', X2: 'Mb5' };

// What an action button shows: its keys, then its mouse button.
export function bindLabel(s: Save, heroId: string, abId: string) {
  const parts = (s.keys[heroId]?.[abId] ?? []).filter(Boolean).map(keyLabel);
  const m = s.mouse[heroId]?.[abId];
  if (m) parts.push(MOUSE_SHORT[m]);
  return parts.join(' · ');
}

// 1 to 6 in order, with T also on the interrupt and ` also on the personal defensive (the fifth ability).
export function defaultKeys(heroId: string) {
  const out: Record<string, string[]> = {};
  HEROES[heroId].abilities.forEach((ab, i) => {
    out[ab.id] = ['Digit' + (i + 1), ab.interrupt ? 'KeyT' : i === 4 ? 'Backquote' : ''];
  });
  return out;
}

function defaults(): Save {
  const keys: Save['keys'] = {}, mouse: Save['mouse'] = {};
  for (const id in HEROES) { keys[id] = defaultKeys(id); mouse[id] = {}; }
  return {
    unlocked: 1,
    bests: {},
    bindings: {
      mender: { mend: 'L', quick: 'R', purify: 'S+L', ward: 'S+R' },
      bloomweaver: { vine: 'L', bark: 'R', dew: 'S+L', bramble: 'S+R' },
    },
    keys,
    mouse,
    party: ['warden', 'mender', 'duelist', 'ranger'],
    slot: 1,
    level: 1,
    volume: 0.6,
    muted: false,
  };
}

export function loadSave(): Save {
  const d = defaults();
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return d;
    const s = JSON.parse(raw);
    return {
      ...d, ...s,
      bindings: { ...d.bindings, ...(s.bindings ?? {}) },
      keys: { ...d.keys, ...(s.keys ?? {}) },
      mouse: { ...d.mouse, ...(s.mouse ?? {}) },
    };
  } catch {
    return d;
  }
}

export function storeSave(s: Save) {
  try {
    localStorage.setItem(KEY, JSON.stringify(s));
  } catch {
    // private windows may refuse storage; the game still runs
  }
}
