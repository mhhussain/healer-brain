class_name SaveStore
extends RefCounted

# Reads and writes the save file. In a browser the engine keeps user:// in the browser's own
# storage, so it lasts between visits there too.

static var path := "user://fourfold-save.json"


static func load_save() -> SaveData:
	if not FileAccess.file_exists(path):
		return SaveData.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return SaveData.from_dict(parsed) if parsed is Dictionary else SaveData.new()


static func store(save: SaveData) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	# a browser in a private window may refuse storage; the game still runs
	if file:
		file.store_string(JSON.stringify(save.to_dict()))
