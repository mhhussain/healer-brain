class_name Route
extends RefCounted

# A plan for a run: the pulls, in order. A pull is one or more packs taken together, and
# optionally where the tank holds them, where the healer and each damage dealer stand, whether
# the tank goes at once without waiting for the party, and a note. Anything left out is the
# AI's choice.
#
# It is plain data, so that it can be saved, shared as a line of text and one day kept in a
# profile. Packs are named by their place in the level's list. A pack is in one pull at most.

const VERSION := 1
## What a route's text code begins with.
const CODE_MARK := "FF1:"
const NOTE_LENGTH := 80
## The party's places, which is how spots are named: 0 the tank, 1 the healer, 2 and 3 the
## damage dealers.
const PLACES := 4

var name := ""
## The id of the level it is for.
var level := ""
## {"packs": [int], "spots": {place: Vector3}, "go": bool, "note": String}, in the order they
## are made. A pull may be empty while it is being edited.
var pulls: Array[Dictionary] = []


static func pull(packs: Array = []) -> Dictionary:
	return {"packs": packs.duplicate(), "spots": {}, "go": false, "note": ""}


## The route a level comes with: its own, or failing that each pack by itself in the level's order.
static func default_for(def: LevelDef) -> Route:
	var r := Route.new()
	r.level = def.id
	r.name = "The safe way"
	if def.default_route.is_empty():
		for i in def.packs.size():
			r.pulls.append(pull([i]))
	else:
		for packs: Array in def.default_route:
			r.pulls.append(pull(packs))
	return r


func copy() -> Route:
	var r := Route.new()
	r.name = name
	r.level = level
	for p in pulls:
		r.pulls.append({"packs": p.packs.duplicate(), "spots": p.spots.duplicate(), "go": p.go, "note": p.note})
	return r


# ---------- asking

## The pull that pack is in, or -1.
func pull_of(pack: int) -> int:
	for i in pulls.size():
		if pulls[i].packs.has(pack):
			return i
	return -1


## What a pull's packs are worth.
func count_of(def: LevelDef, i: int) -> int:
	var n := 0
	for pack: int in pulls[i].packs:
		n += def.pack_count(pack)
	return n


## What the route is worth up to and including that pull.
func count_through(def: LevelDef, i: int) -> int:
	var n := 0
	for k in i + 1:
		n += count_of(def, k)
	return n


## The pull that brings the count to what the level asks for, or -1 if none does.
func completes_at(def: LevelDef) -> int:
	var n := 0
	for i in pulls.size():
		n += count_of(def, i)
		if n >= def.count_goal() and not pulls[i].packs.is_empty():
			return i
	return -1


## What the route leaves undone: {"count": how far short it falls, "bosses": the names of
## the bosses it never pulls}.
func missing(def: LevelDef) -> Dictionary:
	var bosses: Array[String] = []
	for i in def.packs.size():
		if def.packs[i].boss and pull_of(i) < 0:
			bosses.append(def.packs[i].name)
	var total := count_through(def, pulls.size() - 1) if not pulls.is_empty() else 0
	return {"count": maxi(0, def.count_goal() - total), "bosses": bosses}


# ---------- changing

## Puts a pack in that pull, taking it out of whichever pull had it; or takes it out, if that
## pull had it.
func toggle(pack: int, at: int) -> void:
	var was := pull_of(pack)
	if was >= 0:
		pulls[was].packs.erase(pack)
	if was != at:
		pulls[at].packs.append(pack)


## Adds an empty pull before that place, or at the end. Returns where it is.
func add_pull(before := -1) -> int:
	var at := pulls.size() if before < 0 else mini(before, pulls.size())
	pulls.insert(at, pull())
	return at


func remove_pull(i: int) -> void:
	pulls.remove_at(i)


## Moves a pull so that it ends up at that place in the order.
func move_pull(from: int, to: int) -> void:
	var p: Dictionary = pulls[from]
	pulls.remove_at(from)
	pulls.insert(clampi(to, 0, pulls.size()), p)


