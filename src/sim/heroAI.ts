import type { AIState, Unit, Vec } from './types';
import { inZone, type World } from './world';

const dist = (a: Vec, b: Vec) => Math.hypot(a.x - b.x, a.y - b.y);
const pct = (u: Unit) => u.hp / u.maxHp;

export function newAI(w: World): AIState {
  return { reaction: 0.3 + w.rng() * 0.3, escape: null, pos: null, posT: 0, tankSpot: null, hide: null };
}

function use(w: World, h: Unit, id: string, t: Unit | null = null) {
  const i = h.hero!.abilities.findIndex((a) => a.id === id);
  return w.useAbility(h, i, t) === null;
}

const ready = (h: Unit, id: string) => (h.cds[id] ?? 0) <= 0;

// ---------- hazards

function safeAt(w: World, x: number, y: number) {
  return !w.zones.some((z) => inZone(z, x, y, 0.6));
}

function inDanger(w: World, h: Unit) {
  return w.zones.some((z) => z.t >= h.ai!.reaction && inZone(z, h.x, h.y, 0.4));
}

function findEscape(w: World, h: Unit): Vec | null {
  for (const r of [1.5, 2.5, 3.5, 5, 6.5, 8, 10, 13]) {
    for (let k = 0; k < 16; k++) {
      const a = (k / 16) * Math.PI * 2 + h.id;
      const x = h.x + Math.cos(a) * r, y = h.y + Math.sin(a) * r;
      if (w.map.canStand(x, y) && safeAt(w, x, y) && w.map.clearWalk(h.x, h.y, x, y)) return { x, y };
    }
  }
  return null;
}

function findHideSpot(w: World, h: Unit, boss: Unit): Vec | null {
  let best: Vec | null = null, bd = 1e9;
  for (const p of w.map.pillars) {
    if (!p.alive) continue;
    const cx = p.x + p.w / 2, cy = p.y + p.h / 2;
    if (Math.hypot(cx - boss.x, cy - boss.y) > 32) continue;
    const a = Math.atan2(cy - boss.y, cx - boss.x);
    for (const extra of [1, 1.6, 2.2]) {
      const r = Math.max(p.w, p.h) / 2 + extra;
      const s = { x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r };
      if (!w.map.canStand(s.x, s.y) || w.map.los(boss.x, boss.y, s.x, s.y)) continue;
      const d = dist(h, s);
      if (d < bd) { bd = d; best = s; }
      break;
    }
  }
  return best;
}

// In front of an enemy that can swing a frontal cone.
function inFront(w: World, x: number, y: number) {
  for (const e of w.enemies) {
    if (!e.alive || !e.engaged || !e.enemy!.frontal) continue;
    const d = Math.hypot(x - e.x, y - e.y);
    if (d > 13) continue;
    let a = Math.atan2(y - e.y, x - e.x) - e.facing;
    a = Math.atan2(Math.sin(a), Math.cos(a));
    if (Math.abs(a) < 1.35) return true;
  }
  return false;
}

// ---------- targeting and positioning

function pickTarget(w: World, h: Unit): Unit | null {
  const tankTarget = w.heroes[0].targetId;
  const melee = h.hero!.auto.range < 5;
  let best: Unit | null = null, bs = -1e9;
  for (const e of w.engagedEnemies()) {
    const s = e.enemy!.priority * 1000 - pct(e) * 100 + (e.id === h.targetId ? 60 : 0) + (e.id === tankTarget ? 80 : 0) - dist(h, e) * (melee ? 3 : 0.3);
    if (s > bs) { bs = s; best = e; }
  }
  return best;
}

function partyReady(w: World, tank: Unit) {
  const healer = w.heroes[1];
  return (
    w.heroes.every((h) => h.alive && pct(h) >= 0.8 && dist(h, tank) <= 22) &&
    healer.res >= healer.resMax * 0.6
  );
}

function tankTravel(w: World, h: Unit): Vec | null {
  const pack = w.nextPack();
  if (!pack) return null;
  const ok = partyReady(w, h);
  let vis: Unit | null = null;
  for (const e of pack.units) {
    if (!e.alive || dist(e, h) > 27 || !w.map.los(h.x, h.y, e.x, e.y)) continue;
    if (!vis || dist(e, h) < dist(vis, h)) vis = e;
  }
  if (vis) {
    if (!ok || !ready(h, 'challenge')) return null;
    h.targetId = vis.id;
    if (use(w, h, 'challenge', vis) && pack.def.losSpot) {
      w.gather = { x: pack.def.losSpot.x, y: pack.def.losSpot.y, until: w.time + 8 };
    }
    return null;
  }
  const human = w.autoplay ? null : w.player;
  if (human && human !== h && dist(human, h) > 28) return null;
  return pack.def.pullFrom;
}

