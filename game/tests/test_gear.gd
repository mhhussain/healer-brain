extends GutTest

# Milestone 12: gear. What an item is worth, what a chest holds, what each trinket does in a
# fight, teams and the default team, fast clears and records, the save as a file, and the
# screens for all of it.

const DT := 1.0 / 60.0
const TEMP_SAVE := "user://test-gear-save.json"

var combat: Combat
var pack: Pack
var events: Array[Dictionary]
var _saved_keys: SaveData


func before_all():
	SaveStore.path = TEMP_SAVE
	SaveStore.file_dir = OS.get_user_data_dir()
	_saved_keys = Run.keys


func after_all():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	DirAccess.remove_absolute(SaveStore.file_path())
	SaveStore.path = "user://fourfold-save.json"
	SaveStore.file_dir = ""
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


func enemy(def_id: String, at: Vector3) -> Combatant:
	return combat.spawn_enemy(def_id, at, 0)


func run_for(seconds: float) -> void:
	for i in roundi(seconds / DT):
		combat.tick(DT)


func of(kind: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e.k == kind)


func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


## A save with a few things in it: weapons of item level 9, 7, 5, 3 and 1, armour of 8 and 2,
## and two trinkets.
func stocked() -> SaveData:
	var save := SaveData.new()
	for ilvl: int in [5, 9, 1, 7, 3]:
		save.take(Items.plain("weapon", ilvl))
	save.take(Items.plain("armour", 2))
	save.take(Items.plain("armour", 8, 1))
	save.take(Items.trinket("great_key", 4))
	save.take(Items.trinket("seal", 6))
	return save


# ---------- what an item is worth

func test_an_item_level_is_a_hundredth_and_rarity_a_share_more():
	assert_almost_eq(Items.bonus(Items.plain("weapon", 10)), 0.10, 1e-6)
	assert_almost_eq(Items.bonus(Items.plain("weapon", 10, 1)), 0.105, 1e-6)
	assert_almost_eq(Items.bonus(Items.plain("armour", 20, 2)), 0.22, 1e-6)
	assert_eq(Items.describe(Items.plain("weapon", 20, 2)), "+22% damage and healing")
	assert_eq(Items.describe(Items.plain("armour", 10, 1)), "+10.5% health")
	assert_eq(Items.bonus(Items.trinket("lens", 30)), 0.0, "a trinket has no stat")
	assert_eq(Items.bonus({}), 0.0)


func test_the_ceiling_rises_three_item_levels_with_each_dungeon_level():
	assert_eq(Items.ceiling(1), 5)
	assert_eq(Items.ceiling(5), 17)
	assert_eq(Items.ceiling(10), 32)


func test_gear_level_is_the_average_of_the_best_weapon_and_the_best_armour():
	assert_eq(Items.gear_level([]), 0.0)
	assert_eq(Items.gear_level(stocked().items), 8.5)
	var only := [Items.plain("weapon", 6), Items.trinket("lens", 30)]
	assert_eq(Items.gear_level(only), 3.0, "a slot with nothing in it counts as nothing, and trinkets do not count")


func test_a_chest_holds_two_items_or_three_and_they_climb_to_the_ceiling():
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	assert_eq(Items.chest(rng, "abbey", 1, false, []).size(), 2)
	assert_eq(Items.chest(rng, "abbey", 1, true, []).size(), 3)
	var owned := [Items.plain("weapon", 10), Items.plain("armour", 10)]
	var slots := {"weapon": 0, "armour": 0, "trinket": 0}
	var rarities := [0, 0, 0]
	for i in 600:
		var item := Items.roll(rng, "tollhaven", 5, Items.gear_level(owned))
		assert_between(item.ilvl, 11, 13, "one to three above what is owned")
		slots[item.slot] += 1
		if item.slot == "trinket":
			assert_eq(item.rarity, 2, "trinkets are always rare")
			assert_eq(Items.TRINKETS[item.kind].from, "tollhaven", "and are the dungeon's own")
			assert_eq(item.name, Items.TRINKETS[item.kind].name)
		else:
			rarities[item.rarity] += 1
			assert_ne(item.name, "")
	assert_between(slots.weapon, 200, 280)
	assert_between(slots.armour, 200, 280)
	assert_between(slots.trinket, 85, 160)
	assert_gt(rarities[2], 30, "rare from level 3")
	assert_gt(rarities[0], rarities[1])
	for i in 200:
		var low := Items.roll(rng, "abbey", 2, 0.0)
		assert_true(low.slot == "trinket" or low.rarity < 2, "nothing rare below level 3 but trinkets")
		assert_between(low.ilvl, 1, 3)
		assert_eq(Items.roll(rng, "abbey", 2, 30.0).ilvl, 8, "never above the level's ceiling")


