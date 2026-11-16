class_name Sound
extends Node

# Plays the game's sound effects. A sound is a file in assets/sound named after what happens
# ("swing_1.wav", "heal.wav"): to change one, save another file over it, as .wav or .ogg.
# Given a run to follow, it turns what the rules report into sounds.

const FOLDER := "res://assets/sound/"

## Every sound: how many takes there are of it (files name_1, name_2 and so on; 0 for one file
## called just name), and how loud it is played, in decibels.
const SOUNDS := {
	"swing": {"takes": 3, "db": -9.0},
	"shot": {"takes": 0, "db": -8.0},
	"fire": {"takes": 3, "db": -10.0},
	"spell": {"takes": 2, "db": -10.0},
	"guard": {"takes": 2, "db": -9.0},
	"surge": {"takes": 0, "db": -7.0},
	"heal": {"takes": 0, "db": -12.0},
	"dispel": {"takes": 0, "db": -10.0},
	"strike": {"takes": 3, "db": -15.0},
	"blow": {"takes": 3, "db": -7.0},
	"death": {"takes": 2, "db": -10.0},
	"fallen": {"takes": 0, "db": -4.0},
	"revive": {"takes": 0, "db": -7.0},
	"interrupt": {"takes": 0, "db": -6.0},
	"chant": {"takes": 0, "db": -13.0},
	"toll": {"takes": 0, "db": -5.0},
	"boom": {"takes": 2, "db": -7.0},
	"stones": {"takes": 2, "db": -5.0},
	"clear": {"takes": 0, "db": -7.0},
	"lamp": {"takes": 0, "db": -4.0},
	"wipe": {"takes": 0, "db": -4.0},
	"ui_click": {"takes": 0, "db": -6.0},
	"ui_deny": {"takes": 0, "db": -14.0},
}

## Which sound a hero's ability makes when it is used. One not listed here is silent: what it
## does (a heal, a dispel, an interrupt) has a sound of its own.
const ABILITIES := {
	"swing": ["strike", "sweep", "slash", "whirl", "thrust", "jab", "bash"],
	"shot": ["quickshot", "piercing", "volley", "jarring"],
	"fire": ["firebolt", "ignite", "burst"],
	"spell": ["rebuke"],
	"guard": ["brace", "ward", "bark", "bramble", "ember", "riposte", "tumble", "unbreakable"],
	"surge": ["sanctuary", "tide", "bloodrush", "hawk", "kindled", "bloom"],
}
## The note each kind of drowned monk sings while casting, in semitones from the recording's.
const CHANT := {"hexer": 0, "shaman": 3, "hatchling": 12, "velisse": -2, "sulmar": -12}

## How many sounds can play at once; a new one past that cuts off the oldest.
@export var voices := 12
## Seconds before the same sound may start again, so twenty hits at once are not twenty sounds.
@export var gap := 0.07
## How much quieter, in decibels, the rest of the party's abilities are than yours.
@export var others_db := -8.0
## How many monks can be heard chanting at once.
@export var chanters := 3

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams := {}  # file name -> AudioStream, or null if there is no such file
var _last := {}  # sound name -> when it last started, in seconds
var _run: Run
var _chants := {}  # enemy id -> its AudioStreamPlayer
var _clear_frame := -1


func _ready() -> void:
	for i in voices:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## The file a take of a sound is in, or "" if there is none.
static func file_of(sound: String, take := 0) -> String:
	var stem := FOLDER + sound + ("_%d" % take if take > 0 else "")
	for ending: String in [".wav", ".ogg"]:
		if ResourceLoader.exists(stem + ending):
			return stem + ending
	return ""


func _stream(sound: String) -> AudioStream:
	var takes: int = SOUNDS[sound].takes
	var take := randi_range(1, takes) if takes > 0 else 0
	var key := "%s %d" % [sound, take]
	if not _streams.has(key):
		var path := file_of(sound, take)
		_streams[key] = load(path) if path != "" else null
	return _streams[key]


