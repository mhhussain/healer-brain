class_name Combat
extends RefCounted

# The rules of a fight: cooldowns, the global cooldown, auto-attacks, damage, threat and who is
# in combat. It knows nothing about the scene. The scene tells each Combatant where it stands,
# calls tick() 60 times a second, and reacts to the events emitted here.
# Ported from src/sim/world.ts a milestone at a time.

## Something happened: {"k": kind, ...}. Kinds: hit, heal, death, ability, engage, wipe, revive.
signal event(e: Dictionary)

## How near a hero must come for an enemy to notice, in metres.
const AGGRO := 11.0
## A press this long before an ability is ready still goes off, the moment it can.
const QUEUE_WINDOW := 0.5
const TAB_RANGE := 45.0

var time := 0.0
var units: Array[Combatant] = []
var heroes: Array[Combatant] = []
var enemies: Array[Combatant] = []
var player: Combatant
var in_combat := false

## Whether one spot can see another: func(a: Vector3, b: Vector3) -> bool. The scene supplies a
## ray cast against the walls; on its own, everything can see everything.
var los := func(_a: Vector3, _b: Vector3) -> bool: return true

## Why the player's last press did nothing, for the interface to show, and how long ago.
var error := ""
var error_t := 0.0

var _queued := {}
var _next_id := 1


# ---------- who is in the fight

func add_hero(def: HeroDef, is_player := false) -> Combatant:
	var u := _add("hero", def.name)
	u.hero = def
	u.is_player = is_player
	u.max_hp = def.hp
	u.hp = def.hp
	u.res_max = def.res_max
	u.res = def.res_start
	heroes.append(u)
	if is_player:
		player = u
	return u


func add_enemy(def: EnemyDef, at := Vector3.ZERO) -> Combatant:
	var u := _add("enemy", def.name)
	u.enemy = def
	u.radius = def.radius
	u.max_hp = def.hp
	u.hp = def.hp
	u.pos = at
	u.home = at
	enemies.append(u)
	return u


func _add(team: String, name: String) -> Combatant:
	var u := Combatant.new()
	u.id = _next_id
	_next_id += 1
	u.team = team
	u.name = name
	units.append(u)
	return u


func unit(id: int) -> Combatant:
	for u in units:
		if u.id == id:
			return u
	return null


static func dist(a: Combatant, b: Combatant) -> float:
	return Vector2(a.pos.x - b.pos.x, a.pos.z - b.pos.z).length()


func sees(a: Combatant, b: Combatant) -> bool:
	return los.call(a.pos, b.pos)


# ---------- damage, healing, threat

func gain(u: Combatant, n: float) -> void:
	u.res = clampf(u.res + n, 0.0, u.res_max)


## Returns the damage dealt. `type` is "phys" or "magic".
func damage(src: Combatant, tgt: Combatant, amount: float, type := "phys") -> float:
	if not tgt.alive:
		return 0.0
	var a := roundf(amount)
	tgt.hp -= a
	event.emit({"k": "hit", "id": tgt.id, "src": src.id if src else -1, "amt": a, "s": type})
	if tgt.team == "enemy" and src and src.hero:
		src.stats.dmg += a
		engage(tgt, src)
		add_threat(tgt, src.id, a * src.hero.threat_mult)
	if tgt.hp <= 0.0:
		_kill(tgt)
	return a


## Returns the health restored.
func heal(src: Combatant, tgt: Combatant, amount: float) -> float:
	if not tgt.alive:
		return 0.0
	var eff := roundf(minf(tgt.max_hp - tgt.hp, amount))
	tgt.hp += eff
	if eff > 0.0:
		src.stats.heal += eff
		event.emit({"k": "heal", "id": tgt.id, "src": src.id, "amt": eff})
	return eff


func _kill(u: Combatant) -> void:
	u.alive = false
	u.hp = 0.0
	u.has_goal = false
	if u.team == "hero":
		u.stats.deaths += 1
	event.emit({"k": "death", "id": u.id})


func add_threat(e: Combatant, hero_id: int, amt: float) -> void:
	e.threat[hero_id] = e.threat.get(hero_id, 0.0) + amt


## The enemy joins the fight against that hero.
func engage(e: Combatant, hero: Combatant) -> void:
	if e.engaged or not e.alive:
		return
	e.engaged = true
	in_combat = true
	e.auto_timer = 0.0
	add_threat(e, hero.id, 1.0)
	event.emit({"k": "engage", "id": e.id, "src": hero.id})


