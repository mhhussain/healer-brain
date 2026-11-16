class_name Items
extends RefCounted

# Gear, as rules on plain data. An item is a Dictionary, so that it goes into the save as it is:
#   {"id": its number in the inventory, "slot": "weapon", "armour" or "trinket", "ilvl": its
#    item level, "rarity": 0 common, 1 uncommon or 2 rare, "name": what it is called,
#    "kind": which trinket it is (trinkets only), "from": the dungeon it came out of}
# A weapon raises damage and healing, armour raises health, and a trinket does one thing of its
# own. What a trinket does in a fight is in rules/combat.gd; what it is and how big is here.

const SLOTS: Array[String] = ["weapon", "armour", "trinket"]
const SLOT_NAMES := {"weapon": "Weapon", "armour": "Armour", "trinket": "Trinket"}
const RARITIES: Array[String] = ["Common", "Uncommon", "Rare"]
const RARITY_COLORS: Array[Color] = [Color("e8e4d8"), Color("6fd36f"), Color("5aa2f0")]
## How much more of its stat an item of each rarity gives.
const RARITY_MORE: Array[float] = [0.0, 0.05, 0.10]
## What one item level is worth: a hundredth more damage and healing, or health.
const PER_LEVEL := 0.01
## How many items the inventory holds.
const SPACE := 60
## The chance of each slot in the chest, and of each rarity before and from the level rares begin.
const SLOT_ODDS := {"weapon": 0.4, "armour": 0.4, "trinket": 0.2}
const RARE_FROM := 3
const RARITY_ODDS_EARLY: Array[float] = [0.7, 0.3, 0.0]
const RARITY_ODDS: Array[float] = [0.5, 0.35, 0.15]
## How fast a clear must be to open more than one level: a fifth inside the time opens two,
## two fifths inside opens three.
const FAST := [[0.6, 3], [0.8, 2], [1.0, 1]]

## The ten trinkets, five to a dungeon. "press" ones are used with the trinket key, on the
## cooldown given; the rest work by themselves. "base" is the number at item level 1, "per" what
## each level adds and "cap" where it stops; "words" says it with the number put in.
const TRINKETS := {
	"great_key": {"name": "Krogg's Great Key", "from": "abbey", "press": true, "cd": 90.0, "base": 0.30, "per": 0.005, "cap": 0.5,
		"words": "Press: you take %s less damage for 8 seconds. 90 second cooldown."},
	"thimble": {"name": "Velisse's Thimble", "from": "abbey", "press": false, "cd": 60.0, "base": 0.20, "per": 0.005, "cap": 1.0,
		"words": "When you fall below 35%% health, you are healed for %s of your health. Once a minute."},
	"bell_rope": {"name": "Sulmar's Bell Rope", "from": "abbey", "press": true, "cd": 120.0, "base": 0.10, "per": 0.003, "cap": 1.0,
		"words": "Press: everyone in the party hits and heals %s harder for 10 seconds. Two ropes do not add up. 2 minute cooldown."},
	"shell": {"name": "Brineling Shell", "from": "abbey", "press": false, "cd": 20.0, "base": 150.0, "per": 10.0, "cap": 99999.0,
		"words": "In a fight, every 20 seconds you are given a shield that soaks %s damage."},
	"tuning_fork": {"name": "Cantor's Tuning Fork", "from": "abbey", "press": false, "cd": 0.0, "base": 0.15, "per": 0.005, "cap": 1.0,
		"words": "After you silence a cast, you hit and heal %s harder for 8 seconds."},
	"gutting_knife": {"name": "Hask's Gutting Knife", "from": "tollhaven", "press": false, "cd": 0.0, "base": 60.0, "per": 6.0, "cap": 99999.0,
		"words": "Every sixth hit or heal of yours lands again for %s."},
	"seal": {"name": "Corrow's Seal", "from": "tollhaven", "press": true, "cd": 45.0, "base": 45.0, "per": -0.5, "cap": 25.0,
		"words": "Press: silences the cast of your target. %s second cooldown."},
	"pitch_pot": {"name": "Garrow's Pitch Pot", "from": "tollhaven", "press": true, "cd": 60.0, "base": 40.0, "per": 4.0, "cap": 99999.0,
		"words": "Press: burning pitch on your target and every enemy within 5 m of it, for %s damage a second for 8 seconds. 1 minute cooldown."},
	"lens": {"name": "The Keeper's Lens", "from": "tollhaven", "press": true, "cd": 90.0, "base": 0.50, "per": 0.01, "cap": 9.0,
		"words": "Press: your next three hits or heals are %s stronger. 90 second cooldown."},
	"tide_glass": {"name": "Tide Glass", "from": "tollhaven", "press": true, "cd": 120.0, "base": 0.30, "per": 0.01, "cap": 0.6,
		"words": "Press: gives you back %s of what your hero spends. 2 minute cooldown."},
}

