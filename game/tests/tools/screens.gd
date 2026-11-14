extends SceneTree

# A developer tool, not a test: walks the app through its screens so that --write-movie can
# record frames of each to look at. It uses a save file of its own. From the repo root:
#   godot --path game -s tests/tools/screens.gd --write-movie build/shots/f.png --fixed-fps 60 --quit-after 700 -- mender
# The last word is the hero you play. It prints the frame at which each screen is up.

func _initialize() -> void:
	SaveStore.path = "user://tool-screens-save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path))
	var args := OS.get_cmdline_user_args()
	var hero: String = args[0] if args.size() > 0 else "mender"
	var app: App = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	_walk(app, hero)


func _walk(app: App, hero: String) -> void:
	await _frames(40)
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
	app.start_run()
	# let the party pull and fight for a while, with the AI playing your hero so something happens
	app.run.combat.autoplay = true
	await _frames(330)
	_say("run")
	app.pause()
	await _frames(40)
	_say("pause")
	app.resume()
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
