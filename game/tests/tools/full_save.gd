extends SceneTree

# A developer tool, not a test: writes the save with everything in it (see tests/full_save.gd)
# to saves/fourfold-everything.txt at the top of the repo. Run it whenever a milestone adds
# something a player has to earn, after adding that to FullSave.build. From the repo root:
#   godot --headless --path game -s tests/tools/full_save.gd

func _initialize() -> void:
	var save := FullSave.build()
	DirAccess.make_dir_recursive_absolute(FullSave.path().get_base_dir())
	var file := FileAccess.open(FullSave.path(), FileAccess.WRITE)
	if file == null:
		printerr("could not write " + FullSave.path())
		quit(1)
		return
	file.store_string(save.to_text() + "\n")
	file.close()
	print("wrote %s: %d items, %d teams, every dungeon open to level %d" % [FullSave.path(), save.items.size(), save.teams.size(), FullSave.LEVEL])
	quit()
