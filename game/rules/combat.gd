class_name Combat
extends RefCounted

# The rules of a run: abilities, casts, cooldowns, auras, damage, threat, enemy abilities,
# telegraphed zones and who is in a fight. It knows nothing about the scene. The scene tells each
# Combatant where it stands, calls tick() 60 times a second, walks units to their goals and
# reacts to the events emitted here. Ported from src/sim/world.ts and src/sim/enemyAI.ts.

## Something happened: {"k": kind, ...}. Kinds:
## hit, heal, death, ability, interrupt, dispel, engage, clear, wipe, revive (rules);
## text, beam, ring, alert (things to show); spawn, despawn, dash, pillar, pillars_up (things
## the scene must do).
signal event(e: Dictionary)

## How near a hero must come for an enemy to notice, in metres.
const AGGRO := 11.0
## A press this long before an ability is ready still goes off, the moment it can.
const QUEUE_WINDOW := 0.5
const TAB_RANGE := 45.0
const TIME_LIMIT := 14 * 60.0
const DEATH_PENALTY := 5.0

var level := 1
## Enemy health and damage are multiplied by this: 8% a level, compounding.
var scale := 1.0
var time := 0.0
## Seconds since the first pull.
var elapsed := 0.0
var deaths := 0
var started := false
var finished := false
var in_combat := false
## A sandbox never finishes, however many packs are cleared.
var endless := false
## The AI plays the heroes that are not the player's. Tests of the rules alone turn it off.
var ai_plays := true
## The AI plays the player's hero too.
var autoplay := false

var heroes: Array[Combatant] = []
var enemies: Array[Combatant] = []
var packs: Array[Pack] = []
var zones: Array[Zone] = []
var player: Combatant
## The ally under the mouse, if any: ally abilities go there.
var hover_ally_id := 0

## Whether one spot can see another: func(a: Vector3, b: Vector3) -> bool. The scene supplies a
## ray cast against the walls; on its own, everything can see everything.
var los := func(_a: Vector3, _b: Vector3) -> bool: return true
## Which pillar stands between two spots, or -1: func(a: Vector3, b: Vector3) -> int.
var blocker := func(_a: Vector3, _b: Vector3) -> int: return -1
## Whether a unit could stand on a spot: func(p: Vector3) -> bool.
var can_stand := func(_p: Vector3) -> bool: return true
## Whether a unit could walk straight from one spot to another: func(a: Vector3, b: Vector3) -> bool.
var clear_walk := func(_a: Vector3, _b: Vector3) -> bool: return true
## Columns the party can hide behind: {"pos": Vector3, "r": float, "alive": bool}. Its place in
## the list is the id that `blocker` answers with.
var pillars: Array[Dictionary] = []

## Why the player's last press did nothing, for the interface to show, and how long ago.
var error := ""
var error_t := 0.0

var _units := {}
var _queued := {}
var _next_id := 1
var _rng := RandomNumberGenerator.new()


func _init(run_level := 1, rng_seed := 1) -> void:
	level = run_level
	scale = pow(1.08, level - 1)
	_rng.seed = rng_seed


# ---------- who is in the run

func add_hero(def: HeroDef, is_player := false) -> Combatant:
	var u := _make("hero", def.name)
	u.hero = def
	u.is_player = is_player
	u.slot = heroes.size()
	u.max_hp = def.hp
	u.hp = def.hp
	u.res_max = def.res_max
	u.res = def.res_start
	u.ai = AIState.new()
	u.ai.reaction = 0.3 + rng() * 0.3
	heroes.append(u)
	if is_player:
		player = u
	return u


func add_pack(name := "", boss := false) -> Pack:
	var p := Pack.new()
	p.id = packs.size()
	p.name = name
	p.boss = boss
	packs.append(p)
	return p


