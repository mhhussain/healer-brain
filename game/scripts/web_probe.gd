extends Node

# On the web build with ?debug in the address, publishes a little state as window.fourfold, so a
# browser test can read where the hero is and how the game is running.

@export var run: Run
@export var camera: IsoCamera


func _ready() -> void:
	set_process(OS.has_feature("web") and str(JavaScriptBridge.eval("location.search")).contains("debug"))


func _process(_delta: float) -> void:
	var unit := run.player
	if unit == null:
		return
	var state := {
		"x": unit.global_position.x,
		"z": unit.global_position.z,
		"speed": unit.velocity.length(),
		"facing": unit.facing,
		"zoom": camera.zoom,
		"fps": Engine.get_frames_per_second(),
		"ticks": Engine.get_physics_frames(),
	}
	if unit.c:
		var combat := unit.run.combat
		var t := combat.unit(unit.c.target_id)
		state.merge({
			"hp": unit.c.hp, "res": unit.c.res, "gcd": unit.c.gcd, "lift": unit.lift,
			"in_combat": combat.in_combat, "error": combat.error,
			"target": t.name if t else "", "target_hp": t.hp if t else 0.0,
		})
	JavaScriptBridge.eval("window.fourfold=" + JSON.stringify(state), true)
