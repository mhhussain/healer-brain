class_name AbilityButton
extends Control

# One button of the action bar: its key, its cost, its cooldown draining down it, and dimmed
# when it cannot be used. Click it to use it; hold the mouse over it to read what it does.

signal used(idx: int)
signal hovered(idx: int, on: bool)

var idx := 0
var run: Run


func _ready() -> void:
	custom_minimum_size = Vector2(86, 62)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: hovered.emit(idx, true))
	mouse_exited.connect(func() -> void: hovered.emit(idx, false))


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		used.emit(idx)
		accept_event()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if run == null or run.combat == null or run.combat.player == null:
		return
	var p := run.combat.player
	if idx >= p.hero.abilities.size():
		return
	var ab := p.hero.abilities[idx]
	var st := run.combat.ability_state(p, idx)
	var r := Rect2(Vector2.ZERO, size)
	var casting := p.cast != null and p.cast.ab_idx == idx
	draw_rect(r, Kit.DARK)
	draw_rect(r, Kit.GOLD if casting else Kit.BONE if st.usable else Color(Kit.BONE, 0.35), false, 2.0)
	Kit.wrapped(self, Vector2(3, 36), ab.name, 11, Kit.BONE if st.usable else Color(Kit.BONE, 0.45), size.x - 6)
	Kit.text(self, Vector2(6, 15), Bindings.label(Run.keys, p.hero.id, ab.id), 12, Kit.GOLD, size.x - 30, HORIZONTAL_ALIGNMENT_LEFT)
	if ab.cost > 0.0:
		Kit.text(self, Vector2(size.x - 34, 15), str(int(ab.cost)), 11, p.hero.res_color, 28.0, HORIZONTAL_ALIGNMENT_RIGHT)
	if st.cd > 0.0:
		# the cooldown drains down the button
		var left: float = clampf(st.cd / st.cd_max, 0.0, 1.0)
		draw_rect(Rect2(0, size.y * (1.0 - left), size.x, size.y * left), Color(0, 0, 0, 0.6))
		if st.cd_max > p.hero.gcd + 0.01:
			Kit.text(self, Vector2(size.x / 2, size.y - 6), "%d" % ceili(st.cd) if st.cd >= 3.0 else "%.1f" % st.cd, 13, Color.WHITE)


## What the tooltip says: the description, then cost, cast time, cooldown and reach.
static func details(hero: HeroDef, ab: AbilityDef) -> String:
	var facts: Array[String] = []
	if ab.cost > 0.0:
		facts.append("%d %s" % [ab.cost, hero.res_name.to_lower()])
	facts.append("%s s cast" % str(ab.cast).trim_suffix(".0") if ab.cast > 0.0 else "instant")
	if ab.cd > 0.0:
		facts.append("%s s cooldown" % str(ab.cd).trim_suffix(".0"))
	if ab.target != "self":
		facts.append("%d m" % ab.reach if ab.reach > 5.0 else "melee")
	if ab.off_gcd:
		facts.append("does not wait for other abilities")
	return ab.desc + "\n" + ", ".join(facts)
