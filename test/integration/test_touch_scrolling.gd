extends GutTest
## Scrolling the menus with a finger, as on the phone. Each touch goes to the
## real menu with the mouse event Godot makes from it on Android, in the same
## order Input sends them. The headless test run has no display to send them
## through Input itself.

const MENU := preload("res://scenes/main/main_menu.tscn")
const GARAGE_TAB := 2
const CAREER_TAB := 4

var screen: SubViewport
var menu: MainMenu
var presses := 0


func before_each() -> void:
	Profile.load_from("user://test_save_scroll.json")
	Profile.data = PlayerProfile.new()
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.intro_done = true
	Profile.data.coins = 100000
	Profile.data.xp = 100000
	presses = 0
	# A screen of its own at a 16:9 phone's size, away from the test runner's window.
	screen = SubViewport.new()
	screen.size = Vector2i(1280, 720)
	add_child_autofree(screen)
	menu = MENU.instantiate()
	screen.add_child(menu)
	await wait_physics_frames(2)


func after_all() -> void:
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func _send(touch: InputEvent, mouse: InputEvent) -> void:
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	screen.push_input(mouse, true)
	screen.push_input(touch, true)


func _touch(position: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = down
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = down
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	mouse.position = position
	mouse.global_position = position
	_send(event, mouse)
	await wait_physics_frames(2)


## Moves a finger that is already down, one step a frame.
func _move(from: Vector2, to: Vector2, steps: int) -> void:
	var last := from
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / steps)
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = point
		event.relative = point - last
		event.velocity = (point - last) * 60.0
		var mouse := InputEventMouseMotion.new()
		mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
		mouse.position = point
		mouse.global_position = point
		mouse.relative = event.relative
		mouse.velocity = event.velocity
		_send(event, mouse)
		last = point
		await wait_physics_frames(1)


func _swipe(from: Vector2, to: Vector2, steps: int = 12) -> void:
	await _touch(from, true)
	await _move(from, to, steps)
	await _touch(to, false)


func _tap(position: Vector2) -> void:
	await _touch(position, true)
	await _touch(position, false)


func _open(tab: int) -> TouchScroll:
	menu.show_tab(tab)
	await wait_physics_frames(3)
	return TouchScroll.first_in(menu._content)


## The first enabled control of a class that is fully in view in the list.
func _in_view(list: ScrollContainer, type: String) -> Control:
	for node in list.find_children("*", type, true, false):
		var control := node as Control
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		if control.is_visible_in_tree() and list.get_global_rect().encloses(control.get_global_rect()):
			return control
	return null


func _count_press() -> void:
	presses += 1


func _count_every_press(list: ScrollContainer) -> void:
	for node in list.find_children("*", "BaseButton", true, false):
		(node as BaseButton).pressed.connect(_count_press)


## Waits for a flick to die down, and a little longer, as a player would
## before tapping. A tap on a list that is still moving only stops it.
func _settle(list: ScrollContainer) -> void:
	var last := -1
	while list.scroll_vertical != last:
		last = list.scroll_vertical
		await wait_physics_frames(4)
	await wait_physics_frames(12)


func test_a_drag_that_starts_on_a_buy_button_scrolls_and_buys_nothing() -> void:
	var list := await _open(GARAGE_TAB)
	var buy: Button = _in_view(list, "Button")
	buy.pressed.connect(_count_press)
	var centre := buy.get_global_rect().get_center()
	await _swipe(centre, centre + Vector2(0.0, -260.0))
	assert_gt(list.scroll_vertical, 150, "The list follows the finger")
	assert_eq(presses, 0, "A scroll is not a tap")
	assert_eq(Profile.data.coins, 100000, "Nothing bought")


func test_a_short_drag_that_ends_back_on_the_button_does_not_press_it() -> void:
	var list := await _open(GARAGE_TAB)
	var buy: Button = _in_view(list, "Button")
	buy.pressed.connect(_count_press)
	var centre := buy.get_global_rect().get_center()
	await _touch(centre, true)
	await _move(centre, centre + Vector2(0.0, 30.0), 4)
	await _move(centre + Vector2(0.0, 30.0), centre, 4)
	await _touch(centre, false)
	assert_eq(presses, 0)
	assert_eq(Profile.data.coins, 100000)


func test_a_drag_that_starts_on_a_card_scrolls() -> void:
	var list := await _open(CAREER_TAB)
	var card: Control = _in_view(list, "PanelContainer")
	var centre := card.get_global_rect().get_center()
	await _swipe(centre, centre + Vector2(0.0, -200.0))
	assert_gt(list.scroll_vertical, 100)


