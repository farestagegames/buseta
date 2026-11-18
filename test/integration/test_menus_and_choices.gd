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
	var cost := int(Profile.catalog.find(Catalog.LIVERIES, "verde_manglar")["cost"])
	menu._on_buy(Catalog.LIVERIES, "verde_manglar")
	assert_eq(Profile.data.coins, 1000 - cost)
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


func test_drivers_tab_tries_a_locked_driver_without_buying_it() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(MainMenu.DRIVERS_TAB)
	await wait_frames(2)
	var item := Profile.catalog.find(Catalog.DRIVERS, "fanny_mosquera")
	menu.try_on_driver(item)
	await wait_frames(1)
	assert_eq(menu._drivers_preview.shown_look().driver_name, "Fanny Mosquera")
	assert_eq(menu._drivers_note.text, "%s · %s" % [item["name"], Country.pack.money(int(item["cost"]))])
	assert_false(Profile.data.owns(Catalog.DRIVERS, "fanny_mosquera"))
	assert_ne(Profile.data.selected[Catalog.DRIVERS], "fanny_mosquera")
	assert_eq(Profile.data.coins, 0, "Trying a driver never spends coins")


func test_drivers_tab_buy_button_still_buys() -> void:
	Profile.data.coins = 1000
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(MainMenu.DRIVERS_TAB)
	await wait_frames(2)
	var item := Profile.catalog.find(Catalog.DRIVERS, "fanny_mosquera")
	menu._on_buy(Catalog.DRIVERS, "fanny_mosquera")
	assert_eq(Profile.data.selected[Catalog.DRIVERS], "fanny_mosquera")
	assert_eq(Profile.data.coins, 1000 - int(item["cost"]))


func test_leaving_the_drivers_tab_returns_to_the_selected_driver() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(MainMenu.DRIVERS_TAB)
	await wait_frames(2)
	menu.try_on_driver(Profile.catalog.find(Catalog.DRIVERS, "fanny_mosquera"))
	assert_eq(menu._drivers_preview.shown_look().driver_name, "Fanny Mosquera")
	menu.show_tab(MainMenu.DRIVERS_TAB)
	await wait_frames(2)
	assert_eq(menu._drivers_preview.shown_look().driver_name, "Wilmer Pertuz")


func test_home_shows_the_chosen_driver() -> void:
	Profile.data.coins = 5000
	Profile.buy(Catalog.DRIVERS, "yolima_uriana")
	Profile.select(Catalog.DRIVERS, "yolima_uriana")
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	var labels := menu.find_children("*", "Label", true, false)
	assert_true(labels.any(func(label: Label) -> bool: return label.text == MenuTopBar.short_name("Yolima Uriana")), "The driver pill names her")


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


func test_the_bus_card_follows_a_garage_try_on_and_returns_on_home() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(2)
	await wait_frames(2)
	var chiva := Profile.catalog.find(Catalog.BUSES, "chiva")
	menu.try_on(Catalog.BUSES, chiva)
	await wait_frames(1)
	assert_eq(menu._bus_card.name_label.text, str(chiva["name"]).to_upper())
	menu.try_on(Catalog.LIVERIES, Profile.catalog.find(Catalog.LIVERIES, "carnaval"))
	await wait_frames(1)
	assert_eq(menu._bus_card.name_label.text, str(chiva["name"]).to_upper(), "a paint keeps the tried bus")
	menu.show_tab(0)
	await wait_frames(1)
	var chosen := Profile.selected_item(Catalog.BUSES)
	assert_eq(menu._bus_card.name_label.text, str(chosen["name"]).to_upper())


