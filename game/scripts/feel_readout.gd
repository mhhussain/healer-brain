extends Label

# A corner readout for tuning the feel: how fast the hero is going and how smoothly the game
# draws. F3 shows and hides it.

@export var run: Run
@export var camera: IsoCamera


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		visible = not visible


func _process(_delta: float) -> void:
	if not visible or run == null or run.player == null or camera == null:
		return
	text = "%.1f m/s   zoom %.0f m   %d fps%s" % [run.player.velocity.length(), camera.zoom, Engine.get_frames_per_second(),
		"   AI playing" if Run.autoplay else ""]
