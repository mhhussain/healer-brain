extends SceneTree
func _initialize() -> void:
	SaveStore.path = "user://dbg-save.json"
	_go()

func _go() -> void:
	change_scene_to_file("res://scenes/run.tscn")
	for i in 5:
		await physics_frame
	print("dbg first load: saves ", current_scene._saves)
	current_scene.chosen_level = 1
	current_scene.save.unlocked = 4
	Run.chosen_level = 3
	current_scene._remember()
	print("dbg file after remember: ", FileAccess.get_file_as_string(SaveStore.path))
	reload_current_scene()
	for i in 5:
		await physics_frame
	print("dbg after reload: saves ", current_scene._saves, " unlocked ", current_scene.save.unlocked, " level ", Run.chosen_level)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path))
	quit()
