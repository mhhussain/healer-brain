class_name Paths
extends RefCounted

# Finds a way across a level that keeps clear of the packs the party must not wake. The floor
# is cut into squares; a square in the ground a sleeping pack watches costs far more to cross
# than any other, so a way goes through one only when there is no other way at all. The AI asks
# it where to walk between pulls, and the map asks it whether a pull can be reached without
# waking something else.

## The side of a square, in metres.
const CELL := 1.5
## What a step onto watched ground costs, against 1 for a step anywhere else.
const HEAVY := 40.0
## How much further out than a pack can notice the party keeps, in metres.
const SLACK := 1.5
## How far ahead along a way a walker heads straight for, in metres.
const REACH := 8.0
## A way round is long when it is this many times the plain way and this many metres more.
const LONG := 1.5
const LONG_BY := 40.0

var def: LevelDef

var _grid := AStarGrid2D.new()
var _origin := Vector2.ZERO
var _cols := 0
var _rows := 0
# square -> the room it is in, -2 - door for a doorway, -1 for neither
var _place := PackedInt32Array()
# square -> how many of the packs to keep clear of watch it
var _cover := PackedInt32Array()
# pack -> {"at": Vector3, "r": float, "cells": PackedInt32Array}
var _avoided := {}


func _init(level: LevelDef) -> void:
	def = level
	var all: Rect2 = def.floors[0]
	for f in def.floors:
		all = all.merge(f)
	_origin = all.position
	_cols = maxi(1, ceili(all.size.x / CELL))
	_rows = maxi(1, ceili(all.size.y / CELL))
	_grid.region = Rect2i(0, 0, _cols, _rows)
	_grid.cell_size = Vector2(CELL, CELL)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	_grid.fill_solid_region(_grid.region, true)
	_place.resize(_cols * _rows)
	_place.fill(-1)
	_cover.resize(_cols * _rows)
	for f in def.floors:
		for cell in _within(f):
			_grid.set_point_solid(cell, false)
	for i in def.rooms.size():
		for cell in _within(def.rooms[i].rect):
			_place[cell.y * _cols + cell.x] = i
	for i in def.doors.size():
		for cell in _within(def.doors[i].rect):
			_place[cell.y * _cols + cell.x] = -2 - i
			if def.shut.has(i):
				_grid.set_point_solid(cell, true)
	# a unit's half-width is kept clear of everything that stands
	for w in def.walls:
		for cell in _within((w.rect as Rect2).grow(0.5)):
			_grid.set_point_solid(cell, true)
	for p in def.pillars:
		var reach: float = p.r + 0.5
		for cell in _within(Rect2(p.pos.x - reach, p.pos.z - reach, reach * 2.0, reach * 2.0)):
			if Combat.flat(_middle(cell), p.pos) < reach:
				_grid.set_point_solid(cell, true)


# The squares whose middles are in a rectangle of floor.
func _within(r: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var from := ((r.position - _origin) / CELL - Vector2(0.5, 0.5)).ceil()
	var to := ((r.end - _origin) / CELL - Vector2(0.5, 0.5)).floor()
	for z in range(maxi(0, int(from.y)), mini(_rows - 1, int(to.y)) + 1):
		for x in range(maxi(0, int(from.x)), mini(_cols - 1, int(to.x)) + 1):
			out.append(Vector2i(x, z))
	return out


func _middle(cell: Vector2i) -> Vector3:
	return Vector3(_origin.x + (cell.x + 0.5) * CELL, 0, _origin.y + (cell.y + 0.5) * CELL)


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(floori((p.x - _origin.x) / CELL), 0, _cols - 1), clampi(floori((p.z - _origin.y) / CELL), 0, _rows - 1))


# The square a spot is in, or the nearest one to it that can be stood on. (-1, -1) if none is near.
func _open_cell(p: Vector3) -> Vector2i:
	var at := _cell(p)
	if not _grid.is_point_solid(at):
		return at
	var best := Vector2i(-1, -1)
	var best_d := INF
	for z in range(maxi(0, at.y - 2), mini(_rows - 1, at.y + 2) + 1):
		for x in range(maxi(0, at.x - 2), mini(_cols - 1, at.x + 2) + 1):
			var cell := Vector2i(x, z)
			var d := Combat.flat(_middle(cell), p)
			if d < best_d and not _grid.is_point_solid(cell):
				best_d = d
				best = cell
	return best


## A gate has opened: its doorway can be walked.
func open_door(door: int) -> void:
	for cell in _within(def.doors[door].rect):
		_grid.set_point_solid(cell, false)
	for w in def.walls:
		for cell in _within((w.rect as Rect2).grow(0.5)):
			_grid.set_point_solid(cell, true)


