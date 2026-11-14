class_name Story
extends RefCounted

# The Last Vespers: what the game says, and when. Ported from src/ui/story.ts.
# Every line has an id, which is also the name of its voice file: assets/voice/<id>.wav.

## A party member says a line: {"id", "speaker", "text", "unit_id"}.
signal said(line: Dictionary)

const NARRATOR := "narrator"

const OPENING: Array[String] = [
	"A hundred years ago, Abbot Sulmar rang the great bell against the storm. The sea answered.",
	"Tonight the tide draws back for fourteen minutes.",
	"Three lamps wait in the dark. Light them, and the abbey may finally sleep.",
]
const ENDING_IN_TIME := "You climb the sea stair with dry boots. Below you, for the first time in a hundred years, the abbey sleeps."
const ENDING_LATE := "The tide caught you on the stair and you came home soaked to the collar. But the lamps hold, and the abbey sleeps."

## When a line is said: a pack is pulled, a boss is met, a lamp is lit, someone falls, the tide turns.
const MOMENTS: Array[String] = ["pull", "krogg", "velisse", "sulmar", "lamp", "fallen", "late"]

## One short line each, said in a speech bubble. Nobody says the same thing twice in a run.
const LINES := {
	"mender": {
		"pull": ["Stay close to the light.", "Hold still. This only stings if you argue.", "They were brothers once. Be gentle."],
		"krogg": ["Brother Krogg. We have come to relieve you."],
		"velisse": ["She is still nursing them. Oh, Sister."],
		"sulmar": ["Father Abbot. You can stop ringing now."],
		"lamp": ["One more light against the dark.", "There. Rest now."],
		"fallen": ["No, no, no. Up you get!"],
		"late": ["The tide is turning. I can hear it."],
	},
	"warden": {
		"pull": ["In, all of you. The sea takes the doorways first.", "Behind me. All of you. Yes, you too.", "Steady. I have seen worse weather.", "My knees remember these stairs."],
		"krogg": ["A gatekeeper. I know the type."],
		"velisse": ["Mind the little ones. They nip."],
		"sulmar": ["When that bell swings, find a pillar."],
		"lamp": ["Now that is a proper harbour light."],
		"fallen": ["Hold the line. We will fetch them after."],
		"late": ["Water is coming in. Pick up your feet."],
	},
	"bloomweaver": {
		"pull": ["The sea takes. It also gives back, if you ask nicely.", "Kelp does not hurry. Neither do I.", "Smells like low tide. Lovely."],
		"krogg": ["Poor lamb. Rusted to his post."],
		"velisse": ["A ward full of crabs. She would be mortified."],
		"sulmar": ["He never could leave that rope alone."],
		"lamp": ["There. That will keep the damp off."],
		"fallen": ["Up, dear. The kelp has you."],
		"late": ["She is coming home, the sea. Quick now."],
	},
	"duelist": {
		"pull": ["I am only here for the candlesticks.", "Nobody mentioned they would still be home.", "Is any of this silver?"],
		"krogg": ["Big keys. Must be a big lock."],
		"velisse": ["I have robbed worse hospitals."],
		"sulmar": ["That bell would fetch a fortune. I am only saying."],
		"lamp": ["...Fine. It is a bit lovely."],
		"fallen": ["I am not carrying anyone."],
		"late": ["I cannot swim in these boots."],
	},
	"ranger": {
		"pull": ["Mine.", "Left one.", "Quiet."],
		"krogg": ["Big."],
		"velisse": ["Too many legs."],
		"sulmar": ["Loud."],
		"lamp": ["Good."],
		"fallen": ["Get up."],
		"late": ["Tide."],
	},
	"pyromancer": {
		"pull": ["Sorry. Sorry! That one got away from me.", "Six generations of candles and nobody mentioned this.", "Is it meant to be this damp?"],
		"krogg": ["Excuse us! We have an appointment?"],
		"velisse": ["I am sure she is a very good nurse."],
		"sulmar": ["My great-great-grandfather made his candles."],
		"lamp": ["Oh! It caught first time."],
		"fallen": ["Was that my fault? That felt like my fault."],
		"late": ["Wet wicks. This is my nightmare."],
	},
}

var _combat: Combat
var _used := {}
var _turn := 0
var _late_said := false
var _lamp_in := -1.0
var _fallen_at := -99.0


## Every line in the game, in a fixed order: {"id", "speaker", "text"}. The narrator's first,
## then each hero's by moment.
static func all_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in OPENING.size():
		out.append({"id": "opening_%d" % (i + 1), "speaker": NARRATOR, "text": OPENING[i]})
	out.append({"id": "ending_in_time", "speaker": NARRATOR, "text": ENDING_IN_TIME})
	out.append({"id": "ending_late", "speaker": NARRATOR, "text": ENDING_LATE})
	for hero in Heroes.ALL:
		for moment in MOMENTS:
			var texts: Array = LINES[hero][moment]
			for i in texts.size():
				out.append({"id": "%s_%s_%d" % [hero, moment, i + 1], "speaker": hero, "text": texts[i]})
	return out


## The narrator's line for how the run ended.
static func ending(timed: bool) -> Dictionary:
	return {"id": "ending_in_time" if timed else "ending_late", "speaker": NARRATOR, "text": ENDING_IN_TIME if timed else ENDING_LATE}


func _init(combat: Combat) -> void:
	_combat = combat
	combat.event.connect(_on_event)


func _on_event(e: Dictionary) -> void:
	match e.k:
		"engage":
			var pack := _combat.packs[e.id]
			if pack.boss:
				_speak(pack.units[0].enemy.id)
			# not every pull: the middle room of each part goes by in silence, unless nobody has spoken yet
			elif e.id % 3 != 1 or _turn == 0:
				_speak("pull")
		"clear":
			if _combat.packs[e.id].boss:
				_lamp_in = 1.8
		"death":
			var u := _combat.unit(e.id)
			if u and u.team == "hero" and _combat.time - _fallen_at > 15.0:
				_fallen_at = _combat.time
				_speak("fallen")


## Called every tick, after the rules.
func frame(dt: float) -> void:
	if _lamp_in > 0.0:
		_lamp_in -= dt
		if _lamp_in <= 0.0:
			_speak("lamp")
	if not _late_said and _combat.started and _combat.total_time() > Combat.TIME_LIMIT - 120.0:
		_late_said = true
		_speak("late")


# The next party member in turn who still has something new to say about this.
func _speak(moment: String) -> void:
	if not LINES["warden"].has(moment):
		return
	var alive := _combat.alive_heroes()
	for i in alive.size():
		var h: Combatant = alive[(_turn + i) % alive.size()]
		var texts: Array = LINES[h.hero.id][moment]
		for n in texts.size():
			var id := "%s_%s_%d" % [h.hero.id, moment, n + 1]
			if _used.has(id):
				continue
			_used[id] = true
			_turn += i + 1
			said.emit({"id": id, "speaker": h.hero.id, "text": texts[n], "unit_id": h.id})
			return
