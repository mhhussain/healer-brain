class_name Aura
extends RefCounted

# A timed effect on a unit: a shield, a damage reduction, a burn, a heal over time.

var id := ""
var name := ""
## Seconds left, and how long it started with.
var t := 0.0
var dur := 0.0
var src_id := 0
var debuff := false
var dispellable := false
## Multipliers: damage taken, physical damage taken, damage done, attack speed.
var taken := 1.0
var taken_phys := 1.0
var done := 1.0
var haste := 1.0
## Damage it will still soak up.
var absorb := 0.0
var tick_every := 0.0
var tick_timer := 0.0
var tick_dmg := 0.0
var tick_heal := 0.0


static func make(fields: Dictionary) -> Aura:
	var a := Aura.new()
	for k: String in fields:
		assert(k in a, "Aura has no field " + k)
		a.set(k, fields[k])
	return a
