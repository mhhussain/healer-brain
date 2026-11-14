class_name Heroes
extends RefCounted

# The six heroes, as data. Ported from src/sim/heroes.ts; the numbers are the tuned ones.

const MELEE := 3.2
const TANKS: Array[String] = ["warden"]
const HEALERS: Array[String] = ["mender", "bloomweaver"]
const DPS: Array[String] = ["duelist", "ranger", "pyromancer"]
const ALL: Array[String] = ["warden", "mender", "bloomweaver", "duelist", "ranger", "pyromancer"]

static var _defs := {}


static func by_id(id: String) -> HeroDef:
	if _defs.is_empty():
		for def: HeroDef in [_warden(), _mender(), _bloomweaver(), _duelist(), _ranger(), _pyromancer()]:
			_defs[def.id] = def
	return _defs.get(id)


static func _ab(fields: Dictionary) -> AbilityDef:
	return AbilityDef.make(fields)


# ---------- Hale Dunmarrow, the Gatewarden

static func _warden() -> HeroDef:
	return HeroDef.make({
		"id": "warden", "name": "Hale Dunmarrow", "title": "The Gatewarden", "role": "tank", "sub": "Tank",
		"color": Color("6fa0d6"), "hp": 2400.0,
		"res_name": "Grit", "res_max": 100.0, "res_start": 0.0, "res_color": Color("c9744a"), "regen": 0.0, "gcd": 1.5,
		"auto_dmg": 40.0, "auto_interval": 1.8, "auto_reach": MELEE, "threat_mult": 4.0,
		"how_to": "Pull with Pilot's Hail, keep every enemy on you with Mooring Sweep, and save grit so Brace is up for telegraphed heavy hits.",
		"abilities": [
			_ab({"id": "strike", "name": "Bulwark Blow", "target": "enemy", "reach": MELEE, "cd": 4.5,
				"desc": "110 damage. +8 grit.", "fire": _warden_strike}),
			_ab({"id": "sweep", "name": "Mooring Sweep", "target": "self",
				"desc": "50 damage to every enemy within 6 m. +1 grit per enemy hit, up to 5.", "fire": _warden_sweep}),
			_ab({"id": "challenge", "name": "Pilot's Hail", "target": "enemy", "cd": 8.0, "off_gcd": true,
				"desc": "The target attacks you for 4 s and you go to the top of its threat. Works at range: use it to pull.",
				"fire": _warden_challenge}),
			_ab({"id": "bash", "name": "Breakwater Bash", "target": "enemy", "reach": MELEE, "cd": 15.0, "off_gcd": true, "interrupt": true,
				"desc": "Silence the target's cast.", "fire": _interrupt}),
			_ab({"id": "brace", "name": "Brace", "target": "self", "cost": 40.0, "off_gcd": true,
				"desc": "Take 50% less physical damage for 6 s.", "fire": _warden_brace}),
			_ab({"id": "unbreakable", "name": "Seawall", "target": "self", "cd": 120.0, "off_gcd": true,
				"desc": "Take 40% less damage of all kinds for 10 s and heal 20% of maximum health.", "fire": _warden_unbreakable}),
		],
	})


static func _warden_strike(c: Combat, u: Combatant, t: Combatant) -> void:
	c.damage(u, t, 110.0, "phys")
	c.gain(u, 8.0)


static func _warden_sweep(c: Combat, u: Combatant, _t: Combatant) -> void:
	var hit := c.enemies_near(u.pos, 6.0)
	for e: Combatant in hit:
		c.damage(u, e, 50.0, "phys")
	c.gain(u, minf(5.0, hit.size()))
	c.ring(u.pos, 6.0, u.hero.color)


static func _warden_challenge(c: Combat, u: Combatant, t: Combatant) -> void:
	c.taunt(u, t, "Pilot's Hail")


static func _warden_brace(c: Combat, u: Combatant, _t: Combatant) -> void:
	c.add_aura(u, {"id": "brace", "name": "Brace", "dur": 6.0, "src_id": u.id, "taken_phys": 0.5})


static func _warden_unbreakable(c: Combat, u: Combatant, _t: Combatant) -> void:
	c.add_aura(u, {"id": "unbreakable", "name": "Seawall", "dur": 10.0, "src_id": u.id, "taken": 0.6})
	c.heal(u, u, u.max_hp * 0.2)


static func _interrupt(c: Combat, u: Combatant, t: Combatant) -> void:
	c.interrupt(u, t)


