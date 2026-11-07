extends GutTest
## A country is a folder of data. These prove a pack loads, gets checked, and that
## left-hand driving works without any country-specific code.

const COLOMBIA := "res://data/packs/colombia/pack.json"
const TESTLAND := "res://test/fixtures/packs/testland/pack.json"


func after_each() -> void:
	Country.use_pack(COLOMBIA)


func _broken_pack(changes: Dictionary) -> CountryPack:
	var pack := CountryPack.read(COLOMBIA)
	pack.data = pack.data.duplicate(true)
	pack.data.merge(changes, true)
	return pack


func test_the_game_starts_in_colombia() -> void:
	assert_eq(Country.pack.id, "colombia")
	assert_eq(Country.pack.traffic_side, CountryPack.RIGHT_HAND)


func test_colombia_pack_is_valid() -> void:
	assert_eq(CountryPack.read(COLOMBIA).validate(), [] as Array[String])


func test_dummy_pack_is_valid() -> void:
	assert_eq(CountryPack.read(TESTLAND).validate(), [] as Array[String])


func test_missing_pack_is_reported_and_does_not_crash() -> void:
	var problems := CountryPack.read("res://data/packs/nowhere/pack.json").validate()
	assert_eq(problems.size(), 1)


func test_missing_field_is_reported() -> void:
	var pack := CountryPack.read(COLOMBIA)
	pack.data = pack.data.duplicate(true)
	pack.data.erase("currency")
	assert_true(pack.validate().has("Missing field: currency"))


func test_nonsense_driving_side_is_rejected() -> void:
	assert_true(_broken_pack({"driving_side": "middle"}).validate().has("driving_side must be left or right"))


func test_unknown_speed_unit_is_rejected() -> void:
	var rules := {"speed_unit": "knots", "default_speed_limit": 50}
	assert_true(_broken_pack({"road_rules": rules}).validate().has("road_rules.speed_unit must be kmh or mph"))


func test_default_language_must_be_offered() -> void:
	assert_true(_broken_pack({"default_language": "xx"}).validate().has("default_language is not one of the languages"))


func test_missing_sound_file_is_reported() -> void:
	var problems := _broken_pack({"sounds": {"ambience": "res://assets/audio/nothing.wav"}}).validate()
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "nothing.wav")


func test_a_pack_needs_a_horn() -> void:
	assert_true(_broken_pack({"horns": []}).validate().has("A pack needs at least one horn"))


func _with_passengers(path: String) -> CountryPack:
	var content: Dictionary = (CountryPack.read(COLOMBIA).data["content"] as Dictionary).duplicate()
	content["passengers"] = path
	return _broken_pack({"content": content})


func test_a_pack_with_a_broken_passengers_file_fails_validation() -> void:
	for file: String in ["not_json.json", "no_looks.json", "bad_looks.json"]:
		var problems := _with_passengers("res://test/fixtures/passengers/" + file).validate()
		assert_false(problems.is_empty(), file)
		assert_true(problems.all(func(problem: String) -> bool: return problem.contains("assenger")), "%s: %s" % [file, problems])


func test_a_missing_passengers_file_is_reported() -> void:
	var problems := _with_passengers("nobody.json").validate()
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "nobody.json")


func test_a_pack_with_a_broken_passengers_file_still_has_people() -> void:
	var pack := _with_passengers("res://test/fixtures/passengers/not_json.json")
	assert_gt(pack.passenger_looks().looks.size(), 0)


func test_the_test_pack_shares_colombias_passengers() -> void:
	var colombia := CountryPack.read(COLOMBIA).passenger_looks()
	assert_eq(CountryPack.read(TESTLAND).passenger_looks().looks.size(), colombia.looks.size())


func test_money_uses_the_countrys_format() -> void:
	assert_eq(CountryPack.read(COLOMBIA).money(29), "$2.900")
	assert_eq(CountryPack.read(COLOMBIA).money(500), "$50.000")
	assert_eq(CountryPack.read(COLOMBIA).money(12345), "$1.234.500")
	assert_eq(CountryPack.read(TESTLAND).money(1234), "£1,234")


func test_money_can_be_negative_and_zero() -> void:
	assert_eq(CountryPack.read(COLOMBIA).money(0), "$0")
	assert_eq(CountryPack.read(COLOMBIA).money(-5), "-$500")


