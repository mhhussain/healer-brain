extends SceneTree

# A developer tool, not a test: plays a short scripted fight in the main scene so that
# --write-movie can record frames to look at. From the repo root:
#   godot --path game -s tests/tools/capture.gd --write-movie build/shots/f.png --fixed-fps 60 --quit-after 420

func _initialize() -> void:
	var main: Run = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_play(main)


func _play(main: Run) -> void:
	var enemy: Unit = main.get_node("Enemy")
	await _frames(20)
	main.player.c.target_id = enemy.c.id
	main.combat.press(0)
	await _frames(40)
	# back away up the hall while it comes, jumping on the way
	Input.action_press("move_left")
	await _frames(10)
	main.player.jump()
	await _frames(50)
	Input.action_release("move_left")
	main.combat.press(1)
	await _frames(100)
	main.combat.press(1)
	await _frames(30)
	main.combat.press(1)
	# then hide behind the first pillar
	main.player.place(Vector3(4.5, 0, -4))
	await _frames(90)
	main.combat.press(0)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
