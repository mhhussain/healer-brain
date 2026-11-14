class_name Enemies
extends RefCounted

# The enemies of the Drowned Abbey, as data. Ported from src/sim/enemies.ts; the numbers are the
# tuned ones.

const GREEN := Color("8fe6b4")

static var _defs := {}


static func by_id(id: String) -> EnemyDef:
	if _defs.is_empty():
		for def: EnemyDef in [_brute(), _hexer(), _archer(), _shaman(), _berserker(), _overseer(),
				_krogg(), _velisse(), _hatchling(), _sulmar()]:
			_defs[def.id] = def
	return _defs.get(id)


static func _ab(fields: Dictionary) -> EnemyAbility:
	return EnemyAbility.make(fields)


# ---------- shared shapes

## A swing across a cone in front of the enemy, shown on the floor while it winds up.
static func _cone(name: String, id: String, cd: float, first: float, cast: float, half: float, reach: float, dmg: float) -> EnemyAbility:
	var ab := _ab({"id": id, "name": name, "cd": cd, "first": first, "cast": cast, "targeting": "threat"})
	ab.start = func(c: Combat, e: Combatant, t: Combatant, cs: Cast) -> void:
		cs.dir = Combat.toward(e, t) if t else e.facing
		c.add_zone({"kind": "cone", "pos": e.pos, "r": reach, "dir": cs.dir, "half": half, "delay": cast,
			"dmg": dmg, "type": "phys", "owner_id": e.id, "tied": true})
	return ab


## One heavy blow on whoever it is fighting, after a short wind-up.
static func _buster(name: String, id: String, cd: float, first: float, dmg: float, min_level := 0) -> EnemyAbility:
	var ab := _ab({"id": id, "name": name, "cd": cd, "first": first, "cast": 1.5, "min_level": min_level,
		"targeting": "threat", "tank_buster": true, "melee": true})
	ab.finish = func(c: Combat, e: Combatant, t: Combatant) -> void:
		if t and Combat.dist(e, t) <= 5.0:
			c.damage(e, t, dmg, "phys")
	return ab


static func _circles_under(c: Combat, e: Combatant, targets: Array, r: float, delay: float, dmg: float) -> void:
	for h: Combatant in targets:
		c.add_zone({"kind": "circle", "pos": h.pos, "r": r, "delay": delay, "dmg": dmg, "type": "magic", "owner_id": e.id})


## Below a share of its health it hits harder and faster for the rest of the fight.
static func _enrage(low: float, low_from_level_3: float) -> Callable:
	return func(c: Combat, e: Combatant) -> void:
		var below := low_from_level_3 if c.level >= 3 else low
		if e.hp / e.max_hp < below and not c.has_aura(e, "enrage"):
			c.add_aura(e, {"id": "enrage", "name": "Fervour", "dur": 9999.0, "src_id": e.id, "done": 1.25, "haste": 1.5})
			c.text(e.pos, "Fervour", Color("ef5d4a"))


# ---------- the keepers

static func _brute() -> EnemyDef:
	return EnemyDef.make({
		"id": "brute", "name": "Drowned Porter", "hp": 2300.0, "radius": 0.7, "reach": 2.3, "priority": 1,
		"auto_dmg": 46.0, "auto_interval": 1.5, "auto_type": "phys",
		"abilities": [_buster("Heavy Load", "crush", 10.0, 5.0, 240.0, 3)],
	})


static func _hexer() -> EnemyDef:
	var wither := _ab({"id": "wither", "name": "Withering Verse", "cd": 12.0, "first": 6.0, "cast": 2.5, "min_level": 3,
		"interruptible": true, "importance": 2, "targeting": "random", "needs_los": true})
	wither.finish = func(c: Combat, e: Combatant, t: Combatant) -> void:
		if t:
			c.add_aura(t, {"id": "wither", "name": "Withering Verse", "dur": 10.0, "src_id": e.id, "debuff": true,
				"dispellable": true, "tick_every": 1.0, "tick_dmg": 38.0})
	var bolt := _ab({"id": "darkbolt", "name": "Sour Note", "cd": 2.0, "cast": 2.5, "interruptible": true, "importance": 1,
		"targeting": "random", "needs_los": true})
	bolt.finish = func(c: Combat, e: Combatant, t: Combatant) -> void:
		if t:
			c.damage(e, t, 165.0, "magic")
	return EnemyDef.make({
		"id": "hexer", "name": "Brine Cantor", "hp": 1700.0, "radius": 0.6, "reach": 24.0, "priority": 2,
		"abilities": [wither, bolt],
	})