## Names for weapons and armour, so that two can be told apart. The name is for show.
const NAMES := {
	"abbey": {
		"first": ["Sexton's", "Cantor's", "Prior's", "Novice's", "Bellringer's", "Almoner's", "Cellarer's", "Pilgrim's", "Choir", "Drowned", "Salt-stained", "Vesper"],
		"weapon": ["Hook", "Censer", "Crook", "Mace", "Candlestick", "Flail", "Bell Hammer", "Staff"],
		"armour": ["Cassock", "Habit", "Cowl", "Hauberk", "Scapular", "Mantle", "Surplice", "Sandals"],
	},
	"tollhaven": {
		"first": ["Chandler's", "Tallyman's", "Shipwright's", "Dredger's", "Harbourmaster's", "Netmender's", "Exciseman's", "Lamplighter's", "Tarred", "Brined", "Bonded", "Quayside"],
		"weapon": ["Maul", "Gaff", "Boathook", "Adze", "Marlinspike", "Cutlass", "Caulking Iron", "Harpoon"],
		"armour": ["Coat", "Oilskin", "Jerkin", "Sea Cloak", "Apron", "Brigandine", "Sou'wester", "Sea Boots"],
	},
}


## The highest item level a dungeon level gives.
static func ceiling(dungeon_level: int) -> int:
	return 2 + 3 * dungeon_level


## How many levels a timed clear opens: one, two for a fast one, three for a very fast one.
static func levels_opened(time: float, time_limit: float) -> int:
	for step: Array in FAST:
		if time <= time_limit * step[0]:
			return step[1]
	return 0


## The share a weapon adds to damage and healing, or armour to health: 0.22 is 22% more.
static func bonus(item: Dictionary) -> float:
	if item.is_empty() or item.slot == "trinket":
		return 0.0
	return item.ilvl * PER_LEVEL * (1.0 + RARITY_MORE[item.rarity])


## Whether a comes before b when the best is wanted: the higher item level, then the rarer.
static func better(a: Dictionary, b: Dictionary) -> bool:
	if a.ilvl != b.ilvl:
		return a.ilvl > b.ilvl
	if a.rarity != b.rarity:
		return a.rarity > b.rarity
	return a.id < b.id


## The items for one slot, best first.
static func of_slot(items: Array, slot: String) -> Array:
	var out := items.filter(func(i: Dictionary) -> bool: return i.slot == slot)
	out.sort_custom(better)
	return out


## What drops are measured against: the average of the best weapon and the best armour owned.
static func gear_level(items: Array) -> float:
	var sum := 0.0
	for slot: String in ["weapon", "armour"]:
		var mine := of_slot(items, slot)
		sum += mine[0].ilvl if not mine.is_empty() else 0
	return sum / 2.0


## The trinkets a dungeon's chest can hold.
static func trinkets_of(dungeon: String) -> Array[String]:
	var out: Array[String] = []
	for kind: String in TRINKETS:
		if TRINKETS[kind].from == dungeon:
			out.append(kind)
	return out


## The number a trinket works with at its item level.
static func amount(kind: String, ilvl: int) -> float:
	var t: Dictionary = TRINKETS[kind]
	var n: float = t.base + t.per * (ilvl - 1)
	return maxf(n, t.cap) if t.per < 0.0 else minf(n, t.cap)


## A trinket's cooldown at its item level: only Corrow's Seal's changes.
static func cooldown(item: Dictionary) -> float:
	return amount("seal", item.ilvl) if item.kind == "seal" else TRINKETS[item.kind].cd


