extends GutTest

# Milestone 8: sound effects and music.

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
	# the same sound twice in a row is wanted here
	main.sound.gap = 0.0
	hero = main.player
	enemy = main.unit_of(main.combat.packs[0].units[0].id)
	await wait_physics_frames(2)


func after_all():
	Run.place = "abbey"
	Run.chosen_level = 1
	Run.rng_seed = 0


# The sounds playing now, by name, without the number of the take.
func heard() -> Array:
	var names := []
	for player: AudioStreamPlayer in main.sound._players:
		if player.playing and player.stream:
			names.append(player.stream.resource_path.get_file().get_basename().rstrip("_0123456789"))
	return names


func test_every_sound_has_its_files():
	for sound: String in Sound.SOUNDS:
		var takes: int = Sound.SOUNDS[sound].takes
		for take in range(1 if takes > 0 else 0, takes + 1):
			assert_ne(Sound.file_of(sound, take), "", "%s take %d has a file" % [sound, take])


func test_every_ability_named_for_a_sound_is_a_real_ability():
	var real := {}
	for id: String in Heroes.ALL:
		for ab in Heroes.by_id(id).abilities:
			real[ab.id] = true
	for sound: String in Sound.ABILITIES:
		assert_has(Sound.SOUNDS, sound)
		for id: String in Sound.ABILITIES[sound]:
			assert_has(real, id, "%s is a hero's ability" % id)
	assert_eq(Sound.sound_of_ability("quickshot"), "shot")
	assert_eq(Sound.sound_of_ability("mend"), "", "a heal is heard when it lands, not when it is cast")


func test_using_an_ability_is_heard():
	hero.c.target_id = enemy.c.id
	main.combat.press(0)
	await wait_physics_frames(3)
	assert_has(heard(), "shot", "the Harpooner throws")


func test_a_heavy_blow_on_a_hero_is_heard_and_a_scratch_on_another_is_not():
	var hale := main.combat.heroes[0]
	main.combat.damage(enemy.c, hale, 5.0, "phys", {"raw": true})
	assert_does_not_have(heard(), "blow")
	main.combat.damage(enemy.c, hale, hale.max_hp * 0.3, "phys", {"raw": true})
	assert_has(heard(), "blow")


func test_the_dead_are_heard_going_down():
	main.combat.damage(hero.c, enemy.c, 999999.0)
	assert_has(heard(), "death")


func test_a_monk_chants_while_casting_and_stops_when_cut_off():
	var cantor := main.combat.packs[0].units[1]
	assert_eq(cantor.enemy.id, "hexer")
	var bolt: EnemyAbility = cantor.enemy.abilities.filter(func(a: EnemyAbility) -> bool: return a.interruptible)[0]
	main.combat.engage(main.combat.packs[0], hero.c)
	main.combat.start_enemy_cast(cantor, bolt, main.combat.heroes[0])
	await wait_frames(2)
	assert_has(heard(), "chant")
	main.combat.interrupt(hero.c, cantor)
	assert_does_not_have(heard(), "chant")
	assert_has(heard(), "interrupt")


func test_a_cleared_room_rings_and_does_not_toll():
	for e in main.combat.packs[0].units:
		main.combat.damage(hero.c, e, 999999.0)
	await wait_physics_frames(2)
	assert_has(heard(), "clear")
	assert_does_not_have(heard(), "toll", "the line that says so is not a warning")
	main.combat.alert("The Last Toll. Hide behind a pillar!")
	assert_has(heard(), "toll")


# ---------- music

func test_every_loop_has_a_file_and_comes_round():
	var music := Music.new()
	add_child_autofree(music)
	for mood: String in ["calm", "fight", "boss"]:
		for zone in 3:
			var loop := "%s_%d" % [mood, zone]
			assert_ne(Music.file_of(loop), "", loop + " has a file")
			var stream := music._stream(loop) as AudioStreamWAV
			assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, loop + " loops")
			assert_gt(stream.loop_end, 100000)
	assert_ne(Music.file_of("tide_bell"), "")


func test_the_music_follows_the_run():
	assert_eq(Music.loop_for(main), "calm_0")
	main.combat.engage(main.combat.packs[0], hero.c)
	assert_eq(Music.loop_for(main), "fight_0")
	main.combat.packs[0].boss = true
	assert_eq(Music.loop_for(main), "boss_0")


func test_the_music_changes_with_the_part_of_the_abbey():
	Run.place = "abbey"
	var abbey: Run = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(abbey)
	abbey.combat.ai_plays = false
	await wait_physics_frames(2)
	for i in 3:
		abbey.combat.packs[i].cleared = true
	assert_eq(Music.loop_for(abbey), "calm_1", "past the first boss it is the Infirmary")
	abbey.combat.engage(abbey.combat.packs[5], abbey.player.c)
	abbey.combat.packs[3].cleared = true
	abbey.combat.packs[4].cleared = true
	assert_eq(Music.loop_for(abbey), "boss_1")
	Run.place = "sandbox"


func test_one_loop_fades_out_under_the_next():
	var music := Music.new()
	add_child_autofree(music)
	music.fade = 0.2
	music.want = "calm_0"
	music.quiet = false
	await wait_frames(30)
	assert_eq(music.playing(), "calm_0")
	var first := music._on
	assert_almost_eq(first.volume_db, music.loud_db, 0.5)
	music.want = "fight_0"
	music.ducked = true
	await wait_frames(60)
	assert_ne(music._on, first)
	assert_false(first.playing, "the old loop has stopped")
	assert_almost_eq(music._on.volume_db, music.loud_db + music.duck_db, 0.5, "lower while someone speaks")


func test_the_app_plays_quietly_on_the_menus_and_clicks_its_buttons():
	var app: App = load("res://scenes/app.tscn").instantiate()
	add_child_autofree(app)
	await wait_frames(2)
	assert_eq(app.music.want, "calm_0")
	assert_true(app.music.quiet)
	app.clicks.gap = 0.0
	(app.screen.find_child("Begin", true, false) as Button).pressed.emit()
	var clicked := app.clicks._players.any(func(p: AudioStreamPlayer) -> bool: return p.playing)
	assert_true(clicked, "a button clicks")
	await wait_frames(2)
	assert_true(app.music.ducked, "the narrator is reading the opening")
	await app.start_run()
	await wait_frames(2)
	assert_false(app.music.quiet)
	# in the sandbox the first pack is in reach from the start, so the AI may already have pulled
	assert_has(["calm_0", "fight_0"], app.music.want)
