class_name SaveData
extends RefCounted

# What is kept between runs: how far you have got in each dungeon and your records there, the
# gear you own and the teams that wear it, the party you last chose and the routes you have
# planned. It is plain data with a version number, so that it can be read by a later game, kept
# as a file of text and one day moved to a profile. Reading and writing the file
# is the scene's job (scripts/save_store.gd).

## Goes up when what is kept changes shape. 1 had no number and no routes. 2 had one dungeon:
## its levels and bests are now the Abbey's. 3 had no gear, teams or records.
const VERSION := 4
## Routes kept for each level.
const SLOTS := 3

## The dungeon the next run is in: one of Levels.DUNGEONS.
var place := "abbey"
## Dungeon id -> {"unlocked", "level", "bests", "timed", "records"}: how far you have got in
## each. Levels are earned in each dungeon by itself. "timed" is the highest level finished in
## time there, and "records" is level (as text) -> {"time", "party", "slot"}: the best time at
## each level and the four who set it. The three below read and write the chosen dungeon's.
var progress := {}
## The highest level you may start: one above your highest timed clear. Shared by all heroes.
var unlocked: int:
	get: return progress_in(place).unlocked
	set(n): progress_in(place).unlocked = n
## The level chosen for the next run.
var level: int:
	get: return progress_in(place).level
	set(n): progress_in(place).level = n
## Hero id -> {"level": highest level timed with that hero, "time": best time at it, in seconds}.
var bests: Dictionary:
	get: return progress_in(place).bests
	set(d): progress_in(place).bests = d
var party: Array[String] = ["warden", "mender", "duelist", "ranger"]
var slot := 3
## How loud the game is, 0 to 1, and whether sound is off.
var volume := 0.8
var muted := false
## Hero id -> ability id -> [key, key]: two slots of physical keycodes, 0 for an empty one.
var keys := {}
## Hero id -> ability id -> "M", "X1" or "X2": a mouse button that casts it wherever the pointer is.
var mouse := {}
## Hero id -> ability id -> a click on a party frame, such as "L" or "S+R".
var clicks := {}
## Level id -> {"used": the slot used last, "slots": [a route as plain data, or null]}.
var routes := {}
## Whether the next pull's spots are marked on the ground during a run.
var markers := true
## What is owned: items as rules/items.gd describes them, each with a number of its own.
var items: Array = []
var next_item := 1
## Teams of the player's own, as rules/teams.gd describes them, and the one the next run goes
## in with: 0 is the default team, 1 the first of these.
var teams: Array = []
var team := 0
## The three gear keys, by where they sit: the weapon's, the armour's and the trinket's.
var gear_keys: Array[int] = [KEY_Z, KEY_X, KEY_C]


func _init() -> void:
	for dungeon in Levels.DUNGEONS:
		progress_in(dungeon)
	for id in Heroes.ALL:
		Bindings.reset(self, id)


## How far you have got in a dungeon. Everyone starts at level 1.
func progress_in(dungeon: String) -> Dictionary:
	if not progress.has(dungeon):
		progress[dungeon] = {"unlocked": 1, "level": 1, "bests": {}, "timed": 0, "records": {}}
	return progress[dungeon]


## Records a finished run played as that hero, in the chosen dungeon or the one named. A run
## inside the time limit unlocks that dungeon's next level and may be a new best there; one
## over it changes nothing. Given the dungeon's time limit, a fast run opens more: two levels
## up a fifth inside the time, three levels two fifths inside. Given the crew ({"party",
## "slot"}), the best time at the level is kept with it. Returns how many levels were opened.
func record(run_level: int, hero_id: String, time: float, timed: bool, dungeon := "", time_limit := 0.0, crew := {}) -> int:
	if not timed:
		return 0
	var got := progress_in(dungeon if dungeon != "" else place)
	var before: int = got.unlocked
	var up := Items.levels_opened(time, time_limit) if time_limit > 0.0 else 1
	got.unlocked = maxi(got.unlocked, run_level + maxi(up, 1))
	got.timed = maxi(got.timed, run_level)
	var best: Dictionary = got.bests.get(hero_id, {})
	if best.is_empty() or run_level > best.level or (run_level == best.level and time < best.time):
		got.bests[hero_id] = {"level": run_level, "time": time}
	var was: Dictionary = got.records.get(str(run_level), {})
	if not crew.is_empty() and (was.is_empty() or time < was.time):
		got.records[str(run_level)] = {"time": time, "party": crew.party.duplicate(), "slot": crew.slot}
	return got.unlocked - before


