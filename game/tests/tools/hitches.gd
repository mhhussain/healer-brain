extends SceneTree

# A developer tool, not a test: plays a fight in a real window and prints every frame that took
# too long, with what was on screen, to find where the game stutters. From the repo root:
#   godot --path game -s tests/tools/hitches.gd

const SLOW_MS := 40.0
const SECONDS := 14.0

var _main: Run
var _last := 0
var _frame := 0
var _worst := 0.0


func _initialize() -> void:
	Run.chosen_hero = "pyromancer"
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_play()


func _play() -> void:
	for i in 60:
		await physics_frame
	var p := _main.player
	var prior: Unit = _main.get_node("Enemies/Prior")
	p.place(Vector3(36.5, 0, 0))
	p.c.target_id = prior.c.id
	_main.combat.press(1)
	print("hitches: fight started at frame ", _frame)


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	var ms := (now - _last) / 1000.0
	_frame += 1
	if _last > 0 and _frame > 90:
		_worst = maxf(_worst, ms)
		if ms > SLOW_MS:
			var casting := _main.combat.enemies.filter(func(e: Combatant) -> bool: return e.cast != null).map(func(e: Combatant) -> String: return e.cast.name)
			print("hitches: frame %d took %.0f ms; zones %d, casting %s, t %.2f" % [_frame, ms, _main.combat.zones.size(), casting, _main.combat.time])
	_last = now
	if _main.combat and _main.combat.time > SECONDS:
		print("hitches: worst frame after start-up %.0f ms" % _worst)
		return true
	return false
