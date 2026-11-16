class_name Levels
extends RefCounted

# The places to fight.

## The dungeons a run can be made in, by id, in the order they are offered.
const DUNGEONS: Array[String] = ["abbey", "tollhaven"]


static func by_name(name: String) -> LevelDef:
	match name:
		"sandbox": return sandbox()
		"tollhaven": return tollhaven()
	return abbey()


# ---------- the Drowned Abbey

const ENCOUNTERS := [
	{"name": "The Cloister Walk", "enemies": ["brute", "brute", "brute", "hexer"]},
	{"name": "The Wet Stair", "enemies": ["brute", "brute", "archer", "shaman"]},
	{"name": "Brother Krogg", "boss": true, "lamp_name": "the Gate Lamp", "lamp": "The Gate Lamp burns. Brother Krogg sets down his keys.", "enemies": ["krogg"]},
	{"name": "The Undercroft", "enemies": ["brute", "brute", "hexer", "hexer"], "pillars": [[-8, -4, 2], [8, -4, 2], [-8, 4, 2], [8, 4, 2]]},
	{"name": "The Dispensary", "enemies": ["overseer", "archer", "archer", "shaman"]},
	{"name": "Sister Velisse", "boss": true, "lamp_name": "the Ward Lamp", "lamp": "The Ward Lamp burns. Sister Velisse's little ones are quiet.", "enemies": ["velisse"]},
	{"name": "The Choir Stalls", "enemies": ["berserker", "berserker", "hexer", "shaman"], "pillars": [[-9, 0, 2], [9, 0, 2]]},
	{"name": "The Bell Stair", "enemies": ["overseer", "berserker", "archer", "archer"]},
	{"name": "Abbot Sulmar", "boss": true, "lamp_name": "the Bell Lamp", "lamp": "The Bell Lamp burns. The Abbot lets go of the rope.", "enemies": ["sulmar"],
		"pillars": [[-9, -5, 3], [9, -5, 3], [-9, 5, 3], [9, 5, 3]]},
]

# The rooms stand in a row along x. z is depth: the back wall is at -z, and FRONT is the open
# front edge nearest the camera. Rooms are split by walls that jut out from the back and leave
# a doorway along the front.
const FRONT := 8.0
const ROOM_DEPTH := 16.0
const BOSS_DEPTH := 20.0
const ROOM_WIDTH := 28.0
const BOSS_WIDTH := 34.0
const WALL := 3.0
const DOOR := 6.0
const TALL := 3.0
# the walls between rooms: tall enough to block the view, low enough to hide little of the floor
const DIVIDER := 2.2
const LOW := 1.0


## The Drowned Abbey: six packs and three bosses in nine rooms, in three parts of three, after
## the landing the party starts on. Each room is joined to the next by one doorway.
static func abbey() -> LevelDef:
	var l := LevelDef.new()
	l.id = "abbey"
	l.name = "The Drowned Abbey"
	l.zones = ["The Sea Gate", "The Infirmary", "The Nave"]
	# the room the party starts in
	var right := 18.0
	l.add_room("The Landing", Rect2(4, FRONT - ROOM_DEPTH, 14, ROOM_DEPTH), 0)
	l.add_wall(4, FRONT - ROOM_DEPTH - 0.6, 14, 0.6, TALL)
	l.add_wall(3.4, FRONT - ROOM_DEPTH, 0.6, ROOM_DEPTH, LOW)
	l.start = Vector3(11, 0, FRONT - ROOM_DEPTH / 2)
	l.lamps.append({"name": "the landing", "pos": _by_the_way_on(right), "pack": -1})
	var last_back := FRONT - ROOM_DEPTH
	for i in ENCOUNTERS.size():
		var enc: Dictionary = ENCOUNTERS[i]
		var boss: bool = enc.get("boss", false)
		var width := BOSS_WIDTH if boss else ROOM_WIDTH
		var depth := BOSS_DEPTH if boss else ROOM_DEPTH
		var left := right + WALL
		var back := FRONT - depth
		# the doorway along the front, and the wall that fills the rest of the gap between rooms
		var room := l.rooms.size()
		l.add_door(room - 1, room, Rect2(right, FRONT - DOOR, WALL, DOOR))
		var gap_back := minf(last_back, back) - 0.6
		l.add_wall(right, gap_back, WALL, FRONT - DOOR - gap_back, DIVIDER)
		# the room and its back wall
		l.add_room(enc.name, Rect2(left, back, width, depth), i / 3)
		l.add_wall(left, back - 0.6, width, 0.6, TALL)
		var centre := Vector3(left + width / 2, 0, FRONT - depth / 2)
		for p: Array in enc.get("pillars", []):
			l.add_pillar(centre.x + p[0], centre.z + p[1], p[2] / 2.0)
		l.packs.append({
			"name": enc.name, "boss": boss, "lamp": enc.get("lamp", ""), "enemies": enc.enemies, "room": room,
			"center": centre,
			"pull_from": Vector3(right + WALL / 2, 0, FRONT - DOOR / 2),
			"stand": Vector3(left + (10 if boss else 8), 0, centre.z + 1),
		})
		right = left + width
		last_back = back
		# a boss's lamp stands by the way on from its room
		if boss:
			l.lamps.append({"name": enc.lamp_name, "pos": _by_the_way_on(right), "pack": i})
	# the far end, and a low kerb all along the front so the floor is not hidden
	l.add_wall(right, last_back - 0.6, 0.6, FRONT - last_back + 0.6, TALL)
	l.add_wall(3.4, FRONT, right - 3.4 + 0.6, 0.6, LOW)
	return l


