class_name App
extends Node

# The game as a whole: the title, the start screen and the editors behind it, the run, the pause
# menu, the summary and the chest, and the save that outlasts them. It is the only thing that
# reads or writes the save file.
#
# M opens the map during a run, between fights, and closes it again. Two keys are for looking
# under the bonnet: F9 lets the AI play your hero too, and F8 swaps the dungeon for the sandbox
# hall. Either starts the run over.

const RUN := "res://scenes/run.tscn"

var save: SaveData
var run: Run
## "title", "opening", "setup", "route" (planning before a run), "team", "gear", "settings",
## "loading", "run", "paused", "map" (the planner over a run), "summary" or "chest".
var state := "title"
## The screen that is up, if any. A screen that changes the save builds itself again in the
## same place, so this is whichever is there now.
var screen: Control:
	get: return _layer.get_child(_layer.get_child_count() - 1) as Control if _layer and _layer.get_child_count() > 0 else null
## What the chest of the run just finished holds: a list of {"item", "state"}, as
## GearScreens.chest shows it. Whatever is not taken is gone when the next thing begins.
var chest: Array = []
## The narrator: the opening and the ending.
var narrator: Voice
## The music, which plays on through the menus, and the clicks of their buttons.
var music: Music
var clicks: Sound

## Frames the new run is drawn under the loading card before it starts.
var warm_frames := 8

var _layer: CanvasLayer
var _dice := RandomNumberGenerator.new()
var _told_opening := false
# how many levels the run just finished unlocked, for the summary, and the coin it paid
var _opened := 0
var _paid := 0
# counts the runs asked for, so a start that was overtaken by another gives up
var _starting := 0
# room pieces read ahead of the run, held so they are not read again
var _kept: Array[Resource] = []


func _ready() -> void:
	# the menus work while the run is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	Controls.install()
	save = SaveStore.load_save()
	Run.keys = save
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	narrator = Voice.new()
	narrator.name = "Narrator"
	add_child(narrator)
	narrator.started.connect(func(line: Dictionary, _seconds: float) -> void:
		if state == "opening" and screen:
			Screens.light(screen, line.id))
	music = Music.new()
	music.name = "Music"
	add_child(music)
	clicks = Sound.new()
	clicks.name = "Clicks"
	add_child(clicks)
	# every button on every screen clicks, however the screen was made
	get_tree().node_added.connect(_on_node_added)
	_apply_sound()
	show_title()


func _on_node_added(node: Node) -> void:
	if node is BaseButton and _layer.is_ancestor_of(node):
		(node as BaseButton).pressed.connect(clicks.play.bind("ui_click"))


# The music follows the game: quiet on the menus, the run's own loop under a run, lower while
# anyone is speaking, and the tide bell once the clock is in its last two minutes.
func _process(_delta: float) -> void:
	var playing := run != null and is_instance_valid(run) and state in ["run", "paused", "map", "summary", "chest", "gear"]
	music.want = Music.loop_for(run, music.want) if playing else "calm_0"
	music.quiet = state != "run"
	music.ducked = narrator.is_talking() or (playing and run.voice.is_talking())
	music.late = playing and not run.combat.finished and run.combat.time >= run.combat.time_limit - 120.0


func _show(next: Control, new_state: String) -> void:
	for old in _layer.get_children():
		_layer.remove_child(old)
		old.queue_free()
	state = new_state
	if next:
		_layer.add_child(next)


# Called whenever something in the save may have changed.
func _store() -> void:
	_apply_sound()
	SaveStore.store(save)


func _apply_sound() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(save.volume, 0.0001)))
	AudioServer.set_bus_mute(master, save.muted or save.volume <= 0.0)


func show_title() -> void:
	_end_run()
	_show(Screens.title(show_opening, show_gear.bind(show_title)), "title")


## The story so far, read aloud, the first time you go on from the title.
func show_opening() -> void:
	if _told_opening:
		show_setup()
		return
	_told_opening = true
	_show(Screens.opening(show_setup), "opening")
	for line in Story.all_lines().slice(0, Story.OPENING.size()):
		narrator.say(line)


## The start screen: the dungeon and level, the team and the route, side by side.
func show_setup() -> void:
	_end_run()
	chest = []
	narrator.hush()
	_show(Screens.setup(save, _store, start_run, {"route": show_route, "team": show_team, "gear": show_gear.bind(show_setup), "settings": show_settings}), "setup")


