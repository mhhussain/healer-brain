extends SceneTree

# A developer tool, not a test: walks the app through its screens so that --write-movie can
# record frames of each to look at. It uses a save file of its own. From the repo root:
#   godot --path game -s tests/tools/screens.gd --write-movie build/shots/f.png --fixed-fps 60 --quit-after 700 -- mender tollhaven
# The last words are the hero you play and the dungeon (the Abbey if left out). It prints the
# frame at which each screen is up.

func _initialize() -> void:
	SaveStore.path = "user://tool-screens-save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path))
	var args := OS.get_cmdline_user_args()
	var hero: String = args[0] if args.size() > 0 else "mender"
	var app: App = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	_walk(app, hero, args[1] if args.size() > 1 and Levels.DUNGEONS.has(args[1]) else "abbey")


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
