class_name Enemies
extends RefCounted

# The enemies of the Drowned Abbey and of Tollhaven, as data. Ported from src/sim/enemies.ts of the TypeScript game; the numbers are the
# tuned ones.

const GREEN := Color("8fe6b4")
const GOLD := Color("f0b54a")
const SLATE := Color("9fb0b1")
## How far a Tide Crier's cry carries, in metres.
const CRY_REACH := 35.0
## How wide a lit circle is when the Keeper puts the lights out, in metres from its middle.
const LIT := 4.5

## What each enemy does, in words: [name, what it does, the level it starts at]. The map shows
## these. An ability added to an enemy needs a line here; the tests check.
const TRAITS := {
	"brute": [["Heavy Load", "A heavy blow on whoever it is fighting, after a wind-up.", 3]],
	"hexer": [
		["Sour Note", "A bolt at a random hero. It can be silenced.", 1],
		["Withering Verse", "A curse that wears a hero down for 10 s. Silence it, or cleanse it.", 3]],
	"archer": [["Rain of Hooks", "A circle on the floor under a random hero. Step out of it.", 3]],
	"shaman": [["Alms", "Heals the most hurt enemy, and more from level 3. Silence it, and kill the Almoner first.", 1]],
	"berserker": [["Fervour", "Below 30% health it hits a quarter harder and half again as fast. From level 3, below 50%.", 1]],
	"overseer": [
		["Banner Sweep", "A cone in front of it, shown on the floor. Only the tank should stand there.", 1],
		["Rally", "Enemies within 15 m of it hit 15% harder while it lives.", 3]],
	"krogg": [
		["The Great Key", "A heavy blow on the tank, after a wind-up. Brace for it.", 1],
		["Chain Sweep", "A wide cone in front of him, shown on the floor.", 1],
		["None Shall Pass", "Below 30% health he attacks 30% faster.", 1],
		["Falling Stones", "Circles on the floor under two heroes.", 6]],
	"velisse": [
		["Wake the Ward", "Every 25 s three Brinelings wake and spit brine, which can be silenced. The tank picks them up; kill them.", 1],
		["Bedside Manner", "She heals herself for a tenth of her health. Silence it.", 1],
		["Bursting", "A Brineling leaves a circle on the floor where it dies.", 6]],
	"hatchling": [["Brine Spit", "A bolt at a random hero. It can be silenced.", 1]],
	"sulmar": [
		["Dirge", "Hurts everyone for 5 s, every 20 s. Heal through it.", 1],
		["Saltfall", "A circle on the floor under every hero. Step out of it.", 1],
		["Brine Brand", "A burning curse on two heroes. Cleanse it.", 1],
		["The Last Toll", "At 66% and 33% health: 5 s to get out of his sight, behind a pillar, or be all but killed.", 1],
		["Falling Pillars", "The Last Toll brings down the pillar that was hidden behind.", 6]],
	"deckhand": [["Many Hands", "Weak, and six to a pack. Anything that hits several at once is well spent on them.", 1]],
	"crier": [["Cry the Hour", "A 3 s cast that wakes the nearest sleeping pack within 35 m. Silence it, or kill the Crier first.", 1]],
	"mate": [
		["Tarred Shield", "It takes 60% less damage from the front. The tank turns it away; everyone else hits its back.", 1],
		["Caulking Maul", "A heavy blow on whoever it is fighting, after a wind-up.", 3]],
	"dredger": [["Grapple", "Hooks the hero standing furthest off and drags them to its feet. Out of its sight, you cannot be hooked.", 1]],
	"hask": [
		["Cast Net", "Nets a hero, who cannot move or act until the net is cut down. The net is a target. From level 6, two heroes at once, in nets half as stout.", 1],
		["Haul", "10 s after a net lands she drags everyone still netted to her feet, net and all, and strikes all within 7 m.", 1],
		["Gutting Knife", "A heavy blow on the tank, after a wind-up.", 3]],
	"net": [["Net", "Holds a hero fast and squeezes. Cut it down.", 1]],
	"corrow": [
		["The Audit", "Three casts one after another, each to be silenced: take turns. One that lands taxes a hero, who is hurt and hits a fifth less until cleansed. Four casts from level 6.", 1],
		["Seize", "Marks a hero with a wide circle that goes off in 5 s wherever they are. Carry it away from the others.", 1],
		["Stamp and Seal", "A heavy blow on the tank, after a wind-up. Brace for it.", 1]],
	"garrow": [
		["Launch", "A hull runs down one of the three slips: a lane right across the dock, with 3 s of warning. From level 6 a second crosses it.", 1],
		["Pitch Pot", "Thrown at the tank's feet every 9 s. It leaves a patch that burns for 26 s, so he must be kept moving.", 1],
		["The Adze", "A heavy blow on the tank, after a wind-up. Brace for it.", 1]],
	"keeper": [
		["The Beam", "A cone of light that turns slowly round him for 11 s and burns whoever it falls on. Keep ahead of it, or behind a pillar. It turns faster from level 6.", 1],
		["Lights Out", "At 60% and 30% health: 5 s to reach one of three lit circles, or be all but killed.", 1],
		["Undertow", "Hurts everyone for 5 s, every 22 s. Heal through it.", 1]],
}