function oocGoal(w: World, h: Unit): Vec | null {
  const tank = w.heroes[0];
  if (h === tank) return tankTravel(w, h);
  const stop = 2.5 + h.slot * 1.3;
  return dist(h, tank) > stop + 1 ? { x: tank.x, y: tank.y } : null;
}

function tankCombat(w: World, h: Unit): Vec | null {
  const ai = h.ai!;
  const es = w.engagedEnemies();
  if (!es.length) return null;
  if (w.gather) {
    const g = w.gather;
    const far = es.some((e) => dist(e, h) > 9);
    if (w.time > g.until || (dist(h, g) < 1.5 && !far)) w.gather = null;
    else {
      h.targetId = es.reduce((a, b) => (dist(a, h) < dist(b, h) ? a : b)).id;
      return g;
    }
  }
  // pick up anything that is not on the tank
  if (ready(h, 'challenge')) {
    const loose = es
      .filter((e) => e.targetId !== h.id && e.targetId >= 0 && e.forcedT <= w.time)
      .sort((a, b) => b.enemy!.priority - a.enemy!.priority || dist(a, h) - dist(b, h));
    for (const e of loose) if (use(w, h, 'challenge', e)) break;
  }
  const near = es.filter((e) => dist(e, h) <= 3.2 + e.radius * 0.5);
  // stand among the ranged enemies so the melee ones are dragged onto them
  const ranged = es.filter((e) => e.enemy!.range > 5);
  if (ranged.some((e) => dist(e, h) > 5.5)) {
    const c = { x: 0, y: 0 };
    for (const e of ranged) { c.x += e.x / ranged.length; c.y += e.y / ranged.length; }
    if (dist(h, c) > 2 && w.map.canStand(c.x, c.y)) {
      ai.tankSpot = null;
      if (near.length) h.targetId = near[0].id;
      return c;
    }
  }
  if (!near.length) {
    ai.tankSpot = null;
    const e = es.reduce((a, b) => (dist(a, h) < dist(b, h) ? a : b));
    h.targetId = e.id;
    return { x: e.x, y: e.y };
  }
  let best = near[0];
  for (const e of near) {
    if (e.enemy!.priority > best.enemy!.priority || (e.enemy!.priority === best.enemy!.priority && e.id === h.targetId)) best = e;
  }
  h.targetId = best.id;
  if (!ai.tankSpot) ai.tankSpot = { x: h.x, y: h.y };
  return dist(h, ai.tankSpot) > 1 ? ai.tankSpot : null;
}

function meleePos(w: World, h: Unit, t: Unit): Vec | null {
  const tt = w.unit(t.targetId);
  const reach = 2.8 + t.radius * 0.5;
  if (tt && tt !== h && tt.alive && tt.team === 'hero') {
    const a = Math.atan2(t.y - tt.y, t.x - tt.x);
    const r = t.radius + 1.1;
    const p = { x: t.x + Math.cos(a) * r, y: t.y + Math.sin(a) * r };
    if (w.map.canStand(p.x, p.y)) return dist(h, p) < 1.2 && dist(h, t) <= reach ? null : p;
  }
  return dist(h, t) <= reach ? null : { x: t.x, y: t.y };
}

// Hold a spot with range and line of sight to the anchor, out of frontals and ground effects.
function rangedPos(w: World, h: Unit, anchor: Unit): Vec | null {
  const ai = h.ai!;
  if (w.time < ai.posT) return ai.pos;
  ai.posT = w.time + 0.3;
  const minD = anchor.team === 'enemy' ? 4 : 0;
  const valid = (x: number, y: number) => {
    const d = Math.hypot(x - anchor.x, y - anchor.y);
    return d <= 26 && d >= minD && w.map.los(x, y, anchor.x, anchor.y) && !inFront(w, x, y) && safeAt(w, x, y);
  };
  if (valid(h.x, h.y)) return (ai.pos = null);
  if (ai.pos && valid(ai.pos.x, ai.pos.y)) return ai.pos;
  let best: Vec | null = null, bd = 1e9;
  for (const r of [16, 11, 21, 7]) {
    for (let k = 0; k < 12; k++) {
      const a = (k / 12) * Math.PI * 2 + h.id;
      const x = anchor.x + Math.cos(a) * r, y = anchor.y + Math.sin(a) * r;
      if (!w.map.canStand(x, y) || !valid(x, y)) continue;
      const d = Math.hypot(x - h.x, y - h.y) + (w.map.clearWalk(h.x, h.y, x, y) ? 0 : 12);
      if (d < bd) { bd = d; best = { x, y }; }
    }
  }
  return (ai.pos = best ?? { x: anchor.x, y: anchor.y });
}