## The best time at a level of the chosen dungeon, with who set it: {"time", "party", "slot"},
## or empty.
func record_at(run_level: int) -> Dictionary:
	return progress_in(place).records.get(str(run_level), {})


# ---------- gear

## The item with that number, or empty.
func item(id: int) -> Dictionary:
	for i: Dictionary in items:
		if id != 0 and i.id == id:
			return i
	return {}


## Whether the inventory has room for another.
func has_room() -> bool:
	return items.size() < Items.SPACE


## Puts an item in the inventory and gives it its number. False if there is no room.
func take(new_item: Dictionary) -> bool:
	if not has_room():
		return false
	new_item.id = next_item
	next_item += 1
	items.append(new_item)
	return true


## Throws an item out for good. It comes off every team that wore it.
func throw_out(id: int) -> void:
	items = items.filter(func(i: Dictionary) -> bool: return i.id != id)
	Teams.strip(self, id)


# ---------- routes

## Which of a level's slots was used last.
func route_slot(def: LevelDef) -> int:
	return routes.get(def.id, {}).get("used", 0)


## The route kept in one of a level's slots, or null if the slot is empty.
func route_in(def: LevelDef, at: int) -> Route:
	var slots: Array = routes.get(def.id, {}).get("slots", [])
	return Route.from_dict(slots[at], def) if at < slots.size() else null


## The route to run a level by: the one in the slot used last, or the level's own.
func route_for(def: LevelDef) -> Route:
	var kept := route_in(def, route_slot(def))
	return kept if kept else Route.default_for(def)


## Keeps a route in one of a level's slots and makes that the slot in use. Null empties it.
func keep_route(def: LevelDef, at: int, route: Route) -> void:
	if not routes.has(def.id):
		var empty := []
		empty.resize(SLOTS)
		routes[def.id] = {"used": 0, "slots": empty}
	routes[def.id].used = at
	routes[def.id].slots[at] = route.to_dict() if route else null


func use_slot(def: LevelDef, at: int) -> void:
	if routes.has(def.id):
		routes[def.id].used = at
	elif at != 0:
		keep_route(def, at, null)


func to_dict() -> Dictionary:
	return {"v": VERSION, "place": place, "progress": progress, "party": party, "slot": slot,
		"volume": volume, "muted": muted, "markers": markers, "keys": keys, "mouse": mouse, "clicks": clicks,
		"routes": routes, "items": items, "next_item": next_item, "teams": teams, "team": team, "gear_keys": gear_keys}


## The whole save as text, to be kept as a file.
func to_text() -> String:
	return JSON.stringify(to_dict(), "  ")


## A save read back from such text, or null if it is not one.
static func from_text(text: String) -> SaveData:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return from_dict(json.data) if json.data is Dictionary and json.data.has("v") else null


## Reads what it can from a dictionary and keeps the defaults for anything missing or wrong.
static func from_dict(d: Dictionary) -> SaveData:
	var s := SaveData.new()
	# before dungeons were told apart, everything was the Abbey's
	var kept: Variant = d.get("progress")
	if not kept is Dictionary:
		kept = {"abbey": d}
	for dungeon in Levels.DUNGEONS:
		var was: Variant = kept.get(dungeon)
		if not was is Dictionary:
			continue
		var got := s.progress_in(dungeon)
		got.unlocked = maxi(1, int(was.get("unlocked", 1)))
		got.level = clampi(int(was.get("level", 1)), 1, got.unlocked)
		var bests: Variant = was.get("bests", {})
		if bests is Dictionary:
			for id: String in bests:
				var b: Variant = bests[id]
				if Heroes.by_id(id) and b is Dictionary and b.has("level") and b.has("time"):
					got.bests[id] = {"level": int(b.level), "time": float(b.time)}
		# before records were kept, the highest level timed was always one below the unlocked
		got.timed = clampi(int(was.get("timed", got.unlocked - 1)), 0, got.unlocked - 1)
		var records: Variant = was.get("records", {})
		if records is Dictionary:
			for at: Variant in records:
				var r: Variant = records[at]
				if at is String and at.is_valid_int() and r is Dictionary and r.has("time") and _is_party(r.get("party")):
					got.records[at] = {"time": float(r.time), "party": r.party.duplicate(), "slot": clampi(int(r.get("slot", 3)), 0, 3)}
	if d.get("place") is String and Levels.DUNGEONS.has(d.place):
		s.place = d.place
	var party: Variant = d.get("party", [])
	if _is_party(party):
		s.party.assign(party)
	s.slot = clampi(int(d.get("slot", 3)), 0, 3)
	s.volume = clampf(float(d.get("volume", 0.8)), 0.0, 1.0)
	s.muted = d.get("muted", false) is bool and d.get("muted", false)
	s.markers = not (d.get("markers", true) is bool) or d.get("markers", true)
	s._read_bindings(d)
	s._read_routes(d)
	s._read_gear(d)
	return s