## Plays a sound; `db` is added to its usual loudness and `pitch` multiplies its speed. Returns
## the player it is on, or null if it was not played.
func play(sound: String, db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	if not SOUNDS.has(sound):
		return null
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sound, -1.0)) < gap:
		return null
	var stream := _stream(sound)
	if stream == null:
		return null
	_last[sound] = now
	# the next player round the ring that is not holding a chant
	var player: AudioStreamPlayer = null
	for i in _players.size():
		var candidate := _players[(_next + i) % _players.size()]
		if candidate not in _chants.values():
			player = candidate
			_next = (_next + i + 1) % _players.size()
			break
	if player == null:
		return null
	player.stream = stream
	player.volume_db = SOUNDS[sound].db + db
	player.pitch_scale = pitch
	player.play()
	return player


## Reads every sound from disk now, so that the first of each does not stall a fight.
func preload_all() -> void:
	for sound: String in SOUNDS:
		var takes: int = SOUNDS[sound].takes
		for take in range(1 if takes > 0 else 0, takes + 1):
			var key := "%s %d" % [sound, take]
			if not _streams.has(key):
				var path := file_of(sound, take)
				_streams[key] = load(path) if path != "" else null


# ---------- a run's sounds

## Makes the sounds of that run from now on.
func follow(run: Run) -> void:
	_run = run
	run.combat.event.connect(_on_event)
	preload_all()


## The sound that ability makes when used, or "".
static func sound_of_ability(id: String) -> String:
	for sound: String in ABILITIES:
		if id in ABILITIES[sound]:
			return sound
	return ""


func _on_event(e: Dictionary) -> void:
	var c := _run.combat
	match e.k:
		"ability":
			var u := c.unit(e.id)
			var sound := sound_of_ability(e.s)
			if sound != "":
				play(sound, 0.0 if u.is_player else others_db, randf_range(0.94, 1.06))
		"hit":
			var tgt := c.unit(e.id)
			var src := c.unit(e.src)
			if tgt == null or e.amt <= 0.0:
				return
			if tgt.hero:
				# a heavy blow is heard; on you, every blow is, a little
				var heavy: bool = e.amt >= tgt.max_hp * 0.12
				if heavy or tgt.is_player:
					play("blow", (0.0 if heavy else -9.0) + (0.0 if tgt.is_player else -6.0), randf_range(0.9, 1.1))
			elif src and src.is_player and Combat.flat(src.pos, tgt.pos) < 5.0:
				play("strike", 0.0, randf_range(0.92, 1.08))
		"heal":
			var src := c.unit(e.src)
			if src and src.is_player and e.amt > 0.0:
				# a bigger heal rings higher
				play("heal", 0.0, pow(2.0, minf(12.0, roundf(e.amt / 420.0 * 7.0)) / 12.0))
		"dispel":
			play("dispel")
		"gear":
			# a trinket is pressed: the same chime, higher, until it has a sound of its own
			var u := c.unit(e.id)
			play("dispel", 0.0 if u and u.is_player else others_db, 1.35)
		"interrupt":
			play("interrupt")
			_hush(e.id)
		"death":
			var u := c.unit(e.id)
			if u == null:
				return
			_hush(u.id)
			if u.hero:
				play("fallen")
			else:
				# the bigger it was, the deeper it goes down
				play("death", 4.0 if u.enemy.boss else 0.0, clampf(1.25 - u.radius * 0.45, 0.6, 1.1) * randf_range(0.95, 1.05))
		"revive":
			play("revive")
		"boom":
			play("boom", 0.0, randf_range(0.9, 1.05))
		"pillar":
			play("stones")
		"clear":
			_clear_frame = Engine.get_physics_frames()
			play("lamp" if c.packs[e.id].boss else "clear")
		"alert":
			# a warning tolls the great bell; the line that says a room is cleared does not
			if _clear_frame != Engine.get_physics_frames():
				play("toll")
		"wipe":
			for player in _players:
				player.stop()
			_chants.clear()
			play("wipe")


func _process(_delta: float) -> void:
	if _run == null:
		return
	# a monk casting something you can stop sings until it lands or is cut off
	for e in _run.combat.enemies:
		var singing: bool = e.alive and e.cast != null and e.cast.interruptible
		if singing and not _chants.has(e.id) and _chants.size() < chanters:
			var semitones: int = CHANT.get(e.enemy.id, -5)
			var player := play("chant", 0.0, pow(2.0, semitones / 12.0))
			if player:
				_chants[e.id] = player
		elif not singing and _chants.has(e.id):
			_hush(e.id)


func _hush(id: int) -> void:
	if _chants.has(id):
		(_chants[id] as AudioStreamPlayer).stop()
		_chants.erase(id)
