extends Node

# Walks the enemy this sits under to wherever the rules say it wants to go, in a straight line.
# Path-finding round corners comes with the AI milestone.

@onready var unit: Unit = get_parent()


func _ready() -> void:
	process_physics_priority = -1


func _physics_process(_delta: float) -> void:
	var c := unit.c
	unit.wish = Vector3.ZERO
	if c == null or not c.alive or not c.has_goal:
		return
	var to := c.goal - unit.global_position
	to.y = 0
	if to.length() > 0.15:
		unit.wish = to.normalized()
