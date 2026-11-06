extends GutTest

var network: RoadNetwork


func before_each() -> void:
	network = RoadNetwork.new()
	network.add_node("a", Vector2(0.0, 0.0), "junction", 11.0, 0.0)
	network.add_node("b", Vector2(100.0, 0.0), "roundabout", 20.0, 9.0)
	network.add_node("c", Vector2(100.0, -100.0), "junction", 11.0, 0.0)
	var no_via: Array[Vector2] = []
	network.add_road("east", "a", "b", no_via)
	network.add_road("north", "b", "c", no_via)


func test_road_length_is_measured() -> void:
	assert_almost_eq(float(network.roads["east"]["length"]), 100.0, 0.01)


func test_sample_finds_the_right_lane() -> void:
	var lane := RoadNetwork.LANE_WIDTH / 2.0
	var point: Dictionary = network.sample("east", 40.0, lane, 1)
	assert_almost_eq((point["position"] as Vector2).distance_to(Vector2(40.0, lane)), 0.0, 0.01, "Travelling +X, right is +Z")
	var reverse: Dictionary = network.sample("east", 40.0, lane, -1)
	assert_almost_eq((reverse["position"] as Vector2).distance_to(Vector2(40.0, -lane)), 0.0, 0.01)


func test_heading_matches_bus_convention() -> void:
	assert_almost_eq(RoadNetwork.heading_of(Vector2(0.0, -1.0)), 0.0, 0.001, "North is heading 0")
	assert_almost_eq(RoadNetwork.heading_of(Vector2(1.0, 0.0)), -PI / 2.0, 0.001, "East")


func test_curved_road_passes_through_its_via_point() -> void:
	var via: Array[Vector2] = [Vector2(60.0, 40.0)]
	network.add_road("bend", "a", "b", via)
	var points: PackedVector2Array = network.roads["bend"]["points"]
	var nearest := INF
	for point in points:
		nearest = minf(nearest, point.distance_to(via[0]))
	assert_lt(nearest, 0.5)


func test_edge_distance_inside_and_outside_the_road() -> void:
	assert_lt(network.edge_distance(Vector2(50.0, 0.0)), 0.0, "Road centre")
	assert_almost_eq(network.edge_distance(Vector2(50.0, 5.75)), 2.0, 0.01, "Two metres off the road")
	assert_eq(network.edge_distance(Vector2(50.0, 80.0)), INF, "Far away")


func test_junction_disc_counts_as_road() -> void:
	assert_lt(network.edge_distance(Vector2(7.0, 7.0)), 0.0)


func test_roundabout_island_is_not_road() -> void:
	assert_gt(network.edge_distance(Vector2(103.0, 0.0)), 0.0)
	assert_lt(network.edge_distance(Vector2(114.0, 0.0)), 0.0, "The ring is road")


func test_bay_widens_the_road() -> void:
	var spot := Vector2(50.0, RoadNetwork.ROAD_HALF_WIDTH + 2.0)
	assert_gt(network.edge_distance(spot), 0.0)
	network.add_bay("east", 50.0, 1)
	assert_lt(network.edge_distance(spot), 0.0)


func test_kerb_lifts_a_wheel_on_the_pavement_only() -> void:
	var ground := GroundSurface.new()
	ground.network = network
	assert_eq(ground.height_at(Vector2(50.0, 0.0)), 0.0)
	assert_eq(ground.height_at(Vector2(50.0, 6.0)), GroundSurface.KERB_HEIGHT)
	assert_eq(ground.height_at(Vector2(50.0, 9.0)), 0.0, "Past the pavement is grass")


func test_right_turn_sweep_stays_on_a_junction() -> void:
	# A rear axle on full lock turning right from the right lane must stay on
	# asphalt at a standard junction. This keeps junction size honest.
	var spec := BusSpec.new()
	var radius := spec.wheelbase / tan(deg_to_rad(spec.max_steer_degrees))
	var lane := RoadNetwork.LANE_WIDTH / 2.0
	var centre := Vector2(lane + radius, lane + radius)
	for degrees in range(0, 91, 10):
		var inner_wheel := radius - spec.body_width / 2.0
		var point := centre + Vector2(-inner_wheel, 0.0).rotated(deg_to_rad(degrees))
		assert_lte(network.edge_distance(point), 0.0, "Inner wheel at %d degrees" % degrees)