func test_every_trinket_says_what_it_does_and_grows_with_item_level():
	assert_eq(Items.TRINKETS.size(), 10)
	for dungeon in Levels.DUNGEONS:
		assert_eq(Items.trinkets_of(dungeon).size(), 5, dungeon)
	for kind: String in Items.TRINKETS:
		var low := Items.trinket(kind, 1)
		var high := Items.trinket(kind, 20)
		assert_false(Items.describe(low).contains("%s"), kind)
		assert_ne(Items.describe(low), Items.describe(high), kind + " is better at a higher item level")
		assert_eq(Items.pressed(low), Items.TRINKETS[kind].press)
	assert_eq(Items.describe(Items.trinket("great_key", 1)), "Press: you take 30% less damage for 8 seconds. 90 second cooldown.")
	assert_eq(Items.amount("great_key", 99), 0.5, "the Key stops at half")
	assert_eq(Items.cooldown(Items.trinket("seal", 1)), 45.0)
	assert_eq(Items.cooldown(Items.trinket("seal", 99)), 25.0, "the Seal's cooldown stops at 25 seconds")
	assert_eq(Items.amount("tide_glass", 99), 0.6)
	assert_string_contains(Items.describe(Items.trinket("thimble", 1)), "below 35% health, you are healed for 20%")
	assert_string_contains(Items.describe(Items.trinket("shell", 3)), "soaks 170 damage")


# ---------- gear in a fight

func test_a_weapon_raises_damage_healing_and_shields_and_armour_raises_health():
	var h := start(["mender", "warden"], {"weapon": Items.plain("weapon", 20), "armour": Items.plain("armour", 10)})
	var e := enemy("brute", Vector3(2, 0, 0))
	assert_eq(h.power, 1.2)
	assert_eq(h.max_hp, roundf(h.hero.hp * 1.1))
	assert_eq(h.hp, h.max_hp)
	assert_eq(combat.damage(h, e, 100.0), 120.0)
	var ally := combat.heroes[1]
	assert_eq(ally.max_hp, ally.hero.hp, "the others wear nothing")
	ally.hp = 100.0
	assert_eq(combat.heal(h, ally, 100.0), 120.0)
	assert_eq(combat.mended(h, 350.0), 420.0)
	assert_eq(combat.heal(h, ally, 100.0, {"raw": true}), 100.0)
	assert_eq(combat.damage(ally, e, 100.0), 100.0)


func test_with_nothing_worn_nothing_changes():
	var h := start(["ranger"])
	assert_eq(h.power, 1.0)
	assert_eq(h.max_hp, h.hero.hp)
	assert_true(h.trinket.is_empty())
	assert_eq(combat.use_trinket(h), "Nothing to use")
	assert_true(combat.gear_state(h, 2).is_empty())
	combat.press_gear(2)
	assert_eq(combat.error, "")


func test_the_great_key_cuts_what_you_take_for_eight_seconds():
	var h := start(["warden"], {"trinket": Items.trinket("great_key", 1)})
	var e := enemy("brute", Vector3(2, 0, 0))
	assert_eq(combat.use_trinket(h), "")
	assert_eq(combat.damage(e, h, 100.0), 70.0)
	assert_eq(combat.use_trinket(h), "cd")
	assert_eq(combat.gear_state(h, 2).cd, 90.0)
	run_for(8.1)
	assert_eq(combat.damage(e, h, 100.0), 100.0)
	assert_eq(of("gear").size(), 1)


func test_the_thimble_heals_you_once_a_minute_when_you_are_low():
	var h := start(["warden"], {"trinket": Items.trinket("thimble", 1)})
	enemy("brute", Vector3(60, 0, 0))
	combat.engage(pack, h)
	h.hp = h.max_hp * 0.5
	run_for(0.1)
	assert_eq(h.hp, h.max_hp * 0.5, "not until below 35%")
	h.hp = h.max_hp * 0.3
	run_for(0.1)
	assert_almost_eq(h.hp, h.max_hp * 0.5, 1.0)
	h.hp = h.max_hp * 0.3
	run_for(30.0)
	assert_almost_eq(h.hp, h.max_hp * 0.3, 1.0, "once a minute")
	run_for(30.5)
	assert_almost_eq(h.hp, h.max_hp * 0.5, 1.0)


func test_the_bell_rope_lifts_the_whole_party_and_two_do_not_add_up():
	var h := start(["ranger", "mender"], {"trinket": Items.trinket("bell_rope", 1)})
	var other := combat.heroes[1]
	combat.wear(other, {"trinket": Items.trinket("bell_rope", 1)})
	var e := enemy("brute", Vector3(2, 0, 0))
	assert_eq(combat.use_trinket(h), "")
	assert_eq(combat.use_trinket(other), "")
	assert_eq(combat.damage(h, e, 100.0), 110.0)
	assert_eq(combat.damage(other, e, 100.0), 110.0)
	h.hp = 100.0
	assert_eq(combat.heal(other, h, 100.0), 110.0)
	run_for(10.1)
	assert_eq(combat.damage(h, e, 100.0), 100.0)


