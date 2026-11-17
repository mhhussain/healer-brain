extends GutTest

# Milestone 13: rare gear and the shop. Epics and their six abilities, the three sets, the
# three legendaries, what is unique, what drops from which level, coin, selling and the gamble,
# and the screens for them.

const DT := 1.0 / 60.0
const TEMP_SAVE := "user://test-rare-save.json"

var combat: Combat
var pack: Pack
var events: Array[Dictionary]
var _saved_keys: SaveData


func before_all():
	SaveStore.path = TEMP_SAVE
	_saved_keys = Run.keys


func after_all():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	SaveStore.path = "user://fourfold-save.json"
	Run.keys = _saved_keys
	Run.place = "abbey"
	Run.party.assign(["warden", "mender", "duelist", "ranger"])
	Run.player_slot = 3
	Run.chosen_level = 1
	Run.autoplay = false
	Run.rng_seed = 0
	Run.gear = []
	get_tree().paused = false


func before_each():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	Run.keys = SaveData.new()
	Run.autoplay = false
	Run.place = "abbey"
	Run.gear = []
	get_tree().paused = false


## A run with those heroes in a row from the origin, the first of them wearing that, and one
## empty pack.
func start(hero_ids: Array, gear := {}, level := 1) -> Combatant:
	combat = Combat.new(level, 7)
	combat.endless = true
	combat.ai_plays = false
	events = []
	combat.event.connect(func(e: Dictionary) -> void: events.append(e))
	for i in hero_ids.size():
		var h := combat.add_hero(Heroes.by_id(hero_ids[i]), i == 0)
		h.pos = Vector3(-i * 1.5, 0, 0)
	combat.wear(combat.player, gear)
	pack = combat.add_pack()
	return combat.player


## An enemy of the first pack with health to spare.
func enemy(at: Vector3, in_pack := 0) -> Combatant:
	var e := combat.spawn_enemy("brute", at, in_pack)
	e.max_hp = 100000.0
	e.hp = e.max_hp
	return e


func run_for(seconds: float) -> void:
	for i in roundi(seconds / DT):
		combat.tick(DT)


func of(kind: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e.k == kind)


func casting(e: Combatant, interruptible := true) -> void:
	e.cast = Cast.new()
	e.cast.interruptible = interruptible
	e.cast.ab = EnemyAbility.new()
	e.cast.total = 30.0


func whole(kind: String, ilvl := 10) -> Dictionary:
	return {"weapon": Items.set_piece(kind, "weapon", ilvl), "armour": Items.set_piece(kind, "armour", ilvl), "trinket": Items.set_piece(kind, "trinket", ilvl)}


func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e


# ---------- what the rarer things are

func test_an_epic_a_set_piece_and_a_legendary_give_more_of_their_stat():
	assert_almost_eq(Items.bonus(Items.epic("forked", 20)), 0.23, 1e-6)
	assert_almost_eq(Items.bonus(Items.set_piece("vigil", "armour", 20)), 0.23, 1e-6)
	assert_almost_eq(Items.bonus(Items.legendary("undertow", 20)), 0.24, 1e-6)
	assert_eq(Items.bonus(Items.set_piece("vigil", "trinket", 20)), 0.0)
	assert_eq(Items.bonus(Items.legendary("vesper_bell", 20)), 0.0)


func test_every_rare_thing_has_a_name_a_slot_and_words():
	var weapons := 0
	for does: String in Items.ABILITIES:
		var item := Items.epic(does, 12, "Gaff")
		assert_eq(item.slot, Items.ABILITIES[does].slot)
		assert_eq(item.name, Items.ABILITIES[does].name + " Gaff")
		assert_string_contains(Items.describe(item), Items.ABILITIES[does].words)
		assert_string_contains(Items.describe(item), "+13.8%")
		assert_eq(Items.kind_words(item), "Epic %s, item level 12" % item.slot)
		weapons += 1 if item.slot == "weapon" else 0
	assert_eq(Items.ABILITIES.size(), 6)
	assert_eq(weapons, 3, "three for weapons and three for armour")
	assert_true(Items.pressed(Items.epic("stormcalling", 1)))
	assert_true(Items.pressed(Items.epic("bulwarked", 1)))
	assert_false(Items.pressed(Items.epic("forked", 1)))
	assert_eq(Items.cooldown(Items.epic("stormcalling", 1)), 60.0)
	assert_eq(Items.cooldown(Items.epic("bulwarked", 1)), 90.0)
	assert_true(Items.unique(Items.epic("lifelined", 1)))
	assert_false(Items.unique(Items.epic("barnacled", 1)))
	assert_eq(Items.SETS.size(), 3)
	for kind: String in Items.SETS:
		for slot in Items.SLOTS:
			var piece := Items.set_piece(kind, slot, 9)
			assert_eq(piece.name, Items.SETS[kind][slot])
			assert_string_contains(Items.describe(piece), Items.SETS[kind].words)
			assert_false(Items.pressed(piece))
		assert_string_contains(Items.describe(Items.set_piece(kind, "trinket", 9)), "Does nothing by itself")
	assert_eq(Items.LEGENDARIES.size(), 3)
	var slots := {}
	for kind: String in Items.LEGENDARIES:
		var item := Items.legendary(kind, 30)
		slots[item.slot] = true
		assert_string_contains(Items.describe(item), Items.LEGENDARIES[kind].words)
		assert_string_contains(Items.describe(item), "one to a party")
	assert_eq(slots.size(), 3, "one for each slot")
	assert_true(Items.pressed(Items.legendary("vesper_bell", 1)))
	assert_eq(Items.cooldown(Items.legendary("vesper_bell", 1)), 180.0)


func test_a_set_is_whole_when_one_hero_wears_all_three():
	assert_eq(Items.set_of(whole("vigil")), "vigil")
	var two := whole("vigil")
	two.trinket = Items.trinket("lens", 5)
	assert_eq(Items.set_of(two), "")
	var mixed := whole("vigil")
	mixed.armour = Items.set_piece("wrecker", "armour", 5)
	assert_eq(Items.set_of(mixed), "")
	assert_eq(Items.set_of({}), "")
	assert_eq(Items.set_of({"weapon": Items.plain("weapon", 3)}), "")


