class_name Walker
extends Node

# Walks the unit this sits under to wherever the rules say it wants to go, round walls and
# pillars, along the navigation mesh. It is the legs of every enemy and every AI hero.

## Seconds before it looks for a fresh path to the same goal.
const REPATH := 0.5

var _path := PackedVector3Array()
var _next := 0
var _path_goal := Vector3.INF
var _age := 0.0

@onready var unit: Unit = get_parent()


func _ready() -> void:
	# ahead of the unit's own tick
	process_physics_priority = -1


func _physics_process(delta: float) -> void:
	var c := unit.c
	unit.wish = Vector3.ZERO
	if c == null or unit.run == null or not c.alive or not c.has_goal:
		_path_goal = Vector3.INF
		return
	var here := unit.global_position
	_age += delta
	if Combat.flat(_path_goal, c.goal) > 0.5 or _age > REPATH:
		_path = unit.run.level.path(here, c.goal)
		_next = 1
		_path_goal = c.goal
		_age = 0.0
	while _next < _path.size() - 1 and Combat.flat(here, _path[_next]) < 0.4:
		_next += 1
	# with no path, such as a goal off the mesh, head straight for it
	var last := _next >= _path.size() - 1
	var stop := _path[_next] if _next < _path.size() else c.goal
	var to := Vector3(stop.x - here.x, 0, stop.z - here.z)
	var d := to.length()
	if d < 0.05:
		return
	# ease off over the last stretch so it settles on the spot instead of running through it
	unit.wish = to / d * (clampf(d / 0.8, 0.2, 1.0) if last else 1.0)