function combatGoal(w: World, h: Unit): Vec | null {
  const def = h.hero!;
  if (def.role === 'tank') return tankCombat(w, h);
  const t = pickTarget(w, h);
  if (t) h.targetId = t.id;
  if (w.gather) return dist(h, w.gather) > 2.5 ? w.gather : null;
  if (def.role === 'healer') {
    const tank = w.heroes[0];
    let anchor = tank.alive ? tank : h;
    // go to whoever needs healing and cannot be reached
    for (const a of w.heroes) {
      if (a.alive && a !== h && pct(a) < 0.6 && (dist(a, h) > 28 || !w.map.los(h.x, h.y, a.x, a.y))) anchor = a;
    }
    return anchor === h ? null : rangedPos(w, h, anchor);
  }
  if (!t || !w.canAttack()) return null;
  return def.auto.range < 5 ? meleePos(w, h, t) : rangedPos(w, h, t);
}

// ---------- actions

function kick(w: World, h: Unit) {
  const ab = h.hero!.abilities.find((a) => a.interrupt);
  if (!ab || !ready(h, ab.id)) return;
  for (const e of w.enemies) {
    const c = e.cast;
    if (e.alive && c && c.assignee === h.id && w.time - c.assignedAt! >= h.ai!.reaction) {
      use(w, h, ab.id, e);
      return;
    }
  }
}

function busterOn(w: World, h: Unit, bossOnly = false) {
  return w.enemies.some(
    (e) => e.alive && e.cast && e.cast.ab!.tankBuster && e.cast.targetId === h.id && e.cast.t >= 0.4 && (!bossOnly || e.enemy!.boss),
  );
}

function reachable(w: World, h: Unit, a: Unit) {
  return a === h || (dist(a, h) <= 30 && w.map.los(h.x, h.y, a.x, a.y));
}

function healerCommon(w: World, h: Unit, dispelId: string, wardId: string, bigId: string) {
  const allies = w.heroes.filter((a) => a.alive && reachable(w, h, a));
  if (ready(h, dispelId)) {
    const d = allies.find((a) => a.auras.some((au) => au.dispellable && au.dur - au.t >= h.ai!.reaction + 0.3));
    if (d) use(w, h, dispelId, d);
  }
  if (ready(h, wardId)) {
    const tank = w.heroes[0];
    const shielded = w.hasAura(tank, 'brace') || w.hasAura(tank, 'unbreakable');
    const needy = allies.find((a) => pct(a) < 0.3);
    if (tank.alive && allies.includes(tank) && busterOn(w, tank, true) && !shielded) use(w, h, wardId, tank);
    else if (needy) use(w, h, wardId, needy);
  }
  const low = allies.filter((a) => pct(a) < 0.5).length, vlow = allies.filter((a) => pct(a) < 0.35).length;
  if (low >= 3 || vlow >= 2) use(w, h, bigId);
  return allies.sort((a, b) => pct(a) - pct(b));
}

