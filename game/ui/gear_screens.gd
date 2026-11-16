class_name GearScreens
extends RefCounted

# The screens for gear: what is owned, the teams that wear it, and the chest at the end of a
# run. Like the other screens, each is built here from the save and handed the things to call;
# one that changes the save builds itself again in the same place, so every part agrees with it.

const ROLES := ["Tank", "Healer", "Damage", "Damage"]
const NOTHING := "Nothing"


# Puts a screen built afresh where the old one was.
static func swap(old: Control, fresh: Control) -> void:
	var parent := old.get_parent()
	if parent == null:
		return
	var place := old.get_index()
	parent.remove_child(old)
	old.queue_free()
	parent.add_child(fresh)
	parent.move_child(fresh, place)


## An item's name in its rarity's colour. Hold the mouse over it to read what it does.
static func item_name(item: Dictionary, px := 14) -> Label:
	var l := Kit.label(item.name, px, Items.color(item))
	l.tooltip_text = "%s\n%s" % [Items.kind_words(item), Items.describe(item)]
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	return l


## "Gear level 11.5": what drops are measured against.
static func gear_level_words(save: SaveData) -> String:
	return "Gear level %s" % str(Items.gear_level(save.items)).trim_suffix(".0")


# How an item reads in a list to choose from: "12  Sexton's Hook (uncommon)".
static func _choice(item: Dictionary) -> String:
	return "%d  %s%s" % [item.ilvl, item.name, "" if item.slot == "trinket" or item.rarity == 0 else " (%s)" % Items.RARITIES[item.rarity].to_lower()]


# ---------- what is owned

