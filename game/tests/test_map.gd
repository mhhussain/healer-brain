extends GutTest

# Milestone 10: the route planner, the app round it, and the plan shown during a run.

const TEMP_SAVE := "user://test-map-save.json"
const PARTY: Array[String] = ["warden", "mender", "duelist", "ranger"]

var abbey: LevelDef
var save: SaveData
var map: RouteMap
var changes := 0
var _saved_keys: SaveData


func before_all():
	SaveStore.path = TEMP_SAVE
	_saved_keys = Run.keys


func after_all():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	SaveStore.path = "user://fourfold-save.json"
	Run.keys = _saved_keys
	Run.route = null
	Run.place = "abbey"
	Run.party.assign(PARTY)
	Run.player_slot = 3
	Run.chosen_level = 1
	Run.autoplay = false
	Run.rng_seed = 0
	get_tree().paused = false


func before_each():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	Run.keys = SaveData.new()
	Run.route = null
	Run.autoplay = false
	Run.place = "abbey"
	get_tree().paused = false
	abbey = Levels.abbey()
	save = SaveData.new()
	changes = 0


## The planner on the Abbey, on a screen of the game's own size.
func planner(over: Combat = null) -> RouteMap:
	var holder := Control.new()
	holder.size = Vector2(1440, 810)
	add_child_autofree(holder)
	map = RouteMap.new()
	map.open(abbey, save, PARTY, over)
	map.changed.connect(func() -> void: changes += 1)
	holder.add_child(map)
	return map


func mouse(at: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT, shift := false) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = at
	e.global_position = at
	e.shift_pressed = shift
	return e


func click_pack(pack: int, shift := false) -> void:
	var at := map.view.to_screen(abbey.packs[pack].center)
	map.view._gui_input(mouse(at, true, MOUSE_BUTTON_LEFT, shift))
	map.view._gui_input(mouse(at, false, MOUSE_BUTTON_LEFT, shift))


func drag_marker(place: int, to: Vector2) -> void:
	var from := map.view._marker_at(place)
	map.view._gui_input(mouse(from, true))
	var move := InputEventMouseMotion.new()
	move.position = to
	move.relative = to - from
	map.view._gui_input(move)
	map.view._gui_input(mouse(to, false))


func packs() -> Array:
	return map.route.pulls.map(func(p: Dictionary) -> Array: return p.packs)


func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


# ---------- the planner

func test_the_planner_opens_on_the_safe_way_with_the_whole_dungeon_in_view():
	planner()
	await wait_frames(2)
	assert_eq(packs(), [[0], [1], [2], [3], [4], [5], [6], [7], [8]])
	assert_eq(map.find_child("Pulls", true, false).get_child(0).get_child_count(), 9, "a row for each pull")
	assert_eq(map.warnings(), "")
	assert_false(map.find_child("Warnings", true, false).visible)
	var view := map.view
	assert_gt(view.size.x, 900.0, "the map has the left of the screen")
	assert_gt(map.find_child("Side", true, false).global_position.x, view.size.x - 5.0, "the list is on the right")
	var all := view.bounds()
	for corner: Vector2 in [all.position, all.end]:
		assert_true(Rect2(Vector2.ZERO, view.size).has_point(view.to_screen(Vector3(corner.x, 0, corner.y))), "all of it is in view")
	assert_eq(changes, 0, "looking changes nothing")
	assert_eq(save.routes, {})


func test_a_click_on_a_pack_puts_it_in_the_pull_being_edited_and_again_takes_it_out():
	planner()
	await wait_frames(2)
	assert_eq(map.view.pack_at(map.view.to_screen(abbey.packs[1].center)), 1)
	assert_eq(map.view.pack_at(map.view.to_screen(abbey.doors[1].pos)), -1, "a doorway is nobody's ground")
	click_pack(1)
	assert_eq(packs()[0], [0, 1], "the Wet Stair joins the first pull")
	assert_eq(packs()[1], [2], "and its own pull, left empty, is gone")
	assert_eq(packs().size(), 8)
	click_pack(1)
	assert_eq(packs()[0], [0])
	assert_string_contains(map.warnings(), "14 short of the count")
	click_pack(2)
	assert_string_contains(map.warnings(), "14 short")
	click_pack(2)
	assert_string_contains(map.warnings(), "never pulls Brother Krogg")
	assert_true(map.find_child("Warnings", true, false).visible)
	assert_eq(save.route_for(abbey).to_dict(), map.route.to_dict(), "every change is kept")
	assert_eq(changes, 4)