const ACT: Record<string, (w: World, h: Unit) => void> = {
  warden(w, h) {
    kick(w, h);
    const es = w.engagedEnemies();
    const hasBuster = es.some((e) => e.enemy!.abilities.some((a) => a.tankBuster && w.level >= (a.minLevel ?? 0)));
    if (!w.hasAura(h, 'brace')) {
      if (busterOn(w, h) || h.res >= 85 || (!hasBuster && h.res >= 40 && pct(h) < 0.9)) use(w, h, 'brace');
    }
    if (pct(h) < 0.35) use(w, h, 'unbreakable');
    const t = w.unit(h.targetId);
    if (t && t.alive && use(w, h, 'strike', t)) return;
    if (w.enemiesNear(h.x, h.y, 6).some((e) => e.engaged)) use(w, h, 'sweep');
  },

  mender(w, h) {
    const allies = healerCommon(w, h, 'purify', 'ward', 'sanctuary');
    if (h.cast || h.gcd > 0) return;
    const low = allies[0];
    const tank = w.heroes[0];
    const missing = low ? low.maxHp - low.hp : 0;
    if (low && pct(low) < 0.4 && h.res >= 200 && use(w, h, 'quick', low)) return;
    if (low && (pct(low) < 0.7 || missing >= 380) && use(w, h, 'mend', low)) return;
    if (tank.alive && tank.maxHp - tank.hp >= 300 && allies.includes(tank) && use(w, h, 'mend', tank)) return;
    const t = w.unit(h.targetId);
    if (t && t.alive && w.canAttack()) use(w, h, 'rebuke', t);
  },

  bloomweaver(w, h) {
    const allies = healerCommon(w, h, 'dew', 'bramble', 'tide');
    if (h.gcd > 0) return;
    const tank = w.heroes[0];
    const low = allies[0];
    if (low && pct(low) < 0.6 && !w.hasAura(low, 'bark') && use(w, h, 'bark', low)) return;
    const tankOk = tank.alive && allies.includes(tank);
    if (tankOk && !w.hasAura(tank, 'bark') && (pct(tank) < 0.8 || busterOn(w, tank)) && use(w, h, 'bark', tank)) return;
    const vines = allies.filter((a) => w.hasAura(a, 'vine'));
    if ((vines.filter((a) => pct(a) < 0.75).length >= 2 || vines.some((a) => pct(a) < 0.5)) && use(w, h, 'bloom')) return;
    if (tank.alive && allies.includes(tank) && !w.hasAura(tank, 'vine') && use(w, h, 'vine', tank)) return;
    const need = allies.find((a) => pct(a) < 0.8 && !w.hasAura(a, 'vine'));
    if (need && use(w, h, 'vine', need)) return;
    if (tank.alive && allies.includes(tank) && pct(tank) < 0.85 && !w.hasAura(tank, 'bark')) use(w, h, 'bark', tank);
  },

  duelist(w, h) {
    kick(w, h);
    if (pct(h) < 0.4) use(w, h, 'riposte');
    const t = w.unit(h.targetId);
    if (!t || !t.alive || !w.canAttack()) return;
    const n = w.enemiesNear(h.x, h.y, 5).length;
    if ((t.enemy!.boss || n >= 3) && dist(h, t) < 4) use(w, h, 'bloodrush');
    if (h.gcd > 0) return;
    if (h.combo >= 5 && use(w, h, 'thrust', t)) return;
    if (n >= 3) use(w, h, 'whirl');
    else use(w, h, 'slash', t);
  },

  ranger(w, h) {
    kick(w, h);
    if (pct(h) < 0.4) use(w, h, 'tumble');
    const t = w.unit(h.targetId);
    if (!t || !t.alive || !w.canAttack()) return;
    const n = w.enemiesNear(t.x, t.y, 6).length;
    if (t.enemy!.boss || n >= 3) use(w, h, 'hawk');
    if (h.gcd > 0) return;
    if (n >= 3 && use(w, h, 'volley', t)) return;
    if (n < 3 && use(w, h, 'piercing', t)) return;
    use(w, h, 'quickshot', t);
  },

  pyromancer(w, h) {
    kick(w, h);
    if (pct(h) < 0.5) use(w, h, 'ember');
    const t = w.unit(h.targetId);
    if (!t || !t.alive || !w.canAttack()) return;
    if (t.enemy!.boss || w.enemiesNear(t.x, t.y, 6).length >= 3) use(w, h, 'kindled');
    if (h.cast || h.gcd > 0) return;
    if (use(w, h, 'burst', t)) return;
    if (!w.hasAura(t, 'ignite' + h.id) && t.hp > 300 && use(w, h, 'ignite', t)) return;
    if (!h.moved) use(w, h, 'firebolt', t);
    else if (!w.hasAura(t, 'ignite' + h.id)) use(w, h, 'ignite', t);
  },
};

export function heroAI(w: World, h: Unit, dt: number) {
  const ai = h.ai!;
  let goal: Vec | null = null;
  let urgent = false;

  const boss = w.hideCaster();
  if (boss && boss.cast!.t >= ai.reaction) {
    if (!ai.hide) ai.hide = findHideSpot(w, h, boss);
    if (ai.hide) { goal = ai.hide; urgent = true; }
  } else {
    ai.hide = null;
    if (inDanger(w, h)) {
      if (!ai.escape || !safeAt(w, ai.escape.x, ai.escape.y)) ai.escape = findEscape(w, h);
      goal = ai.escape;
      urgent = !!goal;
    } else {
      ai.escape = null;
    }
  }

  if (!w.inCombat) {
    ai.tankSpot = null;
    ai.pos = null;
    const g = oocGoal(w, h);
    if (!urgent) goal = g;
  } else {
    const g = combatGoal(w, h);
    if (!urgent) goal = g;
  }
  if (goal && dist(h, goal) > 0.35) w.navigate(h, goal.x, goal.y, dt);
  if (w.inCombat) ACT[h.hero!.id](w, h);
}
