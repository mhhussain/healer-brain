extends SceneTree

# Headless all-AI runs for balance tuning: the AI plays all four heroes through the real scene.
# From the repo root:
#   godot --headless --fixed-fps 60 --path game -s tests/tools/sim.gd -- [levels] [seeds] [place] [-v] [route=CODE]
# such as "-- 1,3,5 2" for levels 1, 3 and 5 of the Abbey with two seeds each, or "-- 1 1 sandbox"
# for the sandbox hall. --fixed-fps lets it run as fast as the machine can, instead of in real time.
# "route=" takes a route's text code, as the map copies it, to run that plan instead of the
# place's own; "pulls=0+1,2,3+4" writes one on the spot from packs by number, with the packs it
# leaves out following one at a time; "skip=3,5" is the safe way without those packs, for a
# place that holds more than it asks for. "party=2" runs only the third of the six parties.

const GIVE_UP := 60 * 60.0
const DPS := [["duelist", "ranger"], ["duelist", "pyromancer"], ["ranger", "pyromancer"]]

# the one party to run, by its place among the six, or -1 for all
var _only := -1


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var verbose := args.has("-v")
	args.erase("-v")
	var plan := ""
	for word: String in args.duplicate():
		if word.begins_with("route=") or word.begins_with("pulls=") or word.begins_with("skip="):
			plan = word
			args.erase(word)
		elif word.begins_with("party="):
			_only = int(word.substr(6))
			args.erase(word)
	var levels: Array = (args[0] if args.size() > 0 else "1").split(",")
	var seeds := int(args[1]) if args.size() > 1 else 1
	Run.place = args[2] if args.size() > 2 else "abbey"
	Run.route = _route(plan, Levels.by_name(Run.place))
	if plan != "":
		print("route: " + (" | ".join(Run.route.pulls.map(func(p: Dictionary) -> String: return "+".join(p.packs.map(func(i: int) -> String: return str(i))))) if Run.route else "not a route for this place"))
	_go(levels, seeds, verbose)


func _go(levels: Array, seeds: int, verbose: bool) -> void:
	var began := Time.get_ticks_msec()
	var runs := 0
	for level: String in levels:
		var party := -1
		for healer in Heroes.HEALERS:
			for dps: Array in DPS:
				party += 1
				if _only >= 0 and party != _only:
					continue
				for rng_seed in range(1, seeds + 1):
					await _run(int(level), healer, dps, rng_seed, verbose)
					runs += 1
	print("%d runs in %.1f s" % [runs, (Time.get_ticks_msec() - began) / 1000.0])
	quit()


func _run(level: int, healer: String, dps: Array, rng_seed: int, verbose: bool) -> void:
	Run.party.assign(["warden", healer] + dps)
	Run.player_slot = 0
	Run.chosen_level = level
	Run.autoplay = true
	Run.rng_seed = rng_seed
	var main: Run = load("res://scenes/run.tscn").instantiate()
	main.endless = false
	root.add_child(main)
	await physics_frame
	var c := main.combat
	var marks: Array[String] = []
	var cleared := 0
	while not c.finished and c.time < GIVE_UP:
		await physics_frame
		var n := c.packs.filter(func(p: Pack) -> bool: return p.cleared).size()
		if n != cleared:
			cleared = n
			marks.append(_clock(c.total_time()))
	var t := c.total_time()
	var secs := maxf(1.0, c.elapsed)
	var stats := "  ".join(c.heroes.map(func(u: Combatant) -> String:
		return "%s %dd/%dh/%dk/%dx" % [u.hero.id.left(4), roundi(u.stats.dmg / secs), roundi(u.stats.heal / secs), u.stats.interrupts, u.stats.deaths]))
	var result := _clock(t) if c.finished else "STUCK %d/%d packs, count %d/%d" % [cleared, c.packs.size(), c.count(), c.count_goal()]
	print("L%d %s+%s s%d: %s %s deaths %d | %s" % [level, healer.left(5), "+".join(dps.map(func(d: String) -> String: return d.left(4))),
		rng_seed, result, "timed" if c.timed() else "over ", c.deaths, stats])
	if verbose:
		print("   packs at " + " ".join(marks))
	main.queue_free()
	await process_frame


# The plan asked for on the command line, or null for the place's own.
func _route(plan: String, def: LevelDef) -> Route:
	if plan.begins_with("route="):
		return Route.from_code(plan.substr(6), def)
	if plan.begins_with("skip="):
		var safe := Route.default_for(def)
		for pack: String in plan.substr(5).split(","):
			if safe.pull_of(int(pack)) >= 0:
				safe.toggle(int(pack), safe.pull_of(int(pack)))
		safe.prune()
		return safe
	if not plan.begins_with("pulls="):
		return null
	var r := Route.new()
	r.level = def.id
	for group: String in plan.substr(6).split(","):
		var at := r.add_pull()
		for pack: String in group.split("+"):
			if int(pack) < def.packs.size() and r.pull_of(int(pack)) < 0:
				r.toggle(int(pack), at)
	for i in def.packs.size():
		if r.pull_of(i) < 0:
			r.toggle(i, r.add_pull())
	return r


func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
