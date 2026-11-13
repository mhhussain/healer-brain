class_name Controls
extends RefCounted

# The keys the game uses, by where they sit on the keyboard. Rebinding comes in a later milestone.
const KEYS := {
	"move_left": [KEY_A, KEY_Q],
	"move_right": [KEY_D, KEY_E],
	"move_up": [KEY_W],
	"move_down": [KEY_S],
	"jump": [KEY_SPACE],
	"target_next": [KEY_TAB],
	"clear_target": [KEY_ESCAPE],
	"ability_1": [KEY_1],
	"ability_2": [KEY_2],
	"ability_3": [KEY_3],
	"ability_4": [KEY_4],
	"ability_5": [KEY_5],
	"ability_6": [KEY_6],
}
const ABILITY_SLOTS := 6


static func install() -> void:
	for action: String in KEYS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		for code: Key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)


## What to print on a button for that action: its first key.
static func label(action: String) -> String:
	return OS.get_keycode_string(KEYS[action][0])


# Turns the movement keys (x to the right of the screen, y down it) into a direction on the floor,
# as the camera sees it: "up" is away from the camera, whichever way the camera is turned.
static func ground_direction(stick: Vector2, camera_basis: Basis) -> Vector3:
	var right := Vector3(camera_basis.x.x, 0, camera_basis.x.z).normalized()
	var away := Vector3(-camera_basis.z.x, 0, -camera_basis.z.z).normalized()
	return (right * stick.x - away * stick.y).limit_length(1.0)
