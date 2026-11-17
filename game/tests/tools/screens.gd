extends SceneTree

# A developer tool, not a test: walks the app through its screens so that --write-movie can
# record frames of each to look at. It uses a save file of its own. From the repo root:
#   godot --path game -s tests/tools/screens.gd --write-movie build/shots/f.png --fixed-fps 60 --quit-after 700 -- mender tollhaven
# The last words are the hero you play and the dungeon (the Abbey if left out). It prints the
# frame at which each screen is up. With "gear" as a third word it walks the screens for gear
# instead: the start screen, the teams, the inventory, the settings, a run with a trinket worn,
# and the chest (about 420 frames). With "rare" it loads the save with everything in it and walks
# what rare gear added: the start screen at level 12, the inventory with the shop and a gamble,
# the sets, a legendary refused, a run with an epic on each key, and a chest with a legendary in it
# (about 480 frames).

func _initialize() -> void:
	SaveStore.path = "user://tool-screens-save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path))
	var args := OS.get_cmdline_user_args()
	var hero: String = args[0] if args.size() > 0 else "mender"
	var app: App = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	var dungeon: String = args[1] if args.size() > 1 and Levels.DUNGEONS.has(args[1]) else "abbey"
	if args.has("rare"):
		_walk_rare(app)
	elif args.has("gear"):
		_walk_gear(app, hero, dungeon)
	else:
		_walk(app, hero, dungeon)


func _walk_gear(app: App, hero: String, dungeon: String) -> void:
	await _frames(20)
	var save := app.save
	save.place = dungeon
	save.unlocked = 6
	save.level = 4
	Run.choose(hero)
	save.party.assign(Run.party)
	save.slot = Run.player_slot
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 14:
		save.take(Items.roll(rng, "abbey" if i % 2 else "tollhaven", 4, 6.0 + i % 5))
	save.take(Items.trinket("great_key", 14))
	save.take(Items.trinket("seal", 7))
	save.record(4, hero, 600.0, true, "", Levels.by_name(dungeon).time_limit, {"party": save.party, "slot": save.slot})
	save.level = 4
	app.show_setup()
	await _frames(30)
	_say("start screen")
	app.show_team()
	await _frames(30)
	_say("the default team")
	save.team = Teams.copy(save, Teams.in_use(save))
	app.show_team()
	await _frames(30)
	_say("a team of your own")
	save.team = 0
	app.show_gear(app.show_setup)
	await _frames(30)
	_say("gear")
	app.show_settings()
	await _frames(30)
	_say("settings")
	await app.start_run()
	app.run.combat.autoplay = true
	await _frames(200)
	_say("run with a trinket")
	for e in app.run.combat.enemies.duplicate():
		app.run.combat.damage(app.run.player.c, e, 9999999.0)
	await _frames(30)
	_say("summary")
	app.show_chest()
	await _frames(30)
	_say("chest")
	await _frames(10)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path))
	quit()


func _walk_rare(app: App) -> void:
	await _frames(20)
	app._take_save(FullSave.build())
	var save := app.save
	save.level = 12
	app.show_setup()
	await _frames(30)
	_say("start screen at level 12")
	app.show_gear(app.show_setup)
	await _frames(30)
	_say("gear and the shop")
	GearScreens.dice.seed = 8
	(app.screen.find_child("Gamble_weapon", true, false) as Button).pressed.emit()
	await _frames(30)
	_say("after a gamble")
	var names := save.teams.map(func(t: Dictionary) -> String: return t.name)
	save.team = names.find("The three sets") + 1
	app.show_team()
	await _frames(30)
	_say("the three sets")
	save.team = names.find("The Undertow") + 1
	app.show_team()
	(app.screen.find_child("Armour0", true, false) as OptionButton).item_selected.emit(1)
	await _frames(30)
	_say("a second legendary refused")
	save.team = names.find("Epic abilities") + 1
	save.level = 1
	await app.start_run()
	app.run.combat.autoplay = true
	await _frames(200)
	_say("run with an epic on each key")
	for e in app.run.combat.enemies.duplicate():
		app.run.combat.damage(app.run.player.c, e, 9999999.0, "phys", {"raw": true})
	await _frames(30)
	_say("summary")
	app.chest = [{"item": Items.epic("reaving", 40, "Harpoon", "tollhaven"), "state": ""}, {"item": Items.set_piece("vigil", "trinket", 41), "state": ""},
		{"item": Items.legendary("vesper_bell", 64), "state": ""}]
	app.show_chest()
	await _frames(30)
	_say("chest")
	await _frames(10)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path))
	quit()


func _walk(app: App, hero: String, dungeon: String) -> void:
	await _frames(40)
	app.save.place = dungeon
	_say("title")
	app.show_opening()
	await _frames(200)
	_say("opening")
	app.save.unlocked = 6
	app.save.level = 3
	app.save.bests[hero] = {"level": 5, "time": 644.0}
	Run.choose(hero)
	app.save.party.assign(Run.party)
	app.save.slot = Run.player_slot
	app.show_setup()
	await _frames(60)
	_say("setup")
	# the planner: two packs in the first pull, with a spot for the tank and one for a damage dealer
	app.show_route()
	var map := app.screen as RouteMap
	await _frames(10)
	map._on_pack(1, false)
	map._on_spot(0, map.def.packs[1].stand, true)
	map._on_spot(3, map.def.doors[1].pos + Vector3(-4, 0, 0), true)
	map.route.pulls[0].go = true
	map.select(0)
	await _frames(30)
	_say("route")
	map.view.zoom_about(map.view.to_screen(map.def.packs[1].center), 3.0)
	map.view._set_hover(1)
	await _frames(30)
	_say("route, closer")
	app.close_map()
	await _frames(20)
	_say("setup with a route")
	await app.start_run()
	# let the party pull and fight for a while, with the AI playing your hero so something happens
	app.run.combat.autoplay = true
	await _frames(330)
	_say("run")
	app.pause()
	await _frames(40)
	_say("pause")
	app.resume()
	# the map over the run, once the fight is won
	for pack in app.run.combat.packs:
		if pack.engaged:
			for e in pack.units:
				app.run.combat.damage(app.run.player.c, e, 9999999.0)
	await _frames(90)
	_say("run, between pulls")
	app.open_map()
	await _frames(30)
	_say("map")
	app.close_map()
	for e in app.run.combat.enemies.duplicate():
		app.run.combat.damage(app.run.player.c, e, 9999999.0)
	await _frames(40)
	_say("summary")
	await _frames(20)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path))
	quit()


func _say(what: String) -> void:
	print("screens: %s at frame %d" % [what, Engine.get_frames_drawn() - 1])


func _frames(n: int) -> void:
	for i in n:
		await process_frame
