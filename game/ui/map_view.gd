class_name MapView
extends Control

# The dungeon seen from straight above, drawn from the level's own description: rooms,
# doorways, walls, pillars, lamps and packs, with the route laid over it. It reports clicks on
# packs and the dragging of the spot markers; the planner round it decides what they mean.
#
# The wheel zooms about the pointer. Dragging empty floor, or dragging with the right or
# middle button, moves the map.

## A pack was clicked. `fresh` is true with Shift held: start a new pull with it.
signal pack_clicked(pack: int, fresh: bool)
## A spot marker was dropped: on the floor at `at`, or off it (`placed` false) to clear it.
signal spot_dropped(place: int, at: Vector3, placed: bool)

## One colour a pull, by its place in the route; they come round again after the last.
const PULL_COLORS: Array[Color] = [
	Color("56b4e9"), Color("e69f00"), Color("cc79a7"), Color("009e73"), Color("f0e442"), Color("d55e00"),
	Color("9d8df1"), Color("7fd1c7"), Color("f29ca3"), Color("b5d66b"), Color("c9a27a"), Color("8fa7d6"),
]
## What stands for each kind of enemy: a colour and a letter.
const ENEMY_MARKS := {
	"brute": [Color("b5651d"), "P"], "berserker": [Color("d9534f"), "F"], "hexer": [Color("9b6fd6"), "C"],
	"archer": [Color("4aa3a3"), "N"], "shaman": [Color("6fbf73"), "A"], "overseer": [Color("d4a72c"), "Pr"],
}
const BOSS_MARK := [Color("e0503a"), "B"]
const PLACE_LETTERS := ["T", "H", "D", "D"]
const FLOOR := Color(0.2, 0.24, 0.27)
const DOORWAY := Color(0.27, 0.31, 0.33)
const WALL := Color(0.42, 0.46, 0.48)
const KERB := Color(0.3, 0.34, 0.36)
const FADED := Color(0.55, 0.58, 0.6, 0.55)
## How far round a pack's middle counts as the pack, in metres.
const PACK_REACH := 5.4
const MAX_ZOOM := 16.0
const MARKER := 11.0

var def: LevelDef
var route: Route
## The pull being edited: its spots are the ones shown.
var current := 0
## The party, for the colours of the spot markers.
var party: Array[String] = []
## During a run: what is already dead is shown as done, and where everyone is.
var combat: Combat

## Pixels to a metre, and the spot of the level at the middle of the view.
var zoom := 3.0
var centre := Vector2.ZERO
## The pack under the pointer, or -1.
var hover := -1

var _fit := 3.0
var _fitted := false
var _panning := false
var _pan_moved := 0.0
var _pressed_pack := -1
# the spot marker being dragged: its place in the party, or -1
var _dragging := -1
var _drag_at := Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void:
		if not _fitted:
			fit())


func show_level(level: LevelDef, plan: Route) -> void:
	def = level
	route = plan
	_fitted = false
	fit()


## Zooms and moves so that the whole level is in view.
func fit() -> void:
	if def == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var all := bounds()
	_fit = minf((size.x - 60.0) / all.size.x, (size.y - 120.0) / all.size.y)
	zoom = clampf(_fit, 0.5, MAX_ZOOM)
	centre = all.get_center()
	_fitted = true
	queue_redraw()


## The rectangle that holds all the level's floor.
func bounds() -> Rect2:
	var all: Rect2 = def.floors[0]
	for f in def.floors:
		all = all.merge(f)
	return all


func to_screen(p: Vector3) -> Vector2:
	return (Vector2(p.x, p.z) - centre) * zoom + size / 2.0


func to_level(s: Vector2) -> Vector3:
	var at := (s - size / 2.0) / zoom + centre
	return Vector3(at.x, 0, at.y)


func _rect(r: Rect2) -> Rect2:
	return Rect2((r.position - centre) * zoom + size / 2.0, r.size * zoom)


static func pull_color(i: int) -> Color:
	return PULL_COLORS[i % PULL_COLORS.size()]


