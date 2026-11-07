extends GutTest
## A real shift in the left-hand test country, using the game's own scene.

const CITY := preload("res://scenes/main/city_shift.tscn")
const TESTLAND := "res://test/fixtures/packs/testland/pack.json"
const COLOMBIA := "res://data/packs/colombia/pack.json"

var scene: CityShift
var bus: BusController
var system: RouteSystem


func before_each() -> void:
	Country.use_pack(TESTLAND)
	Profile.load_from("user://test_save_left.json")
	Profile.data = PlayerProfile.new()
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.intro_done = true
	Profile.data.selected[Catalog.ROUTES] = "test_loop"
	Profile.data.selected[Catalog.BUSES] = "test_bus"
	scene = CITY.instantiate()
	add_child_autofree(scene)
	bus = scene.get_node("Bus")
	system = scene.get_node("RouteSystem")
	await wait_physics_frames(2)


func after_each() -> void:
	Country.use_pack(COLOMBIA)


func after_all() -> void:
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func test_bus_has_its_door_on_the_left() -> void:
	assert_eq(bus.spec.door_side, -1)
	assert_gt(bus.spec.driver_seat_x, 0.0)


func test_traffic_keeps_left() -> void:
	var graph: LaneGraph = scene.traffic_for_tools().graph
	assert_eq(graph.network.traffic_side, -1)
	var lane: TrafficLane = graph.lanes[0]
	var forward := lane.forward_at(lane.length / 2.0)
	var middle: Vector2 = lane.point_at(lane.length / 2.0)
	var road: Dictionary = graph.network.roads[lane.road]
	var nearest := INF
	var kerb := 0.0
	var points: PackedVector2Array = road["points"]
	for point in points:
		if point.distance_to(middle) < nearest:
			nearest = point.distance_to(middle)
			kerb = (middle - point).dot(Vector2(-forward.y, forward.x))
	assert_lt(kerb, 0.0, "The lane sits to the left of the road's centre")


func test_passengers_board_through_the_left_door_from_the_pavement() -> void:
	var stop: RouteStop = scene.route.stops[0]
	GameEvents.bus_relocate_requested.emit(stop.position + stop.forward() * bus.spec.body_centre_z(), stop.heading)
	await wait_physics_frames(3)
	var crowd: PassengerCrowd = scene.get_node("Crowd")
	assert_eq(crowd.waiting.size(), stop.waiting)
	var forward := stop.forward()
	var left := Vector2(forward.y, -forward.x)
	for walker in crowd.waiting:
		var offset := Vector2(walker.position.x, walker.position.z) - stop.position
		assert_gt(offset.dot(left), 0.0, "People wait on the kerb side")
	GameEvents.door_toggle_requested.emit()
	await wait_physics_frames(100)
	assert_not_null(system.session, "Parking in a left-hand bay starts the stop")
	for i in 40:
		await wait_physics_frames(30)
		if system.session.is_complete():
			break
	assert_true(system.session.is_complete())
	assert_eq(system.ledger.count(), stop.waiting)


func test_speed_limit_shows_in_the_packs_unit() -> void:
	assert_eq(Country.pack.speed_unit(), "mph")
