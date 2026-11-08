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
	menu._on_buy(Catalog.LIVERIES, "verde_manglar")
	assert_eq(Profile.data.coins, 600)
	assert_eq(Profile.data.selected[Catalog.LIVERIES], "verde_manglar")


func test_selected_livery_paints_the_bus() -> void:
	Profile.data.coins = 1000
	Profile.buy(Catalog.LIVERIES, "verde_manglar")
	Profile.select(Catalog.LIVERIES, "verde_manglar")
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	var bus: BusController = city.get_node("Bus")
	assert_almost_eq(bus.spec.body_colour.g, 0.46, 0.01)
	var stock: BusSpec = load("res://data/packs/colombia/buses/city_bus.tres")
	assert_ne(stock.body_colour, bus.spec.body_colour, "Must not repaint the shared bus data")


func test_midi_bus_is_shorter_and_turns_tighter() -> void:
	Profile.data.coins = 5000
	Profile.buy(Catalog.BUSES, "midi_10")
	Profile.select(Catalog.BUSES, "midi_10")
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	var bus: BusController = city.get_node("Bus")
	assert_eq(bus.spec.display_name, "Caimán B10")
	assert_lt(bus.spec.overall_length(), 11.0)
	var midi_radius := bus.spec.wheelbase / tan(deg_to_rad(bus.spec.max_steer_degrees))
	var big: BusSpec = load("res://data/packs/colombia/buses/city_bus.tres")
	assert_lt(midi_radius, big.wheelbase / tan(deg_to_rad(big.max_steer_degrees)))
	var system: RouteSystem = city.get_node("RouteSystem")
	assert_eq(system.ledger.capacity, 30)


func test_second_route_loads_with_its_own_stops() -> void:
	Profile.data.coins = 5000
	Profile.buy(Catalog.ROUTES, "route_02")
	Profile.select(Catalog.ROUTES, "route_02")
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	assert_eq(city.route.current_stop().stop_name, "Calle de los Almendros")
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
	assert_eq(settings.language_picker.item_count, Country.pack.languages().size())
	assert_eq(settings.language_picker.get_item_text(0), "Español (Colombia)", "Names stay in their own language")
	assert_eq(settings.language_picker.get_item_text(1), "English", "English comes second")


func test_choosing_from_the_dropdown_changes_the_language() -> void:
	var settings: SettingsPanel = await _settings_tab()
	settings.language_picker.select(0)
	settings.language_picker.item_selected.emit(0)
	assert_eq(GameSettings.language, "es_CO")
	assert_eq(TranslationServer.get_locale(), "es_CO")
	GameSettings.language = "en"
	await wait_frames(1)
	assert_eq(settings.language_picker.selected, 1, "Follows the setting")


func test_dropdown_shows_the_saved_language_when_it_opens() -> void:
	GameSettings.language = "es_CO"
	var settings: SettingsPanel = await _settings_tab()
	assert_eq(settings.language_picker.selected, 0)
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
	Profile.buy(Catalog.DRIVERS, "yolima_uriana")
	Profile.select(Catalog.DRIVERS, "yolima_uriana")
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	var labels := menu.find_children("*", "Label", true, false)
	assert_true(labels.any(func(label: Label) -> bool: return label.text == "Yolima Uriana"))


func test_chosen_driver_sits_in_the_bus() -> void:
	Profile.data.coins = 5000
	Profile.buy(Catalog.DRIVERS, "fanny_mosquera")
	Profile.select(Catalog.DRIVERS, "fanny_mosquera")
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	var visual: BusVisual = city.get_node("Bus/Visual")
	assert_eq(visual.driver_look.driver_name, "Fanny Mosquera")
	assert_eq(visual.driver_look.hat, "headwrap")


## Draws a portrait and counts how often it was drawn.
class CountedBadge:
	extends DriverBadge
	var draws: int = 0

	func _draw() -> void:
		super()
		draws += 1


