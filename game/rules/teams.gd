class_name Teams
extends RefCounted

# Teams, as rules on plain data. A team is who goes in and what each of them wears:
#   {"name", "party": four hero ids (tank, healer, two damage dealers), "slot": which of them
#    you play, "gear": for each of the four {"weapon": item id, "armour": item id,
#    "trinket": item id}, 0 for nothing}
# Items are things: one item is worn by one hero of a team, though any number of teams may use
# it. The default team is not kept anywhere: it is the crew chosen in the save wearing the best
# of what is owned, worked out afresh whenever it is asked for.
# A party wears one legendary, and one of anything unique.

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
## the next to the tank, and so on. Only one legendary is worn and one of anything unique, and
## a set's trinket is passed over: it does nothing without the rest, and sets are put together
## by hand.
static func best_gear(items: Array, slot_played: int) -> Array:
	var out := bare()
	var turn := order(slot_played)
	var legend := false
	var uniques := {}
	for slot in Items.SLOTS:
		var at := 0
		for item: Dictionary in Items.of_slot(items, slot):
			if at >= 4:
				break
			if item.rarity == Items.LEGENDARY:
				if legend:
					continue
				legend = true
			elif Items.unique(item):
				if uniques.has(item.kind):
					continue
				uniques[item.kind] = true
			elif item.rarity == Items.SET and slot == "trinket":
				continue
			out[turn[at]][slot] = item.id
			at += 1
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


## Why an item may not go on a hero of a team, to say to the player, or "" if it may: a party
## wears one legendary, and one of anything unique. What the hero wears in that slot now does
## not count, since the new item takes its place.
static func refusal(save: SaveData, team: Dictionary, hero: int, item: Dictionary) -> String:
	if item.is_empty() or (item.rarity != Items.LEGENDARY and not Items.unique(item)):
		return ""
	for i in 4:
		for slot in Items.SLOTS:
			var on := save.item(team.gear[i][slot])
			if on.is_empty() or on.id == item.id or (i == hero and slot == item.slot):
				continue
			var who := Heroes.by_id(team.party[i]).name
			if item.rarity == Items.LEGENDARY and on.rarity == Items.LEGENDARY:
				return "A party wears one legendary, and %s has %s." % [who, on.name]
			if Items.unique(item) and Items.unique(on) and on.kind == item.kind:
				return "%s is unique: one to a party, and %s has %s." % [Items.ABILITIES[item.kind].name, who, on.name]
	return ""


## Puts an item on a hero of a team, in the slot the item is for, or empties that slot with
## 0. An item worn by another hero of the team comes off them: one thing cannot be worn twice.
## Returns "" if it was done, or why it was not (see refusal).
static func equip(save: SaveData, team: Dictionary, hero: int, slot: String, item_id: int) -> String:
	var item := save.item(item_id)
	if item_id != 0 and (item.is_empty() or item.slot != slot):
		return "That does not go there."
	var why := refusal(save, team, hero, item)
	if why != "":
		return why
	for i in 4:
		if item_id != 0 and team.gear[i][slot] == item_id:
			team.gear[i][slot] = 0
	team.gear[hero][slot] = item_id
	return ""


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
## -> item: gear that is not owned, or is in the wrong slot, or is worn twice, comes off, and
## so does a second legendary or a second of anything unique.
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
				if not (id is int or id is float) or not owned.has(int(id)) or owned[int(id)].slot != slot or seen.has(int(id)):
					continue
				var item: Dictionary = owned[int(id)]
				var one: String = "legendary" if item.rarity == Items.LEGENDARY else item.kind if Items.unique(item) else ""
				if one != "" and seen.has(one):
					continue
				out.gear[i][slot] = int(id)
				seen[int(id)] = true
				seen[one] = true
	return out