static func enemy_mark(id: String) -> Array:
	return BOSS_MARK if Enemies.by_id(id).boss else ENEMY_MARKS.get(id, [Kit.GREY, "?"])


## The pack whose ground that point of the view is on, or -1.
func pack_at(s: Vector2) -> int:
	var at := to_level(s)
	var best := -1
	var best_d := PACK_REACH
	for i in def.packs.size():
		var d := Combat.flat(at, def.packs[i].center)
		if d < best_d:
			best_d = d
			best = i
	return best


## Whether that pack is already dead in the run this map is open over.
func done(pack: int) -> bool:
	return combat != null and pack < combat.packs.size() and combat.packs[pack].cleared


# Where a spot marker is drawn: on its spot, or waiting in the tray along the bottom.
func _marker_at(place: int) -> Vector2:
	if _dragging == place:
		return _drag_at
	var spots: Dictionary = route.pulls[current].spots if current < route.pulls.size() else {}
	if spots.has(place):
		return to_screen(spots[place])
	return Vector2(28.0 + place * 34.0, size.y - 30.0)


func _marker_under(s: Vector2) -> int:
	if route == null or current >= route.pulls.size():
		return -1
	for place in Route.PLACES:
		if s.distance_to(_marker_at(place)) <= MARKER + 3.0:
			return place
	return -1


# ---------- the mouse