static func _is_party(party: Variant) -> bool:
	return party is Array and party.size() == 4 and party.all(func(id: Variant) -> bool: return id is String and Heroes.by_id(id) != null)


# Items are taken one at a time and given a number if theirs is missing or used twice; teams
# keep only what makes sense with the items that were read.
func _read_gear(d: Dictionary) -> void:
	var owned := {}
	var saved: Variant = d.get("items")
	if saved is Array:
		for raw: Variant in saved:
			var it := Items.read(raw)
			if it.is_empty() or items.size() >= Items.SPACE:
				continue
			if it.id <= 0 or owned.has(it.id):
				it.id = 0
			else:
				owned[it.id] = it
			items.append(it)
	next_item = maxi(1, int(d.get("next_item", 1)))
	for id: int in owned:
		next_item = maxi(next_item, id + 1)
	for it: Dictionary in items:
		if it.id == 0:
			it.id = next_item
			owned[it.id] = it
			next_item += 1
	var kept: Variant = d.get("teams")
	if kept is Array:
		for raw: Variant in kept:
			var t := Teams.read(raw, owned)
			if not t.is_empty() and teams.size() < Teams.MOST:
				teams.append(t)
	team = clampi(int(d.get("team", 0)), 0, teams.size())
	var codes: Variant = d.get("gear_keys")
	if codes is Array and codes.size() == 3:
		for i in 3:
			if codes[i] is int or codes[i] is float:
				gear_keys[i] = int(codes[i])
	# a key does one thing: an ability that already has one of these keeps it
	for hero_id: String in keys:
		for ab_id: String in keys[hero_id]:
			for code: int in keys[hero_id][ab_id]:
				if code != 0 and gear_keys.has(code):
					gear_keys[gear_keys.find(code)] = 0


# Routes are kept as plain data and read when they are wanted, since what makes sense in one
# depends on the level. Here only the shape is checked.
func _read_routes(d: Dictionary) -> void:
	var saved: Variant = d.get("routes")
	if not saved is Dictionary:
		return
	for id: Variant in saved:
		var entry: Variant = saved[id]
		if not id is String or not entry is Dictionary or not entry.get("slots") is Array:
			continue
		var slots := []
		slots.resize(SLOTS)
		for i in mini(SLOTS, entry.slots.size()):
			var route := Route.from_dict(entry.slots[i], null)
			if route and route.level == id:
				slots[i] = route.to_dict()
		var used: Variant = entry.get("used", 0)
		routes[id] = {"used": clampi(int(used), 0, SLOTS - 1) if used is int or used is float else 0, "slots": slots}


# Bindings are taken one ability at a time, so a save from before an ability existed, or with
# nonsense in it, still leaves every ability with something sensible.
func _read_bindings(d: Dictionary) -> void:
	for id in Heroes.ALL:
		var known := {}
		for ab in Heroes.by_id(id).abilities:
			known[ab.id] = ab
		var saved_keys: Variant = d.get("keys", {}).get(id) if d.get("keys") is Dictionary else null
		if saved_keys is Dictionary:
			for ab_id: String in saved_keys:
				var pair: Variant = saved_keys[ab_id]
				if known.has(ab_id) and pair is Array and pair.size() == 2:
					keys[id][ab_id] = [int(pair[0]), int(pair[1])]
		var saved_mouse: Variant = d.get("mouse", {}).get(id) if d.get("mouse") is Dictionary else null
		if saved_mouse is Dictionary:
			mouse[id] = {}
			for ab_id: String in saved_mouse:
				if known.has(ab_id) and saved_mouse[ab_id] in Bindings.MOUSE:
					mouse[id][ab_id] = saved_mouse[ab_id]
		var saved_clicks: Variant = d.get("clicks", {}).get(id) if d.get("clicks") is Dictionary else null
		if saved_clicks is Dictionary:
			clicks[id] = {}
			for ab_id: String in saved_clicks:
				if known.has(ab_id) and known[ab_id].target == "ally" and saved_clicks[ab_id] in Bindings.combos():
					clicks[id][ab_id] = saved_clicks[ab_id]
