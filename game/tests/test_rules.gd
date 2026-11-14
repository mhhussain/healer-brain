extends GutTest

# Milestone 3: the full rules, on their own, with no scene: every hero and enemy, casts, auras,
# threat, interrupts, dispels, telegraphed zones, packs and level scaling.

const DT := 1.0 / 60.0
const FAR := Vector3(200, 0, 0)

var combat: Combat
var pack: Pack
var events: Array[Dictionary]


## A run with those heroes standing in a row from the origin, and one empty pack.
func start(hero_ids: Array, level := 1) -> void:
	combat = Combat.new(level, 7)
	combat.endless = true
	combat.ai_plays = false
	events = []
	combat.event.connect(func(e: Dictionary) -> void: events.append(e))
	for i in hero_ids.size():
		var h := combat.add_hero(Heroes.by_id(hero_ids[i]), i == 0)
		h.pos = Vector3(-i * 1.5, 0, 0)
	pack = combat.add_pack()


func enemy(def_id: String, at: Vector3) -> Combatant:
	return combat.spawn_enemy(def_id, at, 0)


func run_for(seconds: float) -> void:
	for i in roundi(seconds / DT):
		combat.tick(DT)


func run_until(what: Callable, at_most := 30.0) -> bool:
	for i in roundi(at_most / DT):
		if what.call():
			return true
		combat.tick(DT)
	return what.call()


func of(kind: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e.k == kind)


func hits_on(u: Combatant) -> Array:
	return of("hit").filter(func(e: Dictionary) -> bool: return e.id == u.id).map(func(e: Dictionary) -> float: return e.amt)


# ---------- the kits

func test_every_ability_of_every_hero_goes_off():
	for id in Heroes.ALL:
		start([id])
		var h := combat.player
		var e := enemy("brute", Vector3(2, 0, 0))
		assert_eq(h.hero.abilities.size(), 6, id)
		for idx in 6:
			var ab := h.hero.abilities[idx]
			h.gcd = 0.0
			h.cast = null
			h.res = h.res_max
			h.combo = 3
			assert_eq(combat.use_ability(h, idx, e if ab.target == "enemy" else h), "", "%s: %s" % [id, ab.name])
			run_for(ab.cast + 0.1)
			var fired := of("ability").filter(func(ev: Dictionary) -> bool: return ev.s == ab.id)
			assert_eq(fired.size(), 1, "%s: %s went off" % [id, ab.name])


func test_every_enemy_fights_at_level_9_without_breaking():
	start(["warden", "mender", "duelist", "pyromancer"], 9)
	combat.endless = false
	var kinds := ["brute", "hexer", "archer", "shaman", "berserker", "overseer", "krogg", "velisse", "sulmar"]
	for i in kinds.size():
		enemy(kinds[i], Vector3(4 + i, 0, (i % 3) * 2.0))
	for e in combat.enemies:
		e.hp = e.max_hp * 0.6
	combat.engage(pack, combat.heroes[0])
	run_for(90.0)
	assert_gt(of("wipe").size(), 0, "four heroes standing still are beaten")
	assert_gt(of("boom").size(), 0, "telegraphs went off")
	assert_false(combat.finished)


func test_the_duelist_builds_and_spends_combo_points():
	start(["duelist"])
	var h := combat.player
	var e := enemy("brute", Vector3(2, 0, 0))
	combat.use_ability(h, 0, e)
	h.gcd = 0.0
	combat.use_ability(h, 1, h)
	assert_eq(h.combo, 2)
	assert_eq(h.res, 15.0)
	h.gcd = 0.0
	assert_eq(combat.use_ability(h, 2, e), "Not enough nerve")
	h.res = 100.0
	var before := e.hp
	assert_eq(combat.use_ability(h, 2, e), "")
	assert_eq(before - e.hp, 90.0, "45 a point")
	assert_eq(h.combo, 0)
	h.gcd = 0.0
	assert_eq(combat.use_ability(h, 2, e), "No combo points")
	assert_false(combat.ability_state(h, 2).usable)


