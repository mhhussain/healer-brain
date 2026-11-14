extends GutTest

# Milestone 6: the interface during a run, the screens round it, and the app that ties them up.

const TEMP_SAVE := "user://test-ui-save.json"

var _saved_keys: SaveData


func before_all():
	SaveStore.path = TEMP_SAVE
	_saved_keys = Run.keys


func after_all():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	SaveStore.path = "user://fourfold-save.json"
	Run.keys = _saved_keys
	Run.place = "abbey"
	Run.party.assign(["warden", "mender", "duelist", "ranger"])
	Run.player_slot = 3
	Run.chosen_level = 1
	Run.autoplay = false
	Run.rng_seed = 0
	get_tree().paused = false


func before_each():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	Run.keys = SaveData.new()
	Run.autoplay = false
	Run.place = "abbey"
	get_tree().paused = false


func click(button := MOUSE_BUTTON_LEFT, shift := false) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.shift_pressed = shift
	return e


func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


## A run in the sandbox hall as that hero, with the rest of the party standing still.
func run_as(hero_id: String) -> Run:
	Run.place = "sandbox"
	Run.party.assign(["warden", "mender", "duelist", "ranger"])
	Run.choose(hero_id)
	Run.chosen_level = 1
	Run.rng_seed = 3
	var run: Run = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(run)
	run.combat.ai_plays = false
	return run


# ---------- during a run

func test_the_bottom_of_the_screen_is_laid_out_as_agreed():
	var run := run_as("ranger")
	await wait_frames(3)
	var hud := run.hud
	var me: Control = hud.find_child("Player", true, false)
	var them: Control = hud.find_child("Target", true, false)
	var party := hud.party_frame(0)
	var action := hud.action_button(0)
	assert_eq(hud.find_child("Party", true, false).get_child_count(), 4)
	assert_eq(hud.find_child("Actions", true, false).get_child_count(), 6)
	# from the bottom up: the action bar, the party row, then you and your target
	assert_gt(action.global_position.y, party.global_position.y, "the action bar is below the party")
	assert_gt(party.global_position.y, me.global_position.y, "the party is below your frame")
	assert_almost_eq(me.global_position.y, them.global_position.y, 1.0, "you and your target share a row")
	assert_lt(me.global_position.x, them.global_position.x, "you on the left, your target on the right")
	assert_almost_eq(me.global_position.x, party.global_position.x, 2.0, "your frame lines up with the left of the party row")
	assert_lt(action.get_global_rect().end.y, hud.size.y, "and it all fits on the screen")


func test_clicking_an_action_button_uses_the_ability():
	var run := run_as("ranger")
	await wait_physics_frames(2)
	var enemy := run.combat.enemies[0]
	run.player.c.target_id = enemy.id
	run.hud.action_button(0)._gui_input(click())
	await wait_physics_frames(3)
	assert_lt(enemy.hp, enemy.max_hp)


func test_a_healer_casts_by_clicking_party_frames():
	var run := run_as("mender")
	await wait_physics_frames(2)
	var me := run.player.c
	var tank := run.combat.heroes[0]
	assert_eq(me.hero.id, "mender")
	tank.hp = 1000.0
	run.hud.party_frame(0)._gui_input(click(MOUSE_BUTTON_RIGHT))
	await wait_physics_frames(3)
	assert_gt(tank.hp, 1300.0, "a right click is Spark, at once")
	tank.hp = 1000.0
	me.gcd = 0.0
	run.hud.party_frame(0)._gui_input(click(MOUSE_BUTTON_LEFT))
	await wait_physics_frames(3)
	assert_not_null(me.cast, "a left click starts Warm Light")
	assert_eq(me.cast.target_id, tank.id)
	me.cast = null
	me.gcd = 0.0
	run.combat.add_aura(tank, {"id": "wither", "name": "Withering Verse", "dur": 10.0, "src_id": 0, "debuff": true, "dispellable": true})
	run.hud.party_frame(0)._gui_input(click(MOUSE_BUTTON_LEFT, true))
	await wait_physics_frames(3)
	assert_false(run.combat.has_aura(tank, "wither"), "Shift and left click lifts the curse")


func test_a_mouse_button_binding_lands_on_the_frame_it_is_clicked_on():
	var run := run_as("mender")
	await wait_physics_frames(2)
	var tank := run.combat.heroes[0]
	Bindings.set_mouse(Run.keys, "mender", "ward", "M")
	run.hud.party_frame(0)._gui_input(click(MOUSE_BUTTON_MIDDLE))
	await wait_physics_frames(3)
	assert_true(run.combat.has_aura(tank, "ward"))