func test_the_shell_shields_you_every_twenty_seconds_of_a_fight():
	var h := start(["warden"], {"trinket": Items.trinket("shell", 1)})
	var e := enemy("brute", Vector3(60, 0, 0))
	run_for(0.2)
	assert_false(combat.has_aura(h, "shell"), "not outside a fight")
	combat.engage(pack, h)
	run_for(0.1)
	assert_true(combat.has_aura(h, "shell"))
	var before := h.hp
	combat.damage(e, h, 100.0)
	assert_eq(h.hp, before, "it soaks the blow")
	combat.damage(e, h, 100.0)
	assert_eq(h.hp, before - 50.0, "150 in all")


func test_the_tuning_fork_rewards_a_silence():
	var h := start(["ranger"], {"trinket": Items.trinket("tuning_fork", 1)})
	var e := enemy("brute", Vector3(2, 0, 0))
	e.cast = Cast.new()
	e.cast.interruptible = true
	e.cast.ab = e.enemy.abilities[0] if not e.enemy.abilities.is_empty() else EnemyAbility.new()
	e.cast.total = 3.0
	combat.interrupt(h, e)
	assert_true(combat.has_aura(h, "tuning_fork"))
	assert_almost_eq(combat.damage(h, e, 100.0), 115.0, 0.5)
	run_for(8.1)
	assert_eq(combat.damage(h, e, 100.0), 100.0)


func test_the_gutting_knife_lands_every_sixth_hit_again():
	var h := start(["ranger", "warden"], {"trinket": Items.trinket("gutting_knife", 1)})
	var e := enemy("brute", Vector3(2, 0, 0))
	e.max_hp = 99999.0
	e.hp = e.max_hp
	for i in 5:
		combat.damage(h, e, 10.0)
	combat.damage(h, e, 10.0, "magic", {"tick": true})
	var before := e.hp
	assert_eq(of("hit").size(), 6, "the tick of a lasting effect is no hit")
	combat.damage(h, e, 10.0)
	assert_eq(e.hp, before - 70.0, "the sixth lands again for 60")
	assert_eq(h.trinket_n, 0, "and what the knife does is no hit either")
	# heals count too
	var ally := combat.heroes[1]
	ally.hp = 100.0
	for i in 6:
		combat.heal(h, ally, 10.0)
	assert_eq(ally.hp, 100.0 + 60.0 + 60.0)


func test_corrows_seal_gives_anyone_a_silence():
	var h := start(["mender"], {"trinket": Items.trinket("seal", 1)})
	var e := enemy("brute", Vector3(4, 0, 0))
	assert_eq(combat.use_trinket(h), "No target")
	assert_eq(combat.use_trinket(h, e), "Nothing to silence")
	assert_eq(h.trinket_cd, 0.0, "and it is not spent")
	e.cast = Cast.new()
	e.cast.interruptible = true
	e.cast.ab = EnemyAbility.new()
	e.cast.total = 3.0
	assert_eq(combat.use_trinket(h, e), "")
	assert_null(e.cast)
	assert_eq(h.stats.interrupts, 1)
	assert_eq(h.trinket_cd, 45.0)
	e.pos = Vector3(60, 0, 0)
	h.trinket_cd = 0.0
	assert_eq(combat.use_trinket(h, e), "Out of range")


func test_the_pitch_pot_burns_the_target_and_those_beside_it():
	var h := start(["ranger"], {"trinket": Items.trinket("pitch_pot", 1)})
	var a := enemy("brute", Vector3(6, 0, 0))
	var b := enemy("brute", Vector3(9, 0, 0))
	var far := enemy("brute", Vector3(16, 0, 0))
	for e: Combatant in [a, b, far]:
		e.max_hp = 99999.0
		e.hp = e.max_hp
		e.engaged = true
	assert_eq(combat.use_trinket(h, a), "")
	run_for(8.2)
	assert_eq(a.max_hp - a.hp, 320.0, "40 a second for 8 seconds")
	assert_eq(b.max_hp - b.hp, 320.0)
	assert_eq(far.max_hp - far.hp, 0.0, "more than 5 m away")


func test_the_lens_strengthens_the_next_three_hits():
	var h := start(["ranger"], {"trinket": Items.trinket("lens", 1)})
	var e := enemy("brute", Vector3(2, 0, 0))
	e.max_hp = 99999.0
	e.hp = e.max_hp
	assert_eq(combat.use_trinket(h), "")
	assert_eq(combat.damage(h, e, 100.0, "magic", {"tick": true}), 100.0, "a tick is no hit")
	for i in 3:
		assert_eq(combat.damage(h, e, 100.0), 150.0)
	assert_eq(combat.damage(h, e, 100.0), 100.0)


func test_the_tide_glass_gives_back_what_you_spend():
	var h := start(["mender"], {"trinket": Items.trinket("tide_glass", 1)})
	h.res = 0.0
	assert_eq(combat.use_trinket(h), "")
	assert_almost_eq(h.res, h.res_max * 0.3, 0.01)


