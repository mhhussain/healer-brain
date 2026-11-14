extends Label

# A corner readout for tuning the feel: how fast the hero is going and how smoothly the game draws.

@export var run: Run
@export var camera: IsoCamera


func _process(_delta: float) -> void:
	if run == null or run.player == null or camera == null:
		return
	text = "WASD or Q/E move, Space jumps, wheel zooms\nTab or click targets, Esc clears, 1 to 6 are your abilities\nF1 to F6 hero,  - and = level,  F8 %s,  F9 AI plays for you%s\n%.1f m/s   zoom %.0f m   %d fps" % [
		"the Abbey" if run.sandbox else "the sandbox hall", " (on)" if Run.autoplay else "", run.player.velocity.length(), camera.zoom, Engine.get_frames_per_second()]
