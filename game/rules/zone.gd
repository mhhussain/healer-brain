class_name Zone
extends RefCounted

# A telegraphed patch of floor that hurts whoever is standing in it when its time runs out.

## "circle" or "cone".
var kind := "circle"
var pos := Vector3.ZERO
var r := 1.0
## Cones: the way it points along the floor, and half its width in radians.
var dir := Vector3.ZERO
var half := 0.0
var t := 0.0
var delay := 1.0
var dmg := 0.0
var type := "phys"
var owner_id := 0
## Tied to its owner's cast: it goes if the cast is stopped.
var tied := false


static func make(fields: Dictionary) -> Zone:
	var z := Zone.new()
	for k: String in fields:
		assert(k in z, "Zone has no field " + k)
		z.set(k, fields[k])
	return z


## Whether a spot on the floor is inside it. A margin widens it, for those deciding where to stand.
func holds(p: Vector3, margin := 0.0) -> bool:
	var off := Vector2(p.x - pos.x, p.z - pos.z)
	var d := off.length()
	if d > r + margin:
		return false
	if kind == "circle" or d < 0.5:
		return true
	return absf(Vector2(dir.x, dir.z).angle_to(off)) <= half + (0.2 if margin > 0.0 else 0.0)
