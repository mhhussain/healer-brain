class_name Figures
extends RefCounted

# Which 3D figure stands for each hero and enemy. To swap one for your own, save your .glb over
# the file named here (or change the name here to your file's). A unit with no file keeps the
# grey capsule.
#
# What a figure file must be: facing +Z, standing on the floor at the centre, sized in metres,
# with clips named idle, run, attack, cast, hit and fall (any that are missing are skipped).

const FOLDER := "res://assets/characters/"

## Hero or enemy id (as in rules/heroes.gd and rules/enemies.gd) -> file name, without ".glb".
const FILES := {
	"warden": "warden",
	"mender": "lamplighter",
	"bloomweaver": "kelpwife",
	"duelist": "wrecker",
	"ranger": "harpooner",
	"pyromancer": "chandler",
	"brute": "porter",
	"hexer": "cantor",
	"archer": "net_brother",
	"shaman": "almoner",
	"berserker": "penitent",
	"overseer": "prior",
	"hatchling": "brineling",
	"krogg": "krogg",
	"velisse": "velisse",
	"sulmar": "sulmar",
}

## The clips a figure may carry. A figure that shares another's clips has them as "shared/run".
const CLIPS := ["idle", "run", "attack", "cast", "hit", "fall"]


# figures already read from disk, so that a unit appearing mid-fight does not stall the game
static var _loaded := {}


## The figure for that hero or enemy, or null if it has none yet.
static func scene_for(def_id: String) -> PackedScene:
	if not _loaded.has(def_id):
		var path: String = FOLDER + FILES.get(def_id, def_id) + ".glb"
		_loaded[def_id] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	return _loaded[def_id]


## A new figure for that hero or enemy, or null if it has none yet.
static func make(def_id: String) -> Node3D:
	var scene := scene_for(def_id)
	return scene.instantiate() as Node3D if scene else null


## Gives a figure copies of its materials that are its alone, so a hit can flash it without
## flashing every figure of its kind, and returns them. The glow is always on (at nothing), so
## that a flash does not make the engine build a new shader in the middle of a fight.
static func own_materials(figure: Node3D) -> Array[StandardMaterial3D]:
	var mine: Array[StandardMaterial3D] = []
	var copies := {}
	for node in figure.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		for i in part.mesh.get_surface_count():
			var mat := part.mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null:
				continue
			if not copies.has(mat):
				var copy: StandardMaterial3D = mat.duplicate()
				copy.emission_enabled = true
				copy.emission = Color.BLACK
				copies[mat] = copy
				mine.append(copy)
			part.set_surface_override_material(i, copies[mat])
	return mine


## Everyone who can appear in a run of that place with that party: the ids to have ready.
static func cast_of(party: Array, level: LevelDef) -> Array[String]:
	var ids: Array[String] = []
	for id: String in party:
		if id not in ids:
			ids.append(id)
	for pack in level.packs:
		for id: String in pack.enemies:
			if id not in ids:
				ids.append(id)
	# Sister Velisse wakes her ward mid-fight
	if "velisse" in ids:
		ids.append("hatchling")
	return ids