func test_wreckers_luck_adds_damage_and_nerve():
	start(["duelist"])
	var h := combat.player
	var e := enemy("brute", FAR)
	combat.engage(pack, h)
	combat.use_ability(h, 5, h)
	assert_eq(combat.damage(h, e, 100.0), 120.0)
	h.res = 0.0
	run_for(1.0)
	assert_almost_eq(h.res, 40.0, 0.7, "20 a second, doubled")


func test_gulls_eye_speeds_the_harpooner_up():
	start(["ranger"])
	var h := combat.player
	var e := enemy("brute", Vector3(29, 0, 0))
	h.res = 0.0
	combat.use_ability(h, 5, h)
	combat.use_ability(h, 0, e)
	assert_eq(h.res, 30.0, "Snap Throw gives double focus")
	h.target_id = e.id
	events.clear()
	run_for(3.3)
	# every 1.6 / 1.5 s: at 0, 1.07, 2.13 and 3.2 s
	assert_eq(hits_on(e).size(), 4)


func test_a_roll_asks_the_scene_to_move_her():
	start(["ranger"])
	var h := combat.player
	h.facing = Vector3.RIGHT
	combat.use_ability(h, 4, h)
	var dash := of("dash")[0]
	assert_eq(dash.dir, Vector3.LEFT, "standing still, she rolls backwards")
	assert_eq(dash.dist, 8.0)
	assert_eq(combat.damage(null, h, 100.0), 70.0)


# ---------- casts

func test_a_cast_takes_its_time():
	start(["mender"])
	var h := combat.player
	h.hp = 500.0
	assert_eq(combat.use_ability(h, 0, h), "")
	assert_not_null(h.cast)
	assert_eq(h.hp, 500.0, "nothing yet")
	assert_eq(h.res, 1000.0)
	assert_eq(combat.use_ability(h, 1, h), "gcd", "nothing else while casting")
	enemy("brute", FAR)
	combat.engage(pack, h)
	run_for(1.9)
	assert_not_null(h.cast)
	run_for(0.2)
	assert_null(h.cast)
	assert_eq(h.hp, 920.0)
	assert_almost_eq(h.res, 960.0, 1.0, "paid for when it lands")


func test_moving_stops_a_cast():
	start(["mender"])
	var h := combat.player
	h.hp = 500.0
	enemy("brute", FAR)
	combat.engage(pack, h)
	combat.use_ability(h, 0, h)
	run_for(1.0)
	h.moved = true
	combat.tick(DT)
	assert_null(h.cast)
	h.gcd = 0.0
	assert_eq(combat.use_ability(h, 0, h), "Cannot cast while moving")
	assert_eq(combat.use_ability(h, 1, h), "", "but an instant spell is fine on the move")
	assert_eq(h.hp, 830.0)


func test_steady_flame_halves_wickfire():
	start(["pyromancer"])
	var h := combat.player
	var e := enemy("brute", Vector3(20, 0, 0))
	assert_eq(combat.cast_time(h, h.hero.abilities[0]), 2.0)
	combat.use_ability(h, 5, h)
	assert_eq(combat.cast_time(h, h.hero.abilities[0]), 1.0)
	combat.use_ability(h, 0, e)
	run_for(1.05)
	assert_eq(e.max_hp - e.hp, 170.0)
	assert_eq(h.res, 25.0)


func test_a_cast_fails_if_the_target_gets_away():
	start(["pyromancer"])
	var h := combat.player
	var e := enemy("brute", Vector3(20, 0, 0))
	combat.use_ability(h, 0, e)
	e.pos = Vector3(60, 0, 0)
	run_for(2.1)
	assert_eq(e.hp, e.max_hp)
	assert_eq(h.res, 0.0)


# ---------- auras

