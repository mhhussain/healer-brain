class_name App
extends Node

# The game as a whole: the title, the party setup, the run, the pause menu and the summary, and
# the save that outlasts them. It is the only thing that reads or writes the save file.
#
# M turns the sound off and on anywhere. Two keys are for looking under the bonnet: F9 lets the
# AI play your hero too, and F8 swaps the Abbey for the sandbox hall. Either starts the run over.

const RUN := "res://scenes/run.tscn"

var save: SaveData
var run: Run
## "title", "opening", "setup", "run", "paused" or "summary".
var state := "title"
var screen: Control
## The narrator: the opening and the ending.
var narrator: Voice

var _layer: CanvasLayer
var _told_opening := false


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
	_apply_sound()
	show_title()


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
	_show(Screens.setup(save, _store, start_run), "setup")


func _end_run() -> void:
	get_tree().paused = false
	if run and is_instance_valid(run):
		run.queue_free()
	run = null


## Starts a run with the crew and level in the save.
func start_run() -> void:
	_end_run()
	narrator.hush()
	_store()
	Run.party.assign(save.party)
	Run.player_slot = save.slot
	Run.chosen_level = save.level
	run = load(RUN).instantiate()
	run.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(run)
	move_child(run, 0)
	run.finished.connect(_on_finished)
	run.pause_requested.connect(pause)
	_show(null, "run")


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
	if not Run.autoplay and Run.place == "abbey":
		unlocked_now = save.record(c.level, run.player.c.hero.id, c.total_time(), c.timed())
		_store()
	get_tree().paused = true
	_show(Screens.summary(c, unlocked_now, save.unlocked > c.level, start_run, _next_level, show_setup), "summary")
	narrator.say(Story.ending(c.timed()))


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
	if code == KEY_M and not editing:
		save.muted = not save.muted
		_store()
		var box := screen.find_child("Mute", true, false) as CheckBox if screen else null
		if box:
			box.set_pressed_no_signal(save.muted)
		return
	match state:
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
	if state in ["run", "paused", "summary"]:
		if code == KEY_F9:
			Run.autoplay = not Run.autoplay
			start_run()
		elif code == KEY_F8:
			Run.place = "sandbox" if Run.place == "abbey" else "abbey"
			start_run()
