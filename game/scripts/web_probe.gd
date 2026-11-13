extends Node

# On the web build with ?debug in the address, publishes a little state as window.fourfold, so a
# browser test can read where the hero is and how the game is running.

@export var unit: Unit
@export var camera: IsoCamera


func _ready() -> void:
	set_process(OS.has_feature("web") and str(JavaScriptBridge.eval("location.search")).contains("debug"))


func _process(_delta: float) -> void:
	var state := {
		"x": unit.global_position.x,
		"z": unit.global_position.z,
		"speed": unit.velocity.length(),
		"facing": unit.facing,
		"zoom": camera.zoom,
		"fps": Engine.get_frames_per_second(),
		"ticks": Engine.get_physics_frames(),
	}
	JavaScriptBridge.eval("window.fourfold=" + JSON.stringify(state), true)
