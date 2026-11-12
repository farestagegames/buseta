extends GutTest

var network: RoadNetwork
var runner: RouteRunner


func before_each() -> void:
	network = RoadNetwork.new()
	network.add_node("a", Vector2(0.0, 0.0), "terminal", 11.0, 0.0)
	network.add_node("b", Vector2(200.0, 0.0), "junction", 11.0, 0.0)
	network.add_node("c", Vector2(200.0, 200.0), "roundabout", 20.0, 9.0)
	network.add_node("d", Vector2(0.0, 200.0), "junction", 11.0, 0.0)
	var no_via: Array[Vector2] = []
	network.add_road("r1", "a", "b", no_via)
	network.add_road("r2", "b", "c", no_via)
	network.add_road("r3", "c", "d", no_via)
	runner = RouteRunner.build({
		"name": "Test",
		"start": {"road": "r1", "along": 20.0, "lateral": 1.9, "dir": 1},
		"legs": [{"road": "r1", "dir": 1}, {"road": "r2", "dir": 1}, {"road": "r3", "dir": 1}],
		"stops": [
			{"name": "One", "road": "r1", "along": 100.0, "dir": 1, "waiting": 3},
			{"name": "Two", "road": "r2", "along": 100.0, "dir": 1, "waiting": 2},
			{"name": "End", "road": "r3", "along": 100.0, "dir": 1, "final": true},
		],
	}, network)


func test_route_starts_at_the_first_stop() -> void:
	assert_eq(runner.current_stop().stop_name, "One")
	assert_almost_eq(runner.distance_to_next_stop(), 80.0, 1.0)


func test_progress_follows_the_bus() -> void:
	runner.update_position(Vector2(60.0, 2.0))
	assert_almost_eq(runner.distance_to_next_stop(), 40.0, 1.0)


func test_progress_does_not_jump_backward() -> void:
	runner.update_position(Vector2(60.0, 2.0))
	runner.update_position(Vector2(50.0, 2.0))
	assert_almost_eq(runner.progress, 60.0, 1.0)


func test_stops_advance_in_order_and_finish() -> void:
	runner.advance_stop()
	assert_eq(runner.current_stop().stop_name, "Two")
	assert_almost_eq(runner.current_stop().route_distance, 300.0, 1.0)
	runner.advance_stop()
	assert_true(runner.current_stop().is_final)
	runner.advance_stop()
	assert_true(runner.is_finished())


func test_right_turn_is_announced_near_the_junction() -> void:
	assert_eq(runner.upcoming_turn(), "")
	runner.update_position(Vector2(150.0, 2.0))
	assert_eq(runner.upcoming_turn(), "Turn right")


func test_roundabout_is_announced() -> void:
	for x in [100.0, 190.0]:
		runner.update_position(Vector2(x, 2.0))
	for z in [40.0, 80.0, 150.0]:
		runner.update_position(Vector2(202.0, z))
	assert_string_starts_with(runner.upcoming_turn(), "Roundabout")


func test_recovery_puts_the_bus_in_the_right_lane_on_the_route() -> void:
	runner.update_position(Vector2(60.0, 9.0))
	var pose := runner.recovery_pose()
	assert_almost_eq((pose["position"] as Vector2).y, RoadNetwork.LANE_WIDTH / 2.0, 0.01)
	assert_almost_eq(float(pose["heading"]), -PI / 2.0, 0.01)


func test_stop_sits_in_a_bay_right_of_the_lane() -> void:
	var stop := runner.current_stop()
	assert_gt(stop.position.y, RoadNetwork.ROAD_HALF_WIDTH)


func test_bus_lined_up_in_the_bay_is_aligned() -> void:
	var stop := runner.current_stop()
	assert_true(stop.is_aligned(stop.position, stop.heading))
	assert_eq(stop.accuracy(stop.position), 1.0)


func test_bus_too_far_out_is_not_aligned() -> void:
	var stop := runner.current_stop()
	assert_false(stop.is_aligned(stop.position - Vector2(0.0, 2.5), stop.heading))


func test_bus_too_far_along_is_not_aligned() -> void:
	var stop := runner.current_stop()
	assert_false(stop.is_aligned(stop.position + stop.forward() * 7.0, stop.heading))


