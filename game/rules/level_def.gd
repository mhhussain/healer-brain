class_name LevelDef
extends RefCounted

# A place to fight, as data: rooms joined by doorways, the walls, the pillars, where the party
# starts, where the packs stand and where the sanctuary lamps are. The scene builds its meshes,
# collision and navigation from this; the rules take the packs, the lamps and the count from it
# and ask it which room a spot is in. On the floor, a Rect2's x is the world's x and its y is the
# world's z.

## How far from a pack's middle its enemies stand, in metres, when there is more than one.
const RING := 3.2

## What saved things, such as routes, know it by.
var id := ""
var name := ""
## Walkable floor, as rectangles that may overlap. Rooms and doorways add their own.
var floors: Array[Rect2] = []
## {"name": String, "rect": Rect2, "zone": int}: one rectangle of floor each. "zone" is the part
## of the place it belongs to, a place in `zones`.
var rooms: Array[Dictionary] = []
## {"a": room, "b": room, "rect": Rect2, "pos": Vector3}: a doorway joining two rooms, and its
## middle. Its floor belongs to neither room.
var doors: Array[Dictionary] = []
## {"rect": Rect2, "height": float}: boxes that block the way, and the view if they are tall.
var walls: Array[Dictionary] = []
## {"pos": Vector3, "r": float, "height": float}: round columns that can be hidden behind.
var pillars: Array[Dictionary] = []
var start := Vector3.ZERO
## {"name", "boss", "lamp", "enemies": [ids], "room", "center", "pull_from", "stand"}. "lamp" is
## the line shown when a boss falls; "room" is a place in `rooms`, or -1. They are listed in the
## order the party takes them when nobody has planned otherwise. A pack with a "path" (a list
## of spots) is a patrol: until it is woken it walks from each spot to the next, and round again.
var packs: Array[Dictionary] = []
## The parts of the place, in order.
var zones: Array[String] = []
## {"name": String, "pos": Vector3, "pack": int}: where a beaten party starts again. "pack" is
## the boss pack whose fall lights the lamp, or -1 for one that burns from the start. With none,
## the party starts again from `start`.
var lamps: Array[Dictionary] = []
## The count a run must reach, from what its enemies are worth. 0 asks for all the place holds.
var count_needed := 0
## The route the party takes when nobody has planned one: a list of pulls, each a list of
## packs by their place in `packs`. Empty means every pack by itself, in order.
var default_route: Array = []
## How long a run here has, in seconds.
var time_limit := 14 * 60.0
## {"door": int, "packs": [int], "name": String}: a doorway that is shut until those boss packs
## are cleared.
var gates: Array[Dictionary] = []
## The doorways that are shut now: door -> true. A run opens them as it goes, so a level
## description belongs to one run.
var shut := {}

var _open_rooms := {}


## Adds a room and its floor. Returns its place in `rooms`.
func add_room(room_name: String, rect: Rect2, zone := 0) -> int:
	rooms.append({"name": room_name, "rect": rect, "zone": zone})
	floors.append(rect)
	return rooms.size() - 1


## Adds a doorway between two rooms, and its floor. Returns its place in `doors`.
func add_door(a: int, b: int, rect: Rect2) -> int:
	doors.append({"a": a, "b": b, "rect": rect, "pos": Vector3(rect.get_center().x, 0, rect.get_center().y)})
	floors.append(rect)
	return doors.size() - 1


## Shuts a doorway until those boss packs are cleared. Returns its place in `gates`.
func add_gate(door: int, boss_packs: Array, gate_name: String) -> int:
	gates.append({"door": door, "packs": boss_packs.duplicate(), "name": gate_name})
	shut[door] = true
	_open_rooms = {}
	return gates.size() - 1


func open_gate(gate: int) -> void:
	shut.erase(gates[gate].door)
	_open_rooms = {}


## Sets which doorways are shut, as whoever tries a route out must before and after.
func set_shut(doors_shut: Dictionary) -> void:
	shut = doors_shut.duplicate()
	_open_rooms = {}


func add_wall(x: float, z: float, w: float, d: float, height: float) -> void:
	walls.append({"rect": Rect2(x, z, w, d), "height": height})


func add_pillar(x: float, z: float, r: float, height := 3.0) -> void:
	pillars.append({"pos": Vector3(x, 0, z), "r": r, "height": height})


## Whether a spot is on the floor and clear of walls and pillars by a unit's half-width.
## The floor's own edges do not count: every edge that matters has a wall along it.
func can_stand(p: Vector3, margin := 0.5) -> bool:
	var at := Vector2(p.x, p.z)
	var on_floor := false
	for f in floors:
		if f.grow(0.01).has_point(at):
			on_floor = true
			break
	if not on_floor:
		return false
	for door: int in shut:
		if (doors[door].rect as Rect2).has_point(at):
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
	# most walls are nowhere near the line: those are passed over at a glance
	var near := Rect2(from, Vector2.ZERO).expand(to).grow(margin + 0.01)
	for w in walls:
		if w.height >= over and near.intersects(w.rect) and _crosses((w.rect as Rect2).grow(margin), from, to):
			return false
	for door: int in shut:
		if _crosses(doors[door].rect, from, to):
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


