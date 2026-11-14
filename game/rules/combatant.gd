class_name Combatant
extends RefCounted

# What the rules know about one hero or enemy. The scene keeps the first block up to date
# (where it stands and how it is moving); everything else is changed only by Combat.

## Where it stands; only x and z matter to the rules.
var pos := Vector3.ZERO
## Whether it moved this tick, the way it last moved, and when.
var moved := false
var move_dir := Vector3.ZERO
var last_move_t := -9.0
## The way it faces along the floor.
var facing := Vector3.FORWARD

var id := 0
## "hero" or "enemy".
var team := "hero"
var name := ""
var hero: HeroDef
var enemy: EnemyDef
var is_player := false
## Heroes: place in the party, 0 to 3.
var slot := 0
var radius := 0.6

var hp := 1.0
var max_hp := 1.0
var alive := true
var res := 0.0
var res_max := 0.0
var combo := 0
var target_id := 0
var cast: Cast
var gcd := 0.0
## Ability id -> seconds left.
var cds := {}
var auras: Array[Aura] = []
var auto_timer := 0.0
var stats := {"dmg": 0.0, "heal": 0.0, "interrupts": 0, "dispels": 0, "deaths": 0}
var last_interrupt := -99.0
var rage_gate := -9.0
## Heroes: what its AI remembers. Used when the AI is playing it.
var ai: AIState

# enemies only
var pack_id := -1
var engaged := false
var summoned := false
## Hero id -> threat.
var threat := {}
## A taunt: the hero it must attack, and until when.
var forced_id := 0
var forced_t := 0.0
## Seconds before it may start another ability.
var busy := 0.0
## An ability waiting for a line of sight: {"ab": id, "target_id": id}, or empty.
var pending := {}
## Where round its target it stands, so a pack does not pile onto one spot.
var slot_angle := 0.0
var flags := {}
var home := Vector3.ZERO
## Where it wants to walk, when has_goal is set. The scene does the walking.
var goal := Vector3.ZERO
var has_goal := false
var chasing := false
var aggro_t := 0.0
