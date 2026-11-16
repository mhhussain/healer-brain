class_name RouteMap
extends Control

# The route planner: the map on the left, and on the right the list of pulls with the count
# above it. It is laid out like the planners players of timed dungeons already use.
#
# Click a pack to put it in the pull being edited, and again to take it out. Shift-click, or
# "Add a pull", starts a new pull. Click a row to edit that pull, drag a row to change the
# order, right-click it to insert, join or delete. The markers (a shield for the tank, a cross
# for the healer, a sword for each damage dealer) are dragged onto the map to say where the
# tank holds the pull and where the others stand. Resting the pointer on a pack or a row lists
# its enemies and what they do.
#
# The route is kept in the save as it is changed, in whichever of the level's three slots is
# in use. Opened over a run, it edits that run's plan as well: packs already dead are shown as
# done and cannot be moved.

## The route or the slot in use changed, and the save should be written.
signal changed
## "Done" was pressed.
signal closed

const SIDE := 410.0
const ROW := 32.0
const HINT := "Click a pack to add it to the pull you are editing; click it again to take it out. Shift-click starts a new pull with it. Drag a row to change the order; right-click a row for more. Rest the pointer on a pack or a row to see what its enemies do. Wheel to zoom, drag to move the map."
const DETAILS_WIDTH := 400.0

var def: LevelDef
var save: SaveData
## The plan being edited. Over a run this is the run's own plan.
var route: Route
var combat: Combat
var view: MapView
## The pull being edited.
var current := 0
## The level enemies are described at: the run's, or the one chosen for the next run.
var level := 1

var _rows: VBoxContainer
var _count: Control
var _warn: Label
var _name: LineEdit
var _go: CheckBox
var _note: LineEdit
var _code: LineEdit
var _said: Label
var _menu: PopupMenu
var _menu_for := -1
var _line: Control
var _details: PanelContainer
var _slots: Array[Button] = []
# a row being dragged, and the gap it would be dropped into; -1 for none
var _drag_row := -1
var _drop_at := -1


## Opens the planner on a level. Before a run the route comes from the save; over a run it is
## the run's own plan, and `over` is that run's rules.
func open(level: LevelDef, from: SaveData, party: Array[String], over: Combat = null) -> void:
	def = level
	save = from
	combat = over
	route = over.route if over and over.route else from.route_for(level)
	self.level = over.level if over else from.level
	theme = Kit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.06, 0.94)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var cols := Kit.hbox(0)
	cols.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cols)

	view = MapView.new()
	view.name = "Map"
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.party = party
	view.combat = over
	view.pack_clicked.connect(_on_pack)
	view.spot_dropped.connect(_on_spot)
	view.pack_hovered.connect(_on_pack_hover)
	cols.add_child(view)
	cols.add_child(_side())
	view.show_level(level, route)

	_details = PanelContainer.new()
	_details.name = "Details"
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.visible = false
	_details.add_child(Kit.vbox(3))
	add_child(_details)
	# drawn over everything: where a dragged row would land
	_line = Control.new()
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	_line.draw.connect(_draw_line)
	add_child(_line)
	_menu = PopupMenu.new()
	_menu.add_item("Insert a pull above", 0)
	_menu.add_item("Join to the pull above", 1)
	_menu.add_item("Delete this pull", 2)
	_menu.id_pressed.connect(_on_menu)
	add_child(_menu)
	if over:
		current = maxi(0, over.next_pull().get("index", 0))
	_refresh()


