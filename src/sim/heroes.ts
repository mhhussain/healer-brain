import type { HeroDef, Unit } from './types';
import type { World } from './world';

const MELEE = 3.2;

function dispel(w: World, u: Unit, t: Unit) {
  w.dispel(u, t);
}

export const HEROES: Record<string, HeroDef> = {
  warden: {
    id: 'warden', name: 'Hale Dunmarrow', title: 'The Gatewarden', role: 'tank', sub: 'Tank', color: '#6fa0d6',
    hp: 2400, resName: 'Grit', resMax: 100, resStart: 0, resColor: '#c9744a', regen: 0, gcd: 1.5,
    auto: { dmg: 40, interval: 1.8, range: MELEE }, threatMult: 4,
    howTo: 'Pull with Pilot\'s Hail, keep every enemy on you with Mooring Sweep, and save grit so Brace is up for telegraphed heavy hits.',
    abilities: [
      {
        id: 'strike', name: 'Bulwark Blow', target: 'enemy', range: MELEE, cd: 4.5,
        desc: '110 damage. +8 grit.',
        fire: (w, u, t) => { w.damage(u, t, 110, 'phys'); w.gain(u, 8); },
      },
      {
        id: 'sweep', name: 'Mooring Sweep', target: 'self',
        desc: '50 damage to every enemy within 6 m. +1 grit per enemy hit, up to 5.',
        fire: (w, u) => {
          const hit = w.enemiesNear(u.x, u.y, 6);
          for (const e of hit) w.damage(u, e, 50, 'phys');
          w.gain(u, Math.min(5, hit.length));
          w.ring(u.x, u.y, 6, u.hero!.color);
        },
      },
      {
        id: 'challenge', name: "Pilot's Hail", target: 'enemy', cd: 8, offGcd: true,
        desc: 'The target attacks you for 4 s and you go to the top of its threat. Works at range: use it to pull.',
        fire: (w, u, t) => w.taunt(u, t),
      },
      {
        id: 'bash', name: 'Breakwater Bash', target: 'enemy', range: MELEE, cd: 15, offGcd: true, interrupt: true,
        desc: 'Silence the target\'s cast.',
        fire: (w, u, t) => w.interrupt(u, t),
      },
      {
        id: 'brace', name: 'Brace', target: 'self', cost: 40, offGcd: true,
        desc: 'Take 50% less physical damage for 6 s.',
        fire: (w, u) => w.addAura(u, { id: 'brace', name: 'Brace', dur: 6, srcId: u.id, takenPhys: 0.5 }),
      },
      {
        id: 'unbreakable', name: 'Seawall', target: 'self', cd: 120, offGcd: true,
        desc: 'Take 40% less damage of all kinds for 10 s and heal 20% of maximum health.',
        fire: (w, u) => {
          w.addAura(u, { id: 'unbreakable', name: 'Seawall', dur: 10, srcId: u.id, taken: 0.6 });
          w.heal(u, u, u.maxHp * 0.2);
        },
      },
    ],
  },

  mender: {
    id: 'mender', name: 'Sister Wren', title: 'The Lamplighter', role: 'healer', sub: 'Direct healer', color: '#5fd6c6',
    hp: 1200, resName: 'Lamplight', resMax: 1000, resStart: 1000, resColor: '#e0a93c', regen: 8, gcd: 1.5,
    auto: { dmg: 22, interval: 2, range: 30 }, threatMult: 1,
    howTo: 'React to damage: Warm Light for efficiency, Spark for emergencies. Rebuke when nobody needs healing to win back lamplight.',
    abilities: [
      {
        id: 'mend', name: 'Warm Light', target: 'ally', cost: 40, cast: 2,
        desc: 'Heal 420. Also heals the most injured other ally within 10 m of the target for 30%.',
        fire: (w, u, t) => {
          w.heal(u, t, 420);
          let best: Unit | null = null;
          for (const h of w.heroes) {
            if (h === t || !h.alive || h.hp >= h.maxHp || Math.hypot(h.x - t.x, h.y - t.y) > 10) continue;
            if (!best || h.hp / h.maxHp < best.hp / best.maxHp) best = h;
          }
          if (best) w.heal(u, best, 126);
        },
      },
      {
        id: 'quick', name: 'Spark', target: 'ally', cost: 90,
        desc: 'Instant. Heal 330.',
        fire: (w, u, t) => { w.heal(u, t, 330); },
      },
      {
        id: 'rebuke', name: 'Rebuke', target: 'enemy', cast: 1.5,
        desc: '70 damage. Restores 15 lamplight.',
        fire: (w, u, t) => { w.damage(u, t, 70, 'magic'); w.gain(u, 15); },
      },
      {
        id: 'purify', name: 'Absolve', target: 'ally', cost: 30, cd: 8, dispel: true,
        desc: 'Cleanse an ally of every curse that can be lifted.',
        fire: dispel,
      },
      {
        id: 'ward', name: 'Lantern Ward', target: 'ally', cd: 45, offGcd: true,
        desc: 'An ally takes 40% less damage for 6 s.',
        fire: (w, u, t) => w.addAura(t, { id: 'ward', name: 'Lantern Ward', dur: 6, srcId: u.id, taken: 0.6 }),
      },
      {
        id: 'sanctuary', name: 'Sanctuary', target: 'self', cd: 120,
        desc: 'Heal every ally for 300 now and 600 more over 8 s.',
        fire: (w, u) => {
          for (const h of w.heroes) {
            if (!h.alive) continue;
            w.heal(u, h, 300);
            w.addAura(h, { id: 'sanctuary', name: 'Sanctuary', dur: 8, srcId: u.id, tickEvery: 2, tickHeal: 150 });
          }
        },
      },
    ],
  },

  bloomweaver: {
    id: 'bloomweaver', name: 'Old Maren', title: 'The Kelpwife', role: 'healer', sub: 'Heal-over-time and shield healer', color: '#7fbf6a',
    hp: 1200, resName: 'Tidewater', resMax: 1000, resStart: 1000, resColor: '#3f9fb8', regen: 12, gcd: 1.5,
    auto: { dmg: 22, interval: 2, range: 30 }, threatMult: 1,
    howTo: 'Heal ahead of the damage: keep Mending Kelp rolling, shield whoever is about to be hit, and Kelp Bloom when several strands are out.',
    abilities: [
      {
        id: 'vine', name: 'Mending Kelp', target: 'ally', cost: 30,
        desc: 'Heal 60 every 2 s for 14 s. One per ally; recasting refreshes it.',
        fire: (w, u, t) => w.addAura(t, { id: 'vine', name: 'Mending Kelp', dur: 14, srcId: u.id, tickEvery: 2, tickHeal: 60 }),
      },
      {
        id: 'bark', name: 'Shell Ward', target: 'ally', cost: 42, cd: 3,
        desc: 'Shield an ally against the next 350 damage, for 12 s.',
        fire: (w, u, t) => {
          w.addAura(t, { id: 'bark', name: 'Shell Ward', dur: 12, srcId: u.id, absorb: 350 });
          if (w.hasAura(u, 'tide')) u.cds.bark = 0;
        },
      },
      {
        id: 'bloom', name: 'Kelp Bloom', target: 'self', cost: 45, cd: 10,
        desc: 'Every ally with Mending Kelp is healed for 240 at once. The kelp keeps working.',
        fire: (w, u) => {
          for (const h of w.heroes) if (h.alive && w.hasAura(h, 'vine')) w.heal(u, h, 240);
        },
      },
      {
        id: 'dew', name: 'Salt Rinse', target: 'ally', cost: 30, cd: 8, dispel: true,
        desc: 'Cleanse an ally of every curse that can be lifted.',
        fire: dispel,
      },
      {
        id: 'bramble', name: 'Barnacle Guard', target: 'ally', cd: 45, offGcd: true,
        desc: 'An ally takes 30% less damage for 8 s.',
        fire: (w, u, t) => w.addAura(t, { id: 'bramble', name: 'Barnacle Guard', dur: 8, srcId: u.id, taken: 0.7 }),
      },
      {
        id: 'tide', name: 'Green Tide', target: 'self', cd: 120,
        desc: 'Put Mending Kelp on every ally. For 10 s kelp heals twice as fast and Shell Ward has no cooldown.',
        fire: (w, u) => {
          w.addAura(u, { id: 'tide', name: 'Green Tide', dur: 10, srcId: u.id });
          u.cds.bark = 0;
          for (const h of w.heroes) {
            if (h.alive) w.addAura(h, { id: 'vine', name: 'Mending Kelp', dur: 14, srcId: u.id, tickEvery: 2, tickHeal: 60 });
          }
        },
      },
    ],
  },

  duelist: {
    id: 'duelist', name: 'Corvin Ashby', title: 'The Wrecker', role: 'dps', sub: 'Melee damage', color: '#d0668f',
    hp: 1300, resName: 'Nerve', resMax: 100, resStart: 100, resColor: '#d9b84a', regen: 12, gcd: 1,
    auto: { dmg: 55, interval: 1.2, range: MELEE }, threatMult: 1,
    howTo: 'Build combo points with Cutlass or Round Turn, spend five on Final Cut, and stay behind the enemy, out of frontals.',
    abilities: [
      {
        id: 'slash', name: 'Cutlass', target: 'enemy', range: MELEE, cost: 40,
        desc: '95 damage. +1 combo point.',
        fire: (w, u, t) => { w.damage(u, t, 95, 'phys'); u.combo = Math.min(5, u.combo + 1); },
      },
      {
        id: 'whirl', name: 'Round Turn', target: 'self', cost: 45,
        desc: '55 damage to every enemy within 5 m. +1 combo point.',
        fire: (w, u) => {
          for (const e of w.enemiesNear(u.x, u.y, 5)) w.damage(u, e, 55, 'phys');
          u.combo = Math.min(5, u.combo + 1);
          w.ring(u.x, u.y, 5, u.hero!.color);
        },
      },
      {
        id: 'thrust', name: 'Final Cut', target: 'enemy', range: MELEE, cost: 25,
        desc: 'Spends all combo points. 70 damage per point.',
        usable: (_w, u) => (u.combo > 0 ? null : 'No combo points'),
        fire: (w, u, t) => { const c = u.combo; u.combo = 0; w.damage(u, t, 70 * c, 'phys'); },
      },
      {
        id: 'jab', name: 'Hilt Jab', target: 'enemy', range: MELEE, cd: 15, offGcd: true, interrupt: true,
        desc: 'Silence the target\'s cast.',
        fire: (w, u, t) => w.interrupt(u, t),
      },
      {
        id: 'riposte', name: 'Riposte', target: 'self', cd: 60, offGcd: true,
        desc: 'Take 50% less damage for 5 s.',
        fire: (w, u) => w.addAura(u, { id: 'riposte', name: 'Riposte', dur: 5, srcId: u.id, taken: 0.5 }),
      },
      {
        id: 'bloodrush', name: "Wrecker's Luck", target: 'self', cd: 120, offGcd: true,
        desc: 'For 12 s, nerve returns twice as fast and you deal 20% more damage.',
        fire: (w, u) => w.addAura(u, { id: 'bloodrush', name: "Wrecker's Luck", dur: 12, srcId: u.id, done: 1.2 }),
      },
    ],
  },

  ranger: {
    id: 'ranger', name: 'Isolde Fenn', title: 'The Harpooner', role: 'dps', sub: 'Ranged damage', color: '#e6b93c',
    hp: 1200, resName: 'Focus', resMax: 100, resStart: 100, resColor: '#8fb8c9', regen: 4, gcd: 1.5,
    auto: { dmg: 50, interval: 1.6, range: 30 }, threatMult: 1,
    howTo: 'Everything works on the move. Snap Throw builds focus; spend it on Whaler\'s Lance, or Barb Scatter against groups.',
    abilities: [
      {
        id: 'quickshot', name: 'Snap Throw', target: 'enemy',
        desc: '60 damage. +15 focus.',
        fire: (w, u, t) => { w.damage(u, t, 60, 'phys'); w.gain(u, w.hasAura(u, 'hawk') ? 30 : 15); },
      },
      {
        id: 'piercing', name: "Whaler's Lance", target: 'enemy', cost: 45,
        desc: '190 damage.',
        fire: (w, u, t) => { w.damage(u, t, 190, 'phys'); },
      },
      {
        id: 'volley', name: 'Barb Scatter', target: 'enemy', cost: 40,
        desc: '75 damage to the target and every enemy within 6 m of it.',
        fire: (w, u, t) => {
          for (const e of w.enemiesNear(t.x, t.y, 6)) w.damage(u, e, 75, 'phys', { noBeam: e !== t });
          w.ring(t.x, t.y, 6, u.hero!.color);
        },
      },
      {
        id: 'jarring', name: 'Jarring Barb', target: 'enemy', cd: 20, offGcd: true, interrupt: true,
        desc: 'Silence the target\'s cast, at range.',
        fire: (w, u, t) => w.interrupt(u, t),
      },
      {
        id: 'tumble', name: 'Deck Roll', target: 'self', cd: 20, offGcd: true,
        desc: 'Roll 8 m in your move direction and take 30% less damage for 3 s.',
        fire: (w, u) => {
          const a = w.time - u.lastMoveT < 0.2 ? u.moveDir : u.facing + Math.PI;
          for (let i = 0; i < 16; i++) if (!w.map.move(u, Math.cos(a) * 0.5, Math.sin(a) * 0.5)) break;
          w.addAura(u, { id: 'tumble', name: 'Deck Roll', dur: 3, srcId: u.id, taken: 0.7 });
        },
      },
      {
        id: 'hawk', name: 'Gull\'s Eye', target: 'self', cd: 90, offGcd: true,
        desc: 'For 10 s, auto-attacks fly 50% faster and Snap Throw gives double focus.',
        fire: (w, u) => w.addAura(u, { id: 'hawk', name: 'Gull\'s Eye', dur: 10, srcId: u.id, haste: 1.5 }),
      },
    ],
  },

  pyromancer: {
    id: 'pyromancer', name: 'Tobias Wick', title: 'The Chandler', role: 'dps', sub: 'Caster damage', color: '#e8843c',
    hp: 1100, resName: 'Heat', resMax: 100, resStart: 0, resColor: '#ff7a2f', regen: 0, gcd: 1.5,
    auto: { dmg: 22, interval: 2, range: 30 }, threatMult: 1,
    howTo: 'Stand still to cast Wickfire and build Heat. Keep Tallow Burn on your target and save Flare-Up for when you have to move.',
    abilities: [
      {
        id: 'firebolt', name: 'Wickfire', target: 'enemy', cast: 2,
        desc: '170 damage. +25 Heat.',
        fire: (w, u, t) => { w.damage(u, t, 170, 'magic'); w.gain(u, 25); },
      },
      {
        id: 'ignite', name: 'Tallow Burn', target: 'enemy',
        desc: 'Instant. 240 damage over 12 s. +10 Heat. One per enemy.',
        fire: (w, u, t) => {
          w.addAura(t, { id: 'ignite' + u.id, name: 'Tallow Burn', dur: 12, srcId: u.id, debuff: true, tickEvery: 2, tickDmg: 40 });
          w.engageFrom(u, t);
          w.gain(u, 10);
        },
      },
      {
        id: 'burst', name: 'Flare-Up', target: 'enemy', cost: 50,
        desc: 'Instant. 200 damage to the target and 90 to every enemy within 6 m of it.',
        fire: (w, u, t) => {
          w.damage(u, t, 200, 'magic');
          for (const e of w.enemiesNear(t.x, t.y, 6)) if (e !== t) w.damage(u, e, 90, 'magic', { noBeam: true });
          w.ring(t.x, t.y, 6, u.hero!.color);
        },
      },
      {
        id: 'stifle', name: 'Snuff', target: 'enemy', cd: 20, offGcd: true, interrupt: true,
        desc: 'Silence the target\'s cast, at range.',
        fire: (w, u, t) => w.interrupt(u, t),
      },
      {
        id: 'ember', name: 'Wax Seal', target: 'self', cd: 45, offGcd: true,
        desc: 'Shield yourself against the next 400 damage, for 8 s.',
        fire: (w, u) => w.addAura(u, { id: 'ember', name: 'Wax Seal', dur: 8, srcId: u.id, absorb: 400 }),
      },
      {
        id: 'kindled', name: 'Steady Flame', target: 'self', cd: 120, offGcd: true,
        desc: 'For 12 s, Wickfire casts in half the time.',
        fire: (w, u) => w.addAura(u, { id: 'kindled', name: 'Steady Flame', dur: 12, srcId: u.id }),
      },
    ],
  },
};

export const TANKS = ['warden'];
export const HEALERS = ['mender', 'bloomweaver'];
export const DPS = ['duelist', 'ranger', 'pyromancer'];