func spawn_enemy(def_id: String, at: Vector3, pack_id: int, summoned := false) -> Combatant:
	var def := Enemies.by_id(def_id)
	var pack := packs[pack_id]
	var u := _make("enemy", def.name)
	u.enemy = def
	u.radius = def.radius
	u.max_hp = roundf(def.hp * scale)
	u.hp = u.max_hp
	u.pos = at
	u.home = at
	u.pack_id = pack_id
	u.summoned = summoned
	u.slot_angle = pack.units.size() * 2.4
	pack.units.append(u)
	enemies.append(u)
	if summoned:
		if pack.engaged:
			_wake(u)
		event.emit({"k": "spawn", "id": u.id})
	return u


func _make(team: String, name: String) -> Combatant:
	var u := Combatant.new()
	u.id = _next_id
	_next_id += 1
	u.team = team
	u.name = name
	_units[u.id] = u
	return u


func unit(id: int) -> Combatant:
	return _units.get(id)


func alive_heroes() -> Array[Combatant]:
	return heroes.filter(func(h: Combatant) -> bool: return h.alive)


func engaged_enemies() -> Array[Combatant]:
	return enemies.filter(func(e: Combatant) -> bool: return e.alive and e.engaged)


func enemies_near(p: Vector3, r: float) -> Array[Combatant]:
	return enemies.filter(func(e: Combatant) -> bool:
		return e.alive and flat(e.pos, p) <= r + e.radius * 0.5)


func rng() -> float:
	return _rng.randf()


func random_hero() -> Combatant:
	var a := alive_heroes()
	return a[_rng.randi() % a.size()] if not a.is_empty() else null


func random_heroes(n: int) -> Array[Combatant]:
	var a := alive_heroes()
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var keep := a[i]
		a[i] = a[j]
		a[j] = keep
	return a.slice(0, n)


func next_pack() -> Pack:
	for p in packs:
		if not p.cleared:
			return p
	return null


## The x at which the room holding a spot begins. A doorway counts as part of the room before it.
func room_start(x: float) -> float:
	var left := -INF
	for p in packs:
		if p.room_left <= x:
			left = p.room_left
	return left


func total_time() -> float:
	return elapsed + deaths * DEATH_PENALTY


func timed() -> bool:
	return finished and total_time() <= TIME_LIMIT


## The tank: the first hero whose role says so, or the first hero.
func tank() -> Combatant:
	for h in heroes:
		if h.hero.role == "tank":
			return h
	return heroes[0] if not heroes.is_empty() else null


## Distance along the floor.
static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func dist(a: Combatant, b: Combatant) -> float:
	return flat(a.pos, b.pos)


## The way from one unit to another along the floor.
static func toward(a: Combatant, b: Combatant) -> Vector3:
	return Vector3(b.pos.x - a.pos.x, 0, b.pos.z - a.pos.z).normalized()


func sees(a: Combatant, b: Combatant) -> bool:
	return los.call(a.pos, b.pos)


# ---------- things to show

func text(at: Vector3, s: String, color: Color) -> void:
	event.emit({"k": "text", "at": at, "s": s, "color": color})


func beam(a: Combatant, b: Combatant, color: Color) -> void:
	event.emit({"k": "beam", "src": a.id, "id": b.id, "color": color})


func ring(at: Vector3, r: float, color: Color) -> void:
	event.emit({"k": "ring", "at": at, "r": r, "color": color})


func alert(s: String) -> void:
	event.emit({"k": "alert", "s": s})


func add_zone(fields: Dictionary) -> Zone:
	var z := Zone.make(fields)
	zones.append(z)
	return z


# ---------- auras and resources

func has_aura(u: Combatant, id: String) -> bool:
	return u.auras.any(func(a: Aura) -> bool: return a.id == id)


## Puts an aura on a unit. One of each id: a new one replaces the old.
func add_aura(u: Combatant, fields: Dictionary) -> void:
	if not u.alive:
		return
	var a := Aura.make(fields)
	a.t = a.dur
	a.tick_timer = a.tick_every
	u.auras = u.auras.filter(func(o: Aura) -> bool: return o.id != a.id)
	u.auras.append(a)


