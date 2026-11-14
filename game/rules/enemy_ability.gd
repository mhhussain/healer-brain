class_name EnemyAbility
extends RefCounted

# One enemy ability, as data.

var id := ""
var name := ""
var cd := 10.0
## Seconds into the fight before its first use; -1 picks a random part of the cooldown.
var first := -1.0
var min_level := 0
var cast := 0.0
var interruptible := false
## 2 is a cast the party must stop; 1 is one it stops when it can.
var importance := 1
var tank_buster := false
## The party must break line of sight before it lands.
var hide := false
var melee := false
var needs_los := false
## "threat", "random" or "self".
var targeting := "threat"
## func(c: Combat, e: Combatant) -> bool
var ready := Callable()
## func(c: Combat, e: Combatant, t: Combatant, cast: Cast) -> void
var start := Callable()
## Once a second while casting: func(c: Combat, e: Combatant, cast: Cast) -> void
var tick := Callable()
## func(c: Combat, e: Combatant, t: Combatant) -> void
var finish := Callable()


static func make(fields: Dictionary) -> EnemyAbility:
	var a := EnemyAbility.new()
	for k: String in fields:
		assert(k in a, "EnemyAbility has no field " + k)
		a.set(k, fields[k])
	return a
