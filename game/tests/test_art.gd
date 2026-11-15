extends GutTest

# Milestone 8: the starter figures and room pieces, and how units and the level wear them.

const ENEMIES := ["brute", "hexer", "archer", "shaman", "berserker", "overseer", "hatchling", "krogg", "velisse", "sulmar"]

var main: Run
var hero: Unit
var enemy: Unit


func before_each():
	Run.place = "sandbox"
	Run.party = ["warden", "mender", "duelist", "ranger"]
	Run.player_slot = 3
	Run.chosen_level = 3
	Run.autoplay = false
	Run.rng_seed = 5
	main = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(main)
	main.combat.ai_plays = false
	hero = main.player
	enemy = main.unit_of(main.combat.packs[0].units[0].id)
	await wait_physics_frames(2)


func after_all():
	Run.place = "abbey"
	Run.chosen_level = 1
	Run.rng_seed = 0


func test_every_hero_and_enemy_has_a_figure_with_the_six_clips():
	for id: String in Heroes.ALL + ENEMIES:
		assert_not_null(Enemies.by_id(id) if id in ENEMIES else Heroes.by_id(id), id + " is in the rules")
		var scene := Figures.scene_for(id)
		assert_not_null(scene, id + " has a figure")
		if scene == null:
			continue
		var figure: Node3D = scene.instantiate()
		var player := figure.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_not_null(player, id + " has clips")
		for clip: String in Figures.CLIPS:
			assert_true(player.has_animation(clip), "%s has the clip %s" % [id, clip])
		assert_eq(player.get_animation("idle").loop_mode, Animation.LOOP_LINEAR, id + " idles on a loop")
		assert_eq(player.get_animation("run").loop_mode, Animation.LOOP_LINEAR, id + " runs on a loop")
		assert_eq(player.get_animation("fall").loop_mode, Animation.LOOP_NONE, id + " falls once")
		figure.free()


func test_a_unit_with_no_figure_keeps_the_capsule():
	assert_null(Figures.scene_for("nobody"))
	assert_not_null(hero.figure, "the Harpooner has a figure")
	assert_false(hero.body.visible, "which stands in for the capsule")


func test_a_figure_faces_the_way_its_unit_faces():
	# figures look along +Z and units along -Z, so the figure is turned half round inside it
	assert_almost_eq(absf(hero.figure.rotation.y), PI, 0.001)


func test_it_runs_when_it_moves_and_idles_when_it_stops():
	var hale := main.unit_of(main.combat.heroes[0].id)
	assert_eq(hale._clip, "idle")
	_send(hale, Vector3(6, 0, 0))
	await wait_physics_frames(10)
	assert_eq(hale._clip, "run")
	hale.c.has_goal = false
	await wait_physics_frames(20)
	assert_eq(hale._clip, "idle")


func test_it_swings_when_it_attacks_but_not_on_the_move():
	var hale := main.unit_of(main.combat.heroes[0].id)
	hale.swing()
	assert_eq(hale._clip, "attack")
	await wait_physics_frames(90)
	assert_eq(hale._clip, "idle", "and goes back to standing")
	_send(hale, Vector3(6, 0, 0))
	await wait_physics_frames(10)
	hale.swing()
	assert_eq(hale._clip, "run", "its legs keep running")


# Sets an AI hero walking that far from where it stands.
func _send(u: Unit, by: Vector3) -> void:
	u.c.goal = u.global_position + by
	u.c.has_goal = true


func test_it_flinches_when_hit_but_not_over_and_over():
	enemy.flash()
	assert_eq(enemy._clip, "hit")
	await wait_physics_frames(40)
	assert_eq(enemy._clip, "idle")
	enemy.flash()
	assert_eq(enemy._clip, "idle", "too soon to flinch again")


func test_it_holds_the_cast_clip_while_casting():
	var wren := main.unit_of(main.combat.heroes[1].id)
	wren.c.cast = Cast.new()
	wren.c.cast.total = 2.0
	await wait_physics_frames(3)
	assert_eq(wren._clip, "cast")


func test_the_dead_fall_by_their_clip_and_do_not_tip_over():
	main.combat.damage(hero.c, enemy.c, 999999.0)
	await wait_physics_frames(30)
	assert_false(enemy.c.alive)
	assert_eq(enemy._clip, "fall")
	assert_almost_eq(enemy.visual.rotation.z, 0.0, 0.001)


func test_a_hit_flashes_one_figure_and_not_the_others_of_its_kind():
	var other := main.unit_of(main.combat.packs[1].units[1].id)
	var twin := main.unit_of(main.combat.packs[1].units[1].id)
	assert_eq(other, twin)
	enemy.flash()
	await wait_physics_frames(1)
	assert_gt(enemy._figure_mats[0].emission.r, 0.2)
	assert_eq(hero._figure_mats[0].emission.r, 0.0)


func test_the_level_is_dressed_with_the_room_pieces():
	var copies := main.level.find_children("*", "MultiMeshInstance3D", true, false)
	assert_gt(copies.size(), 5, "floor, walls and kerbs are laid from pieces")
	var tiles := 0
	for node in copies:
		tiles += (node as MultiMeshInstance3D).multimesh.instance_count
	assert_gt(tiles, 150)
	assert_gt(main.level.nav_polygons(), 10, "and the floor can still be walked")


func test_without_the_pieces_it_is_grey_boxes():
	var plain := LevelBuilder.new()
	plain.dressed = false
	add_child_autofree(plain)
	plain.build(Levels.sandbox())
	assert_eq(plain.find_children("*", "MultiMeshInstance3D", true, false).size(), 0)
	assert_gt(plain.find_children("*", "MeshInstance3D", true, false).size(), 10)
