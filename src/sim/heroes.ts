import type { HeroDef, Unit } from './types';
import type { World } from './world';

const MELEE = 3.2;

function dispel(w: World, u: Unit, t: Unit) {
  w.dispel(u, t);
}

export const HEROES: Record<string, HeroDef> = {
  warden: {
    id: 'warden', name: 'Warden', role: 'tank', sub: 'Tank', color: '#4a90e2',
    hp: 2400, resName: 'Rage', resMax: 100, resStart: 0, resColor: '#c0392b', regen: 0, gcd: 1.5,
    auto: { dmg: 40, interval: 1.8, range: MELEE }, threatMult: 4,
    howTo: 'Pull with Challenge, keep every enemy on you with Sweep, and save rage so Brace is up for telegraphed heavy hits.',
    abilities: [
      {
        id: 'strike', name: 'Shield Strike', target: 'enemy', range: MELEE, cd: 4.5,
        desc: '110 damage. +8 rage.',
        fire: (w, u, t) => { w.damage(u, t, 110, 'phys'); w.gain(u, 8); },
      },
      {
        id: 'sweep', name: 'Sweep', target: 'self',
        desc: '50 damage to every enemy within 6 m. +1 rage per enemy hit, up to 5.',
        fire: (w, u) => {
          const hit = w.enemiesNear(u.x, u.y, 6);
          for (const e of hit) w.damage(u, e, 50, 'phys');
          w.gain(u, Math.min(5, hit.length));
          w.ring(u.x, u.y, 6, u.hero!.color);
        },
      },
      {
        id: 'challenge', name: 'Challenge', target: 'enemy', cd: 8, offGcd: true,
        desc: 'The target attacks you for 4 s and you go to the top of its threat. Works at range: use it to pull.',
        fire: (w, u, t) => w.taunt(u, t),
      },
      {
        id: 'bash', name: 'Shield Bash', target: 'enemy', range: MELEE, cd: 15, offGcd: true, interrupt: true,
        desc: 'Interrupt the target\'s cast.',
        fire: (w, u, t) => w.interrupt(u, t),
      },
      {
        id: 'brace', name: 'Brace', target: 'self', cost: 40, offGcd: true,
        desc: 'Take 50% less physical damage for 6 s.',
        fire: (w, u) => w.addAura(u, { id: 'brace', name: 'Brace', dur: 6, srcId: u.id, takenPhys: 0.5 }),
      },
      {
        id: 'unbreakable', name: 'Unbreakable', target: 'self', cd: 120, offGcd: true,
        desc: 'Take 40% less damage of all kinds for 10 s and heal 20% of maximum health.',
        fire: (w, u) => {
          w.addAura(u, { id: 'unbreakable', name: 'Unbreakable', dur: 10, srcId: u.id, taken: 0.6 });
          w.heal(u, u, u.maxHp * 0.2);
        },
      },
    ],
  },

  mender: {
    id: 'mender', name: 'Mender', role: 'healer', sub: 'Direct healer', color: '#f2d16b',
    hp: 1200, resName: 'Mana', resMax: 1000, resStart: 1000, resColor: '#3f7fd9', regen: 8, gcd: 1.5,
    auto: { dmg: 22, interval: 2, range: 30 }, threatMult: 1,
    howTo: 'React to damage: Mend for efficiency, Quick Mend for emergencies. Rebuke when nobody needs healing to win back mana.',
    abilities: [
      {
        id: 'mend', name: 'Mend', target: 'ally', cost: 40, cast: 2,
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
        id: 'quick', name: 'Quick Mend', target: 'ally', cost: 90,
        desc: 'Instant. Heal 330.',
        fire: (w, u, t) => { w.heal(u, t, 330); },
      },
      {
        id: 'rebuke', name: 'Rebuke', target: 'enemy', cast: 1.5,
        desc: '70 damage. Restores 15 mana.',
        fire: (w, u, t) => { w.damage(u, t, 70, 'magic'); w.gain(u, 15); },
      },
      {
        id: 'purify', name: 'Purify', target: 'ally', cost: 30, cd: 8, dispel: true,
        desc: 'Remove every dispellable debuff from an ally.',
        fire: dispel,
      },
      {
        id: 'ward', name: 'Guardian Ward', target: 'ally', cd: 45, offGcd: true,
        desc: 'An ally takes 40% less damage for 6 s.',
        fire: (w, u, t) => w.addAura(t, { id: 'ward', name: 'Guardian Ward', dur: 6, srcId: u.id, taken: 0.6 }),
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
    id: 'bloomweaver', name: 'Bloomweaver', role: 'healer', sub: 'Heal-over-time and shield healer', color: '#4caf7a',
    hp: 1200, resName: 'Mana', resMax: 1000, resStart: 1000, resColor: '#3f7fd9', regen: 8, gcd: 1.5,
    auto: { dmg: 22, interval: 2, range: 30 }, threatMult: 1,
    howTo: 'Heal ahead of the damage: keep Mending Vine rolling, shield whoever is about to be hit, and Bloom when several vines are out.',
    abilities: [
      {
        id: 'vine', name: 'Mending Vine', target: 'ally', cost: 35,
        desc: 'Heal 60 every 2 s for 14 s. One per ally; recasting refreshes it.',
        fire: (w, u, t) => w.addAura(t, { id: 'vine', name: 'Mending Vine', dur: 14, srcId: u.id, tickEvery: 2, tickHeal: 60 }),
      },
      {
        id: 'bark', name: 'Bark Ward', target: 'ally', cost: 55, cd: 4,
        desc: 'Shield an ally against the next 350 damage, for 12 s.',
        fire: (w, u, t) => {
          w.addAura(t, { id: 'bark', name: 'Bark Ward', dur: 12, srcId: u.id, absorb: 350 });
          if (w.hasAura(u, 'tide')) u.cds.bark = 0;
        },
      },
      {
        id: 'bloom', name: 'Bloom', target: 'self', cost: 60, cd: 10,
        desc: 'Every ally with Mending Vine is healed for 240 at once. The vines keep running.',
        fire: (w, u) => {
          for (const h of w.heroes) if (h.alive && w.hasAura(h, 'vine')) w.heal(u, h, 240);
        },
      },
      {
        id: 'dew', name: 'Cleansing Dew', target: 'ally', cost: 30, cd: 8, dispel: true,
        desc: 'Remove every dispellable debuff from an ally.',
        fire: dispel,
      },
      {
        id: 'bramble', name: 'Bramble Guard', target: 'ally', cd: 45, offGcd: true,
        desc: 'An ally takes 30% less damage for 8 s.',
        fire: (w, u, t) => w.addAura(t, { id: 'bramble', name: 'Bramble Guard', dur: 8, srcId: u.id, taken: 0.7 }),
      },
      {
        id: 'tide', name: 'Verdant Tide', target: 'self', cd: 120,
        desc: 'Put Mending Vine on every ally. For 10 s vines tick twice as fast and Bark Ward has no cooldown.',
        fire: (w, u) => {
          w.addAura(u, { id: 'tide', name: 'Verdant Tide', dur: 10, srcId: u.id });
          u.cds.bark = 0;
          for (const h of w.heroes) {
            if (h.alive) w.addAura(h, { id: 'vine', name: 'Mending Vine', dur: 14, srcId: u.id, tickEvery: 2, tickHeal: 60 });
          }
        },
      },
    ],
  },

  duelist: {
    id: 'duelist', name: 'Duelist', role: 'dps', sub: 'Melee damage', color: '#e8a23a',
    hp: 1300, resName: 'Energy', resMax: 100, resStart: 100, resColor: '#e3c33b', regen: 12, gcd: 1,
    auto: { dmg: 55, interval: 1.2, range: MELEE }, threatMult: 1,
    howTo: 'Build combo points with Slash or Whirl, spend five on Finishing Thrust, and stay behind the enemy, out of frontals.',
    abilities: [
      {
        id: 'slash', name: 'Slash', target: 'enemy', range: MELEE, cost: 40,
        desc: '95 damage. +1 combo point.',
        fire: (w, u, t) => { w.damage(u, t, 95, 'phys'); u.combo = Math.min(5, u.combo + 1); },
      },
      {
        id: 'whirl', name: 'Whirl', target: 'self', cost: 45,
        desc: '55 damage to every enemy within 5 m. +1 combo point.',
        fire: (w, u) => {
          for (const e of w.enemiesNear(u.x, u.y, 5)) w.damage(u, e, 55, 'phys');
          u.combo = Math.min(5, u.combo + 1);
          w.ring(u.x, u.y, 5, u.hero!.color);
        },
      },
      {
        id: 'thrust', name: 'Finishing Thrust', target: 'enemy', range: MELEE, cost: 25,
        desc: 'Spends all combo points. 70 damage per point.',
        usable: (_w, u) => (u.combo > 0 ? null : 'No combo points'),
        fire: (w, u, t) => { const c = u.combo; u.combo = 0; w.damage(u, t, 70 * c, 'phys'); },
      },
      {
        id: 'jab', name: 'Hilt Jab', target: 'enemy', range: MELEE, cd: 15, offGcd: true, interrupt: true,
        desc: 'Interrupt the target\'s cast.',
        fire: (w, u, t) => w.interrupt(u, t),
      },
      {
        id: 'riposte', name: 'Riposte', target: 'self', cd: 60, offGcd: true,
        desc: 'Take 50% less damage for 5 s.',
        fire: (w, u) => w.addAura(u, { id: 'riposte', name: 'Riposte', dur: 5, srcId: u.id, taken: 0.5 }),
      },
      {
        id: 'bloodrush', name: 'Bloodrush', target: 'self', cd: 120, offGcd: true,
        desc: 'For 12 s, energy regenerates twice as fast and you deal 20% more damage.',
        fire: (w, u) => w.addAura(u, { id: 'bloodrush', name: 'Bloodrush', dur: 12, srcId: u.id, done: 1.2 }),
      },
    ],
  },

  ranger: {
    id: 'ranger', name: 'Ranger', role: 'dps', sub: 'Ranged damage', color: '#b5c94a',
    hp: 1200, resName: 'Focus', resMax: 100, resStart: 100, resColor: '#d98a3f', regen: 4, gcd: 1.5,
    auto: { dmg: 50, interval: 1.6, range: 30 }, threatMult: 1,
    howTo: 'Everything works on the move. Quick Shot builds focus; spend it on Piercing Shot, or Scatter Volley against groups.',
    abilities: [
      {
        id: 'quickshot', name: 'Quick Shot', target: 'enemy',
        desc: '60 damage. +15 focus.',
        fire: (w, u, t) => { w.damage(u, t, 60, 'phys'); w.gain(u, w.hasAura(u, 'hawk') ? 30 : 15); },
      },
      {
        id: 'piercing', name: 'Piercing Shot', target: 'enemy', cost: 45,
        desc: '190 damage.',
        fire: (w, u, t) => { w.damage(u, t, 190, 'phys'); },
      },
      {
        id: 'volley', name: 'Scatter Volley', target: 'enemy', cost: 40,
        desc: '75 damage to the target and every enemy within 6 m of it.',
        fire: (w, u, t) => {
          for (const e of w.enemiesNear(t.x, t.y, 6)) w.damage(u, e, 75, 'phys', { noBeam: e !== t });
          w.ring(t.x, t.y, 6, u.hero!.color);
        },
      },
      {
        id: 'jarring', name: 'Jarring Shot', target: 'enemy', cd: 20, offGcd: true, interrupt: true,
        desc: 'Interrupt the target\'s cast, at range.',
        fire: (w, u, t) => w.interrupt(u, t),
      },
      {
        id: 'tumble', name: 'Tumble', target: 'self', cd: 20, offGcd: true,
        desc: 'Roll 8 m in your move direction and take 30% less damage for 3 s.',
        fire: (w, u) => {
          const a = w.time - u.lastMoveT < 0.2 ? u.moveDir : u.facing + Math.PI;
          for (let i = 0; i < 16; i++) if (!w.map.move(u, Math.cos(a) * 0.5, Math.sin(a) * 0.5)) break;
          w.addAura(u, { id: 'tumble', name: 'Tumble', dur: 3, srcId: u.id, taken: 0.7 });
        },
      },
      {
        id: 'hawk', name: 'Hawk\'s Focus', target: 'self', cd: 90, offGcd: true,
        desc: 'For 10 s, auto-attacks fire 50% faster and Quick Shot gives double focus.',
        fire: (w, u) => w.addAura(u, { id: 'hawk', name: 'Hawk\'s Focus', dur: 10, srcId: u.id, haste: 1.5 }),
      },
    ],
  },

  pyromancer: {
    id: 'pyromancer', name: 'Pyromancer', role: 'dps', sub: 'Caster damage', color: '#e2674a',
    hp: 1100, resName: 'Heat', resMax: 100, resStart: 0, resColor: '#ff7a2f', regen: 0, gcd: 1.5,
    auto: { dmg: 22, interval: 2, range: 30 }, threatMult: 1,
    howTo: 'Stand still to cast Firebolt and build Heat. Keep Ignite on your target and save Flame Burst for when you have to move.',
    abilities: [
      {
        id: 'firebolt', name: 'Firebolt', target: 'enemy', cast: 2,
        desc: '170 damage. +25 Heat.',
        fire: (w, u, t) => { w.damage(u, t, 170, 'magic'); w.gain(u, 25); },
      },
      {
        id: 'ignite', name: 'Ignite', target: 'enemy',
        desc: 'Instant. 240 damage over 12 s. +10 Heat. One per enemy.',
        fire: (w, u, t) => {
          w.addAura(t, { id: 'ignite' + u.id, name: 'Ignite', dur: 12, srcId: u.id, debuff: true, tickEvery: 2, tickDmg: 40 });
          w.engageFrom(u, t);
          w.gain(u, 10);
        },
      },
      {
        id: 'burst', name: 'Flame Burst', target: 'enemy', cost: 50,
        desc: 'Instant. 200 damage to the target and 90 to every enemy within 6 m of it.',
        fire: (w, u, t) => {
          w.damage(u, t, 200, 'magic');
          for (const e of w.enemiesNear(t.x, t.y, 6)) if (e !== t) w.damage(u, e, 90, 'magic', { noBeam: true });
          w.ring(t.x, t.y, 6, u.hero!.color);
        },
      },
      {
        id: 'stifle', name: 'Stifle', target: 'enemy', cd: 20, offGcd: true, interrupt: true,
        desc: 'Interrupt the target\'s cast, at range.',
        fire: (w, u, t) => w.interrupt(u, t),
      },
      {
        id: 'ember', name: 'Ember Shield', target: 'self', cd: 45, offGcd: true,
        desc: 'Shield yourself against the next 400 damage, for 8 s.',
        fire: (w, u) => w.addAura(u, { id: 'ember', name: 'Ember Shield', dur: 8, srcId: u.id, absorb: 400 }),
      },
      {
        id: 'kindled', name: 'Kindled Mind', target: 'self', cd: 120, offGcd: true,
        desc: 'For 12 s, Firebolt casts in half the time.',
        fire: (w, u) => w.addAura(u, { id: 'kindled', name: 'Kindled Mind', dur: 12, srcId: u.id }),
      },
    ],
  },
};

export const TANKS = ['warden'];
export const HEALERS = ['mender', 'bloomweaver'];
export const DPS = ['duelist', 'ranger', 'pyromancer'];
