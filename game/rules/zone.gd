class_name Zone
extends RefCounted

# A telegraphed patch of floor that hurts whoever is standing in it when its time runs out. Some
# stay after that and go on hurting; some move with a unit or turn; one kind is a place to be.

## How far ahead of a turning cone the AI treats as part of it, in seconds of its turning.
const LEAD := 1.3

## "circle", "cone" or "lane".
var kind := "circle"
var pos := Vector3.ZERO
## Its radius; for a lane, how far it runs each way from `pos`.
var r := 1.0
## Cones and lanes: the way it points along the floor. Cones: half its width in radians. Lanes:
## half its width in metres.
var dir := Vector3.ZERO
var half := 0.0
var t := 0.0
var delay := 1.0
var dmg := 0.0
var type := "phys"
var owner_id := 0
## Tied to its owner's cast: it goes if the cast is stopped.
var tied := false
## After it goes off it stays this many seconds, and whoever stands in it is hurt for
## `linger_dmg` every `every` seconds. It goes when its owner dies.
var linger := 0.0
var linger_dmg := 0.0
var every := 1.0
## It moves with this unit.
var follow_id := 0
## Cones: how fast it turns, in radians a second.
var turn := 0.0
## Only those its owner can see are hurt: a pillar shelters.
var sight := false
## A place to stand, not one to leave: it hurts nobody, and goes when its time runs out.
var safe := false
## It has gone off, and is lingering.
var went := false
var tick_t := 0.0


static func make(fields: Dictionary) -> Zone:
	var z := Zone.new()
	for k: String in fields:
		assert(k in z, "Zone has no field " + k)
		z.set(k, fields[k])
	return z


## Whether a spot on the floor is inside it. A margin widens it, for those deciding where to
## stand; with one, a turning cone also covers what it is about to sweep.
func holds(p: Vector3, margin := 0.0) -> bool:
	var off := Vector2(p.x - pos.x, p.z - pos.z)
	if kind == "lane":
		var along := Vector2(dir.x, dir.z)
		return absf(off.dot(along)) <= r + margin and absf(off.dot(along.orthogonal())) <= half + margin
	var d := off.length()
	if d > r + margin:
		return false
	if kind == "circle" or d < 0.5:
		return true
	var a := Vector2(dir.x, dir.z).angle_to(off)
	var slack := 0.2 if margin > 0.0 else 0.0
	if turn != 0.0 and margin > 0.0:
		# measured the way it turns: a little behind it, and well ahead
		a *= signf(turn)
		return a >= -half - slack and a <= half + slack + absf(turn) * LEAD
	return absf(a) <= half + slack
