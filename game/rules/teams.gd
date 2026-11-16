class_name Teams
extends RefCounted

# Teams, as rules on plain data. A team is who goes in and what each of them wears:
#   {"name", "party": four hero ids (tank, healer, two damage dealers), "slot": which of them
#    you play, "gear": for each of the four {"weapon": item id, "armour": item id,
#    "trinket": item id}, 0 for nothing}
# Items are things: one item is worn by one hero of a team, though any number of teams may use
# it. The default team is not kept anywhere: it is the crew chosen in the save wearing the best
# of what is owned, worked out afresh whenever it is asked for.

const DEFAULT_NAME := "The default team"
## Teams of the player's own that may be kept.
const MOST := 12


## An empty set of gear for four heroes.
static func bare() -> Array:
	var out := []
	for i in 4:
		out.append({"weapon": 0, "armour": 0, "trinket": 0})
	return out


## The order the best gear is handed out in: the hero you play, then the tank, the healer and
## the other damage dealers.
static func order(slot_played: int) -> Array[int]:
	var out: Array[int] = [slot_played]
	for i in 4:
		if i != slot_played:
			out.append(i)
	return out


## The best of what is owned, shared out: for each slot the best item to the hero you play,
## the next to the tank, and so on.
static func best_gear(items: Array, slot_played: int) -> Array:
	var out := bare()
	var turn := order(slot_played)
	for slot in Items.SLOTS:
		var mine := Items.of_slot(items, slot)
		for i in mini(4, mine.size()):
			out[turn[i]][slot] = mine[i].id
	return out


## The default team: the crew chosen in the save, wearing the best of what is owned.
static func default_team(save: SaveData) -> Dictionary:
	return {"name": DEFAULT_NAME, "party": save.party.duplicate(), "slot": save.slot, "gear": best_gear(save.items, save.slot)}


## The team at that place: 0 is the default team, 1 the first of the player's own.
static func at(save: SaveData, place: int) -> Dictionary:
	return save.teams[place - 1] if place >= 1 and place <= save.teams.size() else default_team(save)


## The team the next run goes in with.
static func in_use(save: SaveData) -> Dictionary:
	return at(save, save.team)


## What each of a team's four heroes wears, as items: {"weapon": item, "armour": item,
## "trinket": item}, empty for a slot with nothing in it or whose item is no longer owned.
static func worn(save: SaveData, team: Dictionary) -> Array:
	var out := []
	for i in 4:
		var on := {}
		for slot in Items.SLOTS:
			on[slot] = save.item(team.gear[i][slot])
		out.append(on)
	return out


## Which hero of a team wears that item: its place, or -1.
static func wearer(team: Dictionary, item_id: int) -> int:
	for i in 4:
		if item_id != 0 and item_id in team.gear[i].values():
			return i
	return -1


## Puts an item on a hero of a team, in the slot the item is for, or empties that slot with
## 0. An item worn by another hero of the team comes off them: one thing cannot be worn twice.
static func equip(save: SaveData, team: Dictionary, hero: int, slot: String, item_id: int) -> void:
	var item := save.item(item_id)
	if item_id != 0 and (item.is_empty() or item.slot != slot):
		return
	for i in 4:
		if item_id != 0 and team.gear[i][slot] == item_id:
			team.gear[i][slot] = 0
	team.gear[hero][slot] = item_id


## Dresses a team in the best of what is owned, as the default team is.
static func wear_best(save: SaveData, team: Dictionary) -> void:
	team.gear = best_gear(save.items, team.slot)


## Makes a team of the player's own from another (the default team included) and returns its
## place, or 0 if no more may be kept.
static func copy(save: SaveData, from: Dictionary) -> int:
	if save.teams.size() >= MOST:
		return 0
	var made: Dictionary = from.duplicate(true)
	var names := save.teams.map(func(t: Dictionary) -> String: return t.name)
	var n := save.teams.size() + 1
	while names.has("Team %d" % n):
		n += 1
	made.name = "Team %d" % n
	save.teams.append(made)
	return save.teams.size()


## Forgets one of the player's own teams. The team in use stays the one it was, or becomes
## the default if it was the one forgotten.
static func remove(save: SaveData, place: int) -> void:
	if place < 1 or place > save.teams.size():
		return
	save.teams.remove_at(place - 1)
	if save.team == place:
		save.team = 0
	elif save.team > place:
		save.team -= 1


## The names of the player's own teams that use an item, to warn with before it goes.
static func using(save: SaveData, item_id: int) -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in save.teams:
		if wearer(t, item_id) >= 0:
			out.append(t.name)
	return out


## Takes an item that is no longer owned off every team.
static func strip(save: SaveData, item_id: int) -> void:
	for t: Dictionary in save.teams:
		for on: Dictionary in t.gear:
			for slot: String in on:
				if on[slot] == item_id:
					on[slot] = 0


## A team read back from a save, made safe, or empty if it makes no sense. `owned` is item id
## -> item: gear that is not owned, or is in the wrong slot, or is worn twice, comes off.
static func read(d: Variant, owned: Dictionary) -> Dictionary:
	if not d is Dictionary:
		return {}
	var party: Variant = d.get("party")
	var choices := [Heroes.TANKS, Heroes.HEALERS, Heroes.DPS, Heroes.DPS]
	if not party is Array or party.size() != 4:
		return {}
	for i in 4:
		if not party[i] is String or not choices[i].has(party[i]):
			return {}
	var out := {"name": str(d.get("name", "Team")).left(24), "party": party.duplicate(), "slot": clampi(int(d.get("slot", 3)), 0, 3), "gear": bare()}
	var gear: Variant = d.get("gear")
	var seen := {}
	if gear is Array and gear.size() == 4:
		for i in 4:
			for slot in Items.SLOTS:
				var id: Variant = gear[i].get(slot, 0) if gear[i] is Dictionary else 0
				if (id is int or id is float) and owned.has(int(id)) and owned[int(id)].slot == slot and not seen.has(int(id)):
					out.gear[i][slot] = int(id)
					seen[int(id)] = true
	return out
