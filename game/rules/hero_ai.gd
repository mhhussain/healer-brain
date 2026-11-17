class_name HeroAI
extends RefCounted

# How the AI plays a hero: where it wants to stand and which ability it uses. It only decides;
# it sets the hero's goal and the scene does the walking. Ported from src/sim/heroAI.ts of the TypeScript game.
# A spot is a Vector3, or null for none.

## The tank has gone in once it is this near the spot it means to hold, in metres.
const ARRIVED := 1.1
## The party keeps this far inside the tank's room from the doorways into it, in metres.
const THRESHOLD := 1.5
## A hero is on its planned spot when it is this near it, in metres.
const ON_SPOT := 2.5
## From a planned spot a ranged hero must be able to reach who it is there for, in metres.
const SPOT_REACH := 28.0

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

# A zone that is no danger to this hero: a place to shelter, or one the hero carries.
static func _harmless(z: Zone, h: Combatant) -> bool:
	return z.safe or (h != null and z.follow_id == h.id)


static func _safe_at(c: Combat, p: Vector3, h: Combatant = null) -> bool:
	for z in c.zones:
		if not _harmless(z, h) and z.holds(p, 0.6):
			return false
	return true


# Close enough to a pack that is not in the fight to wake it.
static func _near_idle(c: Combat, p: Vector3) -> bool:
	for e in c.enemies:
		if e.alive and not e.engaged and Combat.flat(e.pos, p) < 14.0:
			return true
	return false


# So near a pack that is not in the fight that standing there would wake it.
static func _would_wake(c: Combat, p: Vector3) -> bool:
	for e in c.enemies:
		if e.alive and not e.engaged and Combat.flat(e.pos, p) < Combat.AGGRO + 1.5:
			return true
	return false


static func _in_danger(c: Combat, h: Combatant) -> bool:
	for z in c.zones:
		if not _harmless(z, h) and z.t >= h.ai.reaction and z.holds(h.pos, 0.4):
			return true
	return false


# The nearest spot out of danger. Given somewhere to keep near, it is the spot nearest that
# among the first that are near enough to step to: a tank chased off a burning patch again
# and again then goes round where it was holding, not ever further from it.
static func _find_escape(c: Combat, h: Combatant, near = null):
	var best = null
	var found_at := 0.0
	for r: float in [1.5, 2.5, 3.5, 5.0, 6.5, 8.0, 10.0, 13.0]:
		if best != null and r > found_at + 2.0:
			break
		for k in 16:
			var a := k / 16.0 * TAU + h.id
			var p := h.pos + Vector3(cos(a), 0, sin(a)) * r
			if c.can_stand.call(p) and _safe_at(c, p, h) and not _near_idle(c, p) and c.clear_walk.call(h.pos, p):
				if near == null:
					return p
				if best == null:
					found_at = r
				if best == null or Combat.flat(p, near) < Combat.flat(best, near):
					best = p
	return best


# Where the tank keeps near when it is chased off a patch that burns on: where the pull is
# held. Null for anyone else and anything else, who simply take the nearest way out.
static func _holding_near(c: Combat, h: Combatant):
	if h != c.tank() or not c.zones.any(func(z: Zone) -> bool: return z.went and z.linger > 0.0 and z.turn == 0.0 and z.holds(h.pos, 0.4)):
		return null
	var planned = Combat.spot_in(c.fight, h)
	if planned != null:
		return planned
	var packs: Array = c.fight.get("packs", [])
	return (packs[-1] as Pack).stand if not packs.is_empty() else null


# The nearest place to shelter, if a boss has lit any: a spot inside it, each hero a little
# apart from the next.
static func _find_shelter(c: Combat, h: Combatant):
	var best: Zone = null
	for z in c.zones:
		if z.safe and (best == null or Combat.flat(z.pos, h.pos) < Combat.flat(best.pos, h.pos)):
			best = z
	if best == null:
		return null
	var a := h.slot * TAU / 4.0
	var spot := best.pos + Vector3(cos(a), 0, sin(a)) * minf(1.4, best.r * 0.4)
	return spot if c.can_stand.call(spot) else best.pos


# The zone this hero carries, if any: one that goes off wherever the hero is.
static func _carried(c: Combat, h: Combatant) -> Zone:
	for z in c.zones:
		if z.follow_id == h.id and not z.safe:
			return z
	return null


