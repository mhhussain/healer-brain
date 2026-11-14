class_name UnitFrame
extends Control

# One frame at the bottom of the screen: yours, your target's, or a party member's.
# A party frame can be clicked: that is how a healer casts.

signal clicked(hero_id: int, event: InputEventMouseButton)

## "player", "target" or "party".
var kind := "party"
## Party frames: which hero, by place in the party.
var slot := 0
var run: Run


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if kind == "party" else Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(190, 52) if kind == "party" else Vector2(260, 70)
	if kind == "party":
		mouse_entered.connect(func() -> void: run.hover_frame_id = who().id)
		mouse_exited.connect(func() -> void:
			if run.hover_frame_id == who().id:
				run.hover_frame_id = 0)


## The combatant this frame shows, or null.
func who() -> Combatant:
	var c := run.combat
	match kind:
		"player": return c.player
		"target": return c.unit(c.player.target_id)
	return c.heroes[slot]


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and kind == "party":
		clicked.emit(who().id, mb)
		accept_event()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if run == null or run.combat == null or run.combat.player == null:
		return
	var u := who()
	if u == null:
		return
	match kind:
		"player": _draw_player(u)
		"target": _draw_target(u)
		_: _draw_party(u)


func _draw_player(p: Combatant) -> void:
	var r := Rect2(Vector2.ZERO, size)
	Kit.frame(self, r, Color(p.hero.color, 0.9))
	Kit.text(self, Vector2(size.x / 2, 18), "%s, %s" % [p.name, p.hero.title], 13, p.hero.color, size.x - 8)
	_health(Rect2(8, 26, size.x - 16, 16), p)
	Kit.text(self, Vector2(size.x / 2, 39), "%d / %d" % [p.hp, p.max_hp], 11, Color.WHITE)
	Kit.bar(self, Rect2(8, 48, size.x - 16, 12), p.res / p.res_max, p.hero.res_color)
	Kit.text(self, Vector2(size.x / 2, 58), "%d %s" % [p.res, p.hero.res_name.to_lower()], 10, Color.WHITE)
	if p.hero.id == "duelist":
		for i in 5:
			draw_circle(Vector2(size.x / 2 - 32 + i * 16, -10), 5.0, Kit.GOLD if i < p.combo else Color(Kit.BONE, 0.25))
	_auras(Vector2(size.x / 2, -24 if p.hero.id == "duelist" else -8), p, 0)


func _draw_target(t: Combatant) -> void:
	var c := run.combat
	var p := c.player
	var r := Rect2(Vector2.ZERO, size)
	var hostile := t.team == "enemy"
	Kit.frame(self, r, Color(Kit.HP_ENEMY if hostile else t.hero.color, 0.9))
	Kit.text(self, Vector2(8, 18), t.name if t.alive else t.name + " (dead)", 13, Kit.BONE, size.x * 0.56, HORIZONTAL_ALIGNMENT_LEFT)
	# who it is after: red when that is not the tank
	if hostile and t.alive and t.engaged:
		var prey := c.unit(t.target_id)
		if prey and prey.hero:
			var on_tank := prey == c.tank()
			Kit.text(self, Vector2(size.x * 0.56, 18), "after " + ("you" if prey == p else prey.name.split(" ")[0]), 11,
				Kit.GREY if on_tank else Kit.RED, size.x * 0.44 - 8, HORIZONTAL_ALIGNMENT_RIGHT)
	Kit.bar(self, Rect2(8, 26, size.x - 16, 16), t.hp / t.max_hp, Kit.HP_ENEMY if hostile else Kit.HP_HERO)
	Kit.text(self, Vector2(size.x / 2, 39), "%d / %d" % [t.hp, t.max_hp], 11, Color.WHITE)
	if t.cast:
		Kit.bar(self, Rect2(8, 48, size.x - 16, 12), t.cast.t / t.cast.total, Kit.GOLD if t.cast.interruptible else Kit.GREY)
		Kit.text(self, Vector2(size.x / 2, 58), t.cast.name, 10, Color.WHITE)
	else:
		var where := "%.0f m" % Combat.dist(p, t)
		if t.alive and not c.sees(p, t):
			where += ", out of sight"
		Kit.text(self, Vector2(size.x / 2, 60), where, 11, Kit.GREY)
	_auras(Vector2(size.x / 2, -8), t, p.id)


func _draw_party(h: Combatant) -> void:
	var c := run.combat
	var r := Rect2(Vector2.ZERO, size)
	var curse: Aura = null
	for a in h.auras:
		if a.dispellable:
			curse = a
	var hovered := c.hover_ally_id == h.id
	# a curse that can be lifted lights the whole frame
	Kit.frame(self, r, Kit.GOLD if hovered else Kit.CURSE if curse else Color(h.hero.color, 0.85), 2.0 if hovered or curse else 1.0)
	Kit.text(self, Vector2(8, 17), h.name.split(" ")[-1] if h.alive else "dead", 12, h.hero.color if h.alive else Kit.RED, 90.0, HORIZONTAL_ALIGNMENT_LEFT)
	_health(Rect2(8, 23, size.x - 16, 13), h)
	Kit.bar(self, Rect2(8, 41, size.x - 16, 4), h.res / h.res_max, h.hero.res_color)
	# what is on them, as words: a curse first, then shields, heals over time and defensives
	var notes: Array[String] = []
	var color := Kit.BONE
	if curse:
		notes.append("%s %.0f" % [curse.name, curse.t])
		color = Kit.CURSE
	else:
		for a in h.auras:
			if a.absorb > 0.0:
				notes.append("shield %d" % a.absorb)
			elif a.tick_heal > 0.0:
				notes.append("mending")
			elif (a.taken < 1.0 or a.taken_phys < 1.0) and a.id != "sandbox":
				notes.append("guarded")
	if not notes.is_empty():
		Kit.text(self, Vector2(size.x - 8 - 110, 17), ", ".join(notes.slice(0, 2)), 10, color, 110.0, HORIZONTAL_ALIGNMENT_RIGHT)


# A health bar with any shield shown as a paler stretch beyond the health.
func _health(r: Rect2, u: Combatant) -> void:
	Kit.bar(self, r, u.hp / u.max_hp, Kit.HP_HERO)
	var shield := 0.0
	for a in u.auras:
		shield += a.absorb
	if shield > 0.0:
		var from := r.size.x * clampf(u.hp / u.max_hp, 0.0, 1.0)
		var width := minf(r.size.x * shield / u.max_hp, r.size.x - from)
		draw_rect(Rect2(r.position + Vector2(from, 0), Vector2(maxf(width, 3.0), r.size.y)), Color(Kit.SHIELD, 0.8))


# The auras on a unit, stacked upwards from a point: name and seconds left. Harmful ones are red;
# on an enemy, yours come first and are gold.
func _auras(at: Vector2, u: Combatant, mine_id: int) -> void:
	var list := u.auras.duplicate()
	list.sort_custom(func(a: Aura, b: Aura) -> bool: return a.src_id == mine_id and b.src_id != mine_id)
	var row := 0
	for a: Aura in list:
		if a.id == "sandbox":
			continue
		var color := Kit.BONE
		if a.debuff:
			color = Kit.GOLD if a.src_id == mine_id else Kit.RED if u.team == "hero" else Kit.GREY
		var left := "" if a.t > 600.0 else "  %.0f" % a.t if a.t >= 3.0 else "  %.1f" % a.t
		var extra := "  (%d)" % a.absorb if a.absorb > 0.0 else ""
		Kit.text(self, at - Vector2(0, row * 15.0), a.name + extra + left, 12, color)
		row += 1