func test_trying_a_decoration_looks_into_the_cab_and_a_paint_looks_back_out() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(2)
	await wait_frames(2)
	var toy := Profile.catalog.find(Catalog.DECORATIONS, "dash_perrito")
	menu.try_on(Catalog.DECORATIONS, toy)
	await wait_frames(1)
	assert_true(menu._stage.in_cab())
	assert_true(menu._stage.visual().shows_decoration("dash_perrito"))
	assert_string_contains(menu._preview_note.text, tr("Decorations go in the cab: you see them in cockpit view while driving"))
	assert_false(Profile.data.owns(Catalog.DECORATIONS, "dash_perrito"), "trying is not buying")
	menu.try_on(Catalog.LIVERIES, Profile.catalog.find(Catalog.LIVERIES, "carnaval"))
	await wait_frames(1)
	assert_eq(menu._stage.current_view(), "home")
	menu.try_on(Catalog.DECORATIONS, toy)
	menu.show_tab(0)
	await wait_frames(1)
	assert_eq(menu._stage.current_view(), "home", "Home never opens in the cab")


func test_the_card_dots_ring_a_paint_being_tried_on() -> void:
	var dots := MainMenu.card_dots("carnaval")
	var carnaval: Array = Profile.catalog.find(Catalog.LIVERIES, "carnaval")["body"]
	assert_between(int(dots["chosen"]), 0, MainMenu.CARD_DOTS - 1)
	assert_eq(dots["colours"][dots["chosen"]], Color(carnaval[0], carnaval[1], carnaval[2]))
	for item: Dictionary in Profile.catalog.items(Catalog.LIVERIES):
		Profile.data.owned[Catalog.LIVERIES].append(item["id"])
	var last: Dictionary = Profile.catalog.items(Catalog.LIVERIES).back()
	dots = MainMenu.card_dots(last["id"])
	assert_eq(dots["colours"].size(), MainMenu.CARD_DOTS)
	assert_eq(dots["chosen"], MainMenu.CARD_DOTS - 1, "a paint past the sixth takes the last place")


func test_routes_and_crew_buttons_open_a_quick_tray_over_the_stage() -> void:
	Profile.data.owned[Catalog.ROUTES].append("starter_b")
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	menu.open_tab(1)
	await wait_frames(1)
	var tray: MenuQuickTray = menu.find_child("QuickTray", true, false)
	assert_not_null(tray)
	assert_false(menu._stage.paused, "the stage shows behind the tray")
	var pick: Button = tray.find_child("Pick_starter_b", true, false)
	assert_not_null(pick)
	pick.pressed.emit()
	await wait_frames(1)
	assert_eq(Profile.data.selected[Catalog.ROUTES], "starter_b")
	assert_not_null(menu.find_child("QuickTray", true, false), "picking keeps the tray")
	(menu.find_child("MoreCard", true, false) as Button).pressed.emit()
	await wait_frames(1)
	assert_null(menu.find_child("QuickTray", true, false))
	assert_not_null(TouchScroll.first_in(menu._content), "the full list opens")
	assert_true(menu._stage.paused)
	menu.open_tab(MainMenu.DRIVERS_TAB)
	await wait_frames(1)
	tray = menu.find_child("QuickTray", true, false)
	var chosen: String = Profile.data.selected[Catalog.DRIVERS]
	assert_not_null(tray.find_child("Pick_" + chosen, true, false))


func test_the_arrows_show_a_locked_bus_with_a_padlock() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	var before: String = Profile.data.selected[Catalog.BUSES]
	assert_false(menu.showing_locked_bus())
	var seen_lock := false
	for i in MainMenu.arrow_buses().size():
		menu.cycle_bus(1)
		if menu.showing_locked_bus():
			seen_lock = true
			assert_false(Profile.data.owns(Catalog.BUSES, menu._home_bus["id"]))
	assert_true(seen_lock, "a new save has locked buses")
	assert_eq(Profile.data.selected[Catalog.BUSES], before, "a locked bus is never chosen")


func test_the_garage_has_no_bus_list() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(MainMenu.GARAGE_TAB)
	await wait_frames(2)
	for label: Label in menu._content.find_children("*", "Label", true, false):
		assert_ne(label.text, "Caimán B10", "buses are picked with the Home arrows")