# Where to carry a zone so that it goes off on nobody else: the nearest spot that leaves
# every other hero outside it.
static func _carry_to(c: Combat, h: Combatant, z: Zone):
	var clear := func(p: Vector3) -> bool:
		for o in c.heroes:
			if o != h and o.alive and Combat.flat(o.pos, p) < z.r + 1.5:
				return false
		return true
	if clear.call(h.pos):
		return null
	for r: float in [4.0, 7.0, 10.0, 13.0, 17.0, 21.0]:
		for k in 16:
			var a := k / 16.0 * TAU + h.id
			var p := h.pos + Vector3(cos(a), 0, sin(a)) * r
			if c.can_stand.call(p) and clear.call(p) and _safe_at(c, p, h) and not _near_idle(c, p) and c.clear_walk.call(h.pos, p):
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


# Whether a spot is in front of an enemy that turns aside what is thrown at its front.
static func _guarded_from(e: Combatant, p: Vector3) -> bool:
	return e.team == "enemy" and e.enemy.front_guard > 0.0 and Combat.in_front(e, p)


# ---------- targeting and positioning

static func _pick_target(c: Combat, h: Combatant) -> Combatant:
	var tank_target := c.tank().target_id
	var melee := h.hero.auto_reach < 5.0
	var best: Combatant = null
	var best_s := -INF
	for e in c.engaged_enemies():
		# of two nets, the one that holds the healer is cut first
		var healer := _healer(c)
		var holds_healer: bool = healer != null and e.flags.get("holds", 0) == healer.id
		var s: float = e.enemy.priority * 1000.0 + (300.0 if holds_healer else 0.0) - _pct(e) * 100.0 + (60.0 if e.id == h.target_id else 0.0) \
			+ (80.0 if e.id == tank_target else 0.0) - Combat.dist(h, e) * (3.0 if melee else 0.3)
		if s > best_s:
			best_s = s
			best = e
	return best


# Where a hero waits for a pull to begin: its planned spot, if it has one that can be stood on
# without waking anything. Otherwise null, and it keeps with the tank.
static func _waits_at(c: Combat, pull: Dictionary, h: Combatant):
	var spot = Combat.spot_in(pull, h)
	return null if spot == null or h == c.tank() or _near_idle(c, spot) else spot


# Everyone is alive and well, and where they should be: on their planned spot, or with the tank.
static func _party_ready(c: Combat, tank: Combatant, pull: Dictionary) -> bool:
	for h in c.heroes:
		if not h.alive or _pct(h) < 0.8:
			return false
		var spot = _waits_at(c, pull, h)
		var there: bool = spot != null and Combat.flat(h.pos, spot) <= ON_SPOT
		# the AI goes to its spot; you may wait on yours or come along
		var ai_led := not h.is_player or c.autoplay
		if (ai_led and spot != null and not there) or (not there and Combat.dist(h, tank) > 22.0 and (spot == null or not ai_led)):
			return false
	var healer := _healer(c)
	return healer == null or healer.res >= healer.res_max * 0.6


# Out of a fight, the tank leads the way to the first pack of the next pull and wakes it once
# everyone is ready, or at once if the plan says so.
static func _tank_travel(c: Combat, h: Combatant):
	var pull := c.next_pull()
	if pull.is_empty():
		return null
	var pack: Pack = pull.packs[0]
	var ok: bool = pull.go or _party_ready(c, h, pull)
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
	# do not run off without the player, unless they are waiting where the plan puts them
	var human := null if c.autoplay else c.player
	if human and human != h and Combat.dist(human, h) > 28.0:
		var spot = Combat.spot_in(pull, human)
		if spot == null or Combat.flat(human.pos, spot) > ON_SPOT:
			return null
	return pack.pull_from


# Keeping up with the tank, a few steps behind, each in its own place.
static func _follow(h: Combatant, tank: Combatant):
	var stop := 2.5 + h.slot * 1.3
	return tank.pos if Combat.dist(h, tank) > (stop if h.ai.moving else stop + 1.5) else null


# Standing on a spot, with a little slack so a hero does not shuffle about on it.
static func _hold(h: Combatant, spot: Vector3):
	return spot if Combat.flat(h.pos, spot) > (0.4 if h.ai.moving else 1.0) else null