## Everything owned, best first in each slot, with what it does and who wears it. An item can
## be thrown out, after being asked: `asking` is the item the question is about.
static func inventory(save: SaveData, on_change: Callable, on_back: Callable, asking := 0) -> Control:
	var root := Kit.screen(1.0)
	root.name = "Inventory"
	var col := Kit.vbox(10)
	Kit.panel_of(root).add_child(col)
	var head := Kit.hbox(18)
	head.add_child(Kit.label("Gear", 24, Kit.GOLD))
	var room := Kit.label("%d of %d    %s" % [save.items.size(), Items.SPACE, gear_level_words(save)], 14, Kit.GREY)
	room.name = "Room"
	room.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(room)
	col.add_child(head)
	col.add_child(Kit.para("A weapon raises damage and healing, armour raises health, and a trinket does one thing of its own. Gear belongs to you, not to a hero: any team may wear it. What a chest holds is a little better than the best weapon and armour you own, up to what its level allows.", 12, Kit.GREY, 1000.0))

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(1040, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.name = "Items"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	col.add_child(scroll)
	var going := Teams.in_use(save)
	for slot in Items.SLOTS:
		for item: Dictionary in Items.of_slot(save.items, slot):
			var named := item_name(item, 14)
			named.custom_minimum_size.x = 200
			grid.add_child(named)
			grid.add_child(Kit.label(Items.kind_words(item), 12, Kit.GREY))
			grid.add_child(Kit.para(Items.describe(item), 12, Kit.BONE, 360.0))
			var on := Teams.wearer(going, item.id)
			grid.add_child(Kit.label("on " + Heroes.by_id(going.party[on]).name if on >= 0 else "", 12, Kit.GREY))
			var used := Teams.using(save, item.id)
			var sure: bool = asking == item.id
			var out := Kit.button("Gone for good. Sure?" if sure else "Throw out", func() -> void:
				if sure:
					save.throw_out(item.id)
					on_change.call()
				swap(root, inventory(save, on_change, on_back, 0 if sure else item.id)), 12)
			out.name = "Out%d" % item.id
			if sure:
				out.add_theme_color_override("font_color", Kit.RED)
				if not used.is_empty():
					out.tooltip_text = "Worn in " + Kit.listed(used)
					out.text = "Worn in %s. Sure?" % Kit.listed(used)
			grid.add_child(out)
	if save.items.is_empty():
		col.add_child(Kit.label("Nothing yet. Finish a run and open its chest.", 14, Kit.BONE))
	var back := Kit.button("Back", on_back, 16)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(back)
	return root


# ---------- teams

## The teams: which one the next run goes in with, who is in it, which of them you play and
## what each wears. The default team wears the best of what is owned and looks after itself;
## a team of your own is dressed by hand.
static func team(save: SaveData, on_change: Callable, on_back: Callable) -> Control:
	var root := Kit.screen(1.0)
	root.name = "Team"
	var cols := Kit.hbox(28)
	Kit.panel_of(root).add_child(cols)
	var rebuild := func() -> void:
		on_change.call()
		swap(root, team(save, on_change, on_back))
	var mine := save.team > 0
	var now := Teams.in_use(save)

	# which team
	var list := Kit.vbox(8)
	list.name = "Teams"
	list.add_child(Kit.label("Teams", 20, Kit.GOLD))
	for place in save.teams.size() + 1:
		var t := Teams.at(save, place)
		var pick := Kit.button(t.name, func() -> void:
			save.team = place
			rebuild.call(), 14)
		pick.name = "Team%d" % place
		pick.custom_minimum_size.x = 200
		if place == save.team:
			pick.add_theme_color_override("font_color", Kit.GOLD)
		list.add_child(pick)
	var copy := Kit.button("Copy this team", func() -> void:
		var made := Teams.copy(save, now)
		if made > 0:
			save.team = made
		rebuild.call(), 13)
	copy.name = "Copy"
	copy.disabled = save.teams.size() >= Teams.MOST
	list.add_child(copy)
	if mine:
		var named := LineEdit.new()
		named.name = "Name"
		named.text = now.name
		named.max_length = 24
		named.custom_minimum_size.x = 200
		named.tooltip_text = "The name of this team"
		named.text_submitted.connect(func(text: String) -> void:
			now.name = text.strip_edges() if text.strip_edges() != "" else now.name
			rebuild.call())
		named.focus_exited.connect(func() -> void:
			if named.text.strip_edges() != "" and named.text.strip_edges() != now.name:
				now.name = named.text.strip_edges()
				on_change.call())
		list.add_child(named)
		var best := Kit.button("Wear the best", func() -> void:
			Teams.wear_best(save, now)
			rebuild.call(), 13)
		best.name = "Best"
		list.add_child(best)
		var forget := Kit.button("Forget this team", func() -> void:
			Teams.remove(save, save.team)
			rebuild.call(), 13)
		forget.name = "Forget"
		list.add_child(forget)
	list.add_child(Kit.para("The default team always wears the best you own: the best to the hero you play, then the tank, the healer and the other damage dealer. Copy it to dress a team by hand." if not mine
		else "A team of your own wears what you give it, and nothing changes unless you change it.", 12, Kit.GREY, 200.0))
	var back := Kit.button("Back", on_back, 16)
	back.name = "Back"
	list.add_child(back)
	cols.add_child(list)

	# who is in it, and what they wear
	var crew := Kit.vbox(6)
	crew.name = "Crew"
	crew.add_child(Kit.label(now.name, 20, Kit.GOLD))
	var choices := [Heroes.TANKS, Heroes.HEALERS, Heroes.DPS, Heroes.DPS]
	var worn := Teams.worn(save, now)
	for i in 4:
		var row := Kit.hbox(8)
		var role := Kit.label(ROLES[i], 12, Kit.GREY)
		role.custom_minimum_size.x = 56
		row.add_child(role)
		var pick := OptionButton.new()
		pick.name = "Pick%d" % i
		pick.custom_minimum_size.x = 170
		for id: String in choices[i]:
			pick.add_item(Heroes.by_id(id).name)
		pick.select(choices[i].find(now.party[i]))
		pick.item_selected.connect(func(at: int) -> void:
			if mine:
				now.party[i] = choices[i][at]
			else:
				save.party[i] = choices[i][at]
			rebuild.call())
		row.add_child(pick)
		var you := Kit.button("You" if now.slot == i else "Play", func() -> void:
			if mine:
				now.slot = i
			else:
				save.slot = i
			rebuild.call(), 12)
		you.name = "You%d" % i
		you.custom_minimum_size.x = 56
		if now.slot == i:
			you.add_theme_color_override("font_color", Kit.GOLD)
		row.add_child(you)
		var sums: Array[String] = []
		if Items.bonus(worn[i].weapon) > 0.0:
			sums.append(Items.describe(worn[i].weapon))
		if Items.bonus(worn[i].armour) > 0.0:
			sums.append(Items.describe(worn[i].armour))
		var sum := Kit.label(", ".join(sums), 12, Kit.GREY)
		sum.name = "Sum%d" % i
		row.add_child(sum)
		crew.add_child(row)

		var wears := Kit.hbox(8)
		var pad := Control.new()
		pad.custom_minimum_size.x = 56
		wears.add_child(pad)
		for slot in Items.SLOTS:
			var have := Items.of_slot(save.items, slot)
			var box := OptionButton.new()
			box.name = "%s%d" % [Items.SLOT_NAMES[slot], i]
			box.custom_minimum_size.x = 215
			box.clip_text = true
			box.fit_to_longest_item = false
			box.add_item("%s: %s" % [Items.SLOT_NAMES[slot], NOTHING.to_lower()])
			var chosen := 0
			for k in have.size():
				var other := Teams.wearer(now, have[k].id)
				box.add_item(_choice(have[k]) + ("" if other < 0 or other == i else "  · on " + Heroes.by_id(now.party[other]).name.split(" ")[0]))
				if have[k].id == now.gear[i][slot]:
					chosen = k + 1
			box.select(chosen)
			var on: Dictionary = worn[i][slot]
			box.tooltip_text = "%s\n%s" % [Items.kind_words(on), Items.describe(on)] if not on.is_empty() else ""
			if not on.is_empty():
				box.add_theme_color_override("font_color", Items.color(on))
			# the default team dresses itself
			box.disabled = not mine
			box.add_theme_color_override("font_disabled_color", Color(Items.color(on), 0.75) if not on.is_empty() else Color(Kit.BONE, 0.35))
			box.item_selected.connect(func(at: int) -> void:
				Teams.equip(save, now, i, slot, have[at - 1].id if at > 0 else 0)
				rebuild.call())
			wears.add_child(box)
		crew.add_child(wears)
	var trinket: Dictionary = worn[now.slot].trinket
	if not trinket.is_empty():
		crew.add_child(Kit.para("%s: %s" % [trinket.name, Items.describe(trinket)], 12, Kit.BONE, 700.0))
	crew.add_child(Kit.para("The AI plays the other three, and uses what it wears by itself. Any hero may be in the crew twice. Gear cannot be changed once a run has begun.", 12, Kit.GREY, 700.0))
	cols.add_child(crew)

	# the hero you play: how to play it and what it does
	var def := Heroes.by_id(now.party[now.slot])
	var hero := Kit.vbox(6)
	hero.name = "Hero"
	hero.add_child(Kit.label("%s, %s" % [def.name, def.title], 20, def.color))
	hero.add_child(Kit.label(def.sub, 12, Kit.GREY))
	hero.add_child(Kit.para(def.how_to, 13, Kit.BONE, 320.0))
	for ab in def.abilities:
		hero.add_child(Kit.para("%s: %s" % [ab.name, ab.desc], 12, Kit.GREY, 320.0))
	cols.add_child(hero)
	return root


# ---------- the chest

## The chest at the end of a run. `found` is a list of {"item", "state"}: the state is ""
## until the item is taken ("taken") or left ("left"). Whatever has not been taken when the
## screen is left stays behind. `on_change` is called when the save has changed; `go` holds
## where to go next: "again", "next" (missing if there is no next level to go to), "setup" and
## "gear".
static func chest(found: Array, save: SaveData, on_change: Callable, go: Dictionary, level := 1) -> Control:
	var root := Kit.screen(0.55)
	root.name = "Chest"
	var col := Kit.vbox(12)
	Kit.panel_of(root).add_child(col)
	var again := func() -> void: swap(root, chest(found, save, on_change, go, level))
	var take := func(entry: Dictionary) -> void:
		if entry.state != "taken" and save.take(entry.item):
			entry.state = "taken"
	col.add_child(Kit.label("The chest", 26, Kit.GOLD))
	var room := Kit.label("%s    %d of %d carried" % [gear_level_words(save), save.items.size(), Items.SPACE], 13, Kit.GREY)
	room.name = "Room"
	col.add_child(room)
	var row := Kit.hbox(18)
	for i in found.size():
		var entry: Dictionary = found[i]
		var item: Dictionary = entry.item
		var card := Kit.vbox(6)
		card.name = "Item%d" % i
		card.custom_minimum_size.x = 270
		card.add_child(item_name(item, 18))
		card.add_child(Kit.label(Items.kind_words(item), 12, Kit.GREY))
		card.add_child(Kit.para(Items.describe(item), 13, Kit.BONE, 270.0))
		if item.slot != "trinket":
			var mine := Items.of_slot(save.items.filter(func(o: Dictionary) -> bool: return o.id != item.id or entry.state != "taken"), item.slot)
			card.add_child(Kit.label("Your best is item level %d" % mine[0].ilvl if not mine.is_empty() else "Your first", 12, Kit.GREY))
		var buttons := Kit.hbox(8)
		if entry.state == "taken":
			buttons.add_child(Kit.label("Taken", 14, Kit.GREEN))
		else:
			var yes := Kit.button("Take", func() -> void:
				take.call(entry)
				on_change.call()
				again.call(), 14)
			yes.name = "Take%d" % i
			yes.disabled = not save.has_room()
			buttons.add_child(yes)
			if entry.state == "left":
				buttons.add_child(Kit.label("Left", 14, Kit.GREY))
			else:
				var no := Kit.button("Leave", func() -> void:
					entry.state = "left"
					again.call(), 14)
				no.name = "Leave%d" % i
				buttons.add_child(no)
		card.add_child(buttons)
		row.add_child(card)
	col.add_child(row)
	var open := found.filter(func(e: Dictionary) -> bool: return e.state != "taken")
	if not save.has_room() and not open.is_empty():
		col.add_child(Kit.label("You can carry no more. Throw something out in Gear to make room.", 13, Kit.RED))
	elif not open.is_empty():
		col.add_child(Kit.label("What you do not take stays behind.", 13, Kit.GREY))
	var foot := Kit.hbox(10)
	if open.any(func(e: Dictionary) -> bool: return e.state == ""):
		var all := Kit.button("Take all", func() -> void:
			for e: Dictionary in found:
				if e.state == "":
					take.call(e)
			on_change.call()
			again.call(), 16)
		all.name = "TakeAll"
		all.disabled = not save.has_room()
		foot.add_child(all)
	var run := Kit.button("Run it again", go.again, 16)
	run.name = "Again"
	foot.add_child(run)
	if go.has("next"):
		var next := Kit.button("On to level %d" % (level + 1), go.next, 16)
		next.name = "Next"
		foot.add_child(next)
	var gear := Kit.button("Gear", go.gear, 13)
	gear.name = "Gear"
	foot.add_child(gear)
	var back := Kit.button("Back to the start", go.setup, 13)
	back.name = "Setup"
	foot.add_child(back)
	col.add_child(foot)
	return root
