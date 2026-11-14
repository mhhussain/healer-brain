class_name CombatHud
extends Control

# A plain, drawn-in-code interface for the grey-box stage: health and cast bars over heads,
# damage numbers, your frame, your target's frame, your cast bar and the action buttons.
# The real interface comes in a later milestone and replaces this.

@export var run: Run

const TEXT_LIFE := 0.9
const ALERT_LIFE := 3.5
const BONE := Color("d9d3c2")
const DARK := Color(0.05, 0.06, 0.08, 0.85)
const EDGE := Color(0, 0, 0, 0.9)
const GOLD := Color("f0b54a")
const RED := Color("ef5d4a")
const GREY := Color("9fb0b1")
const HP_HERO := Color("5fbf6e")
const HP_ENEMY := Color("c9503f")

const PARTY_AT := Vector2(24, 190)
const PARTY_SIZE := Vector2(190, 46)
const PARTY_GAP := 8.0

var _texts: Array[Dictionary] = []
var _alerts: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A number that rises from a unit and fades.
func float_text(u: Unit, text: String, color: Color) -> void:
	float_at(u.global_position + Vector3(randf_range(-0.35, 0.35), u.height + 1.1, 0), text, color)


## Words that rise from a spot and fade.
func float_at(at: Vector3, text: String, color: Color) -> void:
	_texts.append({"at": at, "text": text, "color": color, "t": 0.0})


## A line across the top of the screen for a few seconds.
func alert(text: String) -> void:
	_alerts.append({"text": text, "t": 0.0})


## The party member whose frame is under that point of the screen: its id, or 0.
func ally_at(point: Vector2) -> int:
	if run == null or run.combat == null:
		return 0
	var heroes := run.combat.heroes
	for i in heroes.size():
		if _party_frame(i).has_point(point):
			return heroes[i].id
	return 0


func _party_frame(i: int) -> Rect2:
	return Rect2(PARTY_AT + Vector2(0, i * (PARTY_SIZE.y + PARTY_GAP)), PARTY_SIZE)