func test_a_tap_with_a_little_wobble_still_presses() -> void:
	var list := await _open(GARAGE_TAB)
	var buy: Button = _in_view(list, "Button")
	buy.pressed.connect(_count_press)
	var centre := buy.get_global_rect().get_center()
	await _swipe(centre, centre + Vector2(5.0, 7.0), 2)
	assert_eq(presses, 1)
	assert_lt(Profile.data.coins, 100000, "Bought")
	assert_eq(TouchScroll.first_in(menu._content).scroll_vertical, 0, "A wobble is not a scroll")


func test_a_flick_keeps_the_list_moving() -> void:
	var list := await _open(GARAGE_TAB)
	var start := list.get_global_rect().get_center()
	await _swipe(start, start + Vector2(0.0, -120.0), 3)
	var at_release := list.scroll_vertical
	await wait_physics_frames(20)
	assert_gt(list.scroll_vertical, at_release + 50, "Momentum carries it on")


func test_a_tap_on_a_moving_list_only_stops_it() -> void:
	var list := await _open(GARAGE_TAB)
	var start := list.get_global_rect().get_center()
	_count_every_press(list)
	await _swipe(start + Vector2(0.0, 200.0), start + Vector2(0.0, 80.0), 3)
	var button: Button = _in_view(list, "Button")
	await _tap(button.get_global_rect().get_center())
	assert_eq(presses, 0, "Stopping a fling presses nothing")
	var stopped := list.scroll_vertical
	assert_lt(stopped, 1000, "It stopped before the end")
	await wait_physics_frames(10)
	assert_eq(list.scroll_vertical, stopped, "And the list stays where it stopped")
	await _settle(list)
	button = _in_view(list, "Button")
	await _tap(button.get_global_rect().get_center())
	assert_eq(presses, 1, "Once still, a tap presses again")


func test_scrolling_over_a_garage_row_does_not_try_it_on() -> void:
	var list := await _open(GARAGE_TAB)
	var shown := menu._preview_note.text
	var row: Control = _in_view(list, "PanelContainer")
	var point := row.get_global_rect().position + Vector2(30.0, 20.0)
	await _swipe(point, point + Vector2(0.0, -200.0))
	assert_gt(list.scroll_vertical, 100)
	assert_eq(menu._preview_note.text, shown, "Scrolling past a bus does not show it")
	await _settle(list)
	row = _in_view(list, "PanelContainer")
	await _tap(row.get_global_rect().position + Vector2(30.0, 20.0))
	assert_ne(menu._preview_note.text, shown, "A tap does")


func test_buying_keeps_the_list_where_it_was() -> void:
	var list := await _open(GARAGE_TAB)
	list.scroll_vertical = 600
	await wait_physics_frames(3)
	var buy: Button = null
	for node in list.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text.begins_with(tr("Buy %s") % "") and list.get_global_rect().encloses(button.get_global_rect()):
			buy = button
	assert_not_null(buy, "A Buy button in view")
	await _tap(buy.get_global_rect().get_center())
	assert_lt(Profile.data.coins, 100000, "The tap bought it")
	var rebuilt := TouchScroll.first_in(menu._content)
	assert_ne(rebuilt, list, "The tab was rebuilt")
	await wait_physics_frames(3)
	assert_eq(rebuilt.scroll_vertical, 600)


func test_a_vertical_drag_on_a_slider_scrolls_and_keeps_the_setting() -> void:
	var list := await _open(MainMenu.SETTINGS_TAB)
	var slider: HSlider = _in_view(list, "HSlider")
	var before := slider.value
	var point := slider.get_global_rect().get_center() + Vector2(200.0, 0.0)
	await _swipe(point, point + Vector2(0.0, -200.0))
	assert_gt(list.scroll_vertical, 50)
	assert_eq(slider.value, before)


func test_a_sideways_drag_on_a_slider_moves_it_and_not_the_list() -> void:
	var list := await _open(MainMenu.SETTINGS_TAB)
	var slider: TouchSlider = _in_view(list, "HSlider")
	var start := slider.get_global_rect().get_center()
	var end := start + Vector2(-220.0, 10.0)
	await _swipe(start, end)
	assert_eq(list.scroll_vertical, 0)
	assert_almost_eq(slider.value, snappedf(slider.value_at(end.x - slider.get_global_rect().position.x), slider.step), 0.001)
	assert_lt(slider.value, 1.0)
	GameSettings.sensitivity = 1.0


