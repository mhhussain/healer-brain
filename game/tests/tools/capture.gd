extends SceneTree

# A developer tool, not a test: lets the AI play the hall so that --write-movie can record
# frames to look at. From the repo root:
#   godot --path game -s tests/tools/capture.gd --write-movie build/shots/f.png --fixed-fps 60 --quit-after 1500 -- pyromancer 3 abbey
# The last words are the hero the camera follows (the Chandler if left out), the level, and
# the place: abbey or sandbox.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Run.choose(args[0] if args.size() > 0 else "pyromancer")
	Run.chosen_level = int(args[1]) if args.size() > 1 else 3
	Run.place = args[2] if args.size() > 2 else "abbey"
	Run.autoplay = true
	Run.rng_seed = 4
	var main: Run = load("res://scenes/run.tscn").instantiate()
	main.endless = false
	root.add_child(main)
	if args.size() > 3 and args[3] == "end":
		_end_it(main)


# With "end" as a fourth word, every enemy drops dead after five seconds, to see how a run ends.
func _end_it(main: Run) -> void:
	for i in 300:
		await physics_frame
	for e in main.combat.enemies:
		main.combat.damage(main.player.c, e, 999999.0)
