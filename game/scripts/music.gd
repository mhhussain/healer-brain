class_name Music
extends Node

# Plays the music: one loop at a time from assets/music, fading to another as the run moves
# from wandering to a fight to a boss, and from one part of the abbey to the next. To change a
# loop, save another file over it, as .wav or .ogg.
#
#   calm_N    wandering in part N of the place (0 the Sea Gate, 1 the Infirmary, 2 the Nave)
#   fight_N   a fight there
#   boss_N    that part's boss
#   tide_bell struck once a bar in the last two minutes of the clock

const FOLDER := "res://assets/music/"
## Seconds in a bar of every loop: the tide bell is struck once in each.
const BAR := 3.2
## How many parts of a place have loops of their own. A place with more parts goes round again.
const PARTS := 3

## How loud the music is under a run, and on the menus and while paused, in decibels.
@export var loud_db := -11.0
@export var quiet_db := -17.0
## How much it drops while someone is speaking.
@export var duck_db := -7.0
## Seconds to fade from one loop to another.
@export var fade := 1.6

## The loop wanted now, such as "calm_0"; "" for silence.
var want := ""
## On the menus and while paused.
var quiet := true
## Someone is speaking.
var ducked := false
## The clock is in its last two minutes: the tide bell is struck each bar.
var late := false

var _a := AudioStreamPlayer.new()
var _b := AudioStreamPlayer.new()
var _bell := AudioStreamPlayer.new()
var _on: AudioStreamPlayer
var _playing := ""
var _streams := {}
var _bar := 0.0


func _ready() -> void:
	for player: AudioStreamPlayer in [_a, _b, _bell]:
		player.volume_db = -60.0
		add_child(player)
	_on = _a


static func file_of(loop: String) -> String:
	for ending: String in [".wav", ".ogg"]:
		if ResourceLoader.exists(FOLDER + loop + ending):
			return FOLDER + loop + ending
	return ""


## The loop for a run as it stands. A fight is played in the part of the place its pack stands
## in, and a boss's fight comes before any other. Out of a fight it is the part you are standing
## in; a doorway is in no part, so there the music stays in the part of `was`, the loop playing now.
static func loop_for(run: Run, was := "") -> String:
	var c := run.combat
	var def := run.level.def
	var fight: Pack = null
	for p in c.packs:
		if p.engaged and not p.cleared and (fight == null or (p.boss and not fight.boss)):
			fight = p
	if fight:
		return "%s_%d" % ["boss" if fight.boss else "fight", (def.rooms[fight.room].zone if fight.room >= 0 else 0) % PARTS]
	var zone := def.zone_at(c.player.pos) if c.player else -1
	if zone < 0:
		zone = int(was.get_slice("_", 1)) if was != "" else 0
	return "calm_%d" % (zone % PARTS)


func _stream(loop: String, looping := true) -> AudioStream:
	if not _streams.has(loop):
		var path := file_of(loop)
		var stream: AudioStream = load(path) if path != "" else null
		# the file plays round and round whatever it says of itself
		if looping and stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		elif looping and stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_streams[loop] = stream
	return _streams[loop]


## Reads the loops from disk now, so that the first fight does not stall while one is read.
func preload_all() -> void:
	for mood: String in ["calm", "fight", "boss"]:
		for zone in 3:
			_stream("%s_%d" % [mood, zone])
	_stream("tide_bell", false)


func _process(delta: float) -> void:
	if want != _playing:
		_playing = want
		# the other player takes the new loop from its start; this one fades away under it
		_on = _b if _on == _a else _a
		var stream := _stream(want) if want != "" else null
		_on.stream = stream
		if stream:
			_on.volume_db = -60.0
			_on.play()
		else:
			_on.stop()
	var level := (quiet_db if quiet else loud_db) + (duck_db if ducked else 0.0)
	var step := 60.0 / fade * delta
	for player: AudioStreamPlayer in [_a, _b]:
		var to := level if player == _on and player.stream != null else -60.0
		player.volume_db = move_toward(player.volume_db, to, step * (1.0 if to > player.volume_db else 0.6))
		if player != _on and player.playing and player.volume_db <= -59.0:
			player.stop()
	if late and not quiet:
		_bar -= delta
		if _bar <= 0.0:
			_bar = BAR
			_bell.stream = _stream("tide_bell", false)
			_bell.volume_db = loud_db + 3.0
			_bell.play()
	else:
		_bar = 0.0


## What is playing now: the loop's name, or "".
func playing() -> String:
	return _playing