func test_a_drag_from_a_switch_or_the_language_box_scrolls_without_changing_them() -> void:
	var list := await _open(MainMenu.SETTINGS_TAB)
	var settings: SettingsPanel = menu._content.get_child(0)
	var picker := settings.language_picker
	var point := picker.get_global_rect().get_center()
	await _swipe(point, point + Vector2(0.0, -150.0))
	assert_gt(list.scroll_vertical, 50)
	assert_false(picker.get_popup().visible, "The dropdown stays shut")
	var switch: CheckButton = _in_view(list, "CheckButton")
	var was_on := switch.button_pressed
	point = switch.get_global_rect().get_center()
	await _swipe(point, point + Vector2(0.0, 150.0))
	assert_eq(switch.button_pressed, was_on)


func test_a_drag_from_a_town_button_scrolls_without_switching_town() -> void:
	var list := await _open(1)
	var selector: HBoxContainer = menu.find_child("TownSelector", true, false)
	assert_not_null(selector, "TownSelector is in routes tab")
	var ac_btn: Button = selector.find_child("TownAltoCafeto", true, false)
	assert_not_null(ac_btn, "Alto Cafeto button exists")
	assert_eq(Profile.chosen_town(), "Puerto Marisol")
	assert_false(ac_btn.button_pressed)

	var point := ac_btn.get_global_rect().get_center()
	await _swipe(point, point + Vector2(0.0, -120.0))
	assert_gt(list.scroll_vertical, 20, "List scrolled from drag on town button")
	assert_eq(Profile.chosen_town(), "Puerto Marisol", "Drag did not switch town")
	assert_false(ac_btn.button_pressed, "Button was not toggled by drag")


func test_every_list_reaches_its_last_row_on_wide_and_narrow_phones() -> void:
	for width: float in [1280.0, 1600.0]:
		screen.size = Vector2i(int(width), 720)
		for tab: int in [1, 2, 3, 4, 5]:
			var list := await _open(tab)
			list.scroll_vertical = 100000
			await wait_physics_frames(2)
			var view := Rect2(Vector2.ZERO, Vector2(screen.size))
			var shown := list.get_global_rect()
			assert_true(view.encloses(shown), "Tab %d at %d: list on screen %s" % [tab, width, shown])
			var rows := list.get_child(0) as Control
			var last := rows.get_child(rows.get_child_count() - 1) as Control
			var bottom := last.get_global_rect().end.y
			assert_between(bottom, shown.position.y, shown.end.y + 0.5, "Tab %d at %d: last row in view" % [tab, width])


func test_every_scrolling_list_is_a_touch_list() -> void:
	for tab in 6:
		menu.show_tab(tab)
		await wait_physics_frames(2)
		for node in _lists(menu._content):
			assert_is(node, TouchScroll, "Tab %d" % tab)
	var hud := DriveHud.new()
	add_child_autofree(hud)
	await wait_physics_frames(2)
	for panel: Control in [hud.settings_panel, hud.shift_panel]:
		var lists := _lists(panel)
		assert_gt(lists.size(), 0)
		for node in lists:
			assert_is(node, TouchScroll, panel.get_class())


## Scrolling lists on screen, leaving out the one inside the dropdown's popup.
func _lists(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	for node in root.find_children("*", "ScrollContainer", true, false):
		if node.get_window() == root.get_window():
			found.append(node)
	return found


func test_the_menu_keeps_clear_of_a_notch() -> void:
	# The phone can be turned round without the view changing size, so a notch on
	# either side keeps both sides clear.
	for insets: Vector4 in [Vector4(48.0, 0.0, 0.0, 0.0), Vector4(0.0, 0.0, 48.0, 0.0)]:
		menu.fit_to_screen(insets)
		var list := await _open(GARAGE_TAB)
		for tab: Button in menu._tabs:
			assert_gte(tab.get_global_rect().position.x, 48.0, str(insets))
		assert_lte(list.get_global_rect().end.x, float(screen.size.x) - 48.0, str(insets))


func test_tapping_the_language_box_opens_it_and_a_choice_changes_the_language() -> void:
	var was := GameSettings.language
	await _open(MainMenu.SETTINGS_TAB)
	var settings: SettingsPanel = menu._content.get_child(0)
	var picker := settings.language_picker
	var popup := picker.get_popup()
	assert_eq(popup.child_entered_tree.get_connections().size(), 0, "The list leaves the popup's insides alone")
	await _tap(picker.get_global_rect().get_center())
	assert_true(popup.visible, "The dropdown opened")
	var choice := 1 if picker.selected != 1 else 0
	# The popup reports a picked row with this signal, as a tap on it would.
	popup.index_pressed.emit(choice)
	await wait_physics_frames(2)
	assert_eq(picker.selected, choice)
	assert_eq(GameSettings.language, Country.pack.languages()[choice]["code"])
	popup.hide()
	GameSettings.language = was
