class_name Items
extends RefCounted

# Gear, as rules on plain data. An item is a Dictionary, so that it goes into the save as it is:
#   {"id": its number in the inventory, "slot": "weapon", "armour" or "trinket", "ilvl": its
#    item level, "rarity": 0 common, 1 uncommon, 2 rare, 3 epic, 4 a set piece or 5 legendary,
#    "name": what it is called, "kind": what it does beyond its stat (which trinket it is, an
#    epic's ability, a set piece's set or which legendary; "" for the rest),
#    "from": the dungeon it came out of}
# A weapon raises damage and healing, armour raises health, and a trinket does one thing of its
# own. An epic weapon or armour carries an ability as well; a set's three pieces, worn by one
# hero, give that set's bonus; a legendary does something for the whole party. What each does
# in a fight is in rules/combat.gd; what it is and how big is here.

const SLOTS: Array[String] = ["weapon", "armour", "trinket"]
const SLOT_NAMES := {"weapon": "Weapon", "armour": "Armour", "trinket": "Trinket"}
const RARITIES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Set", "Legendary"]
const RARITY_COLORS: Array[Color] = [Color("e8e4d8"), Color("6fd36f"), Color("5aa2f0"), Color("b77bf2"), Color("f08a3c"), Color("f2c84b")]
const EPIC := 3
const SET := 4
const LEGENDARY := 5
## How much more of its stat an item of each rarity gives.
const RARITY_MORE: Array[float] = [0.0, 0.05, 0.10, 0.15, 0.15, 0.20]
## What one item level is worth: a hundredth more damage and healing, or health.
const PER_LEVEL := 0.01
## How many items the inventory holds.
const SPACE := 60
## The chance of each slot in the chest, and of each rarity before and from the level rares begin.
const SLOT_ODDS := {"weapon": 0.4, "armour": 0.4, "trinket": 0.2}
const RARE_FROM := 3
const RARITY_ODDS_EARLY: Array[float] = [0.7, 0.3, 0.0]
const RARITY_ODDS: Array[float] = [0.5, 0.35, 0.15]
## From the level epics and sets begin: common, uncommon, rare, epic, a set piece. A trinket
## from then on is a set's that often.
const EPIC_FROM := 7
const RARITY_ODDS_LATE: Array[float] = [0.35, 0.30, 0.20, 0.10, 0.05]
const SET_TRINKET_ODDS := 0.05
## From the level legendaries begin, a chest holds one this often, and that much oftener for
## each chest since the last that held none.
const LEGENDARY_FROM := 12
const LEGENDARY_ODDS := 0.02
const LEGENDARY_CREEP := 0.01
## A legendary counts as the highest item level owned, and this many more.
const LEGENDARY_ABOVE := 2
## What a finished run pays for each of its levels, and how much more of it a timed one pays.
const PAY := {"abbey": 10, "tollhaven": 20}
const TIMED_PAY := 1.5
## An item sells for its item level times this, by rarity. A legendary cannot be sold.
const SELLS: Array[int] = [1, 2, 4, 10, 15, 0]
## A gamble costs this for each level of the highest level finished in time.
const GAMBLE_COST := 50
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
	"gutting_knife": {"name": "Hask's Gutting Knife", "from": "tollhaven", "press": false, "cd": 0.0, "base": 60.0, "per": 3.0, "cap": 99999.0,
		"words": "Every sixth hit or heal of yours lands again for %s."},
	"seal": {"name": "Corrow's Seal", "from": "tollhaven", "press": true, "cd": 45.0, "base": 45.0, "per": -0.5, "cap": 25.0,
		"words": "Press: silences the cast of your target. %s second cooldown."},
	"pitch_pot": {"name": "Garrow's Pitch Pot", "from": "tollhaven", "press": true, "cd": 60.0, "base": 40.0, "per": 2.0, "cap": 99999.0,
		"words": "Press: burning pitch on your target and every enemy within 5 m of it, for %s damage a second for 8 seconds. 1 minute cooldown."},
	"lens": {"name": "The Keeper's Lens", "from": "tollhaven", "press": true, "cd": 90.0, "base": 0.50, "per": 0.01, "cap": 9.0,
		"words": "Press: your next three hits or heals are %s stronger. 90 second cooldown."},
	"tide_glass": {"name": "Tide Glass", "from": "tollhaven", "press": true, "cd": 120.0, "base": 0.30, "per": 0.01, "cap": 0.6,
		"words": "Press: gives you back %s of what your hero spends. 2 minute cooldown."},
}

