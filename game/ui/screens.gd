class_name Screens
extends RefCounted

# The screens outside a run and over it: the title, the start screen, the settings, the pause
# menu and the summary. Each is built here and handed the things to call when its buttons are
# pressed. The screens for gear are in ui/gear_screens.gd.

const ROLES := ["Tank", "Healer", "Damage", "Damage"]
const CONTROLS := "W A S D move (Q and E also go left and right).  Space jumps.  The mouse wheel zooms.\nTab or a left click targets an enemy; Esc clears it, and Esc again opens this menu.  P pauses.  M opens the map, between fights.\nAn ally ability goes to the ally under the mouse: a party frame or the figure. With nobody under it, to you."


static func title(on_begin: Callable, on_gear := Callable()) -> Control:
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
	if on_gear.is_valid():
		var gear := Kit.button("Gear", on_gear, 14)
		gear.name = "Gear"
		gear.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(gear)
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


## The card shown while a run is made ready. Its bar is "Bar" and the line under it "Step".
static func loading(place: String) -> Control:
	var root := Kit.screen(1.0)
	root.name = "Loading"
	var col := Kit.vbox(14)
	col.add_child(Kit.label("Going down to " + place, 22, Kit.GOLD))
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(420, 14)
	bar.max_value = 1.0
	bar.show_percentage = false
	col.add_child(bar)
	var step := Kit.label("", 13, Kit.GREY)
	step.name = "Step"
	col.add_child(step)
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
	mute.text = "Off"
	mute.button_pressed = save.muted
	mute.toggled.connect(func(off: bool) -> void:
		save.muted = off
		on_change.call())
	row.add_child(mute)
	return row


## Whether the next pull's spots are marked on the ground during a run.
static func markers_row(save: SaveData, on_change: Callable) -> Control:
	var box := CheckBox.new()
	box.name = "Markers"
	box.text = "Mark the next pull and its spots on the ground"
	box.button_pressed = save.markers
	box.toggled.connect(func(on: bool) -> void:
		save.markers = on
		on_change.call())
	return box


