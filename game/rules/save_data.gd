class_name SaveData
extends RefCounted

# What is kept between runs: how far you have got, your best with each hero, and the party you
# last chose. Reading and writing the file is the scene's job (scripts/save_store.gd).

## The highest level you may start: one above your highest timed clear. Shared by all heroes.
var unlocked := 1
## Hero id -> {"level": highest level timed with that hero, "time": best time at it, in seconds}.
var bests := {}
var party: Array[String] = ["warden", "mender", "duelist", "ranger"]
var slot := 3
var level := 1
## How loud the game is, 0 to 1, and whether sound is off.
var volume := 0.8
var muted := false
## Hero id -> ability id -> [key, key]: two slots of physical keycodes, 0 for an empty one.
var keys := {}
## Hero id -> ability id -> "M", "X1" or "X2": a mouse button that casts it wherever the pointer is.
var mouse := {}
## Hero id -> ability id -> a click on a party frame, such as "L" or "S+R".
var clicks := {}


func _init() -> void:
	for id in Heroes.ALL:
		Bindings.reset(self, id)


## Records a finished run played as that hero. A run inside the time limit unlocks the next
## level and may be a new best; one over it changes nothing. Returns whether a level was unlocked.
func record(run_level: int, hero_id: String, time: float, timed: bool) -> bool:
	if not timed:
		return false
	var unlocked_now := false
	if run_level >= unlocked:
		unlocked = run_level + 1
		unlocked_now = true
	var best: Dictionary = bests.get(hero_id, {})
	if best.is_empty() or run_level > best.level or (run_level == best.level and time < best.time):
		bests[hero_id] = {"level": run_level, "time": time}
	return unlocked_now


func to_dict() -> Dictionary:
	return {"unlocked": unlocked, "bests": bests, "party": party, "slot": slot, "level": level,
		"volume": volume, "muted": muted, "keys": keys, "mouse": mouse, "clicks": clicks}


## Reads what it can from a dictionary and keeps the defaults for anything missing or wrong.
static func from_dict(d: Dictionary) -> SaveData:
	var s := SaveData.new()
	s.unlocked = maxi(1, int(d.get("unlocked", 1)))
	var bests: Variant = d.get("bests", {})
	if bests is Dictionary:
		for id: String in bests:
			var b: Variant = bests[id]
			if Heroes.by_id(id) and b is Dictionary and b.has("level") and b.has("time"):
				s.bests[id] = {"level": int(b.level), "time": float(b.time)}
	var party: Variant = d.get("party", [])
	if party is Array and party.size() == 4 and party.all(func(id: Variant) -> bool: return id is String and Heroes.by_id(id) != null):
		s.party.assign(party)
	s.slot = clampi(int(d.get("slot", 3)), 0, 3)
	s.level = clampi(int(d.get("level", 1)), 1, s.unlocked)
	s.volume = clampf(float(d.get("volume", 0.8)), 0.0, 1.0)
	s.muted = d.get("muted", false) == true
	s._read_bindings(d)
	return s


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
