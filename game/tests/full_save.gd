class_name FullSave
extends RefCounted

# The save with everything in it, for testing: every dungeon open to a high level, gear for
# four at the ceiling of several levels, one of every trinket, an epic with each ability, every
# set, every legendary, coin for the shop, and teams already dressed. It is
# kept in the repo as saves/fourfold-everything.txt and loaded in the game from Settings,
# "Load from a file". tests/tools/full_save.gd writes the file, and a test fails if the file
# no longer matches what is built here.
#
# When a milestone adds something a player has to earn (a dungeon, a kind of item, a rarity),
# add it here and write the file again.

## Where the file is kept, from the top of the repo.
const FILE := "saves/fourfold-everything.txt"
## The level every dungeon is open to: past every level at which something new begins.
const LEVEL := 20
## The dungeon levels gear is given for: four weapons and four armour at the ceiling of each.
const GEAR_FOR: Array[int] = [5, 10, 20]
## The item level of the trinkets, epics and set pieces: the ceiling of level 10.
const TRINKET_LEVEL := 32
## Coin enough for a good many gambles.
const COIN := 100000


static func path() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../" + FILE).simplify_path()


static func build() -> SaveData:
	var save := SaveData.new()
	for dungeon in Levels.DUNGEONS:
		var got := save.progress_in(dungeon)
		got.unlocked = LEVEL
		got.timed = LEVEL - 1

	# gear for four at each of the levels, one of each rarity and a second rare, named in turn
	# from each dungeon's words
	var tiers := {}
	for level in GEAR_FOR:
		tiers[level] = {"weapon": [], "armour": []}
		for slot: String in ["weapon", "armour"]:
			for i in 4:
				var words: Dictionary = Items.NAMES[Levels.DUNGEONS[i % Levels.DUNGEONS.size()]]
				var item := Items.plain(slot, Items.ceiling(level), [2, 2, 1, 0][i])
				item.name = "%s %s" % [words.first[(level + i * 3) % words.first.size()], words[slot][(level + i) % words[slot].size()]]
				item.from = Levels.DUNGEONS[i % Levels.DUNGEONS.size()]
				save.take(item)
				tiers[level][slot].append(item.id)
	var trinkets := {}
	for kind: String in Items.TRINKETS:
		var item := Items.trinket(kind, TRINKET_LEVEL)
		save.take(item)
		trinkets[kind] = item.id

	# teams: one with nothing on, one for each level of gear, and one for each dungeon's trinkets
	# with a pressed one on the hero you play
	_team(save, "Nothing worn", {}, [])
	for level in GEAR_FOR:
		_team(save, "Gear for level %d" % level, tiers[level], [])
	_team(save, "Abbey trinkets", tiers[10], [trinkets.great_key, trinkets.thimble, trinkets.tuning_fork, trinkets.bell_rope])
	_team(save, "Tollhaven trinkets", tiers[10], [trinkets.gutting_knife, trinkets.seal, trinkets.pitch_pot, trinkets.lens])

	# an epic with each ability, named from each dungeon in turn, and a second Lifelined to try
	# the unique rule with; the team has the two pressed ones on the hero you play
	var epics := {}
	for does: String in Items.ABILITIES:
		var dungeon: String = Levels.DUNGEONS[epics.size() % Levels.DUNGEONS.size()]
		var item := Items.epic(does, TRINKET_LEVEL, Items.NAMES[dungeon][Items.ABILITIES[does].slot][epics.size() + 1], dungeon)
		save.take(item)
		epics[does] = item.id
	save.take(Items.epic("lifelined", TRINKET_LEVEL, "Sea Cloak", "tollhaven"))
	var worn := _team(save, "Epic abilities", tiers[10], [])
	worn.gear[0].armour = epics.barnacled
	worn.gear[1].weapon = epics.forked
	worn.gear[1].armour = epics.lifelined
	worn.gear[2].weapon = epics.reaving
	worn.gear[3].weapon = epics.stormcalling
	worn.gear[3].armour = epics.bulwarked

	# every set, each on the hero it was made for
	var sets := {}
	for kind: String in Items.SETS:
		sets[kind] = {}
		for slot in Items.SLOTS:
			var item := Items.set_piece(kind, slot, TRINKET_LEVEL)
			save.take(item)
			sets[kind][slot] = item.id
	worn = _team(save, "The three sets", tiers[10], [])
	worn.gear[0] = sets.breakwater
	worn.gear[1] = sets.vigil
	worn.gear[3] = sets.wrecker

	# every legendary, and a team for each: the bell on the hero you play, to press
	var legends := {}
	for kind: String in Items.LEGENDARIES:
		var item := Items.legendary(kind, 1)
		save.take(item)
		legends[kind] = item.id
	for kind: String in Items.LEGENDARIES:
		worn = _team(save, Items.LEGENDARIES[kind].name, tiers[10], [])
		worn.gear[3][Items.LEGENDARIES[kind].slot] = legends[kind]
	save.coin = COIN
	return save


# A team of the usual four, played as the fourth. `tier` is {"weapon": four ids, "armour": four
# ids}, handed out in the default team's order; `trinkets` is an id for each hero in party order.
static func _team(save: SaveData, name: String, tier: Dictionary, trinkets: Array) -> Dictionary:
	var team := {"name": name, "party": ["warden", "mender", "duelist", "ranger"], "slot": 3, "gear": Teams.bare()}
	var turn := Teams.order(team.slot)
	for slot: String in tier:
		for i in 4:
			team.gear[turn[i]][slot] = tier[slot][i]
	for i in trinkets.size():
		team.gear[i].trinket = trinkets[i]
	save.teams.append(team)
	return team
