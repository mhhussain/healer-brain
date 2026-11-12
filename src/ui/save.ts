const KEY = 'fourfold-save-v1';

export interface Save {
  unlocked: number;
  bests: Record<string, { level: number; time: number }>;
  // hero id -> ability id -> click combo such as "L" or "S+R"
  bindings: Record<string, Record<string, string>>;
  party: string[];
  slot: number;
  level: number;
}

export const COMBOS = ['L', 'R', 'M', 'S+L', 'S+R', 'S+M', 'C+L', 'C+R', 'C+M', 'A+L', 'A+R', 'A+M'];

export function comboLabel(c: string) {
  const names: Record<string, string> = { L: 'Left click', R: 'Right click', M: 'Middle click', S: 'Shift', C: 'Ctrl', A: 'Alt' };
  return c.split('+').map((p) => names[p]).join(' + ');
}

export function comboOf(e: MouseEvent) {
  const b = e.button === 0 ? 'L' : e.button === 2 ? 'R' : 'M';
  return (e.shiftKey ? 'S+' : e.ctrlKey ? 'C+' : e.altKey ? 'A+' : '') + b;
}

function defaults(): Save {
  return {
    unlocked: 1,
    bests: {},
    bindings: {
      mender: { mend: 'L', quick: 'R', purify: 'S+L', ward: 'S+R' },
      bloomweaver: { vine: 'L', bark: 'R', dew: 'S+L', bramble: 'S+R' },
    },
    party: ['warden', 'mender', 'duelist', 'ranger'],
    slot: 1,
    level: 1,
  };
}

export function loadSave(): Save {
  const d = defaults();
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return d;
    const s = JSON.parse(raw);
    return { ...d, ...s, bindings: { ...d.bindings, ...(s.bindings ?? {}) } };
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