func test_the_pitch_pot_and_the_gutting_knife_grow_half_as_fast():
	assert_eq(Items.amount("pitch_pot", 1), 40.0)
	assert_eq(Items.amount("pitch_pot", 11), 60.0)
	assert_eq(Items.amount("gutting_knife", 1), 60.0)
	assert_eq(Items.amount("gutting_knife", 11), 90.0)


# ---------- what drops

func test_epics_and_set_pieces_begin_at_level_seven():
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 400:
		var early := Items.roll(rng, "abbey", 6, 10.0)
		assert_lt(early.rarity, Items.EPIC, "nothing rarer than rare below level 7")
	var seen := [0, 0, 0, 0, 0, 0]
	var set_trinkets := 0
	var trinkets := 0
	for i in 4000:
		var item := Items.roll(rng, "tollhaven", 7, 10.0)
		assert_between(item.ilvl, 11, 13)
		if item.slot == "trinket":
			trinkets += 1
			set_trinkets += 1 if item.rarity == Items.SET else 0
			continue
		seen[item.rarity] += 1
		if item.rarity == Items.EPIC:
			assert_eq(Items.ABILITIES[item.kind].slot, item.slot)
			assert_true(item.name.begins_with(Items.ABILITIES[item.kind].name + " "))
			assert_true(Items.NAMES.tollhaven[item.slot].has(item.name.trim_prefix(Items.ABILITIES[item.kind].name + " ")))
	var gear: int = seen[0] + seen[1] + seen[2] + seen[3] + seen[4]
	assert_eq(seen[5], 0, "a roll is never a legendary")
	assert_almost_eq(seen[0] / float(gear), 0.35, 0.04)
	assert_almost_eq(seen[1] / float(gear), 0.30, 0.04)
	assert_almost_eq(seen[2] / float(gear), 0.20, 0.04)
	assert_almost_eq(seen[3] / float(gear), 0.10, 0.03)
	assert_almost_eq(seen[4] / float(gear), 0.05, 0.03)
	assert_almost_eq(set_trinkets / float(trinkets), 0.05, 0.03)


func test_a_set_piece_is_one_you_do_not_own_until_you_own_all_nine():
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var owned: Array = []
	# every set piece that comes is a new one, until there are nine
	for i in 20000:
		var item := Items.roll(rng, "abbey", 9, 5.0, owned)
		if item.rarity != Items.SET or owned.size() == 9:
			continue
		assert_false(owned.any(func(o: Dictionary) -> bool: return o.kind == item.kind and o.slot == item.slot), "%s twice" % item.name)
		owned.append(item)
	assert_eq(owned.size(), 9)
	# with all nine, they come again
	var again := 0
	for i in 3000:
		again += 1 if Items.roll(rng, "abbey", 9, 5.0, owned).rarity == Items.SET else 0
	assert_gt(again, 30)
	# two in one chest are not the same piece either
	for i in 300:
		var chest := Items.chest(rng, "abbey", 9, true, [])
		var pieces := chest.filter(func(o: Dictionary) -> bool: return o.rarity == Items.SET).map(func(o: Dictionary) -> String: return o.name)
		for name: String in pieces:
			assert_eq(pieces.count(name), 1)