func test_brace_and_seawall_cut_damage():
	start(["warden"])
	var h := combat.player
	h.res = 100.0
	assert_eq(combat.damage(null, h, 100.0, "phys"), 100.0)
	combat.use_ability(h, 4, h)
	assert_eq(h.res, 60.0)
	assert_eq(combat.damage(null, h, 100.0, "phys"), 50.0)
	assert_eq(combat.damage(null, h, 100.0, "magic"), 100.0, "Brace is against physical blows only")
	h.hp = 1000.0
	combat.use_ability(h, 5, h)
	assert_eq(h.hp, 1480.0, "Seawall heals a fifth")
	assert_eq(combat.damage(null, h, 100.0, "magic"), 60.0)
	assert_eq(combat.damage(null, h, 100.0, "phys"), 30.0)
	run_for(6.1)
	assert_false(combat.has_aura(h, "brace"), "Brace runs out after 6 s")
	assert_true(combat.has_aura(h, "unbreakable"))


func test_a_shield_soaks_damage_and_counts_as_healing():
	start(["bloomweaver"])
	var h := combat.player
	combat.use_ability(h, 1, h)
	assert_eq(combat.damage(null, h, 200.0), 0.0)
	assert_eq(h.hp, 1200.0)
	assert_eq(h.stats.heal, 200.0)
	assert_eq(combat.damage(null, h, 300.0), 150.0, "the last 150 of the shield, then through")
	combat.tick(DT)
	assert_false(combat.has_aura(h, "bark"), "a spent shield is gone")


func test_kelp_heals_over_time_and_green_tide_doubles_it():
	start(["bloomweaver", "warden"])
	var h := combat.player
	var w := combat.heroes[1]
	enemy("brute", FAR)
	combat.engage(pack, h)
	h.hp = 100.0
	combat.use_ability(h, 0, h)
	run_for(14.2)
	assert_eq(h.hp, 100.0 + 7 * 60.0, "60 every 2 s for 14 s")
	assert_false(combat.has_aura(h, "vine"))
	h.hp = 100.0
	w.hp = 100.0
	h.gcd = 0.0
	combat.use_ability(h, 5, h)
	assert_true(combat.has_aura(w, "vine"), "Green Tide puts kelp on everyone")
	run_for(2.05)
	assert_eq(w.hp, 220.0, "two ticks in two seconds")
	h.gcd = 0.0
	combat.use_ability(h, 1, w)
	assert_eq(h.cds["bark"], 0.0, "and Shell Ward has no cooldown")
	h.gcd = 0.0
	w.hp = 100.0
	combat.use_ability(h, 2, h)
	assert_eq(w.hp, 340.0, "Kelp Bloom heals those with kelp")


func test_tallow_burn_burns_and_starts_the_fight():
	start(["pyromancer"])
	var h := combat.player
	var e := enemy("brute", Vector3(29, 0, 0))
	combat.use_ability(h, 1, e)
	assert_true(e.engaged)
	assert_eq(h.res, 10.0)
	h.gcd = 0.0
	combat.use_ability(h, 1, e)
	assert_eq(e.auras.size(), 1, "one burn per enemy")
	assert_true(e.auras[0].debuff)
	run_for(12.1)
	assert_eq(e.max_hp - e.hp, 240.0)
	assert_eq(e.auras.size(), 0)
	assert_eq(h.stats.dmg, 240.0)


func test_sanctuary_heals_now_and_over_time():
	start(["mender", "warden"])
	var h := combat.player
	var w := combat.heroes[1]
	enemy("brute", FAR)
	combat.engage(pack, h)
	w.hp = 100.0
	combat.use_ability(h, 5, h)
	assert_eq(w.hp, 400.0)
	run_for(8.1)
	assert_eq(w.hp, 1000.0)


func test_warm_light_spills_onto_the_worst_hurt_neighbour():
	start(["mender", "warden", "duelist"])
	var h := combat.player
	var w := combat.heroes[1]
	var d := combat.heroes[2]
	enemy("brute", FAR)
	combat.engage(pack, h)
	w.hp = 1000.0
	d.hp = 300.0
	combat.use_ability(h, 0, w)
	run_for(2.05)
	assert_eq(w.hp, 1420.0)
	assert_eq(d.hp, 426.0)


# ---------- threat

