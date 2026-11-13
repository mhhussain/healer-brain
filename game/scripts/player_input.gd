extends Node

# Reads the movement keys and steers the unit this sits under, relative to the camera.

@onready var unit: Unit = get_parent()


func _ready() -> void:
	Controls.install()
	# ahead of the unit's own tick, so a key press moves it on the same tick
	process_physics_priority = -1


func _physics_process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	unit.wish = Controls.ground_direction(stick, cam.global_basis)
