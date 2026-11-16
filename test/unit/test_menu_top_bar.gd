extends GutTest
## Unit tests for the menu's top bar, its route chip and the pulsing shift
## button: texts, signals, touch targets and the short driver name.

var top_bar: MenuTopBar
var _driver_taps: int = 0


func before_each() -> void:
	top_bar = MenuTopBar.new()
	add_child_autofree(top_bar)
	top_bar.size = Vector2(1280.0, 80.0)
	_driver_taps = 0


func test_refresh_sets_texts_and_the_xp_bar() -> void:
	var look := DriverLook.new()
	top_bar.refresh(7, 0.42, "$552.400", "Wilmer Pertuz", look)
	assert_eq(top_bar.level_label.text, "LEVEL 7")
	assert_almost_eq(top_bar.level_bar.value, 0.42, 0.001)
	assert_almost_eq(top_bar.level_bar.max_value, 1.0, 0.001)
	assert_eq(top_bar.coins_label.text, "$552.400")
	var number := top_bar.find_child("LevelNumber", true, false) as Label
	assert_not_null(number, "The yellow badge shows the level number")
	assert_eq(number.text, "7")
	var short := top_bar.find_child("DriverName", true, false) as Label
	assert_not_null(short, "The driver pill shows a short name")
	assert_eq(short.text, "Wilmer P.")
	var badge := top_bar.find_child("DriverBadge", true, false) as DriverBadge
	assert_not_null(badge, "The driver pill holds a portrait")
	assert_eq(badge.look, look)


func test_refresh_clamps_progress_and_takes_a_missing_look() -> void:
	top_bar.refresh(1, 1.5, "", "", null)
	assert_eq(top_bar.level_bar.value, 1.0)
	assert_eq(top_bar.coins_label.text, "")


func test_title_is_the_game_name() -> void:
	assert_eq(top_bar.title_label.name, &"TitleLabel")
	assert_eq(top_bar.title_label.text, str(ProjectSettings.get_setting("application/config/name")))
	assert_eq(top_bar.title_label.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED)
	assert_eq(top_bar.title_label.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_icon_buttons_emit_their_names() -> void:
	var fired: Array[String] = []
	top_bar.icon_pressed.connect(func(icon_name: String) -> void: fired.append(icon_name))
	var cases := [
		["HornButton", "horn"],
		["GearButton", "gear"],
		["CameraButton", "camera"],
		["SoundButton", "sound"],
		["FullscreenButton", "fullscreen"],
	]
	for pair: Array in cases:
		var button := top_bar.find_child(str(pair[0]), true, false) as Button
		assert_not_null(button, "%s exists" % pair[0])
		button.pressed.emit()
	assert_eq(fired, ["horn", "gear", "camera", "sound", "fullscreen"])


func test_driver_pill_emits_driver_pressed() -> void:
	top_bar.driver_pressed.connect(_on_driver_pressed)
	top_bar.driver_button.pressed.emit()
	assert_eq(_driver_taps, 1, "The pill opens the drivers tab")


func test_sound_icon_follows_the_mute() -> void:
	var sound := top_bar.find_child("SoundGlyph", true, false) as MenuIcon
	assert_not_null(sound, "The sound button holds an icon")
	top_bar.set_muted(true)
	assert_eq(sound.icon, "sound_off")
	top_bar.set_muted(false)
	assert_eq(sound.icon, "sound")


func test_every_visible_button_is_at_least_48_square() -> void:
	await wait_frames(2)
	var buttons := top_bar.find_children("*Button", "Button", true, false)
	assert_gte(buttons.size(), 6, "The driver pill and the five icon buttons")
	for node: Node in buttons:
		var button := node as Button
		if not button.visible:
			continue
		assert_gte(button.size.x, 48.0, "%s is too narrow" % button.name)
		assert_gte(button.size.y, 48.0, "%s is too short" % button.name)


func test_short_name_keeps_one_word_and_cuts_the_surname() -> void:
	assert_eq(MenuTopBar.short_name("Wilmer Pertuz"), "Wilmer P.")
	assert_eq(MenuTopBar.short_name("Wilmer"), "Wilmer")
	assert_eq(MenuTopBar.short_name("  Wilmer   Pertuz  "), "Wilmer P.")
	assert_eq(MenuTopBar.short_name(""), "")


func test_route_chip_shows_route_time_and_pay() -> void:
	var chip := MenuRouteChip.new()
	add_child_autofree(chip)
	chip.show_route("Centro", "Mañana", "+$12.000")
	assert_eq(chip.label.text, "CENTRO · MAÑANA · +$12.000")
	assert_eq(chip.custom_minimum_size.y, 52.0)
	assert_eq(chip.focus_mode, Control.FOCUS_NONE)


func test_route_chip_shrinks_a_long_name() -> void:
	var chip := MenuRouteChip.new()
	add_child_autofree(chip)
	chip.show_route("A very long route name that keeps going and going and going", "Late afternoon", "+$123.456.789")
	var fitted := chip.label.get_theme_font_size("font_size")
	assert_lt(fitted, MenuRouteChip.FONT_SIZE, "A long line shrinks")
	assert_gte(fitted, 12, "But it never becomes unreadable")


func test_shift_button_is_big_enough() -> void:
	var shift := MenuShiftButton.new()
	add_child_autofree(shift)
	await wait_frames(1)
	assert_gte(shift.custom_minimum_size.x, 170.0)
	assert_gte(shift.custom_minimum_size.y, 68.0)
	assert_eq(shift.label.text, "START SHIFT")


func test_shift_button_pulsing_toggles() -> void:
	var shift := MenuShiftButton.new()
	add_child_autofree(shift)
	await wait_frames(1)
	assert_false(shift.is_pulsing())
	shift.set_pulsing(true)
	assert_true(shift.is_pulsing())
	await wait_seconds(0.25)
	assert_gt(shift.scale.x, 1.0, "It grows while pulsing")
	shift.set_pulsing(false)
	assert_false(shift.is_pulsing())
	assert_eq(shift.scale, Vector2.ONE, "Stopping puts it back at its normal size")


func _on_driver_pressed() -> void:
	_driver_taps += 1