## A gate is shut again, as the map shuts them to try a route from its start.
func shut_door(door: int) -> void:
	for cell in _within(def.doors[door].rect):
		_grid.set_point_solid(cell, true)


# ---------- the packs to keep clear of

## How far from a pack's middle the ground it watches runs: as far as it can notice, the ring
## it stands in, and some slack.
static func watch(enemies: int) -> float:
	return Combat.AGGRO + (LevelDef.RING if enemies > 1 else 0.0) + SLACK


## Sets the packs to keep clear of, each {"id": int, "at": its middle, "r": how far it watches,
## "room": its room or -1}. Ground is watched only where the pack could see it: its own room,
## that room's doorways, and what shows through them.
func avoid(list: Array) -> void:
	var wanted := {}
	for z: Dictionary in list:
		wanted[z.id] = z
	for id: int in _avoided.keys():
		if not wanted.has(id) or Combat.flat(_avoided[id].at, wanted[id].at) > CELL * 0.5:
			_mark(_avoided[id].cells, -1)
			_avoided.erase(id)
	for id: int in wanted:
		if _avoided.has(id):
			continue
		var z: Dictionary = wanted[id]
		var cells := _watched(z.at, z.r, z.room)
		_mark(cells, 1)
		_avoided[id] = {"at": z.at, "r": z.r, "cells": cells}


func _mark(cells: PackedInt32Array, by: int) -> void:
	for i in cells:
		_cover[i] += by
		if _cover[i] == (1 if by > 0 else 0):
			_grid.set_point_weight_scale(Vector2i(i % _cols, i / _cols), HEAVY if by > 0 else 1.0)


