extends SceneTree

# A developer tool, not a test: lets the AI play the hall in a real window and prints every frame
# that took too long, with what was on screen, to find where the game stutters. From the repo root:
#   godot --path game -s tests/tools/hitches.gd

const SLOW_MS := 40.0
const SECONDS := 40.0

var _main: Run
var _last := 0
var _frame := 0
var _worst := 0.0
var _total := 0.0


func _initialize() -> void:
	Run.choose("pyromancer")
	Run.chosen_level = 3
	Run.place = "abbey"
	Run.autoplay = true
	Run.rng_seed = 4
	_main = load("res://scenes/run.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0
	_frame += 1
	if _last > 0 and _frame > 90:
		_worst = maxf(_worst, ms)
		_total += ms
		if ms > SLOW_MS:
			var casting := _main.combat.enemies.filter(func(e: Combatant) -> bool: return e.cast != null).map(func(e: Combatant) -> String: return e.cast.name)
			# where the time went: the game's own scripts each tick, each drawn frame, path-finding, or (if none of those) the drawing itself
			print("hitches: frame %d took %.0f ms; zones %d, casting %s, t %.2f | tick %.0f ms, frame scripts %.0f ms, paths %.0f ms" % [_frame, ms, _main.combat.zones.size(), casting, _main.combat.time,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0])
	_last = now
	if _main.combat and _main.combat.time > SECONDS:
		print("hitches: worst frame after start-up %.0f ms, average %.1f ms" % [_worst, _total / (_frame - 90)])
		return true
	return false