## The teams: who goes in and what they wear.
func show_team() -> void:
	_show(GearScreens.team(save, _store, show_setup), "team")


## Everything owned. `back` is where its Back button leads: the screen it was opened from.
func show_gear(back: Callable) -> void:
	_show(GearScreens.inventory(save, _store, back), "gear")


## How to play, the sound, the keys, and keeping the save as a file.
func show_settings(note := "") -> void:
	var team := Teams.in_use(save)
	_show(Screens.settings(save, team.party[team.slot], _store, show_setup, save_to_file, load_from_file, note), "settings")


## Keeps a copy of the save as a file of text.
func save_to_file() -> void:
	_store()
	show_settings(SaveStore.save_file(save))


## Loads such a copy, in place of everything here. In a browser a file is asked for first.
func load_from_file() -> void:
	if OS.has_feature("web"):
		SaveStore.ask_for_file(func(text: String) -> void: _take_save(SaveData.from_text(text)))
		show_settings("Choose the file you saved.")
	else:
		_take_save(SaveStore.load_file(), "There is no save at %s." % SaveStore.file_path())


func _take_save(loaded: SaveData, if_not := "That file is not a Fourfold save.") -> void:
	if loaded == null:
		if state == "settings":
			show_settings(if_not)
		return
	save = loaded
	Run.keys = save
	_store()
	if state == "settings":
		show_settings("Loaded. Everything is as it was in the file.")


## The planner, before a run: the route for the place the next run is in.
func show_route() -> void:
	_end_run()
	var map := RouteMap.new()
	map.open(Levels.by_name(_place()), save, Teams.in_use(save).party)
	map.changed.connect(_store)
	map.closed.connect(close_map)
	_show(map, "route")


## The planner over a run. The run stands still while it is open. Not in a fight.
func open_map() -> void:
	if state != "run":
		return
	if run.combat.in_combat:
		if run.hud:
			run.hud.alert("The map cannot be opened in a fight.")
		return
	get_tree().paused = true
	var map := RouteMap.new()
	map.open(run.level.def, save, Run.party, run.combat)
	map.changed.connect(_store)
	map.closed.connect(close_map)
	_show(map, "map")


## Closes the planner: back to the run it was over, or to the setup screen.
func close_map() -> void:
	if not state in ["map", "route"]:
		return
	(screen as RouteMap).finish()
	if state == "route":
		show_setup()
		return
	get_tree().paused = false
	_show(null, "run")


func _end_run() -> void:
	# a run still being made ready is called off
	_starting += 1
	get_tree().paused = false
	if run and is_instance_valid(run):
		run.queue_free()
	run = null


## Starts a run with the crew and level in the save. Making one ready takes a moment (longer
## in a browser), so a card with a bar is shown meanwhile; wait on this call to know when the
## run has begun.
func start_run() -> void:
	_end_run()
	chest = []
	narrator.hush()
	_store()
	# the team goes in as it is now: what it wears cannot be changed until the run is left
	var team := Teams.in_use(save)
	Run.party.assign(team.party)
	Run.player_slot = team.slot
	Run.gear = Teams.worn(save, team).duplicate(true)
	var level := Levels.by_name(_place())
	Run.chosen_level = save.level
	Run.route = save.route_for(level)
	_show(Screens.loading(level.name), "loading")
	_starting += 1
	var mine := _starting
	var bar := screen.find_child("Bar", true, false) as ProgressBar
	var step := screen.find_child("Step", true, false) as Label
	# the card has to be drawn before the work that would freeze it
	await _frames(2)

	# read the figures and the room pieces one a frame, so the bar can move
	var cast := Figures.cast_of(Run.party, level)
	var files := LevelBuilder.piece_files()
	var total := float(cast.size() + files.size() + 2)
	step.text = "Waking the drowned"
	for i in cast.size():
		Figures.scene_for(cast[i])
		bar.value = (i + 1) / total
		await _frames(1)
		if mine != _starting or not is_inside_tree():
			return
	step.text = "Laying the stones"
	music.preload_all()
	for i in files.size():
		_kept.append(load(files[i]))
		bar.value = (cast.size() + i + 1) / total
		await _frames(1)
		if mine != _starting or not is_inside_tree():
			return

	# build the run under the card and hold it still for a few frames, with one of everything
	# that can appear in it in front of the camera: the first time a kind of thing is drawn the
	# engine builds its shader, and that stall belongs here, not in the first fight
	step.text = "Lighting the lamps"
	run = load(RUN).instantiate()
	run.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(run)
	move_child(run, 0)
	run.finished.connect(_on_finished)
	run.pause_requested.connect(pause)
	get_tree().paused = true
	bar.value = (total - 1.0) / total
	var warmers := run.warm_up(cast)
	await _frames(warm_frames)
	for node in warmers:
		if is_instance_valid(node):
			node.queue_free()
	if mine != _starting or not is_inside_tree():
		return
	get_tree().paused = false
	_show(null, "run")