func _watched(at: Vector3, r: float, room: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var eye := Vector2(at.x, at.z)
	for cell in _within(Rect2(at.x - r, at.z - r, r * 2.0, r * 2.0)):
		var mid := _middle(cell)
		if Combat.flat(mid, at) > r or _grid.is_point_solid(cell):
			continue
		var i := cell.y * _cols + cell.x
		if room < 0 or _shows(_place[i], room, Vector2(mid.x, mid.z), eye):
			out.append(i)
	return out


# Whether a square can be seen from a spot in that room: it is in the room, or in one of its
# doorways, or the line between them runs through a doorway that joins the two rooms.
func _shows(where: int, room: int, mid: Vector2, eye: Vector2) -> bool:
	if where == room:
		return true
	if where == -1:
		return false
	if where <= -2:
		var d: Dictionary = def.doors[-2 - where]
		return d.a == room or d.b == room
	for d in def.doors:
		if ((d.a == room and d.b == where) or (d.b == room and d.a == where)) and LevelDef._crosses(d.rect, mid, eye):
			return true
	return false


# ---------- finding the way

## Whether walking from one spot to another the plain way, from doorway to doorway, would come
## onto ground one of the packs watches. If not, there is nothing to find a way round.
func threatened(from: Vector3, to: Vector3) -> bool:
	return not _avoided.is_empty() and not in_the_way(from, to, true).is_empty()


## The packs whose ground the plain way from one spot to another would come onto. With `first`
## it stops at the first it finds.
func in_the_way(from: Vector3, to: Vector3, first := false) -> Array[int]:
	var out: Array[int] = []
	var stops: Array[Vector2] = [Vector2(from.x, from.z)]
	for door in def.doors_between(from, to):
		stops.append(Vector2(def.doors[door].pos.x, def.doors[door].pos.z))
	stops.append(Vector2(to.x, to.z))
	for id: int in _avoided:
		var z: Dictionary = _avoided[id]
		var mid := Vector2(z.at.x, z.at.z)
		for i in stops.size() - 1:
			if Geometry2D.get_closest_point_to_segment(mid, stops[i], stops[i + 1]).distance_to(mid) < z.r + 0.5:
				out.append(id)
				if first:
					return out
				break
	return out


## The way from one spot to another, as stops a square apart, ending on the spot itself. It
## keeps off watched ground wherever it can. Empty if there is no way.
func way(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := _open_cell(from)
	var b := _open_cell(to)
	if a.x < 0 or b.x < 0:
		return out
	var ids := _grid.get_id_path(a, b)
	if ids.is_empty():
		return out
	for cell in ids:
		out.append(_middle(cell))
	out[out.size() - 1] = Vector3(to.x, 0, to.z)
	return out


## Whether a spot is on ground to keep clear of.
func covered(p: Vector3) -> bool:
	var cell := _cell(p)
	return _cover[cell.y * _cols + cell.x] > 0


## A way cut short where it first comes onto ground to keep clear of. A way that begins on
## such ground is left whole: whoever is on it must get off it.
func short_of(path: PackedVector3Array) -> PackedVector3Array:
	if path.is_empty() or covered(path[0]):
		return path
	for i in path.size():
		if covered(path[i]):
			return path.slice(0, i)
	return path


## The packs whose ground a way crosses, in the order it comes to them.
func wakes(path: PackedVector3Array) -> Array[int]:
	var out: Array[int] = []
	for p in path:
		var cell := _cell(p)
		var i := cell.y * _cols + cell.x
		if _cover[i] <= 0:
			continue
		for id: int in _avoided:
			# by the stop itself, not its square: the last stop is wherever the way was asked to end
			if not out.has(id) and _avoided[id].cells.has(i) and Combat.flat(p, _avoided[id].at) <= _avoided[id].r:
				out.append(id)
	return out


## Where to head for now, for someone at `from` following a way: the furthest stop within
## reach that can be walked straight to without crossing a wall or coming onto watched ground.
func ahead(from: Vector3, path: PackedVector3Array) -> Vector3:
	var nearest := 0
	for i in path.size():
		if Combat.flat(from, path[i]) < Combat.flat(from, path[nearest]):
			nearest = i
	var best := path[mini(nearest + 1, path.size() - 1)]
	var here := _cell(from)
	var inside := _cover[here.y * _cols + here.x] > 0
	for i in range(nearest + 2, path.size()):
		if Combat.flat(from, path[i]) > REACH or not _straight(from, path[i], inside):
			break
		best = path[i]
	return best


func _straight(a: Vector3, b: Vector3, inside: bool) -> bool:
	var steps := maxi(1, ceili(Combat.flat(a, b) / (CELL * 0.5)))
	for k in range(1, steps + 1):
		var cell := _cell(a.lerp(b, float(k) / steps))
		if _grid.is_point_solid(cell) or (not inside and _cover[cell.y * _cols + cell.x] > 0):
			return false
	return true


# ---------- trying a route

## Walks a route through a level and says where it goes wrong. For each pull that cannot be
## made cleanly: {"pull": its place in the route, "wakes": the packs it cannot be reached
## without waking, "gate": the name of the shut gate in its way, or "", "round": the packs it
## is reached a long way round to keep clear of, "metres": how long that way is}. `from` is
## where the party sets out and `done` the packs already dead. Patrols are left out: where one
## is when the party passes is for the party to watch.
static func check(def: LevelDef, route: Route, from: Vector3, done: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ways := Paths.new(def)
	# the level's gates are opened as the walk goes, and put back as they were at the end
	var was_shut := def.shut.duplicate()
	var standing := {}
	for i in def.packs.size():
		if not done.has(i):
			standing[i] = true
	var at := from
	for i in route.pulls.size():
		var pull: Dictionary = route.pulls[i]
		var packs: Array = pull.packs.filter(func(p: int) -> bool: return standing.has(p))
		if packs.is_empty():
			continue
		var list := []
		for p: int in standing:
			var d: Dictionary = def.packs[p]
			if not packs.has(p) and not d.has("path"):
				list.append({"id": p, "at": d.center, "r": watch(d.enemies.size()), "room": d.get("room", -1)})
		ways.avoid(list)
		var woken: Array[int] = []
		var gate := ""
		var round: Array[int] = []
		var metres := 0.0
		for k in packs.size():
			var d: Dictionary = def.packs[packs[k]]
			# a patrol is met wherever it has got to: where the tank holds it stands in for that
			var to: Vector3 = d.center if k > 0 else d.stand if d.has("path") else d.pull_from
			var path := ways.way(at, to)
			if path.is_empty():
				for g in def.gates:
					if def.shut.has(g.door):
						gate = g.name
				if gate == "":
					gate = "a wall"
				break
			for id in ways.wakes(path):
				if not woken.has(id):
					woken.append(id)
			# a clean way that is far longer than the plain one is worth a word
			var length := (path.size() - 1) * CELL
			if k == 0 and ways.wakes(path).is_empty() and length > def.walk_length(at, to) * LONG + LONG_BY:
				round = ways.in_the_way(at, to)
				metres = length
			at = to
		if gate != "":
			# it waits for its gate: the party passes it over until then
			out.append({"pull": i, "wakes": woken, "gate": gate, "round": [], "metres": 0.0})
			continue
		if not woken.is_empty() or not round.is_empty():
			out.append({"pull": i, "wakes": woken, "gate": "", "round": round, "metres": metres})
		# whatever was woken is fought with the pull, and dies with it
		for p: int in packs + woken:
			standing.erase(p)
		at = pull.spots.get(0, def.packs[packs[-1]].stand)
		for k in def.gates.size():
			var g: Dictionary = def.gates[k]
			if def.shut.has(g.door) and g.packs.all(func(p: int) -> bool: return not standing.has(p)):
				def.open_gate(k)
				ways.open_door(g.door)
	def.set_shut(was_shut)
	return out
