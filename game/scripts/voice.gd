class_name Voice
extends Node

# Says the game's lines aloud, one at a time. A line's voice file is assets/voice/<id>.wav; a
# line with no file is still "said" for as long as it takes to read, so its words can be shown.

## A line has begun: show its words for that many seconds.
signal started(line: Dictionary, seconds: float)
## Nothing is being said and nothing is waiting.
signal finished

const FOLDER := "res://assets/voice/"
## Lines waiting longer than this many deep are dropped: talk about the last fight is stale.
const MAX_WAITING := 2

var _player := AudioStreamPlayer.new()
var _waiting: Array[Dictionary] = []
var _left := 0.0
var _busy := false


func _ready() -> void:
	add_child(_player)


static func file_of(id: String) -> String:
	return FOLDER + id + ".wav"


## How long a line takes to say: its recording's length, or a guess from how long it is to read.
static func seconds_for(line: Dictionary) -> float:
	var path := file_of(line.id)
	if ResourceLoader.exists(path):
		return (load(path) as AudioStream).get_length()
	return 1.2 + 0.055 * (line.text as String).length()


## Says a line once whatever is being said has finished.
func say(line: Dictionary) -> void:
	_waiting.append(line)
	while _waiting.size() > MAX_WAITING:
		_waiting.pop_front()
	if not _busy:
		_next()


## Stops talking and forgets what was waiting.
func hush() -> void:
	_waiting.clear()
	_player.stop()
	_left = 0.0
	if _busy:
		_busy = false
		finished.emit()


func is_talking() -> bool:
	return _busy


func _next() -> void:
	if _waiting.is_empty():
		_busy = false
		finished.emit()
		return
	_busy = true
	var line: Dictionary = _waiting.pop_front()
	var path := file_of(line.id)
	var seconds := seconds_for(line)
	if ResourceLoader.exists(path):
		_player.stream = load(path)
		_player.play()
	# a short breath between lines
	_left = seconds + 0.35
	started.emit(line, seconds)


func _process(delta: float) -> void:
	if _busy:
		_left -= delta
		if _left <= 0.0:
			_next()