func test_the_ai_uses_a_trinket_that_is_pressed():
	var h := AIHarness.new(Levels.abbey(), ["warden", "mender", "duelist", "ranger"], 1, 3)
	h.combat.wear(h.combat.heroes[3], {"trinket": Items.trinket("bell_rope", 1)})
	h.combat.wear(h.combat.heroes[1], {"trinket": Items.trinket("tide_glass", 1)})
	assert_true(h.run_until(func() -> bool: return not h.of("gear").is_empty(), 120.0), "the Bell Rope is rung on the first big pull")
	assert_eq(h.of("gear")[0].s, "bell_rope")
	assert_true(h.combat.in_combat)
	assert_true(h.combat.has_aura(h.combat.heroes[0], "bell_rope"))


# ---------- the keys

func test_gear_has_three_keys_of_its_own():
	var save := SaveData.new()
	assert_eq(save.gear_keys, [KEY_Z, KEY_X, KEY_C])
	assert_eq(Bindings.gear_for_key(save, KEY_C), 2)
	assert_eq(Bindings.gear_for_key(save, KEY_1), -1)
	assert_eq(Bindings.set_gear_key(save, 2, KEY_W), "W is kept for moving")
	assert_eq(Bindings.set_gear_key(save, 2, KEY_1), "")
	assert_eq(Bindings.ability_for_key(save, "ranger", KEY_1), -1, "a gear key is taken from every hero's abilities")
	assert_eq(Bindings.ability_for_key(save, "mender", KEY_1), -1)
	assert_eq(Bindings.set_key(save, "ranger", "quickshot", 0, KEY_Z), "")
	assert_eq(save.gear_keys, [0, KEY_X, KEY_1], "and an ability key from the gear")
	Bindings.reset_gear(save)
	assert_eq(save.gear_keys, [KEY_Z, KEY_X, KEY_C])
	assert_eq(Bindings.ability_for_key(save, "ranger", KEY_Z), -1)
	var back := SaveData.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	assert_eq(back.gear_keys, [KEY_Z, KEY_X, KEY_C])
	# a save from before gear, with an ability on one of its keys: the ability keeps it
	var old := SaveData.new().to_dict()
	old.erase("gear_keys")
	old.keys["ranger"]["volley"] = [KEY_C, 0]
	assert_eq(SaveData.from_dict(JSON.parse_string(JSON.stringify(old))).gear_keys, [KEY_Z, KEY_X, 0])


func test_the_key_editor_has_the_gear_keys():
	var save := SaveData.new()
	var editor := KeysEditor.new()
	add_child_autofree(editor)
	editor.show_hero(save, "ranger")
	assert_eq((editor.find_child("gear_2", true, false) as Button).text, "C")
	(editor.find_child("gear_2", true, false) as Button).pressed.emit()
	assert_true(editor.is_waiting())
	editor.capture(KEY_V)
	assert_eq(save.gear_keys[2], KEY_V)
	assert_eq((editor.find_child("gear_2", true, false) as Button).text, "V")
	(editor.find_child("gear_0", true, false) as Button).pressed.emit()
	editor.capture(KEY_BACKSPACE)
	assert_eq(save.gear_keys[0], 0)


# ---------- teams

func test_the_default_team_gives_its_best_to_the_hero_you_play_first():
	var save := stocked()
	save.slot = 1
	var team := Teams.in_use(save)
	assert_eq(team.name, Teams.DEFAULT_NAME)
	var worn := Teams.worn(save, team)
	assert_eq([worn[1].weapon.ilvl, worn[0].weapon.ilvl, worn[2].weapon.ilvl, worn[3].weapon.ilvl], [9, 7, 5, 3], "you, the tank, then the others")
	assert_eq(worn[1].armour.ilvl, 8)
	assert_eq(worn[0].armour.ilvl, 2)
	assert_true(worn[2].armour.is_empty())
	assert_eq(worn[1].trinket.kind, "seal", "the highest trinket")
	assert_eq(worn[0].trinket.kind, "great_key")
	save.slot = 3
	assert_eq(Teams.worn(save, Teams.in_use(save))[3].weapon.ilvl, 9, "it follows the hero you play")
	save.take(Items.plain("weapon", 12))
	assert_eq(Teams.worn(save, Teams.in_use(save))[3].weapon.ilvl, 12, "and what you own")


func test_a_team_of_your_own_wears_what_you_give_it():
	var save := stocked()
	var place := Teams.copy(save, Teams.in_use(save))
	assert_eq(place, 1)
	save.team = place
	var team := Teams.in_use(save)
	assert_eq(team.name, "Team 1")
	var best: Dictionary = Items.of_slot(save.items, "weapon")[0]
	assert_eq(Teams.wearer(team, best.id), 3)
	save.take(Items.plain("weapon", 12))
	assert_eq(Teams.worn(save, team)[3].weapon.ilvl, 9, "nothing changes unless you change it")
	# one thing cannot be worn twice: giving it to another takes it off the first
	Teams.equip(save, team, 0, "weapon", best.id)
	assert_eq(Teams.wearer(team, best.id), 0)
	assert_eq(team.gear[3].weapon, 0)
	Teams.equip(save, team, 0, "armour", best.id)
	assert_eq(team.gear[0].armour, Items.of_slot(save.items, "armour")[1].id, "a weapon does not go in the armour slot")
	Teams.equip(save, team, 0, "weapon", 0)
	assert_eq(team.gear[0].weapon, 0)
	Teams.wear_best(save, team)
	assert_eq(Teams.worn(save, team)[3].weapon.ilvl, 12)
	# the default team may wear the same things: using an item in one team does not take it from another
	assert_eq(Teams.worn(save, Teams.at(save, 0))[3].weapon.ilvl, 12)


