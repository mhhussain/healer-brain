class_name App
extends Node

# The game as a whole: the title, the party setup, the run, the pause menu and the summary, and
# the save that outlasts them. It is the only thing that reads or writes the save file.
#
# M opens the map during a run, between fights, and closes it again. Two keys are for looking
# under the bonnet: F9 lets the AI play your hero too, and F8 swaps the dungeon for the sandbox
# hall. Either starts the run over.

const RUN := "res://scenes/run.tscn"

var save: SaveData
var run: Run
## "title", "opening", "setup", "route" (planning before a run), "loading", "run", "paused",
## "map" (the planner over a run) or "summary".
var state := "title"
var screen: Control
## The narrator: the opening and the ending.
var narrator: Voice
## The music, which plays on through the menus, and the clicks of their buttons.
var music: Music
var clicks: Sound

## Frames the new run is drawn under the loading card before it starts.
var warm_frames := 8

var _layer: CanvasLayer
var _told_opening := false
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
	var playing := run != null and is_instance_valid(run) and state in ["run", "paused", "map", "summary"]
	music.want = Music.loop_for(run, music.want) if playing else "calm_0"
	music.quiet = state != "run"
	music.ducked = narrator.is_talking() or (playing and run.voice.is_talking())
	music.late = playing and not run.combat.finished and run.combat.time >= run.combat.time_limit - 120.0


func _show(next: Control, new_state: String) -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
	# the setup screen replaces itself after each change: find whichever is there now
	for old in _layer.get_children():
		old.queue_free()
	screen = next
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
	_show(Screens.title(show_opening), "title")


## The story so far, read aloud, the first time you go on from the title.
func show_opening() -> void:
	if _told_opening:
		show_setup()
		return
	_told_opening = true
	_show(Screens.opening(show_setup), "opening")
	for line in Story.all_lines().slice(0, Story.OPENING.size()):
		narrator.say(line)


func show_setup() -> void:
	_end_run()
	narrator.hush()
	_show(Screens.setup(save, _store, start_run, show_route), "setup")


## The planner, before a run: the route for the place the next run is in.
func show_route() -> void:
	_end_run()
	var map := RouteMap.new()
	map.open(Levels.by_name(_place()), save, save.party)
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
	narrator.hush()
	_store()
	Run.party.assign(save.party)
	Run.player_slot = save.slot
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
	# a run the AI played for you is not yours to record
	var unlocked_now := false
	if not Run.autoplay and Run.place == save.place:
		unlocked_now = save.record(c.level, run.player.c.hero.id, c.total_time(), c.timed())
		_store()
	get_tree().paused = true
	_show(Screens.summary(c, unlocked_now, save.unlocked > c.level, start_run, _next_level, show_setup), "summary")
	narrator.say(Story.ending(c.timed(), Run.place))


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
				start_run()
	if state in ["run", "paused", "map", "summary"]:
		if code == KEY_F9:
			Run.autoplay = not Run.autoplay
			start_run()
		elif code == KEY_F8:
			Run.place = "sandbox" if Run.place != "sandbox" else save.place
			start_run()
