extends SceneTree

# Headless all-AI runs for balance tuning: the AI plays all four heroes through the real scene.
# From the repo root:
#   godot --headless --fixed-fps 60 --path game -s tests/tools/sim.gd -- [levels] [seeds] [place] [-v]
# such as "-- 1,3,5 2" for levels 1, 3 and 5 of the Abbey with two seeds each, or "-- 1 1 sandbox"
# for the sandbox hall. --fixed-fps lets it run as fast as the machine can, instead of in real time.

const GIVE_UP := 40 * 60.0
const DPS := [["duelist", "ranger"], ["duelist", "pyromancer"], ["ranger", "pyromancer"]]


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var verbose := args.has("-v")
	args.erase("-v")
	var levels: Array = (args[0] if args.size() > 0 else "1").split(",")
	var seeds := int(args[1]) if args.size() > 1 else 1
	Run.place = args[2] if args.size() > 2 else "abbey"
	_go(levels, seeds, verbose)


func _go(levels: Array, seeds: int, verbose: bool) -> void:
	var began := Time.get_ticks_msec()
	var runs := 0
	for level: String in levels:
		for healer in Heroes.HEALERS:
			for dps: Array in DPS:
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
	var main: Run = load("res://scenes/main.tscn").instantiate()
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
	var result := _clock(t) if c.finished else "STUCK %d/%d" % [cleared, c.packs.size()]
	print("L%d %s+%s s%d: %s %s deaths %d | %s" % [level, healer.left(5), "+".join(dps.map(func(d: String) -> String: return d.left(4))),
		rng_seed, result, "timed" if c.timed() else "over ", c.deaths, stats])
	if verbose:
		print("   packs at " + " ".join(marks))
	main.queue_free()
	await process_frame


func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