## The living hero highest on the enemy's threat list, or the nearest one it has not met.
func pick_threat_target(e: Combatant) -> Combatant:
	var best: Combatant = null
	var best_score := -INF
	for h in heroes:
		if not h.alive:
			continue
		var score: float = e.threat.get(h.id, 0.0) * 1000.0 - dist(e, h)
		if score > best_score:
			best_score = score
			best = h
	return best


# ---------- hero abilities

func _check_target(u: Combatant, ab: AbilityDef, t: Combatant) -> String:
	if ab.target == "self":
		return ""
	if t == null or not t.alive:
		return "No target" if ab.target == "enemy" else "Target is dead"
	if t == u:
		return ""
	if dist(u, t) > ab.reach + t.radius * 0.5:
		return "Out of range"
	if ab.reach > 5.0 and not sees(u, t):
		return "No line of sight"
	return ""


## Uses the ability now. Returns "" if it went off, "cd" or "gcd" if it is not ready, or the
## reason to show the player.
func use_ability(u: Combatant, idx: int, target: Combatant) -> String:
	var ab := u.hero.abilities[idx]
	if not u.alive:
		return "You are dead"
	if u.cds.get(ab.id, 0.0) > 0.0:
		return "cd"
	if not ab.off_gcd and u.gcd > 0.0:
		return "gcd"
	var t := u
	if ab.target == "enemy":
		t = target if target and target.team == "enemy" else null
	elif ab.target == "ally":
		t = target if target and target.team == "hero" else u
	var bad := _check_target(u, ab, t)
	if bad != "":
		return bad
	if ab.cost > 0.0 and u.res < ab.cost:
		return "Not enough " + u.hero.res_name.to_lower()
	if ab.usable.is_valid():
		var no: String = ab.usable.call(self, u)
		if no != "":
			return no
	_fire(u, ab, t)
	return ""


func _fire(u: Combatant, ab: AbilityDef, t: Combatant) -> void:
	u.res -= ab.cost
	if ab.cd > 0.0:
		u.cds[ab.id] = ab.cd
	if not ab.off_gcd:
		u.gcd = u.hero.gcd
	event.emit({"k": "ability", "id": u.id, "s": ab.id, "tgt": t.id})
	ab.fire.call(self, u, t)


## What an action button shows: {"cd": seconds left, "cd_max": out of how many, "usable": bool}.
func ability_state(u: Combatant, idx: int) -> Dictionary:
	var ab := u.hero.abilities[idx]
	var own: float = u.cds.get(ab.id, 0.0)
	var cd := maxf(own, 0.0 if ab.off_gcd else u.gcd)
	var cd_max := maxf(ab.cd, 1.0) if own > u.gcd or ab.off_gcd else u.hero.gcd
	var usable := u.alive and not (ab.cost > 0.0 and u.res < ab.cost)
	if usable and ab.target == "enemy":
		var t := unit(u.target_id)
		if t and t.alive:
			usable = _check_target(u, ab, t) == ""
	return {"cd": maxf(cd, 0.0), "cd_max": cd_max, "usable": usable}


# ---------- the player

## The player pressed an ability key. It goes off on the next tick, or as soon as it is ready if
## that is within the queue window.
func press(idx: int) -> void:
	if player == null or idx >= player.hero.abilities.size():
		return
	var ab := player.hero.abilities[idx]
	var target_id := 0
	if ab.target == "enemy":
		target_id = player.target_id
	elif ab.target == "ally":
		target_id = player.id
	_queued = {"idx": idx, "target_id": target_id, "until": time + QUEUE_WINDOW}


## Targets the next enemy in sight: those already fighting first, then the nearest.
func tab_target() -> void:
	var p := player
	var list := enemies.filter(func(e: Combatant) -> bool:
		return e.alive and dist(e, p) <= TAB_RANGE and sees(p, e))
	if list.is_empty():
		return
	list.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		if a.engaged != b.engaged:
			return a.engaged
		return dist(a, p) < dist(b, p))
	var i := -1
	for k in list.size():
		if list[k].id == p.target_id:
			i = k
	p.target_id = list[(i + 1) % list.size()].id


