class_name Kit
extends RefCounted

# The interface's colours, its theme and a few helpers for building screens and drawing frames.
# Plain grey-box styling for now: dark see-through panels, gold edges, bone lettering.

const BONE := Color("d9d3c2")
const DARK := Color(0.05, 0.06, 0.08, 0.86)
const SOLID := Color(0.06, 0.07, 0.1, 0.97)
const EDGE := Color(0, 0, 0, 0.9)
const GOLD := Color("f0b54a")
const RED := Color("ef5d4a")
const GREY := Color("9fb0b1")
const GREEN := Color("8fe6b4")
const CURSE := Color("c9a2ff")
const HP_HERO := Color("5fbf6e")
const HP_ENEMY := Color("c9503f")
const SHIELD := Color("8fd0e6")

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 14
	t.set_color("font_color", "Label", BONE)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := _box(SOLID if state != "hover" else Color(0.13, 0.14, 0.18, 0.97),
			GOLD if state in ["hover", "pressed", "focus"] else Color(BONE, 0.45), 2 if state == "pressed" else 1)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		for kind: String in ["Button", "OptionButton", "CheckBox"]:
			if kind == "CheckBox" and state != "focus":
				continue
			t.set_stylebox(state, kind, box)
	for kind: String in ["Button", "OptionButton", "CheckBox"]:
		t.set_color("font_color", kind, BONE)
		t.set_color("font_hover_color", kind, GOLD)
		t.set_color("font_pressed_color", kind, GOLD)
		t.set_color("font_focus_color", kind, BONE)
		t.set_color("font_disabled_color", kind, Color(BONE, 0.35))
	t.set_stylebox("panel", "PanelContainer", _box(SOLID, Color(GOLD, 0.7), 1, 16))
	t.set_stylebox("panel", "PopupMenu", _box(SOLID, Color(BONE, 0.45), 1, 6))
	t.set_color("font_color", "PopupMenu", BONE)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	_theme = t
	return t


static func _box(fill: Color, edge: Color, width: int, margin := 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = edge
	b.set_border_width_all(width)
	b.set_content_margin_all(margin)
	return b


# ---------- building screens

static func label(text: String, px := 14, color := BONE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	return l


## A label that wraps onto as many lines as it needs within its width.
static func para(text: String, px := 13, color := BONE, width := 0.0) -> Label:
	var l := label(text, px, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0.0:
		l.custom_minimum_size.x = width
	return l


static func button(text: String, on_pressed: Callable, px := 14) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", px)
	b.pressed.connect(on_pressed)
	return b


static func vbox(gap := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	return v


static func hbox(gap := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	return h


## A screen: a dim backdrop over everything, with one panel in the middle to fill.
static func screen(dim := 0.7) -> Control:
	var root := Control.new()
	root.theme = theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.06, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	centre.add_child(panel)
	return root


static func panel_of(screen_root: Control) -> PanelContainer:
	return screen_root.get_node("Centre/Panel")


static func clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


# ---------- drawing frames

## Text centred on a point, with a dark outline so it reads over anything.
static func text(on: CanvasItem, at: Vector2, s: String, px: int, color: Color, width := 240.0, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var font := ThemeDB.fallback_font
	var from := Vector2(at.x - width / 2, at.y) if align == HORIZONTAL_ALIGNMENT_CENTER else at
	on.draw_string_outline(font, from, s, align, width, px, 4, Color(0, 0, 0, color.a))
	on.draw_string(font, from, s, align, width, px, color)


## Text centred in a width and wrapped onto two lines, for a name on a button.
static func wrapped(on: CanvasItem, from: Vector2, s: String, px: int, color: Color, width: float) -> void:
	var font := ThemeDB.fallback_font
	on.draw_multiline_string_outline(font, from, s, HORIZONTAL_ALIGNMENT_CENTER, width, px, 2, 4, Color(0, 0, 0, color.a))
	on.draw_multiline_string(font, from, s, HORIZONTAL_ALIGNMENT_CENTER, width, px, 2, color)


static func bar(on: CanvasItem, r: Rect2, part: float, fill: Color, marked := false) -> void:
	on.draw_rect(r.grow(1), EDGE)
	on.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(part, 0.0, 1.0), r.size.y)), fill)
	if marked:
		on.draw_rect(r.grow(2), GOLD, false, 2.0)


static func frame(on: CanvasItem, r: Rect2, edge: Color, width := 1.0) -> void:
	on.draw_rect(r, DARK)
	on.draw_rect(r, edge, false, width)