func gain(u: Combatant, n: float) -> void:
	u.res = clampf(u.res + n, 0.0, u.res_max)


# ---------- damage, healing, threat

## Returns the damage dealt. `type` is "phys" or "magic". Options: "raw" skips every multiplier,
## "no_beam" draws no streak, "scaled" applies the level to damage with no source.
func damage(src: Combatant, tgt: Combatant, amount: float, type := "phys", o := {}) -> float:
	if not tgt.alive:
		return 0.0
	var a := amount
	if not o.get("raw", false):
		if src:
			for au in src.auras:
				a *= au.done
			if src.team == "enemy":
				a *= scale * _enemy_bonus(src)
		elif o.get("scaled", false):
			a *= scale
		for au in tgt.auras:
			a *= au.taken
			if type == "phys":
				a *= au.taken_phys
	for au in tgt.auras:
		if au.absorb <= 0.0 or a <= 0.0:
			continue
		var soaked := minf(au.absorb, a)
		au.absorb -= soaked
		a -= soaked
		var shielder := unit(au.src_id)
		if shielder:
			shielder.stats.heal += soaked
		if au.absorb <= 0.0:
			au.t = 0.0
	a = roundf(a)
	tgt.hp -= a
	event.emit({"k": "hit", "id": tgt.id, "src": src.id if src else 0, "amt": a, "s": type})
	if src and not o.get("no_beam", false) and dist(src, tgt) > 4.0:
		beam(src, tgt, src.hero.color if src.hero else Color("b58cf0"))
	if tgt.team == "enemy":
		if src and src.hero:
			src.stats.dmg += a
			engage_from(src, tgt)
			add_threat(tgt, src.id, a * src.hero.threat_mult)
	elif tgt.hero.id == "warden" and src and a > 0.0 and time - tgt.rage_gate >= 1.0:
		# the Warden earns grit by being hit
		tgt.rage_gate = time
		gain(tgt, 1.0)
	if tgt.hp <= 0.0:
		_kill(tgt)
	return a


func _enemy_bonus(e: Combatant) -> float:
	var m := 1.0
	if e.enemy.boss:
		return m
	if level >= 3:
		for o in enemies:
			if o != e and o.alive and o.engaged and o.enemy.id == "overseer" and dist(o, e) <= 15.0:
				m *= 1.15
				break
	if level >= 9 and e.hp / e.max_hp < 0.25:
		m *= 1.25
	return m


## Returns the health restored.
func heal(src: Combatant, tgt: Combatant, amount: float) -> float:
	if not tgt.alive:
		return 0.0
	var eff := roundf(minf(tgt.max_hp - tgt.hp, amount))
	tgt.hp += eff
	if eff > 0.0:
		src.stats.heal += eff
		event.emit({"k": "heal", "id": tgt.id, "src": src.id, "amt": eff})
		var es := engaged_enemies()
		for e in es:
			add_threat(e, src.id, eff * 0.5 / es.size())
	return eff


func _kill(u: Combatant) -> void:
	u.alive = false
	u.hp = 0.0
	u.cast = null
	u.has_goal = false
	event.emit({"k": "death", "id": u.id})
	u.auras.clear()
	if u.team == "hero":
		u.stats.deaths += 1
		deaths += 1
		text(u.pos, u.name + " falls", Color("ef5d4a"))
	elif u.enemy.on_death.is_valid():
		u.enemy.on_death.call(self, u)


func add_threat(e: Combatant, hero_id: int, amt: float) -> void:
	e.threat[hero_id] = e.threat.get(hero_id, 0.0) + amt


func _wake(u: Combatant) -> void:
	u.engaged = true
	for ab in u.enemy.abilities:
		u.cds[ab.id] = ab.first if ab.first >= 0.0 else ab.cd * (0.3 + 0.7 * rng())


## The whole pack joins the fight against that hero.
func engage(pack: Pack, hero: Combatant) -> void:
	if pack.engaged or pack.cleared:
		return
	pack.engaged = true
	pack.engaged_at = time
	pack.tank_hit_at = -1.0
	started = true
	in_combat = true
	event.emit({"k": "engage", "id": pack.id})
	for u in pack.units:
		if not u.alive:
			continue
		_wake(u)
		add_threat(u, hero.id, 1.0)