func test_an_item_thrown_out_comes_off_every_team_that_wore_it():
	var save := stocked()
	save.team = Teams.copy(save, Teams.in_use(save))
	Teams.copy(save, Teams.in_use(save))
	var best: Dictionary = Items.of_slot(save.items, "weapon")[0]
	assert_eq(Teams.using(save, best.id), ["Team 1", "Team 2"], "the teams to warn about")
	save.throw_out(best.id)
	assert_true(save.item(best.id).is_empty())
	assert_eq(save.items.size(), 8)
	assert_eq(Teams.in_use(save).gear[3].weapon, 0, "the slot is empty, and the team still runs")
	assert_true(Teams.worn(save, Teams.in_use(save))[3].weapon.is_empty())
	Teams.remove(save, 1)
	assert_eq(save.team, 0, "forgetting the team in use goes back to the default")
	assert_eq(save.teams.size(), 1)


func test_the_inventory_holds_sixty():
	var save := SaveData.new()
	for i in Items.SPACE:
		assert_true(save.take(Items.plain("weapon", 1)))
	assert_false(save.has_room())
	assert_false(save.take(Items.plain("weapon", 1)))
	assert_eq(save.items.size(), 60)
	var ids := {}
	for item: Dictionary in save.items:
		ids[item.id] = true
	assert_eq(ids.size(), 60, "each has a number of its own")


# ---------- levels, records and the save

func test_a_fast_clear_opens_two_levels_and_a_very_fast_one_three():
	var limit := 14 * 60.0
	assert_eq(Items.levels_opened(limit, limit), 1)
	assert_eq(Items.levels_opened(limit * 0.8, limit), 2)
	assert_eq(Items.levels_opened(limit * 0.8 + 1.0, limit), 1)
	assert_eq(Items.levels_opened(limit * 0.6, limit), 3)
	var s := SaveData.new()
	assert_eq(s.record(1, "ranger", 700.0, true, "", limit), 1)
	assert_eq(s.record(2, "ranger", 660.0, true, "", limit), 2, "a fifth inside the time")
	assert_eq(s.unlocked, 4)
	assert_eq(s.record(2, "ranger", 500.0, true, "", limit), 1, "two fifths inside: three up from level 2")
	assert_eq(s.unlocked, 5)
	assert_eq(s.record(1, "ranger", 400.0, true, "", limit), 0, "never down")
	assert_eq(s.unlocked, 5)
	assert_eq(s.progress_in("abbey").timed, 2, "the highest level timed")
	assert_eq(s.record(3, "ranger", 900.0, false, "", limit), 0)
	assert_eq(s.progress_in("abbey").timed, 2)


func test_the_best_time_at_each_level_is_kept_with_the_four_who_set_it():
	var s := SaveData.new()
	var crew := {"party": ["warden", "mender", "duelist", "ranger"], "slot": 3}
	s.record(1, "ranger", 700.0, true, "", 840.0, crew)
	assert_eq(s.record_at(1), {"time": 700.0, "party": ["warden", "mender", "duelist", "ranger"], "slot": 3})
	assert_true(s.record_at(2).is_empty())
	s.record(1, "mender", 650.0, true, "", 840.0, {"party": ["warden", "mender", "pyromancer", "ranger"], "slot": 1})
	assert_eq(s.record_at(1).time, 650.0)
	assert_eq(s.record_at(1).slot, 1)
	s.record(1, "ranger", 800.0, true, "", 840.0, crew)
	assert_eq(s.record_at(1).time, 650.0, "a slower run changes nothing")
	s.place = "tollhaven"
	assert_true(s.record_at(1).is_empty(), "each dungeon keeps its own")


func test_gear_teams_and_records_survive_the_file_and_back():
	var s := stocked()
	s.team = Teams.copy(s, Teams.in_use(s))
	Teams.in_use(s).name = "Pushers"
	s.record(2, "ranger", 600.0, true, "", 840.0, {"party": s.party, "slot": 3})
	var back := SaveData.from_text(s.to_text())
	assert_eq(back.to_dict(), s.to_dict())
	assert_eq(back.items.size(), 9)
	assert_eq(back.next_item, 10)
	assert_eq(Teams.in_use(back).name, "Pushers")
	assert_eq(Teams.worn(back, Teams.in_use(back))[3].weapon.ilvl, 9)
	assert_eq(back.record_at(2).time, 600.0)
	assert_eq(back.to_dict().v, SaveData.VERSION)
	assert_null(SaveData.from_text("not a save"))
	assert_null(SaveData.from_text("{\"hello\": 1}"))
	# a save from before gear reads as one with none
	var old := SaveData.from_dict({"v": 3, "place": "abbey", "progress": {"abbey": {"unlocked": 4, "level": 2, "bests": {}}}})
	assert_true(old.items.is_empty())
	assert_eq(old.team, 0)
	assert_eq(old.progress_in("abbey").timed, 3)