func test_an_enemy_goes_for_whoever_threatens_it_most():
	start(["warden", "ranger"])
	var w := combat.heroes[0]
	var r := combat.heroes[1]
	var e := enemy("brute", Vector3(2, 0, 0))
	r.pos = Vector3(-20, 0, 0)
	combat.use_ability(r, 1, e)
	combat.tick(DT)
	assert_eq(e.target_id, r.id)
	combat.use_ability(w, 0, e)
	combat.tick(DT)
	assert_eq(e.target_id, w.id, "the Warden's blows count four times over")
	combat.add_threat(e, r.id, 300.0)
	combat.tick(DT)
	assert_eq(e.target_id, w.id, "a little ahead is not enough to pull it off")
	combat.add_threat(e, r.id, 300.0)
	combat.tick(DT)
	assert_eq(e.target_id, r.id)


func test_a_taunt_forces_the_enemy_and_shows_as_a_debuff():
	start(["warden", "ranger"])
	var w := combat.heroes[0]
	var r := combat.heroes[1]
	var e := enemy("brute", Vector3(20, 0, 0))
	combat.add_threat(e, r.id, 5000.0)
	combat.use_ability(w, 2, e)
	combat.tick(DT)
	assert_eq(e.target_id, w.id)
	assert_gt(e.threat[w.id], 5000.0, "top of the list")
	var aura := e.auras[0]
	assert_eq(aura.name, "Pilot's Hail")
	assert_true(aura.debuff)
	assert_almost_eq(aura.t, 4.0, 0.05)
	assert_true(pack.engaged, "and it pulls")
	assert_almost_eq(pack.tank_hit_at, 0.0, 0.001)


func test_healing_threat_is_shared_between_the_enemies():
	start(["mender"])
	var h := combat.player
	var a := enemy("brute", FAR)
	var b := enemy("brute", FAR)
	combat.engage(pack, h)
	h.hp = 100.0
	combat.use_ability(h, 1, h)
	assert_eq(a.threat[h.id], 1.0 + 330.0 * 0.5 / 2)
	assert_eq(b.threat[h.id], a.threat[h.id])


func test_damage_dealers_wait_for_the_tank():
	start(["warden", "ranger"])
	var w := combat.heroes[0]
	enemy("brute", FAR)
	assert_false(combat.can_attack(), "nothing to attack yet")
	combat.engage(pack, w)
	assert_false(combat.can_attack())
	run_for(4.1)
	assert_true(combat.can_attack(), "after 4 s with no blow from the tank")
	start(["warden", "ranger"])
	var e := enemy("brute", Vector3(2, 0, 0))
	combat.use_ability(combat.heroes[0], 0, e)
	run_for(1.4)
	assert_false(combat.can_attack())
	run_for(0.2)
	assert_true(combat.can_attack(), "1.5 s after the tank's first blow")


# ---------- interrupts and dispels

func test_an_interrupt_stops_a_cast_and_locks_it_out():
	start(["ranger"])
	var h := combat.player
	var e := enemy("hexer", Vector3(15, 0, 0))
	combat.engage(pack, h)
	assert_true(run_until(func() -> bool: return e.cast != null, 3.0), "the Cantor starts a Sour Note")
	assert_eq(e.cast.name, "Sour Note")
	assert_true(e.cast.interruptible)
	assert_eq(combat.use_ability(h, 3, e), "")
	assert_null(e.cast)
	assert_eq(e.cds["darkbolt"], 3.0)
	assert_eq(h.stats.interrupts, 1)
	assert_eq(of("interrupt").size(), 1)
	h.cds.clear()
	combat.use_ability(h, 3, e)
	assert_eq(h.stats.interrupts, 1, "with nothing to silence it is wasted")
	assert_eq(of("text")[-1].s, "Nothing to silence")
	assert_eq(hits_on(h).size(), 0, "and the note never landed")


func test_a_cast_left_alone_lands():
	start(["ranger"])
	var h := combat.player
	enemy("hexer", Vector3(15, 0, 0))
	combat.engage(pack, h)
	run_for(5.0)
	assert_eq(hits_on(h)[0], 165.0)


