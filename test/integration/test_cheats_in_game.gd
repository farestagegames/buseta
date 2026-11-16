extends GutTest
## The cheats stay hidden until asked for, and work in a real shift.

const MENU := preload("res://scenes/main/main_menu.tscn")
const CITY := preload("res://scenes/main/city_shift.tscn")

var reports: Array[Dictionary] = []


func before_each() -> void:
	Profile.load_from("user://test_save_cheats.json")
	Profile.data = PlayerProfile.new()
	Profile.data.intro_done = true
	reports.clear()


func after_all() -> void:
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func _on_report(report: Dictionary) -> void:
	reports.append(report)


func _tap(control: Control, times: int) -> void:
	for i in times:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		control.gui_input.emit(press)


func _title_of(menu: MainMenu) -> Label:
	return menu._frame.get_child(0).get_child(0).get_child(0)


func _cheat_panels(menu: MainMenu) -> int:
	return menu.get_children().filter(func(child: Node) -> bool: return child is CheatPanel).size()


func test_menu_shows_no_cheats_until_the_title_is_tapped_seven_times() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	assert_eq(_cheat_panels(menu), 0)
	_tap(_title_of(menu), 6)
	assert_eq(_cheat_panels(menu), 0)
	_tap(_title_of(menu), 1)
	assert_eq(_cheat_panels(menu), 1)


func test_coin_cheat_reaches_the_save_and_the_menu_header() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	menu.open_cheats()
	await wait_frames(2)
	var panel: CheatPanel = menu.get_child(menu.get_child_count() - 1)
	panel._apply(Cheats.add_coins.bind(1000))
	await wait_frames(2)
	assert_eq(Profile.data.coins, 1000)
	assert_eq(menu._coins_label.text, Country.pack.money(1000))
	assert_eq(PlayerProfile.from_dict(SaveStore.read("user://test_save_cheats.json")).coins, 1000)


func _start_shift() -> CityShift:
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	await wait_physics_frames(3)
	return city


func test_pause_menu_hides_the_shift_cheats_until_revealed() -> void:
	var city := await _start_shift()
	var settings: SettingsPanel = city.get_node("Hud").settings_panel
	assert_false(settings.cheat_row.visible)
	var title: Label = settings.get_child(0).get_child(0).get_child(0)
	_tap(title, 7)
	assert_true(settings.cheat_row.visible)


func test_skip_parks_in_the_next_bay_without_penalties() -> void:
	var city := await _start_shift()
	var system := city.route_system_for_tools()
	var keeper: ScoreKeeper = city.get_node("ScoreKeeper")
	GameEvents.skip_stop_requested.emit()
	await wait_physics_frames(3)
	assert_eq(system.runner.stop_index, 0)
	assert_true(system._aligned, "Parked straight in the first bay")
	GameEvents.skip_stop_requested.emit()
	await wait_physics_frames(3)
	assert_eq(system.runner.stop_index, 1, "A second skip moves on")
	assert_true(system._aligned, "Parked straight in the second bay")
	assert_eq(int(keeper.score.counts["indicators"]), 0, "Skipped turns are not held against the driver")
	assert_eq(int(keeper.score.counts["missed_stops"]), 0)


func test_skipping_every_stop_ends_the_shift() -> void:
	var city := await _start_shift()
	var system := city.route_system_for_tools()
	GameEvents.shift_report_ready.connect(_on_report)
	for i in system.runner.stops.size() + 1:
		if not system.finished:
			GameEvents.skip_stop_requested.emit()
			await wait_physics_frames(3)
	GameEvents.shift_report_ready.disconnect(_on_report)
	assert_true(system.finished)
	assert_eq(reports.size(), 1)


func test_finish_shift_cheat_opens_the_report_from_anywhere() -> void:
	var city := await _start_shift()
	var hud: DriveHud = city.get_node("Hud")
	GameEvents.finish_shift_requested.emit()
	await wait_frames(2)
	assert_true(hud.shift_panel.visible)
	assert_true(hud.shift_panel.menu_button.is_visible_in_tree())