# ---------- count

## What a pack is worth towards the count.
func pack_count(i: int) -> int:
	var n := 0
	for enemy_id: String in packs[i].enemies:
		n += Enemies.by_id(enemy_id).count
	return n


## The count a run here must reach: what it asks for, or all it holds if it does not say.
func count_goal() -> int:
	if count_needed > 0:
		return count_needed
	var n := 0
	for i in packs.size():
		n += pack_count(i)
	return n


# ---------- rooms

## The room a spot is in, or -1: in a doorway, off the floor, or in a place with no rooms.
func room_at(p: Vector3) -> int:
	var at := Vector2(p.x, p.z)
	for i in rooms.size():
		if (rooms[i].rect as Rect2).grow(0.01).has_point(at):
			return i
	return -1


## The doorway a spot is in, or -1.
func door_at(p: Vector3) -> int:
	var at := Vector2(p.x, p.z)
	for i in doors.size():
		if (doors[i].rect as Rect2).has_point(at):
			return i
	return -1


## The part of the place a spot is in, or -1. A doorway belongs to neither side.
func zone_at(p: Vector3) -> int:
	var room := room_at(p)
	return rooms[room].zone if room >= 0 else -1


## Whether a spot is in the same room as someone standing at `of`, and at least `clear` metres
## from that room's doorways: in the room, not hanging back on its threshold. For someone
## standing in a doorway, both rooms it joins count, and the doorway itself. A place with no
## rooms is all one room.
func same_room(of: Vector3, p: Vector3, clear := 0.0) -> bool:
	var room := room_at(of)
	if room >= 0:
		if room_at(p) != room:
			return false
		for d in doors:
			if (d.a == room or d.b == room) and _gap(d.rect, p) < clear:
				return false
		return true
	var door := door_at(of)
	if door < 0:
		return true
	var there := room_at(p)
	return door_at(p) == door if there < 0 else there == doors[door].a or there == doors[door].b


## The doorways to go through, in order, to walk from one spot to another: the fewest there
## can be. Empty if they are in the same room, or if there is no way. A shut gate is no way.
func doors_between(from: Vector3, to: Vector3) -> Array[int]:
	var none: Array[int] = []
	var way = _way(from, to)
	return way if way != null else none


## Whether there is a way to walk from one spot to another, with the gates as they stand.
func reachable(from: Vector3, to: Vector3) -> bool:
	return _way(from, to) != null


## Whether a room cannot be walked to from the start: it is behind a gate that is still shut.
func locked(room: int) -> bool:
	if shut.is_empty() or room < 0:
		return false
	if _open_rooms.is_empty():
		var queue: Array[int] = [maxi(room_at(start), 0)]
		_open_rooms[queue[0]] = true
		while not queue.is_empty():
			var at: int = queue.pop_front()
			for i in doors.size():
				var d: Dictionary = doors[i]
				if shut.has(i) or (d.a != at and d.b != at):
					continue
				var next: int = d.b if d.a == at else d.a
				if not _open_rooms.has(next):
					_open_rooms[next] = true
					queue.append(next)
	return not _open_rooms.has(room)


# The doorways from one spot to another as a list, or null if there is no way.
func _way(from: Vector3, to: Vector3):
	var none: Array[int] = []
	var first := door_at(from) if room_at(from) < 0 else -1
	var last := door_at(to) if room_at(to) < 0 else -1
	var begin: Array = [room_at(from)] if first < 0 else [doors[first].a, doors[first].b]
	var end: Array = [room_at(to)] if last < 0 else [doors[last].a, doors[last].b]
	if begin.has(-1) or end.has(-1):
		return null
	if first >= 0 and first == last:
		return none
	# room -> the doorways gone through to reach it
	var ways := {}
	var queue: Array = []
	for room: int in begin:
		ways[room] = none
		queue.append(room)
	while not queue.is_empty():
		var room: int = queue.pop_front()
		if end.has(room):
			var way: Array[int] = ways[room].duplicate()
			if last >= 0:
				way.append(last)
			return way
		for i in doors.size():
			var d: Dictionary = doors[i]
			if shut.has(i) or (d.a != room and d.b != room):
				continue
			var next: int = d.b if d.a == room else d.a
			if not ways.has(next):
				var way: Array[int] = ways[room].duplicate()
				way.append(i)
				ways[next] = way
				queue.append(next)
	return null


## About how far it is to walk from one spot to another: straight from doorway to doorway.
func walk_length(from: Vector3, to: Vector3) -> float:
	var d := 0.0
	var at := from
	for door in doors_between(from, to):
		d += Combat.flat(at, doors[door].pos)
		at = doors[door].pos
	return d + Combat.flat(at, to)


# How far a spot is from a rectangle of floor; 0 inside it.
static func _gap(r: Rect2, p: Vector3) -> float:
	var at := Vector2(p.x, p.z)
	return at.distance_to(at.clamp(r.position, r.end))


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
		var r := RING if n > 1 else 0.0
		out.append(pack.center + Vector3(cos(a), 0, sin(a)) * r)
	return out
