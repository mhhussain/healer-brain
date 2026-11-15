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


## The figure for that hero or enemy, or null if it has none yet.
static func scene_for(def_id: String) -> PackedScene:
	var path: String = FOLDER + FILES.get(def_id, def_id) + ".glb"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene
