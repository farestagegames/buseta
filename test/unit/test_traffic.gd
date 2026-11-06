extends GutTest

const DT := 1.0 / 60.0

var graph: LaneGraph


func _city() -> Dictionary:
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/routes/route_01.json"))
	return JSON.parse_string(FileAccess.get_file_as_string(route["map"]))


func before_each() -> void:
	var map_data := _city()
	graph = LaneGraph.build(RoadNetwork.from_data(map_data), map_data)


func test_groups_alternate_and_never_both_green() -> void:
	var plan := TrafficLightPlan.new()
	var time := 0.0
	var seen_green := [false, false]
	while time < TrafficLightPlan.CYCLE * 2.0:
		var first := plan.state(0, time)
		var second := plan.state(1, time)
		assert_false(first != TrafficLightPlan.Light.RED and second != TrafficLightPlan.Light.RED, "Conflict at %.1f" % time)
		if first == TrafficLightPlan.Light.GREEN:
			seen_green[0] = true
		if second == TrafficLightPlan.Light.GREEN:
			seen_green[1] = true
		time += 0.25
	assert_true(seen_green[0] and seen_green[1])


func test_amber_follows_green() -> void:
	var plan := TrafficLightPlan.new()
	assert_eq(plan.state(0, 1.0), TrafficLightPlan.Light.GREEN)
	assert_eq(plan.state(0, TrafficLightPlan.GREEN_SECONDS + 1.0), TrafficLightPlan.Light.AMBER)
	assert_eq(plan.state(0, TrafficLightPlan.GREEN_SECONDS + TrafficLightPlan.AMBER_SECONDS + 1.0), TrafficLightPlan.Light.RED)


func test_offset_shifts_the_cycle() -> void:
	var plan := TrafficLightPlan.new(TrafficLightPlan.CYCLE / 2.0)
	assert_eq(plan.state(1, 1.0), TrafficLightPlan.Light.GREEN)


func test_every_road_lane_leads_somewhere() -> void:
	for lane in graph.lanes:
		assert_false(lane.next.is_empty(), "Lane on %s to %s has nowhere to go" % [lane.road, lane.end_node])


func test_links_join_their_lanes_without_gaps() -> void:
	for lane in graph.lanes:
		if lane.is_link:
			var entry: TrafficLane = graph.lanes[lane.from_lane]
			var exit: TrafficLane = graph.lanes[lane.next[0]]
			assert_almost_eq(lane.points[0].distance_to(entry.points[entry.points.size() - 1]), 0.0, 0.01)
			assert_almost_eq(lane.points[lane.points.size() - 1].distance_to(exit.points[0]), 0.0, 0.01)


func test_traffic_stays_on_the_road() -> void:
	var city := graph.network
	for lane in graph.lanes:
		for point in lane.points:
			assert_lte(city.edge_distance(point), 0.0, "Off road at %s" % point)


func test_traffic_keeps_right() -> void:
	var lane: TrafficLane = null
	for candidate in graph.lanes:
		if candidate.road == "mill_lane" and candidate.end_node == "b":
			lane = candidate
	assert_gt(lane.point_at(50.0).y, 70.0, "Heading east, the right side is +Z")


func test_ring_goes_round_the_roundabout_anticlockwise() -> void:
	var links: Array = graph.links_at["c"]
	assert_gt(links.size(), 0)
	var centre: Vector2 = graph.network.nodes["c"]["position"]
	for index: int in links:
		var link: TrafficLane = graph.lanes[index]
		for i in range(1, link.points.size() - 1):
			assert_gt(link.points[i].distance_to(centre), 9.5, "Must miss the island")


func test_left_and_right_are_told_apart() -> void:
	var seen := {}
	for lane in graph.lanes:
		if lane.is_link and lane.node == "a":
			seen[lane.turn] = true
	assert_true(seen.has(-1) or seen.has(1))


func test_junctions_with_three_roads_have_signals() -> void:
	var nodes := graph.signal_nodes()
	assert_true(nodes.has("b"))
	assert_false(nodes.has("c"), "Roundabouts do not have signals")


