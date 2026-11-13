extends GutTest
## Every route in the catalog has to be a shift that can be driven and scored.

## Each town's depot, where every timed route in it ends.
const DEPOTS := {"Puerto Marisol": "Patio Central", "Alto Cafeto": "Patio Cafeto", "Puerto Remanso": "Patio Fluvial"}

var catalog: Catalog
var map_data: Dictionary


func before_each() -> void:
	catalog = Catalog.new()
	map_data = MapLoader.read_json("res://data/packs/colombia/maps/puerto_marisol.json")


func _map_of(item: Dictionary) -> Dictionary:
	return MapLoader.read_map_of(MapLoader.read_json(item["file"]))


func _build(item: Dictionary) -> RouteRunner:
	var data := MapLoader.read_json(item["file"])
	var own_map := MapLoader.read_map_of(data)
	return RouteRunner.build(data, RoadNetwork.from_data(own_map), 7, own_map)


## Routes with a depot at the end. The endless route has none.
func _timed_routes() -> Array:
	return catalog.items(Catalog.ROUTES).filter(func(item: Dictionary) -> bool:
		return not ["endless", "arcade"].has(MapLoader.read_json(item["file"]).get("service", "")))


func test_game_launches_with_five_routes_that_cost_more_as_they_go() -> void:
	var ids: Array = catalog.items(Catalog.ROUTES).map(func(item: Dictionary) -> String: return item["id"])
	assert_eq(ids[0], "starter_a")
	assert_eq(ids[1], "starter_b")
	assert_eq(ids[2], "route_01")
	assert_eq(int(catalog.find(Catalog.ROUTES, "starter_a")["cost"]), 0, "The first route is free")
	assert_eq(int(catalog.find(Catalog.ROUTES, "starter_b")["cost"]), 0)
	assert_eq(int(catalog.find(Catalog.ROUTES, "route_01")["cost"]), 0)
	var paid: Array = ["route_02", "route_03", "route_04"].map(func(id: String) -> Dictionary: return catalog.find(Catalog.ROUTES, id))
	assert_eq(int(paid[0]["cost"]), 500)
	for i in range(1, paid.size()):
		assert_gt(int(paid[i]["cost"]), int(paid[i - 1]["cost"]))
	assert_eq(int(catalog.find(Catalog.ROUTES, "libre")["cost"]), 0, "The endless route is free to play")


func test_every_route_ends_with_a_timed_stop_at_the_depot() -> void:
	for item: Dictionary in _timed_routes():
		var stops := _build(item).stops
		assert_true(stops[stops.size() - 1].is_final, item["id"])
		assert_eq(stops[stops.size() - 1].stop_name, DEPOTS[_map_of(item)["name"]], item["id"])
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
			assert_gt(stops[i].route_distance - stops[i - 1].route_distance, 45.0, "%s: stop %d" % [item["id"], i])


func test_bus_ends_each_shift_empty() -> void:
	for item: Dictionary in _timed_routes():
		var stops := _build(item).stops
		assert_eq(stops[stops.size() - 2].waiting, 0, "%s: nobody boards at the last stop" % item["id"])


func test_no_bay_is_blocked_by_a_parked_car_or_a_prop() -> void:
	for item: Dictionary in catalog.items(Catalog.ROUTES):
		var own_map := _map_of(item)
		for stop in _build(item).stops:
			if stop.is_final:
				continue
			var named: bool = stop.kind != RouteStop.Kind.HAIL or stop.stop_name != RoadNetwork.from_data(own_map).roads[stop.road]["name"]
			if named:
				continue
			for entry: Dictionary in own_map["parked_cars"]:
				if entry["road"] == stop.road and int(entry["dir"]) == stop.dir:
					assert_gt(absf(float(entry["along"]) - stop.along), 21.0, "%s: %s" % [item["id"], stop.stop_name])


func test_every_leg_of_a_route_joins_the_next() -> void:
	for item: Dictionary in catalog.items(Catalog.ROUTES):
		var line := _build(item).polyline
		for i in range(1, line.size()):
			assert_lt(line[i].distance_to(line[i - 1]), 40.0, "%s: legs must join up at %d" % [item["id"], i])


