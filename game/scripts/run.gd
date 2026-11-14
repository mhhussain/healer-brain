class_name Run
extends Node3D

# The run controller: it builds the level, puts the party and the packs in it, owns the rules,
# tells them where every unit stands, ticks them 60 times a second, and turns what happens into
# things you can see.
# Until the menus exist, keys choose the run: F1 to F6 the hero, - and = the level, F8 the place
# (the Drowned Abbey or the sandbox hall), F9 whether the AI plays your hero too.

## The party (tank, healer, two damage dealers), which of them you play, and the level. They
## outlast a reload of the scene, which is how you switch.
static var party: Array[String] = ["warden", "mender", "duelist", "ranger"]
static var player_slot := 3
static var chosen_level := 1
## Where the run is: "abbey" or "sandbox".
static var place := "abbey"
## The AI plays your hero too: for the balance runner and for watching.
static var autoplay := false
## The seed for the run's dice; 0 picks one at random.
static var rng_seed := 0

## In the sandbox hall, start over when it is cleared instead of finishing the run.
@export var endless := true
## Sandbox: seconds after the last pack is cleared before the hall starts over.
@export var respawn_after := 6.0
## Sandbox: the share of damage you take. 1 is the real game.
@export_range(0.05, 1.0) var sandbox_damage_taken := 1.0
@export var hud: CombatHud
@export var camera: IsoCamera

var combat: Combat
var player: Unit
var sandbox := false
## Kept between runs. It is only read and written when this is the game itself, not a test.
var save := SaveData.new()
## Once the run is finished: whether it unlocked the next level.
var unlocked_now := false

static var _restored := false
var _saves := false
var _recorded := false

var _units := {}  # combatant id -> Unit

# loaded when first needed: the scene's own script refers back to this one
const UNIT := "res://scenes/unit.tscn"

@onready var level: LevelBuilder = $Level
@onready var ring: MeshInstance3D = $TargetRing


## Puts that hero in the party in the place of its role, and makes it yours.
static func choose(hero_id: String) -> void:
	var role := Heroes.by_id(hero_id).role
	if role == "tank":
		player_slot = 0
	elif role == "healer":
		player_slot = 1
	else:
		player_slot = 2
		if party[3] == hero_id:
			party[3] = party[2]
	party[player_slot] = hero_id


func _ready() -> void:
	# after the units have moved, so the rules see where they are now
	process_physics_priority = 1
	ring.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_saves = get_tree().current_scene == self
	if _saves:
		save = SaveStore.load_save()
		if not _restored:
			# the first time, pick up where you left off
			_restored = true
			party.assign(save.party)
			player_slot = save.slot
			chosen_level = save.level
	sandbox = place == "sandbox"
	var def := Levels.by_name(place)
	level.build(def)

	combat = Combat.new(chosen_level, rng_seed if rng_seed != 0 else randi())
	combat.endless = sandbox and endless
	combat.autoplay = autoplay
	combat.los = level.sees
	combat.can_stand = level.can_stand
	combat.clear_walk = level.clear_walk
	combat.blocker = level.pillar_between
	for p in def.pillars:
		combat.pillars.append({"pos": p.pos, "r": p.r, "alive": true})
	combat.event.connect(_on_event)

	for i in party.size():
		var c := combat.add_hero(Heroes.by_id(party[i]), i == player_slot)
		c.pos = def.start + Vector3(-i * 1.6, 0, 1.2 if i % 2 else -1.2)
		var u := _spawn(c, PI / -2.0)
		if c.is_player:
			player = u
	for d in def.packs:
		var pack := combat.add_pack(d.name, d.boss)
		pack.lamp = d.lamp
		pack.entry = d.entry
		pack.pull_from = d.pull_from
		pack.stand = d.stand
		pack.room_left = d.room_left
		var posts := LevelDef.posts(d)
		for i in d.enemies.size():
			_spawn(combat.spawn_enemy(d.enemies[i], posts[i], pack.id), PI / 2.0)
	if camera and player:
		camera.follow(player)
	if hud:
		hud.alert("%s, level %d" % [def.name, chosen_level])


# Makes the figure for a combatant, with the player's keys or the AI's legs to drive it.
func _spawn(c: Combatant, facing: float) -> Unit:
	var u: Unit = load(UNIT).instantiate()
	u.team = c.team
	u.is_player = c.is_player
	u.facing = facing
	u.name = c.name.replace(" ", "")
	add_child(u, true)
	u.c = c
	u.run = self
	_units[c.id] = u
	u.setup()
	var driver: Node = PlayerInput.new() if c.is_player and not autoplay else Walker.new()
	driver.name = "PlayerInput" if driver is PlayerInput else "Walker"
	u.add_child(driver)
	u.place(c.pos)
	return u