static func _dispel(c: Combat, u: Combatant, t: Combatant) -> void:
	c.dispel(u, t)


# ---------- Sister Wren, the Lamplighter

static func _mender() -> HeroDef:
	return HeroDef.make({
		"id": "mender", "name": "Sister Wren", "title": "The Lamplighter", "role": "healer", "sub": "Direct healer",
		"color": Color("5fd6c6"), "hp": 1200.0,
		"res_name": "Lamplight", "res_max": 1000.0, "res_start": 1000.0, "res_color": Color("e0a93c"), "regen": 8.0, "gcd": 1.5,
		"auto_dmg": 22.0, "auto_interval": 2.0, "auto_reach": 30.0,
		"how_to": "React to damage: Warm Light for efficiency, Spark for emergencies. Rebuke when nobody needs healing to win back lamplight.",
		"abilities": [
			_ab({"id": "mend", "name": "Warm Light", "target": "ally", "cost": 40.0, "cast": 2.0,
				"desc": "Heal 420. Also heals the most injured other ally within 10 m of the target for 30%.", "fire": _mender_mend}),
			_ab({"id": "quick", "name": "Spark", "target": "ally", "cost": 90.0,
				"desc": "Instant. Heal 330.", "fire": _mender_quick}),
			_ab({"id": "rebuke", "name": "Rebuke", "target": "enemy", "cast": 1.5,
				"desc": "70 damage. Restores 15 lamplight.", "fire": _mender_rebuke}),
			_ab({"id": "purify", "name": "Absolve", "target": "ally", "cost": 30.0, "cd": 8.0, "dispel": true,
				"desc": "Cleanse an ally of every curse that can be lifted.", "fire": _dispel}),
			_ab({"id": "ward", "name": "Lantern Ward", "target": "ally", "cd": 45.0, "off_gcd": true,
				"desc": "An ally takes 40% less damage for 6 s.", "fire": _mender_ward}),
			_ab({"id": "sanctuary", "name": "Sanctuary", "target": "self", "cd": 120.0,
				"desc": "Heal every ally for 300 now and 600 more over 8 s.", "fire": _mender_sanctuary}),
		],
	})


static func _mender_mend(c: Combat, u: Combatant, t: Combatant) -> void:
	c.heal(u, t, 420.0)
	var best: Combatant = null
	for h in c.heroes:
		if h == t or not h.alive or h.hp >= h.max_hp or Combat.dist(h, t) > 10.0:
			continue
		if best == null or h.hp / h.max_hp < best.hp / best.max_hp:
			best = h
	if best:
		c.heal(u, best, 126.0)


static func _mender_quick(c: Combat, u: Combatant, t: Combatant) -> void:
	c.heal(u, t, 330.0)


static func _mender_rebuke(c: Combat, u: Combatant, t: Combatant) -> void:
	c.damage(u, t, 70.0, "magic")
	c.gain(u, 15.0)


static func _mender_ward(c: Combat, u: Combatant, t: Combatant) -> void:
	c.add_aura(t, {"id": "ward", "name": "Lantern Ward", "dur": 6.0, "src_id": u.id, "taken": 0.6})


static func _mender_sanctuary(c: Combat, u: Combatant, _t: Combatant) -> void:
	for h in c.heroes:
		if not h.alive:
			continue
		c.heal(u, h, 300.0)
		c.add_aura(h, {"id": "sanctuary", "name": "Sanctuary", "dur": 8.0, "src_id": u.id, "tick_every": 2.0, "tick_heal": 150.0})


# ---------- Old Maren, the Kelpwife

const KELP := {"id": "vine", "name": "Mending Kelp", "dur": 14.0, "tick_every": 2.0, "tick_heal": 60.0}


