extends SceneTree

# Writes assets/voice/voice_lines.json from the story: every line's id, speaker and text. The
# voice script (tools/voice/make_voice.py) reads it. Run it after changing rules/story.gd:
#   godot --headless --path game -s tests/tools/voice_manifest.gd

func _initialize() -> void:
	var file := FileAccess.open("res://assets/voice/voice_lines.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(Story.all_lines(), "  ") + "\n")
	file.close()
	print("wrote %d lines" % Story.all_lines().size())
	quit()
