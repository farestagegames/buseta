extends GutTest
## The menus and what they change in a shift.

const MENU := preload("res://scenes/main/main_menu.tscn")
const CITY := preload("res://scenes/main/city_shift.tscn")


func before_each() -> void:
	Profile.load_from("user://test_save_menu.json")
	Profile.data = PlayerProfile.new()


func after_all() -> void:
	Profile.data = PlayerProfile.new()
	Profile.load_from("user://test_save_scene.json")


func test_every_menu_tab_opens() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	for i in 5:
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
