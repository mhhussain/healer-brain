class_name LevelDef
extends RefCounted

# A place to fight, as data: the floor, the walls, the pillars, where the party starts and where
# the packs stand. The scene builds its meshes, collision and navigation from this; the rules
# take the packs from it. On the floor, a Rect2's x is the world's x and its y is the world's z.

var name := ""
## Walkable floor, as rectangles that may overlap.
var floors: Array[Rect2] = []
## {"rect": Rect2, "height": float}: boxes that block the way, and the view if they are tall.
var walls: Array[Dictionary] = []
## {"pos": Vector3, "r": float, "height": float}: round columns that can be hidden behind.
var pillars: Array[Dictionary] = []
## The middle of each doorway, in order along the hall.
var doors: Array[Vector3] = []
var start := Vector3.ZERO
## {"name", "boss", "lamp", "enemies": [ids], "center", "entry", "pull_from", "stand", "room_left"}
var packs: Array[Dictionary] = []


func add_wall(x: float, z: float, w: float, d: float, height: float) -> void:
	walls.append({"rect": Rect2(x, z, w, d), "height": height})


func add_pillar(x: float, z: float, r: float, height := 3.0) -> void:
	pillars.append({"pos": Vector3(x, 0, z), "r": r, "height": height})


## Whether a spot is on the floor and clear of walls and pillars by a unit's half-width.
func can_stand(p: Vector3, margin := 0.5) -> bool:
	var at := Vector2(p.x, p.z)
	var on_floor := false
	for f in floors:
		if f.grow(-margin).has_point(at):
			on_floor = true
			break
	if not on_floor:
		return false
	for w in walls:
		if (w.rect as Rect2).grow(margin).has_point(at):
			return false
	for c in pillars:
		if Vector2(c.pos.x, c.pos.z).distance_to(at) < c.r + margin:
			return false
	return true


## Whether a straight line between two spots is clear of everything at least `over` metres tall.
## With over = 0 it asks whether a unit could walk it; with eye height it asks whether one could
## see along it. Fallen pillars are skipped: `standing` holds false for each one that is down.
func clear_line(a: Vector3, b: Vector3, over := 0.0, margin := 0.0, standing: Array = []) -> bool:
	var from := Vector2(a.x, a.z)
	var to := Vector2(b.x, b.z)
	for w in walls:
		if w.height >= over and _crosses((w.rect as Rect2).grow(margin), from, to):
			return false
	for i in pillars.size():
		if i < standing.size() and not standing[i]:
			continue
		var c: Dictionary = pillars[i]
		if c.height < over:
			continue
		var centre := Vector2(c.pos.x, c.pos.z)
		if Geometry2D.get_closest_point_to_segment(centre, from, to).distance_to(centre) < c.r + margin:
			return false
	return true


## The pillar a straight line between two spots runs into first, or -1.
func pillar_between(a: Vector3, b: Vector3, standing: Array = []) -> int:
	var from := Vector2(a.x, a.z)
	var to := Vector2(b.x, b.z)
	var best := -1
	var best_d := INF
	for i in pillars.size():
		if i < standing.size() and not standing[i]:
			continue
		var c: Dictionary = pillars[i]
		var centre := Vector2(c.pos.x, c.pos.z)
		if Geometry2D.get_closest_point_to_segment(centre, from, to).distance_to(centre) < c.r:
			var d := from.distance_to(centre)
			if d < best_d:
				best_d = d
				best = i
	return best


static func _crosses(r: Rect2, from: Vector2, to: Vector2) -> bool:
	if r.has_point(from) or r.has_point(to):
		return true
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(from, to, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false


## Where each enemy of a pack stands: in a ring round the pack's centre.
static func posts(pack: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n: int = pack.enemies.size()
	for i in n:
		var a := float(i) / n * TAU + 0.6
		var r := 3.2 if n > 1 else 0.0
		out.append(pack.center + Vector3(cos(a), 0, sin(a)) * r)
	return out