func _gui_input(event: InputEvent) -> void:
	if def == null or route == null:
		return
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	if mb and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_about(mb.position, 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_about(event.position, event.factor)
		accept_event()
	elif event is InputEventPanGesture:
		zoom_about(event.position, 1.0 - event.delta.y * 0.03)
		accept_event()
	elif mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_dragging = _marker_under(mb.position)
			_drag_at = mb.position
			_pressed_pack = pack_at(mb.position) if _dragging < 0 else -1
			_panning = _dragging < 0
			_pan_moved = 0.0
		else:
			if _dragging >= 0:
				var at := to_level(mb.position)
				spot_dropped.emit(_dragging, at, def.can_stand(at))
			elif _pressed_pack >= 0 and _pan_moved < 6.0 and pack_at(mb.position) == _pressed_pack:
				pack_clicked.emit(_pressed_pack, mb.shift_pressed)
			_dragging = -1
			_pressed_pack = -1
			_panning = false
		accept_event()
		queue_redraw()
	elif mb and mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		# a right click on a marker sends it back to the tray
		var marker := _marker_under(mb.position) if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT else -1
		if marker >= 0:
			spot_dropped.emit(marker, Vector3.ZERO, false)
		else:
			_panning = mb.pressed
			_pan_moved = 0.0
		accept_event()
	elif mm:
		if _dragging >= 0:
			_drag_at = mm.position
		elif _panning:
			_pan_moved += mm.relative.length()
			if _pan_moved >= 6.0 or _pressed_pack < 0:
				centre -= mm.relative / zoom
				_keep_in_view()
		hover = pack_at(mm.position) if _dragging < 0 else -1
		queue_redraw()


func zoom_about(at: Vector2, by: float) -> void:
	var under := to_level(at)
	zoom = clampf(zoom * by, minf(_fit, MAX_ZOOM), MAX_ZOOM)
	# the spot under the pointer stays under it
	centre = Vector2(under.x, under.z) - (at - size / 2.0) / zoom
	_keep_in_view()
	queue_redraw()


func _keep_in_view() -> void:
	var all := bounds()
	centre = centre.clamp(all.position, all.end)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover = -1
		queue_redraw()


# ---------- drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.07))
	if def == null or route == null:
		return
	for room in def.rooms:
		draw_rect(_rect(room.rect), FLOOR)
	if def.rooms.is_empty():
		for f in def.floors:
			draw_rect(_rect(f), FLOOR)
	for d in def.doors:
		draw_rect(_rect(d.rect), DOORWAY)
	for w in def.walls:
		draw_rect(_rect(w.rect), WALL if w.height >= 1.5 else KERB)
	for i in def.pillars.size():
		var p: Dictionary = def.pillars[i]
		var fallen: bool = combat != null and i < combat.pillars.size() and not combat.pillars[i].alive
		draw_circle(to_screen(p.pos), maxf(2.0, p.r * zoom), Color(WALL, 0.3) if fallen else WALL)
	if zoom >= 5.0:
		for room in def.rooms:
			var r := _rect(room.rect)
			Kit.text(self, Vector2(r.get_center().x, r.position.y + 16.0), room.name, 12, Color(Kit.GREY, 0.8), r.size.x)
	for i in def.lamps.size():
		_draw_lamp(i)
	_draw_path()
	for i in def.packs.size():
		_draw_pack(i)
	_draw_party()
	_draw_spots()
	_draw_key()
	if hover >= 0 and _dragging < 0:
		_draw_details(hover)


func _draw_lamp(i: int) -> void:
	var lamp: Dictionary = def.lamps[i]
	var at := to_screen(lamp.pos)
	var lit: bool = combat.lamps[i].lit if combat != null and i < combat.lamps.size() else lamp.pack < 0
	var s := 5.0
	var shape := PackedVector2Array([at + Vector2(0, -s), at + Vector2(s, 0), at + Vector2(0, s), at + Vector2(-s, 0)])
	draw_colored_polygon(shape, Kit.GOLD if lit else Color(Kit.GOLD, 0.25))
	draw_polyline(shape + PackedVector2Array([shape[0]]), Color(Kit.GOLD, 0.9), 1.0)


# The middle of a pull: of its packs' middles.
func _pull_middle(i: int) -> Vector3:
	var mid := Vector3.ZERO
	var packs: Array = route.pulls[i].packs
	for pack: int in packs:
		mid += def.packs[pack].center / packs.size()
	return mid


# A line from each pull to the next, so the order can be followed by eye.
func _draw_path() -> void:
	var last = null
	for i in route.pulls.size():
		if route.pulls[i].packs.is_empty():
			continue
		var at := to_screen(_pull_middle(i))
		if last != null:
			draw_line(last, at, Color(Kit.BONE, 0.35), 2.0, true)
		last = at


func _draw_pack(i: int) -> void:
	var pack: Dictionary = def.packs[i]
	var at := to_screen(pack.center)
	var pull := route.pull_of(i)
	var is_done := done(i)
	var color := pull_color(pull) if pull >= 0 else FADED
	if is_done:
		color = Color(color, 0.3)
	var reach := (PACK_REACH - 0.6) * zoom
	# its ground: tinted in its pull's colour, edged more boldly for the pull being edited
	if pull >= 0:
		draw_circle(at, reach, Color(color, 0.14 if not is_done else 0.05))
		draw_arc(at, reach, 0.0, TAU, 40, color, 3.0 if pull == current else 1.5, true)
	elif hover == i:
		draw_arc(at, reach, 0.0, TAU, 40, FADED, 1.0, true)
	var posts := LevelDef.posts(pack)
	for k in posts.size():
		var mark := enemy_mark(pack.enemies[k])
		var def_e := Enemies.by_id(pack.enemies[k])
		var r := maxf(3.0, def_e.radius * zoom * 1.3)
		var fill: Color = mark[0] if pull >= 0 else Color((mark[0] as Color).lerp(Color(0.5, 0.5, 0.5), 0.6), 0.6)
		if is_done:
			fill = Color(fill, 0.25)
		draw_circle(to_screen(posts[k]), r, fill)
		draw_arc(to_screen(posts[k]), r, 0.0, TAU, 20, Color(0, 0, 0, 0.7), 1.0, true)
	if pull >= 0:
		var tag := at + Vector2(0, -reach - 4.0)
		Kit.text(self, tag, str(pull + 1), 15, color, 60.0)
		if pull == route.completes_at(def) and i == route.pulls[pull].packs[-1]:
			Kit.text(self, tag + Vector2(0, -15.0), "100%", 11, Kit.GREEN, 60.0)
	if is_done:
		Kit.text(self, at + Vector2(0, 5.0), "done", 11, Color(Kit.GREY, 0.8), 60.0)


func _draw_party() -> void:
	if combat == null:
		return
	for h in combat.heroes:
		var at := to_screen(h.pos)
		draw_circle(at, 4.0, h.hero.color)
		if h.is_player:
			draw_arc(at, 7.0, 0.0, TAU, 20, Kit.GOLD, 1.5, true)


# The markers of the pull being edited: one for each place in the party, on its spot or in
# the tray along the bottom if it has none.
func _draw_spots() -> void:
	if current >= route.pulls.size():
		return
	var spots: Dictionary = route.pulls[current].spots
	Kit.text(self, Vector2(160.0, size.y - 54.0), "Pull %d: drag onto the map to say who stands where" % (current + 1), 11, Kit.GREY, 300.0, HORIZONTAL_ALIGNMENT_LEFT)
	for place in Route.PLACES:
		var at := _marker_at(place)
		var color: Color = Heroes.by_id(party[place]).color if place < party.size() else Kit.BONE
		var placed := spots.has(place) or _dragging == place
		draw_circle(at, MARKER, Color(0.05, 0.06, 0.08, 0.95))
		draw_arc(at, MARKER, 0.0, TAU, 24, color if placed else Color(color, 0.6), 2.5 if placed else 1.5, true)
		Kit.text(self, at + Vector2(0, 5.0), PLACE_LETTERS[place], 13, color, 30.0)


# What the discs stand for, down the top left: each kind of enemy the level has.
func _draw_key() -> void:
	var seen := {}
	var y := 20.0
	for pack in def.packs:
		for id: String in pack.enemies:
			var e := Enemies.by_id(id)
			var key := "boss" if e.boss else id
			if seen.has(key):
				continue
			seen[key] = true
			var mark := enemy_mark(id)
			draw_circle(Vector2(20, y), 8.0, mark[0])
			Kit.text(self, Vector2(20, y + 4.0), mark[1], 10, Color.WHITE, 20.0)
			Kit.text(self, Vector2(36, y + 4.0), "A boss" if e.boss else e.name, 12, Kit.GREY, 200.0, HORIZONTAL_ALIGNMENT_LEFT)
			y += 20.0
	draw_colored_polygon(PackedVector2Array([Vector2(20, y - 6), Vector2(26, y), Vector2(20, y + 6), Vector2(14, y)]), Kit.GOLD)
	Kit.text(self, Vector2(36, y + 4.0), "A lamp: where a beaten party starts again", 12, Kit.GREY, 300.0, HORIZONTAL_ALIGNMENT_LEFT)


# What a pack is made of, beside it.
func _draw_details(i: int) -> void:
	var pack: Dictionary = def.packs[i]
	var lines: Array[String] = []
	var kinds := {}
	for id: String in pack.enemies:
		kinds[id] = kinds.get(id, 0) + 1
	var scale := combat.scale if combat else 1.0
	for id: String in kinds:
		var e := Enemies.by_id(id)
		var level := combat.level if combat else 1
		var does := e.abilities.filter(func(a: EnemyAbility) -> bool: return a.min_level <= level).map(func(a: EnemyAbility) -> String: return a.name)
		lines.append("%d× %s   %d health   %s" % [kinds[id], e.name, roundi(e.hp * scale), "count %d" % e.count if e.count > 0 else "no count"])
		if not does.is_empty():
			lines.append("      " + ", ".join(does))
	var pull := route.pull_of(i)
	var head := "%s   count %d%s" % [pack.name, def.pack_count(i), "   pull %d" % (pull + 1) if pull >= 0 else "   in no pull"]
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
	var box := Rect2(to_screen(pack.center) + Vector2(PACK_REACH * zoom + 10.0, -20.0), Vector2(w + 20.0, 30.0 + lines.size() * 17.0))
	box.position.x = clampf(box.position.x, 6.0, maxf(6.0, size.x - box.size.x - 6.0))
	box.position.y = clampf(box.position.y, 6.0, maxf(6.0, size.y - box.size.y - 70.0))
	Kit.frame(self, box, Color(Kit.GOLD, 0.7))
	draw_string(font, box.position + Vector2(10, 20), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Kit.GOLD)
	for k in lines.size():
		draw_string(font, box.position + Vector2(10, 40 + k * 17.0), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Kit.BONE)
