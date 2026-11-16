extends SceneTree

# Looks over a level's packs and says what a designer wants to know: whether each pack can be
# stood at, seen and pulled from where the tank is sent; how near it is to its neighbours; and
# which packs the safe way could leave standing. From the repo root:
#   godot --headless --path game -s tests/tools/level_check.gd -- tollhaven

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var def := Levels.by_name(args[0] if args.size() > 0 else "tollhaven")
	var total := 0
	for i in def.packs.size():
		var p: Dictionary = def.packs[i]
		total += def.pack_count(i)
		var notes: Array[String] = []
		for post in LevelDef.posts(p):
			if not def.can_stand(post):
				notes.append("a post is not on clear floor")
		if def.room_at(p.center) != p.room:
			notes.append("its middle is not in its room")
		for spot: Array in [["pull_from", p.pull_from], ["stand", p.stand]]:
			if not def.can_stand(spot[1]):
				notes.append("%s is not on clear floor" % spot[0])
		var d: float = Combat.flat(p.pull_from, p.center)
		if d > 26.0:
			notes.append("pull_from is %.1f m away" % d)
		if not LevelDef.posts(p).any(func(post: Vector3) -> bool: return def.clear_line(p.pull_from, post, 1.3)):
			notes.append("nothing can be seen from pull_from")
		var near := INF
		var near_from := INF
		var near_stand := INF
		for k in def.packs.size():
			if k != i:
				near = minf(near, Combat.flat(p.center, def.packs[k].center))
				if not def.packs[k].has("path") and def.packs[k].get("room", -1) == p.room:
					near_from = minf(near_from, Combat.flat(p.pull_from, def.packs[k].center))
					near_stand = minf(near_stand, Combat.flat(p.stand, def.packs[k].center))
		print("%2d %-26s count %2d  from %4.1f m  next pack %4.1f  from-to-next %4.1f  stand-to-next %4.1f  %s" % [i, p.name, def.pack_count(i), d,
			near, near_from, near_stand, "; ".join(notes)])
	print("holds %d, asks for %d, %d enemies" % [total, def.count_goal(), def.packs.reduce(func(n: int, p: Dictionary) -> int: return n + p.enemies.size(), 0)])
	var began := Time.get_ticks_msec()
	var safe := Route.default_for(def)
	print("the safe way: ", _words(def, Paths.check(def, safe, def.start)), "  (%d ms)" % (Time.get_ticks_msec() - began))
	var free: Array[String] = []
	for i in def.packs.size():
		if def.packs[i].boss:
			continue
		var without := safe.copy()
		without.remove_pull(without.pull_of(i))
		var wrong := Paths.check(Levels.by_name(def.id), without, def.start)
		if wrong.all(func(w: Dictionary) -> bool: return w.gate == "" and w.wakes.is_empty()):
			free.append(def.packs[i].name + ("" if wrong.is_empty() else " (%s)" % _words(def, wrong)))
		else:
			print("  without %-24s %s" % [def.packs[i].name + ":", _words(def, wrong)])
	print("can be left standing on the safe way: ", ", ".join(free))
	quit()


func _words(def: LevelDef, wrong: Array) -> String:
	if wrong.is_empty():
		return "clean"
	return "; ".join(wrong.map(func(w: Dictionary) -> String:
		var names := func(packs: Array) -> String: return ", ".join(packs.map(func(p: int) -> String: return def.packs[p].name))
		return "pull %d %s" % [w.pull + 1, "is behind " + w.gate if w.gate != "" else "wakes " + names.call(w.wakes) if not w.wakes.is_empty()
			else "goes %d m round %s" % [w.metres, names.call(w.round)]]))
