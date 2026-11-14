class_name HeroAI
extends RefCounted

# How the AI plays a hero: where it wants to stand and which ability it uses. It only decides;
# it sets the hero's goal and the scene does the walking. Ported from src/sim/heroAI.ts.
# A spot is a Vector3, or null for none.

static func _pct(u: Combatant) -> float:
	return u.hp / u.max_hp


static func _off_cd(h: Combatant, id: String) -> bool:
	return h.cds.get(id, 0.0) <= 0.0


## Uses the hero's ability with that id. True if it went off or began casting.
static func _use(c: Combat, h: Combatant, id: String, t: Combatant = null) -> bool:
	for i in h.hero.abilities.size():
		if h.hero.abilities[i].id == id:
			return c.use_ability(h, i, t) == ""
	return false


static func _healer(c: Combat) -> Combatant:
	for h in c.heroes:
		if h.hero.role == "healer":
			return h
	return null


static func _nearest(list: Array, h: Combatant) -> Combatant:
	var best: Combatant = null
	for e: Combatant in list:
		if best == null or Combat.dist(e, h) < Combat.dist(best, h):
			best = e
	return best


# ---------- hazards

static func _safe_at(c: Combat, p: Vector3) -> bool:
	for z in c.zones:
		if z.holds(p, 0.6):
			return false
	return true


# Close enough to a pack that is not in the fight to wake it.
static func _near_idle(c: Combat, p: Vector3) -> bool:
	for e in c.enemies:
		if e.alive and not e.engaged and Combat.flat(e.pos, p) < 14.0:
			return true
	return false


static func _in_danger(c: Combat, h: Combatant) -> bool:
	for z in c.zones:
		if z.t >= h.ai.reaction and z.holds(h.pos, 0.4):
			return true
	return false


static func _find_escape(c: Combat, h: Combatant):
	for r: float in [1.5, 2.5, 3.5, 5.0, 6.5, 8.0, 10.0, 13.0]:
		for k in 16:
			var a := k / 16.0 * TAU + h.id
			var p := h.pos + Vector3(cos(a), 0, sin(a)) * r
			if c.can_stand.call(p) and _safe_at(c, p) and not _near_idle(c, p) and c.clear_walk.call(h.pos, p):
				return p
	return null


# The nearest spot behind a standing pillar that the boss cannot see.
static func _find_hide_spot(c: Combat, h: Combatant, boss: Combatant):
	var best = null
	var best_d := INF
	for pillar in c.pillars:
		if not pillar.alive or Combat.flat(pillar.pos, boss.pos) > 32.0:
			continue
		var away := Vector3(pillar.pos.x - boss.pos.x, 0, pillar.pos.z - boss.pos.z).normalized()
		for extra: float in [1.0, 1.6, 2.2]:
			var spot: Vector3 = pillar.pos + away * (pillar.r + extra)
			if not c.can_stand.call(spot) or c.los.call(boss.pos, spot):
				continue
			var d := Combat.flat(h.pos, spot)
			if d < best_d:
				best_d = d
				best = spot
			break
	return best


# In front of an enemy that can swing a frontal cone.
static func _in_front(c: Combat, p: Vector3) -> bool:
	for e in c.enemies:
		if not e.alive or not e.engaged or not e.enemy.frontal:
			continue
		var off := Vector2(p.x - e.pos.x, p.z - e.pos.z)
		if off.length() > 13.0:
			continue
		if absf(Vector2(e.facing.x, e.facing.z).angle_to(off)) < 1.35:
			return true
	return false


# ---------- targeting and positioning

static func _pick_target(c: Combat, h: Combatant) -> Combatant:
	var tank_target := c.tank().target_id
	var melee := h.hero.auto_reach < 5.0
	var best: Combatant = null
	var best_s := -INF
	for e in c.engaged_enemies():
		var s: float = e.enemy.priority * 1000.0 - _pct(e) * 100.0 + (60.0 if e.id == h.target_id else 0.0) \
			+ (80.0 if e.id == tank_target else 0.0) - Combat.dist(h, e) * (3.0 if melee else 0.3)
		if s > best_s:
			best_s = s
			best = e
	return best