## The start screen: three choices side by side, each with an editor of its own behind it.
## The dungeon and its level; the team that goes in; the route it takes. A run can always be
## started with what is there. `on_change` is called whenever the save has changed and
## `on_start` when the run should begin; `go` holds what opens the other screens: "route",
## "team", "gear" and "settings", any of which may be missing.
static func setup(save: SaveData, on_change: Callable, on_start: Callable, go := {}) -> Control:
	var root := Kit.screen(1.0)
	root.name = "Setup"
	var all := Kit.vbox(18)
	Kit.panel_of(root).add_child(all)
	var cols := Kit.hbox(36)
	all.add_child(cols)
	# rebuilt from the save after every change, so every part agrees with it
	var rebuild := func() -> void:
		on_change.call()
		GearScreens.swap(root, setup(save, on_change, on_start, go))
	var place := Levels.by_name(save.place)
	var team := Teams.in_use(save)
	var played := Heroes.by_id(team.party[team.slot])

	# the dungeon, and the level: any you have unlocked there
	var levels := Kit.vbox(8)
	levels.name = "Levels"
	levels.add_child(Kit.label("Dungeon and level", 20, Kit.GOLD))
	var which := Kit.hbox(8)
	for id in Levels.DUNGEONS:
		var there := Levels.by_name(id)
		var pick := Kit.button(there.name, func() -> void:
			save.place = id
			rebuild.call(), 14)
		pick.name = "Dungeon_" + id
		if id == save.place:
			pick.add_theme_color_override("font_color", Kit.GOLD)
		which.add_child(pick)
	levels.add_child(which)
	var bosses := place.packs.filter(func(p: Dictionary) -> bool: return p.boss).size()
	levels.add_child(Kit.para("%d packs and %d bosses, to be done in %s. %s" % [place.packs.size() - bosses, bosses, Kit.clock(place.time_limit),
		"It holds more than its count asks for: some packs can be left." if place.count_needed > 0 else "Every pack must fall."], 12, Kit.GREY, 360.0))
	var grid := GridContainer.new()
	grid.columns = 7
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
	levels.add_child(Kit.para("Enemies have 8%% more health and hit 8%% harder each level, and learn new tricks at 3, 6 and 9. Finish inside %s to unlock the next, inside %s for two and inside %s for three. Each dungeon keeps its own levels." % [
		Kit.clock(place.time_limit), Kit.clock(place.time_limit * 0.8), Kit.clock(place.time_limit * 0.6)], 12, Kit.GREY, 360.0))
	levels.add_child(Kit.para("A chest at level %d holds gear up to item level %d%s." % [save.level, Items.ceiling(save.level),
		"" if save.level >= Items.RARE_FROM else ", and nothing rarer than uncommon but trinkets"], 12, Kit.GREY, 360.0))
	var record := save.record_at(save.level)
	var best := Kit.para("Best at level %d: %s" % [save.level, "%s, by %s (you as %s)" % [Kit.clock(record.time),
		Kit.listed(record.party.map(func(id: String) -> String: return Heroes.by_id(id).name)),
		Heroes.by_id(record.party[record.slot]).name] if not record.is_empty() else "none yet"], 12, Kit.BONE, 360.0)
	best.name = "Record"
	levels.add_child(best)
	var top: int = save.progress_in(save.place).timed
	var mine: Dictionary = save.bests.get(played.id, {})
	levels.add_child(Kit.para("Highest level timed here: %s. Your best as %s: %s." % [str(top) if top > 0 else "none yet", played.name,
		"level %d in %s" % [mine.level, Kit.clock(mine.time)] if not mine.is_empty() else "none yet"], 12, Kit.GREY, 360.0))
	cols.add_child(levels)

	# the team: who goes in, which of them is you, and what they wear
	var crew := Kit.vbox(8)
	crew.name = "Crew"
	crew.add_child(Kit.label("Team", 20, Kit.GOLD))
	var teams := OptionButton.new()
	teams.name = "TeamPick"
	teams.custom_minimum_size.x = 220
	for at in save.teams.size() + 1:
		teams.add_item(Teams.at(save, at).name)
	teams.select(save.team)
	teams.item_selected.connect(func(at: int) -> void:
		save.team = at
		rebuild.call())
	crew.add_child(teams)
	var worn := Teams.worn(save, team)
	for i in 4:
		var def := Heroes.by_id(team.party[i])
		var who := Kit.hbox(8)
		var role := Kit.label(ROLES[i], 12, Kit.GREY)
		role.custom_minimum_size.x = 56
		who.add_child(role)
		var named := Kit.label(def.name + ("  (you)" if i == team.slot else ""), 14, def.color)
		named.name = "Hero%d" % i
		who.add_child(named)
		crew.add_child(who)
		var wears := Kit.hbox(10)
		var pad := Control.new()
		pad.custom_minimum_size.x = 56
		wears.add_child(pad)
		var any := false
		for slot in Items.SLOTS:
			var on: Dictionary = worn[i][slot]
			if on.is_empty():
				continue
			any = true
			var item := GearScreens.item_name(on, 12)
			item.text = on.name if slot == "trinket" else "%s %d" % [Items.SLOT_NAMES[slot], on.ilvl]
			wears.add_child(item)
		if not any:
			wears.add_child(Kit.label("No gear", 12, Color(Kit.GREY, 0.6)))
		crew.add_child(wears)
	crew.add_child(Kit.para("%s. You play %s; the AI plays the other three." % [GearScreens.gear_level_words(save), played.name], 12, Kit.GREY, 330.0))
	if go.has("team"):
		var edit := Kit.button("Change the team", go.team, 14)
		edit.name = "Team"
		edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		crew.add_child(edit)
	cols.add_child(crew)

	# the route: the one used last, or the safe way if none was ever planned
	var way := Kit.vbox(8)
	way.name = "Route"
	var plan := save.route_for(place)
	way.add_child(Kit.label("Route", 20, Kit.GOLD))
	var pulls := plan.pulls.filter(func(p: Dictionary) -> bool: return not p.packs.is_empty()).size()
	var route_name := Kit.para("%s: %d pulls" % [plan.name if plan.name != "" else "Unnamed", pulls], 14, Kit.BONE, 300.0)
	route_name.name = "RouteName"
	way.add_child(route_name)
	way.add_child(Kit.para("Which packs the tank pulls together, in what order, and where everyone stands. Leave it and the party goes the safe way.", 12, Kit.GREY, 300.0))
	if go.has("route"):
		var route := Kit.button("Plan the route", go.route, 14)
		route.name = "Plan"
		route.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		way.add_child(route)
	cols.add_child(way)

	var foot := Kit.hbox(10)
	if go.has("gear"):
		var gear := Kit.button("Gear", go.gear, 14)
		gear.name = "Gear"
		foot.add_child(gear)
	if go.has("settings"):
		var opts := Kit.button("Settings and keys", go.settings, 14)
		opts.name = "Settings"
		foot.add_child(opts)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	var start := Kit.button("Enter " + ("the Abbey" if place.id == "abbey" else place.name), func() -> void: on_start.call(), 18)
	start.name = "Start"
	foot.add_child(start)
	all.add_child(foot)
	return root