func _update_player() -> void:
	var p := player
	if p == null:
		return
	if not p.alive:
		_queued = {}
		return
	if _queued.is_empty():
		return
	var idx: int = _queued.idx
	var r := use_ability(p, idx, unit(_queued.target_id))
	if r == "":
		_queued = {}
		return
	var ab := p.hero.abilities[idx]
	var waiting: bool = r == "gcd" or (r == "cd" and p.cds.get(ab.id, 0.0) < QUEUE_WINDOW)
	if waiting and time < _queued.until:
		return
	_queued = {}
	error = "Not ready yet" if r == "cd" or r == "gcd" else r
	error_t = 0.0


# ---------- the tick

func tick(dt: float) -> void:
	time += dt
	_update_player()
	for e in enemies:
		if e.alive:
			_enemy_tick(e, dt)
	for u in units:
		_update_unit(u, dt)
	_update_combat()
	if error != "":
		error_t += dt
		if error_t > 1.5:
			error = ""


func _enemy_tick(e: Combatant, dt: float) -> void:
	var def := e.enemy
	if not e.engaged:
		# walk back to its post, and notice any hero who comes near
		e.has_goal = dist_to(e, e.home) > 0.3
		e.goal = e.home
		e.aggro_t -= dt
		if e.aggro_t > 0.0:
			return
		e.aggro_t = 0.2
		for h in heroes:
			if h.alive and dist(h, e) <= AGGRO and sees(e, h):
				engage(e, h)
				break
		return
	var tgt := pick_threat_target(e)
	if tgt == null:
		e.has_goal = false
		return
	e.target_id = tgt.id
	var d := dist(e, tgt)
	var melee := def.reach < 5.0
	# once walking, close a little further than needed, so a small shuffle by the target is not
	# followed step for step
	var stop_at := maxf(def.radius + 1.0, def.reach - 0.5) if melee else def.reach - 0.5
	if d > (stop_at if e.chasing else def.reach) or (not melee and not sees(e, tgt)):
		e.chasing = true
		e.has_goal = true
		e.goal = tgt.pos
		return
	e.chasing = false
	e.has_goal = false
	if def.auto_dmg <= 0.0:
		return
	e.auto_timer -= dt
	if e.auto_timer <= 0.0:
		e.auto_timer = def.auto_interval
		damage(e, tgt, def.auto_dmg, def.auto_type)


static func dist_to(u: Combatant, p: Vector3) -> float:
	return Vector2(u.pos.x - p.x, u.pos.z - p.z).length()


func _update_unit(u: Combatant, dt: float) -> void:
	if not u.alive:
		return
	if u.gcd > 0.0:
		u.gcd -= dt
	for k: String in u.cds:
		if u.cds[k] > 0.0:
			u.cds[k] -= dt
	if u.hero == null:
		return
	var def := u.hero
	if in_combat:
		gain(u, def.regen * dt)
	else:
		u.hp = minf(u.max_hp, u.hp + u.max_hp * 0.1 * dt)
		gain(u, u.res_max * 0.1 * dt if def.regen > 0.0 else -8.0 * dt)

	# auto-attacks go to the enemy target once it is in the fight
	if u.auto_timer > 0.0:
		u.auto_timer -= dt
	var t := unit(u.target_id)
	if t and t.alive and t.team == "enemy" and t.engaged and u.auto_timer <= 0.0:
		if dist(u, t) <= def.auto_reach + t.radius * 0.5 and (def.auto_reach < 5.0 or sees(u, t)):
			u.auto_timer = def.auto_interval
			damage(u, t, def.auto_dmg, "phys")


func _update_combat() -> void:
	in_combat = enemies.any(func(e: Combatant) -> bool: return e.alive and e.engaged)
	if not in_combat:
		# the fallen get up once the fight is over
		for h in heroes:
			if not h.alive:
				h.alive = true
				h.hp = h.max_hp * 0.4
				event.emit({"k": "revive", "id": h.id})
	elif heroes.all(func(h: Combatant) -> bool: return not h.alive):
		_wipe()


# Everyone is down: the enemies go back to their posts, healed.
func _wipe() -> void:
	for e in enemies:
		if e.alive:
			reset_enemy(e)
	in_combat = false
	event.emit({"k": "wipe"})


## Puts an enemy back as it was before the fight, alive and at full health.
func reset_enemy(e: Combatant) -> void:
	e.alive = true
	e.hp = e.max_hp
	e.engaged = false
	e.chasing = false
	e.threat.clear()
	e.target_id = 0
	e.cds.clear()