func test_keys_use_the_bindings():
	var run := run_as("ranger")
	await wait_physics_frames(2)
	var input: PlayerInput = run.player.get_node("PlayerInput")
	var enemy := run.combat.enemies[0]
	run.player.c.target_id = enemy.id
	Bindings.set_key(Run.keys, "ranger", "quickshot", 1, KEY_F)
	input._unhandled_input(key(KEY_F))
	await wait_physics_frames(3)
	assert_gte(enemy.max_hp - enemy.hp, 60.0, "F is Snap Throw now")
	input._unhandled_input(key(KEY_QUOTELEFT))
	await wait_physics_frames(3)
	assert_true(run.combat.has_aura(run.player.c, "tumble"), "` is the personal defensive")
	assert_eq(Bindings.label(Run.keys, "ranger", "quickshot"), "1 · F")


func test_a_tooltip_says_what_an_ability_costs_and_does():
	var def := Heroes.by_id("mender")
	assert_eq(AbilityButton.details(def, def.abilities[0]),
		"Heal 420. Also heals the most injured other ally within 10 m of the target for 30%.\n40 lamplight, 2 s cast, 30 m")
	var warden := Heroes.by_id("warden")
	assert_eq(AbilityButton.details(warden, warden.abilities[3]),
		"Silence the target's cast.\ninstant, 15 s cooldown, melee, does not wait for other abilities")


func test_esc_clears_the_target_then_asks_for_the_menu():
	var run := run_as("ranger")
	watch_signals(run)
	await wait_physics_frames(2)
	var input: PlayerInput = run.player.get_node("PlayerInput")
	run.player.c.target_id = run.combat.enemies[0].id
	input._unhandled_input(key(KEY_ESCAPE))
	await wait_physics_frames(2)
	assert_eq(run.player.c.target_id, 0)
	assert_signal_not_emitted(run, "pause_requested")
	input._unhandled_input(key(KEY_ESCAPE))
	assert_signal_emitted(run, "pause_requested")


# ---------- the keys editor

func test_the_editor_takes_a_key_and_refuses_the_games_own():
	var save := SaveData.new()
	var editor := KeysEditor.new()
	add_child_autofree(editor)
	editor.show_hero(save, "ranger")
	watch_signals(editor)
	assert_null(editor.find_child("quickshot_click", true, false), "no click column for a hero who does not heal")
	(editor.find_child("piercing_1", true, false) as Button).pressed.emit()
	assert_true(editor.is_waiting())
	editor.capture(KEY_W)
	assert_true(editor.is_waiting(), "W is refused, and it keeps waiting")
	assert_string_contains((editor.find_child("Note", true, false) as Label).text, "W is kept for moving")
	editor.capture(KEY_F)
	assert_false(editor.is_waiting())
	assert_eq((editor.find_child("piercing_1", true, false) as Button).text, "F")
	assert_signal_emit_count(editor, "changed", 1)
	(editor.find_child("volley_0", true, false) as Button).pressed.emit()
	editor.capture(KEY_F)
	assert_eq((editor.find_child("piercing_1", true, false) as Button).text, "—", "taking a key empties where it was")
	(editor.find_child("volley_0", true, false) as Button).pressed.emit()
	editor.capture(KEY_ESCAPE)
	assert_eq((editor.find_child("volley_0", true, false) as Button).text, "F", "Esc leaves it")
	(editor.find_child("volley_0", true, false) as Button).pressed.emit()
	editor.capture(KEY_BACKSPACE)
	assert_eq(Bindings.label(save, "ranger", "volley"), "", "Backspace empties it")
	(editor.find_child("Reset", true, false) as Button).pressed.emit()
	assert_eq(Bindings.label(save, "ranger", "volley"), "3")


func test_the_editor_gives_healers_a_click_column_for_ally_abilities():
	var save := SaveData.new()
	var editor := KeysEditor.new()
	add_child_autofree(editor)
	editor.show_hero(save, "mender")
	var click := editor.find_child("quick_click", true, false) as OptionButton
	assert_not_null(click)
	assert_eq(click.get_item_text(click.selected), "Right click")
	assert_null(editor.find_child("rebuke_click", true, false), "Rebuke is aimed at an enemy")
	click.item_selected.emit(Bindings.combos().find("X2") + 1)
	assert_eq(Bindings.ability_for_click(save, "mender", "X2"), 1)
	var mouse := editor.find_child("ward_mouse", true, false) as OptionButton
	mouse.item_selected.emit(1)
	assert_eq(Bindings.label(save, "mender", "ward"), "5 · ` · Mid")