func test_a_legendary_comes_from_level_twelve_and_likelier_each_chest_without():
	assert_almost_eq(Items.legendary_odds(0), 0.02, 1e-6)
	assert_almost_eq(Items.legendary_odds(10), 0.12, 1e-6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var owned: Array = [Items.plain("weapon", 30), Items.plain("armour", 20)]
	for i in 200:
		assert_false(Items.chest(rng, "abbey", 11, true, owned, 98).any(func(o: Dictionary) -> bool: return o.rarity == Items.LEGENDARY), "never below level 12")
	var got := 0
	for i in 3000:
		got += 1 if Items.chest(rng, "abbey", 12, true, owned).any(func(o: Dictionary) -> bool: return o.rarity == Items.LEGENDARY) else 0
	assert_almost_eq(got / 3000.0, 0.02, 0.012)
	# with the odds at their top, it is there, in place of the last thing, at the highest owned plus 2
	var sure := Items.chest(rng, "tollhaven", 12, false, owned, 98)
	assert_eq(sure.size(), 2)
	assert_eq(sure[1].rarity, Items.LEGENDARY)
	assert_eq(sure[1].ilvl, 32)
	# never one that is owned, and none at all once all three are
	owned.append(Items.legendary("undertow", 1))
	owned.append(Items.legendary("tidecaller", 1))
	assert_eq(Items.legendaries_left(owned), ["vesper_bell"] as Array[String])
	for i in 20:
		assert_eq(Items.chest(rng, "abbey", 15, false, owned, 98)[1].kind, "vesper_bell")
	owned.append(Items.legendary("vesper_bell", 1))
	for i in 50:
		assert_false(Items.chest(rng, "abbey", 15, true, owned, 98).any(func(o: Dictionary) -> bool: return o.rarity == Items.LEGENDARY))


# ---------- coin

func test_a_run_pays_by_its_level_and_more_in_time():
	assert_eq(Items.pay("abbey", 1, false), 10)
	assert_eq(Items.pay("abbey", 10, false), 100)
	assert_eq(Items.pay("abbey", 10, true), 150)
	assert_eq(Items.pay("tollhaven", 10, false), 200)
	assert_eq(Items.pay("tollhaven", 7, true), 210)


func test_an_item_sells_by_its_level_and_rarity_and_a_legendary_not_at_all():
	assert_eq(Items.price(Items.plain("weapon", 12)), 12)
	assert_eq(Items.price(Items.plain("weapon", 12, 1)), 24)
	assert_eq(Items.price(Items.plain("armour", 12, 2)), 48)
	assert_eq(Items.price(Items.trinket("lens", 12)), 48)
	assert_eq(Items.price(Items.epic("forked", 12)), 120)
	assert_eq(Items.price(Items.set_piece("vigil", "trinket", 12)), 180)
	assert_eq(Items.price(Items.legendary("undertow", 12)), 0)
	var save := SaveData.new()
	save.take(Items.plain("weapon", 12, 1))
	save.take(Items.legendary("undertow", 1))
	save.team = Teams.copy(save, Teams.in_use(save))
	assert_eq(Teams.in_use(save).gear[3].weapon, 2)
	Teams.equip(save, Teams.in_use(save), 0, "weapon", 1)
	assert_eq(save.sell(2), 0, "a legendary cannot be sold")
	assert_eq(save.items.size(), 2)
	assert_eq(save.sell(1), 24)
	assert_eq(save.coin, 24)
	assert_eq(save.items.size(), 1)
	assert_eq(Teams.in_use(save).gear[0].weapon, 0, "and it comes off the team that wore it")
	assert_eq(save.sell(99), 0)


func test_a_gamble_costs_by_the_highest_level_timed_and_gives_one_item_for_the_slot():
	assert_eq(Items.gamble_cost(0), 50)
	assert_eq(Items.gamble_cost(10), 500)
	var save := SaveData.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	assert_true(save.gamble(rng, "weapon").is_empty(), "no coin, no gamble")
	save.progress_in("abbey").timed = 3
	save.progress_in("tollhaven").timed = 8
	assert_eq(save.timed_level(), 8)
	save.take(Items.plain("weapon", 20))
	save.take(Items.plain("armour", 20))
	save.coin = 400 * 300 + 399
	var kinds := {}
	var rarest := 0
	for i in 100:
		for slot in Items.SLOTS:
			var got := save.gamble(rng, slot)
			assert_eq(got.slot, slot)
			assert_between(got.ilvl, 21, 23)
			assert_ne(got.rarity, Items.LEGENDARY)
			assert_eq(save.item(got.id), got, "it is in the inventory")
			rarest = maxi(rarest, got.rarity)
			if slot == "trinket" and got.rarity == 2:
				kinds[got.kind] = true
			save.throw_out(got.id)
	assert_eq(save.coin, 399)
	assert_eq(kinds.size(), 10, "a trinket may be any of the ten")
	assert_gte(rarest, Items.EPIC, "the odds are those of a chest at that level")
	assert_true(save.gamble(rng, "armour").is_empty(), "not enough left")
	# never above the ceiling of the highest level timed
	save.take(Items.plain("weapon", 40))
	save.take(Items.plain("armour", 40))
	save.coin = 400
	assert_eq(save.gamble(rng, "weapon").ilvl, Items.ceiling(8))
	# and not without room
	save.coin = 4000
	while save.has_room():
		save.take(Items.plain("weapon", 1))
	assert_true(save.gamble(rng, "weapon").is_empty())
	assert_eq(save.coin, 4000)


# ---------- the save

func test_a_legendary_is_kept_two_above_the_highest_owned():
	var save := SaveData.new()
	save.take(Items.legendary("tidecaller", 50))
	assert_eq(save.items[0].ilvl, 2, "with nothing else, 0 and 2")
	save.take(Items.plain("weapon", 14))
	assert_eq(save.items[0].ilvl, 16)
	save.take(Items.trinket("lens", 21))
	assert_eq(save.items[0].ilvl, 23)
	save.take(Items.legendary("undertow", 1))
	assert_eq(save.items[3].ilvl, 23, "another legendary does not lift it")
	save.throw_out(3)
	assert_eq(save.items[0].ilvl, 16)
	assert_eq(Items.gear_level(save.items), 7.0, "and a legendary is not what drops are measured against")
	assert_eq(Items.top_level(save.items), 14)


func test_coin_and_rare_gear_survive_the_file_and_back():
	var save := SaveData.new()
	save.take(Items.epic("lifelined", 12, "Cowl"))
	save.take(Items.set_piece("wrecker", "trinket", 9))
	save.take(Items.legendary("vesper_bell", 1))
	save.coin = 1234
	save.dry = 7
	save.team = Teams.copy(save, Teams.in_use(save))
	var back := SaveData.from_text(save.to_text())
	assert_eq(back.to_dict(), save.to_dict())
	assert_eq(back.coin, 1234)
	assert_eq(back.dry, 7)
	assert_eq(back.items[2].ilvl, 14)
	assert_eq(back.to_dict().v, 5)
	# a save from before coin has none
	var old := SaveData.from_dict({"v": 4, "items": [{"id": 1, "slot": "weapon", "name": "Hook", "ilvl": 4, "rarity": 1}]})
	assert_eq(old.coin, 0)
	assert_eq(old.dry, 0)
	assert_eq(old.items.size(), 1)


func test_damaged_rare_gear_in_a_save_does_no_harm():
	var d := SaveData.new().to_dict()
	d["coin"] = "lots"
	d["dry"] = -4
	d["items"] = [
		{"id": 1, "slot": "weapon", "name": "No such ability", "ilvl": 9, "rarity": 3, "kind": "singing"},
		{"id": 2, "slot": "weapon", "name": "Armour's ability", "ilvl": 9, "rarity": 3, "kind": "barnacled"},
		{"id": 3, "slot": "trinket", "name": "No such set", "ilvl": 9, "rarity": 4, "kind": "nothing"},
		{"id": 4, "slot": "armour", "name": "The bell is no armour", "ilvl": 9, "rarity": 5, "kind": "vesper_bell"},
		{"id": 5, "slot": "trinket", "name": "The Last Vesper Bell", "ilvl": 99, "rarity": 5, "kind": "vesper_bell"},
		{"id": 6, "slot": "trinket", "name": "The Last Vesper Bell", "ilvl": 99, "rarity": 5, "kind": "vesper_bell"},
		{"id": 7, "slot": "armour", "name": "Lifelined Cowl", "ilvl": 9, "rarity": 3, "kind": "lifelined"},
		{"id": 8, "slot": "armour", "name": "Lifelined Habit", "ilvl": 9, "rarity": 3, "kind": "lifelined"},
		{"id": 9, "slot": "weapon", "name": "The Undertow", "ilvl": 1, "rarity": 5, "kind": "undertow"},
	]
	d["teams"] = [{"name": "Too much", "party": ["warden", "mender", "duelist", "ranger"], "slot": 3,
		"gear": [{"weapon": 9, "armour": 7}, {"armour": 8, "trinket": 5}, {}, {}]}]
	var s := SaveData.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_eq(s.coin, 0)
	assert_eq(s.dry, 0)
	assert_eq(s.items.map(func(i: Dictionary) -> int: return i.id), [1, 2, 4, 5, 7, 8, 9], "the trinket of no set is dropped, and the second bell")
	assert_eq(s.item(1).rarity, 2, "a weapon with an ability there is not is kept as a rare one")
	assert_eq(s.item(2).kind, "")
	assert_eq(s.item(4).rarity, 2)
	assert_eq(s.item(5).ilvl, 11, "and a legendary's item level is put right")
	assert_eq(s.teams[0].gear[0], {"weapon": 9, "armour": 7, "trinket": 0})
	assert_eq(s.teams[0].gear[1], {"weapon": 0, "armour": 0, "trinket": 0}, "a second Lifelined and a second legendary come off")


# ---------- teams

func test_a_party_wears_one_legendary_and_one_of_anything_unique():
	var save := SaveData.new()
	for item: Dictionary in [Items.legendary("undertow", 1), Items.legendary("tidecaller", 1), Items.legendary("vesper_bell", 1),
			Items.epic("lifelined", 9, "Cowl"), Items.epic("lifelined", 8, "Habit"), Items.epic("barnacled", 7), Items.epic("barnacled", 6), Items.plain("weapon", 5)]:
		save.take(item)
	save.teams.append({"name": "Mine", "party": ["warden", "mender", "duelist", "ranger"], "slot": 3, "gear": Teams.bare()})
	var team: Dictionary = save.teams[0]
	assert_eq(Teams.equip(save, team, 0, "weapon", 1), "")
	var why := Teams.equip(save, team, 1, "armour", 2)
	assert_string_contains(why, "one legendary")
	assert_string_contains(why, "The Undertow")
	assert_string_contains(why, Heroes.by_id("warden").name)
	assert_eq(team.gear[1].armour, 0)
	assert_string_contains(Teams.equip(save, team, 0, "trinket", 3), "one legendary", "nor a second on the same hero")
	assert_eq(Teams.equip(save, team, 2, "weapon", 1), "", "the one worn may move to another hero")
	assert_eq(team.gear[0].weapon, 0)
	assert_eq(Teams.equip(save, team, 2, "weapon", 8), "", "and once it is off")
	assert_eq(Teams.equip(save, team, 1, "armour", 2), "", "another may go on")
	assert_eq(Teams.equip(save, team, 0, "armour", 4), "")
	why = Teams.equip(save, team, 3, "armour", 5)
	assert_string_contains(why, "Lifelined is unique")
	assert_eq(team.gear[3].armour, 0)
	assert_eq(Teams.equip(save, team, 0, "armour", 5), "", "one Lifelined may take the place of the other")
	assert_eq(Teams.equip(save, team, 2, "armour", 6), "")
	assert_eq(Teams.equip(save, team, 3, "armour", 7), "", "what is not unique may be worn twice")
	assert_eq(Teams.equip(save, team, 3, "weapon", 6), "That does not go there.")


func test_the_default_team_wears_one_legendary_one_lifelined_and_no_lone_set_trinket():
	var save := SaveData.new()
	for item: Dictionary in [Items.plain("weapon", 30), Items.plain("armour", 30), Items.epic("lifelined", 29, "Cowl"), Items.epic("lifelined", 28, "Habit"),
			Items.plain("armour", 5), Items.plain("armour", 4), Items.set_piece("vigil", "trinket", 31), Items.trinket("lens", 3),
			Items.legendary("undertow", 1), Items.legendary("tidecaller", 1), Items.legendary("vesper_bell", 1), Items.set_piece("vigil", "weapon", 20)]:
		save.take(item)
	var worn := Teams.worn(save, Teams.default_team(save))
	assert_eq(worn[3].weapon.kind, "undertow", "the hero you play has the legendary")
	assert_eq(worn[0].weapon.ilvl, 30)
	assert_eq(worn[1].weapon.name, "Vigil Crook", "a set's weapon is as good as any")
	assert_eq(worn[3].armour.ilvl, 30, "and no second legendary is worn")
	assert_eq(worn[0].armour.name, "Lifelined Cowl")
	assert_eq(worn[1].armour.ilvl, 5, "nor a second Lifelined")
	assert_eq(worn[2].armour.ilvl, 4)
	assert_eq(worn[3].trinket.kind, "lens", "nor a set's trinket by itself, nor the bell")
	assert_true(worn[0].trinket.is_empty())


# ---------- the six abilities

func test_stormcalling_is_pressed_for_a_quarter_more_for_ten_seconds():
	var h := start(["ranger", "warden"], {"weapon": Items.epic("stormcalling", 20)})
	var e := enemy(Vector3(3, 0, 0))
	assert_eq(h.weapon_does, "stormcalling")
	assert_almost_eq(combat.damage(h, e, 100.0), 123.0, 0.5, "an epic of item level 20")
	assert_eq(combat.gear_state(h, 0).cd_max, 60.0)
	assert_true(combat.gear_state(h, 1).is_empty())
	assert_eq(combat.use_gear(h, 0), "")
	assert_almost_eq(combat.damage(h, e, 100.0), 123.0 * 1.25, 0.6)
	var ally := combat.heroes[1]
	ally.hp = 100.0
	assert_almost_eq(combat.heal(h, ally, 100.0), 123.0 * 1.25, 0.6)
	assert_eq(combat.use_gear(h, 0), "cd")
	assert_eq(of("gear").size(), 1)
	run_for(10.1)
	assert_almost_eq(combat.damage(h, e, 100.0), 123.0, 0.5)
	assert_almost_eq(combat.gear_state(h, 0).cd, 49.9, 0.2)
	run_for(50.0)
	assert_eq(combat.use_gear(h, 0), "")
	assert_eq(combat.use_gear(h, 1), "Nothing to use")


func test_reaving_is_harder_on_whoever_is_nearly_done_for():
	var h := start(["mender", "warden"], {"weapon": Items.epic("reaving", 1)})
	h.power = 1.0
	var e := enemy(Vector3(3, 0, 0))
	assert_eq(combat.damage(h, e, 100.0), 100.0)
	e.hp = e.max_hp * 0.29
	assert_eq(combat.damage(h, e, 100.0), 125.0)
	assert_eq(combat.damage(h, e, 100.0, "magic", {"raw": true}), 100.0)
	var ally := combat.heroes[1]
	ally.hp = ally.max_hp * 0.5
	assert_eq(combat.heal(h, ally, 100.0), 100.0)
	ally.hp = ally.max_hp * 0.2
	assert_eq(combat.heal(h, ally, 100.0), 125.0)


func test_forked_gives_a_fifth_to_another():
	var h := start(["ranger", "warden", "mender"], {"weapon": Items.epic("forked", 1)})
	h.power = 1.0
	var a := enemy(Vector3(6, 0, 0))
	var near := enemy(Vector3(9, 0, 0))
	var nearer := enemy(Vector3(8, 0, 0))
	var far := enemy(Vector3(16, 0, 0))
	combat.add_pack()
	var asleep := enemy(Vector3(5, 0, 0), 1)
	for e: Combatant in [a, near, nearer, far]:
		e.engaged = true
	assert_eq(combat.damage(h, a, 200.0), 200.0)
	assert_eq(nearer.max_hp - nearer.hp, 40.0, "the nearest other enemy in the fight")
	assert_eq(near.max_hp - near.hp, 0.0)
	assert_eq(far.max_hp - far.hp, 0.0)
	assert_eq(asleep.max_hp - asleep.hp, 0.0, "and it wakes nothing")
	assert_eq(a.max_hp - a.hp, 200.0, "what forks does not fork again")
	assert_eq(h.stats.dmg, 240.0)
	combat.damage(h, a, 200.0, "magic", {"tick": true})
	assert_eq(nearer.max_hp - nearer.hp, 40.0, "the tick of a lasting effect is no hit")
	combat.damage(h, far, 200.0)
	assert_eq(far.max_hp - far.hp, 200.0, "with no one within 6 m, nothing forks")
	# heals: a fifth to the most hurt other ally
	var tank := combat.heroes[1]
	var healer := combat.heroes[2]
	tank.hp = tank.max_hp - 500.0
	healer.hp = healer.max_hp * 0.5
	h.hp = h.max_hp - 10.0
	assert_eq(combat.heal(h, tank, 100.0), 100.0)
	assert_eq(healer.hp, healer.max_hp * 0.5 + 20.0)
	assert_eq(h.hp, h.max_hp - 10.0)
	healer.hp = healer.max_hp
	combat.heal(h, tank, 100.0)
	assert_eq(h.hp, h.max_hp, "what is left over is not carried")


func test_bulwarked_is_pressed_for_a_shield_of_three_tenths():
	var h := start(["warden"], {"armour": Items.epic("bulwarked", 1)})
	var e := enemy(Vector3(2, 0, 0))
	assert_eq(combat.gear_state(h, 1).item.kind, "bulwarked")
	assert_eq(combat.use_gear(h, 1), "")
	assert_eq(h.armour_cd, 90.0)
	var full := h.hp
	var shield := roundf(h.max_hp * 0.3)
	combat.damage(e, h, shield - 10.0)
	assert_eq(h.hp, full, "soaked")
	combat.damage(e, h, 110.0)
	assert_eq(h.hp, full - 100.0, "and then it is spent")
	h.armour_cd = 0.0
	combat.use_gear(h, 1)
	run_for(10.1)
	assert_false(combat.has_aura(h, "bulwarked"), "it lasts ten seconds")


func test_barnacled_gives_the_attacker_a_fifth_of_the_blow():
	var h := start(["warden"], {"armour": Items.epic("barnacled", 1)})
	var e := enemy(Vector3(2, 0, 0))
	combat.damage(e, h, 200.0)
	assert_eq(e.max_hp - e.hp, 40.0)
	assert_eq(h.stats.dmg, 40.0)
	combat.add_aura(h, {"id": "ward", "dur": 5.0, "absorb": 1000.0})
	combat.damage(e, h, 200.0)
	assert_eq(e.max_hp - e.hp, 80.0, "a shield takes nothing from it")
	combat.damage(e, h, 200.0, "magic", {"tick": true})
	combat.damage(e, h, 200.0, "magic", {"zone": true})
	combat.damage(null, h, 200.0)
	assert_eq(e.max_hp - e.hp, 80.0, "a burn, a patch on the ground and what has no attacker are not blows")


func test_lifelined_turns_a_killing_blow_once_every_three_minutes():
	var h := start(["mender"], {"armour": Items.epic("lifelined", 1)})
	var e := enemy(Vector3(2, 0, 0))
	combat.engage(pack, h)
	e.pos = Vector3(200, 0, 0)
	h.hp = 300.0
	combat.damage(e, h, 5000.0)
	assert_true(h.alive)
	assert_eq(h.hp, 1.0)
	assert_eq(h.armour_cd, 180.0)
	assert_true(combat.has_aura(h, "lifelined"))
	assert_eq(of("gear")[0].s, "lifelined")
	combat.damage(e, h, roundf(h.max_hp * 0.2))
	assert_eq(h.hp, 1.0, "the shield is a fifth of your health")
	run_for(5.1)
	assert_false(combat.has_aura(h, "lifelined"))
	h.hp = 300.0
	combat.damage(e, h, 5000.0)
	assert_false(h.alive, "and it is not ready again")
	assert_true(combat.gear_state(h, 1).is_empty(), "it is not pressed, so it has no button")


# ---------- the three sets

func test_breakwater_takes_less_the_more_enemies_are_on_you():
	var h := start(["warden"], whole("breakwater", 1))
	assert_eq(h.set_on, "breakwater")
	var foes: Array[Combatant] = []
	for i in 9:
		foes.append(enemy(Vector3(2 + i, 0, 0)))
	var hit := func() -> float:
		h.hp = h.max_hp
		return combat.damage(foes[0], h, 1000.0)
	assert_eq(hit.call(), 1000.0)
	for i in 2:
		foes[i].engaged = true
		foes[i].target_id = h.id
	assert_eq(hit.call(), 1000.0, "two are free")
	foes[2].engaged = true
	foes[2].target_id = h.id
	assert_eq(hit.call(), 950.0)
	foes[3].engaged = true
	foes[3].target_id = 999
	assert_eq(hit.call(), 950.0, "one that is on someone else does not count")
	for e in foes:
		e.engaged = true
		e.target_id = h.id
	assert_eq(hit.call(), 750.0, "a quarter at most")
	# two pieces are not a set
	var two := whole("breakwater", 1)
	two.erase("trinket")
	h = start(["warden"], two)
	assert_eq(h.set_on, "")


func test_the_vigil_makes_an_ally_you_heal_hit_harder():
	var h := start(["mender", "ranger"], whole("vigil", 1))
	var ally := combat.heroes[1]
	var e := enemy(Vector3(3, 0, 0))
	assert_eq(combat.damage(ally, e, 100.0), 100.0)
	ally.hp = ally.max_hp - 50.0
	combat.heal(h, ally, 30.0)
	assert_eq(combat.damage(ally, e, 100.0), 108.0)
	run_for(6.1)
	assert_eq(combat.damage(ally, e, 100.0), 100.0, "for six seconds")
	combat.heal(h, ally, 30.0, {"tick": true})
	assert_true(combat.has_aura(ally, "vigil"), "a heal over time keeps it up")
	h.hp = h.max_hp - 50.0
	combat.heal(h, h, 30.0)
	assert_false(combat.has_aura(h, "vigil"), "an ally, not yourself")


func test_wreckers_due_stacks_with_each_kill():
	var h := start(["duelist", "ranger"], whole("wrecker", 1))
	h.power = 1.0
	var other := combat.heroes[1]
	var dummy := enemy(Vector3(3, 0, 0))
	var kill := func(by: Combatant) -> void:
		var e := enemy(Vector3(3, 0, 0))
		e.hp = 50.0
		combat.damage(by, e, 60.0, "phys", {"raw": true})
	assert_eq(combat.damage(h, dummy, 100.0), 100.0)
	kill.call(other)
	assert_eq(combat.damage(h, dummy, 100.0), 100.0, "an enemy you never hit is no kill of yours")
	kill.call(h)
	assert_eq(combat.damage(h, dummy, 100.0), 106.0)
	# one you hit and another finished counts too
	var shared := enemy(Vector3(3, 0, 0))
	shared.hp = 50.0
	combat.damage(h, shared, 10.0, "phys", {"raw": true})
	combat.damage(other, shared, 60.0, "phys", {"raw": true})
	assert_eq(combat.damage(h, dummy, 100.0), 112.0)
	for i in 6:
		kill.call(h)
	assert_eq(combat.damage(h, dummy, 100.0), 130.0, "five at most")
	run_for(15.1)
	assert_eq(combat.damage(h, dummy, 100.0), 100.0, "and it runs out fifteen seconds after the last")
	kill.call(h)
	assert_eq(combat.damage(h, dummy, 100.0), 106.0, "and starts again from one")


# ---------- the three legendaries

func test_the_last_vesper_bell_silences_every_cast_and_opens_every_enemy():
	var h := start(["ranger", "warden"], {"trinket": Items.legendary("vesper_bell", 30)})
	assert_eq(combat.legend, "vesper_bell")
	assert_eq(combat.use_trinket(h), "Not in a fight")
	assert_eq(h.trinket_cd, 0.0)
	var a := enemy(Vector3(6, 0, 0))
	var b := enemy(Vector3(9, 0, 0))
	var c := enemy(Vector3(12, 0, 0))
	combat.engage(pack, combat.heroes[1])
	for e: Combatant in [a, b, c]:
		e.pos = Vector3(e.pos.x + 20.0, 0, 0)
	casting(a)
	casting(b)
	casting(c, false)
	assert_eq(combat.gear_state(h, 2).cd_max, 180.0)
	assert_eq(combat.use_gear(h, 2), "")
	assert_null(a.cast)
	assert_null(b.cast)
	assert_not_null(c.cast, "a cast that cannot be silenced is not")
	assert_eq(h.stats.interrupts, 2)
	assert_eq(h.trinket_cd, 180.0)
	assert_eq(combat.damage(h, c, 100.0), 125.0)
	assert_eq(combat.damage(combat.heroes[1], a, 100.0), 125.0, "for the whole party")
	run_for(10.1)
	assert_eq(combat.damage(h, c, 100.0), 100.0)


func test_tidecallers_mantle_stands_the_first_to_fall_up_again():
	var h := start(["mender", "warden"], {"armour": Items.legendary("tidecaller", 1)})
	var tank := combat.heroes[1]
	var e := enemy(Vector3(200, 0, 0))
	combat.damage(e, tank, 99999.0, "phys", {"raw": true})
	assert_false(tank.alive)
	run_for(0.5)
	assert_true(tank.alive, "out of a fight, the fallen get up as ever")
	assert_eq(of("gear").size(), 0)
	tank.hp = tank.max_hp
	combat.engage(pack, tank)
	combat.damage(e, tank, 99999.0, "phys", {"raw": true})
	run_for(2.9)
	assert_false(tank.alive)
	run_for(0.2)
	assert_true(tank.alive, "three seconds later")
	assert_eq(tank.hp, roundf(tank.max_hp * 0.5))
	assert_eq(of("revive").size(), 2)
	assert_eq(of("gear")[0].s, "tidecaller")
	assert_eq(combat.deaths, 2, "a fall is still a death")
	# once a fight
	combat.damage(e, h, 99999.0, "phys", {"raw": true})
	run_for(4.0)
	assert_false(h.alive)
	assert_true(combat.in_combat)
	# and when the last one falls, the party is not driven back while someone is about to stand
	start(["mender"], {"armour": Items.legendary("tidecaller", 1)})
	h = combat.player
	e = enemy(Vector3(200, 0, 0))
	combat.engage(pack, h)
	combat.damage(e, h, 99999.0, "phys", {"raw": true})
	run_for(2.0)
	assert_eq(of("wipe").size(), 0)
	run_for(1.2)
	assert_true(h.alive)
	assert_true(combat.in_combat)
	combat.damage(e, h, 99999.0, "phys", {"raw": true})
	run_for(0.1)
	assert_eq(of("wipe").size(), 1, "the second time it is")
	combat.engage(pack, h)
	combat.damage(e, h, 99999.0, "phys", {"raw": true})
	run_for(3.2)
	assert_eq(of("wipe").size(), 1, "and a new fight has it again")
	assert_true(h.alive)


func test_the_undertow_rewards_every_pack_pulled_into_the_fight():
	var h := start(["warden", "ranger", "mender"], {"weapon": Items.legendary("undertow", 1)})
	h.power = 1.0
	var ranger := combat.heroes[1]
	var healer := combat.heroes[2]
	var foes: Array[Combatant] = [enemy(Vector3(200, 0, 0))]
	var packs: Array[Pack] = [pack]
	for i in 4:
		packs.append(combat.add_pack())
		foes.append(enemy(Vector3(200, 0, 0), i + 1))
	combat.engage(packs[0], h)
	assert_eq(combat.damage(ranger, foes[0], 100.0), 100.0, "one pack is no more than a pull")
	combat.engage(packs[1], h)
	assert_eq(combat.damage(ranger, foes[0], 100.0), 106.0, "the whole party")
	h.hp = 100.0
	assert_eq(combat.heal(healer, h, 100.0), 106.0, "healing too")
	assert_almost_eq(combat.mended(healer, 100.0), 106.0, 1e-6, "and shields")
	combat.engage(packs[2], h)
	assert_almost_eq(combat.damage(ranger, foes[0], 100.0), 112.0, 0.01)
	# a pack that falls still counts until the fight is over
	combat.damage(ranger, foes[1], 999999.0, "phys", {"raw": true})
	run_for(0.1)
	assert_true(packs[1].cleared)
	assert_almost_eq(combat.damage(ranger, foes[0], 100.0), 112.0, 0.01)
	combat.engage(packs[3], h)
	combat.engage(packs[4], h)
	assert_almost_eq(combat.damage(ranger, foes[0], 100.0), 118.0, 0.01, "18% at most")
	for e in foes:
		combat.damage(ranger, e, 999999.0, "phys", {"raw": true})
	run_for(0.1)
	assert_false(combat.in_combat)
	assert_eq(combat.undertow, 1.0, "and the next fight starts from nothing")


func test_the_ai_uses_what_an_epic_and_a_legendary_give_it():
	var h := start(["warden", "mender"], {"weapon": Items.epic("stormcalling", 1), "armour": Items.epic("bulwarked", 1), "trinket": Items.legendary("vesper_bell", 3)})
	combat.ai_plays = true
	combat.autoplay = true
	var foes: Array[Combatant] = []
	for i in 4:
		foes.append(enemy(Vector3(3 + i * 0.5, 0, 1)))
	combat.engage(pack, h)
	run_for(8.0)
	assert_true(of("gear").any(func(e: Dictionary) -> bool: return e.s == "stormcalling"), "on a pull of four")
	assert_true(of("gear").any(func(e: Dictionary) -> bool: return e.s == "vesper_bell"))
	assert_false(of("gear").any(func(e: Dictionary) -> bool: return e.s == "bulwarked"), "not while it is well")
	h.hp = h.max_hp * 0.4
	run_for(0.5)
	assert_true(of("gear").any(func(e: Dictionary) -> bool: return e.s == "bulwarked"))


# ---------- the screens

func test_the_inventory_has_the_shop_and_sells():
	var save := SaveData.new()
	save.progress_in("abbey").timed = 4
	save.take(Items.plain("weapon", 12))
	save.take(Items.plain("armour", 12, 2))
	save.take(Items.legendary("undertow", 1))
	save.coin = 450
	GearScreens.dice.seed = 4
	var changes := [0]
	var holder := Control.new()
	add_child_autofree(holder)
	holder.add_child(GearScreens.inventory(save, func() -> void: changes[0] += 1, func() -> void: pass))
	var now := func() -> Control: return holder.get_child(holder.get_child_count() - 1)
	var button := func(name: String) -> Button: return now.call().find_child(name, true, false) as Button
	assert_eq((now.call().find_child("Coin", true, false) as Label).text, "450 coin")
	assert_string_contains((now.call().find_child("Shop", true, false).get_child(0) as Label).text, "200 coin")
	assert_null(button.call("Out3"), "a legendary has no price")
	button.call("Gamble_trinket").pressed.emit()
	assert_eq(save.coin, 250)
	assert_eq(save.items.size(), 4)
	assert_eq(save.items[3].slot, "trinket")
	assert_eq((now.call().find_child("Got", true, false) as Label).text, save.items[3].name)
	button.call("Gamble_armour").pressed.emit()
	assert_eq(save.coin, 50)
	assert_true(button.call("Gamble_weapon").disabled, "not enough left")
	assert_eq(changes[0], 2)
	# a common thing no team of yours wears goes at one press; a rare one asks first
	assert_eq(button.call("Out1").text, "Sell for 12")
	button.call("Out1").pressed.emit()
	assert_eq(save.coin, 62)
	assert_null(button.call("Out1"))
	button.call("Out2").pressed.emit()
	assert_eq(save.coin, 62, "the first press only asks")
	assert_string_contains(button.call("Out2").text, "Sure?")
	button.call("Out2").pressed.emit()
	assert_eq(save.coin, 62 + 48)
	assert_eq((now.call().find_child("Coin", true, false) as Label).text, "110 coin")


func test_the_team_editor_says_why_a_second_legendary_will_not_go_on():
	var save := SaveData.new()
	save.take(Items.legendary("undertow", 1))
	save.take(Items.legendary("tidecaller", 1))
	for slot in Items.SLOTS:
		save.take(Items.set_piece("wrecker", slot, 9))
	save.team = Teams.copy(save, Teams.in_use(save))
	var holder := Control.new()
	add_child_autofree(holder)
	holder.add_child(GearScreens.team(save, func() -> void: pass, func() -> void: pass))
	var now := func() -> Control: return holder.get_child(holder.get_child_count() - 1)
	assert_eq(save.teams[0].gear[3].weapon, 1, "the copy of the default team wears the one legendary")
	assert_null(now.call().find_child("Note", true, false))
	# the armour list of the tank: nothing, then the mantle (11), then the coat (9)
	var box := now.call().find_child("Armour0", true, false) as OptionButton
	assert_string_contains(box.get_item_text(1), "Tidecaller's Mantle (legendary)")
	box.item_selected.emit(1)
	assert_eq(save.teams[0].gear[0].armour, 0)
	assert_string_contains((now.call().find_child("Note", true, false) as Label).text, "one legendary")
	# a whole set on one hero is said
	assert_null(now.call().find_child("Set2", true, false))
	Teams.equip(save, save.teams[0], 2, "weapon", 3)
	Teams.equip(save, save.teams[0], 2, "armour", 4)
	Teams.equip(save, save.teams[0], 2, "trinket", 5)
	GearScreens.swap(now.call(), GearScreens.team(save, func() -> void: pass, func() -> void: pass))
	assert_string_contains((now.call().find_child("Set2", true, false) as Label).text, "Wrecker's Due")
	assert_null(now.call().find_child("Note", true, false))


func test_a_legendary_in_the_chest_can_only_be_taken():
	var save := SaveData.new()
	var found := [{"item": Items.epic("forked", 10, "Hook"), "state": ""}, {"item": Items.legendary("vesper_bell", 12), "state": ""}]
	var holder := Control.new()
	add_child_autofree(holder)
	var go := {"again": func() -> void: pass, "setup": func() -> void: pass, "gear": func() -> void: pass}
	holder.add_child(GearScreens.chest(found, save, func() -> void: pass, go, 12, 180))
	var now := func() -> Control: return holder.get_child(holder.get_child_count() - 1)
	assert_string_contains((now.call().find_child("Room", true, false) as Label).text, "180 of it paid by this run")
	assert_null(now.call().find_child("Sell1", true, false))
	assert_eq((now.call().find_child("Sell0", true, false) as Button).text, "Sell for 100")
	(now.call().find_child("Sell0", true, false) as Button).pressed.emit()
	assert_eq(save.coin, 100)
	(now.call().find_child("TakeAll", true, false) as Button).pressed.emit()
	assert_eq(save.items.size(), 1)
	assert_eq(save.items[0].kind, "vesper_bell")
	assert_eq(save.items[0].ilvl, 2, "its item level follows what is owned")


func test_an_epic_that_is_pressed_has_a_button_and_its_slots_key():
	Run.place = "sandbox"
	Run.party.assign(["warden", "mender", "duelist", "ranger"])
	Run.player_slot = 3
	Run.chosen_level = 1
	Run.rng_seed = 3
	Run.gear = [{}, {}, {}, {"weapon": Items.epic("stormcalling", 10), "armour": Items.epic("bulwarked", 10), "trinket": Items.legendary("vesper_bell", 12)}]
	var run: Run = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(run)
	run.combat.ai_plays = false
	await wait_frames(3)
	var p := run.combat.player
	assert_eq(run.combat.legend, "vesper_bell")
	for slot in 3:
		assert_true(run.hud.gear_button(slot).visible)
	run.player.get_node("PlayerInput")._unhandled_input(key(KEY_Z))
	assert_true(run.combat.has_aura(p, "stormcalling"))
	run.player.get_node("PlayerInput")._unhandled_input(key(KEY_X))
	assert_true(run.combat.has_aura(p, "bulwarked"))
	run.player.get_node("PlayerInput")._unhandled_input(key(KEY_C))
	assert_string_contains(run.combat.error, "Not in a fight")
	run.hud.gear_clicked.emit(0)
	assert_string_contains(run.combat.error, "Stormcalling Hook is not ready")
	run.hud.gear_button(1).hovered.emit(1, true)
	await wait_frames(2)
	assert_eq(run.hud._tip_title.text, "Bulwarked Cassock")
	assert_string_contains(run.hud._tip_body.text, "Press: a shield")


func test_a_run_pays_coin_and_counts_the_chests_without_a_legendary():
	var app: App = load("res://scenes/app.tscn").instantiate()
	add_child_autofree(app)
	app.save.place = "tollhaven"
	app.save.unlocked = 12
	app.save.level = 12
	app.save.dry = 3
	app.show_setup()
	assert_string_contains((app.screen.find_child("ChestWords", true, false) as Label).text, "may hold a legendary")
	assert_string_contains((app.screen.find_child("ChestWords", true, false) as Label).text, "pays 240 coin, 360 if it is in time")
	await app.start_run()
	await wait_physics_frames(3)
	var c := app.run.combat
	for e in c.enemies.duplicate():
		c.damage(app.run.player.c, e, 9999999.0, "phys", {"raw": true})
	await wait_physics_frames(3)
	assert_eq(app.state, "summary")
	assert_eq(app.save.coin, 360)
	var legendary := app.chest.any(func(e: Dictionary) -> bool: return e.item.rarity == Items.LEGENDARY)
	assert_eq(app.save.dry, 0 if legendary else 4)
	assert_eq(SaveStore.load_save().coin, 360)
	app.show_setup()
	await wait_frames(2)