func test_an_enemy_walks_until_it_can_see_its_target():
	start(["ranger"])
	var h := combat.player
	var e := enemy("hexer", Vector3(15, 0, 0))
	combat.los = func(a: Vector3, b: Vector3) -> bool: return absf(a.x - b.x) < 8.0
	combat.engage(pack, h)
	run_for(3.0)
	assert_null(e.cast)
	assert_true(e.has_goal, "it comes round to find a line")
	e.pos = Vector3(6, 0, 0)
	assert_true(run_until(func() -> bool: return e.cast != null, 1.0))


func test_a_curse_can_be_lifted():
	start(["mender"], 3)
	var h := combat.player
	enemy("hexer", Vector3(15, 0, 0))
	combat.engage(pack, h)
	assert_true(run_until(func() -> bool: return combat.has_aura(h, "wither"), 16.0), "Withering Verse from level 3")
	combat.add_aura(h, {"id": "ward", "name": "Lantern Ward", "dur": 6.0, "src_id": h.id, "taken": 0.6})
	h.gcd = 0.0
	assert_eq(combat.use_ability(h, 3, h), "")
	assert_false(combat.has_aura(h, "wither"))
	assert_true(combat.has_aura(h, "ward"), "only curses are lifted")
	assert_eq(h.stats.dispels, 1)
	assert_eq(of("dispel").size(), 1)


func test_two_casts_go_to_two_different_heroes():
	start(["warden", "ranger", "pyromancer"])
	var a := enemy("hexer", Vector3(15, 0, 0))
	var b := enemy("hexer", Vector3(15, 0, 3))
	combat.engage(pack, combat.heroes[0])
	assert_true(run_until(func() -> bool: return a.cast != null and b.cast != null and a.cast.assignee > 0 and b.cast.assignee > 0, 4.0))
	assert_ne(a.cast.assignee, b.cast.assignee)
	assert_ne(a.cast.assignee, combat.heroes[0].id, "the Warden's bash does not reach")


# ---------- telegraphs

func test_zone_shapes():
	var circle := Zone.make({"kind": "circle", "pos": Vector3(10, 0, 10), "r": 3.0})
	assert_true(circle.holds(Vector3(12, 0, 11)))
	assert_false(circle.holds(Vector3(13.5, 0, 10)))
	assert_true(circle.holds(Vector3(13.5, 0, 10), 1.0), "a margin widens it")
	var cone := Zone.make({"kind": "cone", "pos": Vector3.ZERO, "r": 9.0, "dir": Vector3.RIGHT, "half": 0.87})
	assert_true(cone.holds(Vector3(5, 0, 0)))
	assert_true(cone.holds(Vector3(4, 0, 4)), "45 degrees off is inside a 50 degree half-width")
	assert_false(cone.holds(Vector3(0, 0, 5)), "to the side")
	assert_false(cone.holds(Vector3(-3, 0, 0)), "behind")
	assert_true(cone.holds(Vector3(-0.3, 0, 0)), "right on top of it counts")
	assert_false(cone.holds(Vector3(10, 0, 0)), "past the end")


func test_a_sweep_hits_whoever_stays_in_front():
	start(["warden", "duelist"])
	var w := combat.heroes[0]
	var d := combat.heroes[1]
	var e := enemy("overseer", Vector3(2, 0, 0))
	d.pos = Vector3(4.5, 0, 0)
	combat.use_ability(w, 0, e)
	assert_true(run_until(func() -> bool: return e.cast != null, 6.0))
	assert_eq(e.cast.name, "Banner Sweep")
	assert_eq(e.cast.dir, Vector3.LEFT, "aimed at the tank")
	assert_eq(combat.zones.size(), 1)
	assert_true(combat.zones[0].holds(w.pos))
	assert_false(combat.zones[0].holds(d.pos), "behind it is safe")
	run_for(2.1)
	assert_true(hits_on(w).has(380.0))
	assert_false(hits_on(d).has(380.0))
	assert_eq(combat.zones.size(), 0)
	assert_eq(of("boom").size(), 1)


func test_a_telegraph_goes_if_its_caster_dies():
	start(["warden"])
	var w := combat.player
	var e := enemy("overseer", Vector3(2, 0, 0))
	combat.use_ability(w, 0, e)
	run_until(func() -> bool: return e.cast != null, 6.0)
	combat.damage(w, e, 99999.0)
	combat.tick(DT)
	assert_eq(combat.zones.size(), 0)
	assert_eq(of("boom").size(), 0)