## How to play, the sound, the keys of the hero you play and of the gear, and keeping the
## save as a file. `on_save_file` and `on_load_file` do that; `note` says how the last went.
## Loading asks first, since it replaces everything: `asking` is whether it is asking now.
static func settings(save: SaveData, hero_id: String, on_change: Callable, on_back: Callable, on_save_file := Callable(), on_load_file := Callable(), note := "", asking := false) -> Control:
	var root := Kit.screen(1.0)
	root.name = "Settings"
	var cols := Kit.hbox(36)
	Kit.panel_of(root).add_child(cols)
	var col := Kit.vbox(10)
	cols.add_child(col)
	col.add_child(Kit.label("Settings", 24, Kit.GOLD))
	col.add_child(Kit.label("How to play", 16, Kit.GOLD))
	col.add_child(Kit.para(CONTROLS.replace("this menu", "the menu"), 12, Kit.GREY, 520.0))
	col.add_child(sound_row(save, on_change))
	col.add_child(markers_row(save, on_change))
	if on_save_file.is_valid():
		col.add_child(Kit.label("Your save", 16, Kit.GOLD))
		col.add_child(Kit.para("Everything you have earned lives in this browser, or on this machine. Keep a copy as a file, and load it back here or anywhere else.", 12, Kit.GREY, 520.0))
		var files := Kit.hbox(10)
		var out := Kit.button("Save to a file", on_save_file, 13)
		out.name = "SaveFile"
		files.add_child(out)
		var back_in := Kit.button("It replaces everything here. Load it?" if asking else "Load from a file", func() -> void:
			if asking:
				on_load_file.call()
			else:
				GearScreens.swap(root, settings(save, hero_id, on_change, on_back, on_save_file, on_load_file, "", true)), 13)
		back_in.name = "LoadFile"
		if asking:
			back_in.add_theme_color_override("font_color", Kit.RED)
		files.add_child(back_in)
		col.add_child(files)
		var said := Kit.para(note, 12, Kit.BONE, 520.0)
		said.name = "FileNote"
		col.add_child(said)
	var back := Kit.button("Back", on_back, 16)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(back)

	var keys := Kit.vbox(10)
	keys.add_child(Kit.label("Keys for %s" % Heroes.by_id(hero_id).name, 16, Kit.GOLD))
	var editor := KeysEditor.new()
	editor.name = "Keys"
	editor.show_hero(save, hero_id)
	editor.changed.connect(on_change)
	keys.add_child(editor)
	cols.add_child(keys)
	return root


static func pause(save: SaveData, hero_id: String, on_change: Callable, on_resume: Callable, on_abandon: Callable) -> Control:
	var root := Kit.screen(0.6)
	root.name = "Pause"
	var col := Kit.vbox(10)
	col.add_child(Kit.label("Paused", 24, Kit.GOLD))
	col.add_child(Kit.para(CONTROLS, 12, Kit.GREY, 640.0))
	col.add_child(sound_row(save, on_change))
	col.add_child(markers_row(save, on_change))
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
## `opened` is how many levels the run unlocked, and `unlocked` the highest that may be started
## now. With a chest to open, `on_chest` is given and is the one way on: where to go next is
## asked there.
static func summary(c: Combat, opened: int, unlocked: int, on_again: Callable, on_next: Callable, on_setup: Callable, on_chest := Callable()) -> Control:
	var root := Kit.screen(0.55)
	root.name = "Summary"
	var col := Kit.vbox(10)
	var timed := c.timed()
	var head := Kit.label("%s: %s at level %d" % ["Timed" if timed else "Completed, over the time", Kit.clock(c.total_time()), c.level], 26, Kit.GOLD if timed else Kit.BONE)
	head.name = "Result"
	col.add_child(head)
	var note := "Level %d unlocked." % unlocked if opened == 1 else "A fast clear: levels up to %d unlocked." % unlocked if opened > 1 \
		else "" if timed else "The next level unlocks when you finish inside %s." % Kit.clock(c.time_limit)
	if note != "":
		var news := Kit.label(note, 14, Kit.GOLD if opened > 0 else Kit.GREY)
		news.name = "Unlocked"
		col.add_child(news)
	col.add_child(Kit.label(Hud.progress(c), 12, Kit.GREY))
	var ending := Kit.para(Story.ending(timed, c.place.id if c.place else "abbey").text, 15, Kit.BONE, 620.0)
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
	if on_chest.is_valid():
		var chest := Kit.button("Open the chest", on_chest, 18)
		chest.name = "Chest"
		row.add_child(chest)
	else:
		var again := Kit.button("Run it again", on_again, 16)
		again.name = "Again"
		row.add_child(again)
		if unlocked > c.level:
			var next := Kit.button("On to level %d" % (c.level + 1), on_next, 16)
			next.name = "Next"
			row.add_child(next)
		var back := Kit.button("Back to the start", on_setup, 13)
		back.name = "Setup"
		row.add_child(back)
	col.add_child(row)
	Kit.panel_of(root).add_child(col)
	return root