## Whether an item is used with a key, not worn and forgotten.
static func pressed(item: Dictionary) -> bool:
	return not item.is_empty() and item.slot == "trinket" and TRINKETS[item.kind].press


## What an item does, in words, with its numbers in.
static func describe(item: Dictionary) -> String:
	match item.slot:
		"weapon": return "+%s%% damage and healing" % _trim(bonus(item) * 100.0)
		"armour": return "+%s%% health" % _trim(bonus(item) * 100.0)
	var n := amount(item.kind, item.ilvl)
	var shown := _trim(n * 100.0) + "%" if n < 10.0 and not item.kind in ["seal"] else _trim(n)
	return TRINKETS[item.kind].words % shown


## "Rare weapon, item level 12".
static func kind_words(item: Dictionary) -> String:
	return "%s %s, item level %d" % [RARITIES[item.rarity], SLOT_NAMES[item.slot].to_lower(), item.ilvl]


static func color(item: Dictionary) -> Color:
	return RARITY_COLORS[item.rarity]


static func _trim(n: float) -> String:
	return ("%.1f" % n).trim_suffix(".0")


# ---------- the chest

## What a finished run gives: two items, three if it was timed, made for that dungeon and
## level and for what is owned already. They have no id until they are taken.
static func chest(rng: RandomNumberGenerator, dungeon: String, dungeon_level: int, timed: bool, owned: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var have := gear_level(owned)
	for i in 3 if timed else 2:
		out.append(roll(rng, dungeon, dungeon_level, have))
	return out


## One item: its slot and rarity by the odds, its item level one to three above what is owned
## and never above the level's ceiling.
static func roll(rng: RandomNumberGenerator, dungeon: String, dungeon_level: int, have: float) -> Dictionary:
	var ilvl := clampi(floori(have) + rng.randi_range(1, 3), 1, ceiling(dungeon_level))
	var slot: String = SLOTS[_pick(rng, [SLOT_ODDS.weapon, SLOT_ODDS.armour, SLOT_ODDS.trinket])]
	if slot == "trinket":
		var kinds := trinkets_of(dungeon)
		return trinket(kinds[rng.randi_range(0, kinds.size() - 1)], ilvl)
	var rarity := _pick(rng, RARITY_ODDS if dungeon_level >= RARE_FROM else RARITY_ODDS_EARLY)
	var words: Dictionary = NAMES.get(dungeon, NAMES.abbey)
	var name := "%s %s" % [words.first[rng.randi_range(0, words.first.size() - 1)], words[slot][rng.randi_range(0, words[slot].size() - 1)]]
	return {"id": 0, "slot": slot, "ilvl": ilvl, "rarity": rarity, "name": name, "kind": "", "from": dungeon}


## A trinket of that kind and item level. Trinkets are always rare.
static func trinket(kind: String, ilvl: int) -> Dictionary:
	return {"id": 0, "slot": "trinket", "ilvl": ilvl, "rarity": 2, "name": TRINKETS[kind].name, "kind": kind, "from": TRINKETS[kind].from}


## A plain weapon or armour of that item level, for tests and the balance runner.
static func plain(slot: String, ilvl: int, rarity := 0) -> Dictionary:
	return {"id": 0, "slot": slot, "ilvl": ilvl, "rarity": rarity, "name": "Plain " + slot, "kind": "", "from": "abbey"}


static func _pick(rng: RandomNumberGenerator, odds: Array) -> int:
	var at := rng.randf()
	for i in odds.size():
		at -= odds[i]
		if at < 0.0:
			return i
	return odds.size() - 1


# ---------- reading a save

## An item read back from a save: itself, made safe, or empty if it makes no sense.
static func read(d: Variant) -> Dictionary:
	if not d is Dictionary or not d.get("slot") in SLOTS or not d.get("name") is String:
		return {}
	var kind: Variant = d.get("kind", "")
	if d.slot == "trinket" and not (kind is String and TRINKETS.has(kind)):
		return {}
	return {"id": int(d.get("id", 0)), "slot": d.slot, "ilvl": maxi(1, int(d.get("ilvl", 1))),
		"rarity": 2 if d.slot == "trinket" else clampi(int(d.get("rarity", 0)), 0, RARITIES.size() - 1),
		"name": d.name, "kind": kind if d.slot == "trinket" else "", "from": str(d.get("from", "abbey"))}