func test_hooks_fall_where_the_target_stood():
	start(["ranger"], 3)
	var h := combat.player
	var e := enemy("archer", Vector3(15, 0, 0))
	combat.engage(pack, h)
	e.cds["arrowrain"] = 0.0
	run_for(0.5)
	assert_eq(combat.zones.size(), 1)
	h.pos = Vector3(-10, 0, 0)
	events.clear()
	run_for(1.5)
	assert_eq(of("boom").size(), 1)
	assert_false(hits_on(h).has(roundf(210.0 * combat.scale)), "she stepped out in time")


# ---------- packs and levels

func test_a_pack_fights_as_one_and_is_cleared_together():
	start(["ranger"])
	combat.endless = false
	var h := combat.player
	var a := enemy("brute", Vector3(25, 0, 0))
	var b := enemy("brute", Vector3(25, 0, 3))
	combat.use_ability(h, 0, a)
	assert_true(b.engaged, "hit one and they all come")
	assert_true(combat.started)
	combat.damage(h, a, 99999.0)
	combat.tick(DT)
	assert_true(combat.in_combat)
	combat.damage(h, b, 99999.0)
	combat.tick(DT)
	assert_true(pack.cleared)
	assert_eq(of("clear").size(), 1)
	assert_false(combat.in_combat)
	assert_true(combat.finished, "that was the only pack")
	assert_true(combat.timed())


func test_the_fallen_get_up_after_the_fight():
	start(["warden", "ranger"])
	var w := combat.heroes[0]
	var r := combat.heroes[1]
	var e := enemy("brute", Vector3(2, 0, 0))
	combat.use_ability(w, 0, e)
	combat.damage(e, r, 99999.0, "phys", {"raw": true})
	assert_false(r.alive)
	assert_eq(combat.deaths, 1)
	run_for(1.0)
	assert_false(r.alive, "not while the fight goes on")
	combat.damage(w, e, 99999.0)
	combat.tick(DT)
	assert_true(r.alive)
	assert_eq(r.hp, 480.0)


func test_enemies_grow_with_the_level():
	start(["warden"], 5)
	var e := enemy("brute", Vector3(2, 0, 0))
	assert_almost_eq(combat.scale, 1.3605, 0.0001)
	assert_eq(e.max_hp, 3129.0)
	assert_eq(combat.damage(e, combat.player, 100.0), 136.0)
	assert_eq(combat.damage(combat.player, e, 100.0), 100.0, "heroes do not")


func test_new_abilities_arrive_at_level_3():
	start(["warden"], 1)
	var e := enemy("brute", Vector3(2, 0, 0))
	combat.use_ability(combat.player, 0, e)
	run_for(8.0)
	assert_false(hits_on(combat.player).has(240.0), "no Heavy Load at level 1")
	start(["warden"], 3)
	e = enemy("brute", Vector3(2, 0, 0))
	combat.use_ability(combat.player, 0, e)
	run_for(8.0)
	assert_true(hits_on(combat.player).has(roundf(240.0 * combat.scale)), "Heavy Load from level 3")


func test_a_penitent_flies_into_a_fervour():
	start(["warden"])
	var w := combat.player
	var e := enemy("berserker", Vector3(2, 0, 0))
	combat.use_ability(w, 0, e)
	combat.tick(DT)
	assert_false(combat.has_aura(e, "enrage"))
	e.hp = e.max_hp * 0.25
	combat.tick(DT)
	assert_true(combat.has_aura(e, "enrage"))
	assert_eq(combat.damage(e, w, 100.0), 125.0)


func test_the_prior_makes_his_brothers_hit_harder_from_level_3():
	start(["warden"], 3)
	var w := combat.player
	var prior := enemy("overseer", Vector3(2, 0, 0))
	var porter := enemy("brute", Vector3(2, 0, 2))
	combat.engage(pack, w)
	assert_eq(combat.damage(porter, w, 100.0), roundf(100.0 * combat.scale * 1.15))
	assert_eq(combat.damage(prior, w, 100.0), roundf(100.0 * combat.scale), "not himself")


