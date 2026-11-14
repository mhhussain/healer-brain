class_name Run
extends Node3D

# The run controller: it owns the rules, tells them where every unit stands, ticks them 60 times
# a second, and turns what happens into things you can see.
# For now it is a sandbox: you pick any hero and level, packs stand back up a few seconds after
# they are cleared, and you take far less damage than you should, since you are alone.

## The hero and level to play. They outlast a reload of the scene, which is how you switch.
static var chosen_hero := "ranger"
static var chosen_level := 3

@export var sandbox := true
## Sandbox: seconds before a cleared pack stands up again at its posts.
@export var respawn_after := 4.0
## Sandbox: the share of damage you take. 1 is the real game.
@export_range(0.05, 1.0) var sandbox_damage_taken := 0.1
@export var hud: CombatHud

var combat: Combat
var player: Unit

var _units := {}  # combatant id -> Unit

# line of sight is judged at about chest height, so low kerbs and crates do not block it
const EYE := Vector3(0, 1.3, 0)
const WALLS := 1
# loaded when first needed: the scene's own script refers back to this one
const ENEMY := "res://scenes/enemy.tscn"

@onready var ring: MeshInstance3D = $TargetRing


func _ready() -> void:
	# after the units have moved, so the rules see where they are now
	process_physics_priority = 1
	ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	combat = Combat.new(chosen_level, randi())
	combat.endless = sandbox
	combat.los = _sees
	combat.event.connect(_on_event)
	var found := get_tree().get_nodes_in_group("units").filter(func(u: Unit) -> bool: return is_ancestor_of(u))
	for u: Unit in found:
		if u.team == "hero":
			var def := Heroes.by_id(chosen_hero if u.is_player else u.def_id)
			_bind(u, combat.add_hero(def, u.is_player))
			u.c.pos = u.global_position
			if u.is_player:
				player = u
	for u: Unit in found:
		if u.team == "enemy":
			while combat.packs.size() <= u.pack:
				combat.add_pack()
			_bind(u, combat.spawn_enemy(u.def_id, u.global_position, u.pack))
	# beaten, the party starts again from where it began
	if player:
		for p in combat.packs:
			p.entry = player.global_position + Vector3(2, 0, 1.5)


func _bind(u: Unit, c: Combatant) -> void:
	u.c = c
	u.run = self
	_units[c.id] = u
	u.setup()


func unit_of(id: int) -> Unit:
	return _units.get(id)


func all_units() -> Array:
	return _units.values()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not sandbox or key == null or not key.pressed or key.echo:
		return
	var hero := Heroes.ALL.find(chosen_hero)
	var level := chosen_level
	match key.physical_keycode:
		KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6:
			hero = key.physical_keycode - KEY_F1
		KEY_MINUS:
			level = maxi(1, level - 1)
		KEY_EQUAL:
			level += 1
		_:
			return
	chosen_hero = Heroes.ALL[hero]
	chosen_level = level
	get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	for u: Unit in _units.values():
		var c := u.c
		c.pos = u.global_position
		c.facing = u.forward()
		c.moved = u.velocity.length_squared() > 0.01
		if c.moved:
			c.move_dir = u.velocity.normalized()
			c.last_move_t = combat.time
	if sandbox and player and player.c.alive and sandbox_damage_taken < 1.0 and not combat.has_aura(player.c, "sandbox"):
		combat.add_aura(player.c, {"id": "sandbox", "name": "Sandbox", "dur": 99999.0, "src_id": player.c.id, "taken": sandbox_damage_taken})
	combat.tick(delta)
	if sandbox:
		for p in combat.packs:
			if p.cleared and combat.time - p.cleared_at >= respawn_after:
				combat.reset_pack(p)


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
					if e.amt > 0.0:
						hud.float_text(tgt, str(int(e.amt)), Color("f0b54a") if src and src.is_player else Color("d9d3c2"))
				else:
					hud.float_text(tgt, "-%d" % e.amt if e.amt > 0.0 else "absorbed", Color("ef5d4a"))
		"heal":
			if hud:
				hud.float_text(unit_of(e.id), "+%d" % e.amt, Color("8fe6b4"))
		"text":
			if hud:
				hud.float_at(e.at + Vector3(0, 2.6, 0), e.s, e.color)
		"alert":
			if hud:
				hud.alert(e.s)
		"beam":
			_beam(unit_of(e.src), unit_of(e.id), e.color)
		"ring":
			_ring(e.at, e.r, e.color)
		"boom":
			_ring(e.at, e.r, Color("ef5d4a"))
		"dash":
			unit_of(e.id).dash(e.dir, e.dist)
		"spawn":
			var c := combat.unit(e.id)
			var u: Unit = load(ENEMY).instantiate()
			u.team = "enemy"
			u.def_id = c.enemy.id
			u.pack = c.pack_id
			add_child(u)
			_bind(u, c)
			u.place(c.pos)
		"despawn":
			var u := unit_of(e.id)
			if u:
				_units.erase(e.id)
				u.queue_free()
		"wipe":
			# driven back: everyone is where the rules have put them
			for u: Unit in _units.values():
				u.place(u.c.pos)
		"reset":
			for c in combat.packs[e.id].units:
				unit_of(c.id).place(c.pos)


# A streak from one unit to another: a thrown harpoon, a bolt, a heal.
func _beam(src: Unit, tgt: Unit, color: Color) -> void:
	if src == null or tgt == null:
		return
	var a := src.global_position + Vector3(0, src.height * 0.7, 0)
	var b := tgt.global_position + Vector3(0, tgt.height * 0.6, 0)
	if a.distance_to(b) < 0.1:
		return
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.07, 1.0)
	var streak := _effect(box, color)
	streak.global_position = (a + b) / 2.0
	streak.look_at(b)
	streak.scale.z = a.distance_to(b)
	var tween := create_tween()
	tween.tween_property(streak.material_override, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(streak.queue_free)


# A ring that spreads across the floor: an attack that hits everything round a spot.
func _ring(at: Vector3, r: float, color: Color) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 4
	var hoop := _effect(torus, color)
	hoop.global_position = Vector3(at.x, 0.06, at.z)
	hoop.scale = Vector3(r * 0.35, 1, r * 0.35)
	var tween := create_tween().set_parallel()
	tween.tween_property(hoop, "scale", Vector3(r, 1, r), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(hoop.material_override, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(hoop.queue_free)


func _effect(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(node)
	return node