func test_speed_is_shown_in_the_countrys_unit() -> void:
	assert_eq(CountryPack.read(COLOMBIA).display_speed(50.0), 50.0)
	assert_almost_eq(CountryPack.read(TESTLAND).display_speed(100.0), 62.1, 0.1)


func test_relative_paths_stay_in_the_pack_and_full_paths_are_kept() -> void:
	var pack := CountryPack.read(TESTLAND)
	assert_eq(pack.resolve("routes/x.json"), "res://test/fixtures/packs/testland/routes/x.json")
	assert_eq(pack.resolve("res://elsewhere/x.json"), "res://elsewhere/x.json")


func test_switching_pack_changes_the_catalog() -> void:
	Country.use_pack(TESTLAND)
	assert_eq(Profile.catalog.items(Catalog.ROUTES)[0]["id"], "test_loop")
	Country.use_pack(COLOMBIA)
	assert_gt(Profile.catalog.items(Catalog.ROUTES).size(), 1)


func _network(side: int) -> RoadNetwork:
	return RoadNetwork.from_data(MapLoader.read_json("res://data/packs/colombia/maps/puerto_marisol.json"), side)


func test_left_hand_lanes_are_on_the_other_side_of_the_road() -> void:
	var right_hand: Vector2 = _network(1).sample("mill_lane", 100.0, 1.9, 1)["position"]
	var left_hand: Vector2 = _network(-1).sample("mill_lane", 100.0, 1.9, 1)["position"]
	var centre: Vector2 = _network(1).sample("mill_lane", 100.0)["position"]
	assert_almost_eq(right_hand.distance_to(centre), 1.9, 0.01)
	assert_almost_eq(left_hand.distance_to(centre), 1.9, 0.01)
	assert_almost_eq(right_hand.distance_to(left_hand), 3.8, 0.01)
	var heading: Vector2 = _network(-1).sample("mill_lane", 100.0, 0.0, 1)["forward"]
	assert_lt((left_hand - centre).dot(Vector2(-heading.y, heading.x)), 0.0, "Left of travel")


func test_road_frame_geometry_does_not_change_with_the_side() -> void:
	var a: Vector2 = _network(1).sample("mill_lane", 100.0, 2.0)["position"]
	var b: Vector2 = _network(-1).sample("mill_lane", 100.0, 2.0)["position"]
	assert_eq(a, b)


func test_left_hand_stops_sit_on_the_left() -> void:
	Country.use_pack(TESTLAND)
	var data := MapLoader.read_json(Profile.catalog.items(Catalog.ROUTES)[0]["file"])
	var network := RoadNetwork.from_data(MapLoader.read_map_of(data), Country.pack.traffic_side)
	var route := RouteRunner.build(data, network)
	var stop := route.stops[0]
	var centre: Vector2 = network.sample(stop.road, stop.along)["position"]
	var forward := stop.forward()
	assert_lt((stop.position - centre).dot(Vector2(-forward.y, forward.x)), 0.0)


func test_left_hand_roundabouts_turn_the_other_way() -> void:
	var map_data := MapLoader.read_json("res://data/packs/colombia/maps/puerto_marisol.json")
	for side: int in [1, -1]:
		var graph := LaneGraph.build(RoadNetwork.from_data(map_data, side), map_data)
		var centre: Vector2 = graph.network.nodes["c"]["position"]
		for link_index: int in graph.links_at["c"]:
			var link: TrafficLane = graph.lanes[link_index]
			var turning := 0.0
			for i in range(1, link.points.size()):
				turning += (link.points[i - 1] - centre).angle_to(link.points[i] - centre)
			assert_eq(signf(turning), -float(side), "Ring direction for side %d" % side)


func test_right_hand_buses_stay_as_they_are() -> void:
	var spec := BusSpec.new()
	spec.keep_to_side(1)
	assert_eq(spec.door_side, 1)
	assert_lt(spec.driver_seat_x, 0.0)


func test_left_hand_buses_mirror_door_and_driver() -> void:
	var spec := BusSpec.new()
	spec.keep_to_side(-1)
	assert_eq(spec.door_side, -1)
	assert_gt(spec.driver_seat_x, 0.0)
