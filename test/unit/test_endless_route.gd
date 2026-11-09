extends GutTest
## The endless route: planned road that keeps growing, hails along it, a paced
## timetable, and passengers who only ride a few stops.

var network: RoadNetwork
var map_data: Dictionary
var route_data: Dictionary


func before_all() -> void:
	route_data = MapLoader.read_json(Profile.catalog.find(Catalog.ROUTES, "libre")["file"])
	map_data = MapLoader.read_map_of(route_data)
	network = RoadNetwork.from_data(map_data, Country.pack.traffic_side, Country.pack.default_speed_limit())


func _end_node(leg: Dictionary) -> String:
	var road: Dictionary = network.roads[leg["road"]]
	return road["to"] if int(leg["dir"]) > 0 else road["from"]


func _start_node(leg: Dictionary) -> String:
	var road: Dictionary = network.roads[leg["road"]]
	return road["from"] if int(leg["dir"]) > 0 else road["to"]


func test_the_planned_road_joins_up_and_avoids_the_busway() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 3
	var legs := EndlessPlanner.walk(network, "depot_road", 1, 40, random)
	assert_eq(legs.size(), 40)
	var previous := {"road": "depot_road", "dir": 1}
	for leg: Dictionary in legs:
		assert_eq(_start_node(leg), _end_node(previous), "Each road starts where the last ended")
		assert_false(network.roads[leg["road"]].get("busway", false), "Never on the busway")
		previous = leg


func test_the_same_seed_plans_the_same_road() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 11
	var b := RandomNumberGenerator.new()
	b.seed = 11
	assert_eq(EndlessPlanner.walk(network, "depot_road", 1, 12, a), EndlessPlanner.walk(network, "depot_road", 1, 12, b))


func test_the_endless_route_starts_with_hails_and_a_paced_timetable() -> void:
	var runner := RouteRunner.build(route_data, network, 5, map_data)
	assert_true(runner.endless)
	assert_gt(runner.stops.size(), 5)
	assert_false(runner.stops.any(func(stop: RouteStop) -> bool: return stop.is_final), "No last stop")
	for i in range(1, runner.stops.size()):
		assert_gt(runner.stops[i].route_distance, runner.stops[i - 1].route_distance)
		assert_gt(runner.stops[i].due, runner.stops[i - 1].due)


func test_extending_adds_road_turns_and_stops_after_the_old_ones() -> void:
	var runner := RouteRunner.build(route_data, network, 5, map_data)
	var stops_before := runner.stops.size()
	var length_before := runner.distances[runner.distances.size() - 1]
	var turns_before := runner.turns.size()
	var last_due := runner.stops[stops_before - 1].due
	var random := RandomNumberGenerator.new()
	random.seed = 8
	var legs := EndlessPlanner.walk(network, runner.last_leg["road"], int(runner.last_leg["dir"]), 6, random)
	runner.extend(legs, network, EndlessPlanner.hails(legs, route_data["hail"], network, 77, map_data))
	assert_gt(runner.stops.size(), stops_before)
	assert_gt(runner.distances[runner.distances.size() - 1], length_before)
	assert_gt(runner.turns.size(), turns_before, "The old end's turn is now known, and new ones added")
	assert_gt(runner.stops[stops_before].route_distance, runner.stops[stops_before - 1].route_distance)
	assert_gt(runner.stops[stops_before].due, last_due)


func test_the_map_line_only_shows_the_road_ahead() -> void:
	var runner := RouteRunner.build(route_data, network, 5, map_data)
	var ahead := runner.line_ahead(300.0)
	assert_gt(ahead.size(), 1)
	assert_lt(ahead.size(), runner.polyline.size())


func test_endless_passengers_ride_only_a_few_stops() -> void:
	var ledger := PassengerLedger.new(1, 1 << 30)
	ledger.max_ride = 8
	for i in 200:
		ledger.board_one(10)
	for destination in ledger.onboard:
		assert_between(destination, 11, 18)


func test_the_endless_route_validates() -> void:
	assert_eq(Country.pack.validate(), [] as Array[String])