static var _defs := {}


static func by_id(id: String) -> EnemyDef:
	if _defs.is_empty():
		for def: EnemyDef in [_brute(), _hexer(), _archer(), _shaman(), _berserker(), _overseer(),
				_krogg(), _velisse(), _hatchling(), _sulmar(),
				_deckhand(), _crier(), _mate(), _dredger(), _hask(), _net(), _corrow(), _garrow(), _keeper()]:
			def.traits = TRAITS.get(def.id, [])
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
		"id": "brute", "name": "Drowned Porter", "hp": 2300.0, "count": 4, "radius": 0.7, "reach": 2.3, "priority": 1,
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
		"id": "hexer", "name": "Brine Cantor", "hp": 1700.0, "count": 3, "radius": 0.6, "reach": 24.0, "priority": 2,
		"abilities": [wither, bolt],
	})


static func _archer() -> EnemyDef:
	var rain := _ab({"id": "arrowrain", "name": "Rain of Hooks", "cd": 9.0, "cast": 0.0, "min_level": 3, "targeting": "random"})
	rain.finish = func(c: Combat, e: Combatant, t: Combatant) -> void:
		if t:
			_circles_under(c, e, [t], 3.5, 1.6, 210.0)
	return EnemyDef.make({
		"id": "archer", "name": "Net-Brother", "hp": 1700.0, "count": 3, "radius": 0.6, "reach": 24.0, "priority": 1,
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
		"id": "shaman", "name": "Tide Almoner", "hp": 1500.0, "count": 3, "radius": 0.6, "reach": 24.0, "priority": 3,
		"auto_dmg": 34.0, "auto_interval": 2.0, "auto_type": "magic",
		"abilities": [alms],
	})


static func _berserker() -> EnemyDef:
	return EnemyDef.make({
		"id": "berserker", "name": "Penitent", "hp": 2100.0, "count": 4, "radius": 0.7, "reach": 2.3, "priority": 1,
		"auto_dmg": 38.0, "auto_interval": 1.0, "auto_type": "phys",
		"passive": _enrage(0.3, 0.5),
	})