static func _bloomweaver() -> HeroDef:
	return HeroDef.make({
		"id": "bloomweaver", "name": "Old Maren", "title": "The Kelpwife", "role": "healer", "sub": "Heal-over-time and shield healer",
		"color": Color("7fbf6a"), "hp": 1200.0,
		"res_name": "Tidewater", "res_max": 1000.0, "res_start": 1000.0, "res_color": Color("3f9fb8"), "regen": 12.0, "gcd": 1.5,
		"auto_dmg": 22.0, "auto_interval": 2.0, "auto_reach": 30.0,
		"how_to": "Heal ahead of the damage: keep Mending Kelp rolling, shield whoever is about to be hit, and Kelp Bloom when several strands are out.",
		"abilities": [
			_ab({"id": "vine", "name": "Mending Kelp", "target": "ally", "cost": 30.0,
				"desc": "Heal 60 every 2 s for 14 s. One per ally; recasting refreshes it.", "fire": _bloom_vine}),
			_ab({"id": "bark", "name": "Shell Ward", "target": "ally", "cost": 42.0, "cd": 3.0,
				"desc": "Shield an ally against the next 350 damage, for 12 s.", "fire": _bloom_bark}),
			_ab({"id": "bloom", "name": "Kelp Bloom", "target": "self", "cost": 45.0, "cd": 10.0,
				"desc": "Every ally with Mending Kelp is healed for 240 at once. The kelp keeps working.", "fire": _bloom_bloom}),
			_ab({"id": "dew", "name": "Salt Rinse", "target": "ally", "cost": 30.0, "cd": 8.0, "dispel": true,
				"desc": "Cleanse an ally of every curse that can be lifted.", "fire": _dispel}),
			_ab({"id": "bramble", "name": "Barnacle Guard", "target": "ally", "cd": 45.0, "off_gcd": true,
				"desc": "An ally takes 30% less damage for 8 s.", "fire": _bloom_bramble}),
			_ab({"id": "tide", "name": "Green Tide", "target": "self", "cd": 120.0,
				"desc": "Put Mending Kelp on every ally. For 10 s kelp heals twice as fast and Shell Ward has no cooldown.", "fire": _bloom_tide}),
		],
	})


static func _kelp(c: Combat, u: Combatant, t: Combatant) -> void:
	var fields := KELP.duplicate()
	fields["src_id"] = u.id
	c.add_aura(t, fields)


static func _bloom_vine(c: Combat, u: Combatant, t: Combatant) -> void:
	_kelp(c, u, t)


static func _bloom_bark(c: Combat, u: Combatant, t: Combatant) -> void:
	c.add_aura(t, {"id": "bark", "name": "Shell Ward", "dur": 12.0, "src_id": u.id, "absorb": 350.0})
	if c.has_aura(u, "tide"):
		u.cds["bark"] = 0.0


static func _bloom_bloom(c: Combat, u: Combatant, _t: Combatant) -> void:
	for h in c.heroes:
		if h.alive and c.has_aura(h, "vine"):
			c.heal(u, h, 240.0)


static func _bloom_bramble(c: Combat, u: Combatant, t: Combatant) -> void:
	c.add_aura(t, {"id": "bramble", "name": "Barnacle Guard", "dur": 8.0, "src_id": u.id, "taken": 0.7})


static func _bloom_tide(c: Combat, u: Combatant, _t: Combatant) -> void:
	c.add_aura(u, {"id": "tide", "name": "Green Tide", "dur": 10.0, "src_id": u.id})
	u.cds["bark"] = 0.0
	for h in c.heroes:
		if h.alive:
			_kelp(c, u, h)


# ---------- Corvin Ashby, the Wrecker

static func _duelist() -> HeroDef:
	return HeroDef.make({
		"id": "duelist", "name": "Corvin Ashby", "title": "The Wrecker", "role": "dps", "sub": "Melee damage",
		"color": Color("d0668f"), "hp": 1300.0,
		"res_name": "Nerve", "res_max": 100.0, "res_start": 100.0, "res_color": Color("d9b84a"), "regen": 20.0, "gcd": 1.0,
		"auto_dmg": 55.0, "auto_interval": 1.2, "auto_reach": MELEE,
		"how_to": "Build combo points with Cutlass or Round Turn, spend five on Final Cut, and stay behind the enemy, out of frontals.",
		"abilities": [
			_ab({"id": "slash", "name": "Cutlass", "target": "enemy", "reach": MELEE, "cost": 40.0,
				"desc": "60 damage. +1 combo point.", "fire": _duelist_slash}),
			_ab({"id": "whirl", "name": "Round Turn", "target": "self", "cost": 45.0,
				"desc": "35 damage to every enemy within 5 m. +1 combo point.", "fire": _duelist_whirl}),
			_ab({"id": "thrust", "name": "Final Cut", "target": "enemy", "reach": MELEE, "cost": 25.0,
				"desc": "Spends all combo points. 45 damage per point.", "usable": _duelist_has_combo, "fire": _duelist_thrust}),
			_ab({"id": "jab", "name": "Hilt Jab", "target": "enemy", "reach": MELEE, "cd": 15.0, "off_gcd": true, "interrupt": true,
				"desc": "Silence the target's cast.", "fire": _interrupt}),
			_ab({"id": "riposte", "name": "Riposte", "target": "self", "cd": 60.0, "off_gcd": true,
				"desc": "Take 50% less damage for 5 s.", "fire": _duelist_riposte}),
			_ab({"id": "bloodrush", "name": "Wrecker's Luck", "target": "self", "cd": 120.0, "off_gcd": true,
				"desc": "For 12 s, nerve returns twice as fast and you deal 20% more damage.", "fire": _duelist_bloodrush}),
		],
	})


