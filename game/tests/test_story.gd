extends GutTest

# Milestone 7: what the party says, when, and the voice files that say it.

const DT := 1.0 / 60.0
const VOICE := "res://assets/voice/"

var combat: Combat
var story: Story
var said: Array[Dictionary]


func before_each():
	combat = Combat.new(1, 4)
	combat.ai_plays = false
	for id: String in ["warden", "mender", "duelist", "ranger"]:
		combat.add_hero(Heroes.by_id(id), id == "ranger")
	# three parts of three rooms, the third of each a boss, as in the Abbey
	var bosses := ["krogg", "velisse", "sulmar"]
	for i in 9:
		var boss := i % 3 == 2
		combat.add_pack("Room %d" % i, boss)
		combat.spawn_enemy(bosses[i / 3] if boss else "brute", Vector3(100 + i * 50, 0, 0), i)
	story = Story.new(combat)
	said = []
	story.said.connect(func(line: Dictionary) -> void: said.append(line))


func pull(pack: int) -> void:
	combat.engage(combat.packs[pack], combat.heroes[0])


func clear(pack: int) -> void:
	for e in combat.packs[pack].units:
		combat.damage(combat.heroes[0], e, 9999999.0)
	combat.tick(DT)
	story.frame(DT)


func wait(seconds: float) -> void:
	for i in roundi(seconds / DT):
		combat.tick(DT)
		story.frame(DT)


# ---------- the lines and their files

func test_every_line_has_an_id_of_its_own():
	var lines := Story.all_lines()
	var ids := {}
	for line in lines:
		assert_false(ids.has(line.id), line.id + " is used twice")
		ids[line.id] = true
		assert_true(line.speaker == Story.NARRATOR or Heroes.by_id(line.speaker) != null, line.id)
	assert_eq(lines.size(), 61)
	assert_eq(lines[0], {"id": "opening_1", "speaker": "narrator", "text": Story.OPENING[0]})
	assert_true(ids.has("warden_pull_4"))
	assert_true(ids.has("ranger_late_1"))
	for hero in Heroes.ALL:
		for moment in Story.MOMENTS:
			assert_gt(Story.LINES[hero][moment].size(), 0, "%s has something to say at %s" % [hero, moment])


func test_the_manifest_matches_the_story():
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(VOICE + "voice_lines.json"))
	assert_eq(manifest, Story.all_lines(), "run tests/tools/voice_manifest.gd after changing the story")


func test_every_line_has_a_voice_file_made_from_its_words():
	var built: Variant = JSON.parse_string(FileAccess.get_file_as_string(VOICE + "voice_built.json"))
	for line in Story.all_lines():
		assert_true(ResourceLoader.exists(Voice.file_of(line.id)), line.id + " has a voice file")
		assert_eq(built.get(line.id, {}).get("text"), line.text, line.id + ": the file was made from these words; run tools/voice/make_voice.py")
	assert_eq(built.size(), Story.all_lines().size(), "and there are no files for lines that are gone")


# ---------- when they are said

func test_a_pull_gets_one_line_and_the_party_take_turns():
	pull(0)
	assert_eq(said.size(), 1)
	assert_eq(said[0].id, "warden_pull_1")
	assert_eq(said[0].unit_id, combat.heroes[0].id)
	clear(0)
	pull(1)
	assert_eq(said.size(), 1, "the middle room of each part goes by in silence")
	clear(1)
	pull(3)
	assert_eq(said[1].id, "mender_pull_1", "the next one in the party speaks")
	clear(3)
	pull(6)
	assert_eq(said[2].speaker, "duelist")


func test_a_boss_and_its_lamp_each_get_a_line():
	pull(2)
	assert_eq(said[0].id, "warden_krogg_1")
	clear(2)
	assert_eq(said.size(), 1, "not at once")
	wait(2.0)
	assert_eq(said.size(), 2)
	assert_eq(said[1].id, "mender_lamp_1", "a moment after the boss falls")
	pull(5)
	assert_eq(said[2].id, "duelist_velisse_1")
	pull(8)
	assert_eq(said[3].id, "ranger_sulmar_1")
	assert_eq(said[3].text, "Loud.")


