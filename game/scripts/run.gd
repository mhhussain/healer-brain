class_name Run
extends Node3D

# The run controller: it owns the rules of the fight, tells them where every unit stands, ticks
# them 60 times a second, and turns what happens into things you can see.
# For now it is a sandbox: a dead enemy comes back after a few seconds.

## Seconds before a dead enemy stands up again at its post.
@export var respawn_after := 4.0
@export var hud: CombatHud

var combat := Combat.new()
var player: Unit

var _units := {}  # combatant id -> Unit
var _starts := {}  # combatant id -> where it began
var _dead_for := {}  # enemy id -> seconds dead

# line of sight is judged at about chest height, so low kerbs and crates do not block it
const EYE := Vector3(0, 1.3, 0)
const WALLS := 1

@onready var ring: MeshInstance3D = $TargetRing


func _ready() -> void:
	# after the units have moved, so the rules see where they are now
	process_physics_priority = 1
	ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	combat.los = _sees
	combat.event.connect(_on_event)
	for u: Unit in get_tree().get_nodes_in_group("units"):
		if is_ancestor_of(u):
			_register(u)


func _register(u: Unit) -> void:
	var c: Combatant
	if u.team == "hero":
		c = combat.add_hero(Heroes.by_id(u.def_id), u.is_player)
	else:
		c = combat.add_enemy(Enemies.by_id(u.def_id), u.global_position)
	c.pos = u.global_position
	u.c = c
	u.run = self
	_units[c.id] = u
	_starts[c.id] = u.global_position
	if u.is_player:
		player = u


func unit_of(id: int) -> Unit:
	return _units.get(id)


func all_units() -> Array:
	return _units.values()


func _physics_process(delta: float) -> void:
	for u: Unit in _units.values():
		u.c.pos = u.global_position
		u.c.moved = u.velocity.length_squared() > 0.01
	combat.tick(delta)

	for e in combat.enemies:
		if e.alive:
			_dead_for.erase(e.id)
			continue
		_dead_for[e.id] = _dead_for.get(e.id, 0.0) + delta
		if _dead_for[e.id] >= respawn_after:
			combat.reset_enemy(e)
			e.pos = _starts[e.id]
			unit_of(e.id).place(e.pos)


func _process(_delta: float) -> void:
	var t := unit_of(player.c.target_id) if player else null
	ring.visible = t != null and t.c.alive
	if ring.visible:
		ring.global_position = t.get_global_transform_interpolated().origin + Vector3(0, 0.05, 0)
		ring.scale = Vector3.ONE * (t.c.radius / 0.6)


func _sees(a: Vector3, b: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a + EYE, b + EYE, WALLS)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The living enemy whose figure is under that point of the screen, or null.
func enemy_under(cam: Camera3D, screen: Vector2) -> Unit:
	var from := cam.project_ray_origin(screen)
	var to := from + cam.project_ray_normal(screen) * 500.0
	var best: Unit = null
	var best_d := INF
	for u: Unit in _units.values():
		if u.c.team != "enemy" or not u.c.alive:
			continue
		var foot := u.global_position
		var pts := Geometry3D.get_closest_points_between_segments(from, to, foot, foot + Vector3(0, u.height, 0))
		var d := pts[0].distance_to(pts[1])
		# a little generous, so a near miss still counts
		if d <= u.c.radius * 1.4 + 0.25 and d < best_d:
			best_d = d
			best = u
	return best


func _on_event(e: Dictionary) -> void:
	match e.k:
		"hit":
			var tgt := unit_of(e.id)
			var src := unit_of(e.src)
			tgt.flash()
			if hud:
				if tgt.c.team == "enemy":
					hud.float_text(tgt, str(int(e.amt)), Color("f0b54a") if src and src.is_player else Color("d9d3c2"))
				else:
					hud.float_text(tgt, "-%d" % e.amt, Color("ef5d4a"))
			if src and src.global_position.distance_to(tgt.global_position) > 4.0:
				_beam(src, tgt)
		"heal":
			if hud:
				hud.float_text(unit_of(e.id), "+%d" % e.amt, Color("8fe6b4"))
		"wipe":
			# driven back: the heroes get up where they started
			for h in combat.heroes:
				h.pos = _starts[h.id]
				unit_of(h.id).place(h.pos)


# A streak from the attacker to its target for a ranged hit.
func _beam(src: Unit, tgt: Unit) -> void:
	var a := src.global_position + Vector3(0, src.height * 0.7, 0)
	var b := tgt.global_position + Vector3(0, tgt.height * 0.6, 0)
	if a.distance_to(b) < 0.1:
		return
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.07, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = src.c.hero.color if src.c.hero else Color("b58cf0")
	var streak := MeshInstance3D.new()
	streak.mesh = box
	streak.material_override = mat
	streak.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(streak)
	streak.global_position = (a + b) / 2.0
	streak.look_at(b)
	streak.scale.z = a.distance_to(b)
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(streak.queue_free)