static func _party_ready(c: Combat, tank: Combatant) -> bool:
	for h in c.heroes:
		if not h.alive or _pct(h) < 0.8 or Combat.dist(h, tank) > 22.0:
			return false
	var healer := _healer(c)
	return healer == null or healer.res >= healer.res_max * 0.6


# Out of a fight, the tank leads the way to the next pack and pulls it once everyone is ready.
static func _tank_travel(c: Combat, h: Combatant):
	var pack := c.next_pack()
	if pack == null:
		return null
	var ok := _party_ready(c, h)
	var vis: Combatant = null
	for e in pack.units:
		if not e.alive or Combat.dist(e, h) > 27.0 or not c.sees(h, e):
			continue
		if vis == null or Combat.dist(e, h) < Combat.dist(vis, h):
			vis = e
	if vis:
		if not ok or not _off_cd(h, "challenge"):
			return null
		h.target_id = vis.id
		_use(c, h, "challenge", vis)
		return null
	# do not run off without the player
	var human := null if c.autoplay else c.player
	if human and human != h and Combat.dist(human, h) > 28.0:
		return null
	return pack.pull_from


static func _ooc_goal(c: Combat, h: Combatant):
	var tank := c.tank()
	if h == tank:
		return _tank_travel(c, h)
	var stop := 2.5 + h.slot * 1.3
	return tank.pos if Combat.dist(h, tank) > (stop if h.ai.moving else stop + 1.5) else null


static func _tank_combat(c: Combat, h: Combatant):
	var ai := h.ai
	var es := c.engaged_enemies()
	if es.is_empty():
		return null
	# go in: the fight happens inside the room, not on the threshold
	var pack: Pack = null
	for p in c.packs:
		if p.engaged and not p.cleared:
			pack = p
			break
	if pack and ai.entered != pack.id and h.pos.x >= pack.stand.x - 1.0:
		ai.entered = pack.id
	if pack and ai.entered != pack.id:
		ai.tank_spot = null
		h.target_id = _nearest(es, h).id
		return pack.stand
	# pick up anything that is not on the tank
	if _off_cd(h, "challenge"):
		var loose := es.filter(func(e: Combatant) -> bool:
			return e.target_id != h.id and e.target_id > 0 and e.forced_t <= c.time)
		loose.sort_custom(func(a: Combatant, b: Combatant) -> bool:
			if a.enemy.priority != b.enemy.priority:
				return a.enemy.priority > b.enemy.priority
			return Combat.dist(a, h) < Combat.dist(b, h))
		for e: Combatant in loose:
			if _use(c, h, "challenge", e):
				break
	var near := es.filter(func(e: Combatant) -> bool: return Combat.dist(e, h) <= 3.2 + e.radius * 0.5)
	# stand among the ranged enemies so the melee ones are dragged onto them
	var ranged := es.filter(func(e: Combatant) -> bool: return e.enemy.reach > 5.0)
	if ranged.any(func(e: Combatant) -> bool: return Combat.dist(e, h) > 5.5):
		var mid := Vector3.ZERO
		for e: Combatant in ranged:
			mid += e.pos / ranged.size()
		mid.y = 0
		if Combat.flat(h.pos, mid) > 2.0 and c.can_stand.call(mid):
			ai.tank_spot = null
			if not near.is_empty():
				h.target_id = near[0].id
			return mid
	if near.is_empty():
		ai.tank_spot = null
		var e := _nearest(es, h)
		h.target_id = e.id
		return e.pos
	var best: Combatant = near[0]
	for e: Combatant in near:
		if e.enemy.priority > best.enemy.priority or (e.enemy.priority == best.enemy.priority and e.id == h.target_id):
			best = e
	h.target_id = best.id
	if ai.tank_spot == null:
		ai.tank_spot = h.pos
	return ai.tank_spot if Combat.flat(h.pos, ai.tank_spot) > (0.4 if ai.moving else 1.0) else null


