extends GutTest
## Puerto Remanso, the third town: a tropical river port on the lower Magdalena
## with an elevated river bridge, a sloping ferry ramp, and a driver level it opens at.

const MAP := "res://data/packs/colombia/maps/puerto_remanso.json"
const MAX_GRADE := 0.125
const STARTER_ROADS := [
	"depot_road", "calle_bodegas", "avenida_fluvial", "carrera_mercado",
	"paseo_ribera", "puente_fluvial", "camino_garzas", "avenida_norte", "carrera_central"
]

var map_data: Dictionary
var catalog: Catalog


func before_each() -> void:
	map_data = MapLoader.read_json(MAP)
	catalog = Catalog.new()


func _grade_along(road: Dictionary, ground: GroundSurface) -> float:
	var points: PackedVector2Array = road["points"]
	var steepest := 0.0
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var run := a.distance_to(b)
		if run > 0.5:
			steepest = maxf(steepest, absf(ground.terrain_height(b) - ground.terrain_height(a)) / run)
	return steepest


func test_map_loads_with_every_road_joined_to_its_nodes() -> void:
	assert_eq(map_data["name"], "Puerto Remanso")
	var network := RoadNetwork.from_data(map_data)
	assert_eq(network.roads.size(), 13)
	var degree := {}
	for road: Dictionary in network.roads.values():
		assert_true(network.nodes.has(road["from"]), road["id"])
		assert_true(network.nodes.has(road["to"]), road["id"])
		degree[road["from"]] = int(degree.get(road["from"], 0)) + 1
		degree[road["to"]] = int(degree.get(road["to"], 0)) + 1
	for id: String in network.nodes:
		assert_gt(int(degree.get(id, 0)), 0, "Node %s has a road" % id)
	assert_eq(network.nodes["c"]["kind"], "roundabout", "Glorieta Central is a roundabout")
	assert_eq(network.nodes["e"]["kind"], "roundabout", "Glorieta del Embarcadero is a roundabout")


func test_river_port_has_coast_for_the_magdalena() -> void:
	assert_true(map_data.has("coast"))
	var ground := MapLoader.build_ground(map_data, RoadNetwork.from_data(map_data))
	assert_eq(ground.coast_x, 200.0)
	assert_gt(ground.beach_share(Vector2(230.0, 80.0)), 0.0, "Ferry landing touches the river water")


func test_puente_fluvial_arches_above_the_riverbank() -> void:
	var network := RoadNetwork.from_data(map_data)
	var ground := MapLoader.build_ground(map_data, network)
	var depot_y := ground.terrain_height(network.nodes["depot"]["position"])
	var bridge_road: Dictionary = network.roads["puente_fluvial"]
	var mid_point: Vector2 = bridge_road["points"][bridge_road["points"].size() / 2]
	var bridge_mid_y := ground.terrain_height(mid_point)
	assert_gt(bridge_mid_y - depot_y, 4.0, "Bridge arches above the town baseline")


func test_ferry_ramp_slopes_down_to_the_river() -> void:
	var network := RoadNetwork.from_data(map_data)
	var ground := MapLoader.build_ground(map_data, network)
	var top_y := ground.terrain_height(network.nodes["d"]["position"])
	var ramp_bottom_y := ground.terrain_height(network.nodes["e"]["position"])
	assert_gt(top_y - ramp_bottom_y, 2.0, "Ferry ramp descends towards the river")


func test_no_road_is_steep_enough_to_stall_the_starter_buseta() -> void:
	var network := RoadNetwork.from_data(map_data)
	var ground := MapLoader.build_ground(map_data, network)
	var steepest := 0.0
	for road: Dictionary in network.roads.values():
		var grade := _grade_along(road, ground)
		assert_lt(grade, MAX_GRADE, "%s climbs %.1f%%" % [road["id"], grade * 100.0])
		steepest = maxf(steepest, grade)
	assert_gt(steepest, 0.05, "Some slope exists on the bridge or ferry ramp")


func test_starter_roads_stay_gentle() -> void:
	var network := RoadNetwork.from_data(map_data)
	var ground := MapLoader.build_ground(map_data, network)
	for id: String in STARTER_ROADS:
		assert_lt(_grade_along(network.roads[id], ground), 0.10, id)


func test_props_stand_on_the_pavement() -> void:
	var network := RoadNetwork.from_data(map_data)
	for entry: Dictionary in map_data["knockables"]:
		var spot: Vector2 = network.sample(entry["road"], entry["along"], entry["lateral"], entry["dir"])["position"]
		assert_gt(network.edge_distance(spot), 0.3, "%s on %s at %s" % [entry["kind"], entry["road"], entry["along"]])


func test_bird_clusters_are_valid_and_inside_the_town() -> void:
	assert_eq(MapLoader.check_bird_clusters(map_data["bird_clusters"]), [] as Array[String])
	var cluster_ids: Array = (map_data["bird_clusters"] as Array).map(func(c: Dictionary) -> String: return c["id"])
	assert_true(cluster_ids.has("ribera_manglares"), "Bird cluster exists near riverfront")
	assert_true(cluster_ids.has("glorieta_ceiba"), "Bird cluster exists near central plaza")
	assert_true(cluster_ids.has("isla_garzas"), "Bird cluster exists near north wetland")
	for cluster: Dictionary in map_data["bird_clusters"]:
		assert_lt(absf(float(cluster["x"])), 300.0, cluster["id"])
		assert_lt(absf(float(cluster["z"])), 300.0, cluster["id"])


