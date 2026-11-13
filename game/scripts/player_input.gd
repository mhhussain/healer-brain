extends Node

# The player's keys and mouse for the unit this sits under: moving relative to the camera,
# jumping, targeting and abilities. Presses are noted as they arrive and acted on in the tick.

@onready var unit: Unit = get_parent()

var _tab := false
var _clear := false
var _click := false
var _click_at := Vector2.ZERO


func _ready() -> void:
	Controls.install()
	# ahead of the unit's own tick, so a key press moves it on the same tick
	process_physics_priority = -1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		unit.jump()
	elif event.is_action_pressed("target_next"):
		_tab = true
	elif event.is_action_pressed("clear_target"):
		_clear = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click = true
		_click_at = event.position
	elif unit.run:
		for i in Controls.ABILITY_SLOTS:
			if event.is_action_pressed("ability_%d" % (i + 1)):
				unit.run.combat.press(i)


func _physics_process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	unit.wish = Controls.ground_direction(stick, cam.global_basis)

	var run := unit.run
	if run == null:
		return
	if _tab:
		run.combat.tab_target()
	if _clear:
		unit.c.target_id = 0
	if _click:
		var hit := run.enemy_under(cam, _click_at)
		if hit:
			unit.c.target_id = hit.c.id
	_tab = false
	_clear = false
	_click = false
