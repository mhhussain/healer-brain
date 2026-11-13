class_name CombatHud
extends Control

# A plain, drawn-in-code interface for the grey-box stage: health bars over heads, damage numbers,
# your frame, your target's frame and the action buttons. The real interface comes in a later
# milestone and replaces this.

@export var run: Run

const TEXT_LIFE := 0.9
const BONE := Color("d9d3c2")
const DARK := Color(0.05, 0.06, 0.08, 0.85)
const EDGE := Color(0, 0, 0, 0.9)
const GOLD := Color("f0b54a")
const RED := Color("ef5d4a")
const HP_HERO := Color("5fbf6e")
const HP_ENEMY := Color("c9503f")

var _texts: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A number that rises from a unit and fades.
func float_text(u: Unit, text: String, color: Color) -> void:
	var at := u.global_position + Vector3(randf_range(-0.35, 0.35), u.height + 1.1, 0)
	_texts.append({"at": at, "text": text, "color": color, "t": 0.0})


func _process(delta: float) -> void:
	for t in _texts:
		t.t += delta
	_texts = _texts.filter(func(t: Dictionary) -> bool: return t.t < TEXT_LIFE)
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or run == null or run.player == null:
		return
	var combat := run.combat
	var p := combat.player

	for u: Unit in run.all_units():
		if not u.c.alive:
			continue
		var head := u.get_global_transform_interpolated().origin + Vector3(0, u.height + 0.45 + u.lift, 0)
		var s := cam.unproject_position(head)
		var enemy := u.c.team == "enemy"
		var w := 84.0 if enemy else 64.0
		_bar(Rect2(s.x - w / 2, s.y - 5, w, 9), u.c.hp / u.c.max_hp, HP_ENEMY if enemy else HP_HERO, p.target_id == u.c.id)
		if enemy:
			_text(Vector2(s.x, s.y - 11), u.c.name, 13, BONE)

	for t in _texts:
		var k: float = t.t / TEXT_LIFE
		var s := cam.unproject_position(t.at) - Vector2(0, 50.0 * k)
		_text(s, t.text, 19, Color(t.color, 1.0 - k * k))

	var mid := size.x / 2
	var base := size.y - 24

	# your frame, left of centre
	var me := Rect2(mid - 330, base - 150, 240, 62)
	_frame(me, p.name)
	_bar(Rect2(me.position + Vector2(8, 26), Vector2(224, 14)), p.hp / p.max_hp, HP_HERO)
	_text(me.position + Vector2(120, 38), "%d / %d" % [p.hp, p.max_hp], 11, Color.WHITE)
	_bar(Rect2(me.position + Vector2(8, 44), Vector2(224, 10)), p.res / p.res_max, Color("8fb8c9"))
	_text(me.position + Vector2(120, 53), "%d %s" % [p.res, p.hero.res_name.to_lower()], 10, Color.WHITE)

	# your target's frame, right of centre
	var t := combat.unit(p.target_id)
	if t:
		var them := Rect2(mid + 90, base - 150, 240, 62)
		_frame(them, t.name if t.alive else t.name + " (dead)")
		_bar(Rect2(them.position + Vector2(8, 26), Vector2(224, 14)), t.hp / t.max_hp, HP_ENEMY)
		_text(them.position + Vector2(120, 38), "%d / %d" % [t.hp, t.max_hp], 11, Color.WHITE)
		var where := "%.0f m" % Combat.dist(p, t)
		if t.alive and not combat.sees(p, t):
			where += ", out of sight"
		_text(them.position + Vector2(120, 55), where, 11, BONE)

	# the action buttons
	var n := p.hero.abilities.size()
	var side := 68.0
	var gap := 8.0
	var x := mid - (n * side + (n - 1) * gap) / 2
	for i in n:
		var ab := p.hero.abilities[i]
		var st := combat.ability_state(p, i)
		var r := Rect2(x + i * (side + gap), base - side, side, side)
		draw_rect(r, DARK)
		draw_rect(r, BONE if st.usable else Color(BONE, 0.35), false, 2.0)
		_wrapped(r.position + Vector2(3, 36), ab.name, 11, BONE if st.usable else Color(BONE, 0.45), side - 6)
		_text(r.position + Vector2(11, 15), Controls.label("ability_%d" % (i + 1)), 13, GOLD)
		if ab.cost > 0.0:
			_text(r.position + Vector2(side - 14, 15), str(int(ab.cost)), 11, Color("8fb8c9"))
		if st.cd > 0.0:
			# the cooldown drains down the button
			var left: float = clampf(st.cd / st.cd_max, 0.0, 1.0)
			draw_rect(Rect2(r.position + Vector2(0, side * (1.0 - left)), Vector2(side, side * left)), Color(0, 0, 0, 0.6))
			if st.cd_max > p.hero.gcd + 0.01:
				_text(r.position + Vector2(side / 2, side - 8), "%.1f" % st.cd, 13, Color.WHITE)

	if combat.error != "":
		_text(Vector2(mid, base - 170), combat.error, 16, Color(RED, clampf(3.0 - combat.error_t * 2.0, 0.0, 1.0)))


func _frame(r: Rect2, title: String) -> void:
	draw_rect(r, DARK)
	draw_rect(r, Color(BONE, 0.5), false, 1.0)
	_text(r.position + Vector2(r.size.x / 2, 18), title, 13, BONE)


func _bar(r: Rect2, part: float, fill: Color, marked := false) -> void:
	draw_rect(r.grow(1), EDGE)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(part, 0.0, 1.0), r.size.y)), fill)
	if marked:
		draw_rect(r.grow(2), GOLD, false, 2.0)


# Text centred in a width and wrapped onto two lines, for a name on a button.
func _wrapped(from: Vector2, text: String, px: int, color: Color, width: float) -> void:
	var font := ThemeDB.fallback_font
	draw_multiline_string_outline(font, from, text, HORIZONTAL_ALIGNMENT_CENTER, width, px, 2, 4, Color(0, 0, 0, color.a))
	draw_multiline_string(font, from, text, HORIZONTAL_ALIGNMENT_CENTER, width, px, 2, color)


# Text centred on a point, with a dark outline so it reads over anything.
func _text(at: Vector2, text: String, px: int, color: Color, width := 240.0) -> void:
	var font := ThemeDB.fallback_font
	var from := Vector2(at.x - width / 2, at.y)
	draw_string_outline(font, from, text, HORIZONTAL_ALIGNMENT_CENTER, width, px, 4, Color(0, 0, 0, color.a))
	draw_string(font, from, text, HORIZONTAL_ALIGNMENT_CENTER, width, px, color)