# ---------- the screens

func test_the_setup_screen_changes_the_crew_and_the_level():
	var save := SaveData.new()
	save.unlocked = 3
	var changes := [0]
	var started := [false]
	var holder := Control.new()
	add_child_autofree(holder)
	holder.add_child(Screens.setup(save, func() -> void: changes[0] += 1, func() -> void: started[0] = true))
	var now := func() -> Control: return holder.get_child(holder.get_child_count() - 1)
	(now.call().find_child("Pick1", true, false) as OptionButton).item_selected.emit(1)
	assert_eq(save.party[1], "bloomweaver")
	(now.call().find_child("You1", true, false) as Button).pressed.emit()
	assert_eq(save.slot, 1)
	assert_not_null(now.call().find_child("dew_click", true, false), "the keys shown are the Kelpwife's now")
	(now.call().find_child("Pick3", true, false) as OptionButton).item_selected.emit(0)
	assert_eq(save.party, ["warden", "bloomweaver", "duelist", "duelist"], "the same hero twice is allowed")
	assert_null(now.call().find_child("Level4", true, false), "only unlocked levels are offered")
	(now.call().find_child("Level3", true, false) as Button).pressed.emit()
	assert_eq(save.level, 3)
	assert_gt(changes[0], 3)
	(now.call().find_child("Start", true, false) as Button).pressed.emit()
	assert_true(started[0])


# ---------- the app

func test_the_app_goes_from_title_to_run_to_summary_and_keeps_the_save():
	var app: App = load("res://scenes/app.tscn").instantiate()
	add_child_autofree(app)
	assert_eq(app.state, "title")
	assert_eq(app.save.unlocked, 1, "a fresh save, from the test's own file")
	(app.screen.find_child("Begin", true, false) as Button).pressed.emit()
	assert_eq(app.state, "setup")
	app.save.party.assign(["warden", "mender", "duelist", "pyromancer"])
	app.save.slot = 3
	app.start_run()
	assert_eq(app.state, "run")
	assert_eq(app.run.player.c.hero.id, "pyromancer")
	assert_eq(Run.keys, app.save, "the run reads its keys from the save")
	await wait_physics_frames(3)

	app.run.pause_requested.emit()
	assert_eq(app.state, "paused")
	assert_true(get_tree().paused)
	assert_not_null(app.screen.find_child("stifle_0", true, false), "the pause menu has the keys editor")
	app._unhandled_input(key(KEY_ESCAPE))
	assert_eq(app.state, "run")
	assert_false(get_tree().paused)

	# the last boss falls inside the time
	var c := app.run.combat
	for e in c.enemies.duplicate():
		c.damage(app.run.player.c, e, 9999999.0)
	await wait_physics_frames(3)
	assert_eq(app.state, "summary")
	assert_true(get_tree().paused)
	assert_string_contains((app.screen.find_child("Result", true, false) as Label).text, "Timed")
	assert_eq(app.save.unlocked, 2)
	assert_true(app.save.bests.has("pyromancer"))
	assert_eq(SaveStore.load_save().unlocked, 2, "and it is in the file")

	(app.screen.find_child("Next", true, false) as Button).pressed.emit()
	assert_eq(app.state, "run")
	assert_eq(app.run.combat.level, 2)
	assert_false(get_tree().paused)
	await wait_physics_frames(2)
	app.run.pause_requested.emit()
	(app.screen.find_child("Abandon", true, false) as Button).pressed.emit()
	assert_eq(app.state, "setup")
	await wait_frames(2)
	assert_null(app.run, "abandoning ends the run")
	assert_eq(app.save.unlocked, 2, "and records nothing")


func test_a_run_the_ai_played_is_not_recorded():
	var app: App = load("res://scenes/app.tscn").instantiate()
	add_child_autofree(app)
	Run.autoplay = true
	app.start_run()
	await wait_physics_frames(3)
	for e in app.run.combat.enemies.duplicate():
		app.run.combat.damage(app.run.player.c, e, 9999999.0)
	await wait_physics_frames(3)
	assert_eq(app.state, "summary")
	assert_eq(app.save.unlocked, 1)
	assert_true(app.save.bests.is_empty())
