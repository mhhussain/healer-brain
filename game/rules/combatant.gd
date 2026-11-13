class_name Combatant
extends RefCounted

# What the rules know about one hero or enemy. The scene keeps `pos` and `moved` up to date;
# everything else is changed only by Combat.

var id := 0
## "hero" or "enemy".
var team := "hero"
var name := ""
var hero: HeroDef
var enemy: EnemyDef
var is_player := false

## Where it stands; only x and z matter to the rules.
var pos := Vector3.ZERO
var radius := 0.6
## Whether it moved this tick.
var moved := false

var hp := 1.0
var max_hp := 1.0
var alive := true
var res := 0.0
var res_max := 0.0
var target_id := 0
var gcd := 0.0
## Ability id -> seconds left.
var cds := {}
var auto_timer := 0.0
var stats := {"dmg": 0.0, "heal": 0.0, "interrupts": 0, "dispels": 0, "deaths": 0}

# enemies only
var engaged := false
## Hero id -> threat.
var threat := {}
var home := Vector3.ZERO
## Where it wants to walk, when has_goal is set. The scene does the walking.
var goal := Vector3.ZERO
var has_goal := false
var chasing := false
var aggro_t := 0.0