# ---------- the bosses

func test_velisse_wakes_brinelings_and_a_wipe_clears_them_away():
	start(["warden", "ranger"])
	var v := enemy("velisse", Vector3(2, 0, 0))
	combat.engage(pack, combat.heroes[0])
	run_for(8.2)
	assert_eq(of("spawn").size(), 3)
	assert_eq(combat.enemies.size(), 4)
	assert_true(combat.enemies[-1].engaged, "they wake fighting")
	assert_true(combat.enemies[-1].summoned)
	for h in combat.heroes:
		combat.damage(v, h, 99999.0, "phys", {"raw": true})
	combat.tick(DT)
	assert_eq(of("wipe").size(), 1)
	assert_eq(of("despawn").size(), 3)
	assert_eq(combat.enemies.size(), 1)
	assert_eq(pack.units.size(), 1)
	assert_false(v.engaged)


func test_the_last_toll_spares_those_behind_a_pillar():
	start(["warden", "ranger"], 6)
	var w := combat.heroes[0]
	var r := combat.heroes[1]
	r.pos = Vector3(60, 0, 0)
	# anyone past x = 50 is behind pillar 2
	combat.los = func(a: Vector3, b: Vector3) -> bool: return maxf(a.x, b.x) < 50.0
	combat.blocker = func(a: Vector3, b: Vector3) -> int: return 2 if maxf(a.x, b.x) >= 50.0 else -1
	var s := enemy("sulmar", Vector3(2, 0, 0))
	combat.engage(pack, w)
	for ab in s.enemy.abilities:
		s.cds[ab.id] = 99.0
	s.cds["annihilation"] = 0.0
	s.hp = s.max_hp * 0.6
	w.hp = 99999.0
	assert_true(run_until(func() -> bool: return s.cast != null, 1.0))
	assert_eq(s.cast.name, "The Last Toll")
	assert_false(s.cast.interruptible)
	assert_eq(combat.hide_caster(), s)
	run_for(5.1)
	assert_true(hits_on(w).has(roundf(w.max_hp * 0.9)), "in the open: nine tenths of your health")
	assert_eq(hits_on(r).size(), 0)
	assert_eq(of("pillar").size(), 1, "from level 6 the pillar is spent")
	assert_eq(of("pillar")[0].id, 2)
	run_for(3.0)
	assert_null(s.cast, "once at two thirds, not again until one third")


func test_krogg_bars_the_gate_when_he_is_nearly_done():
	start(["warden"])
	var k := enemy("krogg", Vector3(2, 0, 0))
	combat.engage(pack, combat.player)
	k.hp = k.max_hp * 0.29
	combat.tick(DT)
	assert_true(combat.has_aura(k, "frenzy"))
	assert_eq(of("alert").size(), 1)


# ---------- the player

func test_with_no_target_you_take_the_tanks():
	start(["ranger", "warden"])
	var r := combat.player
	var w := combat.heroes[1]
	var e := enemy("brute", Vector3(20, 0, 0))
	assert_eq(combat.tank(), w, "the tank is found by role, not by place in the party")
	combat.press(0)
	combat.tick(DT)
	assert_eq(combat.error, "No target")
	w.target_id = e.id
	combat.press(0)
	combat.tick(DT)
	assert_eq(r.target_id, e.id)
	assert_true(hits_on(e).has(60.0))


func test_an_ally_spell_lands_on_the_ally_under_the_mouse():
	start(["mender", "warden"])
	var h := combat.player
	var w := combat.heroes[1]
	h.hp = 500.0
	w.hp = 500.0
	combat.hover_ally_id = w.id
	combat.press(1)
	combat.tick(DT)
	assert_almost_eq(w.hp, 830.0, 5.0)
	combat.hover_ally_id = 0
	h.gcd = 0.0
	combat.press(1)
	combat.tick(DT)
	assert_gt(h.hp, 829.0, "with nobody under the mouse, yourself")