func _side() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Side"
	panel.custom_minimum_size.x = SIDE
	var col := Kit.vbox(8)
	panel.add_child(col)
	col.add_child(Kit.label("Route: " + def.name, 20, Kit.GOLD))

	var slots := Kit.hbox(6)
	slots.add_child(Kit.label("Kept as", 12, Kit.GREY))
	for i in SaveData.SLOTS:
		var b := Kit.button(str(i + 1), _use_slot.bind(i), 13)
		b.name = "Slot%d" % i
		b.custom_minimum_size = Vector2(34, 30)
		b.tooltip_text = "Three routes are kept for each dungeon. The one you used last is the one a run follows."
		_slots.append(b)
		slots.add_child(b)
	_name = LineEdit.new()
	_name.name = "RouteName"
	_name.placeholder_text = "A name for this route"
	_name.max_length = 40
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_changed.connect(func(text: String) -> void:
		route.name = text
		_keep())
	slots.add_child(_name)
	col.add_child(slots)

	_count = Control.new()
	_count.name = "Count"
	_count.custom_minimum_size.y = 34
	_count.draw.connect(_draw_count)
	col.add_child(_count)
	_warn = Kit.para("", 12, Kit.RED, SIDE - 40.0)
	_warn.name = "Warnings"
	col.add_child(_warn)

	var scroll := ScrollContainer.new()
	scroll.name = "Pulls"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows = Kit.vbox(3)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	col.add_child(scroll)

	var edit := Kit.hbox(8)
	var add := Kit.button("Add a pull", _add_pull, 13)
	add.name = "AddPull"
	edit.add_child(add)
	var reset := Kit.button("Reset to the safe way", _reset, 13)
	reset.name = "Reset"
	edit.add_child(reset)
	col.add_child(edit)

	_go = CheckBox.new()
	_go.name = "Go"
	_go.text = "Go at once: the tank does not wait for the party"
	_go.toggled.connect(func(on: bool) -> void:
		if current < route.pulls.size():
			route.pulls[current].go = on
			_keep()
			_refresh())
	col.add_child(_go)
	_note = LineEdit.new()
	_note.name = "Note"
	_note.placeholder_text = "A note for this pull"
	_note.max_length = Route.NOTE_LENGTH
	_note.text_changed.connect(func(text: String) -> void:
		if current < route.pulls.size():
			route.pulls[current].note = text
			_keep())
	col.add_child(_note)

	var share := Kit.hbox(6)
	_code = LineEdit.new()
	_code.name = "Code"
	_code.placeholder_text = "Paste a route's code here"
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	share.add_child(_code)
	var copy := Kit.button("Copy code", _copy_code, 12)
	copy.name = "CopyCode"
	share.add_child(copy)
	var load_code := Kit.button("Load", _load_code, 12)
	load_code.name = "LoadCode"
	share.add_child(load_code)
	col.add_child(share)
	_said = Kit.para("", 12, Kit.GREY, SIDE - 40.0)
	_said.name = "Said"
	col.add_child(_said)

	col.add_child(Kit.para(HINT, 11, Kit.GREY, SIDE - 40.0))
	var done := Kit.button("Done", func() -> void: closed.emit(), 16)
	done.name = "Done"
	col.add_child(done)
	return panel


# ---------- what the map and the list report

## Whether a pull's packs are all dead already, in the run this is open over.
func is_done(i: int) -> bool:
	var packs: Array = route.pulls[i].packs
	return combat != null and not packs.is_empty() and packs.all(func(pack: int) -> bool: return view.done(pack))


func _on_pack(pack: int, fresh: bool) -> void:
	if view.done(pack):
		_say("That pack is already at rest.")
		return
	if route.pulls.is_empty():
		current = route.add_pull()
	elif fresh or is_done(current):
		current = route.add_pull(current + 1)
	var was := route.pull_of(pack)
	route.toggle(pack, current)
	# a pull whose last pack was taken for another has nothing left to be
	if was >= 0 and was != current and route.pulls[was].packs.is_empty():
		route.remove_pull(was)
		if was < current:
			current -= 1
	_edited()


func _on_spot(place: int, at: Vector3, placed: bool) -> void:
	if current >= route.pulls.size():
		return
	if placed:
		route.set_spot(current, place, at)
	else:
		route.clear_spot(current, place)
	_edited()


func _add_pull() -> void:
	current = route.add_pull(current + 1 if not route.pulls.is_empty() else -1)
	_edited()


func select(i: int) -> void:
	current = clampi(i, 0, maxi(0, route.pulls.size() - 1))
	_refresh()