func test_damaged_gear_in_a_save_does_no_harm():
	var d := stocked().to_dict()
	d.items.append({"slot": "hat", "name": "A hat", "ilvl": 3})
	d.items.append({"slot": "trinket", "name": "Nothing", "kind": "nothing", "ilvl": 3})
	d.items.append({"id": 1, "slot": "weapon", "name": "A copy of the first's number", "ilvl": 4, "rarity": 9})
	d.items.append("junk")
	d["teams"] = [{"name": "Odd", "party": ["warden", "mender", "duelist", "ranger"], "slot": 2,
		"gear": [{"weapon": 2, "armour": 2, "trinket": 999}, {"weapon": 2}, "x", {}]}, {"party": ["mender", "mender", "duelist", "ranger"]}, 7]
	d["team"] = 9
	var s := SaveData.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_eq(s.items.size(), 10, "the hat and the unknown trinket are dropped")
	var twin: Dictionary = s.items[-1]
	assert_eq(twin.id, 10, "a number used twice is given afresh")
	assert_eq(twin.rarity, 2)
	assert_eq(s.teams.size(), 1, "a team with a healer as its tank is dropped")
	assert_eq(s.team, 1)
	assert_eq(s.teams[0].gear[0], {"weapon": 2, "armour": 0, "trinket": 0}, "a weapon is not armour, and what is not owned is not worn")
	assert_eq(s.teams[0].gear[1].weapon, 0, "one thing is not worn twice")


# ---------- the screens

func test_the_start_screen_has_the_dungeon_the_team_and_the_route_side_by_side():
	var save := stocked()
	save.unlocked = 3
	save.record(2, "ranger", 600.0, true, "", 840.0, {"party": save.party, "slot": 3})
	var changes := [0]
	var went: Array[String] = []
	var holder := Control.new()
	add_child_autofree(holder)
	var go := {"route": func() -> void: went.append("route"), "team": func() -> void: went.append("team"),
		"gear": func() -> void: went.append("gear"), "settings": func() -> void: went.append("settings")}
	holder.add_child(Screens.setup(save, func() -> void: changes[0] += 1, func() -> void: went.append("start"), go))
	var now := func() -> Control: return holder.get_child(holder.get_child_count() - 1)
	for part: String in ["Levels", "Crew", "Route"]:
		assert_not_null(now.call().find_child(part, true, false), part)
	assert_null(now.call().find_child("Level5", true, false), "only unlocked levels are offered")
	(now.call().find_child("Level2", true, false) as Button).pressed.emit()
	assert_eq(save.level, 2)
	assert_string_contains((now.call().find_child("Record", true, false) as Label).text, "10:00, by Hale Dunmarrow, Sister Wren, %s and %s (you as %s)" % [Heroes.by_id("duelist").name, Heroes.by_id("ranger").name, Heroes.by_id("ranger").name])
	assert_string_contains((now.call().find_child("Hero3", true, false) as Label).text, "(you)")
	assert_eq((now.call().find_child("TeamPick", true, false) as OptionButton).item_count, 1)
	for name: String in ["Plan", "Team", "Gear", "Settings", "Start"]:
		(now.call().find_child(name, true, false) as Button).pressed.emit()
	assert_eq(went, ["route", "team", "gear", "settings", "start"])
	assert_gt(changes[0], 0)


func test_the_team_editor_changes_the_crew_and_dresses_a_team_of_your_own():
	var save := stocked()
	var changes := [0]
	var holder := Control.new()
	add_child_autofree(holder)
	holder.add_child(GearScreens.team(save, func() -> void: changes[0] += 1, func() -> void: pass))
	var now := func() -> Control: return holder.get_child(holder.get_child_count() - 1)
	(now.call().find_child("Pick1", true, false) as OptionButton).item_selected.emit(1)
	assert_eq(save.party[1], "bloomweaver")
	(now.call().find_child("You1", true, false) as Button).pressed.emit()
	assert_eq(save.slot, 1)
	(now.call().find_child("Pick3", true, false) as OptionButton).item_selected.emit(0)
	assert_eq(save.party, ["warden", "bloomweaver", "duelist", "duelist"], "the same hero twice is allowed")
	var box := now.call().find_child("Weapon1", true, false) as OptionButton
	assert_true(box.disabled, "the default team dresses itself")
	assert_string_contains(box.get_item_text(box.selected), "9", "the best to the hero you play")
	assert_null(now.call().find_child("Forget", true, false))

	(now.call().find_child("Copy", true, false) as Button).pressed.emit()
	assert_eq(save.team, 1)
	assert_eq(save.teams[0].party, ["warden", "bloomweaver", "duelist", "duelist"])
	box = now.call().find_child("Weapon0", true, false) as OptionButton
	assert_false(box.disabled)
	assert_eq(box.item_count, 6, "nothing, and the five weapons")
	box.item_selected.emit(1)
	assert_eq(Teams.worn(save, save.teams[0])[0].weapon.ilvl, 9, "the best weapon goes to the tank")
	assert_true(Teams.worn(save, save.teams[0])[1].weapon.is_empty(), "and comes off the healer")
	(now.call().find_child("Trinket2", true, false) as OptionButton).item_selected.emit(0)
	(now.call().find_child("You0", true, false) as Button).pressed.emit()
	assert_eq(save.teams[0].slot, 0)
	assert_eq(save.slot, 1, "the default team is left as it was")
	(now.call().find_child("Name", true, false) as LineEdit).text_submitted.emit("Pushers")
	assert_eq(save.teams[0].name, "Pushers")
	(now.call().find_child("Best", true, false) as Button).pressed.emit()
	assert_eq(Teams.worn(save, save.teams[0])[0].weapon.ilvl, 9)
	(now.call().find_child("Forget", true, false) as Button).pressed.emit()
	assert_eq(save.teams.size(), 0)
	assert_eq(save.team, 0)
	assert_gt(changes[0], 6)


