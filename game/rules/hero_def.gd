class_name HeroDef
extends RefCounted

# One hero, as data.

var id := ""
var name := ""
## Epithet, such as "The Harpooner".
var title := ""
## "tank", "healer" or "dps".
var role := "dps"
var sub := ""
var color := Color.WHITE
var hp := 1000.0
var res_name := ""
var res_max := 100.0
var res_start := 0.0
var res_color := Color.WHITE
## Resource gained each second in combat.
var regen := 0.0
var gcd := 1.5
var auto_dmg := 0.0
var auto_interval := 2.0
var auto_reach := 3.2
var threat_mult := 1.0
var how_to := ""
var abilities: Array[AbilityDef] = []


static func make(fields: Dictionary) -> HeroDef:
	var d := HeroDef.new()
	for k: String in fields:
		assert(k in d, "HeroDef has no field " + k)
		if k == "abilities":
			d.abilities.assign(fields[k])
		else:
			d.set(k, fields[k])
	return d
