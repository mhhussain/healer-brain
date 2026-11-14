extends GutTest

# Milestone 6: which key, mouse button or click does what.

var save: SaveData


func before_each():
	save = SaveData.new()


func test_the_usual_keys():
	assert_eq(Bindings.label(save, "ranger", "quickshot"), "1")
	assert_eq(Bindings.label(save, "ranger", "jarring"), "4 · T", "T is also the interrupt")
	assert_eq(Bindings.label(save, "ranger", "tumble"), "5 · `", "and ` the personal defensive")
	assert_eq(Bindings.label(save, "mender", "ward"), "5 · `")
	assert_eq(Bindings.label(save, "mender", "purify"), "4", "healers have no interrupt, so no T")
	assert_eq(Bindings.ability_for_key(save, "ranger", KEY_T), 3)
	assert_eq(Bindings.ability_for_key(save, "ranger", KEY_QUOTELEFT), 4)
	assert_eq(Bindings.ability_for_key(save, "ranger", KEY_1), 0)
	assert_eq(Bindings.ability_for_key(save, "ranger", KEY_F), -1)


func test_a_key_does_one_thing():
	assert_eq(Bindings.set_key(save, "ranger", "piercing", 1, KEY_F), "")
	assert_eq(Bindings.label(save, "ranger", "piercing"), "2 · F")
	assert_eq(Bindings.set_key(save, "ranger", "volley", 0, KEY_F), "", "binding it elsewhere takes it away")
	assert_eq(Bindings.label(save, "ranger", "piercing"), "2")
	assert_eq(Bindings.label(save, "ranger", "volley"), "F")
	assert_eq(Bindings.ability_for_key(save, "ranger", KEY_3), -1, "and the key it replaced does nothing now")
	assert_eq(Bindings.ability_for_key(save, "pyromancer", KEY_3), 2, "each hero has its own")
	Bindings.clear_key(save, "ranger", "volley", 0)
	assert_eq(Bindings.label(save, "ranger", "volley"), "")


func test_the_games_own_keys_cannot_be_taken():
	assert_eq(Bindings.set_key(save, "ranger", "quickshot", 0, KEY_W), "W is kept for moving")
	assert_eq(Bindings.set_key(save, "ranger", "quickshot", 0, KEY_SPACE), "Space is kept for jumping")
	assert_eq(Bindings.set_key(save, "ranger", "quickshot", 0, KEY_TAB), "Tab is kept for targeting")
	assert_eq(Bindings.label(save, "ranger", "quickshot"), "1", "nothing changed")


func test_mouse_buttons():
	Bindings.set_mouse(save, "pyromancer", "ignite", "M")
	Bindings.set_mouse(save, "pyromancer", "ember", "X1")
	assert_eq(Bindings.label(save, "pyromancer", "ignite"), "2 · Mid")
	assert_eq(Bindings.label(save, "pyromancer", "ember"), "5 · ` · Mb4")
	assert_eq(Bindings.ability_for_mouse(save, "pyromancer", "X1"), 4)
	Bindings.set_mouse(save, "pyromancer", "burst", "M")
	assert_eq(Bindings.ability_for_mouse(save, "pyromancer", "M"), 2, "a button does one thing")
	assert_eq(Bindings.label(save, "pyromancer", "ignite"), "2")
	Bindings.set_mouse(save, "pyromancer", "burst", "")
	assert_eq(Bindings.ability_for_mouse(save, "pyromancer", "M"), -1)


func test_healers_click_party_frames():
	assert_eq(Bindings.ability_for_click(save, "mender", "L"), 0, "left click is Warm Light")
	assert_eq(Bindings.ability_for_click(save, "mender", "R"), 1)
	assert_eq(Bindings.ability_for_click(save, "mender", "S+L"), 3, "Shift and left is the dispel")
	assert_eq(Bindings.ability_for_click(save, "mender", "S+R"), 4)
	assert_eq(Bindings.ability_for_click(save, "bloomweaver", "L"), 0)
	assert_eq(Bindings.ability_for_click(save, "ranger", "L"), -1, "others have none")
	Bindings.set_click(save, "mender", "quick", "X2")
	assert_eq(Bindings.ability_for_click(save, "mender", "X2"), 1)
	assert_eq(Bindings.ability_for_click(save, "mender", "R"), -1)
	Bindings.set_click(save, "mender", "purify", "L")
	assert_eq(Bindings.ability_for_click(save, "mender", "L"), 3, "a click does one thing")
	assert_false(save.clicks["mender"].has("mend"))


func test_names_for_clicks_and_events():
	assert_eq(Bindings.combo_name("L"), "Left click")
	assert_eq(Bindings.combo_name("S+R"), "Shift + Right click")
	assert_eq(Bindings.combo_name("A+X1"), "Alt + Side back")
	assert_eq(Bindings.combos().size(), 20)
	assert_eq(Bindings.combo_of(MOUSE_BUTTON_LEFT, true, false, false), "S+L")
	assert_eq(Bindings.combo_of(MOUSE_BUTTON_XBUTTON2, false, false, false), "X2")
	assert_eq(Bindings.combo_of(MOUSE_BUTTON_WHEEL_UP, false, false, false), "")


func test_going_back_to_the_usual():
	Bindings.set_key(save, "mender", "mend", 0, KEY_F)
	Bindings.set_mouse(save, "mender", "mend", "M")
	Bindings.set_click(save, "mender", "mend", "A+L")
	Bindings.reset(save, "mender")
	assert_eq(Bindings.label(save, "mender", "mend"), "1")
	assert_eq(Bindings.ability_for_click(save, "mender", "L"), 0)


func test_bindings_survive_the_file_and_bad_ones_are_dropped():
	Bindings.set_key(save, "ranger", "piercing", 1, KEY_F)
	Bindings.set_mouse(save, "ranger", "hawk", "X2")
	Bindings.set_click(save, "bloomweaver", "bark", "C+L")
	# what a file gives back: numbers as floats
	var back := SaveData.from_dict(JSON.parse_string(JSON.stringify(save.to_dict())))
	assert_eq(Bindings.label(back, "ranger", "piercing"), "2 · F")
	assert_eq(Bindings.label(back, "ranger", "hawk"), "6 · Mb5")
	assert_eq(Bindings.ability_for_click(back, "bloomweaver", "C+L"), 1)
	var odd := SaveData.from_dict({"keys": {"ranger": {"piercing": [70], "nonsense": [1, 2]}, "ghost": {}},
		"mouse": {"ranger": {"hawk": "Z9"}}, "clicks": {"mender": {"rebuke": "L"}}})
	assert_eq(Bindings.label(odd, "ranger", "piercing"), "2", "a broken entry keeps the usual key")
	assert_false(odd.keys["ranger"].has("nonsense"))
	assert_eq(Bindings.ability_for_mouse(odd, "ranger", "Z9"), -1)
	assert_eq(Bindings.ability_for_click(odd, "mender", "L"), -1, "an enemy ability cannot be on a frame click")