# Where a lamp stands in a room of the Abbey: just inside the doorway that leads on from it,
# given the x of that room's far end.
static func _by_the_way_on(right: float) -> Vector3:
	return Vector3(right - 4.25, 0, FRONT - 3.75)


# ---------- Tollhaven

# The harbour town under the Abbey: a market with three wings off it, each three rooms and a
# boss, two passages that join the wings, and a pier to the light at the harbour mouth, shut
# until the three wings' bosses are at rest. x runs east and z south. The camera looks from the
# south-west, so north and east walls are tall and the others low.

## The walls the camera looks over: as low as will still block the view.
const LOWWALL := 1.45
const THICK := 0.6
const GAP := 6.0

## key, name, x, z, width, depth, part of the town
const TOLL_ROOMS := [
	["S", "The Sea Stair", 92, 134, 16, 14, 0],
	["H", "The Fish Market", 80, 96, 40, 32, 0],
	["W1", "Net Row", 40, 98, 34, 28, 1],
	["W2", "The Drying Yard", 4, 96, 30, 30, 1],
	["W3", "The Smokehouse", 4, 56, 30, 34, 1],
	["WB", "The Net Loft", 2, 14, 36, 36, 1],
	["A1", "Gutter Lane", 40, 56, 38, 10, 1],
	["N1", "Chandlers' Cross", 84, 58, 32, 32, 2],
	["N2", "The Counting Rooms", 78, 22, 44, 30, 2],
	["N3", "The Bonded Store", 78, -14, 44, 30, 2],
	["NB", "The Custom House", 82, -56, 36, 36, 2],
	["A2", "The Ropewalk", 122, 56, 38, 10, 3],
	["E3", "The Sawpit", 166, 56, 30, 34, 3],
	["EB", "The Dry Dock", 162, 14, 38, 36, 3],
	["E2", "The Timber Yard", 166, 96, 30, 30, 3],
	["E1", "Keel Street", 126, 98, 34, 28, 3],
	["M", "The Mole", 110, 134, 66, 12, 4],
	["F", "The Harbour Light", 182, 132, 34, 28, 4],
]

## The two rooms a doorway joins, and its corner. Each is GAP square.
const TOLL_DOORS := [
	["S", "H", 97, 128], ["H", "W1", 74, 100], ["W1", "W2", 34, 100], ["W2", "W3", 8, 90], ["W3", "WB", 16, 50],
	["W3", "A1", 34, 58], ["A1", "N1", 78, 58], ["H", "N1", 97, 90], ["N1", "N2", 90, 52], ["N2", "N3", 90, 16],
	["N3", "NB", 97, -20], ["N1", "A2", 116, 58], ["A2", "E3", 160, 58], ["E3", "EB", 178, 50], ["E3", "E2", 186, 90],
	["E2", "E1", 160, 100], ["E1", "H", 120, 100], ["H", "M", 112, 128], ["M", "F", 176, 137],
]

