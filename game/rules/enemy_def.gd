class_name EnemyDef
extends RefCounted

# One kind of enemy, as data.

var id := ""
var name := ""
var hp := 1000.0
var boss := false
var elite := false
var radius := 0.6
## How close it must be to attack, in metres.
var reach := 2.3
var auto_dmg := 0.0
var auto_interval := 1.5
## "phys" or "magic".
var auto_type := "phys"
## Which the AI kills first: higher goes first.
var priority := 1
## It hits in front of itself, so only the tank should stand there.
var frontal := false
var abilities: Array[EnemyAbility] = []
## Every tick while fighting: func(c: Combat, e: Combatant) -> void
var passive := Callable()
## func(c: Combat, e: Combatant) -> void
var on_death := Callable()


static func make(fields: Dictionary) -> EnemyDef:
	var d := EnemyDef.new()
	for k: String in fields:
		assert(k in d, "EnemyDef has no field " + k)
		if k == "abilities":
			d.abilities.assign(fields[k])
		else:
			d.set(k, fields[k])
	return d