static func _ooc_goal(c: Combat, h: Combatant):
	var tank := c.tank()
	if h == tank:
		return _tank_travel(c, h)
	var spot = _waits_at(c, c.next_pull(), h)
	return _hold(h, spot) if spot != null else _follow(h, tank)


static func _tank_combat(c: Combat, h: Combatant):
	var ai := h.ai
	var es := c.engaged_enemies().filter(func(e: Combatant) -> bool: return not e.enemy.still)
	if es.is_empty():
		return null
	# with every damage dealer down or held fast, nobody else will cut a net: the tank does,
	# and whatever it was fighting comes along
	var nets := c.engaged_enemies().filter(func(e: Combatant) -> bool: return e.enemy.still)
	if not nets.is_empty() and not c.heroes.any(func(o: Combatant) -> bool: return o.hero.role == "dps" and o.alive and not c.held(o)):
		var net: Combatant = _nearest(nets, h)
		h.target_id = net.id
		ai.tank_spot = null
		return null if Combat.dist(net, h) <= 2.6 + net.radius * 0.5 else net.pos
	# gather: wake each pack of the pull in turn, with a hail as soon as one can be given, or
	# else by walking at it, and bring them all along
	var woken: Pack = null
	for pack: Pack in c.fight.get("packs", []):
		if pack.cleared:
			continue
		if pack.engaged:
			woken = pack
			continue
		var near: Combatant = _nearest(pack.units.filter(func(e: Combatant) -> bool: return e.alive), h)
		if near == null:
			continue
		ai.tank_spot = null
		h.target_id = _nearest(es, h).id
		if Combat.dist(near, h) <= 27.0 and c.sees(h, near) and _off_cd(h, "challenge"):
			_use(c, h, "challenge", near)
		return near.pos
	# go in: to the spot the plan holds this pull at, or else well inside the room of the pack
	# woken last, so the fight is not on the threshold
	var planned = Combat.spot_in(c.fight, h)
	var hold = planned if planned != null else woken.stand if woken else null
	if hold != null and not ai.arrived:
		if Combat.flat(h.pos, hold) <= ARRIVED:
			ai.arrived = true
		else:
			ai.tank_spot = null
			h.target_id = _nearest(es, h).id
			return hold
	# pick up anything that is not on the tank
	if _off_cd(h, "challenge"):
		var loose := es.filter(func(e: Combatant) -> bool:
			return e.target_id != h.id and e.target_id > 0 and e.forced_t <= c.time and not e.enemy.still)
		loose.sort_custom(func(a: Combatant, b: Combatant) -> bool:
			if a.enemy.priority != b.enemy.priority:
				return a.enemy.priority > b.enemy.priority
			return Combat.dist(a, h) < Combat.dist(b, h))
		for e: Combatant in loose:
			if _use(c, h, "challenge", e):
				break
	var near := es.filter(func(e: Combatant) -> bool: return Combat.dist(e, h) <= 3.2 + e.radius * 0.5)
	# a planned spot is held: the tank steps off it only to get out of danger
	if planned != null:
		ai.tank_spot = planned
		var first: Combatant = _nearest(near if not near.is_empty() else es, h)
		for e: Combatant in near:
			if e.enemy.priority > first.enemy.priority or (e.enemy.priority == first.enemy.priority and e.id == h.target_id):
				first = e
		h.target_id = first.id
		return _hold(h, planned)
	# stand among the ranged enemies so the melee ones are dragged onto them
	var ranged := es.filter(func(e: Combatant) -> bool: return e.enemy.reach > 5.0 and not e.enemy.still)
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
	# a spot that has caught fire is given up for wherever the tank stands now
	if ai.tank_spot != null and c.zones.any(func(z: Zone) -> bool: return z.went and not z.safe and z.holds(ai.tank_spot, 0.6)):
		ai.tank_spot = null
	if ai.tank_spot == null:
		ai.tank_spot = h.pos
	return ai.tank_spot if Combat.flat(h.pos, ai.tank_spot) > (0.4 if ai.moving else 1.0) else null


