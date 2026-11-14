class_name Levels
extends RefCounted

# The places to fight.

static func by_name(name: String) -> LevelDef:
	return sandbox() if name == "sandbox" else abbey()


# ---------- the Drowned Abbey

const ENCOUNTERS := [
	{"name": "The Cloister Walk", "enemies": ["brute", "brute", "brute", "hexer"]},
	{"name": "The Wet Stair", "enemies": ["brute", "brute", "archer", "shaman"]},
	{"name": "Brother Krogg", "boss": true, "lamp": "The Gate Lamp burns. Brother Krogg sets down his keys.", "enemies": ["krogg"]},
	{"name": "The Undercroft", "enemies": ["brute", "brute", "hexer", "hexer"], "pillars": [[-8, -4, 2], [8, -4, 2], [-8, 4, 2], [8, 4, 2]]},
	{"name": "The Dispensary", "enemies": ["overseer", "archer", "archer", "shaman"]},
	{"name": "Sister Velisse", "boss": true, "lamp": "The Ward Lamp burns. Sister Velisse's little ones are quiet.", "enemies": ["velisse"]},
	{"name": "The Choir Stalls", "enemies": ["berserker", "berserker", "hexer", "shaman"], "pillars": [[-9, 0, 2], [9, 0, 2]]},
	{"name": "The Bell Stair", "enemies": ["overseer", "berserker", "archer", "archer"]},
	{"name": "Abbot Sulmar", "boss": true, "lamp": "The Bell Lamp burns. The Abbot lets go of the rope.", "enemies": ["sulmar"],
		"pillars": [[-9, -5, 3], [9, -5, 3], [-9, 5, 3], [9, 5, 3]]},
]

# One straight hall, running along x. z is depth: the back wall is at -z, and FRONT is the open
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


## The Drowned Abbey: six packs and three bosses in nine rooms, in three parts of three.
static func abbey() -> LevelDef:
	var l := LevelDef.new()
	l.name = "The Drowned Abbey"
	l.zones = ["The Sea Gate", "The Infirmary", "The Nave"]
	# the room the party starts in
	var right := 18.0
	l.floors.append(Rect2(4, FRONT - ROOM_DEPTH, 14, ROOM_DEPTH))
	l.add_wall(4, FRONT - ROOM_DEPTH - 0.6, 14, 0.6, TALL)
	l.add_wall(3.4, FRONT - ROOM_DEPTH, 0.6, ROOM_DEPTH, LOW)
	l.start = Vector3(11, 0, FRONT - ROOM_DEPTH / 2)
	var last_back := FRONT - ROOM_DEPTH
	for i in ENCOUNTERS.size():
		var enc: Dictionary = ENCOUNTERS[i]
		var boss: bool = enc.get("boss", false)
		var width := BOSS_WIDTH if boss else ROOM_WIDTH
		var depth := BOSS_DEPTH if boss else ROOM_DEPTH
		var left := right + WALL
		var back := FRONT - depth
		# the doorway along the front, and the wall that fills the rest of the gap between rooms
		l.floors.append(Rect2(right, FRONT - DOOR, WALL, DOOR))
		l.doors.append(Vector3(right + WALL / 2, 0, FRONT - DOOR / 2))
		var gap_back := minf(last_back, back) - 0.6
		l.add_wall(right, gap_back, WALL, FRONT - DOOR - gap_back, DIVIDER)
		# the room and its back wall
		l.floors.append(Rect2(left, back, width, depth))
		l.add_wall(left, back - 0.6, width, 0.6, TALL)
		var centre := Vector3(left + width / 2, 0, FRONT - depth / 2)
		for p: Array in enc.get("pillars", []):
			l.add_pillar(centre.x + p[0], centre.z + p[1], p[2] / 2.0)
		l.packs.append({
			"name": enc.name, "boss": boss, "lamp": enc.get("lamp", ""), "enemies": enc.enemies, "zone": i / 3,
			"center": centre,
			"entry": Vector3(right - 3, 0, FRONT - DOOR / 2),
			"pull_from": Vector3(right + WALL / 2, 0, FRONT - DOOR / 2),
			"stand": Vector3(left + (10 if boss else 8), 0, centre.z + 1),
			"room_left": left,
		})
		right = left + width
		last_back = back
	# the far end, and a low kerb all along the front so the floor is not hidden
	l.add_wall(right, last_back - 0.6, 0.6, FRONT - last_back + 0.6, TALL)
	l.add_wall(3.4, FRONT, right - 3.4 + 0.6, 0.6, LOW)
	return l


# ---------- the sandbox

## A grey-box hall of two rooms for trying things out: a small pack in the first, and a harder
## one through the doorway.
static func sandbox() -> LevelDef:
	var l := LevelDef.new()
	l.name = "Sandbox"
	l.floors = [Rect2(-4, -7, 60, 14)]
	# tall at the back and the far end, low at the front and the start so they do not hide the floor
	l.add_wall(-4.6, -7.6, 61.2, 0.6, 3.0)
	l.add_wall(56, -7, 0.6, 14, 3.0)
	l.add_wall(-4.6, 7, 61.2, 0.6, 1.0)
	l.add_wall(-4.6, -7, 0.6, 14, 1.0)
	# the wall between the rooms, with a doorway in the middle
	l.add_wall(25.7, -7, 0.6, 5, 2.0)
	l.add_wall(25.7, 2, 0.6, 5, 2.0)
	l.doors = [Vector3(26, 0, 0)]
	# a crate: in the way, but low enough to throw over
	l.add_wall(19.4, -5.2, 1.2, 1.2, 1.2)
	l.add_pillar(9, -3, 0.8)
	l.add_pillar(16, 3, 0.8)
	l.add_pillar(36, -2, 0.8)
	l.add_pillar(44, 3, 0.8)
	l.start = Vector3(2, 0, 0)
	l.packs = [
		{"name": "The first room", "boss": false, "lamp": "", "enemies": ["brute", "hexer"],
			"center": Vector3(19, 0, 0.5), "entry": Vector3(3, 0, 0), "pull_from": Vector3(5, 0, 0),
			"stand": Vector3(12, 0, 1), "room_left": -4.0},
		{"name": "Through the doorway", "boss": false, "lamp": "", "enemies": ["overseer", "archer", "shaman"],
			"center": Vector3(42, 0, 0), "entry": Vector3(22, 0, 0), "pull_from": Vector3(26, 0, 0),
			"stand": Vector3(34, 0, 1), "room_left": 26.3},
	]
	return l
