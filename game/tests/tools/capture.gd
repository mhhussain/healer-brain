extends SceneTree

# A developer tool, not a test: lets the AI play the hall so that --write-movie can record
# frames to look at. From the repo root:
#   godot --path game -s tests/tools/capture.gd --write-movie build/shots/f.png --fixed-fps 60 --quit-after 1500 -- pyromancer 3
# The last words are the hero the camera follows (the Chandler if left out) and the level.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Run.choose(args[0] if args.size() > 0 else "pyromancer")
	Run.chosen_level = int(args[1]) if args.size() > 1 else 3
	Run.autoplay = true
	Run.rng_seed = 4
	var main: Run = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
