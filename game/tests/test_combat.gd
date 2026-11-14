extends GutTest

# Milestone 2: the rules of a fight, on their own, with no scene.

const DT := 1.0 / 60.0

var combat: Combat
var hero: Combatant
var pack: Pack
var enemy: Combatant
var events: Array[Dictionary]


func before_each():
	combat = Combat.new()
	hero = combat.add_hero(Heroes.by_id("ranger"), true)
	pack = combat.add_pack()
	enemy = combat.spawn_enemy("brute", Vector3(20, 0, 0), 0)
	hero.target_id = enemy.id
	events = []
	combat.event.connect(func(e: Dictionary) -> void: events.append(e))


func run_for(seconds: float) -> void:
	for i in roundi(seconds / DT):
		combat.tick(DT)


func count(kind: String, from_id := 0) -> int:
	return events.filter(func(e: Dictionary) -> bool:
		return e.k == kind and (from_id == 0 or e.get("src") == from_id)).size()


func test_an_ability_hits_and_starts_the_fight():
	assert_false(combat.in_combat)
	assert_eq(combat.use_ability(hero, 0, enemy), "")
	assert_eq(enemy.hp, 2300.0 - 60.0)
	assert_true(enemy.engaged, "the enemy joins the fight when it is hit")
	assert_true(combat.in_combat)


func test_the_global_cooldown_holds_the_next_ability():
	combat.use_ability(hero, 0, enemy)
	assert_eq(combat.use_ability(hero, 1, enemy), "gcd", "nothing else goes off straight away")
	run_for(1.4)
	assert_eq(combat.use_ability(hero, 0, enemy), "gcd")
	run_for(0.15)
	assert_eq(combat.use_ability(hero, 0, enemy), "", "it is ready after 1.5 s")


func test_a_press_just_before_ready_is_kept():
	combat.use_ability(hero, 0, enemy)
	enemy.auto_timer = 99.0
	run_for(1.2)
	combat.press(0)
	var before := count("ability")
	run_for(0.2)
	assert_eq(count("ability"), before, "still on the global cooldown")
	run_for(0.2)
	assert_eq(count("ability"), before + 1, "it went off as soon as it could")
	assert_eq(combat.error, "")


func test_a_press_too_early_is_dropped():
	combat.use_ability(hero, 0, enemy)
	enemy.auto_timer = 99.0
	var before := count("ability")
	combat.press(0)
	run_for(1.6)
	assert_eq(count("ability"), before, "a press a full second early does not wait for the cooldown")
	assert_eq(combat.error, "", "and the global cooldown says nothing about it")
	hero.cds["jarring"] = 10.0
	combat.press(3)
	run_for(0.1)
	assert_eq(combat.error, "Jarring Barb is not ready")
	run_for(1.6)
	assert_eq(combat.error, "", "the message clears")


func test_out_of_range_and_out_of_sight():
	enemy.pos = Vector3(40, 0, 0)
	assert_eq(combat.use_ability(hero, 0, enemy), "Out of range")
	enemy.pos = Vector3(20, 0, 0)
	combat.los = func(_a: Vector3, _b: Vector3) -> bool: return false
	assert_eq(combat.use_ability(hero, 0, enemy), "No line of sight")
	assert_eq(combat.use_ability(hero, 0, null), "No target")


func test_resource_is_spent_and_earned():
	hero.res = 50.0
	assert_eq(combat.use_ability(hero, 1, enemy), "", "Whaler's Lance costs 45 focus")
	assert_eq(hero.res, 5.0)
	assert_eq(enemy.hp, 2300.0 - 190.0)
	hero.gcd = 0.0
	assert_eq(combat.use_ability(hero, 1, enemy), "Not enough focus")
	assert_eq(combat.use_ability(hero, 0, enemy), "", "Snap Throw gives 15 back")
	assert_eq(hero.res, 20.0)
	hero.res = 95.0
	combat.gain(hero, 15.0)
	assert_eq(hero.res, 100.0, "it stops at the top")