func _on_menu(id: int) -> void:
	var i := _menu_for
	if i < 0 or i >= route.pulls.size():
		return
	match id:
		0:
			current = route.add_pull(i)
		1:
			if i == 0 or is_done(i - 1):
				_say("There is no pull above to join.")
				return
			route.merge_up(i)
			current = i - 1
		2:
			route.remove_pull(i)
			current = clampi(current if current < i else current - 1, 0, maxi(0, route.pulls.size() - 1))
	_edited()


## Moves a pull to a gap in the list: gap 0 is above the first row.
func move_row(from: int, gap: int) -> void:
	var to := gap if gap <= from else gap - 1
	if to == from:
		return
	route.move_pull(from, to)
	current = to
	_edited()


func _use_slot(i: int) -> void:
	finish()
	save.use_slot(def, i)
	_adopt(save.route_for(def))
	changed.emit()


func _reset() -> void:
	save.keep_route(def, save.route_slot(def), null)
	_adopt(Route.default_for(def))
	changed.emit()
	_say("Back to the safe way: every pack by itself, in order.")


func _copy_code() -> void:
	_code.text = route.to_code()
	_code.select_all()
	DisplayServer.clipboard_set(_code.text)
	_say("Copied. Send the line to someone, or keep it somewhere safe.")


func _load_code() -> void:
	var read := Route.from_code(_code.text, def)
	if read == null:
		_say("That is not a route for %s." % def.name)
		return
	_adopt(read)
	_keep()
	changed.emit()
	_say("Loaded \"%s\"." % read.name if read.name != "" else "Loaded.")


# Takes on another route's pulls and name. The object stays the same, since a run may be
# following it.
func _adopt(other: Route) -> void:
	var fresh := other.copy()
	route.name = fresh.name
	route.pulls = fresh.pulls
	current = maxi(0, combat.next_pull().get("index", 0)) if combat else 0
	_refresh()


func _edited() -> void:
	_keep()
	changed.emit()
	_refresh()


func _keep() -> void:
	save.keep_route(def, save.route_slot(def), route)


## Tidies the route as the planner is closed: pulls left empty are dropped.
func finish() -> void:
	var before := route.pulls.size()
	route.prune()
	if route.pulls.size() != before:
		_keep()
		changed.emit()
		_refresh()


func _say(text: String) -> void:
	_said.text = text


# ---------- what a pack or a pull is made of

func _on_pack_hover(pack: int) -> void:
	if pack < 0:
		hide_details()
		return
	var pull := route.pull_of(pack)
	var title := "%s    count %d    %s" % [def.packs[pack].name, def.pack_count(pack), "pull %d" % (pull + 1) if pull >= 0 else "in no pull"]
	var beside := view.global_position + view.to_screen(def.packs[pack].center) + Vector2(MapView.PACK_REACH * view.zoom + 14.0, -24.0)
	show_details([pack], title, beside)


## Lists the enemies of those packs beside a point of the screen: how many of each kind, their
## health at this level, what they are worth, and what each of them does. `left_of` puts the
## list's right edge at the point instead of its left.
func show_details(packs: Array, title: String, at: Vector2, left_of := false, note := "") -> void:
	var box: VBoxContainer = _details.get_child(0)
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	box.add_child(Kit.label(title, 14, Kit.GOLD))
	if note != "":
		box.add_child(Kit.para("\"%s\"" % note, 12, Kit.BONE, DETAILS_WIDTH))
	var kinds := {}
	for pack: int in packs:
		for id: String in def.packs[pack].enemies:
			kinds[id] = kinds.get(id, 0) + 1
	var scale := pow(1.08, level - 1)
	for id: String in kinds:
		var e := Enemies.by_id(id)
		box.add_child(Kit.label("%d× %s    %d health    %s" % [kinds[id], e.name, roundi(e.hp * scale), "count %d" % e.count if e.count > 0 else "no count"], 13))
		for t: Array in e.traits:
			var from: int = t[2]
			var words := "%s%s: %s" % [t[0], " (from level %d)" % from if from > 1 else "", t[1]]
			box.add_child(Kit.para(words, 12, Kit.GREY if level >= from else Color(Kit.GREY, 0.45), DETAILS_WIDTH))
	_details.visible = true
	_details.reset_size()
	var room := size - _details.size - Vector2(6, 6)
	var corner := at - Vector2(_details.size.x, 0) - global_position if left_of else at - global_position
	_details.position = corner.clamp(Vector2(6, 6), room.max(Vector2(6, 6)))