## A hero did something hostile to an enemy.
func engage_from(hero: Combatant, e: Combatant) -> void:
	var pack := packs[e.pack_id]
	engage(pack, hero)
	if hero.hero.role == "tank" and pack.tank_hit_at < 0.0:
		pack.tank_hit_at = time
	if not e.threat.has(hero.id):
		add_threat(e, hero.id, 1.0)


func taunt(u: Combatant, e: Combatant, name: String) -> void:
	engage_from(u, e)
	var top := 0.0
	for v: float in e.threat.values():
		top = maxf(top, v)
	e.threat[u.id] = top * 1.1 + 100.0
	e.forced_id = u.id
	e.forced_t = time + 4.0
	add_aura(e, {"id": "taunt", "name": name, "dur": 4.0, "src_id": u.id, "debuff": true})
	beam(u, e, u.hero.color)


func interrupt(u: Combatant, e: Combatant) -> void:
	engage_from(u, e)
	var c := e.cast
	if c == null or not c.interruptible:
		text(e.pos, "Nothing to silence", Color("9fb0b1"))
		return
	e.cast = null
	e.busy = 0.6
	e.cds[c.ab.id] = maxf(c.ab.cd, 3.0)
	u.stats.interrupts += 1
	event.emit({"k": "interrupt", "id": e.id, "src": u.id})
	u.last_interrupt = time
	text(e.pos, "Silenced", Color("f0b54a"))
	if dist(u, e) > 4.0:
		beam(u, e, u.hero.color)


func dispel(u: Combatant, t: Combatant) -> void:
	var before := t.auras.size()
	t.auras = t.auras.filter(func(a: Aura) -> bool: return not a.dispellable)
	if t.auras.size() < before:
		u.stats.dispels += 1
		event.emit({"k": "dispel", "id": t.id, "src": u.id})
		text(t.pos, "Cleansed", Color("c9a2ff"))


## Who the enemy attacks: whoever taunted it, else the top of its threat list. It only swaps to
## a new hero once that hero is clearly ahead, so it does not flicker between two.
func pick_threat_target(e: Combatant) -> Combatant:
	if e.forced_t > time:
		var f := unit(e.forced_id)
		if f and f.alive:
			return f
	var best: Combatant = null
	var best_v := -1.0
	for id: int in e.threat:
		var h := unit(id)
		if h and h.alive and e.threat[id] > best_v:
			best = h
			best_v = e.threat[id]
	if best == null:
		for h in heroes:
			if h.alive and (best == null or dist(h, e) < dist(best, e)):
				best = h
		if best:
			add_threat(e, best.id, 1.0)
		return best
	var cur := unit(e.target_id)
	if cur == null or not cur.alive or cur.team != "hero" or not e.threat.has(cur.id) or cur == best:
		return best
	var mult := 1.1 if dist(best, e) <= 4.0 else 1.3
	return best if best_v > e.threat[cur.id] * mult else cur


func start_enemy_cast(e: Combatant, ab: EnemyAbility, t: Combatant) -> void:
	e.cds[ab.id] = ab.cd + ab.cast
	e.pending = {}
	if ab.cast <= 0.0:
		e.busy = 0.3
		if ab.finish.is_valid():
			ab.finish.call(self, e, t)
		return
	var c := Cast.new()
	c.name = ab.name
	c.total = ab.cast
	c.target_id = t.id if t else 0
	c.ab = ab
	c.interruptible = ab.interruptible
	c.importance = ab.importance
	e.cast = c
	if ab.start.is_valid():
		ab.start.call(self, e, t, c)


## The enemy casting something the party must hide from, if any.
func hide_caster() -> Combatant:
	for e in enemies:
		if e.alive and e.cast and e.cast.ab.hide:
			return e
	return null