## The packs, in the order of the safe way: room, name, enemies, its middle, and where the tank
## pulls it from. A patrol has the spots it walks between and where the tank holds it instead.
const TOLL_PACKS := [
	{"room": "H", "name": "The Harbour Watch", "enemies": ["brute", "brute", "archer", "shaman"], "at": [97, 114],
		"path": [[89, 108], [105, 108], [105, 121], [89, 121]], "stand": [100, 124]},
	{"room": "H", "name": "The Fish Stalls", "enemies": ["deckhand", "deckhand", "deckhand", "deckhand", "deckhand", "deckhand"], "at": [112, 103], "from": [100, 116]},
	{"room": "W1", "name": "Net Row", "enemies": ["deckhand", "deckhand", "deckhand", "deckhand", "dredger"], "at": [62, 104], "from": [76, 103]},
	{"room": "W1", "name": "The Net Menders", "enemies": ["archer", "archer", "hexer", "shaman"], "at": [47, 120], "from": [58, 112]},
	{"room": "W2", "name": "The Drying Racks", "enemies": ["dredger", "brute", "brute", "archer"], "at": [26, 102], "from": [38, 103]},
	{"room": "W2", "name": "The Salt Pans", "enemies": ["deckhand", "deckhand", "deckhand", "deckhand", "deckhand", "deckhand", "hexer"], "at": [12, 118], "from": [22, 109]},
	{"room": "W3", "name": "The Brine Vats", "enemies": ["berserker", "berserker", "shaman", "dredger"], "at": [26, 84], "from": [12, 87]},
	{"room": "W3", "name": "The Smoke Racks", "enemies": ["dredger", "dredger", "hexer", "archer"], "at": [20, 64], "from": [8, 76]},
	{"room": "WB", "name": "Mother Hask", "boss": "hask", "at": [20, 30], "from": [19, 52],
		"lamp_name": "the Net Lamp", "lamp": "The Net Lamp burns. Mother Hask lets her nets go slack.", "lamp_at": [24.5, 46.5]},
	{"room": "A1", "name": "Gutter Lane", "enemies": ["deckhand", "deckhand", "deckhand", "deckhand", "deckhand", "crier"], "at": [59, 61], "from": [38, 61]},
	{"room": "N1", "name": "The Cross Well", "enemies": ["crier", "brute", "brute", "archer"], "at": [100, 65], "from": [86, 62]},
	{"room": "N1", "name": "The Chandlery", "enemies": ["hexer", "hexer", "brute", "brute"], "at": [109, 82], "from": [98, 74]},
	{"room": "N2", "name": "The Counting Desks", "enemies": ["crier", "hexer", "mate", "archer"], "at": [91, 33], "from": [93, 50]},
	{"room": "N2", "name": "The Strongroom", "enemies": ["overseer", "hexer", "shaman", "archer"], "at": [113, 39], "from": [101, 43]},
	{"room": "N3", "name": "The Bonded Casks", "enemies": ["crier", "crier", "brute", "brute"], "at": [98, -4], "from": [94, 13]},
	{"room": "N3", "name": "The Tally Clerks", "enemies": ["hexer", "hexer", "hexer", "shaman"], "at": [114, 9], "from": [103, 4]},
	{"room": "NB", "name": "Exciseman Corrow", "boss": "corrow", "at": [100, -38], "from": [100, -18],
		"lamp_name": "the Tally Lamp", "lamp": "The Tally Lamp burns. Exciseman Corrow closes his book.", "lamp_at": [104.5, -23.5]},
	{"room": "A2", "name": "The Rope Gang", "enemies": ["mate", "deckhand", "deckhand", "deckhand", "deckhand"], "at": [141, 61],
		"path": [[152, 61], [130, 61]], "stand": [126, 61]},
	{"room": "E3", "name": "The Saw Benches", "enemies": ["mate", "mate", "archer", "shaman"], "at": [180, 64], "from": [163, 61]},
	{"room": "E3", "name": "The Pit Men", "enemies": ["berserker", "berserker", "brute", "hexer"], "at": [173, 84], "from": [185, 77]},
	{"room": "EB", "name": "Old Garrow", "boss": "garrow", "at": [181, 30], "from": [181, 52],
		"lamp_name": "the Slip Lamp", "lamp": "The Slip Lamp burns. Old Garrow lays down his adze.", "lamp_at": [186.5, 46.5]},
	{"room": "E2", "name": "The Yard Watch", "enemies": ["mate", "berserker", "archer", "archer"], "at": [178, 106],
		"path": [[172, 102], [184, 102], [184, 110], [172, 110]], "stand": [188, 100]},
	{"room": "E2", "name": "The Timber Stacks", "enemies": ["overseer", "mate", "shaman", "deckhand", "deckhand"], "at": [188, 119], "from": [178, 109]},
	{"room": "E1", "name": "The Caulkers", "enemies": ["brute", "brute", "brute", "shaman"], "at": [153, 120], "from": [157, 106]},
	{"room": "E1", "name": "Keel Street", "enemies": ["mate", "dredger", "archer", "hexer"], "at": [138, 104], "from": [153, 104]},
	{"room": "F", "name": "The Keeper of the Light", "boss": "keeper", "at": [199, 146], "from": [179, 140],
		"lamp_name": "the Harbour Light", "lamp": "The Harbour Light burns. The Keeper can go down to his supper.", "lamp_at": [185.5, 135.5]},
]

