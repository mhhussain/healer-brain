class_name App
extends Node

# The game as a whole: the title, the party setup, the run, the pause menu and the summary, and
# the save that outlasts them. It is the only thing that reads or writes the save file.
#
# Two keys are for looking under the bonnet: F9 lets the AI play your hero too, and F8 swaps the
# Abbey for the sandbox hall. Either starts the run over.

const RUN := "res://scenes/run.tscn"

var save: SaveData
var run: Run
## "title", "setup", "run", "paused" or "summary".
var state := "title"
var screen: Control

var _layer: CanvasLayer


func _ready() -> void:
	# the menus work while the run is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	Controls.install()
	save = SaveStore.load_save()
	Run.keys = save
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
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


func _store() -> void:
	SaveStore.store(save)


func show_title() -> void:
	_end_run()
	_show(Screens.title(show_setup), "title")


func show_setup() -> void:
	_end_run()
	_show(Screens.setup(save, _store, start_run), "setup")


func _end_run() -> void:
	get_tree().paused = false
	if run and is_instance_valid(run):
		run.queue_free()
	run = null


## Starts a run with the crew and level in the save.
func start_run() -> void:
	_end_run()
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


func _next_level() -> void:
	save.level = mini(save.level + 1, save.unlocked)
	start_run()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.physical_keycode
	var enter := code == KEY_ENTER or code == KEY_KP_ENTER
	match state:
		"title":
			if enter or code == KEY_SPACE:
				show_setup()
		"paused":
			var editor := screen.find_child("Keys", true, false) as KeysEditor
			if (code == KEY_ESCAPE or code == KEY_P) and not (editor and editor.is_waiting()):
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