func test_crooked_bus_is_not_aligned() -> void:
	var stop := runner.current_stop()
	assert_false(stop.is_aligned(stop.position, stop.heading + 0.6))


func test_stopping_near_the_middle_counts_as_perfect() -> void:
	var stop := runner.current_stop()
	assert_eq(stop.accuracy(stop.position + stop.forward() * 1.2), 1.0)


func test_accuracy_falls_gently_to_a_fair_floor() -> void:
	var stop := runner.current_stop()
	var right := Vector2(-stop.forward().y, stop.forward().x)
	assert_between(stop.accuracy(stop.position + stop.forward() * 3.0), 0.75, 0.9)
	assert_almost_eq(stop.accuracy(stop.position + right * RouteStop.LATERAL_TOLERANCE), RouteStop.EDGE_ACCURACY, 0.01)


func test_bump_warning_shows_shortly_before_it() -> void:
	runner.add_hazard(Vector2(100.0, 0.0))
	runner.update_position(Vector2(20.0, 2.0))
	assert_false(runner.hazard_ahead())
	runner.update_position(Vector2(60.0, 2.0))
	assert_true(runner.hazard_ahead())
	runner.update_position(Vector2(110.0, 2.0))
	assert_false(runner.hazard_ahead())


func test_stop_counts_as_passed_only_when_well_beyond_it() -> void:
	var stop := runner.current_stop()
	assert_false(stop.is_passed(stop.position + stop.forward() * 10.0))
	assert_true(stop.is_passed(stop.position + stop.forward() * 30.0))


func test_passengers_get_off_at_their_stop_only() -> void:
	var ledger := PassengerLedger.new(1, 5)
	ledger.onboard = [1, 3, 3] as Array[int]
	assert_eq(ledger.alight_at(1), 1)
	assert_eq(ledger.count(), 2)


func test_boarding_passengers_pick_a_later_stop() -> void:
	var ledger := PassengerLedger.new(7, 5)
	for i in 20:
		ledger.board_one(2)
	for destination in ledger.onboard:
		assert_between(destination, 3, 5)


func test_bus_capacity_limits_boarding() -> void:
	var ledger := PassengerLedger.new(7, 5)
	for i in PassengerLedger.CAPACITY + 5:
		ledger.board_one(0)
	assert_eq(ledger.count(), PassengerLedger.CAPACITY)
	assert_eq(ledger.boardable(4), 0)


func test_ledger_is_repeatable_with_the_same_seed() -> void:
	var a := PassengerLedger.new(9, 6)
	var b := PassengerLedger.new(9, 6)
	for i in 10:
		a.board_one(0)
		b.board_one(0)
	assert_eq(a.onboard, b.onboard)


func test_session_boards_while_others_get_off() -> void:
	var order: Array[String] = []
	var session := StopSession.new(4, 2)
	session.passenger_alighted.connect(func() -> void: order.append("off"))
	session.passenger_boarded.connect(func() -> void: order.append("on"))
	for i in 600:
		session.update(1.0 / 60.0, true)
	assert_eq(order.count("off"), 4)
	assert_eq(order.count("on"), 2)
	assert_lt(order.find("on"), order.rfind("off"), "Someone gets on before the last one is off")
	assert_true(session.is_complete())


func test_a_busy_stop_is_quicker_than_one_side_after_the_other() -> void:
	var session := StopSession.new(4, 4)
	var seconds := 0.0
	while not session.is_complete() and seconds < 60.0:
		session.update(1.0 / 60.0, true)
		seconds += 1.0 / 60.0
	var one_after_other := 4 * StopSession.ALIGHT_SECONDS + StopSession.QUEUE_SECONDS + 3 * StopSession.BOARD_SECONDS
	assert_lt(seconds, one_after_other - 2.0)


func test_session_waits_for_open_doors() -> void:
	var session := StopSession.new(2, 0)
	for i in 600:
		session.update(1.0 / 60.0, false)
	assert_eq(session.alighting_left, 2)


func test_empty_stop_is_complete_at_once() -> void:
	assert_true(StopSession.new(0, 0).is_complete())