## Damage dealers and healers hold their damage until the tank has had a moment to take threat.
func can_attack() -> bool:
	var pack: Pack = null
	for p in packs:
		if p.engaged and not p.cleared:
			pack = p
			break
	if pack == null:
		return false
	if not tank().alive:
		return true
	if pack.tank_hit_at < 0.0:
		return time - pack.engaged_at > 4.0
	return time - pack.tank_hit_at > 1.5


# ---------- hero abilities

func cast_time(u: Combatant, ab: AbilityDef) -> float:
	return ab.cast / 2.0 if ab.id == "firebolt" and has_aura(u, "kindled") else ab.cast


func _check_target(u: Combatant, ab: AbilityDef, t: Combatant, leeway := 0.0) -> String:
	if ab.target == "self":
		return ""
	if t == null or not t.alive:
		return "No target" if ab.target == "enemy" else "Target is dead"
	if t == u:
		return ""
	if dist(u, t) > ab.reach + t.radius * 0.5 + leeway:
		return "Out of range"
	if ab.reach > 5.0 and not sees(u, t):
		return "No line of sight"
	return ""


## Uses the ability now. Returns "" if it went off or began casting, "cd" or "gcd" if it is not
## ready, or the reason to show the player.
func use_ability(u: Combatant, idx: int, target: Combatant) -> String:
	var ab := u.hero.abilities[idx]
	if not u.alive:
		return "You are dead"
	if u.cds.get(ab.id, 0.0) > 0.0:
		return "cd"
	if not ab.off_gcd and (u.gcd > 0.0 or u.cast):
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
	var ct := cast_time(u, ab)
	if ct > 0.0:
		if u.moved:
			return "Cannot cast while moving"
		var c := Cast.new()
		c.name = ab.name
		c.total = ct
		c.target_id = t.id
		c.ab_idx = idx
		u.cast = c
		u.gcd = minf(u.hero.gcd, maxf(1.0, ct))
		return ""
	_fire(u, ab, t)
	return ""


func _fire(u: Combatant, ab: AbilityDef, t: Combatant) -> void:
	u.res -= ab.cost
	if ab.cd > 0.0:
		u.cds[ab.id] = ab.cd
	if not ab.off_gcd and ab.cast <= 0.0:
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
	if usable and ab.usable.is_valid():
		usable = ab.usable.call(self, u) == ""
	if usable and ab.target == "enemy":
		var t := unit(u.target_id)
		if t and t.alive:
			usable = _check_target(u, ab, t) == ""
	return {"cd": maxf(cd, 0.0), "cd_max": cd_max, "usable": usable}


# ---------- the player

## The player pressed an ability. It goes off on the next tick, or as soon as it is ready if that
## is within the queue window. `ally_id` is the party member a click-cast landed on.
func press(idx: int, ally_id := 0) -> void:
	var p := player
	if p == null or idx >= p.hero.abilities.size():
		return
	var ab := p.hero.abilities[idx]
	var target_id := 0
	if ab.target == "enemy":
		var t := unit(p.target_id)
		if t == null or not t.alive or t.team != "enemy":
			# with no target of your own, take the tank's
			var tt := unit(tank().target_id)
			if tt and tt.alive and tt.team == "enemy":
				t = tt
				p.target_id = tt.id
		target_id = t.id if t else 0
	elif ab.target == "ally":
		target_id = ally_id if ally_id > 0 else hover_ally_id if hover_ally_id > 0 else p.id
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


func _fail(s: String) -> void:
	error = s
	error_t = 0.0


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
	if r == "cd":
		_fail(ab.name + " is not ready")
	elif r != "gcd":
		_fail(r)


# ---------- the tick

func tick(dt: float) -> void:
	if finished:
		return
	time += dt
	if started:
		elapsed += dt
	_update_player()
	for h in heroes:
		if ai_plays and h.alive and (not h.is_player or autoplay):
			HeroAI.think(self, h)
	for e in enemies:
		if e.alive:
			_enemy_tick(e, dt)
	for u in heroes:
		_update_unit(u, dt)
	for u in enemies:
		_update_unit(u, dt)
	_update_zones(dt)
	_assign_interrupts()
	_update_combat()
	if error != "":
		error_t += dt
		if error_t > 1.5:
			error = ""