func _process(delta: float) -> void:
	for t in _texts:
		t.t += delta
	_texts = _texts.filter(func(t: Dictionary) -> bool: return t.t < TEXT_LIFE)
	for a in _alerts:
		a.t += delta
	_alerts = _alerts.filter(func(a: Dictionary) -> bool: return a.t < ALERT_LIFE)
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or run == null or run.player == null:
		return
	var combat := run.combat
	var p := combat.player

	var screen := Rect2(Vector2.ZERO, size).grow(80)
	for u: Unit in run.all_units():
		if not u.c.alive:
			continue
		var head := u.get_global_transform_interpolated().origin + Vector3(0, u.height + 0.45 + u.lift, 0)
		var s := cam.unproject_position(head)
		if not screen.has_point(s):
			continue
		var enemy := u.c.team == "enemy"
		var w := 84.0 if enemy else 64.0
		_bar(Rect2(s.x - w / 2, s.y - 5, w, 9), u.c.hp / u.c.max_hp, HP_ENEMY if enemy else HP_HERO, p.target_id == u.c.id)
		if enemy:
			_text(Vector2(s.x, s.y - 11), u.c.name, 13, BONE)
			var c := u.c.cast
			if c:
				# gold can be silenced, grey cannot
				_bar(Rect2(s.x - w / 2, s.y + 8, w, 7), c.t / c.total, GOLD if c.interruptible else GREY)
				_text(Vector2(s.x, s.y + 29), c.name, 12, GOLD if c.interruptible else GREY)

	for t in _texts:
		var k: float = t.t / TEXT_LIFE
		var s := cam.unproject_position(t.at) - Vector2(0, 50.0 * k)
		_text(s, t.text, 19, Color(t.color, 1.0 - k * k))

	for i in _alerts.size():
		var a := _alerts[i]
		_text(Vector2(size.x / 2, 120.0 + i * 30.0), a.text, 22, Color(GOLD, clampf((ALERT_LIFE - a.t) * 2.0, 0.0, 1.0)), 900.0)

	# the party, down the left: hold the mouse over one to aim an ally ability at them
	for i in combat.heroes.size():
		var h := combat.heroes[i]
		var r := _party_frame(i)
		draw_rect(r, DARK)
		draw_rect(r, GOLD if combat.hover_ally_id == h.id else Color(h.hero.color, 0.8), false, 2.0 if combat.hover_ally_id == h.id else 1.0)
		_text(r.position + Vector2(r.size.x / 2, 16), h.name if h.alive else h.name + " (dead)", 12, h.hero.color)
		_bar(Rect2(r.position + Vector2(8, 22), Vector2(r.size.x - 16, 10)), h.hp / h.max_hp, HP_HERO)
		_bar(Rect2(r.position + Vector2(8, 35), Vector2(r.size.x - 16, 4)), h.res / h.res_max, h.hero.res_color)
		var harm := h.auras.filter(func(a: Aura) -> bool: return a.debuff)
		if not harm.is_empty():
			_text(r.position + Vector2(r.size.x + 70, 28), harm[0].name, 12, RED, 130.0)

	var mid := size.x / 2
	var base := size.y - 24
	_run_bar(mid)

	# your frame, left of centre
	var me := Rect2(mid - 420, base - 150, 240, 62)
	_frame(me, "%s, %s" % [p.name, p.hero.title])
	_bar(Rect2(me.position + Vector2(8, 26), Vector2(224, 14)), p.hp / p.max_hp, HP_HERO)
	_text(me.position + Vector2(120, 38), "%d / %d" % [p.hp, p.max_hp], 11, Color.WHITE)
	_bar(Rect2(me.position + Vector2(8, 44), Vector2(224, 10)), p.res / p.res_max, p.hero.res_color)
	_text(me.position + Vector2(120, 53), "%d %s" % [p.res, p.hero.res_name.to_lower()], 10, Color.WHITE)
	_auras(me.position + Vector2(120, -8), p, -1)
	if p.hero.id == "duelist":
		for i in 5:
			draw_circle(me.position + Vector2(250 + 8, 10 + i * 12), 4.5, GOLD if i < p.combo else Color(BONE, 0.25))

	# your target's frame, right of centre
	var t := combat.unit(p.target_id)
	if t:
		var them := Rect2(mid + 180, base - 150, 240, 62)
		_frame(them, t.name if t.alive else t.name + " (dead)")
		_bar(Rect2(them.position + Vector2(8, 26), Vector2(224, 14)), t.hp / t.max_hp, HP_ENEMY)
		_text(them.position + Vector2(120, 38), "%d / %d" % [t.hp, t.max_hp], 11, Color.WHITE)
		var where := "%.0f m" % Combat.dist(p, t)
		if t.alive and not combat.sees(p, t):
			where += ", out of sight"
		_text(them.position + Vector2(120, 55), where, 11, BONE)
		_auras(them.position + Vector2(120, -8), t, p.id)

	# your cast bar, between the frames
	if p.cast:
		var r := Rect2(mid - 120, base - 112, 240, 14)
		_bar(r, p.cast.t / p.cast.total, GOLD)
		_text(r.position + Vector2(120, -6), p.cast.name, 13, BONE)

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
			_text(r.position + Vector2(side - 16, 15), str(int(ab.cost)), 11, p.hero.res_color)
		if st.cd > 0.0:
			# the cooldown drains down the button
			var left: float = clampf(st.cd / st.cd_max, 0.0, 1.0)
			draw_rect(Rect2(r.position + Vector2(0, side * (1.0 - left)), Vector2(side, side * left)), Color(0, 0, 0, 0.6))
			if st.cd_max > p.hero.gcd + 0.01:
				_text(r.position + Vector2(side / 2, side - 8), "%d" % ceili(st.cd) if st.cd >= 3.0 else "%.1f" % st.cd, 13, Color.WHITE)

	if combat.error != "":
		_text(Vector2(mid, base - 175), combat.error, 16, Color(RED, clampf(3.0 - combat.error_t * 2.0, 0.0, 1.0)), 500.0)


