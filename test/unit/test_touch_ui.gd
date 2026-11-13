extends GutTest
## The pieces behind finger-friendly menus.

const MENU := preload("res://scenes/main/main_menu.tscn")


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


func test_routes_tab_district_filtering_and_lock_badge() -> void:
	Profile.load_from("user://test_save_touch_ui.json")
	Profile.data = PlayerProfile.new()
	Profile.data.intro_done = true
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.xp = 0 # Level 1 driver
	var was_lang := GameSettings.language
	GameSettings.language = "es_CO"

	var menu: MainMenu = autofree(MENU.instantiate())
	add_child(menu)
	menu.show_tab(1)
	await wait_frames(2)

	var selector: HBoxContainer = menu.find_child("TownSelector", true, false)
	assert_not_null(selector, "TownSelector segmented row exists on Routes tab")
	var pm_btn: Button = selector.find_child("TownPuertoMarisol", true, false)
	var ac_btn: Button = selector.find_child("TownAltoCafeto", true, false)
	assert_not_null(pm_btn, "Puerto Marisol button exists")
	assert_not_null(ac_btn, "Alto Cafeto button exists")
	assert_gte(pm_btn.size.y, 48.0, "Buttons at least 48 px high")
	assert_gte(ac_btn.size.y, 48.0, "Buttons at least 48 px high")

	# Lock badge below level 5
	assert_null(pm_btn.find_child("LockBadge", true, false), "Puerto Marisol is not locked")
	var lock_badge: Label = ac_btn.find_child("LockBadge", true, false)
	assert_not_null(lock_badge, "Alto Cafeto has lock badge below level 5")
	assert_true(lock_badge.text.contains("🔒"), "Badge shows a lock")
	assert_true(lock_badge.text.contains("Nivel 5"), "Badge shows Nivel 5 in Spanish")
	var remanso_btn: Button = selector.find_child("TownPuertoRemanso", true, false)
	assert_not_null(remanso_btn, "Puerto Remanso button exists")
	var remanso_badge: Label = remanso_btn.find_child("LockBadge", true, false)
	assert_true(remanso_badge != null and remanso_badge.text.contains("Nivel 10"), "Puerto Remanso badge shows its lowest route level, 10")

	# Filtering Puerto Marisol
	var labels := menu._content.find_children("*", "Label", true, false)
	var label_texts: Array[String] = []
	for l: Label in labels:
		label_texts.append(l.text)
	assert_true(label_texts.any(func(t: String) -> bool: return t.contains("Vuelta a la Costa") or t.contains("Route 1") or t.contains("Ruta 1")))
	assert_false(label_texts.any(func(t: String) -> bool: return t.contains("Vuelta al Pueblo")))

	# View locked town
	ac_btn.pressed.emit()
	await wait_frames(2)
	assert_eq(Profile.chosen_town(), "Alto Cafeto")
	labels = menu._content.find_children("*", "Label", true, false)
	label_texts = []
	for l: Label in labels:
		label_texts.append(l.text)
	assert_true(label_texts.any(func(t: String) -> bool: return t.contains("Vuelta al Pueblo")), "Alto Cafeto routes can be viewed")
	assert_false(label_texts.any(func(t: String) -> bool: return t.contains("Vuelta a la Costa") or t.contains("Ruta 1")), "Puerto Marisol routes filtered out")

	# Locked routes cannot be played
	assert_false(Profile.data.can_play_route("cafeto_c0", Profile.catalog))
	assert_false(Profile.select(Catalog.ROUTES, "cafeto_c0"))
	assert_ne(Profile.data.selected[Catalog.ROUTES], "cafeto_c0")

	# Reach level 5: badge disappears
	Profile.data.xp = DriverLevel.xp_for_level(5)
	menu.show_tab(1)
	await wait_frames(2)
	selector = menu.find_child("TownSelector", true, false)
	ac_btn = selector.find_child("TownAltoCafeto", true, false)
	assert_null(ac_btn.find_child("LockBadge", true, false), "Badge gone at level 5")
	assert_true(Profile.data.can_play_route("cafeto_c0", Profile.catalog), "Playable at level 5")

	GameSettings.language = was_lang


func test_chosen_town_persists_in_profile() -> void:
	var profile := PlayerProfile.new()
	profile.grant_free_items(Profile.catalog)
	# Old save with no town key
	var old_save := {
		"coins": 500,
		"selected": {Catalog.ROUTES: "starter_a"}
	}
	var loaded := PlayerProfile.from_dict(old_save)
	assert_eq(loaded.town, "", "Old save has empty town")
	Profile.data = loaded
	assert_eq(Profile.chosen_town(), "Puerto Marisol", "Defaults to town of selected route")

	# Explicitly choose Alto Cafeto
	Profile.choose_town("Alto Cafeto")
	assert_eq(Profile.chosen_town(), "Alto Cafeto")
	assert_eq(Profile.data.town, "Alto Cafeto")

	# Saves and loads back
	var dict := Profile.data.to_dict()
	assert_eq(dict["town"], "Alto Cafeto")
	var restored := PlayerProfile.from_dict(dict)
	assert_eq(restored.town, "Alto Cafeto")