func hide_details() -> void:
	_details.visible = false


# ---------- showing it

func _refresh() -> void:
	hide_details()
	current = clampi(current, 0, maxi(0, route.pulls.size() - 1))
	view.current = current
	view.queue_redraw()
	for i in _slots.size():
		_slots[i].add_theme_color_override("font_color", Kit.GOLD if i == save.route_slot(def) else Kit.BONE)
	if _name.text != route.name:
		_name.text = route.name
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for i in route.pulls.size():
		var row := Row.new()
		row.name = "Pull%d" % i
		row.map = self
		row.index = i
		_rows.add_child(row)
	var has := current < route.pulls.size()
	_go.disabled = not has
	_note.editable = has
	_go.set_pressed_no_signal(has and route.pulls[current].go)
	var note: String = route.pulls[current].note if has else ""
	if _note.text != note:
		_note.text = note
	_warn.text = warnings()
	_warn.visible = _warn.text != ""
	_count.queue_redraw()


## What the route leaves undone, in words; "" if nothing.
func warnings() -> String:
	var miss := route.missing(def)
	var lines: Array[String] = []
	if miss.count > 0:
		lines.append("This route is %d short of the count." % miss.count)
	if not miss.bosses.is_empty():
		lines.append("It never pulls %s." % " or ".join(miss.bosses))
	if not lines.is_empty():
		lines.append("The run can still start: the party takes what is left, nearest first.")
	return " ".join(lines)


func _draw_count() -> void:
	var goal := def.count_goal()
	var planned := route.count_through(def, route.pulls.size() - 1) if not route.pulls.is_empty() else 0
	var w := _count.size.x
	var short := planned < goal
	Kit.bar(_count, Rect2(1, 1, w - 2, 10), float(planned) / maxf(goal, 1), Kit.RED if short else Kit.GREEN)
	if combat:
		# what the run has earned already, over what is planned
		_count.draw_rect(Rect2(1, 1, (w - 2) * clampf(float(combat.count()) / maxf(goal, 1), 0.0, 1.0), 10), Kit.GOLD)
	var words := "Count planned: %d / %d (%d%%)" % [planned, goal, planned * 100 / maxi(goal, 1)]
	if combat:
		words += "    earned: %d" % combat.count()
	Kit.text(_count, Vector2(0, 28), words, 13, Kit.RED if short else Kit.BONE, w, HORIZONTAL_ALIGNMENT_LEFT)


func _draw_line() -> void:
	if _drag_row < 0 or _drop_at < 0 or _rows.get_child_count() == 0:
		return
	var last: Control = _rows.get_child(_rows.get_child_count() - 1)
	var under: Control = _rows.get_child(mini(_drop_at, _rows.get_child_count() - 1))
	var y := under.global_position.y - 2.0 if _drop_at < _rows.get_child_count() else last.global_position.y + last.size.y + 1.0
	var x := _rows.global_position.x
	_line.draw_line(Vector2(x, y) - global_position, Vector2(x + _rows.size.x, y) - global_position, Kit.GOLD, 2.0)


# The gap in the list nearest a height on the screen: 0 above the first row.
func _gap_at(global_y: float) -> int:
	for i in _rows.get_child_count():
		var row: Control = _rows.get_child(i)
		if global_y < row.global_position.y + row.size.y / 2.0:
			return i
	return _rows.get_child_count()