# The run across the top: level, the clock against the limit, and how far through you are.
func _run_bar(mid: float) -> void:
	var combat := run.combat
	var t := combat.total_time()
	var over := t > Combat.TIME_LIMIT
	var r := Rect2(mid - 170, 16, 340, 8)
	_bar(r, t / Combat.TIME_LIMIT, RED if over else GOLD)
	_text(Vector2(mid, 44), "Level %d    %s / %s" % [combat.level, clock(t), clock(Combat.TIME_LIMIT)], 16, RED if over else BONE, 400.0)
	var rooms := combat.packs.filter(func(p: Pack) -> bool: return p.cleared).size()
	var bosses := combat.packs.filter(func(p: Pack) -> bool: return p.boss)
	var lamps := bosses.filter(func(p: Pack) -> bool: return p.cleared).size()
	var line := "Rooms %d/%d" % [rooms, combat.packs.size()]
	if not bosses.is_empty():
		line += "    Lamps %d/%d" % [lamps, bosses.size()]
	if combat.deaths > 0:
		line += "    Deaths %d (+%d s)" % [combat.deaths, combat.deaths * Combat.DEATH_PENALTY]
	_text(Vector2(mid, 62), line, 12, GREY, 400.0)
	if combat.finished:
		_summary(mid)


static func clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


# The end of the run: the result, and what each hero did.
func _summary(mid: float) -> void:
	var combat := run.combat
	var r := Rect2(mid - 330, 150, 660, 300)
	draw_rect(r, Color(0.05, 0.06, 0.08, 0.94))
	draw_rect(r, GOLD if combat.timed() else BONE, false, 2.0)
	var result := "Timed" if combat.timed() else "Completed, over the time"
	_text(r.position + Vector2(330, 40), "%s: %s at level %d" % [result, clock(combat.total_time()), combat.level], 24, GOLD if combat.timed() else BONE, 640.0)
	var note := "Level %d unlocked" % (combat.level + 1) if run.unlocked_now else "The next level unlocks inside %s" % clock(Combat.TIME_LIMIT) if not combat.timed() else ""
	_text(r.position + Vector2(330, 66), note, 14, GOLD, 640.0)
	var cols := [150.0, 290.0, 380.0, 470.0, 545.0, 615.0]
	var heads := ["", "damage/s", "healing/s", "silenced", "cleansed", "deaths"]
	for i in heads.size():
		_text(r.position + Vector2(cols[i], 104), heads[i], 12, GREY, 120.0)
	var secs := maxf(1.0, combat.elapsed)
	for row in combat.heroes.size():
		var h := combat.heroes[row]
		var y := 130.0 + row * 28.0
		var cells := [h.name + (" (you)" if h.is_player else ""), "%d" % roundi(h.stats.dmg / secs), "%d" % roundi(h.stats.heal / secs),
			str(h.stats.interrupts), str(h.stats.dispels), str(h.stats.deaths)]
		for i in cells.size():
			_text(r.position + Vector2(cols[i], y), cells[i], 14, h.hero.color if i == 0 else BONE, 240.0 if i == 0 else 120.0)
	_text(r.position + Vector2(330, 274), "Enter runs it again.  = goes up a level,  - down.  F1 to F6 change hero.", 13, BONE, 640.0)


# The auras on a unit, stacked upwards from a point: name and seconds left. Harmful ones are red;
# on an enemy, the ones you put there are gold.
func _auras(at: Vector2, u: Combatant, mine_id: int) -> void:
	var row := 0
	for a in u.auras:
		var color := BONE
		if a.debuff:
			color = GOLD if a.src_id == mine_id else RED if u.team == "hero" else GREY
		var left := "" if a.t > 600.0 else "  %.0f" % a.t if a.t >= 3.0 else "  %.1f" % a.t
		var extra := "  (%d)" % a.absorb if a.absorb > 0.0 else ""
		_text(at - Vector2(0, row * 15.0), a.name + extra + left, 12, color)
		row += 1


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