# Where the next run is: the dungeon chosen in the save, unless the sandbox hall was asked for.
func _place() -> String:
	if Run.place != "sandbox":
		Run.place = save.place
	return Run.place


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func pause() -> void:
	if state != "run":
		return
	get_tree().paused = true
	_show(Screens.pause(save, run.player.c.hero.id, _store, resume, show_setup), "paused")


func resume() -> void:
	if state != "paused":
		return
	get_tree().paused = false
	_show(null, "run")


func _on_finished() -> void:
	var c := run.combat
	# a run the AI played for you is not yours to record, and earns no chest and no coin
	_opened = 0
	_paid = 0
	chest = []
	if not Run.autoplay and Run.place == save.place:
		_opened = save.record(c.level, run.player.c.hero.id, c.total_time(), c.timed(), "", c.time_limit, {"party": Run.party, "slot": Run.player_slot})
		_paid = Items.pay(save.place, c.level, c.timed())
		save.coin += _paid
		_dice.randomize()
		for item in Items.chest(_dice, save.place, c.level, c.timed(), save.items, save.dry):
			chest.append({"item": item, "state": ""})
		# a chest that could have held a legendary and did not makes the next likelier to
		if c.level >= Items.LEGENDARY_FROM:
			save.dry = 0 if chest.any(func(e: Dictionary) -> bool: return e.item.rarity == Items.LEGENDARY) else save.dry + 1
		_store()
	get_tree().paused = true
	_show(Screens.summary(c, _opened, save.unlocked, start_run, _next_level, show_setup,
		show_chest if not chest.is_empty() else Callable()), "summary")
	narrator.say(Story.ending(c.timed(), Run.place))


## What the run gave: each thing is taken or left, and then it is on to the next run.
func show_chest() -> void:
	if chest.is_empty() or run == null:
		return
	var level := run.combat.level
	var go := {"again": start_run, "setup": show_setup, "gear": show_gear.bind(show_chest)}
	if save.unlocked > level:
		go["next"] = _next_level
	_show(GearScreens.chest(chest, save, _store, go, level, _paid), "chest")


func _next_level() -> void:
	save.level = mini(save.level + 1, save.unlocked)
	start_run()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.physical_keycode
	var enter := code == KEY_ENTER or code == KEY_KP_ENTER
	var editing := screen and (screen.find_child("Keys", true, false) as KeysEditor) != null \
		and (screen.find_child("Keys", true, false) as KeysEditor).is_waiting()
	match state:
		"run":
			if code == KEY_M:
				open_map()
		"map", "route":
			if code == KEY_M or code == KEY_ESCAPE:
				close_map()
		"title":
			if enter or code == KEY_SPACE:
				show_opening()
		"opening":
			if enter or code == KEY_SPACE or code == KEY_ESCAPE:
				show_setup()
		"paused":
			if (code == KEY_ESCAPE or code == KEY_P) and not editing:
				resume()
		"summary":
			if enter:
				if chest.is_empty():
					start_run()
				else:
					show_chest()
		"team", "gear", "settings":
			if code == KEY_ESCAPE and not editing:
				(screen.find_child("Back", true, false) as Button).pressed.emit()
	if state in ["run", "paused", "map", "summary", "chest"]:
		if code == KEY_F9:
			Run.autoplay = not Run.autoplay
			start_run()
		elif code == KEY_F8:
			Run.place = "sandbox" if Run.place != "sandbox" else save.place
			start_run()