func test_every_driver_option_draws_a_portrait() -> void:
	var looks: Array[DriverLook] = []
	for style: String in DriverLook.HAIR_STYLES:
		var look := DriverLook.new()
		look.hair_style = style
		looks.append(look)
	for i in maxi(DriverLook.HATS.size(), DriverLook.BEARDS.size()):
		var look := DriverLook.new()
		look.hat = DriverLook.HATS[i % DriverLook.HATS.size()]
		look.beard = DriverLook.BEARDS[i % DriverLook.BEARDS.size()]
		look.outfit = DriverLook.OUTFITS[i % DriverLook.OUTFITS.size()]
		look.glasses = i % 2 == 0
		look.greying = i % 2 == 1
		look.earrings = true
		looks.append(look)
	var badges: Array[CountedBadge] = []
	for look in looks:
		var badge := CountedBadge.new(look)
		add_child_autofree(badge)
		badges.append(badge)
	await wait_frames(3)
	for badge in badges:
		assert_gt(badge.draws, 0, "%s %s" % [badge.look.hair_style, badge.look.hat])


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


func test_garage_tries_a_paint_on_the_bus_without_buying_it() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(2)
	await wait_frames(2)
	menu.try_on(Catalog.LIVERIES, Profile.catalog.find(Catalog.LIVERIES, "carnaval"))
	await wait_frames(1)
	assert_eq(menu._garage_preview.shown_spec().pattern, "zigzag")
	assert_eq(Profile.data.selected[Catalog.LIVERIES], PlayerProfile.DEFAULT_LIVERY)
	assert_false(Profile.data.owns(Catalog.LIVERIES, "carnaval"))


func test_garage_can_try_a_locked_bus() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(2)
	await wait_frames(2)
	menu.try_on(Catalog.BUSES, Profile.catalog.find(Catalog.BUSES, "chiva"))
	await wait_frames(1)
	assert_eq(menu._garage_preview.shown_spec().body_style, "chiva")


func test_route_only_bus_is_not_on_sale_in_the_garage() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(2)
	await wait_frames(2)
	var labels := menu.find_children("*", "Label", true, false)
	assert_false(labels.any(func(label: Label) -> bool: return label.text == "Alcatraz A18"))


func test_garage_lists_the_horns_and_plays_one_to_listen() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(2)
	await wait_frames(2)
	var labels := menu.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
	for item: Dictionary in Country.pack.horns():
		assert_true(labels.has(item["name"]), item["name"])
	assert_true(labels.has("The bus's own horn"))
	menu.preview_horn(Country.pack.horn("chiva"))
	assert_true(menu.horn_preview_playing())
	await wait_seconds(2.2)
	assert_false(menu.horn_preview_playing(), "Plays once through")
	menu.preview_horn({})
	assert_true(menu.horn_preview_playing(), "The bus's own horn plays too")


func test_garage_buys_and_fits_a_horn() -> void:
	Profile.data.coins = 1000
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(2)
	await wait_frames(2)
	menu._on_buy_horn("double_tap")
	assert_eq(Profile.data.horn, "double_tap")
	assert_eq(Profile.data.coins, 1000 - int(Country.pack.horn("double_tap")["cost"]))
	menu._on_choose_horn("")
	assert_eq(Profile.data.horn, "")


func test_garage_horn_buttons_sit_in_a_touch_list() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(2)
	await wait_frames(2)
	var listen := menu.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.text == "▶")
	assert_eq(listen.size(), Country.pack.horns().size() + 1)
	for button: Button in listen:
		assert_not_null(TouchScroll.find_list(button))


func test_settings_have_a_radio_volume_slider() -> void:
	var panel := SettingsPanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	assert_true(panel.radio_slider is TouchSlider)
	panel.radio_slider.value = 0.4
	assert_almost_eq(GameSettings.radio_volume, 0.4, 0.001)
	assert_almost_eq(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(SoundBuses.RADIO))), 0.4, 0.01)
	panel.radio_slider.value = 0.8


func test_a_country_without_radio_hides_the_button_and_slider() -> void:
	Country.use_pack("res://test/fixtures/packs/testland/pack.json")
	var hud := DriveHud.new()
	add_child_autofree(hud)
	var panel := SettingsPanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	assert_false(hud.radio_button.visible)
	assert_null(panel.radio_slider)
	Country.use_pack("res://data/packs/colombia/pack.json")
	var colombian := DriveHud.new()
	add_child_autofree(colombian)
	await wait_frames(1)
	assert_true(colombian.radio_button.visible)