# Melee damage dealers stand behind the enemy: on the far side of it from whoever it is fighting.
static func _melee_pos(c: Combat, h: Combatant, t: Combatant):
	var tt := c.unit(t.target_id)
	var reach := 2.8 + t.radius * 0.5
	if tt and tt != h and tt.alive and tt.team == "hero":
		var p := t.pos + Combat.toward(tt, t) * (t.radius + 1.1)
		if c.can_stand.call(p):
			var settled := Combat.flat(h.pos, p) < (0.5 if h.ai.moving else 1.2) and Combat.dist(h, t) <= reach
			return null if settled else p
	return null if Combat.dist(h, t) <= reach else t.pos


# Hold a spot with range and line of sight to the anchor, out of frontals and ground effects,
# and in the same room as the tank: nobody hangs back behind the doorway.
static func _ranged_pos(c: Combat, h: Combatant, anchor: Combatant):
	var ai := h.ai
	if c.time < ai.pos_t:
		return ai.pos
	ai.pos_t = c.time + 0.3
	var min_d := 4.0 if anchor.team == "enemy" else 0.0
	var tank := c.tank()
	var min_x := c.room_start(tank.pos.x) + 1.5 if tank.alive else -INF
	var valid := func(p: Vector3) -> bool:
		var d := Combat.flat(p, anchor.pos)
		return p.x >= min_x and d <= 21.0 and d >= min_d and c.los.call(p, anchor.pos) \
			and not _in_front(c, p) and _safe_at(c, p) and not _near_idle(c, p)
	if valid.call(h.pos):
		ai.pos = null
		return null
	if ai.pos != null and valid.call(ai.pos):
		return ai.pos
	var best = null
	var best_d := INF
	for r: float in [14.0, 10.0, 18.0, 7.0]:
		for k in 12:
			var a := k / 12.0 * TAU + h.id
			var p := anchor.pos + Vector3(cos(a), 0, sin(a)) * r
			if not c.can_stand.call(p) or not valid.call(p):
				continue
			var d := Combat.flat(p, h.pos) + (0.0 if c.clear_walk.call(h.pos, p) else 12.0)
			if d < best_d:
				best_d = d
				best = p
	ai.pos = best if best != null else anchor.pos
	return ai.pos


static func _combat_goal(c: Combat, h: Combatant):
	var def := h.hero
	if def.role == "tank":
		return _tank_combat(c, h)
	var t := _pick_target(c, h)
	if t:
		h.target_id = t.id
	if def.role == "healer":
		var tank := c.tank()
		var anchor := tank if tank.alive else h
		# go to whoever needs healing and cannot be reached
		for a in c.heroes:
			if a.alive and a != h and _pct(a) < 0.6 and (Combat.dist(a, h) > 28.0 or not c.sees(h, a)):
				anchor = a
		return null if anchor == h else _ranged_pos(c, h, anchor)
	if t == null or not c.can_attack():
		return null
	return _melee_pos(c, h, t) if def.auto_reach < 5.0 else _ranged_pos(c, h, t)


# ---------- actions

# Silences the cast the party has handed to this hero, after a moment to notice it.
static func _kick(c: Combat, h: Combatant) -> void:
	var ab := c._interrupt_of(h)
	if ab == null or not _off_cd(h, ab.id):
		return
	for e in c.enemies:
		var cast := e.cast
		if e.alive and cast and cast.assignee == h.id and c.time - cast.assigned_at >= h.ai.reaction:
			_use(c, h, ab.id, e)
			return


# A heavy blow is winding up on this hero.
static func _buster_on(c: Combat, h: Combatant, boss_only := false) -> bool:
	for e in c.enemies:
		if e.alive and e.cast and e.cast.ab.tank_buster and e.cast.target_id == h.id and e.cast.t >= 0.4 \
				and (not boss_only or e.enemy.boss):
			return true
	return false


static func _reachable(c: Combat, h: Combatant, a: Combatant) -> bool:
	return a == h or (Combat.dist(a, h) <= 30.0 and c.sees(h, a))


