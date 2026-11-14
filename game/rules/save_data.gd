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
	return {"unlocked": unlocked, "bests": bests, "party": party, "slot": slot, "level": level}


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
	return s