func unit_of(id: int) -> Unit:
	return _units.get(id)


func all_units() -> Array:
	return _units.values()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# in the Abbey you may start any level you have unlocked; the sandbox has no such limit
	var top := 999 if sandbox or not _saves else save.unlocked
	match key.physical_keycode:
		KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6:
			choose(Heroes.ALL[key.physical_keycode - KEY_F1])
		KEY_MINUS:
			chosen_level = maxi(1, chosen_level - 1)
		KEY_EQUAL:
			chosen_level = mini(top, chosen_level + 1)
		KEY_F8:
			place = "abbey" if sandbox else "sandbox"
		KEY_F9:
			autoplay = not autoplay
		KEY_ENTER, KEY_KP_ENTER:
			if not combat.finished:
				return
		_:
			return
	_remember()
	get_tree().reload_current_scene()


# Keeps the party and level you chose for next time.
func _remember() -> void:
	if not _saves:
		return
	save.party.assign(party)
	save.slot = player_slot
	save.level = clampi(chosen_level, 1, save.unlocked)
	SaveStore.store(save)


# The last boss is down: note the result, and unlock the next level if it was inside the time.
func _finish() -> void:
	_recorded = true
	unlocked_now = save.record(combat.level, player.c.hero.id, combat.total_time(), combat.timed())
	if _saves and not autoplay:
		SaveStore.store(save)


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
	if combat.finished and not _recorded:
		_finish()
	if combat.endless and combat.packs.all(func(p: Pack) -> bool: return p.cleared and combat.time - p.cleared_at >= respawn_after):
		_start_over()


# Sandbox: with every pack cleared, the packs stand back up and the party is put back at the start.
func _start_over() -> void:
	for p in combat.packs:
		combat.reset_pack(p)
	for h in combat.heroes:
		h.pos = level.def.start + Vector3(-h.slot * 1.6, 0, 1.2 if h.slot % 2 else -1.2)
		h.has_goal = false
		h.target_id = 0
		unit_of(h.id).place(h.pos)
	if camera and player:
		camera.follow(player)


func _process(_delta: float) -> void:
	if player == null:
		return
	var t := unit_of(player.c.target_id)
	ring.visible = t != null and t.c.alive
	if ring.visible:
		ring.global_position = t.get_global_transform_interpolated().origin + Vector3(0, 0.05, 0)
		ring.scale = Vector3.ONE * (t.c.radius / 0.6)
	# ally abilities go to the ally under the mouse: a party frame, or the figure itself
	var cam := get_viewport().get_camera_3d()
	if cam:
		var mouse := get_viewport().get_mouse_position()
		var on_frame := hud.ally_at(mouse) if hud else 0
		var figure := unit_under(cam, mouse, "hero")
		combat.hover_ally_id = on_frame if on_frame > 0 else figure.c.id if figure else 0


## The living unit of that team whose figure is under that point of the screen, or null.
func unit_under(cam: Camera3D, screen: Vector2, team: String) -> Unit:
	var from := cam.project_ray_origin(screen)
	var to := from + cam.project_ray_normal(screen) * 500.0
	var best: Unit = null
	var best_d := INF
	for u: Unit in _units.values():
		if u.c.team != team or not u.c.alive:
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
			_spawn(combat.unit(e.id), PI / 2.0)
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
		"clear":
			# a boss is down: the party hops for joy, one after another
			if combat.packs[e.id].boss:
				for h in combat.heroes:
					if h.alive and (not h.is_player or autoplay):
						get_tree().create_timer(0.3 + h.slot * 0.15).timeout.connect(unit_of(h.id).jump)
		"pillar":
			level.destroy_pillar(e.id)
		"pillars_up":
			level.restore_pillars()


# A streak from one unit to another: a thrown harpoon, a bolt, a heal.
func _beam(src: Unit, tgt: Unit, color: Color) -> void:
	if src == null or tgt == null:
		return
	var a := src.global_position + Vector3(0, src.height * 0.7, 0)
	var b := tgt.global_position + Vector3(0, tgt.height * 0.6, 0)
	if Combat.flat(a, b) < 0.1:
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


# Every effect uses these same material settings, so the engine builds their shader once. See
# zone_view.gd for what happens otherwise.
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