static func _duelist_slash(c: Combat, u: Combatant, t: Combatant) -> void:
	c.damage(u, t, 60.0, "phys")
	u.combo = mini(5, u.combo + 1)


static func _duelist_whirl(c: Combat, u: Combatant, _t: Combatant) -> void:
	for e: Combatant in c.enemies_near(u.pos, 5.0):
		c.damage(u, e, 35.0, "phys")
	u.combo = mini(5, u.combo + 1)
	c.ring(u.pos, 5.0, u.hero.color)


static func _duelist_has_combo(_c: Combat, u: Combatant) -> String:
	return "" if u.combo > 0 else "No combo points"


static func _duelist_thrust(c: Combat, u: Combatant, t: Combatant) -> void:
	var points := u.combo
	u.combo = 0
	c.damage(u, t, 45.0 * points, "phys")


static func _duelist_riposte(c: Combat, u: Combatant, _t: Combatant) -> void:
	c.add_aura(u, {"id": "riposte", "name": "Riposte", "dur": 5.0, "src_id": u.id, "taken": 0.5})


static func _duelist_bloodrush(c: Combat, u: Combatant, _t: Combatant) -> void:
	c.add_aura(u, {"id": "bloodrush", "name": "Wrecker's Luck", "dur": 12.0, "src_id": u.id, "done": 1.2})


# ---------- Isolde Fenn, the Harpooner

static func _ranger() -> HeroDef:
	return HeroDef.make({
		"id": "ranger", "name": "Isolde Fenn", "title": "The Harpooner", "role": "dps", "sub": "Ranged damage",
		"color": Color("e6b93c"), "hp": 1200.0,
		"res_name": "Focus", "res_max": 100.0, "res_start": 100.0, "res_color": Color("8fb8c9"), "regen": 4.0, "gcd": 1.5,
		"auto_dmg": 50.0, "auto_interval": 1.6, "auto_reach": 30.0,
		"how_to": "Everything works on the move. Snap Throw builds focus; spend it on Whaler's Lance, or Barb Scatter against groups.",
		"abilities": [
			_ab({"id": "quickshot", "name": "Snap Throw", "target": "enemy",
				"desc": "60 damage. +15 focus.", "fire": _ranger_quickshot}),
			_ab({"id": "piercing", "name": "Whaler's Lance", "target": "enemy", "cost": 45.0,
				"desc": "190 damage.", "fire": _ranger_piercing}),
			_ab({"id": "volley", "name": "Barb Scatter", "target": "enemy", "cost": 40.0,
				"desc": "75 damage to the target and every enemy within 6 m of it.", "fire": _ranger_volley}),
			_ab({"id": "jarring", "name": "Jarring Barb", "target": "enemy", "cd": 20.0, "off_gcd": true, "interrupt": true,
				"desc": "Silence the target's cast, at range.", "fire": _interrupt}),
			_ab({"id": "tumble", "name": "Deck Roll", "target": "self", "cd": 20.0, "off_gcd": true,
				"desc": "Roll 8 m in your move direction and take 30% less damage for 3 s.", "fire": _ranger_tumble}),
			_ab({"id": "hawk", "name": "Gull's Eye", "target": "self", "cd": 90.0, "off_gcd": true,
				"desc": "For 10 s, auto-attacks fly 50% faster and Snap Throw gives double focus.", "fire": _ranger_hawk}),
		],
	})


static func _ranger_quickshot(c: Combat, u: Combatant, t: Combatant) -> void:
	c.damage(u, t, 60.0, "phys")
	c.gain(u, 30.0 if c.has_aura(u, "hawk") else 15.0)


static func _ranger_piercing(c: Combat, u: Combatant, t: Combatant) -> void:
	c.damage(u, t, 190.0, "phys")