func test_tapping_the_open_tab_again_goes_home() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	menu.open_tab(MainMenu.GARAGE_TAB)
	await wait_frames(1)
	assert_eq(menu._current_tab, MainMenu.GARAGE_TAB)
	menu.open_tab(MainMenu.GARAGE_TAB)
	await wait_frames(1)
	assert_eq(menu._current_tab, 0, "a second tap on the Garage goes Home")
	assert_not_null(menu.find_child("HomeDrawer", true, false))
	menu.open_tab(0)
	await wait_frames(1)
	assert_eq(menu._current_tab, 0, "Home stays Home")


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


func _arcade_button(menu: MainMenu) -> Button:
	return menu.find_child("ArcadeButton", true, false) as Button


func test_home_has_a_carrera_express_button_locked_until_its_level() -> void:
	Profile.data.grant_free_items(Profile.catalog)
	var level := int(Profile.catalog.arcade_route()["level"])
	Profile.data.xp = DriverLevel.xp_for_level(level) - 1
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	var button := _arcade_button(menu)
	assert_not_null(button, "Carrera Express is on Home")
	assert_true(button.disabled, "Locked below its level")
	assert_string_contains(button.text, str(level))
	assert_false(MainMenu.prepare_arcade(), "A locked arcade does not start")
	Profile.data.xp = DriverLevel.xp_for_level(level)
	menu.show_tab(0)
	await wait_frames(2)
	button = _arcade_button(menu)
	assert_false(button.disabled, "Open at its level")
	assert_not_null(button.find_child("NewBadge", true, false), "New until raced once")
	Profile.data.best_scores[Profile.catalog.arcade_route()["id"]] = 7
	menu.show_tab(0)
	await wait_frames(2)
	button = _arcade_button(menu)
	assert_null(button.find_child("NewBadge", true, false), "No badge once raced")
	assert_string_contains(button.text, "7")


func test_the_arcade_button_plays_the_arcade_without_changing_the_chosen_route() -> void:
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.xp = 100000
	var chosen: String = Profile.data.selected[Catalog.ROUTES]
	assert_true(MainMenu.prepare_arcade())
	assert_eq(Profile.shift_route()["id"], Profile.catalog.arcade_route()["id"], "The next shift is the arcade")
	assert_eq(Profile.data.selected[Catalog.ROUTES], chosen, "The chosen route stays")
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	assert_eq(Profile.shift_route()["id"], chosen, "Back at the menu, Start shift drives the chosen route")


func test_the_home_arcade_button_races_the_chosen_town() -> void:
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.xp = 100000
	Profile.data.town = "Alto Cafeto"
	Profile.data.best_scores["arcade"] = 9
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	var button := _arcade_button(menu)
	assert_string_contains(button.text, "Alto Cafeto", "Names the town it races")
	assert_not_null(button.find_child("NewBadge", true, false), "Cafeto's is new though Marisol's was raced")
	assert_true(MainMenu.prepare_arcade())
	assert_eq(Profile.shift_route()["id"], "arcade_cafeto")
	Profile.route_override = ""
	Profile.data.town = "Puerto Marisol"
	assert_true(MainMenu.prepare_arcade())
	assert_eq(Profile.shift_route()["id"], "arcade")
	Profile.route_override = ""


func test_the_routes_tab_leaves_the_arcade_to_its_home_button() -> void:
	Profile.data.grant_free_items(Profile.catalog)
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(1)
	await wait_frames(2)
	var labels := menu._content.find_children("*", "Label", true, false)
	for label: Label in labels:
		assert_false(label.text.contains("Carrera Express"), "Not listed with the routes")


