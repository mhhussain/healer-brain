class_name Levels
extends RefCounted

# The places to fight.

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
