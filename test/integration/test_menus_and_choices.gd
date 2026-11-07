extends GutTest
## The menus and what they change in a shift.

const MENU := preload("res://scenes/main/main_menu.tscn")
const CITY := preload("res://scenes/main/city_shift.tscn")


func before_each() -> void:
	Profile.load_from("user://test_save_menu.json")
	Profile.data = PlayerProfile.new()
	Profile.data.intro_done = true


func after_all() -> void:
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func test_every_menu_tab_opens() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	for i in 6:
		menu.show_tab(i)
		await wait_frames(2)
		assert_gt(menu._content.get_child_count(), 0, "Tab %d" % i)


func test_buying_in_the_menu_spends_coins_and_selects() -> void:
	Profile.data.coins = 1000
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(2)
	menu._on_buy(Catalog.LIVERIES, "park_green")
	assert_eq(Profile.data.coins, 600)
	assert_eq(Profile.data.selected[Catalog.LIVERIES], "park_green")


func test_selected_livery_paints_the_bus() -> void:
	Profile.data.coins = 1000
	Profile.buy(Catalog.LIVERIES, "park_green")
	Profile.select(Catalog.LIVERIES, "park_green")
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	var bus: BusController = city.get_node("Bus")
	assert_almost_eq(bus.spec.body_colour.g, 0.42, 0.01)
	var stock: BusSpec = load("res://data/buses/city_bus.tres")
	assert_ne(stock.body_colour, bus.spec.body_colour, "Must not repaint the shared bus data")


func test_midi_bus_is_shorter_and_turns_tighter() -> void:
	Profile.data.coins = 5000
	Profile.buy(Catalog.BUSES, "midi_10")
	Profile.select(Catalog.BUSES, "midi_10")
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	var bus: BusController = city.get_node("Bus")
	assert_eq(bus.spec.display_name, "Midi 10")
	assert_lt(bus.spec.overall_length(), 11.0)
	var midi_radius := bus.spec.wheelbase / tan(deg_to_rad(bus.spec.max_steer_degrees))
	var big: BusSpec = load("res://data/buses/city_bus.tres")
	assert_lt(midi_radius, big.wheelbase / tan(deg_to_rad(big.max_steer_degrees)))
	var system: RouteSystem = city.get_node("RouteSystem")
	assert_eq(system.ledger.capacity, 30)


func test_second_route_loads_with_its_own_stops() -> void:
	Profile.data.coins = 5000
	Profile.buy(Catalog.ROUTES, "route_02")
	Profile.select(Catalog.ROUTES, "route_02")
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	assert_eq(city.route.current_stop().stop_name, "Mill Cross")
	assert_between(city.route.stops.size(), 6, 9)
	var last := 0.0
	for stop in city.route.stops:
		assert_gt(stop.route_distance, last, stop.stop_name)
		assert_gt(stop.due, 0.0, stop.stop_name)
		last = stop.route_distance


func test_settings_are_saved() -> void:
	GameSettings.sensitivity = 1.4
	var saved := PlayerProfile.from_dict(SaveStore.read("user://test_save_menu.json"))
	assert_almost_eq(float(saved.settings["sensitivity"]), 1.4, 0.001)
	GameSettings.sensitivity = 1.0


func _settings_tab() -> SettingsPanel:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(MainMenu.SETTINGS_TAB)
	await wait_frames(2)
	return menu._content.get_child(0)


func test_language_is_a_dropdown_listing_every_language() -> void:
	var settings: SettingsPanel = await _settings_tab()
	assert_eq(settings.language_picker.item_count, Lang.LANGUAGES.size())
	assert_eq(settings.language_picker.get_item_text(4), "हिन्दी", "Names stay in their own script")


func test_choosing_from_the_dropdown_changes_the_language() -> void:
	var settings: SettingsPanel = await _settings_tab()
	settings.language_picker.select(1)
	settings.language_picker.item_selected.emit(1)
	assert_eq(GameSettings.language, "fr")
	assert_eq(TranslationServer.get_locale(), "fr")
	GameSettings.language = "en"
	await wait_frames(1)
	assert_eq(settings.language_picker.selected, 0, "Follows the setting")


func test_dropdown_shows_the_saved_language_when_it_opens() -> void:
	GameSettings.language = "ar"
	var settings: SettingsPanel = await _settings_tab()
	assert_eq(settings.language_picker.selected, 5)
	GameSettings.language = "en"


func test_drivers_tab_lists_everyone() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(MainMenu.DRIVERS_TAB)
	await wait_frames(2)
	var rows: Node = menu._content.get_child(0).get_child(0).get_child(0)
	assert_eq(rows.get_child_count(), Profile.catalog.items(Catalog.DRIVERS).size())


func test_home_shows_the_chosen_driver() -> void:
	Profile.data.coins = 5000
	Profile.buy(Catalog.DRIVERS, "priya_nair")
	Profile.select(Catalog.DRIVERS, "priya_nair")
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	var labels := menu.find_children("*", "Label", true, false)
	assert_true(labels.any(func(label: Label) -> bool: return label.text == "Priya Nair"))


func test_chosen_driver_sits_in_the_bus() -> void:
	Profile.data.coins = 5000
	Profile.buy(Catalog.DRIVERS, "fatima_haddad")
	Profile.select(Catalog.DRIVERS, "fatima_haddad")
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	var visual: BusVisual = city.get_node("Bus/Visual")
	assert_eq(visual.driver_look.driver_name, "Fatima Haddad")
	assert_eq(visual.driver_look.hair_style, "hijab")


func test_cockpit_shows_the_hands_and_mirror_with_the_body_hidden() -> void:
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	await wait_physics_frames(2)
	var visual: BusVisual = city.get_node("Bus/Visual")
	var camera: CameraRig = city.get_node("CameraRig")
	while camera.view_name() != "Cockpit":
		camera.next_view()
	await wait_frames(2)
	assert_false(visual.driver_visible(), "The body would block the view")
	assert_true(visual.hands_visible())
	assert_true(visual.mirror_face().is_visible_in_tree())


func test_hands_follow_the_wheel_only_so_far() -> void:
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	await wait_physics_frames(2)
	var visual: BusVisual = city.get_node("Bus/Visual")
	var straight: Vector3 = visual._hands[0].position
	visual._pose_arms(0.5)
	var turned: Vector3 = visual._hands[0].position
	assert_gt(straight.distance_to(turned), 0.05)
	visual._pose_arms(1.8)
	var far: Vector3 = visual._hands[0].position
	visual._pose_arms(3.0)
	assert_almost_eq(far.distance_to(visual._hands[0].position), 0.0, 0.001)
