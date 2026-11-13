class_name Heroes
extends RefCounted

# The heroes, as data. Ported from src/sim/heroes.ts a milestone at a time.

const MELEE := 3.2

static var _defs := {}


static func by_id(id: String) -> HeroDef:
	if _defs.is_empty():
		_defs["ranger"] = _ranger()
	return _defs.get(id)


static func _ranger() -> HeroDef:
	var h := HeroDef.new()
	h.id = "ranger"
	h.name = "Isolde Fenn"
	h.title = "The Harpooner"
	h.role = "dps"
	h.color = Color("e6b93c")
	h.hp = 1200.0
	h.res_name = "Focus"
	h.res_max = 100.0
	h.res_start = 100.0
	h.regen = 4.0
	h.gcd = 1.5
	h.auto_dmg = 50.0
	h.auto_interval = 1.6
	h.auto_reach = 30.0
	h.abilities = [
		AbilityDef.make({
			"id": "quickshot", "name": "Snap Throw", "target": "enemy",
			"desc": "60 damage. +15 focus.",
			"fire": _snap_throw,
		}),
		AbilityDef.make({
			"id": "piercing", "name": "Whaler's Lance", "target": "enemy", "cost": 45.0,
			"desc": "190 damage.",
			"fire": _whalers_lance,
		}),
	]
	return h


static func _snap_throw(c: Combat, u: Combatant, t: Combatant) -> void:
	c.damage(u, t, 60.0, "phys")
	c.gain(u, 15.0)


static func _whalers_lance(c: Combat, u: Combatant, t: Combatant) -> void:
	c.damage(u, t, 190.0, "phys")