func test_auto_attacks_wait_for_the_fight_then_keep_time():
	run_for(3.0)
	assert_eq(enemy.hp, 2300.0, "no auto-attack on an enemy that is not in the fight")
	# far enough that the enemy never reaches the hero in this test
	enemy.pos = Vector3(29, 0, 0)
	combat.use_ability(hero, 0, enemy)
	run_for(4.9)
	# one every 1.6 s, the first on the next tick: at 0, 1.6, 3.2 and 4.8 s
	assert_eq(count("hit", hero.id), 1 + 4)
	assert_eq(enemy.hp, 2300.0 - 60.0 - 4 * 50.0)


func test_an_enemy_notices_a_hero_who_comes_close():
	hero.pos = Vector3(5, 0, 0)
	run_for(0.5)
	assert_false(enemy.engaged, "15 m away is too far")
	hero.pos = Vector3(10, 0, 0)
	run_for(0.5)
	assert_true(enemy.engaged)
	assert_true(enemy.has_goal, "and it wants to walk to the hero")
	assert_lt(Combat.flat(enemy.goal, hero.pos), 2.0)


func test_an_enemy_in_reach_hits_on_its_timer():
	hero.pos = Vector3(18.5, 0, 0)
	combat.engage(pack, hero)
	run_for(3.1)
	assert_false(enemy.has_goal, "it is close enough to stand and fight")
	# at 0, 1.5 and 3.0 s
	assert_eq(count("hit", enemy.id), 3)
	assert_eq(hero.hp, 1200.0 - 3 * 46.0)


func test_death_and_the_end_of_the_fight():
	combat.endless = true
	enemy.pos = Vector3(29, 0, 0)
	enemy.hp = 50.0
	combat.use_ability(hero, 0, enemy)
	assert_false(enemy.alive)
	assert_eq(count("death"), 1)
	combat.tick(DT)
	assert_false(combat.in_combat)
	hero.hp = 600.0
	hero.res = 0.0
	run_for(2.0)
	assert_almost_eq(hero.hp, 600.0 + 240.0, 1.0, "out of a fight, health comes back at 10% a second")
	assert_almost_eq(hero.res, 20.0, 0.5)


func test_a_wipe_sends_the_enemy_home_and_the_hero_starts_again():
	pack.entry = Vector3(2, 0, 1.5)
	hero.pos = Vector3(18.5, 0, 0)
	combat.use_ability(hero, 0, enemy)
	hero.hp = 40.0
	hero.res = 12.0
	combat.tick(DT)
	assert_eq(count("death"), 1, "the first blow lands and the hero falls")
	assert_eq(count("wipe"), 1)
	assert_false(enemy.engaged)
	assert_eq(enemy.hp, enemy.max_hp, "the enemy is healed")
	assert_true(hero.alive, "and the hero starts again from the way in")
	assert_eq(hero.hp, hero.max_hp)
	assert_eq(hero.res, 100.0)
	assert_eq(hero.pos, Vector3(0, 0, 0))
	assert_false(combat.in_combat)


func test_tab_takes_the_nearest_enemy_in_sight():
	var far := combat.spawn_enemy("brute", Vector3(30, 0, 0), 0)
	hero.target_id = 0
	combat.tab_target()
	assert_eq(hero.target_id, enemy.id)
	combat.tab_target()
	assert_eq(hero.target_id, far.id)
	combat.tab_target()
	assert_eq(hero.target_id, enemy.id, "and round again")
	combat.los = func(_a: Vector3, b: Vector3) -> bool: return b.x > 25.0
	hero.target_id = 0
	combat.tab_target()
	assert_eq(hero.target_id, far.id, "an enemy out of sight is skipped")


func test_the_button_shows_the_cooldown():
	var st := combat.ability_state(hero, 0)
	assert_eq(st.cd, 0.0)
	assert_true(st.usable)
	combat.use_ability(hero, 0, enemy)
	st = combat.ability_state(hero, 1)
	assert_eq(st.cd, 1.5)
	assert_eq(st.cd_max, 1.5)
	hero.res = 10.0
	assert_false(combat.ability_state(hero, 1).usable, "too little focus")
	enemy.pos = Vector3(60, 0, 0)
	assert_false(combat.ability_state(hero, 0).usable, "out of range")