func test_the_inventory_asks_before_an_item_is_thrown_out():
	var save := stocked()
	save.team = Teams.copy(save, Teams.in_use(save))
	var changes := [0]
	var holder := Control.new()
	add_child_autofree(holder)
	holder.add_child(GearScreens.inventory(save, func() -> void: changes[0] += 1, func() -> void: pass))
	var now := func() -> Control: return holder.get_child(holder.get_child_count() - 1)
	assert_string_contains((now.call().find_child("Room", true, false) as Label).text, "9 of 60")
	assert_string_contains((now.call().find_child("Room", true, false) as Label).text, "Gear level 8.5")
	assert_eq(now.call().find_child("Items", true, false).get_child_count(), 9 * 5)
	var best: Dictionary = Items.of_slot(save.items, "weapon")[0]
	(now.call().find_child("Out%d" % best.id, true, false) as Button).pressed.emit()
	assert_eq(save.items.size(), 9, "the first press only asks")
	assert_string_contains((now.call().find_child("Out%d" % best.id, true, false) as Button).text, "Worn in Team 1")
	(now.call().find_child("Out%d" % best.id, true, false) as Button).pressed.emit()
	assert_eq(save.items.size(), 8)
	assert_eq(changes[0], 1)
	assert_null(now.call().find_child("Out%d" % best.id, true, false))


func test_the_chest_is_taken_or_sold_one_thing_at_a_time():
	var save := SaveData.new()
	var found := [{"item": Items.plain("weapon", 3), "state": ""}, {"item": Items.trinket("lens", 2), "state": ""}, {"item": Items.plain("armour", 2), "state": ""}]
	var went: Array[String] = []
	var holder := Control.new()
	add_child_autofree(holder)
	var go := {"again": func() -> void: went.append("again"), "next": func() -> void: went.append("next"),
		"setup": func() -> void: went.append("setup"), "gear": func() -> void: went.append("gear")}
	holder.add_child(GearScreens.chest(found, save, func() -> void: pass, go, 2))
	var now := func() -> Control: return holder.get_child(holder.get_child_count() - 1)
	(now.call().find_child("Take0", true, false) as Button).pressed.emit()
	assert_eq(save.items.size(), 1)
	assert_eq(save.items[0].ilvl, 3)
	assert_eq(save.items[0].id, 1)
	assert_null(now.call().find_child("Take0", true, false), "it cannot be taken twice")
	(now.call().find_child("Sell1", true, false) as Button).pressed.emit()
	assert_eq(found[1].state, "sold")
	assert_eq(save.coin, 8, "a rare of item level 2")
	assert_null(now.call().find_child("Take1", true, false), "a thing sold is gone")
	(now.call().find_child("TakeAll", true, false) as Button).pressed.emit()
	assert_eq(save.items.size(), 2, "all that had not been sold")
	assert_null(now.call().find_child("TakeAll", true, false))
	assert_eq((now.call().find_child("Next", true, false) as Button).text, "On to level 3")
	(now.call().find_child("Next", true, false) as Button).pressed.emit()
	assert_eq(went, ["next"])
	# with no room, nothing more can be taken
	for i in Items.SPACE - 2:
		save.take(Items.plain("weapon", 1))
	var more := [{"item": Items.plain("weapon", 4), "state": ""}]
	GearScreens.swap(now.call(), GearScreens.chest(more, save, func() -> void: pass, go, 2))
	assert_true((now.call().find_child("Take0", true, false) as Button).disabled)
	assert_false((now.call().find_child("Sell0", true, false) as Button).disabled, "but it can still be sold")