func test_shift_click_and_the_button_start_a_new_pull():
	planner()
	await wait_frames(2)
	map.select(2)
	click_pack(7, true)
	assert_eq(map.current, 3, "the new pull comes after the one being edited")
	assert_eq(packs()[3], [7])
	assert_eq(packs().size(), 9, "one more for the new pull, one fewer for the pull it left empty")
	(map.find_child("AddPull", true, false) as Button).pressed.emit()
	assert_eq(map.current, 4)
	assert_eq(packs()[4], [])
	click_pack(6)
	assert_eq(packs()[4], [6])
	map.finish()
	assert_eq(packs(), [[0], [1], [2], [7], [6], [3], [4], [5], [8]])
	(map.find_child("AddPull", true, false) as Button).pressed.emit()
	assert_eq(packs().size(), 10)
	map.finish()
	assert_eq(packs().size(), 9, "closing drops a pull nothing was put in")


func test_rows_are_chosen_moved_joined_inserted_and_deleted():
	planner()
	await wait_frames(2)
	var rows: Control = map.find_child("Pulls", true, false).get_child(0)
	var third: Control = rows.get_child(2)
	third._gui_input(mouse(third.global_position + Vector2(20, 10), true))
	third._gui_input(mouse(third.global_position + Vector2(20, 10), false))
	assert_eq(map.current, 2, "a click on a row edits that pull")
	assert_eq(map.view.current, 2)
	# drag the third row to above the first; the rows were made afresh when one was chosen
	await wait_frames(2)
	third = rows.get_child(2)
	var first: Control = rows.get_child(0)
	third._gui_input(mouse(third.global_position + Vector2(20, 10), true))
	var move := InputEventMouseMotion.new()
	move.global_position = first.global_position + Vector2(20, 2)
	third._gui_input(move)
	third._gui_input(mouse(first.global_position + Vector2(20, 2), false))
	assert_eq(packs().slice(0, 3), [[2], [0], [1]])
	assert_eq(map.current, 0, "and it is still the one being edited")
	map.move_row(0, 3)
	assert_eq(packs().slice(0, 3), [[0], [1], [2]], "dropped in the gap below the third row")
	map._menu_for = 1
	map._on_menu(1)
	assert_eq(packs().slice(0, 2), [[0, 1], [2]], "joined to the pull above")
	map._menu_for = 1
	map._on_menu(0)
	assert_eq(packs().slice(0, 3), [[0, 1], [], [2]], "an empty pull inserted above")
	assert_eq(map.current, 1)
	map._menu_for = 1
	map._on_menu(2)
	assert_eq(packs().slice(0, 2), [[0, 1], [2]], "and deleted")
	map._menu_for = 0
	map._on_menu(1)
	assert_eq(packs().slice(0, 2), [[0, 1], [2]], "the first has none above to join")


func test_markers_are_dragged_onto_the_map_and_back_off_it():
	planner()
	await wait_frames(2)
	map.select(1)
	var view := map.view
	var spot: Vector3 = abbey.packs[1].stand + Vector3(3, 0, 2)
	drag_marker(0, view.to_screen(spot))
	var kept: Vector3 = map.route.pulls[1].spots[0]
	assert_lt(Combat.flat(kept, spot), 0.5, "the tank's spot for the second pull")
	assert_false(map.route.pulls[0].spots.has(0), "and for no other")
	drag_marker(3, view.to_screen(abbey.doors[1].pos))
	assert_true(map.route.pulls[1].spots.has(3))
	assert_eq(save.route_for(abbey).pulls[1].spots.size(), 2)
	# dropped on a wall it goes back to the tray
	drag_marker(0, view.to_screen(Vector3(abbey.doors[1].pos.x, 0, -4)))
	assert_false(map.route.pulls[1].spots.has(0))
	view._gui_input(mouse(view._marker_at(3), true, MOUSE_BUTTON_RIGHT))
	assert_false(map.route.pulls[1].spots.has(3), "and so does one that is right-clicked")