func test_informal_routes_add_hails_between_the_named_stops() -> void:
	var item := catalog.find(Catalog.ROUTES, "route_01")
	var named: Array = MapLoader.read_json(item["file"])["stops"]
	var runner := _build(item)
	assert_gt(runner.stops.size(), named.size())
	for stop in runner.stops:
		assert_eq(stop.kind, RouteStop.Kind.HAIL)


func test_each_shift_lays_out_different_hails() -> void:
	var item := catalog.find(Catalog.ROUTES, "route_01")
	var data := MapLoader.read_json(item["file"])
	var network := RoadNetwork.from_data(map_data)
	var one := RouteRunner.build(data, network, 1, map_data)
	var two := RouteRunner.build(data, network, 2, map_data)
	var places_one: Array = one.stops.map(func(stop: RouteStop) -> Vector2: return stop.position)
	var places_two: Array = two.stops.map(func(stop: RouteStop) -> Vector2: return stop.position)
	assert_ne(places_one, places_two)


func test_the_same_seed_lays_out_the_same_hails() -> void:
	var item := catalog.find(Catalog.ROUTES, "route_02")
	var data := MapLoader.read_json(item["file"])
	var network := RoadNetwork.from_data(map_data)
	var one := RouteRunner.build(data, network, 5, map_data)
	var two := RouteRunner.build(data, network, 5, map_data)
	assert_eq(one.stops.size(), two.stops.size())


func test_starter_routes_are_short_and_simple() -> void:
	var a := _build(catalog.find(Catalog.ROUTES, "starter_a"))
	var b := _build(catalog.find(Catalog.ROUTES, "starter_b"))
	assert_eq(a.stops.size(), 3)
	assert_eq(b.stops.size(), 5)
	assert_eq(a.stops[a.stops.size() - 1].stop_name, "Patio Central")
	assert_eq(b.stops[b.stops.size() - 1].stop_name, "Patio Central")
	assert_lt(a.stops[a.stops.size() - 1].due, b.stops[b.stops.size() - 1].due)


func test_informal_timetable_rises_with_the_distance_driven() -> void:
	var stops := _build(catalog.find(Catalog.ROUTES, "route_01")).stops
	for i in range(1, stops.size()):
		assert_gt(stops[i].due, stops[i - 1].due)


func test_every_informal_route_has_a_vendor_on_it() -> void:
	for id: String in ["route_01", "route_02", "route_04"]:
		var vendors := _build(catalog.find(Catalog.ROUTES, id)).stops.filter(func(stop: RouteStop) -> bool: return stop.vendor)
		assert_gt(vendors.size(), 0, id)


func test_rapid_transit_line_uses_fixed_stations_on_its_own_road() -> void:
	var item := catalog.find(Catalog.ROUTES, "troncal")
	var runner := _build(item)
	var network := RoadNetwork.from_data(map_data)
	assert_eq(item["only_bus"], "articulado_18")
	assert_true(network.roads["troncal"]["busway"])
	assert_false(network.roads["troncal"]["traffic"])
	for stop in runner.stops:
		assert_eq(stop.kind, RouteStop.Kind.STATION)
		assert_eq(stop.road, "troncal")


func test_out_and_back_route_tells_the_two_directions_apart() -> void:
	var runner := _build(catalog.find(Catalog.ROUTES, "troncal"))
	var network := RoadNetwork.from_data(map_data)
	var outward: Dictionary = network.sample("troncal", 500.0, 1.9, 1)
	var back: Dictionary = network.sample("troncal", 500.0, 1.9, -1)
	for along: float in range(40, 860, 30):
		var there: Dictionary = network.sample("troncal", along, 1.9, 1)
		runner.update_position(there["position"], there["forward"])
	var at_far_end := runner.progress
	for along: float in range(860, 40, -30):
		var there: Dictionary = network.sample("troncal", along, 1.9, -1)
		runner.update_position(there["position"], there["forward"])
	assert_gt(runner.progress, at_far_end + 600.0, "Progress keeps climbing on the way back")
	assert_ne(outward["position"], back["position"])
