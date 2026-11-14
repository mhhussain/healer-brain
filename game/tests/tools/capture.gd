extends SceneTree

# A developer tool, not a test: plays a short scripted fight in the main scene so that
# --write-movie can record frames to look at. From the repo root:
#   godot --path game -s tests/tools/capture.gd --write-movie build/shots/f.png --fixed-fps 60 --quit-after 900 -- pyromancer
# The last word is the hero to play; the Chandler if left out.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Run.chosen_hero = args[0] if not args.is_empty() else "pyromancer"
	var main: Run = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_play(main)


func _play(main: Run) -> void:
	await _frames(20)
	var p := main.player
	var cantor: Unit = main.get_node("Enemies/Cantor")
	var prior: Unit = main.get_node("Enemies/Prior")
	# open on the caster, then cast at it
	p.c.target_id = cantor.c.id
	main.combat.press(1)
	await _frames(95)
	main.combat.press(0)
	await _frames(60)
	p.jump()
	# silence its next cast and put up the personal defensive
	await _until(func() -> bool: return cantor.c.cast != null and cantor.c.cast.t > 0.8, 300)
	main.combat.press(3)
	main.combat.press(4)
	await _frames(120)
	# on to the second room, to stand in front of the Prior's sweep
	p.place(Vector3(36.5, 0, 0))
	p.c.target_id = prior.c.id
	main.combat.press(1)
	await _until(func() -> bool: return prior.c.cast != null and prior.c.cast.t > 1.0, 600)
	print("capture: sweep is winding up at frame ", Engine.get_frames_drawn())


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _until(what: Callable, at_most: int) -> void:
	for i in at_most:
		if what.call():
			return
		await physics_frame
