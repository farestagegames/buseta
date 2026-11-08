extends GutTest
## The pieces behind finger-friendly menus.


func test_insets_clear_a_notch_on_the_left() -> void:
	# A 2400 x 1080 phone with an 80 px notch, shown at 1600 x 720.
	var insets := UiStyle.safe_insets(Vector2(1600.0, 720.0), Vector2i(2400, 1080), Rect2i(80, 0, 2320, 1080))
	assert_almost_eq(insets.x, 53.3, 0.1)
	assert_eq(insets.y, 0.0)
	assert_eq(insets.z, 0.0)
	assert_eq(insets.w, 0.0)


func test_insets_clear_a_gesture_bar_and_a_notch_on_the_right() -> void:
	var insets := UiStyle.safe_insets(Vector2(1280.0, 720.0), Vector2i(1920, 1080), Rect2i(0, 0, 1860, 1032))
	assert_almost_eq(insets.z, 40.0, 0.01)
	assert_almost_eq(insets.w, 32.0, 0.01)


func test_insets_are_padded_on_both_sides_so_turning_the_phone_keeps_them_clear() -> void:
	assert_eq(UiStyle.both_ways(Vector4(53.0, 0.0, 0.0, 32.0)), Vector4(53.0, 32.0, 53.0, 32.0))
	assert_eq(UiStyle.both_ways(Vector4(0.0, 10.0, 40.0, 0.0)), Vector4(40.0, 10.0, 40.0, 10.0))


func test_no_insets_without_a_screen() -> void:
	assert_eq(UiStyle.safe_insets(Vector2(1280.0, 720.0), Vector2i.ZERO, Rect2i()), Vector4.ZERO)


func test_screen_insets_are_zero_on_a_computer() -> void:
	if OS.has_feature("mobile"):
		pass_test("Only meaningful on a computer")
		return
	assert_eq(UiStyle.screen_insets(Vector2(1280.0, 720.0)), Vector4.ZERO)


func test_a_touch_list_scrolls_only_up_and_down_with_a_deadzone() -> void:
	var list: TouchScroll = autofree(TouchScroll.new())
	assert_eq(list.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_gte(list.scroll_deadzone, 10)


func test_everything_in_a_touch_list_lets_a_drag_through() -> void:
	var list := TouchScroll.new()
	add_child_autofree(list)
	var rows := VBoxContainer.new()
	list.add_child(rows)
	var card := PanelContainer.new()
	rows.add_child(card)
	var button := Button.new()
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	card.add_child(button)
	var label := Label.new()
	card.add_child(label)
	await wait_physics_frames(1)
	# Added later, as a tab refresh would.
	var late := ColorRect.new()
	rows.add_child(late)
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(button.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(button.action_mode, BaseButton.ACTION_MODE_BUTTON_RELEASE, "Fires on lifting the finger")
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Ignored stays ignored")
	assert_eq(late.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(list.get_v_scroll_bar().mouse_filter, Control.MOUSE_FILTER_STOP, "The bar is left alone")


func test_a_list_rebuilt_after_a_purchase_returns_to_its_place() -> void:
	var list := TouchScroll.new()
	list.size = Vector2(300.0, 200.0)
	add_child_autofree(list)
	var rows := VBoxContainer.new()
	list.add_child(rows)
	list.restore_offset(500)
	for i in 20:
		var row := Control.new()
		row.custom_minimum_size.y = 80.0
		rows.add_child(row)
	await wait_physics_frames(3)
	assert_eq(list.scroll_vertical, 500)


func test_slider_value_follows_the_finger_across_the_track() -> void:
	var slider := TouchSlider.new()
	slider.min_value = 0.5
	slider.max_value = 2.0
	slider.step = 0.0
	slider.size = Vector2(434.0, 40.0)
	add_child_autofree(slider)
	var grab := slider.get_theme_icon("grabber").get_width()
	assert_almost_eq(slider.value_at(grab / 2.0), 0.5, 0.001)
	assert_almost_eq(slider.value_at(slider.size.x - grab / 2.0), 2.0, 0.001)
	assert_almost_eq(slider.value_at(slider.size.x / 2.0), 1.25, 0.001)
	assert_almost_eq(slider.value_at(-50.0), 0.5, 0.001, "Clamped")