## The six abilities an epic can carry, three for weapons and three for armour. Each is a
## share, not a number, so it is the same at every item level. "press" ones are used with the
## slot's key; "unique" ones may be worn once in a party. The item is named for its ability.
const ABILITIES := {
	"stormcalling": {"name": "Stormcalling", "slot": "weapon", "press": true, "cd": 60.0, "unique": false,
		"words": "Press: you hit and heal 25% harder for 10 seconds. 1 minute cooldown."},
	"reaving": {"name": "Reaving", "slot": "weapon", "press": false, "cd": 0.0, "unique": false,
		"words": "Your hits on an enemy below 30% health are 25% harder, and your heals on an ally below 30% are 25% stronger."},
	"forked": {"name": "Forked", "slot": "weapon", "press": false, "cd": 0.0, "unique": false,
		"words": "Each hit of yours strikes one other enemy within 6 m for 20% of it, and each heal of yours gives 20% of it to the most hurt other ally."},
	"bulwarked": {"name": "Bulwarked", "slot": "armour", "press": true, "cd": 90.0, "unique": false,
		"words": "Press: a shield that soaks 30% of your health, for 10 seconds. 90 second cooldown."},
	"barnacled": {"name": "Barnacled", "slot": "armour", "press": false, "cd": 0.0, "unique": false,
		"words": "An enemy that hits you takes 20% of the blow itself."},
	"lifelined": {"name": "Lifelined", "slot": "armour", "press": false, "cd": 180.0, "unique": true,
		"words": "A blow that would kill you leaves you at 1 health instead, with a shield of 20% of your health for 5 seconds. Once every 3 minutes. Unique: one to a party."},
}

## The three sets. Each is a weapon, armour and a trinket; the weapon and armour are as good as
## an epic's and carry no ability, and the trinket does nothing by itself. One hero wearing all
## three has the bonus.
const SETS := {
	"breakwater": {"name": "Breakwater", "weapon": "Breakwater Maul", "armour": "Breakwater Plate", "trinket": "Breakwater Charm",
		"words": "You take 5% less damage for each enemy attacking you beyond the second, to 25% at most."},
	"vigil": {"name": "Lamplighter's Vigil", "weapon": "Vigil Crook", "armour": "Vigil Habit", "trinket": "Vigil Lantern",
		"words": "An ally you heal hits 8% harder for 6 seconds."},
	"wrecker": {"name": "Wrecker's Due", "weapon": "Wrecker's Hook", "armour": "Wrecker's Coat", "trinket": "Wrecker's Tally",
		"words": "When an enemy you have hit dies, you hit 6% harder for 15 seconds. It stacks five times, to 30%."},
}