func test_starter_route_loads_with_three_goals_and_stops() -> void:
	var item := catalog.find(Catalog.ROUTES, "remanso_r0")
	assert_false(item.is_empty())
	var data := MapLoader.read_json(item["file"])
	assert_eq(data["map"], "maps/puerto_remanso.json")
	assert_eq((data["goals"] as Array).size(), 3)
	var runner := RouteRunner.build(data, RoadNetwork.from_data(map_data), 7, map_data)
	assert_eq(runner.stops.size(), 3)
	assert_eq(runner.stops[0].stop_name, "Mercado Fluvial")
	assert_eq(runner.stops[1].stop_name, "Puente Fluvial")
	assert_eq(runner.stops[2].stop_name, "Patio Fluvial")
	assert_true(runner.stops[2].is_final)
	var length := runner.stops[2].route_distance
	assert_between(length, 1000.0, 1500.0, "About two to three minutes of driving")


func test_starter_bays_fit_between_the_junctions() -> void:
	var network := RoadNetwork.from_data(map_data)
	var data := MapLoader.read_json(catalog.find(Catalog.ROUTES, "remanso_r0")["file"])
	for stop: Dictionary in data["stops"]:
		if stop.get("final", false):
			continue
		var road: Dictionary = network.roads[stop["road"]]
		var reach := RoadNetwork.BAY_LENGTH / 2.0 + RoadNetwork.BAY_TAPER
		var start_clear := float(network.nodes[road["from"]]["radius"])
		var end_clear := float(road["length"]) - float(network.nodes[road["to"]]["radius"])
		assert_gt(float(stop["along"]) - reach, start_clear, "remanso_r0: %s" % stop["name"])
		assert_lt(float(stop["along"]) + reach, end_clear, "remanso_r0: %s" % stop["name"])
		for car: Dictionary in map_data["parked_cars"]:
			if car["road"] == stop["road"] and int(car["dir"]) == int(stop["dir"]):
				assert_gt(absf(float(car["along"]) - float(stop["along"])), 21.0, "remanso_r0: %s" % stop["name"])


func test_puerto_remanso_opens_at_driver_level_ten() -> void:
	var item := catalog.find(Catalog.ROUTES, "remanso_r0")
	assert_eq(int(item["level"]), 10)
	assert_eq(int(item["cost"]), 0)
	var profile := PlayerProfile.new()
	profile.grant_free_items(catalog)
	assert_false(profile.can_play_route("remanso_r0", catalog), "Locked for a level 1 driver")
	profile.xp = DriverLevel.xp_for_level(8)
	assert_false(profile.can_play_route("remanso_r0", catalog), "Still locked at level 8")
	profile.xp = DriverLevel.xp_for_level(10) - 1
	assert_false(profile.can_play_route("remanso_r0", catalog))
	profile.xp = DriverLevel.xp_for_level(10)
	assert_true(profile.can_play_route("remanso_r0", catalog), "Open at level 10")


func test_routes_tab_groups_routes_including_puerto_remanso() -> void:
	var towns := MainMenu.route_towns(catalog.items(Catalog.ROUTES))
	assert_eq(towns["starter_a"], "Puerto Marisol")
	assert_eq(towns["cafeto_c0"], "Alto Cafeto")
	assert_eq(towns["remanso_r0"], "Puerto Remanso")


func test_town_info_list_includes_puerto_remanso_with_level_ten() -> void:
	var towns := MainMenu.town_info_list(catalog.items(Catalog.ROUTES))
	var remanso_info: Dictionary = {}
	for t in towns:
		if t["name"] == "Puerto Remanso":
			remanso_info = t
			break
	assert_false(remanso_info.is_empty(), "Puerto Remanso in town list")
	assert_eq(int(remanso_info["level"]), 10)


func test_remanso_route_goals_score() -> void:
	var data := MapLoader.read_json(catalog.find(Catalog.ROUTES, "remanso_r0")["file"])
	var good := {
		"time": 155.0,
		"counts": {"collisions": 0, "fines": 0},
	}
	assert_eq(RouteGoals.stars_for(data["goals"], good), 3)
	var bad := {
		"time": 400.0,
		"counts": {"collisions": 1, "fines": 1},
	}
	assert_eq(RouteGoals.stars_for(data["goals"], bad), 0)


func test_traffic_share_is_relaxed_for_river_port() -> void:
	assert_almost_eq(TrafficSystem.map_traffic_share(map_data), 0.6, 0.001)


func test_the_ferry_landing_road_and_kerbs_are_not_water_but_the_river_is() -> void:
	var network := RoadNetwork.from_data(map_data)
	var ground := MapLoader.build_ground(map_data, network)
	for road: Dictionary in network.roads.values():
		var length := float(road["length"])
		var along := 0.0
		while along <= length:
			for lateral: float in [0.0, RoadNetwork.ROAD_HALF_WIDTH + 1.0, -RoadNetwork.ROAD_HALF_WIDTH - 1.0]:
				var point: Vector2 = network.sample(road["id"], along, lateral)["position"]
				assert_false(MapGuard.in_water(ground, network, point), "%s at %.0f m" % [road["id"], along])
			along += 10.0
	assert_true(MapGuard.in_water(ground, network, Vector2(300.0, 80.0)), "Out in the Magdalena")
