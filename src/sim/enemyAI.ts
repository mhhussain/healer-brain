import type { Unit } from './types';
import type { World } from './world';

const AGGRO = 11;
const dist = (a: Unit, b: Unit) => Math.hypot(a.x - b.x, a.y - b.y);

export function enemyAI(w: World, e: Unit, dt: number) {
  const def = e.enemy!;
  if (!e.engaged) {
    if ((e.aggroT -= dt) > 0) return;
    e.aggroT = 0.2;
    for (const h of w.heroes) {
      if (h.alive && dist(h, e) <= AGGRO && w.map.los(e.x, e.y, h.x, h.y)) {
        w.engage(w.packs[e.packId], h);
        break;
      }
    }
    return;
  }
  def.passive?.(w, e);
  const tgt = w.pickThreatTarget(e);
  if (!tgt) return;
  e.targetId = tgt.id;
  if (e.busy > 0) e.busy -= dt;

  const c = e.cast;
  if (c) {
    const ab = c.ab!;
    const ct = w.unit(c.targetId);
    if (c.dir != null) e.facing = c.dir;
    else if (ct) e.facing = Math.atan2(ct.y - e.y, ct.x - e.x);
    c.t += dt;
    if (ab.tick && (c.tickTimer! -= dt) <= 0) {
      c.tickTimer! += 1;
      ab.tick(w, e, c);
    }
    if (c.t >= c.total) {
      e.cast = null;
      e.busy = 0.4;
      const ok = !ab.needsLos || (ct && ct.alive && w.map.los(e.x, e.y, ct.x, ct.y));
      if (ok) ab.finish?.(w, e, ct && ct.alive ? ct : null);
    }
    return;
  }

  let chase: Unit | null = null;
  if (e.busy <= 0) {
    for (const ab of def.abilities) {
      if (ab.minLevel && w.level < ab.minLevel) continue;
      if ((e.cds[ab.id] ?? 0) > 0) continue;
      if (ab.ready && !ab.ready(w, e)) continue;
      if (ab.melee && dist(e, tgt) > 3.2) continue;
      let t: Unit | null = null;
      if (ab.targeting === 'threat') t = tgt;
      else if (ab.targeting === 'random') {
        const p = e.pending && e.pending.ab === ab.id ? w.unit(e.pending.targetId) : null;
        t = p && p.alive ? p : w.randomHero();
      }
      if (ab.needsLos && t && !w.map.los(e.x, e.y, t.x, t.y)) {
        e.pending = { ab: ab.id, targetId: t.id };
        chase = t;
        break;
      }
      w.startEnemyCast(e, ab, t);
      return;
    }
  }

  const mt = chase ?? tgt;
  const d = dist(e, mt);
  const melee = def.range < 5;
  if (chase) {
    w.navigate(e, mt.x, mt.y, dt);
    return;
  }
  // once walking, close a little further than needed, so a small shuffle by the target is not followed step for step
  const stopAt = melee ? Math.max(def.radius + 1, def.range - 0.5) : def.range - 0.5;
  if (d > (e.flags.chase ? stopAt : def.range) || (!melee && !w.map.los(e.x, e.y, mt.x, mt.y))) {
    e.flags.chase = true;
    let gx = mt.x, gy = mt.y;
    if (melee) {
      const sx = mt.x + Math.cos(e.slotAngle) * (def.radius + 0.9), sy = mt.y + Math.sin(e.slotAngle) * (def.radius + 0.9);
      if (w.map.canStand(sx, sy)) { gx = sx; gy = sy; }
    }
    w.navigate(e, gx, gy, dt);
    return;
  }
  e.flags.chase = false;
  e.facing = Math.atan2(mt.y - e.y, mt.x - e.x);
  if (!def.auto) return;
  let haste = 1;
  for (const a of e.auras) if (a.haste) haste *= a.haste;
  if ((e.autoTimer -= dt * haste) <= 0) {
    e.autoTimer = def.auto.interval;
    w.damage(e, mt, def.auto.dmg, def.auto.type);
  }
}