# What both healers do first: lift curses, ward whoever is about to take a heavy blow or is
# nearly dead, and use the big cooldown when several are low. Returns the allies in reach,
# most hurt first.
static func _healer_common(c: Combat, h: Combatant, dispel_id: String, ward_id: String, big_id: String) -> Array:
	var allies := c.heroes.filter(func(a: Combatant) -> bool: return a.alive and _reachable(c, h, a))
	if _off_cd(h, dispel_id):
		for a: Combatant in allies:
			if a.auras.any(func(au: Aura) -> bool: return au.dispellable and au.dur - au.t >= h.ai.reaction + 0.3):
				_use(c, h, dispel_id, a)
				break
	if _off_cd(h, ward_id):
		var tank := c.tank()
		var shielded := c.has_aura(tank, "brace") or c.has_aura(tank, "unbreakable")
		var needy: Combatant = null
		for a: Combatant in allies:
			if _pct(a) < 0.3:
				needy = a
				break
		if tank.alive and allies.has(tank) and _buster_on(c, tank, true) and not shielded:
			_use(c, h, ward_id, tank)
		elif needy:
			_use(c, h, ward_id, needy)
	var low := allies.filter(func(a: Combatant) -> bool: return _pct(a) < 0.5).size()
	var very_low := allies.filter(func(a: Combatant) -> bool: return _pct(a) < 0.35).size()
	if low >= 3 or very_low >= 2:
		_use(c, h, big_id)
	allies.sort_custom(func(a: Combatant, b: Combatant) -> bool: return _pct(a) < _pct(b))
	return allies


static func _act(c: Combat, h: Combatant) -> void:
	match h.hero.id:
		"warden": _warden(c, h)
		"mender": _mender(c, h)
		"bloomweaver": _bloomweaver(c, h)
		"duelist": _duelist(c, h)
		"ranger": _ranger(c, h)
		"pyromancer": _pyromancer(c, h)


static func _warden(c: Combat, h: Combatant) -> void:
	_kick(c, h)
	var has_buster := false
	for e in c.engaged_enemies():
		for a in e.enemy.abilities:
			if a.tank_buster and c.level >= a.min_level:
				has_buster = true
	if not c.has_aura(h, "brace"):
		if _buster_on(c, h) or h.res >= 85.0 or (not has_buster and h.res >= 40.0 and _pct(h) < 0.9):
			_use(c, h, "brace")
	if _pct(h) < 0.35:
		_use(c, h, "unbreakable")
	var t := c.unit(h.target_id)
	if t and t.alive and _use(c, h, "strike", t):
		return
	if c.enemies_near(h.pos, 6.0).any(func(e: Combatant) -> bool: return e.engaged):
		_use(c, h, "sweep")


static func _mender(c: Combat, h: Combatant) -> void:
	var allies := _healer_common(c, h, "purify", "ward", "sanctuary")
	if h.cast or h.gcd > 0.0:
		return
	var low: Combatant = allies[0] if not allies.is_empty() else null
	var tank := c.tank()
	var missing := low.max_hp - low.hp if low else 0.0
	if low and _pct(low) < 0.4 and h.res >= 200.0 and _use(c, h, "quick", low):
		return
	if low and (_pct(low) < 0.7 or missing >= 380.0) and _use(c, h, "mend", low):
		return
	if tank.alive and tank.max_hp - tank.hp >= 300.0 and allies.has(tank) and _use(c, h, "mend", tank):
		return
	var t := c.unit(h.target_id)
	if t and t.alive and c.can_attack():
		_use(c, h, "rebuke", t)


static func _bloomweaver(c: Combat, h: Combatant) -> void:
	var allies := _healer_common(c, h, "dew", "bramble", "tide")
	if h.gcd > 0.0:
		return
	var tank := c.tank()
	var low: Combatant = allies[0] if not allies.is_empty() else null
	if low and _pct(low) < 0.6 and not c.has_aura(low, "bark") and _use(c, h, "bark", low):
		return
	var tank_ok := tank.alive and allies.has(tank)
	if tank_ok and not c.has_aura(tank, "bark") and (_pct(tank) < 0.8 or _buster_on(c, tank)) and _use(c, h, "bark", tank):
		return
	var kelped := allies.filter(func(a: Combatant) -> bool: return c.has_aura(a, "vine"))
	var hurt := kelped.filter(func(a: Combatant) -> bool: return _pct(a) < 0.75).size()
	if (hurt >= 2 or kelped.any(func(a: Combatant) -> bool: return _pct(a) < 0.5)) and _use(c, h, "bloom"):
		return
	if tank_ok and not c.has_aura(tank, "vine") and _use(c, h, "vine", tank):
		return
	for a: Combatant in allies:
		if _pct(a) < 0.8 and not c.has_aura(a, "vine"):
			if _use(c, h, "vine", a):
				return
			break
	if tank_ok and _pct(tank) < 0.85 and not c.has_aura(tank, "bark"):
		_use(c, h, "bark", tank)


