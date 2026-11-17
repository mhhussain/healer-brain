extends GutTest

# The save with everything in it, kept in the repo for testing (saves/fourfold-everything.txt).
# It must load in the game as it is now and hold everything there is to earn.

const HOW := "write it again: godot --headless --path game -s tests/tools/full_save.gd"


func test_the_file_in_the_repo_is_the_one_built_now():
	assert_true(FileAccess.file_exists(FullSave.path()), "the file is missing; " + HOW)
	var kept := SaveData.from_text(FileAccess.get_file_as_string(FullSave.path()))
	assert_not_null(kept, "the file is not a save")
	if kept:
		assert_eq(kept.to_dict(), FullSave.build().to_dict(), "the file is out of date; " + HOW)


func test_it_holds_everything_there_is_to_earn():
	var save := FullSave.build()
	assert_eq(save.to_dict().v, SaveData.VERSION)
	for dungeon in Levels.DUNGEONS:
		assert_eq(save.progress_in(dungeon).unlocked, FullSave.LEVEL, dungeon)
	assert_gt(FullSave.LEVEL, 12, "past the last level at which a rarity begins")
	var kinds := save.items.filter(func(i: Dictionary) -> bool: return i.slot == "trinket").map(func(i: Dictionary) -> String: return i.kind)
	for kind: String in Items.TRINKETS:
		assert_has(kinds, kind)
	for rarity in Items.RARITIES.size():
		assert_true(save.items.any(func(i: Dictionary) -> bool: return i.rarity == rarity), Items.RARITIES[rarity])
	assert_true(save.has_room(), "with room left for what a chest gives")
	# reading it back changes nothing: every item and every team in it makes sense
	assert_eq(SaveData.from_text(save.to_text()).to_dict(), save.to_dict())
	assert_eq(Teams.in_use(save).name, Teams.DEFAULT_NAME)
	assert_eq(Items.top_level(save.items), Items.ceiling(FullSave.LEVEL))
	assert_eq(Teams.worn(save, Teams.in_use(save))[3].weapon.kind, "undertow", "the default team wears the best of it: a legendary, two above the rest")
	assert_eq(Teams.worn(save, Teams.in_use(save))[3].weapon.ilvl, Items.ceiling(FullSave.LEVEL) + 2)
	for does: String in Items.ABILITIES:
		assert_true(save.items.any(func(i: Dictionary) -> bool: return Items.ability(i) == does), does)
	for kind: String in Items.SETS:
		assert_eq(save.items.filter(func(i: Dictionary) -> bool: return i.rarity == Items.SET and i.kind == kind).size(), 3, kind)
	assert_true(Items.legendaries_left(save.items).is_empty(), "every legendary")
	assert_gt(save.coin, Items.gamble_cost(save.timed_level()) * 20, "coin for the shop")
	for team: Dictionary in save.teams:
		var worn := Teams.worn(save, team)
		for i in 4:
			for slot in Items.SLOTS:
				assert_eq(worn[i][slot].get("id", 0), team.gear[i][slot], "%s: what it wears is owned" % team.name)
	var pressed := save.teams.filter(func(t: Dictionary) -> bool: return Items.pressed(Teams.worn(save, t)[t.slot].trinket))
	assert_eq(pressed.size(), 3, "three teams have a trinket to press on the hero you play")
	var sets := save.teams.filter(func(t: Dictionary) -> bool: return t.name == "The three sets")[0] as Dictionary
	assert_eq(Teams.worn(save, sets).map(func(on: Dictionary) -> String: return Items.set_of(on)), ["breakwater", "vigil", "", "wrecker"])
