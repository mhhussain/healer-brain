class_name WorldOverlay
extends Control

# What is drawn over the figures in the world: health and cast bars over heads, the party's
# debuffs on each enemy, and the numbers and words that rise from a hit.

@export var run: Run

const TEXT_LIFE := 0.9
const CHIP := Vector2(26, 13)

var _texts: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A number that rises from a unit and fades.
func float_text(u: Unit, text: String, color: Color) -> void:
	float_at(u.global_position + Vector3(randf_range(-0.35, 0.35), u.height + 1.1, 0), text, color)


## Words that rise from a spot and fade.
func float_at(at: Vector3, text: String, color: Color) -> void:
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
	var c := run.combat
	var p := c.player
	var tank := c.tank()
	var screen := Rect2(Vector2.ZERO, size).grow(80)
	for u: Unit in run.all_units():
		if not u.c.alive:
			continue
		var head := u.get_global_transform_interpolated().origin + Vector3(0, u.height + 0.45 + u.lift, 0)
		var s := cam.unproject_position(head)
		if not screen.has_point(s):
			continue
		if u.c.team == "hero":
			Kit.bar(self, Rect2(s.x - 32, s.y - 5, 64, 8), u.c.hp / u.c.max_hp, Kit.HP_HERO)
			continue
		var w := 84.0
		var plate := Rect2(s.x - w / 2, s.y - 5, w, 9)
		Kit.bar(self, plate, u.c.hp / u.c.max_hp, Kit.HP_ENEMY, p.target_id == u.c.id)
		# a red edge: it is after someone who is not the tank
		var prey := c.unit(u.c.target_id)
		if u.c.engaged and prey and prey.hero and prey != tank:
			draw_rect(plate.grow(2), Kit.RED, false, 1.5)
		Kit.text(self, Vector2(s.x, s.y - 11), u.c.name, 13, Kit.BONE)
		var y := s.y + 8
		var cast := u.c.cast
		if cast:
			# gold can be silenced, grey cannot; KICK means this one is yours to stop
			var mine := cast.interruptible and cast.assignee == p.id
			Kit.bar(self, Rect2(s.x - w / 2, y, w, 8), cast.t / cast.total, Kit.GOLD if cast.interruptible else Kit.GREY, mine)
			Kit.text(self, Vector2(s.x, y + 22), ("KICK  " if mine else "") + cast.name, 12, Kit.GOLD if cast.interruptible else Kit.GREY)
			y += 28
		_chips(u.c, Vector2(s.x, y + 2), p.id)

	for t in _texts:
		var k: float = t.t / TEXT_LIFE
		var s := cam.unproject_position(t.at) - Vector2(0, 50.0 * k)
		Kit.text(self, s, t.text, 19, Color(t.color, 1.0 - k * k))


# One chip for each debuff the party has put on an enemy: its caster's colour, draining as it
# runs out, with the seconds left. Yours come first, edged in gold.
func _chips(e: Combatant, at: Vector2, mine_id: int) -> void:
	var list := e.auras.filter(func(a: Aura) -> bool: return a.debuff and a.dur < 600.0)
	if list.is_empty():
		return
	list.sort_custom(func(a: Aura, b: Aura) -> bool: return a.src_id == mine_id and b.src_id != mine_id)
	var x := at.x - (list.size() * (CHIP.x + 3) - 3) / 2
	for a: Aura in list:
		var src := run.combat.unit(a.src_id)
		var color: Color = src.hero.color if src and src.hero else Kit.GREY
		var r := Rect2(Vector2(x, at.y), CHIP)
		draw_rect(r, Kit.EDGE)
		draw_rect(Rect2(r.position, Vector2(CHIP.x * clampf(a.t / a.dur, 0.0, 1.0), CHIP.y)), Color(color, 0.85))
		if a.src_id == mine_id:
			draw_rect(r.grow(1), Kit.GOLD, false, 1.5)
		Kit.text(self, Vector2(x + CHIP.x / 2, at.y + 11), "%.0f" % a.t if a.t >= 3.0 else "%.1f" % a.t, 10, Color.WHITE, CHIP.x + 8)
		x += CHIP.x + 3
