extends GutTest
## Every route in the catalog has to be a shift that can be driven and scored.

var catalog: Catalog
var map_data: Dictionary


func before_each() -> void:
	catalog = Catalog.new()
	map_data = MapLoader.read_json("res://data/packs/colombia/maps/puerto_marisol.json")


func _build(item: Dictionary) -> RouteRunner:
	var data := MapLoader.read_json(item["file"])
	return RouteRunner.build(data, RoadNetwork.from_data(MapLoader.read_map_of(data)))


func test_game_launches_with_four_routes_that_cost_more_as_they_go() -> void:
	var routes: Array = catalog.items(Catalog.ROUTES)
	assert_eq(routes.size(), 4)
	assert_eq(int(routes[0]["cost"]), 0, "The first route is free")
	assert_eq(int(routes[1]["cost"]), 500)
	for i in range(1, routes.size()):
		assert_gt(int(routes[i]["cost"]), int(routes[i - 1]["cost"]))


func test_every_route_ends_with_a_timed_stop_at_the_depot() -> void:
	for item: Dictionary in catalog.items(Catalog.ROUTES):
		var stops := _build(item).stops
		assert_true(stops[stops.size() - 1].is_final, item["id"])
		assert_eq(stops[stops.size() - 1].stop_name, "Patio Central", item["id"])
		for i in range(1, stops.size()):
			assert_gt(stops[i].due, stops[i - 1].due, "%s: stop %d" % [item["id"], i])


func test_stops_come_in_route_order() -> void:
	for item: Dictionary in catalog.items(Catalog.ROUTES):
		var stops := _build(item).stops
		for i in range(1, stops.size()):
			assert_gt(stops[i].route_distance, stops[i - 1].route_distance, "%s: stop %d" % [item["id"], i])


func test_stops_are_far_enough_apart_to_brake_for() -> void:
	for item: Dictionary in catalog.items(Catalog.ROUTES):
		var stops := _build(item).stops
		for i in range(1, stops.size()):
			assert_gt(stops[i].route_distance - stops[i - 1].route_distance, 120.0, "%s: stop %d" % [item["id"], i])


func test_bus_ends_each_shift_empty() -> void:
	for item: Dictionary in catalog.items(Catalog.ROUTES):
		var stops := _build(item).stops
		assert_eq(stops[stops.size() - 2].waiting, 0, "%s: nobody boards at the last stop" % item["id"])


func test_no_bay_is_blocked_by_a_parked_car_or_a_prop() -> void:
	var reach := RoadNetwork.BAY_LENGTH / 2.0 + 5.0
	for item: Dictionary in catalog.items(Catalog.ROUTES):
		for stop in _build(item).stops:
			for entry: Dictionary in map_data["parked_cars"] + map_data["knockables"]:
				if entry["road"] == stop.road and int(entry["dir"]) == stop.dir:
					assert_gt(absf(float(entry["along"]) - stop.along), reach, "%s: %s" % [item["id"], stop.stop_name])


func test_every_leg_of_a_route_joins_the_next() -> void:
	for item: Dictionary in catalog.items(Catalog.ROUTES):
		var line := _build(item).polyline
		for i in range(1, line.size()):
			assert_lt(line[i].distance_to(line[i - 1]), 40.0, "%s: legs must join up at %d" % [item["id"], i])