# Melee damage dealers stand behind the enemy: on the far side of it from whoever it is fighting.
# A planned spot is the side to attack from instead, unless that side is in front of something
# that cleaves.
static func _melee_pos(c: Combat, h: Combatant, t: Combatant, spot = null):
	var tt := c.unit(t.target_id)
	var reach := 2.8 + t.radius * 0.5
	var from = null
	if spot != null and Combat.flat(spot, t.pos) > 0.5:
		from = t.pos + Vector3(spot.x - t.pos.x, 0, spot.z - t.pos.z).normalized() * (t.radius + 1.1)
		if not c.can_stand.call(from) or _in_front(c, from):
			from = null
	if from == null and tt and tt != h and tt.alive and tt.team == "hero":
		from = t.pos + Combat.toward(tt, t) * (t.radius + 1.1)
		if not c.can_stand.call(from):
			from = null
		elif _would_wake(c, from):
			# behind it is too near a pack that sleeps: the nearest side that is not, or stay put
			var back := Combat.toward(tt, t)
			from = null
			for turn: float in [1.0, -1.0, 2.0, -2.0]:
				var side := t.pos + back.rotated(Vector3.UP, turn) * (t.radius + 1.1)
				if c.can_stand.call(side) and not _would_wake(c, side) and not _in_front(c, side):
					from = side
					break
			if from == null:
				return null
	if from != null:
		var settled := Combat.flat(h.pos, from) < (0.5 if h.ai.moving else 1.2) and Combat.dist(h, t) <= reach
		return null if settled else from
	return null if Combat.dist(h, t) <= reach else t.pos


# Whether a planned spot does its job: from it the hero can reach whoever it is there for, and
# it is not in front of something that cleaves. If not, the hero finds a spot of its own.
static func _spot_serves(c: Combat, spot: Vector3, who: Combatant) -> bool:
	return Combat.flat(spot, who.pos) <= SPOT_REACH and c.los.call(spot, who.pos) and not _in_front(c, spot) and not _guarded_from(who, spot)


# Hold a spot with range and line of sight to the anchor, out of frontals and ground effects,
# and in the same room as the tank: nobody hangs back behind the doorway.
static func _ranged_pos(c: Combat, h: Combatant, anchor: Combatant):
	var ai := h.ai
	if c.time < ai.pos_t:
		return ai.pos
	ai.pos_t = c.time + 0.3
	var min_d := 4.0 if anchor.team == "enemy" else 0.0
	var tank := c.tank()
	var valid := func(p: Vector3) -> bool:
		var d := Combat.flat(p, anchor.pos)
		return (not tank.alive or c.same_room(tank.pos, p, THRESHOLD)) and d <= 21.0 and d >= min_d \
			and c.los.call(p, anchor.pos) and not _in_front(c, p) and not _guarded_from(anchor, p) and _safe_at(c, p, h) and not _near_idle(c, p)
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
	var spot = Combat.spot_in(c.fight, h)
	var melee := def.auto_reach < 5.0
	if def.role == "healer":
		var tank := c.tank()
		var anchor := tank if tank.alive else h
		# go to whoever needs healing and cannot be reached
		for a in c.heroes:
			if a.alive and a != h and _pct(a) < 0.6 and (Combat.dist(a, h) > 28.0 or not c.sees(h, a)):
				anchor = a
		if anchor == h:
			return null
		# while the tank is still gathering and in no trouble, the spot is where to wait
		var waiting: bool = not c.gathered() and _pct(anchor) >= 0.6 and not _in_front(c, spot) if spot != null else false
		if spot != null and (waiting or _spot_serves(c, spot, anchor)):
			return _hold(h, spot)
		return _ranged_pos(c, h, anchor)
	if t == null or not c.can_attack():
		# holding its damage: on its spot if it has one to stand on, and keeping up with a
		# tank that is still gathering if it has not
		if spot != null and not melee:
			return _hold(h, spot)
		return null if c.gathered() else _follow(h, c.tank())
	if melee:
		return _melee_pos(c, h, t, spot)
	return _hold(h, spot) if spot != null and _spot_serves(c, spot, t) else _ranged_pos(c, h, t)


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


