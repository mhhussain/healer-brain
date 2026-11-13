class_name Enemies
extends RefCounted

# The enemies, as data. Ported from src/sim/enemies.ts a milestone at a time.

static var _defs := {}


static func by_id(id: String) -> EnemyDef:
	if _defs.is_empty():
		_defs["brute"] = _brute()
	return _defs.get(id)


static func _brute() -> EnemyDef:
	var e := EnemyDef.new()
	e.id = "brute"
	e.name = "Drowned Porter"
	e.hp = 2300.0
	e.radius = 0.7
	e.reach = 2.3
	e.auto_dmg = 46.0
	e.auto_interval = 1.5
	e.auto_type = "phys"
	return e