static func _archer() -> EnemyDef:
	var rain := _ab({"id": "arrowrain", "name": "Rain of Hooks", "cd": 9.0, "cast": 0.0, "min_level": 3, "targeting": "random"})
	rain.finish = func(c: Combat, e: Combatant, t: Combatant) -> void:
		if t:
			_circles_under(c, e, [t], 3.5, 1.6, 210.0)
	return EnemyDef.make({
		"id": "archer", "name": "Net-Brother", "hp": 1700.0, "radius": 0.6, "reach": 24.0, "priority": 1,
		"auto_dmg": 58.0, "auto_interval": 2.0, "auto_type": "phys",
		"abilities": [rain],
	})


static func _shaman() -> EnemyDef:
	var alms := _ab({"id": "restore", "name": "Alms", "cd": 8.0, "first": 5.0, "cast": 2.5, "interruptible": true,
		"importance": 2, "targeting": "self"})
	alms.ready = func(c: Combat, _e: Combatant) -> bool:
		return c.engaged_enemies().any(func(o: Combatant) -> bool: return o.hp < o.max_hp * 0.85)
	alms.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		var best: Combatant = null
		for o: Combatant in c.engaged_enemies():
			if best == null or o.hp / o.max_hp < best.hp / best.max_hp:
				best = o
		if best:
			var amt := minf(best.max_hp - best.hp, best.max_hp * (0.35 if c.level >= 3 else 0.2))
			best.hp += amt
			c.text(best.pos, "+%d" % roundi(amt), GREEN)
			c.beam(e, best, GREEN)
	return EnemyDef.make({
		"id": "shaman", "name": "Tide Almoner", "hp": 1500.0, "radius": 0.6, "reach": 24.0, "priority": 3,
		"auto_dmg": 34.0, "auto_interval": 2.0, "auto_type": "magic",
		"abilities": [alms],
	})


static func _berserker() -> EnemyDef:
	return EnemyDef.make({
		"id": "berserker", "name": "Penitent", "hp": 2100.0, "radius": 0.7, "reach": 2.3, "priority": 1,
		"auto_dmg": 38.0, "auto_interval": 1.0, "auto_type": "phys",
		"passive": _enrage(0.3, 0.5),
	})


static func _overseer() -> EnemyDef:
	return EnemyDef.make({
		"id": "overseer", "name": "The Prior", "hp": 4600.0, "elite": true, "radius": 0.95, "reach": 2.3, "priority": 1, "frontal": true,
		"auto_dmg": 68.0, "auto_interval": 1.6, "auto_type": "phys",
		"abilities": [_cone("Banner Sweep", "sweepcut", 9.0, 5.0, 2.0, 0.87, 9.0, 380.0)],
	})


# ---------- the three bosses

static func _krogg() -> EnemyDef:
	var stones := _ab({"id": "tremor", "name": "Falling Stones", "cd": 10.0, "first": 4.0, "cast": 0.0, "min_level": 6, "targeting": "self"})
	stones.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		_circles_under(c, e, c.random_heroes(2), 4.0, 1.6, 300.0)
	return EnemyDef.make({
		"id": "krogg", "name": "Brother Krogg", "hp": 27000.0, "boss": true, "radius": 1.5, "reach": 2.6, "priority": 0, "frontal": true,
		"auto_dmg": 100.0, "auto_interval": 1.6, "auto_type": "phys",
		"abilities": [
			_buster("The Great Key", "skullcrack", 12.0, 6.0, 700.0),
			_cone("Chain Sweep", "rendingsweep", 15.0, 10.0, 2.2, 1.05, 11.0, 480.0),
			stones,
		],
		"passive": _krogg_frenzy,
	})


static func _krogg_frenzy(c: Combat, e: Combatant) -> void:
	if e.hp / e.max_hp < 0.3 and not c.has_aura(e, "frenzy"):
		c.add_aura(e, {"id": "frenzy", "name": "None Shall Pass", "dur": 9999.0, "src_id": e.id, "haste": 1.3})
		c.alert("Brother Krogg bars the gate. None shall pass!")


