class_name Unit
extends CharacterBody3D

# A hero or an enemy on the floor. Whoever drives it (the player's keys now, the AI later) sets
# `wish`; the unit turns that into movement that eases in and out, and turns to face the way it goes.

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

## Where the driver wants to go: a direction on the floor, up to length 1.
var wish := Vector3.ZERO

@onready var visual: Node3D = $Visual


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	visual.rotation.y = facing


func _physics_process(delta: float) -> void:
	var want := Vector3(wish.x, 0, wish.z).limit_length(1.0) * speed
	var steering := not want.is_zero_approx()
	velocity = Vector3(velocity.x, 0, velocity.z).move_toward(want, (acceleration if steering else braking) * delta)
	move_and_slide()
	if steering:
		facing = rotate_toward(facing, atan2(-want.x, -want.z), turn_rate * delta)
	visual.rotation.y = facing