static func _ranger_volley(c: Combat, u: Combatant, t: Combatant) -> void:
	for e: Combatant in c.enemies_near(t.pos, 6.0):
		c.damage(u, e, 75.0, "phys", {"no_beam": e != t})
	c.ring(t.pos, 6.0, u.hero.color)


static func _ranger_tumble(c: Combat, u: Combatant, _t: Combatant) -> void:
	# the way she is moving, or backwards if she is standing still; the scene does the rolling
	var dir := u.move_dir if c.time - u.last_move_t < 0.2 else -u.facing
	c.event.emit({"k": "dash", "id": u.id, "dir": dir, "dist": 8.0})
	c.add_aura(u, {"id": "tumble", "name": "Deck Roll", "dur": 3.0, "src_id": u.id, "taken": 0.7})


static func _ranger_hawk(c: Combat, u: Combatant, _t: Combatant) -> void:
	c.add_aura(u, {"id": "hawk", "name": "Gull's Eye", "dur": 10.0, "src_id": u.id, "haste": 1.5})


# ---------- Tobias Wick, the Chandler

static func _pyromancer() -> HeroDef:
	return HeroDef.make({
		"id": "pyromancer", "name": "Tobias Wick", "title": "The Chandler", "role": "dps", "sub": "Caster damage",
		"color": Color("e8843c"), "hp": 1100.0,
		"res_name": "Heat", "res_max": 100.0, "res_start": 0.0, "res_color": Color("ff7a2f"), "regen": 0.0, "gcd": 1.5,
		"auto_dmg": 22.0, "auto_interval": 2.0, "auto_reach": 30.0,
		"how_to": "Stand still to cast Wickfire and build Heat. Keep Tallow Burn on your target and save Flare-Up for when you have to move.",
		"abilities": [
			_ab({"id": "firebolt", "name": "Wickfire", "target": "enemy", "cast": 2.0,
				"desc": "170 damage. +25 Heat.", "fire": _pyro_firebolt}),
			_ab({"id": "ignite", "name": "Tallow Burn", "target": "enemy",
				"desc": "Instant. 240 damage over 12 s. +10 Heat. One per enemy.", "fire": _pyro_ignite}),
			_ab({"id": "burst", "name": "Flare-Up", "target": "enemy", "cost": 50.0,
				"desc": "Instant. 200 damage to the target and 90 to every enemy within 6 m of it.", "fire": _pyro_burst}),
			_ab({"id": "stifle", "name": "Snuff", "target": "enemy", "cd": 20.0, "off_gcd": true, "interrupt": true,
				"desc": "Silence the target's cast, at range.", "fire": _interrupt}),
			_ab({"id": "ember", "name": "Wax Seal", "target": "self", "cd": 45.0, "off_gcd": true,
				"desc": "Shield yourself against the next 400 damage, for 8 s.", "fire": _pyro_ember}),
			_ab({"id": "kindled", "name": "Steady Flame", "target": "self", "cd": 120.0, "off_gcd": true,
				"desc": "For 12 s, Wickfire casts in half the time.", "fire": _pyro_kindled}),
		],
	})


static func _pyro_firebolt(c: Combat, u: Combatant, t: Combatant) -> void:
	c.damage(u, t, 170.0, "magic")
	c.gain(u, 25.0)


static func _pyro_ignite(c: Combat, u: Combatant, t: Combatant) -> void:
	c.add_aura(t, {"id": "ignite%d" % u.id, "name": "Tallow Burn", "dur": 12.0, "src_id": u.id, "debuff": true, "tick_every": 2.0, "tick_dmg": 40.0})
	c.engage_from(u, t)
	c.gain(u, 10.0)


static func _pyro_burst(c: Combat, u: Combatant, t: Combatant) -> void:
	c.damage(u, t, 200.0, "magic")
	for e: Combatant in c.enemies_near(t.pos, 6.0):
		if e != t:
			c.damage(u, e, 90.0, "magic", {"no_beam": true})
	c.ring(t.pos, 6.0, u.hero.color)


static func _pyro_ember(c: Combat, u: Combatant, _t: Combatant) -> void:
	c.add_aura(u, {"id": "ember", "name": "Wax Seal", "dur": 8.0, "src_id": u.id, "absorb": 400.0})


static func _pyro_kindled(c: Combat, u: Combatant, _t: Combatant) -> void:
	c.add_aura(u, {"id": "kindled", "name": "Steady Flame", "dur": 12.0, "src_id": u.id})
