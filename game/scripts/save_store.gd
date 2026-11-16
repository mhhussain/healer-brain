class_name SaveStore
extends RefCounted

# Reads and writes the save file. In a browser the engine keeps user:// in the browser's own
# storage, so it lasts between visits there too. It also keeps a copy of a save as a file of
# text for the player to hold on to: downloaded in a browser, in the Documents folder otherwise.

const FILE_NAME := "fourfold-save.txt"

static var path := "user://fourfold-save.json"
## The folder the copy is kept in outside a browser; empty for the Documents folder.
static var file_dir := ""


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


## Where the copy is kept outside a browser.
static func file_path() -> String:
	return (file_dir if file_dir != "" else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)).path_join(FILE_NAME)


## Keeps a copy of the save as a file of text. Returns what to tell the player.
static func save_file(save: SaveData) -> String:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(save.to_text().to_utf8_buffer(), FILE_NAME, "text/plain")
		return "Saved as %s, wherever your browser puts what it downloads." % FILE_NAME
	var file := FileAccess.open(file_path(), FileAccess.WRITE)
	if file == null:
		return "It could not be written to %s." % file_path()
	file.store_string(save.to_text())
	return "Saved to %s." % file_path()


## Reads the copy back, outside a browser: the save, or null if there is none or it is not one.
static func load_file() -> SaveData:
	if not FileAccess.file_exists(file_path()):
		return null
	return SaveData.from_text(FileAccess.get_file_as_string(file_path()))


## In a browser: asks for a file and hands its text to `on_text` when one is chosen.
static func ask_for_file(on_text: Callable) -> void:
	_picked = JavaScriptBridge.create_callback(func(args: Array) -> void: on_text.call(str(args[0])))
	JavaScriptBridge.get_interface("window").fourfoldPicked = _picked
	JavaScriptBridge.eval("""
		(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.txt,.json,text/plain,application/json';
			input.onchange = function () {
				var file = input.files[0];
				if (!file) return;
				var reader = new FileReader();
				reader.onload = function () { window.fourfoldPicked(reader.result); };
				reader.readAsText(file);
			};
			input.click();
		})();
	""", true)


# held so that the browser can still call it when the file has been read
static var _picked: JavaScriptObject
