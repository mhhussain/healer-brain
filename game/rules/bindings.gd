class_name Bindings
extends RefCounted

# Which key, mouse button or click does what, as rules on the saved data: no input is read here.
# Keys are physical keycodes (where the key sits, whatever is printed on it).
#
# Every ability has two key slots and one mouse button (middle, side back or side forward) that
# casts it wherever the pointer is. A healer's ally abilities can also be bound to a click on a
# party frame, plain or with Shift, Ctrl or Alt. A key or button does one thing: binding it to
# an ability takes it away from the ability that had it.

## Keys the game keeps for itself, and what for.
const RESERVED := {
	KEY_A: "moving", KEY_Q: "moving", KEY_D: "moving", KEY_E: "moving", KEY_W: "moving", KEY_S: "moving",
	KEY_SPACE: "jumping", KEY_TAB: "targeting", KEY_ESCAPE: "the menu", KEY_P: "pausing", KEY_M: "sound",
}
## The mouse buttons an ability can take, and the buttons a click-cast can use.
const MOUSE: Array[String] = ["M", "X1", "X2"]
const BUTTONS: Array[String] = ["L", "R", "M", "X1", "X2"]
const BUTTON_NAMES := {"L": "Left click", "R": "Right click", "M": "Middle click", "X1": "Side back", "X2": "Side forward"}
const MOD_NAMES := {"S": "Shift", "C": "Ctrl", "A": "Alt"}
const MOUSE_SHORT := {"M": "Mid", "X1": "Mb4", "X2": "Mb5"}
const KEY_NAMES := {KEY_QUOTELEFT: "`", KEY_MINUS: "-", KEY_EQUAL: "=", KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]",
	KEY_BACKSLASH: "\\", KEY_SEMICOLON: ";", KEY_APOSTROPHE: "'", KEY_COMMA: ",", KEY_PERIOD: ".", KEY_SLASH: "/"}


## Every click a party frame can take: each button, plain and with each modifier.
static func combos() -> Array[String]:
	var out: Array[String] = []
	for mod: String in ["", "S+", "C+", "A+"]:
		for b in BUTTONS:
			out.append(mod + b)
	return out


## 1 to 6 in order, with T also on the interrupt and ` also on the personal defensive (the fifth).
static func default_keys(hero_id: String) -> Dictionary:
	var out := {}
	var abilities := Heroes.by_id(hero_id).abilities
	for i in abilities.size():
		var second := KEY_T if abilities[i].interrupt else KEY_QUOTELEFT if i == 4 else 0
		out[abilities[i].id] = [KEY_1 + i, second]
	return out


## Healers heal by clicking party frames: the two heals on the plain clicks, the dispel and the
## ward on Shift.
static func default_clicks(hero_id: String) -> Dictionary:
	match hero_id:
		"mender": return {"mend": "L", "quick": "R", "purify": "S+L", "ward": "S+R"}
		"bloomweaver": return {"vine": "L", "bark": "R", "dew": "S+L", "bramble": "S+R"}
	return {}


static func reset(save: SaveData, hero_id: String) -> void:
	save.keys[hero_id] = default_keys(hero_id)
	save.mouse[hero_id] = {}
	save.clicks[hero_id] = default_clicks(hero_id)


# ---------- changing them

## Puts a key in one of an ability's two slots, taking it from wherever else it was. Returns ""
## if it was done, or why not.
static func set_key(save: SaveData, hero_id: String, ab_id: String, slot: int, code: int) -> String:
	if RESERVED.has(code):
		return "%s is kept for %s" % [key_name(code), RESERVED[code]]
	var mine: Dictionary = save.keys[hero_id]
	for other: String in mine:
		for i in 2:
			if mine[other][i] == code:
				mine[other][i] = 0
	mine[ab_id][slot] = code
	return ""


static func clear_key(save: SaveData, hero_id: String, ab_id: String, slot: int) -> void:
	save.keys[hero_id][ab_id][slot] = 0


## Gives an ability a mouse button, or none with "". The button is taken from any other ability.
static func set_mouse(save: SaveData, hero_id: String, ab_id: String, button: String) -> void:
	var mine: Dictionary = save.mouse[hero_id]
	for other: String in mine.keys():
		if mine[other] == button or other == ab_id:
			mine.erase(other)
	if button != "":
		mine[ab_id] = button


## Gives an ally ability a click on a party frame, or none with "".
static func set_click(save: SaveData, hero_id: String, ab_id: String, combo: String) -> void:
	var mine: Dictionary = save.clicks[hero_id]
	for other: String in mine.keys():
		if mine[other] == combo or other == ab_id:
			mine.erase(other)
	if combo != "":
		mine[ab_id] = combo


# ---------- looking them up

static func _index_of(hero_id: String, ab_id: String) -> int:
	var abilities := Heroes.by_id(hero_id).abilities
	for i in abilities.size():
		if abilities[i].id == ab_id:
			return i
	return -1


## Which of the hero's abilities a key uses: its place in the kit, or -1.
static func ability_for_key(save: SaveData, hero_id: String, code: int) -> int:
	var mine: Dictionary = save.keys[hero_id]
	for ab_id: String in mine:
		if code != 0 and mine[ab_id].has(code):
			return _index_of(hero_id, ab_id)
	return -1


static func ability_for_mouse(save: SaveData, hero_id: String, button: String) -> int:
	var mine: Dictionary = save.mouse[hero_id]
	for ab_id: String in mine:
		if mine[ab_id] == button:
			return _index_of(hero_id, ab_id)
	return -1


static func ability_for_click(save: SaveData, hero_id: String, combo: String) -> int:
	var mine: Dictionary = save.clicks[hero_id]
	for ab_id: String in mine:
		if mine[ab_id] == combo:
			return _index_of(hero_id, ab_id)
	return -1


# ---------- words for them

static func key_name(code: int) -> String:
	if code == 0:
		return ""
	return KEY_NAMES[code] if KEY_NAMES.has(code) else OS.get_keycode_string(code)


## "Shift + Left click" for "S+L".
static func combo_name(combo: String) -> String:
	var parts := combo.split("+")
	var words: Array[String] = []
	for p in parts:
		words.append(MOD_NAMES[p] if MOD_NAMES.has(p) and parts.size() > 1 and p != parts[-1] else BUTTON_NAMES[p])
	return " + ".join(words)


## What an action button shows: its keys, then its mouse button, such as "4 · T · Mb4".
static func label(save: SaveData, hero_id: String, ab_id: String) -> String:
	var parts: Array[String] = []
	for code: int in save.keys[hero_id].get(ab_id, []):
		if code != 0:
			parts.append(key_name(code))
	var button: String = save.mouse[hero_id].get(ab_id, "")
	if button != "":
		parts.append(MOUSE_SHORT[button])
	return " · ".join(parts)


## The name of the button and modifier a mouse event was made with: "S+L", "X1" and so on, or "".
static func combo_of(button_index: int, shift: bool, ctrl: bool, alt: bool) -> String:
	var names := {MOUSE_BUTTON_LEFT: "L", MOUSE_BUTTON_RIGHT: "R", MOUSE_BUTTON_MIDDLE: "M",
		MOUSE_BUTTON_XBUTTON1: "X1", MOUSE_BUTTON_XBUTTON2: "X2"}
	if not names.has(button_index):
		return ""
	return ("S+" if shift else "C+" if ctrl else "A+" if alt else "") + names[button_index]
