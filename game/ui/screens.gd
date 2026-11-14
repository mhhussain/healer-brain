class_name Screens
extends RefCounted

# The screens outside a run and over it: the title, the party setup, the pause menu and the
# summary. Each is built here and handed the things to call when its buttons are pressed.

const ROLES := ["Tank", "Healer", "Damage", "Damage"]
const CONTROLS := "W A S D move (Q and E also go left and right).  Space jumps.  The mouse wheel zooms.\nTab or a left click targets an enemy; Esc clears it, and Esc again opens this menu.  P pauses.\nAn ally ability goes to the ally under the mouse: a party frame or the figure. With nobody under it, to you."


static func title(on_begin: Callable) -> Control:
	var root := Kit.screen(1.0)
	root.name = "Title"
	var col := Kit.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var name := Kit.label("Fourfold", 64, Kit.GOLD)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name)
	var sub := Kit.label("The Drowned Abbey", 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var begin := Kit.button("Begin", on_begin, 18)
	begin.name = "Begin"
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(begin)
	Kit.panel_of(root).add_child(col)
	return root


## The story so far, on one card: each line lights up as the narrator reaches it. Call
## `light(root, id)` when a line begins.
static func opening(on_done: Callable) -> Control:
	var root := Kit.screen(1.0)
	root.name = "Opening"
	var col := Kit.vbox(18)
	col.add_child(Kit.label("The Last Vespers", 26, Kit.GOLD))
	for i in Story.OPENING.size():
		var line := Kit.para(Story.OPENING[i], 18, Kit.BONE, 620.0)
		line.name = "opening_%d" % (i + 1)
		line.modulate.a = 0.3
		col.add_child(line)
	var go := Kit.button("Go down", on_done, 16)
	go.name = "Continue"
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(go)
	Kit.panel_of(root).add_child(col)
	return root


## Lights the line with that id on the opening card.
static func light(card: Control, id: String) -> void:
	var line := card.find_child(id, true, false) as Label
	if line:
		line.create_tween().tween_property(line, "modulate:a", 1.0, 0.5)


## How loud, and whether sound is on at all. `on_change` is called when either changes.
static func sound_row(save: SaveData, on_change: Callable) -> Control:
	var row := Kit.hbox(10)
	row.name = "Sound"
	row.add_child(Kit.label("Sound", 12, Kit.GREY))
	var slider := HSlider.new()
	slider.name = "Volume"
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = save.volume
	slider.custom_minimum_size = Vector2(150, 20)
	slider.value_changed.connect(func(v: float) -> void:
		save.volume = v
		on_change.call())
	row.add_child(slider)
	var mute := CheckBox.new()
	mute.name = "Mute"
	mute.text = "Off (M)"
	mute.button_pressed = save.muted
	mute.toggled.connect(func(off: bool) -> void:
		save.muted = off
		on_change.call())
	row.add_child(mute)
	return row


## The party, your hero and its keys, and the level. `on_change` is called whenever the save
## has changed; `on_start` when the run should begin.
static func setup(save: SaveData, on_change: Callable, on_start: Callable) -> Control:
	var root := Kit.screen(1.0)
	root.name = "Setup"
	var cols := Kit.hbox(28)
	Kit.panel_of(root).add_child(cols)
	# rebuilt from the save after every change, so every part agrees with it
	var rebuild := func() -> void:
		on_change.call()
		var fresh := setup(save, on_change, on_start)
		var parent := root.get_parent()
		if parent:
			var place := root.get_index()
			parent.remove_child(root)
			root.queue_free()
			parent.add_child(fresh)
			parent.move_child(fresh, place)

	# the crew: who fills each place, and which of them is you
	var crew := Kit.vbox(8)
	crew.name = "Crew"
	crew.add_child(Kit.label("Your crew", 20, Kit.GOLD))
	var choices := [Heroes.TANKS, Heroes.HEALERS, Heroes.DPS, Heroes.DPS]
	for slot in 4:
		var row := Kit.hbox(8)
		var role := Kit.label(ROLES[slot], 12, Kit.GREY)
		role.custom_minimum_size.x = 56
		row.add_child(role)
		var pick := OptionButton.new()
		pick.name = "Pick%d" % slot
		pick.custom_minimum_size.x = 170
		for id: String in choices[slot]:
			pick.add_item(Heroes.by_id(id).name)
		pick.select(choices[slot].find(save.party[slot]))
		pick.item_selected.connect(func(i: int) -> void:
			save.party[slot] = choices[slot][i]
			rebuild.call())
		row.add_child(pick)
		var you := Kit.button("You" if save.slot == slot else "Play", func() -> void:
			save.slot = slot
			rebuild.call(), 12)
		you.name = "You%d" % slot
		you.custom_minimum_size.x = 56
		if save.slot == slot:
			you.add_theme_color_override("font_color", Kit.GOLD)
		row.add_child(you)
		crew.add_child(row)
	crew.add_child(Kit.para("The AI plays the other three. Any hero may be in the crew twice.", 12, Kit.GREY, 300.0))
	crew.add_child(Kit.label("How to play", 16, Kit.GOLD))
	crew.add_child(Kit.para(CONTROLS.replace("this menu", "the menu"), 12, Kit.GREY, 300.0))
	crew.add_child(sound_row(save, on_change))
	cols.add_child(crew)

	# your hero: how to play it, what it does, and its keys
	var def := Heroes.by_id(save.party[save.slot])
	var hero := Kit.vbox(6)
	hero.name = "Hero"
	hero.add_child(Kit.label("%s, %s" % [def.name, def.title], 20, def.color))
	hero.add_child(Kit.label(def.sub, 12, Kit.GREY))
	hero.add_child(Kit.para(def.how_to, 13, Kit.BONE, 560.0))
	for ab in def.abilities:
		hero.add_child(Kit.para("%s: %s" % [ab.name, ab.desc], 12, Kit.GREY, 560.0))
	var editor := KeysEditor.new()
	editor.name = "Keys"
	editor.show_hero(save, def.id)
	editor.changed.connect(on_change)
	hero.add_child(editor)
	cols.add_child(hero)

	# the level: any you have unlocked
	var levels := Kit.vbox(8)
	levels.name = "Levels"
	levels.add_child(Kit.label("Level", 20, Kit.GOLD))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	save.level = clampi(save.level, 1, save.unlocked)
	for n in range(1, save.unlocked + 1):
		var b := Kit.button(str(n), func() -> void:
			save.level = n
			rebuild.call(), 14)
		b.name = "Level%d" % n
		b.custom_minimum_size = Vector2(46, 34)
		if n == save.level:
			b.add_theme_color_override("font_color", Kit.GOLD)
		grid.add_child(b)
	levels.add_child(grid)
	levels.add_child(Kit.para("Enemies have 8% more health and hit 8% harder each level, and learn new tricks at 3, 6 and 9. Finish inside 14:00 to unlock the next.", 12, Kit.GREY, 230.0))
	var best: Dictionary = save.bests.get(def.id, {})
	levels.add_child(Kit.para("Your best as %s: %s" % [def.name.split(" ")[0],
		"level %d in %s" % [best.level, Kit.clock(best.time)] if not best.is_empty() else "none yet"], 12, Kit.BONE, 230.0))
	var start := Kit.button("Enter the Abbey", func() -> void: on_start.call(), 18)
	start.name = "Start"
	levels.add_child(start)
	cols.add_child(levels)
	return root


static func pause(save: SaveData, hero_id: String, on_change: Callable, on_resume: Callable, on_abandon: Callable) -> Control:
	var root := Kit.screen(0.6)
	root.name = "Pause"
	var col := Kit.vbox(10)
	col.add_child(Kit.label("Paused", 24, Kit.GOLD))
	col.add_child(Kit.para(CONTROLS, 12, Kit.GREY, 640.0))
	col.add_child(sound_row(save, on_change))
	var editor := KeysEditor.new()
	editor.name = "Keys"
	editor.show_hero(save, hero_id)
	editor.changed.connect(on_change)
	col.add_child(editor)
	var row := Kit.hbox(10)
	var resume := Kit.button("Back to the run", on_resume, 16)
	resume.name = "Resume"
	row.add_child(resume)
	var abandon := Kit.button("Abandon the run", on_abandon, 13)
	abandon.name = "Abandon"
	row.add_child(abandon)
	col.add_child(row)
	Kit.panel_of(root).add_child(col)
	return root


## The end of a run: the result, what each hero did, and where to go next.
static func summary(c: Combat, unlocked_now: bool, can_go_up: bool, on_again: Callable, on_next: Callable, on_setup: Callable) -> Control:
	var root := Kit.screen(0.55)
	root.name = "Summary"
	var col := Kit.vbox(10)
	var timed := c.timed()
	var head := Kit.label("%s: %s at level %d" % ["Timed" if timed else "Completed, over the time", Kit.clock(c.total_time()), c.level], 26, Kit.GOLD if timed else Kit.BONE)
	head.name = "Result"
	col.add_child(head)
	var note := "Level %d unlocked." % (c.level + 1) if unlocked_now else "" if timed else "The next level unlocks when you finish inside %s." % Kit.clock(Combat.TIME_LIMIT)
	if note != "":
		col.add_child(Kit.label(note, 14, Kit.GOLD if unlocked_now else Kit.GREY))
	col.add_child(Kit.label(Hud.progress(c), 12, Kit.GREY))
	var ending := Kit.para(Story.ending(timed).text, 15, Kit.BONE, 620.0)
	ending.name = "Ending"
	col.add_child(ending)
	var grid := GridContainer.new()
	grid.name = "Table"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 4)
	for word: String in ["", "damage a second", "healing a second", "silenced", "cleansed", "deaths"]:
		grid.add_child(Kit.label(word, 11, Kit.GREY))
	var secs := maxf(1.0, c.elapsed)
	for h in c.heroes:
		grid.add_child(Kit.label(h.name + (" (you)" if h.is_player else ""), 14, h.hero.color))
		for cell: String in ["%d" % roundi(h.stats.dmg / secs), "%d" % roundi(h.stats.heal / secs), str(h.stats.interrupts), str(h.stats.dispels), str(h.stats.deaths)]:
			var l := Kit.label(cell, 14)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(l)
	col.add_child(grid)
	var row := Kit.hbox(10)
	var again := Kit.button("Run it again", on_again, 16)
	again.name = "Again"
	row.add_child(again)
	if can_go_up:
		var next := Kit.button("On to level %d" % (c.level + 1), on_next, 16)
		next.name = "Next"
		row.add_child(next)
	var back := Kit.button("Change the crew", on_setup, 13)
	back.name = "Setup"
	row.add_child(back)
	col.add_child(row)
	Kit.panel_of(root).add_child(col)
	return root
