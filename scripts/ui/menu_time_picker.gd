class_name MenuTimePicker
extends PanelContainer
## A small white card on the Home stage: morning, sunset and night. Picking one
## saves it for the next shift and relights the stage, so the player sees how the
## drive will look. Times the driver has not reached show their level.

signal chosen(time: TimeOfDay)

const IDS: Array[String] = ["manana", "atardecer", "noche"]
const LABELS: Array[String] = ["Morning", "Sunset", "Night"]
const BUTTON_SIZE := Vector2(96.0, 64.0)

var buttons: Dictionary = {} ## Time id to its Button.


func setup(times: Array[TimeOfDay], chosen_id: String, driver_level: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	buttons.clear()
	add_theme_stylebox_override("panel", MenuHomeDrawer.card_box())
	theme = MenuCartoon.theme()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", MenuHomeDrawer.GAP)
	add_child(row)
	for i in IDS.size():
		var id: String = IDS[i]
		var time := TimeOfDay.find(times, id)
		if time == null:
			continue
		var button := Button.new()
		button.name = "Time_" + id
		button.custom_minimum_size = BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 18)
		button.toggle_mode = true
		button.button_pressed = id == chosen_id
		if time.is_unlocked(driver_level):
			button.text = tr(LABELS[i])
			button.pressed.connect(_on_pressed.bind(id, time))
		else:
			button.text = "%s\n%s" % [tr(LABELS[i]), tr("Level %d") % time.level]
			button.disabled = true
		buttons[id] = button
		row.add_child(button)


## Rings the one chosen; none when the shift runs at a time not on the card.
func select(id: String) -> void:
	for key: String in buttons:
		(buttons[key] as Button).set_pressed_no_signal(key == id)


func _on_pressed(id: String, time: TimeOfDay) -> void:
	select(id)
	chosen.emit(time)
