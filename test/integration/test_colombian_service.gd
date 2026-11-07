extends GutTest
## Flagging the bus down, vendors, fares and the rapid-transit line in a real shift.

const CITY := preload("res://scenes/main/city_shift.tscn")

var scene: CityShift
var bus: BusController
var crowd: PassengerCrowd
var system: RouteSystem
var keeper: ScoreKeeper


func _start(route: String) -> void:
	Profile.load_from("user://test_save_service.json")
	Profile.data = PlayerProfile.new()
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.intro_done = true
	Cheats.unlock_everything(Profile.data, Profile.catalog)
	Profile.data.select(Catalog.ROUTES, route)
	scene = CITY.instantiate()
	add_child_autofree(scene)
	bus = scene.get_node("Bus")
	crowd = scene.get_node("Crowd")
	system = scene.get_node("RouteSystem")
	keeper = scene.get_node("ScoreKeeper")
	await wait_physics_frames(2)


func after_all() -> void:
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func _park_at(stop: RouteStop) -> void:
	GameEvents.bus_relocate_requested.emit(stop.position + stop.forward() * bus.spec.body_centre_z(), stop.heading)
	await wait_physics_frames(3)


func _wait_until(done: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0 and not done.call():
		await wait_physics_frames(6)
		left -= 0.1
	return done.call()


func test_people_wave_at_the_bus_and_board_with_no_bay_in_sight() -> void:
	await _start("route_01")
	var stop: RouteStop = scene.route.stops[0]
	await _park_at(stop)
	assert_gt(crowd.waiting.size(), 0)
	assert_true(crowd.waiting[0].waving)
	GameEvents.door_toggle_requested.emit()
	assert_true(await _wait_until(func() -> bool: return system.session != null, 5.0), "Doors open beside them")
	assert_false(crowd.waiting[0].waving, "They stop waving")


func test_fares_are_counted_in_pesos() -> void:
	await _start("route_01")
	var stop: RouteStop = scene.route.stops[0]
	await _park_at(stop)
	GameEvents.door_toggle_requested.emit()
	await _wait_until(func() -> bool: return system.session != null and system.session.is_complete(), 30.0)
	assert_eq(system._fares, stop.waiting * int(Country.pack.data["currency"]["fare"]))


func test_people_on_board_ask_for_their_stop() -> void:
	await _start("route_01")
	watch_signals(GameEvents)
	system.ledger.onboard = [1]
	system.runner.stop_index = 0
	system._next_stop()
	assert_signal_emitted(GameEvents, "stop_requested")


func test_going_past_a_requested_stop_costs_points() -> void:
	await _start("route_01")
	system.ledger.onboard = [0]
	var stop: RouteStop = scene.route.stops[0]
	GameEvents.bus_relocate_requested.emit(stop.position + stop.forward() * 35.0, stop.heading)
	await wait_physics_frames(3)
	assert_eq(int(keeper.score.counts["ignored_requests"]), 1)
	assert_eq(system.ledger.wanting_off(1), 1, "They ride on to the next stop")


func test_a_vendor_boards_works_the_aisle_and_leaves() -> void:
	await _start("route_01")
	var stop: RouteStop = scene.route.stops[2]
	stop.vendor = true
	system.runner.stop_index = 2
	await _park_at(stop)
	assert_not_null(crowd.vendor_waiting)
	GameEvents.door_toggle_requested.emit()
	assert_true(await _wait_until(func() -> bool: return not crowd.selling.is_empty(), 40.0), "The vendor gets to work")
	assert_eq(int(keeper.score.counts["vendors"]), 1)
	GameEvents.vendor_left.emit()
	assert_true(crowd.selling.is_empty())
	assert_eq(crowd.getting_off.size(), 1)


func test_vendor_leaves_after_two_more_stops() -> void:
	await _start("route_01")
	watch_signals(GameEvents)
	system._vendor_stops_left = RouteSystem.VENDOR_STOPS + 1
	system._next_stop()
	system._next_stop()
	assert_signal_not_emitted(GameEvents, "vendor_left")
	system._next_stop()
	assert_signal_emitted(GameEvents, "vendor_left")


func test_rapid_transit_route_always_uses_the_articulated_bus() -> void:
	await _start("troncal")
	assert_true(bus.spec.is_articulated())
	assert_eq(scene.route.stops[0].kind, RouteStop.Kind.STATION)


func test_station_boarding_needs_no_stop_at_the_ticket_machine() -> void:
	await _start("troncal")
	var payments := [0]
	var count := func() -> void: payments[0] += 1
	GameEvents.passenger_paid.connect(count)
	var stop: RouteStop = scene.route.stops[0]
	await _park_at(stop)
	GameEvents.door_toggle_requested.emit()
	await _wait_until(func() -> bool: return system.session != null and system.session.is_complete() and crowd.aboard.is_empty(), 30.0)
	GameEvents.passenger_paid.disconnect(count)
	assert_eq(payments[0], 0, "They paid at the turnstile")
	assert_gt(system._fares, 0)


func test_rear_section_of_the_articulated_bus_is_drawn_and_solid() -> void:
	await _start("troncal")
	assert_not_null(bus._trailer_shape)
	var visual: BusVisual = bus.get_node("Visual")
	assert_not_null(visual._trailer)


func test_report_shows_fares() -> void:
	await _start("route_01")
	var report := [{}]
	var keep := func(data: Dictionary) -> void: report[0] = data
	GameEvents.shift_report_ready.connect(keep)
	system._fares = 58
	GameEvents.finish_shift_requested.emit()
	await wait_frames(2)
	GameEvents.shift_report_ready.disconnect(keep)
	assert_string_contains(report[0]["details"], Country.pack.money(58))