func test_nobody_says_the_same_thing_twice():
	var ranger := combat.heroes[3]
	for h in combat.heroes:
		if h != ranger:
			h.alive = false
	for i in [0, 3, 4, 6, 7]:
		combat.packs[i].engaged = false
		pull(i)
	var hers := said.map(func(line: Dictionary) -> String: return line.id)
	assert_eq(hers, ["ranger_pull_1", "ranger_pull_2", "ranger_pull_3"], "three things to say about a pull, then silence")


func test_a_fall_is_remarked_on_but_not_every_time():
	pull(0)
	said.clear()
	combat.damage(null, combat.heroes[3], 99999.0, "phys", {"raw": true})
	assert_eq(said.size(), 1)
	assert_string_ends_with(said[0].id, "_fallen_1")
	assert_ne(said[0].speaker, "ranger", "the fallen do not speak")
	combat.damage(null, combat.heroes[2], 99999.0, "phys", {"raw": true})
	assert_eq(said.size(), 1, "a second fall straight after gets no line")
	wait(16.0)
	combat.damage(null, combat.heroes[1], 99999.0, "phys", {"raw": true})
	assert_eq(said.size(), 2)


func test_the_tide_is_mentioned_once_with_two_minutes_left():
	pull(0)
	said.clear()
	combat.elapsed = Combat.TIME_LIMIT - 121.0
	wait(0.5)
	assert_eq(said.size(), 0)
	wait(1.0)
	assert_eq(said.size(), 1)
	assert_string_ends_with(said[0].id, "_late_1")
	wait(5.0)
	assert_eq(said.size(), 1)


func test_the_ending_depends_on_the_time():
	assert_eq(Story.ending(true).id, "ending_in_time")
	assert_eq(Story.ending(false).text, Story.ENDING_LATE)


# ---------- the voice

func test_lines_are_said_one_at_a_time_for_as_long_as_their_recording():
	var voice := Voice.new()
	add_child_autofree(voice)
	watch_signals(voice)
	var first := {"id": "opening_2", "speaker": "narrator", "text": Story.OPENING[1]}
	var second := {"id": "warden_pull_1", "speaker": "warden", "text": "In, all of you. The sea takes the doorways first."}
	var length := Voice.seconds_for(first)
	assert_between(length, 2.0, 6.0, "the recording's own length")
	voice.say(first)
	voice.say(second)
	assert_signal_emit_count(voice, "started", 1, "the second waits its turn")
	assert_true(voice.is_talking())
	await wait_seconds(length + 0.6)
	assert_signal_emit_count(voice, "started", 2)
	voice.hush()
	assert_false(voice.is_talking())
	assert_signal_emitted(voice, "finished")


func test_a_line_with_no_recording_still_takes_time_to_read():
	var line := {"id": "not_recorded", "speaker": "warden", "text": "Twenty letters or so."}
	assert_almost_eq(Voice.seconds_for(line), 1.2 + 0.055 * 21, 0.01)


func test_old_talk_is_dropped_when_too_much_is_waiting():
	var voice := Voice.new()
	add_child_autofree(voice)
	var heard: Array[String] = []
	voice.started.connect(func(line: Dictionary, _s: float) -> void: heard.append(line.id))
	for id: String in ["ranger_pull_1", "ranger_pull_2", "ranger_pull_3", "ranger_krogg_1"]:
		voice.say({"id": id, "speaker": "ranger", "text": "Mine."})
	await wait_seconds(4.0)
	assert_eq(heard, ["ranger_pull_1", "ranger_pull_3", "ranger_krogg_1"], "the stalest waiting line is the one let go")
