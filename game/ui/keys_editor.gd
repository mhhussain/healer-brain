class_name KeysEditor
extends VBoxContainer

# The editor for one hero's bindings: two keys and a mouse button for each ability, and for a
# healer's ally abilities the click on a party frame that casts them.

## A binding changed, so the save should be written.
signal changed

const NONE := "None"
const MOUSE_WORDS := [NONE, "Middle click", "Side back", "Side forward"]
const PROMPT := "Press a key. Esc leaves it as it was; Backspace empties it."

var save: SaveData
var hero_id := ""

var _waiting := {}  # {"ab": id, "slot": 0 or 1} while a key slot is waiting for a key
var _note: Label


func show_hero(from: SaveData, id: String) -> void:
	save = from
	hero_id = id
	_waiting = {}
	_build()


func _build(note := "") -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 8)
	var def := Heroes.by_id(hero_id)
	var healer := not Bindings.default_clicks(hero_id).is_empty()
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 5 if healer else 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	for head: String in ["", "Key", "Second key", "Mouse button"] + (["Click on a party frame"] if healer else []):
		grid.add_child(Kit.label(head, 11, Kit.GREY))
	for ab in def.abilities:
		var name_label := Kit.label(ab.name, 13)
		name_label.tooltip_text = ab.desc
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		grid.add_child(name_label)
		for slot in 2:
			var code: int = save.keys[hero_id][ab.id][slot]
			var waiting: bool = _waiting.get("ab") == ab.id and _waiting.get("slot") == slot
			var b := Kit.button("…" if waiting else Bindings.key_name(code) if code != 0 else "—", _wait.bind(ab.id, slot), 13)
			b.name = "%s_%d" % [ab.id, slot]
			b.custom_minimum_size.x = 64
			grid.add_child(b)
		var mouse := OptionButton.new()
		mouse.name = ab.id + "_mouse"
		for word: String in MOUSE_WORDS:
			mouse.add_item(word)
		mouse.select(Bindings.MOUSE.find(save.mouse[hero_id].get(ab.id, "")) + 1)
		mouse.item_selected.connect(func(i: int) -> void:
			Bindings.set_mouse(save, hero_id, ab.id, "" if i == 0 else Bindings.MOUSE[i - 1])
			_done())
		grid.add_child(mouse)
		if healer:
			if ab.target == "ally":
				var click := OptionButton.new()
				click.name = ab.id + "_click"
				click.add_item(NONE)
				var all := Bindings.combos()
				for combo in all:
					click.add_item(Bindings.combo_name(combo))
				click.select(all.find(save.clicks[hero_id].get(ab.id, "")) + 1)
				click.item_selected.connect(func(i: int) -> void:
					Bindings.set_click(save, hero_id, ab.id, "" if i == 0 else all[i - 1])
					_done())
				grid.add_child(click)
			else:
				grid.add_child(Control.new())
	add_child(grid)
	_note = Kit.label(note if note != "" else PROMPT if not _waiting.is_empty() else "A key or button does one thing: binding it here takes it from where it was.", 12,
		Kit.RED if note != "" else Kit.GOLD if not _waiting.is_empty() else Kit.GREY)
	_note.name = "Note"
	add_child(_note)
	var reset := Kit.button("Back to the usual keys", func() -> void:
		Bindings.reset(save, hero_id)
		_done(), 12)
	reset.name = "Reset"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(reset)


func _wait(ab_id: String, slot: int) -> void:
	_waiting = {"ab": ab_id, "slot": slot}
	_build()


func _done() -> void:
	_waiting = {}
	_build()
	changed.emit()


## Whether a key slot is waiting for a key.
func is_waiting() -> bool:
	return not _waiting.is_empty()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _waiting.is_empty() or key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	capture(key.physical_keycode)


## Gives the waiting slot that key. Esc leaves the slot alone, Backspace and Delete empty it,
## and a key the game keeps for itself is refused with a note saying why.
func capture(code: int) -> void:
	if _waiting.is_empty():
		return
	var ab_id: String = _waiting.ab
	var slot: int = _waiting.slot
	if code == KEY_ESCAPE:
		_waiting = {}
		_build()
	elif code == KEY_BACKSPACE or code == KEY_DELETE:
		Bindings.clear_key(save, hero_id, ab_id, slot)
		_done()
	else:
		var why := Bindings.set_key(save, hero_id, ab_id, slot, code)
		if why != "":
			_build(why + ". Try another.")
		else:
			_done()