## Columns to hide behind: x, z and width.
const TOLL_PILLARS := [
	[10, 22, 2], [30, 22, 2], [10, 40, 2], [30, 40, 2],
	[90, -48, 2], [110, -48, 2], [90, -28, 2], [110, -28, 2],
	[168, 20, 2], [194, 20, 2], [168, 46, 2], [194, 46, 2],
	[190, 138, 3], [208, 138, 3], [190, 154, 3], [208, 154, 3],
	[92, 104, 2], [18, 112, 2], [100, 78, 2], [100, 37, 2], [104, 2, 2], [181, 74, 2], [176, 118, 2], [143, 116, 2], [55, 112, 2],
]


## Tollhaven: twenty-two packs and four bosses in eighteen rooms. It holds more than the count
## it asks for, so some packs can be left standing, and which is the route's choice.
static func tollhaven() -> LevelDef:
	var l := LevelDef.new()
	l.id = "tollhaven"
	l.name = "Tollhaven"
	l.time_limit = 25 * 60.0
	l.zones = ["The Fish Market", "The Net Quarter", "The Custom Quarter", "The Yards", "The Harbour Light"]
	var rooms := {}
	for r: Array in TOLL_ROOMS:
		rooms[r[0]] = l.add_room(r[1], Rect2(r[2], r[3], r[4], r[5]), r[6])
	var doors := {}
	for d: Array in TOLL_DOORS:
		doors[d[0] + d[1]] = l.add_door(rooms[d[0]], rooms[d[1]], Rect2(d[2], d[3], GAP, GAP))
	_enclose(l)
	for p: Array in TOLL_PILLARS:
		l.add_pillar(p[0], p[1], p[2] / 2.0)
	l.start = Vector3(100, 0, 142)
	l.lamps.append({"name": "the Sea Stair", "pos": Vector3(96, 0, 138), "pack": -1})
	var bosses: Array[int] = []
	for i in TOLL_PACKS.size():
		var p: Dictionary = TOLL_PACKS[i]
		var boss: bool = p.has("boss")
		var centre := Vector3(p.at[0], 0, p.at[1])
		var from: Vector3 = Vector3(p.from[0], 0, p.from[1]) if p.has("from") else centre
		# the tank holds a pack a few steps out from its posts, on the side it came from
		var stand: Vector3 = Vector3(p.stand[0], 0, p.stand[1]) if p.has("stand") else centre + (from - centre).limit_length(7.0 if boss else 5.0)
		var pack := {"name": p.name, "boss": boss, "lamp": p.get("lamp", ""), "enemies": [p.boss] if boss else p.enemies,
			"room": rooms[p.room], "center": centre, "pull_from": from, "stand": stand}
		if p.has("path"):
			pack["path"] = p.path.map(func(at: Array) -> Vector3: return Vector3(at[0], 0, at[1]))
		l.packs.append(pack)
		if boss:
			l.lamps.append({"name": p.lamp_name, "pos": Vector3(p.lamp_at[0], 0, p.lamp_at[1]), "pack": i})
			if p.room != "F":
				bosses.append(i)
	l.add_gate(doors["HM"], bosses, "The Mole gate")
	# about three tenths more than it asks for
	var held := 0
	for i in l.packs.size():
		held += l.pack_count(i)
	l.count_needed = roundi(held / 1.3)
	return l