## Folds a pull into the one before it: its packs are taken after the other's. The earlier
## pull keeps its own spots, and takes this one's where it has none.
func merge_up(i: int) -> void:
	if i <= 0:
		return
	var into: Dictionary = pulls[i - 1]
	var from: Dictionary = pulls[i]
	into.packs.append_array(from.packs)
	for place: int in from.spots:
		if not into.spots.has(place):
			into.spots[place] = from.spots[place]
	if into.note == "":
		into.note = from.note
	pulls.remove_at(i)


func set_spot(i: int, place: int, at: Vector3) -> void:
	pulls[i].spots[place] = Vector3(at.x, 0, at.z)


func clear_spot(i: int, place: int) -> void:
	pulls[i].spots.erase(place)


## Drops the pulls with no pack in them.
func prune() -> void:
	pulls = pulls.filter(func(p: Dictionary) -> bool: return not p.packs.is_empty())


# ---------- saving and sharing

## As plain data, with nothing in it but numbers, words, lists and tables. A pull's spots,
## "go" and note are left out where there are none.
func to_dict() -> Dictionary:
	var list := []
	for p in pulls:
		var d := {"packs": p.packs.duplicate()}
		if not p.spots.is_empty():
			var spots := {}
			for place: int in p.spots:
				var at: Vector3 = p.spots[place]
				spots[str(place)] = [snappedf(at.x, 0.1), snappedf(at.z, 0.1)]
			d["spots"] = spots
		if p.go:
			d["go"] = true
		if p.note != "":
			d["note"] = p.note
		list.append(d)
	return {"v": VERSION, "level": level, "name": name, "pulls": list}


## Reads a route for that level from plain data, keeping what makes sense: packs the level
## has, each once; spots that are on its floor. Null if it is not a route for that level.
## With no level given it reads a route for whichever level it names, and takes its packs
## and spots on trust.
static func from_dict(d: Variant, def: LevelDef) -> Route:
	if not d is Dictionary or not d.get("level") is String or not d.get("pulls") is Array:
		return null
	if def and d.level != def.id:
		return null
	var r := Route.new()
	r.level = d.level
	r.name = str(d.get("name", "")).left(40)
	var taken := {}
	for item: Variant in d.pulls:
		if not item is Dictionary:
			continue
		var p := pull()
		var packs: Variant = item.get("packs")
		if packs is Array:
			for id: Variant in packs:
				if (id is int or id is float) and int(id) >= 0 and (def == null or int(id) < def.packs.size()) and not taken.has(int(id)):
					taken[int(id)] = true
					p.packs.append(int(id))
		var spots: Variant = item.get("spots")
		if spots is Dictionary:
			for key: Variant in spots:
				var xz: Variant = spots[key]
				var place := int(str(key)) if str(key).is_valid_int() else -1
				if place < 0 or place >= PLACES or not xz is Array or xz.size() != 2:
					continue
				if not (xz[0] is float or xz[0] is int) or not (xz[1] is float or xz[1] is int):
					continue
				var at := Vector3(xz[0], 0, xz[1])
				if def == null or def.can_stand(at):
					p.spots[place] = at
		var go: Variant = item.get("go")
		p.go = go is bool and go
		p.note = str(item.get("note", "")).left(NOTE_LENGTH)
		r.pulls.append(p)
	return r


## The route as one line of text, to copy and send to someone.
func to_code() -> String:
	return CODE_MARK + Marshalls.utf8_to_base64(JSON.stringify(to_dict()))


## Reads a route for that level from a text code. Null if the text is not one.
static func from_code(code: String, def: LevelDef) -> Route:
	var text := code.strip_edges()
	if not text.begins_with(CODE_MARK):
		return null
	var body := text.substr(CODE_MARK.length())
	# anything that is not base64 would be read as nothing at all, and complained about
	var allowed := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	if body.length() % 4 != 0 or allowed.search(body) == null:
		return null
	return from_dict(JSON.parse_string(Marshalls.base64_to_utf8(body)), def)
