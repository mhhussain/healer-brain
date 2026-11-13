class_name AbilityDef
extends RefCounted

# One hero ability, as data. `fire` holds what it does.

var id := ""
var name := ""
var desc := ""
## Who it is aimed at: "enemy", "ally" or "self".
var target := "enemy"
## How far it reaches, in metres.
var reach := 30.0
var cost := 0.0
## Seconds of standing still to cast it; 0 is instant.
var cast := 0.0
var cd := 0.0
var off_gcd := false
var interrupt := false
var dispel := false
## func(c: Combat, u: Combatant, t: Combatant) -> void; t is the caster itself for "self".
var fire := Callable()
## func(c: Combat, u: Combatant) -> String: why it cannot be used now, or "".
var usable := Callable()


static func make(fields: Dictionary) -> AbilityDef:
	var a := AbilityDef.new()
	for k: String in fields:
		assert(k in a, "AbilityDef has no field " + k)
		a.set(k, fields[k])
	return a