static func _velisse() -> EnemyDef:
	var mend := _ab({"id": "broodmending", "name": "Bedside Manner", "cd": 20.0, "first": 14.0, "cast": 3.0, "interruptible": true,
		"importance": 2, "targeting": "self"})
	mend.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		var amt := minf(e.max_hp - e.hp, e.max_hp * 0.1)
		e.hp += amt
		c.text(e.pos, "+%d" % roundi(amt), GREEN)
	var brood := _ab({"id": "brood", "name": "Wake the Ward", "cd": 25.0, "first": 8.0, "cast": 0.0, "targeting": "self"})
	brood.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		c.alert("The brinelings wake")
		for i in 3:
			var a := c.rng() * TAU
			var at := e.pos + Vector3(cos(a), 0, sin(a)) * 4.0
			if not c.can_stand.call(at):
				at = e.pos
			var h := c.spawn_enemy("hatchling", at, e.pack_id, true)
			var t := c.random_hero()
			if t:
				c.add_threat(h, t.id, 30.0)
	return EnemyDef.make({
		"id": "velisse", "name": "Sister Velisse", "hp": 23000.0, "boss": true, "radius": 1.4, "reach": 2.6, "priority": 0,
		"auto_dmg": 82.0, "auto_interval": 1.6, "auto_type": "phys",
		"abilities": [mend, brood],
	})


static func _hatchling() -> EnemyDef:
	var spit := _ab({"id": "venombolt", "name": "Brine Spit", "cd": 2.5, "cast": 2.0, "interruptible": true, "importance": 1,
		"targeting": "random", "needs_los": true})
	spit.finish = func(c: Combat, e: Combatant, t: Combatant) -> void:
		if t:
			c.damage(e, t, 90.0, "magic")
	return EnemyDef.make({
		"id": "hatchling", "name": "Brineling", "hp": 480.0, "radius": 0.5, "reach": 2.3, "priority": 4,
		"auto_dmg": 28.0, "auto_interval": 1.2, "auto_type": "phys",
		"abilities": [spit],
		"on_death": _hatchling_bursts,
	})


static func _hatchling_bursts(c: Combat, e: Combatant) -> void:
	if c.level >= 6:
		c.add_zone({"kind": "circle", "pos": e.pos, "r": 3.5, "delay": 1.5, "dmg": 250.0, "type": "magic"})


static func _sulmar() -> EnemyDef:
	var toll := _ab({"id": "annihilation", "name": "The Last Toll", "cd": 1.0, "cast": 5.0, "hide": true, "targeting": "self"})
	# once at two thirds health and once at one third
	toll.ready = func(_c: Combat, e: Combatant) -> bool:
		var part := e.hp / e.max_hp
		return (part <= 0.66 and not e.flags.has("a1")) or (part <= 0.33 and not e.flags.has("a2"))
	toll.start = func(c: Combat, e: Combatant, _t: Combatant, _cs: Cast) -> void:
		e.flags["a2" if e.flags.has("a1") else "a1"] = true
		c.alert("The Last Toll. Hide behind a pillar!")
	toll.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		var used := {}
		for h in c.heroes:
			if not h.alive:
				continue
			var pillar: int = c.blocker.call(e.pos, h.pos)
			if c.sees(e, h):
				c.damage(e, h, h.max_hp * 0.9, "magic", {"raw": true})
			elif pillar >= 0:
				used[pillar] = true
		c.ring(e.pos, 30.0, Color("f0b54a"))
		# from level 6 a pillar only shelters you once
		if c.level >= 6:
			for pillar: int in used:
				c.destroy_pillar(pillar)
	var dirge := _ab({"id": "dirge", "name": "Dirge", "cd": 20.0, "first": 10.0, "cast": 5.0, "targeting": "self"})
	dirge.tick = func(c: Combat, e: Combatant, _cs: Cast) -> void:
		for h: Combatant in c.alive_heroes():
			c.damage(e, h, 58.0, "magic", {"no_beam": true})
	var salt := _ab({"id": "ashfall", "name": "Saltfall", "cd": 11.0, "first": 5.0, "cast": 0.0, "targeting": "self"})
	salt.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		_circles_under(c, e, c.alive_heroes(), 3.5, 1.6, 320.0)
	var brand := _ab({"id": "brand", "name": "Brine Brand", "cd": 17.0, "first": 8.0, "cast": 0.0, "targeting": "self"})
	brand.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		for h: Combatant in c.random_heroes(2):
			c.add_aura(h, {"id": "brand", "name": "Brine Brand", "dur": 12.0, "src_id": e.id, "debuff": true,
				"dispellable": true, "tick_every": 1.0, "tick_dmg": 42.0})
	return EnemyDef.make({
		"id": "sulmar", "name": "Abbot Sulmar", "hp": 28000.0, "boss": true, "radius": 1.5, "reach": 2.6, "priority": 0,
		"auto_dmg": 88.0, "auto_interval": 1.7, "auto_type": "phys",
		"abilities": [toll, dirge, salt, brand],
	})