func test_a_pull_can_be_told_to_go_at_once_and_given_a_note():
	planner()
	await wait_frames(2)
	map.select(3)
	(map.find_child("Go", true, false) as CheckBox).button_pressed = true
	(map.find_child("Note", true, false) as LineEdit).text_changed.emit("behind the pillar")
	assert_true(map.route.pulls[3].go)
	assert_eq(map.route.pulls[3].note, "behind the pillar")
	map.select(0)
	assert_false((map.find_child("Go", true, false) as CheckBox).button_pressed, "each pull has its own")
	assert_eq((map.find_child("Note", true, false) as LineEdit).text, "")
	assert_true(save.route_for(abbey).pulls[3].go)


func test_three_routes_are_kept_and_the_safe_way_can_be_had_back():
	planner()
	await wait_frames(2)
	click_pack(1)
	(map.find_child("RouteName", true, false) as LineEdit).text_changed.emit("Doubles")
	(map.find_child("Slot1", true, false) as Button).pressed.emit()
	assert_eq(save.route_slot(abbey), 1)
	assert_eq(packs().size(), 9, "the second slot starts as the safe way")
	click_pack(4)
	map.select(1)
	(map.find_child("Slot0", true, false) as Button).pressed.emit()
	assert_eq(packs()[0], [0, 1], "the first is as it was left")
	assert_eq(map.route.name, "Doubles")
	assert_eq(map.current, 0)
	assert_eq(save.route_in(abbey, 1).pulls[0].packs, [0, 4])
	assert_null(save.route_in(abbey, 2))
	(map.find_child("Reset", true, false) as Button).pressed.emit()
	assert_eq(packs(), [[0], [1], [2], [3], [4], [5], [6], [7], [8]])
	assert_null(save.route_in(abbey, 0), "the slot is empty again")
	assert_eq(save.route_in(abbey, 1).pulls[0].packs, [0, 4], "the other is untouched")


func test_a_route_is_copied_out_as_a_code_and_loaded_from_one():
	planner()
	await wait_frames(2)
	click_pack(1)
	(map.find_child("CopyCode", true, false) as Button).pressed.emit()
	var code := (map.find_child("Code", true, false) as LineEdit).text
	assert_true(code.begins_with("FF1:"))
	(map.find_child("Reset", true, false) as Button).pressed.emit()
	assert_eq(packs()[0], [0])
	(map.find_child("Code", true, false) as LineEdit).text = "nonsense"
	(map.find_child("LoadCode", true, false) as Button).pressed.emit()
	assert_eq(packs()[0], [0])
	assert_string_contains((map.find_child("Said", true, false) as Label).text, "not a route for The Drowned Abbey")
	(map.find_child("Code", true, false) as LineEdit).text = code
	(map.find_child("LoadCode", true, false) as Button).pressed.emit()
	assert_eq(packs()[0], [0, 1])
	assert_eq(save.route_for(abbey).pulls[0].packs, [0, 1])


func test_a_pull_is_drawn_as_one_outline_round_all_its_packs():
	planner()
	await wait_frames(2)
	var view := map.view
	var first := view.to_screen(abbey.packs[0].center)
	var second := view.to_screen(abbey.packs[1].center)
	var between := view.to_screen(abbey.doors[1].pos)
	assert_true(Geometry2D.is_point_in_polygon(first, view.pull_outline(0)))
	assert_false(Geometry2D.is_point_in_polygon(second, view.pull_outline(0)), "one pack, one shape")
	click_pack(1)
	var both := view.pull_outline(0)
	assert_true(Geometry2D.is_point_in_polygon(first, both))
	assert_true(Geometry2D.is_point_in_polygon(second, both), "two packs in a pull are inside one shape")
	assert_true(Geometry2D.is_point_in_polygon(between, both), "which runs across the wall between them")
	for post in LevelDef.posts(abbey.packs[1]):
		assert_true(Geometry2D.is_point_in_polygon(view.to_screen(post), both), "with every enemy inside it")
	assert_false(Geometry2D.is_point_in_polygon(view.to_screen(abbey.packs[2].center), both))
	(map.find_child("AddPull", true, false) as Button).pressed.emit()
	assert_eq(view.pull_outline(map.current).size(), 0, "an empty pull has no shape")