func test_the_arcade_button_text_fits_in_both_languages() -> void:
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.xp = 100000
	Profile.data.best_scores[Profile.catalog.arcade_route()["id"]] = 188
	var was := GameSettings.language
	for width: int in [1280, 1560]:
		for language: String in ["es_CO", "en"]:
			GameSettings.language = language
			var screen := SubViewport.new()
			screen.size = Vector2i(width, 720)
			add_child_autofree(screen)
			var menu: MainMenu = MENU.instantiate()
			screen.add_child(menu)
			await wait_frames(3)
			var button := _arcade_button(menu)
			assert_lte(button.get_combined_minimum_size().x, button.size.x + 0.5, "%s at %d fits" % [language, width])
			assert_true(Rect2(Vector2.ZERO, Vector2(screen.size)).encloses(button.get_global_rect()), "%s at %d on screen" % [language, width])
			screen.queue_free()
	GameSettings.language = was
	Profile.data.best_scores.clear()


func test_town_buttons_text_fits_in_both_languages() -> void:
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.xp = 0 # Locked Alto Cafeto
	var was := GameSettings.language
	for width: int in [1280, 1560, 1600]:
		for language: String in ["es_CO", "en"]:
			GameSettings.language = language
			var screen := SubViewport.new()
			screen.size = Vector2i(width, 720)
			add_child_autofree(screen)
			var menu: MainMenu = MENU.instantiate()
			screen.add_child(menu)
			menu.show_tab(1)
			await wait_frames(3)
			var selector: HBoxContainer = menu.find_child("TownSelector", true, false)
			assert_not_null(selector, "TownSelector exists at %d in %s" % [width, language])
			var pm_btn: Button = selector.find_child("TownPuertoMarisol", true, false)
			var ac_btn: Button = selector.find_child("TownAltoCafeto", true, false)
			assert_not_null(pm_btn)
			assert_not_null(ac_btn)
			assert_true(Rect2(Vector2.ZERO, Vector2(screen.size)).encloses(pm_btn.get_global_rect()))
			assert_true(Rect2(Vector2.ZERO, Vector2(screen.size)).encloses(ac_btn.get_global_rect()))
			var badge: Label = ac_btn.find_child("LockBadge", true, false)
			assert_not_null(badge)
			assert_true(ac_btn.get_global_rect().encloses(badge.get_global_rect()), "Badge inside button at %d in %s" % [width, language])
			screen.queue_free()
	GameSettings.language = was


func test_the_side_arrows_change_the_chosen_bus_and_the_stage() -> void:
	Profile.data.coins = 100000
	Profile.data.xp = 100000
	Profile.buy(Catalog.BUSES, "midi_10")
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	var before: String = Profile.data.selected[Catalog.BUSES]
	menu.cycle_bus(1)
	assert_ne(Profile.data.selected[Catalog.BUSES], before, "The arrow selects the next owned bus")
	assert_eq(menu._stage.shown_spec().resource_path, "", "The stage shows a fresh copy")
	menu.cycle_bus(-1)
	assert_eq(Profile.data.selected[Catalog.BUSES], before, "And back")


func test_the_stage_stops_rendering_behind_a_full_sheet() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	assert_false(menu._stage.paused, "Home shows the stage")
	menu.show_tab(1)
	assert_true(menu._stage.paused, "Routes covers it")
	menu.show_tab(MainMenu.GARAGE_TAB)
	assert_false(menu._stage.paused, "The garage tries buses on it")
	menu.show_tab(0)
	assert_false(menu._stage.paused)


func test_the_gear_opens_settings_and_the_sound_button_mutes() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	menu._on_icon_pressed("gear")
	assert_true(menu._content.get_child(0) is SettingsPanel)
	var volume := GameSettings.sound_volume
	menu.toggle_mute()
	assert_eq(GameSettings.sound_volume, 0.0)
	menu.toggle_mute()
	assert_eq(GameSettings.sound_volume, volume)


func test_every_home_button_is_big_enough_for_a_thumb() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(3)
	for button: Button in menu.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			assert_gte(minf(button.size.x, button.size.y), 48.0, button.name)