func test_a_trinket_that_is_pressed_has_a_button_and_a_key():
	Run.place = "sandbox"
	Run.party.assign(["warden", "mender", "duelist", "ranger"])
	Run.player_slot = 3
	Run.chosen_level = 1
	Run.rng_seed = 3
	Run.gear = [{}, {}, {}, {"weapon": Items.plain("weapon", 10), "trinket": Items.trinket("great_key", 1)}]
	var run: Run = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(run)
	run.combat.ai_plays = false
	await wait_frames(3)
	var p := run.combat.player
	assert_eq(p.power, 1.1)
	assert_true(run.hud.gear_button(2).visible)
	assert_false(run.hud.gear_button(0).visible, "a weapon is not pressed")
	run.player.get_node("PlayerInput")._unhandled_input(key(KEY_C))
	assert_true(run.combat.has_aura(p, "great_key"))
	assert_gt(p.trinket_cd, 80.0)
	run.hud.gear_clicked.emit(2)
	assert_string_contains(run.combat.error, "not ready")
	run.hud.gear_button(2).hovered.emit(2, true)
	await wait_frames(2)
	assert_true(run.hud._tip.visible)
	assert_eq(run.hud._tip_title.text, "Krogg's Great Key")


func test_a_run_ends_in_a_chest_and_the_next_run_wears_what_it_gave():
	var app: App = load("res://scenes/app.tscn").instantiate()
	add_child_autofree(app)
	app.save.party.assign(["warden", "mender", "duelist", "ranger"])
	app.save.slot = 3
	await app.start_run()
	await wait_physics_frames(3)
	var c := app.run.combat
	for e in c.enemies.duplicate():
		c.damage(app.run.player.c, e, 9999999.0)
	await wait_physics_frames(3)
	assert_eq(app.state, "summary")
	assert_eq(app.chest.size(), 3, "three things for a timed run")
	assert_eq(app.save.coin, 15, "and the run paid: 10 for level 1 of the Abbey, half again in time")
	assert_eq(app.save.unlocked, 4, "and so fast a clear opens three levels")
	assert_string_contains((app.screen.find_child("Unlocked", true, false) as Label).text, "levels up to 4")
	assert_eq(app.save.record_at(1).party, ["warden", "mender", "duelist", "ranger"])
	assert_null(app.screen.find_child("Again", true, false), "the chest comes first")
	(app.screen.find_child("Chest", true, false) as Button).pressed.emit()
	assert_eq(app.state, "chest")
	assert_string_contains((app.screen.find_child("Room", true, false) as Label).text, "15 of it paid by this run")
	(app.screen.find_child("TakeAll", true, false) as Button).pressed.emit()
	assert_eq(app.save.items.size(), 3)
	assert_eq(SaveStore.load_save().items.size(), 3, "and they are in the file")
	for item: Dictionary in app.save.items:
		assert_between(item.ilvl, 1, 3)
	# into the inventory and back to the chest
	(app.screen.find_child("Gear", true, false) as Button).pressed.emit()
	assert_eq(app.state, "gear")
	(app.screen.find_child("Back", true, false) as Button).pressed.emit()
	assert_eq(app.state, "chest")
	app.save.take(Items.plain("weapon", 5))
	app.save.take(Items.plain("armour", 4))
	(app.screen.find_child("Next", true, false) as Button).pressed.emit()
	await wait_until(func() -> bool: return app.state == "run", 10.0)
	assert_eq(app.run.combat.level, 2)
	var me := app.run.combat.player
	assert_eq(me.power, 1.05, "the default team gives the best to the hero you play")
	assert_eq(me.max_hp, roundf(me.hero.hp * 1.04))
	assert_true(app.chest.is_empty())
	app.show_setup()
	await wait_frames(2)


func test_the_save_is_kept_as_a_file_and_loaded_back():
	var app: App = load("res://scenes/app.tscn").instantiate()
	add_child_autofree(app)
	app.save.take(Items.plain("weapon", 7))
	app.save.unlocked = 6
	app.show_setup()
	(app.screen.find_child("Settings", true, false) as Button).pressed.emit()
	assert_eq(app.state, "settings")
	assert_not_null(app.screen.find_child("gear_2", true, false), "the keys are here, the gear keys among them")
	(app.screen.find_child("SaveFile", true, false) as Button).pressed.emit()
	assert_true(FileAccess.file_exists(SaveStore.file_path()))
	assert_string_contains((app.screen.find_child("FileNote", true, false) as Label).text, "Saved to")
	app.save.throw_out(app.save.items[0].id)
	app.save.unlocked = 1
	(app.screen.find_child("LoadFile", true, false) as Button).pressed.emit()
	assert_eq(app.save.unlocked, 1, "it asks first")
	(app.screen.find_child("LoadFile", true, false) as Button).pressed.emit()
	assert_eq(app.save.unlocked, 6)
	assert_eq(app.save.items.size(), 1)
	assert_eq(Run.keys, app.save)
	assert_eq(SaveStore.load_save().unlocked, 6, "and it is the save now")
	assert_string_contains((app.screen.find_child("FileNote", true, false) as Label).text, "Loaded")
	app._unhandled_input(key(KEY_ESCAPE))
	assert_eq(app.state, "setup")
	# the title has a way to the gear too
	app.show_title()
	(app.screen.find_child("Gear", true, false) as Button).pressed.emit()
	assert_eq(app.state, "gear")
	(app.screen.find_child("Back", true, false) as Button).pressed.emit()
	assert_eq(app.state, "title")
