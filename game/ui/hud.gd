class_name Hud
extends Control

# The interface during a run. From the bottom up: the action bar; the party in one row; then
# your frame on the left and your target's on the right, with your cast bar between them.
# Across the top is the run: the clock, the rooms and lamps cleared, the deaths.

signal ability_clicked(idx: int)
signal frame_clicked(hero_id: int, event: InputEventMouseButton)

@export var run: Run

var _tip_for := -1
var _alerts: Array[Dictionary] = []

const ALERT_LIFE := 3.5

var _tip: PanelContainer
var _tip_title: Label
var _tip_body: Label
var _bottom: VBoxContainer


func _ready() -> void:
	theme = Kit.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom = Kit.vbox(8)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom.offset_bottom = -14
	add_child(_bottom)

	# you on the left, your target on the right, your cast bar between
	var units := Kit.hbox(0)
	units.mouse_filter = Control.MOUSE_FILTER_IGNORE
	units.add_child(_frame("player", 0))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	units.add_child(gap)
	units.add_child(_frame("target", 0))
	_bottom.add_child(units)

	var party := Kit.hbox(8)
	party.name = "Party"
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 4:
		party.add_child(_frame("party", i))
	_bottom.add_child(party)

	var actions := Kit.hbox(8)
	actions.name = "Actions"
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 6:
		var b := AbilityButton.new()
		b.idx = i
		b.run = run
		b.used.connect(func(idx: int) -> void: ability_clicked.emit(idx))
		b.hovered.connect(_on_hover)
		actions.add_child(b)
	_bottom.add_child(actions)

	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	var words := Kit.vbox(4)
	_tip_title = Kit.label("", 15, Kit.GOLD)
	_tip_body = Kit.para("", 13, Kit.BONE, 330.0)
	words.add_child(_tip_title)
	words.add_child(_tip_body)
	_tip.add_child(words)
	add_child(_tip)


func _frame(kind: String, slot: int) -> UnitFrame:
	var f := UnitFrame.new()
	f.kind = kind
	f.slot = slot
	f.run = run
	f.name = kind.capitalize() + (str(slot) if kind == "party" else "")
	f.clicked.connect(func(id: int, event: InputEventMouseButton) -> void: frame_clicked.emit(id, event))
	return f


## The frame of the party member in that place, for tests and for pointing at.
func party_frame(slot: int) -> UnitFrame:
	return _bottom.get_node("Party").get_child(slot)


func action_button(idx: int) -> AbilityButton:
	return _bottom.get_node("Actions").get_child(idx)


func _on_hover(idx: int, on: bool) -> void:
	if on:
		_tip_for = idx
	elif _tip_for == idx:
		_tip_for = -1


## A line across the top of the screen for a few seconds.
func alert(text: String) -> void:
	_alerts.append({"text": text, "t": 0.0})


func _process(delta: float) -> void:
	for a in _alerts:
		a.t += delta
	_alerts = _alerts.filter(func(a: Dictionary) -> bool: return a.t < ALERT_LIFE)
	var p := run.combat.player if run and run.combat else null
	_tip.visible = p != null and _tip_for >= 0 and _tip_for < p.hero.abilities.size()
	if _tip.visible:
		var ab := p.hero.abilities[_tip_for]
		_tip_title.text = ab.name
		_tip_body.text = AbilityButton.details(p.hero, ab)
		_tip.reset_size()
		_tip.position = Vector2(size.x / 2 - _tip.size.x / 2, _bottom.position.y - _tip.size.y - 26)
	queue_redraw()


func _draw() -> void:
	if run == null or run.combat == null or run.combat.player == null:
		return
	var c := run.combat
	var p := c.player
	var mid := size.x / 2

	# the run, across the top
	var t := c.total_time()
	var over := t > Combat.TIME_LIMIT
	Kit.bar(self, Rect2(mid - 170, 16, 340, 8), t / Combat.TIME_LIMIT, Kit.RED if over else Kit.GOLD)
	Kit.text(self, Vector2(mid, 44), "Level %d    %s / %s" % [c.level, Kit.clock(t), Kit.clock(Combat.TIME_LIMIT)], 16, Kit.RED if over else Kit.BONE, 400.0)
	Kit.text(self, Vector2(mid, 62), progress(c), 12, Kit.GREY, 400.0)

	for i in _alerts.size():
		var a := _alerts[i]
		Kit.text(self, Vector2(mid, 120.0 + i * 30.0), a.text, 22, Color(Kit.GOLD, clampf((ALERT_LIFE - a.t) * 2.0, 0.0, 1.0)), 900.0)

	# between your frame and your target's: your cast, and why a press did nothing
	var top := _bottom.position.y
	if p.cast:
		Kit.bar(self, Rect2(mid - 110, top + 34, 220, 14), p.cast.t / p.cast.total, Kit.GOLD)
		Kit.text(self, Vector2(mid, top + 28), p.cast.name, 13, Kit.BONE)
	if c.error != "":
		Kit.text(self, Vector2(mid, top + 66), c.error, 14, Color(Kit.RED, clampf(3.0 - c.error_t * 2.0, 0.0, 1.0)), 260.0)


## "Rooms 2/9    Lamps 0/3    Deaths 1 (+5 s)"
static func progress(c: Combat) -> String:
	var rooms := c.packs.filter(func(p: Pack) -> bool: return p.cleared).size()
	var bosses := c.packs.filter(func(p: Pack) -> bool: return p.boss)
	var line := "Rooms %d/%d" % [rooms, c.packs.size()]
	if not bosses.is_empty():
		line += "    Lamps %d/%d" % [bosses.filter(func(p: Pack) -> bool: return p.cleared).size(), bosses.size()]
	if c.deaths > 0:
		line += "    Deaths %d (+%d s)" % [c.deaths, c.deaths * Combat.DEATH_PENALTY]
	return line