func _enemy_tick(e: Combatant, dt: float) -> void:
	var def := e.enemy
	if not e.engaged:
		# walk back to its post, and notice any hero who comes near
		e.has_goal = flat(e.pos, e.home) > 0.3
		e.goal = e.home
		e.aggro_t -= dt
		if e.aggro_t > 0.0:
			return
		e.aggro_t = 0.2
		for h in heroes:
			if h.alive and dist(h, e) <= AGGRO and sees(e, h):
				engage(packs[e.pack_id], h)
				break
		return
	e.has_goal = false
	if def.passive.is_valid():
		def.passive.call(self, e)
	var tgt := pick_threat_target(e)
	if tgt == null:
		return
	e.target_id = tgt.id
	if e.busy > 0.0:
		e.busy -= dt

	var c := e.cast
	if c:
		var ab := c.ab
		var ct := unit(c.target_id)
		c.t += dt
		if ab.tick.is_valid():
			c.tick_timer -= dt
			if c.tick_timer <= 0.0:
				c.tick_timer += 1.0
				ab.tick.call(self, e, c)
		if c.t >= c.total:
			e.cast = null
			e.busy = 0.4
			var ok: bool = not ab.needs_los or (ct != null and ct.alive and sees(e, ct))
			if ok and ab.finish.is_valid():
				ab.finish.call(self, e, ct if ct and ct.alive else null)
		return

	var chase: Combatant = null
	if e.busy <= 0.0:
		for ab in def.abilities:
			if level < ab.min_level:
				continue
			if e.cds.get(ab.id, 0.0) > 0.0:
				continue
			if ab.ready.is_valid() and not ab.ready.call(self, e):
				continue
			if ab.melee and dist(e, tgt) > 3.2:
				continue
			var t: Combatant = null
			if ab.targeting == "threat":
				t = tgt
			elif ab.targeting == "random":
				var p: Combatant = unit(e.pending.target_id) if e.pending.get("ab") == ab.id else null
				t = p if p and p.alive else random_hero()
			if ab.needs_los and t and not sees(e, t):
				# walk until it can see whoever it picked
				e.pending = {"ab": ab.id, "target_id": t.id}
				chase = t
				break
			start_enemy_cast(e, ab, t)
			return

	var mt := chase if chase else tgt
	if chase:
		e.has_goal = true
		e.goal = mt.pos
		return
	var d := dist(e, mt)
	var melee := def.reach < 5.0
	# once walking, close a little further than needed, so a small shuffle by the target is not
	# followed step for step
	var stop_at := maxf(def.radius + 1.0, def.reach - 0.5) if melee else def.reach - 0.5
	if d > (stop_at if e.chasing else def.reach) or (not melee and not sees(e, mt)):
		e.chasing = true
		e.has_goal = true
		e.goal = mt.pos
		if melee:
			# its own place round the target, so a pack spreads out
			var spot := mt.pos + Vector3(cos(e.slot_angle), 0, sin(e.slot_angle)) * (def.radius + 0.9)
			if can_stand.call(spot):
				e.goal = spot
		return
	e.chasing = false
	if def.auto_dmg <= 0.0:
		return
	var haste := 1.0
	for a in e.auras:
		haste *= a.haste
	e.auto_timer -= dt * haste
	if e.auto_timer <= 0.0:
		e.auto_timer = def.auto_interval
		damage(e, mt, def.auto_dmg, def.auto_type)