static func _duelist(c: Combat, h: Combatant) -> void:
	_kick(c, h)
	if _pct(h) < 0.4:
		_use(c, h, "riposte")
	var t := c.unit(h.target_id)
	if t == null or not t.alive or not c.can_attack():
		return
	var n := c.enemies_near(h.pos, 5.0).size()
	if (t.enemy.boss or n >= 3) and Combat.dist(h, t) < 4.0:
		_use(c, h, "bloodrush")
	if h.gcd > 0.0:
		return
	if h.combo >= 5 and _use(c, h, "thrust", t):
		return
	if n >= 3:
		_use(c, h, "whirl")
	else:
		_use(c, h, "slash", t)


static func _ranger(c: Combat, h: Combatant) -> void:
	_kick(c, h)
	if _pct(h) < 0.4:
		_use(c, h, "tumble")
	var t := c.unit(h.target_id)
	if t == null or not t.alive or not c.can_attack():
		return
	var n := c.enemies_near(t.pos, 6.0).size()
	if t.enemy.boss or n >= 3:
		_use(c, h, "hawk")
	if h.gcd > 0.0:
		return
	if n >= 3 and _use(c, h, "volley", t):
		return
	if n < 3 and _use(c, h, "piercing", t):
		return
	_use(c, h, "quickshot", t)


static func _pyromancer(c: Combat, h: Combatant) -> void:
	_kick(c, h)
	if _pct(h) < 0.5:
		_use(c, h, "ember")
	var t := c.unit(h.target_id)
	if t == null or not t.alive or not c.can_attack():
		return
	if t.enemy.boss or c.enemies_near(t.pos, 6.0).size() >= 3:
		_use(c, h, "kindled")
	if h.cast or h.gcd > 0.0:
		return
	if _use(c, h, "burst", t):
		return
	var burning := c.has_aura(t, "ignite%d" % h.id)
	if not burning and t.hp > 300.0 and _use(c, h, "ignite", t):
		return
	if not h.moved:
		_use(c, h, "firebolt", t)
	elif not burning:
		_use(c, h, "ignite", t)


# ---------- the tick

## Decides, for this tick, where the hero wants to be and what it does.
static func think(c: Combat, h: Combatant) -> void:
	var ai := h.ai
	var goal = null
	var urgent := false

	var boss := c.hide_caster()
	if boss and boss.cast.t >= ai.reaction:
		if ai.hide == null:
			ai.hide = _find_hide_spot(c, h, boss)
		if ai.hide != null:
			goal = ai.hide
			urgent = true
	else:
		ai.hide = null
		if _in_danger(c, h):
			if ai.escape == null or not _safe_at(c, ai.escape):
				ai.escape = _find_escape(c, h)
			goal = ai.escape
			urgent = goal != null
		else:
			ai.escape = null

	var usual = null
	if not c.in_combat:
		ai.tank_spot = null
		ai.pos = null
		usual = _ooc_goal(c, h)
	else:
		usual = _combat_goal(c, h)
	if not urgent:
		goal = usual
	# never walk into a telegraph: wait at its edge instead of stepping in and straight back out
	if goal != null and not urgent:
		var d := Combat.flat(h.pos, goal)
		if not _safe_at(c, h.pos.lerp(goal, minf(1.0, 1.0 / maxf(d, 1e-6)))):
			goal = null
	ai.moving = goal != null and Combat.flat(h.pos, goal) > 0.35
	h.has_goal = ai.moving
	if ai.moving:
		h.goal = goal
	if c.in_combat:
		_act(c, h)
