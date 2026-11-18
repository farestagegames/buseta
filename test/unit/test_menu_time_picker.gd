extends GutTest
## The mañana / tarde / noche card on the Home stage.


func _times() -> Array[TimeOfDay]:
	var times: Array[TimeOfDay] = []
	for entry: Array in [["manana", 1], ["atardecer", 2], ["noche", 4], ["mediodia", 1]]:
		var time := TimeOfDay.new()
		time.id = entry[0]
		time.name = entry[0]
		time.level = entry[1]
		times.append(time)
	return times


func _picker(chosen_id: String, level: int) -> MenuTimePicker:
	var picker := MenuTimePicker.new()
	add_child_autofree(picker)
	picker.setup(_times(), chosen_id, level)
	return picker


func test_three_times_with_locked_ones_showing_their_level() -> void:
	var picker := _picker("manana", 2)
	assert_eq(picker.buttons.size(), 3, "midday is left to the Routes page")
	var night: Button = picker.buttons["noche"]
	assert_true(night.disabled)
	assert_string_contains(night.text, "4")
	assert_true((picker.buttons["manana"] as Button).button_pressed)
	assert_false((picker.buttons["atardecer"] as Button).disabled)


func test_picking_a_time_rings_it_and_says_so() -> void:
	var picker := _picker("manana", 2)
	watch_signals(picker)
	var sunset: Button = picker.buttons["atardecer"]
	sunset.button_pressed = true
	sunset.pressed.emit()
	assert_signal_emitted(picker, "chosen")
	var time: TimeOfDay = get_signal_parameters(picker, "chosen")[0]
	assert_eq(time.id, "atardecer")
	assert_false((picker.buttons["manana"] as Button).button_pressed)
	assert_true(sunset.button_pressed)


func test_a_time_not_on_the_card_rings_none() -> void:
	var picker := _picker("mediodia", 4)
	for id: String in picker.buttons:
		assert_false((picker.buttons[id] as Button).button_pressed, id)
	picker.select("noche")
	assert_true((picker.buttons["noche"] as Button).button_pressed)