static func _overseer() -> EnemyDef:
	return EnemyDef.make({
		"id": "overseer", "name": "The Prior", "hp": 4600.0, "count": 8, "elite": true, "radius": 0.95, "reach": 2.3, "priority": 1, "frontal": true,
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


# ---------- the keepers of Tollhaven

static func _deckhand() -> EnemyDef:
	return EnemyDef.make({
		"id": "deckhand", "name": "Drowned Deckhand", "hp": 750.0, "count": 1, "radius": 0.5, "reach": 2.3, "priority": 1,
		"auto_dmg": 22.0, "auto_interval": 1.4, "auto_type": "phys", "tint": Color(0.7, 0.86, 1.0),
	})


static func _crier() -> EnemyDef:
	var cry := _ab({"id": "cry", "name": "Cry the Hour", "cd": 16.0, "first": 5.0, "cast": 3.0, "interruptible": true,
		"importance": 2, "targeting": "self"})
	cry.ready = func(c: Combat, e: Combatant) -> bool:
		return c.sleeping_near(e.pos, CRY_REACH) != null
	cry.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		var pack := c.sleeping_near(e.pos, CRY_REACH)
		var who := c.unit(e.target_id)
		if pack == null or who == null or not who.alive:
			return
		c.alert("The hour is cried. %s wakes!" % pack.name)
		c.ring(e.pos, 12.0, GOLD)
		c.engage(pack, who)
	return EnemyDef.make({
		"id": "crier", "name": "Tide Crier", "hp": 1700.0, "count": 4, "radius": 0.6, "reach": 24.0, "priority": 3,
		"auto_dmg": 30.0, "auto_interval": 2.0, "auto_type": "magic", "tint": Color(1.0, 0.88, 0.6),
		"abilities": [cry],
	})


static func _mate() -> EnemyDef:
	return EnemyDef.make({
		"id": "mate", "name": "Shipwright's Mate", "hp": 3000.0, "count": 5, "radius": 0.8, "reach": 2.3, "priority": 1,
		"auto_dmg": 52.0, "auto_interval": 1.6, "auto_type": "phys", "front_guard": 0.6, "tint": Color(0.62, 0.58, 0.55),
		"abilities": [_buster("Caulking Maul", "maul", 11.0, 6.0, 260.0, 3)],
	})


static func _dredger() -> EnemyDef:
	var hook := _ab({"id": "grapple", "name": "Grapple", "cd": 12.0, "first": 4.0, "cast": 1.5, "targeting": "farthest", "needs_los": true})
	hook.start = func(c: Combat, e: Combatant, t: Combatant, _cs: Cast) -> void:
		if t:
			c.beam(e, t, SLATE)
	hook.finish = func(c: Combat, e: Combatant, t: Combatant) -> void:
		if t == null:
			return
		var at := e.pos + Combat.toward(e, t) * (e.radius + 1.2)
		c.yank(t, at if c.can_stand.call(at) else e.pos)
		c.text(t.pos, "Grappled", SLATE)
		c.damage(e, t, 130.0, "phys")
	return EnemyDef.make({
		"id": "dredger", "name": "Dredger", "hp": 2600.0, "count": 5, "radius": 0.75, "reach": 2.3, "priority": 2,
		"auto_dmg": 44.0, "auto_interval": 1.5, "auto_type": "phys", "tint": Color(0.66, 0.95, 0.7),
		"abilities": [hook],
	})


# ---------- the four bosses of Tollhaven

static func _hask() -> EnemyDef:
	var net := _ab({"id": "castnet", "name": "Cast Net", "cd": 20.0, "first": 7.0, "cast": 1.5, "targeting": "self"})
	net.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		var caught: Array[String] = []
		for h: Combatant in c.random_heroes(4):
			# never whoever she is fighting, and two at once from level 6
			if h.id == e.target_id or c.held(h) or caught.size() >= (2 if c.level >= 6 else 1):
				continue
			var mesh := c.spawn_enemy("net", h.pos, e.pack_id, true)
			mesh.flags["holds"] = h.id
			# two nets are each half as stout as one
			if c.level >= 6:
				mesh.max_hp = roundf(mesh.max_hp * 0.5)
				mesh.hp = mesh.max_hp
			c.add_aura(h, {"id": "netted", "name": "Netted", "dur": 9999.0, "src_id": mesh.id, "debuff": true, "hold": true,
				"tick_every": 1.0, "tick_dmg": 20.0})
			h.cast = null
			c.text(h.pos, "Netted", SLATE)
			caught.append(h.name)
		if not caught.is_empty():
			c.alert("%s netted. Cut the net!" % (" and ".join(caught) + (" is" if caught.size() == 1 else " are")))
			# she hauls ten seconds after a net lands
			e.cds["haul"] = 10.0
	var haul := _ab({"id": "haul", "name": "Haul", "cd": 12.0, "first": 0.0, "cast": 2.5, "targeting": "self"})
	haul.ready = func(c: Combat, _e: Combatant) -> bool:
		return c.heroes.any(func(h: Combatant) -> bool: return h.alive and c.has_aura(h, "netted"))
	haul.start = func(c: Combat, _e: Combatant, _t: Combatant, _cs: Cast) -> void:
		c.alert("Mother Hask hauls on her nets!")
	haul.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		var n := 0
		for h: Combatant in c.alive_heroes():
			if not c.has_aura(h, "netted"):
				continue
			var a := 0.4 + n * 2.1
			n += 1
			var at := e.pos + Vector3(cos(a), 0, sin(a)) * (e.radius + 1.3)
			at = at if c.can_stand.call(at) else e.pos
			c.yank(h, at)
			# the net comes with whoever is in it
			for mesh: Combatant in c.packs[e.pack_id].units:
				if mesh.alive and mesh.flags.get("holds", 0) == h.id:
					c.yank(mesh, at)
		c.ring(e.pos, 7.0, Color("ef5d4a"))
		for h: Combatant in c.alive_heroes():
			if Combat.dist(h, e) <= 7.0:
				c.damage(e, h, 280.0, "phys", {"no_beam": true})
	return EnemyDef.make({
		"id": "hask", "name": "Mother Hask", "hp": 24000.0, "boss": true, "radius": 1.4, "reach": 2.6, "priority": 0,
		"auto_dmg": 86.0, "auto_interval": 1.6, "auto_type": "phys", "tint": Color(0.75, 1.0, 0.85),
		"abilities": [haul, net, _buster("Gutting Knife", "gut", 13.0, 10.0, 520.0, 3)],
		"on_death": _nets_fall,
	})


# With Mother Hask at rest her nets fall slack.
static func _nets_fall(c: Combat, e: Combatant) -> void:
	for u: Combatant in c.packs[e.pack_id].units:
		if u.alive and u.enemy.id == "net":
			c._kill(u)


static func _net() -> EnemyDef:
	return EnemyDef.make({
		"id": "net", "name": "Net", "hp": 1000.0, "radius": 0.7, "reach": 99.0, "priority": 5, "still": true,
		"on_death": _net_cut,
	})


static func _net_cut(c: Combat, e: Combatant) -> void:
	var h := c.unit(e.flags.get("holds", 0))
	if h and c.has_aura(h, "netted"):
		h.auras = h.auras.filter(func(a: Aura) -> bool: return a.id != "netted")
		c.text(h.pos, "Cut free", GREEN)


static func _corrow() -> EnemyDef:
	# the Audit is opened once, and then counted out one cast at a time
	var open := _ab({"id": "audit", "name": "The Audit", "cd": 30.0, "first": 9.0, "cast": 0.0, "targeting": "self"})
	open.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		e.flags["audit"] = 4 if c.level >= 6 else 3
		c.alert("The Audit. Silence every count!")
	var tally := _ab({"id": "tally", "name": "The Audit", "cd": 0.4, "first": 0.0, "cast": 2.2, "interruptible": true,
		"importance": 2, "targeting": "random"})
	tally.ready = func(_c: Combat, e: Combatant) -> bool:
		return e.flags.get("audit", 0) > 0
	tally.start = func(_c: Combat, e: Combatant, _t: Combatant, _cs: Cast) -> void:
		e.flags["audit"] -= 1
	tally.finish = func(c: Combat, e: Combatant, t: Combatant) -> void:
		if t:
			c.add_aura(t, {"id": "tax", "name": "The Tax", "dur": 14.0, "src_id": e.id, "debuff": true, "dispellable": true,
				"tick_every": 1.0, "tick_dmg": 48.0, "done": 0.8})
			c.text(t.pos, "Taxed", GOLD)
	var seize := _ab({"id": "seize", "name": "Seize", "cd": 22.0, "first": 17.0, "cast": 0.0, "targeting": "self"})
	seize.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		var marked: Combatant = null
		for h: Combatant in c.random_heroes(4):
			if marked == null or marked.id == e.target_id:
				marked = h
		if marked == null:
			return
		c.add_zone({"kind": "circle", "pos": marked.pos, "r": 7.0, "delay": 5.0, "dmg": 430.0, "type": "magic",
			"owner_id": e.id, "follow_id": marked.id})
		c.alert("%s is seized. Carry it clear of the others!" % marked.name)
	return EnemyDef.make({
		"id": "corrow", "name": "Exciseman Corrow", "hp": 25000.0, "boss": true, "radius": 1.45, "reach": 2.6, "priority": 0,
		"auto_dmg": 92.0, "auto_interval": 1.7, "auto_type": "phys", "tint": Color(0.82, 0.8, 1.0),
		"abilities": [tally, open, seize, _buster("Stamp and Seal", "stamp", 14.0, 6.0, 640.0)],
	})


static func _garrow() -> EnemyDef:
	var launch := _ab({"id": "launch", "name": "Launch", "cd": 24.0, "first": 10.0, "cast": 3.0, "targeting": "self"})
	launch.start = func(c: Combat, e: Combatant, _t: Combatant, _cs: Cast) -> void:
		c.alert("A hull is coming down the slip!")
		# three slips run the length of the dock; from level 6 a second hull is swung across them
		var slip := (int(c.rng() * 3.0) - 1) * 9.0
		c.add_zone({"kind": "lane", "pos": e.home + Vector3(0, 0, slip), "r": 24.0, "dir": Vector3.RIGHT, "half": 3.5,
			"delay": 3.0, "dmg": 620.0, "type": "phys", "owner_id": e.id, "tied": true})
		if c.level >= 6:
			var across := (int(c.rng() * 3.0) - 1) * 10.0
			c.add_zone({"kind": "lane", "pos": e.home + Vector3(across, 0, 0), "r": 24.0, "dir": Vector3.BACK, "half": 3.5,
				"delay": 3.0, "dmg": 620.0, "type": "phys", "owner_id": e.id, "tied": true})
	var pitch := _ab({"id": "pitch", "name": "Pitch Pot", "cd": 9.0, "first": 5.0, "cast": 0.0, "targeting": "threat"})
	pitch.finish = func(c: Combat, e: Combatant, t: Combatant) -> void:
		if t:
			c.add_zone({"kind": "circle", "pos": t.pos, "r": 4.0, "delay": 1.6, "dmg": 170.0, "type": "magic", "owner_id": e.id,
				"linger": 26.0, "linger_dmg": 75.0})
	return EnemyDef.make({
		"id": "garrow", "name": "Old Garrow", "hp": 27000.0, "boss": true, "radius": 1.5, "reach": 2.6, "priority": 0,
		"auto_dmg": 94.0, "auto_interval": 1.6, "auto_type": "phys", "tint": Color(1.0, 0.82, 0.68),
		"abilities": [launch, pitch, _buster("The Adze", "adze", 15.0, 8.0, 600.0)],
	})


static func _keeper() -> EnemyDef:
	var out := _ab({"id": "lightsout", "name": "Lights Out", "cd": 1.0, "cast": 5.0, "targeting": "self"})
	# once at three fifths of his health and once at three tenths
	out.ready = func(_c: Combat, e: Combatant) -> bool:
		var part := e.hp / e.max_hp
		return (part <= 0.6 and not e.flags.has("d1")) or (part <= 0.3 and not e.flags.has("d2"))
	out.start = func(c: Combat, e: Combatant, _t: Combatant, _cs: Cast) -> void:
		e.flags["d2" if e.flags.has("d1") else "d1"] = true
		c.alert("Lights out. Get into a lit circle!")
		# the beam goes out with the rest
		c.zones = c.zones.filter(func(z: Zone) -> bool: return z.owner_id != e.id or z.turn == 0.0)
		var lit: Array[Vector3] = []
		var from := c.rng() * TAU
		for k in 3:
			var a := from + k * TAU / 3.0
			var at := e.home
			for far: float in [11.0, 8.0, 5.0]:
				var p := e.home + Vector3(cos(a), 0, sin(a)) * far
				if c.can_stand.call(p):
					at = p
					break
			lit.append(at)
			c.add_zone({"kind": "circle", "pos": at, "r": LIT, "delay": 5.3, "safe": true, "owner_id": e.id})
		e.flags["lit"] = lit
	out.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		var lit: Array = e.flags.get("lit", [])
		for h: Combatant in c.alive_heroes():
			if not lit.any(func(at: Vector3) -> bool: return Combat.flat(h.pos, at) <= LIT + 0.3):
				c.damage(e, h, h.max_hp * 0.9, "magic", {"raw": true})
		c.ring(e.pos, 30.0, GOLD)
	var beam := _ab({"id": "beam", "name": "The Beam", "cd": 28.0, "first": 9.0, "cast": 0.0, "targeting": "self"})
	beam.finish = func(c: Combat, e: Combatant, _t: Combatant) -> void:
		# it starts pointing away from whoever he is fighting, and turns either way
		var t := c.unit(e.target_id)
		var away := -Combat.toward(e, t) if t and Combat.dist(e, t) > 0.1 else Vector3.RIGHT
		var turn := (0.55 if c.level >= 6 else 0.38) * (1.0 if c.rng() < 0.5 else -1.0)
		c.add_zone({"kind": "cone", "pos": e.pos, "r": 28.0, "dir": away, "half": 0.3, "delay": 2.0, "type": "magic",
			"owner_id": e.id, "follow_id": e.id, "turn": turn, "linger": 11.0, "linger_dmg": 115.0, "every": 0.5, "sight": true})
		c.alert("The Beam turns. Keep ahead of it, or get behind a pillar.")
	var undertow := _ab({"id": "undertow", "name": "Undertow", "cd": 22.0, "first": 15.0, "cast": 5.0, "targeting": "self"})
	undertow.tick = func(c: Combat, e: Combatant, _cs: Cast) -> void:
		for h: Combatant in c.alive_heroes():
			c.damage(e, h, 55.0, "magic", {"no_beam": true})
	return EnemyDef.make({
		"id": "keeper", "name": "The Keeper of the Light", "hp": 31000.0, "boss": true, "radius": 1.5, "reach": 2.6, "priority": 0,
		"auto_dmg": 88.0, "auto_interval": 1.7, "auto_type": "phys", "tint": Color(1.0, 0.95, 0.7),
		"abilities": [out, beam, undertow],
	})
