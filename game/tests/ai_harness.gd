class_name AIHarness
extends RefCounted

# For tests: an all-rules run of a level with no scene. Line of sight and footing come from the
# level's own geometry, and units walk straight at their goals, sliding along what they cannot
# cross. It is a stand-in for the engine's navigation, good enough to test what the AI decides.

const DT := 1.0 / 60.0
const EYE := 1.3
const HERO_SPEED := 8.5
const ENEMY_SPEED := 6.5

var level: LevelDef
var combat: Combat
var events: Array[Dictionary] = []

var _side := {}  # unit id -> which way it goes round things


func _init(def: LevelDef, party: Array, run_level := 1, rng_seed := 1, autoplay := true, player_slot := 0, route: Route = null) -> void:
	level = def
	combat = Combat.new(run_level, rng_seed)
	combat.autoplay = autoplay
	# the closures below hold these lists, not this object or the rules, so nothing is kept alive in a ring
	var log := events
	var columns := combat.pillars
	combat.event.connect(func(e: Dictionary) -> void: log.append(e))
	for p in def.pillars:
		columns.append({"pos": p.pos, "r": p.r, "alive": true})
	var standing := func() -> Array: return columns.map(func(p: Dictionary) -> bool: return p.alive)
	combat.los = func(a: Vector3, b: Vector3) -> bool: return def.clear_line(a, b, EYE, 0.0, standing.call())
	combat.blocker = func(a: Vector3, b: Vector3) -> int: return def.pillar_between(a, b, standing.call())
	combat.can_stand = func(p: Vector3) -> bool: return def.can_stand(p)
	combat.clear_walk = func(a: Vector3, b: Vector3) -> bool: return def.clear_line(a, b, 0.0, 0.4, standing.call())
	for i in party.size():
		var h := combat.add_hero(Heroes.by_id(party[i]), i == player_slot)
		h.pos = def.start + Vector3(-i * 1.6, 0, 1.2 if i % 2 else -1.2)
	combat.enter(def, route)


func tick() -> void:
	var everyone: Array[Combatant] = combat.heroes + combat.enemies
	for u in everyone:
		u.moved = false
		if not u.alive or not u.has_goal or (u.is_player and not combat.autoplay):
			continue
		var step := (HERO_SPEED if u.hero else ENEMY_SPEED) * DT
		var to := _next_stop(u) - u.pos
		to.y = 0
		if to.length() < 0.05:
			continue
		var move := to.limit_length(step)
		# straight there if it can, else round whatever is in the way, keeping to the side it chose
		var side: float = _side.get(u.id, 1.0)
		for turn: float in [0.0, 0.8 * side, -0.8 * side, 1.5 * side, -1.5 * side]:
			var attempt := move.rotated(Vector3.UP, turn)
			if level.can_stand(u.pos + attempt, 0.4):
				if turn != 0.0:
					_side[u.id] = signf(turn)
				u.pos += attempt
				u.moved = true
				u.move_dir = attempt.normalized()
				u.last_move_t = combat.time
				u.facing = u.move_dir
				break
	for u in everyone:
		if u.alive and not u.moved:
			var t := combat.unit(u.target_id)
			if t and t.alive and t.team != u.team:
				u.facing = Combat.toward(u, t)
	combat.tick(DT)


# Where to head for: the goal if the way is clear, else the middle of the doorway that leads
# towards it.
func _next_stop(u: Combatant) -> Vector3:
	if level.clear_line(u.pos, u.goal, 0.0, 0.4):
		return u.goal
	# in a doorway already: on through its middle, unless that leads away
	var here := level.door_at(u.pos)
	if here >= 0 and level.room_at(u.pos) < 0:
		var middle: Vector3 = level.doors[here].pos
		if Combat.flat(u.pos, middle) > 0.3 and Combat.flat(middle, u.goal) < Combat.flat(u.pos, u.goal):
			return middle
	var way := level.doors_between(u.pos, u.goal)
	return level.doors[way[0]].pos if not way.is_empty() else u.goal


func run_for(seconds: float) -> void:
	for i in roundi(seconds / DT):
		tick()


## Runs until the condition holds or the time is up. True if it held.
func run_until(what: Callable, at_most: float) -> bool:
	for i in roundi(at_most / DT):
		if what.call():
			return true
		tick()
	return what.call()


func of(kind: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e.k == kind)
