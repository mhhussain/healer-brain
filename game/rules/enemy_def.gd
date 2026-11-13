class_name EnemyDef
extends RefCounted

# One kind of enemy, as data.

var id := ""
var name := ""
var hp := 1000.0
var radius := 0.6
## How close it must be to attack, in metres.
var reach := 2.3
var auto_dmg := 0.0
var auto_interval := 1.5
## "phys" or "magic".
var auto_type := "phys"