# Walls round every room and along every doorway, with a gap wherever a doorway meets a room.
static func _enclose(l: LevelDef) -> void:
	for room in l.rooms:
		var r: Rect2 = room.rect
		_wall_with_gaps(l, Rect2(r.position.x - THICK, r.position.y - THICK, r.size.x + 2 * THICK, THICK), TALL)
		_wall_with_gaps(l, Rect2(r.position.x - THICK, r.end.y, r.size.x + 2 * THICK, THICK), LOWWALL)
		_wall_with_gaps(l, Rect2(r.position.x - THICK, r.position.y, THICK, r.size.y), LOWWALL)
		_wall_with_gaps(l, Rect2(r.end.x, r.position.y, THICK, r.size.y), TALL)
	for d in l.doors:
		var r: Rect2 = d.rect
		var a: Rect2 = l.rooms[d.a].rect
		var b: Rect2 = l.rooms[d.b].rect
		# a doorway runs north and south if a room is at its north or south end
		var upright := false
		for room: Rect2 in [a, b]:
			if is_equal_approx(room.end.y, r.position.y) or is_equal_approx(room.position.y, r.end.y):
				upright = true
		if upright:
			l.add_wall(r.position.x - THICK, r.position.y, THICK, r.size.y, LOWWALL)
			l.add_wall(r.end.x, r.position.y, THICK, r.size.y, TALL)
		else:
			l.add_wall(r.position.x, r.position.y - THICK, r.size.x, THICK, TALL)
			l.add_wall(r.position.x, r.end.y, r.size.x, THICK, LOWWALL)


# A wall along one side of a room, left open wherever a doorway meets it.
static func _wall_with_gaps(l: LevelDef, wall: Rect2, height: float) -> void:
	var along_x := wall.size.x >= wall.size.y
	var gaps: Array = []
	for d in l.doors:
		var r: Rect2 = d.rect
		if r.grow(0.01).intersects(wall):
			gaps.append([r.position.x, r.end.x] if along_x else [r.position.y, r.end.y])
	gaps.sort()
	var at := wall.position.x if along_x else wall.position.y
	var end := wall.end.x if along_x else wall.end.y
	for gap: Array in gaps + [[end, end]]:
		if gap[0] > at + 0.01:
			if along_x:
				l.add_wall(at, wall.position.y, gap[0] - at, wall.size.y, height)
			else:
				l.add_wall(wall.position.x, at, wall.size.x, gap[0] - at, height)
		at = maxf(at, gap[1])


# ---------- the sandbox

## A grey-box hall of two rooms for trying things out: a small pack in the first, and a harder
## one through the doorway.
static func sandbox() -> LevelDef:
	var l := LevelDef.new()
	l.id = "sandbox"
	l.name = "Sandbox"
	# two rooms, and a doorway in the middle of the wall between them
	l.add_room("The first room", Rect2(-4, -7, 29.7, 14))
	l.add_room("Through the doorway", Rect2(26.3, -7, 29.7, 14))
	l.add_door(0, 1, Rect2(25.7, -2, 0.6, 4))
	# tall at the back and the far end, low at the front and the start so they do not hide the floor
	l.add_wall(-4.6, -7.6, 61.2, 0.6, 3.0)
	l.add_wall(56, -7, 0.6, 14, 3.0)
	l.add_wall(-4.6, 7, 61.2, 0.6, 1.0)
	l.add_wall(-4.6, -7, 0.6, 14, 1.0)
	l.add_wall(25.7, -7, 0.6, 5, 2.0)
	l.add_wall(25.7, 2, 0.6, 5, 2.0)
	# a crate: in the way, but low enough to throw over
	l.add_wall(19.4, -5.2, 1.2, 1.2, 1.2)
	l.add_pillar(9, -3, 0.8)
	l.add_pillar(16, 3, 0.8)
	l.add_pillar(36, -2, 0.8)
	l.add_pillar(44, 3, 0.8)
	l.start = Vector3(2, 0, 0)
	l.packs = [
		{"name": "The first room", "boss": false, "lamp": "", "enemies": ["brute", "hexer"], "room": 0,
			"center": Vector3(19, 0, 0.5), "pull_from": Vector3(5, 0, 0), "stand": Vector3(12, 0, 1)},
		{"name": "Through the doorway", "boss": false, "lamp": "", "enemies": ["overseer", "archer", "shaman"], "room": 1,
			"center": Vector3(42, 0, 0), "pull_from": Vector3(26, 0, 0), "stand": Vector3(34, 0, 1)},
	]
	return l
