extends Label

# A corner readout for tuning the feel: how fast the hero is going and how smoothly the game draws.

@export var unit: Unit
@export var camera: IsoCamera


func _process(_delta: float) -> void:
	if unit == null or camera == null:
		return
	text = "WASD or Q/E to move, wheel to zoom\n%.1f m/s   zoom %.0f m   %d fps" % [
		unit.velocity.length(), camera.zoom, Engine.get_frames_per_second()]
