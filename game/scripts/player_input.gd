class_name PlayerInput
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
	var run := unit.run
	if event.is_action_pressed("jump"):
		unit.jump()
	elif run == null:
		return
	elif event.is_action_pressed("target_next"):
		_tab = true
	elif event.is_action_pressed("clear_target"):
		# Esc clears the target; with none to clear, it opens the menu
		if unit.c.target_id != 0:
			_clear = true
		else:
			_ask_for_menu()
	elif event.is_action_pressed("pause"):
		_ask_for_menu()
	elif event is InputEventKey and event.pressed and not event.echo:
		_use(Bindings.ability_for_key(Run.keys, unit.c.hero.id, event.physical_keycode))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_click = true
			_click_at = event.position
		else:
			# a middle or side button casts whatever is bound to it, wherever the pointer is
			var button := Bindings.combo_of(event.button_index, false, false, false)
			if button in Bindings.MOUSE:
				_use(Bindings.ability_for_mouse(Run.keys, unit.c.hero.id, button))


# The key is used up here, so the menu it opens does not take the same press as "close".
func _ask_for_menu() -> void:
	get_viewport().set_input_as_handled()
	unit.run.pause_requested.emit()


func _use(idx: int, ally_id := 0) -> bool:
	if idx < 0:
		return false
	unit.run.combat.press(idx, ally_id)
	return true


## A click on a party frame: the click-cast bound to it, or failing that the mouse button's own
## ability, lands on that party member.
func click_frame(hero_id: int, event: InputEventMouseButton) -> void:
	var hero := unit.c.hero.id
	var combo := Bindings.combo_of(event.button_index, event.shift_pressed, event.ctrl_pressed, event.alt_pressed)
	if combo == "":
		return
	if not _use(Bindings.ability_for_click(Run.keys, hero, combo), hero_id) and combo in Bindings.MOUSE:
		_use(Bindings.ability_for_mouse(Run.keys, hero, combo), hero_id)


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
		var hit := run.unit_under(cam, _click_at, "enemy")
		if hit:
			unit.c.target_id = hit.c.id
	_tab = false
	_clear = false
	_click = false