## The three legendaries, one to a slot. What each does is for the whole party, and a party
## wears only one.
const LEGENDARIES := {
	"vesper_bell": {"name": "The Last Vesper Bell", "slot": "trinket", "press": true, "cd": 180.0,
		"words": "Press: silences every cast in the fight that can be silenced, and every enemy in the fight takes 25% more damage for 10 seconds. 3 minute cooldown."},
	"tidecaller": {"name": "Tidecaller's Mantle", "slot": "armour", "press": false, "cd": 0.0,
		"words": "Once a fight, the first of the party to fall stands up again 3 seconds later, with half their health."},
	"undertow": {"name": "The Undertow", "slot": "weapon", "press": false, "cd": 0.0,
		"words": "For each pack in the fight beyond the first, the whole party hits and heals 6% harder, to 18% at most."},
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
## A legendary does not count: its item level follows the rest.
static func gear_level(items: Array) -> float:
	var sum := 0.0
	for slot: String in ["weapon", "armour"]:
		var mine := of_slot(items, slot).filter(func(i: Dictionary) -> bool: return i.rarity != LEGENDARY)
		sum += mine[0].ilvl if not mine.is_empty() else 0
	return sum / 2.0


## The highest item level owned, legendaries apart.
static func top_level(items: Array) -> int:
	var top := 0
	for i: Dictionary in items:
		if i.rarity != LEGENDARY:
			top = maxi(top, i.ilvl)
	return top


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


## The ability an epic weapon or armour carries, or "".
static func ability(item: Dictionary) -> String:
	return item.kind if not item.is_empty() and item.rarity == EPIC else ""


## Which legendary an item is, or "".
static func legend(item: Dictionary) -> String:
	return item.kind if not item.is_empty() and item.rarity == LEGENDARY else ""


## Whether only one of an item may be worn in a party.
static func unique(item: Dictionary) -> bool:
	return ability(item) != "" and ABILITIES[item.kind].unique


## The set a hero has the bonus of: the one all three things worn belong to, or "". `worn` is
## {"weapon": item, "armour": item, "trinket": item}.
static func set_of(worn: Dictionary) -> String:
	var first: Dictionary = worn.get("weapon", {})
	if first.is_empty() or first.rarity != SET:
		return ""
	for slot in SLOTS:
		var on: Dictionary = worn.get(slot, {})
		if on.is_empty() or on.rarity != SET or on.kind != first.kind:
			return ""
	return first.kind


## What an item does beyond its stat, as its entry in TRINKETS, ABILITIES or LEGENDARIES: empty
## for a plain item and for a set piece, which does nothing by itself.
static func _doing(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	match item.rarity:
		LEGENDARY: return LEGENDARIES[item.kind]
		EPIC: return ABILITIES[item.kind]
		SET: return {}
	return TRINKETS[item.kind] if item.slot == "trinket" else {}


## An item's cooldown: only Corrow's Seal's changes with its item level.
static func cooldown(item: Dictionary) -> float:
	if item.slot == "trinket" and item.rarity == 2 and item.kind == "seal":
		return amount("seal", item.ilvl)
	return _doing(item).get("cd", 0.0)


## Whether an item is used with a key, not worn and forgotten.
static func pressed(item: Dictionary) -> bool:
	return _doing(item).get("press", false)


## What a weapon or armour adds, in words: "+22% damage and healing". "" for a trinket.
static func stat_words(item: Dictionary) -> String:
	match item.slot:
		"weapon": return "+%s%% damage and healing" % _trim(bonus(item) * 100.0)
		"armour": return "+%s%% health" % _trim(bonus(item) * 100.0)
	return ""


## What an item does, in words, with its numbers in.
static func describe(item: Dictionary) -> String:
	var stat := stat_words(item)
	var lead := stat + ". " if stat != "" else ""
	match item.rarity:
		EPIC:
			return lead + ABILITIES[item.kind].words
		SET:
			var of: Dictionary = SETS[item.kind]
			return "%s%s (set): with the %s, the %s and the %s on one hero: %s" % [lead if stat != "" else "Does nothing by itself. ", of.name, of.weapon, of.armour, of.trinket, of.words]
		LEGENDARY:
			return lead + LEGENDARIES[item.kind].words + " Legendary: one to a party."
	if stat != "":
		return stat
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


# ---------- coin

## What a finished run pays, in coin.
static func pay(dungeon: String, dungeon_level: int, timed: bool) -> int:
	return roundi(PAY.get(dungeon, PAY.abbey) * dungeon_level * (TIMED_PAY if timed else 1.0))


## What an item sells for. Nothing for a legendary: it cannot be sold.
static func price(item: Dictionary) -> int:
	return item.ilvl * SELLS[item.rarity]


## What a gamble costs, given the highest level finished in time in any dungeon.
static func gamble_cost(timed_level: int) -> int:
	return GAMBLE_COST * maxi(1, timed_level)


## A gamble: one item for the slot chosen, made as a chest at the highest level finished in
## time would make it, from either dungeon. Never a legendary.
static func gamble(rng: RandomNumberGenerator, slot: String, timed_level: int, owned: Array) -> Dictionary:
	var dungeons: Array = NAMES.keys()
	return roll(rng, dungeons[rng.randi_range(0, dungeons.size() - 1)], maxi(1, timed_level), gear_level(owned), owned, slot)


# ---------- the chest

## What a finished run gives: two items, three if it was timed, made for that dungeon and
## level and for what is owned already. From the level legendaries begin, one of them may be
## a legendary not yet owned: `dry` is how many such chests have held none since the last.
## They have no id until they are taken.
static func chest(rng: RandomNumberGenerator, dungeon: String, dungeon_level: int, timed: bool, owned: Array, dry := 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var have := gear_level(owned)
	for i in 3 if timed else 2:
		out.append(roll(rng, dungeon, dungeon_level, have, owned + out))
	if dungeon_level >= LEGENDARY_FROM:
		var left := legendaries_left(owned)
		if not left.is_empty() and rng.randf() < legendary_odds(dry):
			out[out.size() - 1] = legendary(left[rng.randi_range(0, left.size() - 1)], top_level(owned) + LEGENDARY_ABOVE)
	return out


## The chance that a chest holds a legendary, after that many that held none.
static func legendary_odds(dry: int) -> float:
	return LEGENDARY_ODDS + LEGENDARY_CREEP * dry


## The legendaries not yet owned.
static func legendaries_left(owned: Array) -> Array[String]:
	var out: Array[String] = []
	for kind: String in LEGENDARIES:
		if not owned.any(func(i: Dictionary) -> bool: return i.rarity == LEGENDARY and i.kind == kind):
			out.append(kind)
	return out


## One item: its slot and rarity by the odds (or the slot asked for), its item level one to
## three above what is owned and never above the level's ceiling. `owned` is what there is
## already, so that a set piece is one still missing.
static func roll(rng: RandomNumberGenerator, dungeon: String, dungeon_level: int, have: float, owned: Array = [], slot := "") -> Dictionary:
	var ilvl := clampi(floori(have) + rng.randi_range(1, 3), 1, ceiling(dungeon_level))
	if slot == "":
		slot = SLOTS[_pick(rng, [SLOT_ODDS.weapon, SLOT_ODDS.armour, SLOT_ODDS.trinket])]
	var late := dungeon_level >= EPIC_FROM
	if slot == "trinket":
		if late and rng.randf() < SET_TRINKET_ODDS:
			var piece := _set_piece(rng, slot, ilvl, owned)
			if not piece.is_empty():
				return piece
		var kinds := trinkets_of(dungeon)
		return trinket(kinds[rng.randi_range(0, kinds.size() - 1)], ilvl)
	var rarity := _pick(rng, RARITY_ODDS_LATE if late else RARITY_ODDS if dungeon_level >= RARE_FROM else RARITY_ODDS_EARLY)
	if rarity == SET:
		var piece := _set_piece(rng, slot, ilvl, owned)
		if not piece.is_empty():
			return piece
		rarity = EPIC
	var words: Dictionary = NAMES.get(dungeon, NAMES.abbey)
	if rarity == EPIC:
		var does := ABILITIES.keys().filter(func(k: String) -> bool: return ABILITIES[k].slot == slot)
		return epic(does[rng.randi_range(0, does.size() - 1)], ilvl, words[slot][rng.randi_range(0, words[slot].size() - 1)], dungeon)
	var name := "%s %s" % [words.first[rng.randi_range(0, words.first.size() - 1)], words[slot][rng.randi_range(0, words[slot].size() - 1)]]
	return {"id": 0, "slot": slot, "ilvl": ilvl, "rarity": rarity, "name": name, "kind": "", "from": dungeon}


# A set piece for that slot that is not owned yet, or any of them once all nine are. Empty if
# every one for the slot is owned and others are still missing.
static func _set_piece(rng: RandomNumberGenerator, slot: String, ilvl: int, owned: Array) -> Dictionary:
	var has := func(kind: String, at: String) -> bool:
		return owned.any(func(i: Dictionary) -> bool: return i.rarity == SET and i.kind == kind and i.slot == at)
	var missing := SETS.keys().filter(func(k: String) -> bool: return not has.call(k, slot))
	if missing.is_empty():
		for kind: String in SETS:
			for at in SLOTS:
				if not has.call(kind, at):
					return {}
		missing = SETS.keys()
	return set_piece(missing[rng.randi_range(0, missing.size() - 1)], slot, ilvl)


## A trinket of that kind and item level. Trinkets are always rare.
static func trinket(kind: String, ilvl: int) -> Dictionary:
	return {"id": 0, "slot": "trinket", "ilvl": ilvl, "rarity": 2, "name": TRINKETS[kind].name, "kind": kind, "from": TRINKETS[kind].from}


## An epic with that ability, for the slot the ability is for: "Stormcalling Gaff".
static func epic(does: String, ilvl: int, noun := "", dungeon := "abbey") -> Dictionary:
	var slot: String = ABILITIES[does].slot
	return {"id": 0, "slot": slot, "ilvl": ilvl, "rarity": EPIC, "name": "%s %s" % [ABILITIES[does].name, noun if noun != "" else NAMES[dungeon][slot][0]], "kind": does, "from": dungeon}


## One of a set's three pieces.
static func set_piece(kind: String, slot: String, ilvl: int) -> Dictionary:
	return {"id": 0, "slot": slot, "ilvl": ilvl, "rarity": SET, "name": SETS[kind][slot], "kind": kind, "from": ""}


## A legendary. Its item level is not its own: the save keeps it at the highest owned, plus 2.
static func legendary(kind: String, ilvl: int) -> Dictionary:
	return {"id": 0, "slot": LEGENDARIES[kind].slot, "ilvl": maxi(1, ilvl), "rarity": LEGENDARY, "name": LEGENDARIES[kind].name, "kind": kind, "from": ""}


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

## An item read back from a save: itself, made safe, or empty if it makes no sense. A weapon
## or armour that claims an ability, a set or a legend there is not is kept as a rare one.
static func read(d: Variant) -> Dictionary:
	if not d is Dictionary or not d.get("slot") in SLOTS or not d.get("name") is String:
		return {}
	var kind: Variant = d.get("kind", "")
	var rarity := clampi(int(d.get("rarity", 0)), 0, RARITIES.size() - 1)
	var real := false
	if kind is String:
		match rarity:
			LEGENDARY: real = LEGENDARIES.has(kind) and LEGENDARIES[kind].slot == d.slot
			SET: real = SETS.has(kind)
			EPIC: real = ABILITIES.has(kind) and ABILITIES[kind].slot == d.slot
			_: real = d.slot == "trinket" and TRINKETS.has(kind)
	if not real:
		if d.slot == "trinket":
			return {}
		rarity = mini(rarity, 2)
		kind = ""
	elif rarity < EPIC:
		# a trinket is always rare
		rarity = 2
	return {"id": int(d.get("id", 0)), "slot": d.slot, "ilvl": maxi(1, int(d.get("ilvl", 1))),
		"rarity": rarity, "name": d.name, "kind": kind, "from": str(d.get("from", "abbey"))}