## One pull in the list: its number in its colour, what it is made of, what it is worth and
## the count the route has reached by the end of it.
class Row:
	extends Control

	var map: RouteMap
	var index := 0
	var _pressed := false
	var _press_y := 0.0

	func _ready() -> void:
		custom_minimum_size.y = RouteMap.ROW
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(_show_details)
		mouse_exited.connect(map.hide_details)

	# What the pull is made of, to the left of the list.
	func _show_details() -> void:
		var p: Dictionary = map.route.pulls[index] if index < map.route.pulls.size() else {}
		if p.get("packs", []).is_empty() or map._drag_row >= 0:
			return
		var title := "Pull %d    count %d" % [index + 1, map.route.count_of(map.def, index)]
		map.show_details(p.packs, title, global_position + Vector2(-12.0, 0.0), true, p.note)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		var mm := event as InputEventMouseMotion
		if mb and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressed = true
				_press_y = mb.global_position.y
			else:
				var dragged := map._drag_row == index
				var gap := map._drop_at
				_pressed = false
				map._drag_row = -1
				map._drop_at = -1
				map._line.queue_redraw()
				if dragged and gap >= 0:
					map.move_row(index, gap)
				else:
					map.select(index)
			accept_event()
		elif mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if map.is_done(index):
				return
			map._menu_for = index
			map._menu.position = Vector2i(mb.global_position)
			map._menu.popup()
			accept_event()
		elif mm and _pressed and not map.is_done(index):
			if absf(mm.global_position.y - _press_y) > 6.0:
				map._drag_row = index
			if map._drag_row == index:
				map._drop_at = map._gap_at(mm.global_position.y)
				map._line.queue_redraw()

	func _draw() -> void:
		var route := map.route
		if index >= route.pulls.size():
			return
		var p: Dictionary = route.pulls[index]
		var color := MapView.pull_color(index)
		var done := map.is_done(index)
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(color, 0.1 if done else 0.22 if index == map.current else 0.12))
		draw_rect(Rect2(0, 0, 4, size.y), Color(color, 0.4 if done else 1.0))
		if index == map.current:
			draw_rect(r, Kit.GOLD, false, 1.5)
		var fade := 0.45 if done else 1.0
		var mid := size.y / 2.0 + 5.0
		Kit.text(self, Vector2(12, mid), str(index + 1), 15, Color(color, fade), 30.0, HORIZONTAL_ALIGNMENT_LEFT)
		# what it is made of: one disc a kind, with how many
		var kinds := {}
		for pack: int in p.packs:
			for id: String in map.def.packs[pack].enemies:
				kinds[id] = kinds.get(id, 0) + 1
		var x := 44.0
		for id: String in kinds:
			var mark := MapView.enemy_mark(id)
			if kinds[id] > 1:
				Kit.text(self, Vector2(x, mid - 1.0), "%d×" % kinds[id], 11, Color(Kit.BONE, fade), 30.0, HORIZONTAL_ALIGNMENT_LEFT)
				x += 18.0
			draw_circle(Vector2(x + 8.0, size.y / 2.0), 8.0, Color(mark[0] as Color, fade))
			Kit.text(self, Vector2(x + 8.0, mid - 1.0), mark[1], 10, Color(1, 1, 1, fade), 20.0)
			x += 22.0
		if p.packs.is_empty():
			Kit.text(self, Vector2(44, mid - 1.0), "empty: click a pack on the map", 11, Kit.GREY, 240.0, HORIZONTAL_ALIGNMENT_LEFT)
		if p.go:
			Kit.text(self, Vector2(x + 4.0, mid - 1.0), "at once", 10, Kit.GOLD, 60.0, HORIZONTAL_ALIGNMENT_LEFT)
			x += 44.0
		if not p.spots.is_empty():
			Kit.text(self, Vector2(x + 4.0, mid - 1.0), "spots", 10, Kit.GREY, 60.0, HORIZONTAL_ALIGNMENT_LEFT)
		# what it is worth, and where the count stands after it
		var goal := map.def.count_goal()
		var through := route.count_through(map.def, index)
		var words := "done" if done else "+%d    %d%%" % [route.count_of(map.def, index), through * 100 / maxi(goal, 1)]
		var reaches := index == route.completes_at(map.def)
		Kit.text(self, Vector2(size.x - 108.0, mid - 1.0), words, 12, Kit.GREEN if reaches else Color(Kit.BONE, fade), 100.0, HORIZONTAL_ALIGNMENT_RIGHT)
		if reaches:
			draw_rect(Rect2(0, size.y - 2.0, size.x, 2.0), Kit.GREEN)
