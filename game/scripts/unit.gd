class_name Unit
extends CharacterBody3D

# A hero or an enemy on the floor. Whoever drives it (the player's keys or a brain) sets `wish`;
# the unit turns that into movement that eases in and out, and turns to face the way it goes.
# Its health and abilities live in the rules, as `c`; this node only shows them.

@export_group("Who")
@export_enum("hero", "enemy") var team := "hero"
## Which hero or enemy it is, as named in rules/heroes.gd or rules/enemies.gd.
@export var def_id := "ranger"
@export var is_player := false
## How tall it stands, for placing its health bar.
@export var height := 1.8

@export_group("Movement")
## Top speed in metres a second.
@export var speed := 8.5
## How quickly it gets up to speed, in metres a second each second.
@export var acceleration := 90.0
## How quickly it stops once nothing is steering it.
@export var braking := 110.0
## How quickly it turns to face the way it is going, in radians a second.
@export var turn_rate := 18.0
## The way it faces, as a turn about the vertical; 0 looks along -Z.
@export_range(-180, 180, 0.1, "radians_as_degrees") var facing := 0.0

@export_group("Jump")
## Upward speed at take-off, in metres a second. The jump is for show: it clears nothing.
@export var jump_speed := 6.6
@export var gravity := 22.0

## Where the driver wants to go: a direction on the floor, up to length 1.
var wish := Vector3.ZERO
## Its side of the rules, and the run it belongs to. Both are set by the run when it starts.
var c: Combatant
var run: Run
## Height of the figure off the floor while jumping.
var lift := 0.0

var _rise := 0.0
var _fall := 0.0
var _flash := 0.0
var _body_mat: StandardMaterial3D
var _body_color := Color.WHITE

@onready var visual: Node3D = $Visual
@onready var shadow: Node3D = $Shadow
@onready var body: MeshInstance3D = $Visual/Body


func _ready() -> void:
	add_to_group("units")
	motion_mode = MOTION_MODE_FLOATING
	visual.rotation.y = facing
	# its own copy of the body colour, so a hit can flash this figure alone
	_body_mat = body.get_surface_override_material(0).duplicate()
	_body_color = _body_mat.albedo_color
	body.set_surface_override_material(0, _body_mat)


func is_alive() -> bool:
	return c == null or c.alive


## A hop on the spot or on the move. It changes nothing in a fight.
func jump() -> void:
	if is_alive() and lift <= 0.0:
		_rise = jump_speed


## A brief flash and swell when it is hit.
func flash() -> void:
	_flash = 1.0


func _physics_process(delta: float) -> void:
	var want := Vector3.ZERO
	if is_alive():
		want = Vector3(wish.x, 0, wish.z).limit_length(1.0) * speed
	var steering := not want.is_zero_approx()
	velocity = Vector3(velocity.x, 0, velocity.z).move_toward(want, (acceleration if steering else braking) * delta)
	move_and_slide()

	if steering:
		_turn_to(want, delta)
	elif is_alive() and c and run:
		# standing still, it faces whoever it is fighting
		var t := run.unit_of(c.target_id)
		if t and t.c.alive and t.c.team != c.team and (c.team == "enemy" or t.c.engaged):
			_turn_to(t.global_position - global_position, delta)

	if lift > 0.0 or _rise > 0.0:
		lift += _rise * delta
		_rise -= gravity * delta
		if lift <= 0.0:
			lift = 0.0
			_rise = 0.0

	# the fallen lie down
	_fall = move_toward(_fall, 0.0 if is_alive() else 1.0, delta * 5.0)
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	visual.rotation = Vector3(0, facing, _fall * PI / 2)
	visual.position.y = lift + _fall * 0.4
	visual.scale = Vector3.ONE * (1.0 + 0.1 * _flash)
	shadow.scale = Vector3.ONE * (1.0 - 0.4 * minf(lift, 1.0))
	_body_mat.albedo_color = _body_color.lerp(Color.WHITE, 0.6 * _flash).darkened(0.45 * _fall)


func _turn_to(dir: Vector3, delta: float) -> void:
	if Vector2(dir.x, dir.z).length_squared() > 0.0001:
		facing = rotate_toward(facing, atan2(-dir.x, -dir.z), turn_rate * delta)


## Moves it somewhere at once, without the camera or the drawing sliding it there.
func place(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	reset_physics_interpolation()