func _update_unit(u: Combatant, dt: float) -> void:
	if not u.alive:
		return
	if u.gcd > 0.0:
		u.gcd -= dt
	for k: String in u.cds:
		if u.cds[k] > 0.0:
			u.cds[k] -= dt

	for a in u.auras:
		a.t -= dt
		if a.tick_every <= 0.0:
			continue
		var src := unit(a.src_id)
		# Green Tide makes the Kelpwife's kelp work twice as fast
		var rate := 2.0 if a.id == "vine" and src and has_aura(src, "tide") else 1.0
		a.tick_timer -= dt * rate
		# a hair of slack, so rounding in the clock cannot cost an aura its last tick
		if a.tick_timer > 1e-6:
			continue
		a.tick_timer += a.tick_every
		if a.tick_dmg > 0.0:
			damage(src, u, a.tick_dmg, "magic", {"no_beam": true, "scaled": true})
		if a.tick_heal > 0.0 and src:
			heal(src, u, a.tick_heal)
		if not u.alive:
			return
	u.auras = u.auras.filter(func(a: Aura) -> bool: return a.t > 0.0)

	if u.hero == null:
		return
	var def := u.hero
	var c := u.cast
	if c:
		if u.moved:
			u.cast = null
		else:
			c.t += dt
			if c.t >= c.total:
				u.cast = null
				var ab := def.abilities[c.ab_idx]
				var ct := unit(c.target_id)
				if _check_target(u, ab, ct, 5.0) == "" and not (ab.cost > 0.0 and u.res < ab.cost):
					_fire(u, ab, ct)

	if in_combat:
		gain(u, def.regen * dt * (2.0 if has_aura(u, "bloodrush") else 1.0))
	else:
		u.hp = minf(u.max_hp, u.hp + u.max_hp * 0.1 * dt)
		gain(u, u.res_max * 0.1 * dt if def.regen > 0.0 else -8.0 * dt)

	# auto-attacks go to the enemy target once it is in the fight
	var t := unit(u.target_id)
	if u.auto_timer > 0.0:
		var haste := 1.0
		for a in u.auras:
			haste *= a.haste
		u.auto_timer -= dt * haste
	var free := def.role == "tank" or (u.is_player and not autoplay) or can_attack()
	if t and t.alive and t.team == "enemy" and t.engaged and u.cast == null and u.auto_timer <= 0.0 and free:
		if dist(u, t) <= def.auto_reach + t.radius * 0.5 and (def.auto_reach < 5.0 or sees(u, t)):
			u.auto_timer = def.auto_interval
			damage(u, t, def.auto_dmg, "phys")
			if def.id == "warden":
				gain(u, 2.0)


func _update_zones(dt: float) -> void:
	var before := zones.duplicate()
	var keep: Array[Zone] = []
	for z: Zone in before:
		z.t += dt
		var owner := unit(z.owner_id)
		if z.t >= z.delay:
			event.emit({"k": "boom", "at": z.pos, "r": z.r, "id": z.owner_id})
			for h in heroes:
				if h.alive and z.holds(h.pos):
					damage(owner, h, z.dmg, z.type, {"no_beam": true, "scaled": true})
			continue
		if z.tied and (owner == null or not owner.alive or owner.cast == null):
			continue
		keep.append(z)
	# anything laid down while these went off
	for z in zones:
		if not before.has(z):
			keep.append(z)
	zones = keep


## Hands each enemy cast that can be stopped to one party member, so two do not spend their
## interrupts on the same cast. The AI reads `cast.assignee`.
func _assign_interrupts() -> void:
	var casting := enemies.filter(func(e: Combatant) -> bool:
		return e.alive and e.cast and e.cast.interruptible)
	if casting.is_empty():
		return
	var busy := {}
	for e: Combatant in casting:
		if e.cast.assignee > 0:
			busy[e.cast.assignee] = true
	var kickers: Array[Combatant] = []
	for h in heroes:
		var ab := _interrupt_of(h)
		if h.alive and ab and h.cds.get(ab.id, 0.0) <= 0.0:
			kickers.append(h)
	var must_exists := false
	for e in enemies:
		if e.alive and e.engaged:
			for a in e.enemy.abilities:
				if a.importance == 2 and level >= a.min_level:
					must_exists = true
	casting.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		return a.cast.importance > b.cast.importance)
	for e: Combatant in casting:
		var c := e.cast
		if c.assignee > 0 or c.total - c.t < 0.4:
			continue
		var free := kickers.filter(func(h: Combatant) -> bool: return not busy.has(h.id))
		# keep one interrupt back for a cast that must be stopped
		if c.importance == 1 and must_exists and free.size() < 2:
			continue
		var best: Combatant = null
		for h: Combatant in free:
			var ab := _interrupt_of(h)
			if dist(h, e) > ab.reach + e.radius * 0.5:
				continue
			if ab.reach > 5.0 and not sees(h, e):
				continue
			if best == null or h.last_interrupt < best.last_interrupt:
				best = h
		if best:
			c.assignee = best.id
			c.assigned_at = time
			busy[best.id] = true