func test_car_accelerates_on_a_clear_road_to_cruise() -> void:
	var car := TrafficAgent.new(0, 0.0, 11.0)
	for i in 1200:
		car.drive(11.0, INF, 0.0, DT)
	assert_almost_eq(car.speed, 11.0, 0.3)


func test_car_stops_before_a_red_line() -> void:
	var car := TrafficAgent.new(0, 0.0, 11.0)
	car.speed = 11.0
	var line := 60.0
	for i in 1200:
		car.drive(11.0, line - car.distance, 0.0, DT)
	assert_lt(car.speed, 0.1)
	assert_lt(car.distance, line)
	assert_gt(car.distance, line - 6.0)


func test_car_follows_a_slower_leader_without_touching() -> void:
	var car := TrafficAgent.new(0, 0.0, 11.0)
	car.speed = 11.0
	var leader := 40.0
	var smallest := INF
	for i in 1800:
		leader += 4.0 * DT
		var gap := leader - car.distance - TrafficAgent.CAR_LENGTH
		smallest = minf(smallest, gap)
		car.drive(11.0, gap, 4.0, DT)
	assert_gt(smallest, 1.0)
	assert_almost_eq(car.speed, 4.0, 0.3)


func test_hit_car_stops_then_recovers() -> void:
	var car := TrafficAgent.new(0, 0.0, 11.0)
	car.speed = 8.0
	car.hit_by_bus(Vector2(6.0, 0.0))
	for i in 120:
		car.drive(11.0, INF, 0.0, DT)
	assert_lt(car.speed, 0.5, "Stopped after the crash")
	assert_gt(car.nudge.x, 0.5, "Shoved aside")
	for i in 600:
		car.drive(11.0, INF, 0.0, DT)
	assert_gt(car.speed, 5.0, "Drives on later")


func test_car_sees_the_bus_ahead_in_its_lane() -> void:
	var spec := BusSpec.new()
	var gap := BusFootprint.gap_ahead(Vector2(0.0, -20.0), 0.0, spec, Vector2.ZERO, Vector2(0.0, -1.0), 2.2, 0.9)
	assert_almost_eq(gap, 20.0 - 3.3 - 2.2 + 0.0 - 0.0 - 0.0 + 2.7 - 2.7, 3.5)


func test_car_ignores_a_bus_in_the_other_lane_or_behind() -> void:
	var spec := BusSpec.new()
	assert_eq(BusFootprint.gap_ahead(Vector2(5.0, -20.0), 0.0, spec, Vector2.ZERO, Vector2(0.0, -1.0), 2.2, 0.9), INF)
	assert_eq(BusFootprint.gap_ahead(Vector2(0.0, 20.0), 0.0, spec, Vector2.ZERO, Vector2(0.0, -1.0), 2.2, 0.9), INF)


func test_car_sees_a_bus_parked_across_its_lane() -> void:
	var spec := BusSpec.new()
	var gap := BusFootprint.gap_ahead(Vector2(-6.0, -20.0), -PI / 2.0, spec, Vector2.ZERO, Vector2(0.0, -1.0), 2.2, 0.9)
	assert_lt(gap, 20.0)


func test_speed_limit_comes_from_the_map() -> void:
	var city := graph.network
	var spot: Vector2 = city.sample("mill_lane", 100.0)["position"]
	assert_eq(city.speed_limit_at(spot), 30.0)
	var other: Vector2 = city.sample("market_street", 100.0)["position"]
	assert_eq(city.speed_limit_at(other), 50.0)


func test_oncoming_bus_on_a_bend_does_not_stop_a_car() -> void:
	var spec := BusSpec.new()
	var heading := PI - 0.3
	var bus_rear := Vector2(-4.5, -24.0)
	var gap := BusFootprint.gap_ahead(bus_rear, heading, spec, Vector2.ZERO, Vector2(0.0, -1.0), 2.2, 0.9)
	assert_eq(gap, INF)


func test_oncoming_bus_in_the_cars_lane_does_stop_it() -> void:
	var spec := BusSpec.new()
	var gap := BusFootprint.gap_ahead(Vector2(0.0, -30.0), PI, spec, Vector2.ZERO, Vector2(0.0, -1.0), 2.2, 0.9)
	assert_lt(gap, 30.0)