func test_resting_on_a_pack_or_a_row_lists_its_enemies_and_what_they_do():
	save.level = 2
	planner()
	await wait_frames(2)
	var details: Control = map.find_child("Details", true, false)
	assert_false(details.visible)
	var words := func() -> String:
		return "\n".join(details.get_child(0).get_children().map(func(l: Label) -> String: return l.text))
	var move := InputEventMouseMotion.new()
	move.position = map.view.to_screen(abbey.packs[3].center)
	map.view._gui_input(move)
	assert_true(details.visible)
	assert_string_contains(words.call(), "The Undercroft    count 14    pull 4")
	assert_string_contains(words.call(), "2× Drowned Porter    2484 health    count 4", "health at the level chosen")
	assert_string_contains(words.call(), "Sour Note: A bolt at a random hero. It can be silenced.")
	assert_string_contains(words.call(), "Withering Verse (from level 3)")
	move.position = map.view.to_screen(abbey.doors[3].pos)
	map.view._gui_input(move)
	assert_false(details.visible, "off the pack it goes away")
	click_pack(1)
	map.route.pulls[0].note = "behind the wall"
	await wait_frames(2)
	var row: Control = map.find_child("Pulls", true, false).get_child(0).get_child(0)
	row.mouse_entered.emit()
	assert_true(details.visible)
	assert_string_contains(words.call(), "Pull 1    count 29")
	assert_string_contains(words.call(), "\"behind the wall\"")
	assert_string_contains(words.call(), "5× Drowned Porter")
	assert_string_contains(words.call(), "Alms: Heals the most hurt enemy")
	assert_lt(details.get_global_rect().end.x, row.global_position.x, "to the left of the list, not over it")
	row.mouse_exited.emit()
	assert_false(details.visible)


func test_the_wheel_zooms_about_the_pointer_and_never_out_past_the_whole_map():
	planner()
	await wait_frames(2)
	var view := map.view
	var whole := view.zoom
	var at := view.to_screen(abbey.packs[4].center)
	var under := view.to_level(at)
	for i in 6:
		view._gui_input(mouse(at, true, MOUSE_BUTTON_WHEEL_UP))
	assert_gt(view.zoom, whole * 2.0)
	assert_lt(Combat.flat(view.to_level(at), under), 0.01, "what was under the pointer still is")
	assert_eq(view.pack_at(at), 4)
	for i in 30:
		view._gui_input(mouse(at, true, MOUSE_BUTTON_WHEEL_DOWN))
	assert_almost_eq(view.zoom, whole, 0.001)


# ---------- the app round it

func test_the_route_is_planned_from_the_setup_screen_and_the_run_follows_it():
	var app: App = load("res://scenes/app.tscn").instantiate()
	add_child_autofree(app)
	app.show_setup()
	assert_string_contains((app.screen.find_child("RouteName", true, false) as Label).text, "9 pulls")
	(app.screen.find_child("Plan", true, false) as Button).pressed.emit()
	assert_eq(app.state, "route")
	map = app.screen as RouteMap
	abbey = map.def
	await wait_frames(2)
	click_pack(1)
	(map.find_child("Done", true, false) as Button).pressed.emit()
	assert_eq(app.state, "setup")
	assert_string_contains((app.screen.find_child("RouteName", true, false) as Label).text, "8 pulls")
	assert_eq(SaveStore.load_save().route_for(abbey).pulls[0].packs, [0, 1], "it is in the file")
	(app.screen.find_child("Plan", true, false) as Button).pressed.emit()
	app._unhandled_input(key(KEY_ESCAPE))
	assert_eq(app.state, "setup", "Esc closes the planner too")
	await app.start_run()
	var c := app.run.combat
	assert_eq(c.next_pull().packs.map(func(p: Pack) -> int: return p.id), [0, 1], "the run has the plan")
	assert_eq(Hud.pull_words(c), "    Next: pull 1")


