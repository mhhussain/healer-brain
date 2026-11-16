class_name GearButton
extends Control

# One of the three small gear buttons beside the action bar: the slot's key, the item's name
# and its cooldown draining down it. A slot with nothing to press shows no button at all.
# Click it to use it; hold the mouse over it to read what it does.

signal used(slot: int)
signal hovered(slot: int, on: bool)

## 0 the weapon, 1 the armour, 2 the trinket.
var slot := 2
var run: Run


func _ready() -> void:
	custom_minimum_size = Vector2(70, 50)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: hovered.emit(slot, true))
	mouse_exited.connect(func() -> void: hovered.emit(slot, false))


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		used.emit(slot)
		accept_event()


## What the button has to show, or empty.
func state() -> Dictionary:
	if run == null or run.combat == null or run.combat.player == null:
		return {}
	return run.combat.gear_state(run.combat.player, slot)


func _process(_delta: float) -> void:
	visible = not state().is_empty()
	queue_redraw()


func _draw() -> void:
	var st := state()
	if st.is_empty():
		return
	var r := Rect2(Vector2.ZERO, size)
	var ready: bool = st.usable and st.cd <= 0.0
	draw_rect(r, Kit.DARK)
	draw_rect(r, Items.color(st.item) if ready else Color(Items.color(st.item), 0.4), false, 2.0)
	Kit.wrapped(self, Vector2(3, 30), st.item.name, 10, Kit.BONE if ready else Color(Kit.BONE, 0.45), size.x - 6)
	Kit.text(self, Vector2(5, 14), Bindings.key_name(Run.keys.gear_keys[slot]), 12, Kit.GOLD, size.x - 10, HORIZONTAL_ALIGNMENT_LEFT)
	if st.cd > 0.0:
		var left: float = clampf(st.cd / st.cd_max, 0.0, 1.0)
		draw_rect(Rect2(0, size.y * (1.0 - left), size.x, size.y * left), Color(0, 0, 0, 0.6))
		Kit.text(self, Vector2(size.x / 2, size.y - 5), "%d" % ceili(st.cd), 13, Color.WHITE)