func test_boarding_is_paced() -> void:
	var boarded := [0]
	var session := StopSession.new(0, 4)
	session.passenger_boarded.connect(func() -> void: boarded[0] += 1)
	for i in 240:
		session.update(1.0 / 60.0, true)
	assert_between(int(boarded[0]), 1, 3, "Four people should need over four seconds")


func test_city_data_files_load_and_every_stop_is_on_the_route() -> void:
	var route_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/packs/colombia/routes/route_01.json"))
	var map_data: Dictionary = MapLoader.read_map_of(route_data)
	var city := RoadNetwork.from_data(map_data)
	var route := RouteRunner.build(route_data, city)
	assert_between((route_data["stops"] as Array).size(), 6, 9, "Brief asks for 6 to 8 named stops plus the depot")
	var last := -1.0
	for stop in route.stops:
		assert_gt(stop.route_distance, last, "%s should be after the previous stop" % stop.stop_name)
		last = stop.route_distance
	assert_gt(route.distances[route.distances.size() - 1], 1800.0, "Route should be a proper drive")


func test_city_steepest_road_is_drivable() -> void:
	var route_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/packs/colombia/routes/route_01.json"))
	var map_data: Dictionary = MapLoader.read_map_of(route_data)
	var city := RoadNetwork.from_data(map_data)
	var ground := GroundSurface.new()
	for hill: Dictionary in map_data["hills"]:
		ground.add_hill(Vector2(hill["x"], hill["z"]), hill["radius"], hill["height"])
	var route := RouteRunner.build(route_data, city)
	var steepest := 0.0
	for i in route.polyline.size() - 1:
		var run := route.polyline[i].distance_to(route.polyline[i + 1])
		var rise := absf(ground.terrain_height(route.polyline[i + 1]) - ground.terrain_height(route.polyline[i]))
		steepest = maxf(steepest, rise / run)
	assert_lt(steepest, 0.1, "Route should stay under a 10 percent grade")
	assert_gt(steepest, 0.03, "Hills should be noticeable")


func test_route_has_no_corners_tighter_than_a_bus_can_take() -> void:
	var route_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/packs/colombia/routes/route_01.json"))
	var map_data: Dictionary = MapLoader.read_map_of(route_data)
	var city := RoadNetwork.from_data(map_data)
	var tightest := INF
	for road: Dictionary in city.roads.values():
		var points: PackedVector2Array = road["points"]
		var clear_of_nodes := func(point: Vector2) -> bool:
			return point.distance_to(city.nodes[road["from"]]["position"]) > 30.0 \
				and point.distance_to(city.nodes[road["to"]]["position"]) > 30.0
		for i in range(4, points.size() - 4):
			if not clear_of_nodes.call(points[i]):
				continue
			var before := points[i] - points[i - 4]
			var after := points[i + 4] - points[i]
			var turn := absf(before.angle_to(after))
			if turn > 0.01:
				tightest = minf(tightest, (before.length() + after.length()) / 2.0 / turn)
	assert_gt(tightest, 22.0, "Bends should take a bus at about 25 km/h")


func test_people_too_close_are_pushed_apart() -> void:
	var moves := PassengerCrowd.separation(Vector2.ZERO, Vector2(0.2, 0.0), 0.6)
	assert_lt(moves[0].x, 0.0)
	assert_gt(moves[1].x, 0.0)
	var apart := (Vector2(0.2, 0.0) + moves[1]).distance_to(moves[0])
	assert_almost_eq(apart, 0.6, 0.001)


func test_people_with_space_are_left_alone() -> void:
	var moves := PassengerCrowd.separation(Vector2.ZERO, Vector2(2.0, 0.0), 0.6)
	assert_eq(moves[0], Vector2.ZERO)


func test_two_people_in_one_spot_still_separate() -> void:
	var moves := PassengerCrowd.separation(Vector2.ONE, Vector2.ONE, 0.6)
	assert_ne(moves[0], moves[1])


func test_queue_starts_with_whoever_is_nearest_the_door() -> void:
	var spots: Array[Vector2] = [Vector2(5.0, 0.0), Vector2(1.0, 0.0), Vector2(3.0, 0.0)]
	assert_eq(PassengerCrowd.queue_order(Vector2.ZERO, spots), [1, 2, 0] as Array[int])