func _interrupt_of(h: Combatant) -> AbilityDef:
	for ab in h.hero.abilities:
		if ab.interrupt:
			return ab
	return null


func _update_combat() -> void:
	for p in packs:
		if not p.engaged or p.cleared or p.units.any(func(u: Combatant) -> bool: return u.alive):
			continue
		p.cleared = true
		p.cleared_at = time
		event.emit({"k": "clear", "id": p.id})
		if p.boss:
			alert(p.lamp if p.lamp != "" else p.name + " is at rest")
	in_combat = packs.any(func(p: Pack) -> bool: return p.engaged and not p.cleared)
	if not endless and not packs.is_empty() and packs.all(func(p: Pack) -> bool: return p.cleared):
		finished = true
		return
	if not in_combat:
		# the fallen get up once the fight is over
		for h in heroes:
			if not h.alive:
				h.alive = true
				h.hp = h.max_hp * 0.4
				event.emit({"k": "revive", "id": h.id})
	elif heroes.all(func(h: Combatant) -> bool: return not h.alive):
		_wipe()


# Everyone is down: the pack goes back to its posts, healed, and the party starts again from
# the way in.
func _wipe() -> void:
	alert("Driven back. The keepers return to their posts.")
	zones.clear()
	for p in pillars:
		p.alive = true
	event.emit({"k": "pillars_up"})
	var entry := packs[0].entry
	for p in packs:
		if not p.engaged or p.cleared:
			continue
		entry = p.entry
		_reset_pack(p)
	in_combat = false
	for i in heroes.size():
		var h := heroes[i]
		h.alive = true
		h.hp = h.max_hp
		h.auras.clear()
		h.cast = null
		h.res = h.hero.res_start
		h.combo = 0
		h.target_id = 0
		h.has_goal = false
		h.pos = entry + Vector3(-2.0 + (i % 2) * 1.5, 0, -1.5 + floorf(i / 2.0) * 1.5)
	event.emit({"k": "wipe"})


func _reset_pack(p: Pack) -> void:
	for u in p.units:
		if u.summoned:
			u.alive = false
			_units.erase(u.id)
			event.emit({"k": "despawn", "id": u.id})
	enemies = enemies.filter(func(e: Combatant) -> bool: return not (e.summoned and e.pack_id == p.id))
	p.units = p.units.filter(func(u: Combatant) -> bool: return not u.summoned)
	for u in p.units:
		u.alive = true
		u.hp = u.max_hp
		u.pos = u.home
		u.engaged = false
		u.chasing = false
		u.has_goal = false
		u.cast = null
		u.auras.clear()
		u.threat.clear()
		u.cds.clear()
		u.forced_t = 0.0
		u.pending = {}
		u.flags = {}
		u.target_id = 0
		u.busy = 0.0
	p.engaged = false


## Sandbox only: stands a pack back up at its posts, as it was before anyone touched it.
func reset_pack(p: Pack) -> void:
	_reset_pack(p)
	p.cleared = false
	event.emit({"k": "reset", "id": p.id})


func destroy_pillar(id: int) -> void:
	if id >= 0 and id < pillars.size():
		pillars[id].alive = false
	event.emit({"k": "pillar", "id": id})