# A trinket that is pressed: used when it would count. The Great Key when badly hurt; the Bell
# Rope, the Lens and the Pitch Pot on a boss or a big pull; the Seal on a cast nobody else has
# been given; the Tide Glass when running low.
static func _trinket(c: Combat, h: Combatant) -> void:
	var fighting := c.engaged_enemies()
	var big := fighting.size() >= 4 or fighting.any(func(e: Combatant) -> bool: return e.enemy.boss and e.hp > e.max_hp * 0.2)
	# an epic's ability: Stormcalling for a boss or a big pull, Bulwarked when hurt
	if h.weapon_does == "stormcalling" and h.weapon_cd <= 0.0 and big and c.can_attack():
		c.use_gear(h, 0)
	if h.armour_does == "bulwarked" and h.armour_cd <= 0.0 and _pct(h) < 0.5:
		c.use_gear(h, 1)
	if h.trinket_cd > 0.0 or not Items.pressed(h.trinket):
		return
	var t := c.unit(h.target_id)
	var foe: Combatant = t if t and t.alive and t.team == "enemy" and t.engaged else null
	match h.trinket.kind:
		"vesper_bell":
			# for a boss or a big pull, or when two casts want silencing at once
			var casting := fighting.filter(func(e: Combatant) -> bool: return e.cast != null and e.cast.interruptible).size()
			if (big or casting >= 2) and c.can_attack():
				c.use_trinket(h)
		"great_key":
			if _pct(h) < 0.45:
				c.use_trinket(h)
		"bell_rope":
			if big and c.can_attack():
				c.use_trinket(h)
		"lens":
			var wanted := c.alive_heroes().any(func(a: Combatant) -> bool: return _pct(a) < 0.6) if h.hero.role == "healer" else big and foe != null and c.can_attack()
			if wanted:
				c.use_trinket(h)
		"pitch_pot":
			if foe and c.can_attack() and (foe.enemy.boss or fighting.filter(func(e: Combatant) -> bool: return Combat.dist(e, foe) <= 5.0).size() >= 3):
				c.use_trinket(h, foe)
		"tide_glass":
			if h.res < h.res_max * 0.25:
				c.use_trinket(h)
		"seal":
			for e in fighting:
				var cast := e.cast
				if cast and cast.interruptible and cast.assignee == 0 and cast.t >= maxf(0.5, h.ai.reaction) and cast.total - cast.t > 0.2:
					if c.use_trinket(h, e) == "":
						return


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
	if c.held(h):
		ai.moving = false
		h.has_goal = false
		return

	var boss := c.hide_caster()
	var shelter = _find_shelter(c, h)
	var carried := _carried(c, h)
	if boss and boss.cast.t >= ai.reaction:
		if ai.hide == null:
			ai.hide = _find_hide_spot(c, h, boss)
		if ai.hide != null:
			goal = ai.hide
			urgent = true
	elif shelter != null:
		# a place has been lit to stand in: nothing else matters until it is reached
		ai.hide = null
		goal = shelter
		urgent = true
	else:
		ai.hide = null
		if _in_danger(c, h):
			if ai.escape == null or not _safe_at(c, ai.escape, h):
				ai.escape = _find_escape(c, h, _holding_near(c, h))
			goal = ai.escape
			urgent = goal != null
		else:
			ai.escape = null
			if carried and carried.t >= ai.reaction:
				goal = _carry_to(c, h, carried)
				urgent = goal != null

	var usual = null
	if not c.in_combat:
		ai.tank_spot = null
		ai.pos = null
		ai.arrived = false
		usual = _ooc_goal(c, h)
	else:
		usual = _combat_goal(c, h)
	# round the packs that are not to be woken, between pulls and in a fight alike
	if usual != null:
		usual = c.steer(h, usual)
	if not urgent:
		goal = usual
	# never walk into a telegraph: wait at its edge instead of stepping in and straight back out.
	# A patch that burns on is different: it is walked round, and crossed if there is no way
	# round, but never stopped in.
	if goal != null and not urgent:
		var d := Combat.flat(h.pos, goal)
		var step := h.pos.lerp(goal, minf(1.0, 1.0 / maxf(d, 1e-6)))
		for z in c.zones:
			if _harmless(z, h) or not z.holds(step, 0.6):
				continue
			if z.went and z.linger > 0.0 and not z.holds(usual, 0.6):
				continue
			goal = null
			break
	ai.moving = goal != null and Combat.flat(h.pos, goal) > 0.35
	h.has_goal = ai.moving
	if ai.moving:
		h.goal = goal
	if c.in_combat:
		_trinket(c, h)
		_act(c, h)
