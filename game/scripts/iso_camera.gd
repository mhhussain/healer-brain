class_name IsoCamera
extends Camera3D

# The fixed isometric camera: flat (orthographic) projection, looking down from a corner, following
# a target with a little lag and a little lead. It never turns during play; the wheel zooms.

@export var target: Node3D

@export_group("Angle")
## Which corner it looks from, in degrees about the vertical.
@export_range(-180, 180) var yaw_deg := -45.0
## How steeply it looks down.
@export_range(20, 80) var pitch_deg := 45.0
## How far back it sits. With a flat projection this changes nothing you can see, only what clips.
@export var distance := 30.0

@export_group("Follow")
## Seconds for the camera to close most of the gap to the target. 0 locks it on.
@export var lag := 0.12
## Metres the view leads a moving target, so you see more of where you are going.
@export var look_ahead := 1.0
## Seconds for that lead to swing round after a change of direction.
@export var look_ahead_lag := 0.4

@export_group("Zoom")
## Metres of world from the top of the screen to the bottom.
@export var zoom := 18.0
@export var zoom_min := 12.0
@export var zoom_max := 30.0
@export var zoom_step := 1.5
@export var zoom_lag := 0.08

var _focus := Vector3.ZERO
var _lead := Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	# the camera does its own smoothing every drawn frame, from the target's in-between position
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	size = zoom
	if target:
		_focus = target.global_position
	_place()


## Follows that unit from now on, starting right on it.
func follow(unit: Node3D) -> void:
	target = unit
	_focus = unit.global_position
	_lead = Vector3.ZERO
	_place()


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(-zoom_step)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(zoom_step)
	# trackpads: two-finger scroll and pinch
	var pan := event as InputEventPanGesture
	if pan:
		_zoom_by(pan.delta.y * zoom_step * 0.5)
	var pinch := event as InputEventMagnifyGesture
	if pinch:
		_zoom_by(zoom / pinch.factor - zoom)


func _zoom_by(amount: float) -> void:
	zoom = clampf(zoom + amount, zoom_min, zoom_max)


func _process(delta: float) -> void:
	if target:
		var at := target.get_global_transform_interpolated().origin
		var lead := Vector3.ZERO
		var body := target as Unit
		if body and body.speed > 0.0:
			lead = (body.velocity / body.speed).limit_length(1.0) * look_ahead
		_lead = _lead.lerp(lead, _ease(delta, look_ahead_lag))
		_focus = _focus.lerp(at + _lead, _ease(delta, lag))
	size = lerpf(size, zoom, _ease(delta, zoom_lag))
	_place()


# How much of a gap to close this frame so that it closes the same way at any frame rate.
func _ease(delta: float, seconds: float) -> float:
	return 1.0 if seconds <= 0.0 else 1.0 - exp(-delta / seconds)


func _place() -> void:
	rotation_degrees = Vector3(-pitch_deg, yaw_deg, 0)
	global_position = _focus + global_basis.z * distance