func test_m_opens_the_map_over_a_run_and_what_is_changed_there_changes_the_run():
	var app: App = load("res://scenes/app.tscn").instantiate()
	add_child_autofree(app)
	await app.start_run()
	var c := app.run.combat
	c.ai_plays = false
	app._unhandled_input(key(KEY_M))
	assert_eq(app.state, "map")
	assert_true(get_tree().paused, "the run stands still while the map is open")
	map = app.screen as RouteMap
	abbey = map.def
	await wait_frames(2)
	assert_eq(map.route, c.route, "it is the run's own plan")
	click_pack(1)
	assert_eq(c.next_pull().packs.map(func(p: Pack) -> int: return p.id), [0, 1])
	app._unhandled_input(key(KEY_M))
	assert_eq(app.state, "run", "M closes it again")
	assert_false(get_tree().paused)
	assert_eq(c.route.pulls.size(), 8, "with the emptied pull dropped")
	assert_eq(SaveStore.load_save().route_for(abbey).pulls[0].packs, [0, 1], "and the change is kept for next time")

	c.engage(c.packs[0], app.run.player.c)
	app._unhandled_input(key(KEY_M))
	assert_eq(app.state, "run", "not in a fight")
	assert_false(get_tree().paused)


func test_over_a_run_what_is_dead_is_done_and_cannot_be_moved():
	var app: App = load("res://scenes/app.tscn").instantiate()
	add_child_autofree(app)
	await app.start_run()
	var c := app.run.combat
	c.ai_plays = false
	for e in c.packs[0].units:
		c.damage(app.run.player.c, e, 9999999.0)
	await wait_physics_frames(3)
	assert_true(c.packs[0].cleared)
	app.open_map()
	map = app.screen as RouteMap
	abbey = map.def
	await wait_frames(2)
	assert_eq(map.current, 1, "it opens on the pull that comes next")
	assert_true(map.is_done(0))
	assert_false(map.is_done(1))
	click_pack(0)
	assert_eq(packs()[0], [0], "a pack at rest stays where it is")
	assert_string_contains((map.find_child("Said", true, false) as Label).text, "already at rest")
	map._menu_for = 1
	map._on_menu(1)
	assert_eq(packs()[1], [1], "and a pull that is done takes no more")
	click_pack(2)
	assert_eq(packs()[1], [1, 2])
	app.close_map()
	assert_eq(c.next_pull().packs.map(func(p: Pack) -> int: return p.id), [1, 2])


# ---------- the plan during a run

func test_the_next_pulls_spots_are_marked_on_the_ground_unless_turned_off():
	var route := Route.default_for(abbey)
	route.set_spot(0, 0, abbey.packs[0].stand + Vector3(4, 0, 0))
	route.set_spot(0, 3, abbey.doors[0].pos)
	route.set_spot(1, 3, abbey.doors[1].pos)
	Run.route = route
	Run.party.assign(PARTY)
	Run.player_slot = 3
	var run: Run = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(run)
	run.combat.ai_plays = false
	await wait_frames(2)
	assert_eq(run.tank_spot(), abbey.packs[0].stand + Vector3(4, 0, 0))
	assert_eq(run.own_spot(), abbey.doors[0].pos)
	assert_true(run._tank_mark.visible)
	assert_almost_eq(run._own_mark.global_position.x, abbey.doors[0].pos.x, 0.01)
	assert_eq(Hud.pull_words(run.combat), "    Next: pull 1")
	run.combat.engage(run.combat.packs[0], run.player.c)
	assert_eq(Hud.pull_words(run.combat), "    Pull 1")
	assert_eq(run.own_spot(), abbey.doors[0].pos, "the pull being fought is the one marked")
	for e in run.combat.packs[0].units:
		run.combat.damage(run.player.c, e, 9999999.0)
	await wait_physics_frames(2)
	await wait_frames(2)
	assert_null(run.tank_spot(), "nothing planned for the tank in the second pull")
	assert_false(run._tank_mark.visible)
	assert_eq(run.own_spot(), abbey.doors[1].pos)
	Run.keys.markers = false
	await wait_frames(2)
	assert_null(run.own_spot())
	assert_false(run._own_mark.visible)
	assert_eq(Run.route.pulls.size(), 9)


func test_a_tank_has_no_spot_of_its_own_beside_the_tanks():
	var route := Route.default_for(abbey)
	route.set_spot(0, 0, abbey.packs[0].stand)
	Run.route = route
	Run.party.assign(PARTY)
	Run.player_slot = 0
	var run: Run = load("res://scenes/run.tscn").instantiate()
	add_child_autofree(run)
	run.combat.ai_plays = false
	await wait_frames(2)
	assert_eq(run.tank_spot(), abbey.packs[0].stand, "when you tank, the ring is where the plan would have you hold")
	assert_null(run.own_spot())
