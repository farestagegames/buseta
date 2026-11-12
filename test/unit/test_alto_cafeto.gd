extends GutTest
## Alto Cafeto, the second town: a hill town in the coffee region with its own map,
## a short starter route, and a driver level it opens at.

const MAP := "res://data/packs/colombia/maps/alto_cafeto.json"
## The starter buseta stalls near 14%; the design keeps every road under 12.5%.
const MAX_GRADE := 0.125
const STARTER_ROADS := ["depot_road", "subida_cafetal", "curva_cafe", "calle_real"]

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
	assert_eq(map_data["name"], "Alto Cafeto")
	var network := RoadNetwork.from_data(map_data)
	assert_eq(network.roads.size(), 10)
	var degree := {}
	for road: Dictionary in network.roads.values():
		assert_true(network.nodes.has(road["from"]), road["id"])
		assert_true(network.nodes.has(road["to"]), road["id"])
		degree[road["from"]] = int(degree.get(road["from"], 0)) + 1
		degree[road["to"]] = int(degree.get(road["to"], 0)) + 1
	for id: String in network.nodes:
		assert_gt(int(degree.get(id, 0)), 0, "Node %s has a road" % id)
	assert_eq(network.nodes["c"]["kind"], "roundabout", "The plaza is a roundabout the starter turns at")


func test_a_mountain_town_has_no_coast() -> void:
	assert_false(map_data.has("coast"))
	var ground := MapLoader.build_ground(map_data, RoadNetwork.from_data(map_data))
	assert_eq(ground.coast_x, GroundSurface.NO_COAST)
	assert_eq(ground.beach_share(Vector2(400.0, 0.0)), 0.0)


func test_town_climbs_to_a_mirador_well_above_the_depot() -> void:
	var network := RoadNetwork.from_data(map_data)
	var ground := MapLoader.build_ground(map_data, network)
	var depot := ground.terrain_height(network.nodes["depot"]["position"])
	var mirador := ground.terrain_height(network.nodes["e"]["position"])
	var plaza := ground.terrain_height(network.nodes["c"]["position"])
	assert_gt(mirador - depot, 15.0, "A real climb to the mirador")
	assert_gt(plaza, depot + 5.0, "The plaza sits up the hill from the depot")


func test_no_road_is_steep_enough_to_stall_the_starter_buseta() -> void:
	var network := RoadNetwork.from_data(map_data)
	var ground := MapLoader.build_ground(map_data, network)
	var steepest := 0.0
	for road: Dictionary in network.roads.values():
		var grade := _grade_along(road, ground)
		assert_lt(grade, MAX_GRADE, "%s climbs %.1f%%" % [road["id"], grade * 100.0])
		steepest = maxf(steepest, grade)
	assert_gt(steepest, 0.08, "Still a hill town: some road climbs over 8%")


func test_starter_roads_stay_gentle() -> void:
	var network := RoadNetwork.from_data(map_data)
	var ground := MapLoader.build_ground(map_data, network)
	for id: String in STARTER_ROADS:
		assert_lt(_grade_along(network.roads[id], ground), 0.08, id)


func test_props_stand_on_the_pavement() -> void:
	var network := RoadNetwork.from_data(map_data)
	for entry: Dictionary in map_data["knockables"]:
		var spot: Vector2 = network.sample(entry["road"], entry["along"], entry["lateral"], entry["dir"])["position"]
		assert_gt(network.edge_distance(spot), 0.3, "%s on %s at %s" % [entry["kind"], entry["road"], entry["along"]])


func test_bird_clusters_are_valid_and_inside_the_town() -> void:
	assert_eq(MapLoader.check_bird_clusters(map_data["bird_clusters"]), [] as Array[String])
	for cluster: Dictionary in map_data["bird_clusters"]:
		assert_lt(absf(float(cluster["x"])), 300.0, cluster["id"])
		assert_lt(absf(float(cluster["z"])), 300.0, cluster["id"])


func test_theme_is_a_hill_town_without_palms() -> void:
	var theme := CityTheme.from_data(map_data)
	assert_eq(theme.palm_share, 0.0)
	assert_lte(theme.highest_storeys, 3)
	assert_lt(theme.street_gap, 1.0, "A tight street wall")


func test_starter_route_is_a_short_out_and_back_to_the_plaza() -> void:
	var item := catalog.find(Catalog.ROUTES, "cafeto_c0")
	assert_false(item.is_empty())
	var data := MapLoader.read_json(item["file"])
	assert_eq(data["map"], "maps/alto_cafeto.json")
	assert_eq((data["goals"] as Array).size(), 3)
	var runner := RouteRunner.build(data, RoadNetwork.from_data(map_data), 7, map_data)
	assert_eq(runner.stops.size(), 3)
	assert_eq(runner.stops[1].stop_name, "Plaza Principal")
	assert_eq(runner.stops[2].stop_name, "Patio Cafeto")
	assert_true(runner.stops[2].is_final)
	var length := runner.stops[2].route_distance
	assert_between(length, 800.0, 1300.0, "About three minutes of driving")


func test_starter_bays_fit_between_the_junctions() -> void:
	var network := RoadNetwork.from_data(map_data)
	var data := MapLoader.read_json(catalog.find(Catalog.ROUTES, "cafeto_c0")["file"])
	for stop: Dictionary in data["stops"]:
		if stop.get("final", false):
			continue
		var road: Dictionary = network.roads[stop["road"]]
		var reach := RoadNetwork.BAY_LENGTH / 2.0 + RoadNetwork.BAY_TAPER
		var start_clear := float(network.nodes[road["from"]]["radius"])
		var end_clear := float(road["length"]) - float(network.nodes[road["to"]]["radius"])
		assert_gt(float(stop["along"]) - reach, start_clear, stop["name"])
		assert_lt(float(stop["along"]) + reach, end_clear, stop["name"])


func test_alto_cafeto_opens_at_driver_level_six() -> void:
	var item := catalog.find(Catalog.ROUTES, "cafeto_c0")
	assert_eq(int(item["level"]), 6)
	assert_eq(int(item["cost"]), 0)
	var profile := PlayerProfile.new()
	profile.grant_free_items(catalog)
	assert_false(profile.can_play_route("cafeto_c0", catalog), "Locked for a new driver")
	profile.xp = DriverLevel.xp_for_level(6) - 1
	assert_false(profile.can_play_route("cafeto_c0", catalog))
	profile.xp = DriverLevel.xp_for_level(6)
	assert_true(profile.can_play_route("cafeto_c0", catalog), "Open at level 6")


func test_a_locked_town_route_falls_back_when_chosen() -> void:
	var profile := PlayerProfile.new()
	profile.grant_free_items(catalog)
	profile.selected[Catalog.ROUTES] = "cafeto_c0"
	profile.repair_choices(catalog)
	assert_ne(profile.selected[Catalog.ROUTES], "cafeto_c0")


func test_routes_tab_groups_routes_by_town() -> void:
	var towns := MainMenu.route_towns(catalog.items(Catalog.ROUTES))
	assert_eq(towns["starter_a"], "Puerto Marisol")
	assert_eq(towns["cafeto_c0"], "Alto Cafeto")


func test_the_small_town_runs_less_traffic_than_the_city() -> void:
	assert_almost_eq(TrafficSystem.map_traffic_share(map_data), 0.55, 0.001)
	assert_eq(TrafficSystem.map_traffic_share(MapLoader.read_json("res://data/packs/colombia/maps/puerto_marisol.json")), 1.0)
	assert_eq(TrafficSystem.map_traffic_share({"traffic_share": "lots"}), 1.0, "Bad data falls back")


func test_the_intro_scene_sets_up_in_a_town_without_its_streets() -> void:
	var network := RoadNetwork.from_data(map_data)
	var ground := MapLoader.build_ground(map_data, network)
	var intro := IntroCutscene.new()
	var spot: Vector3 = intro._road_point(network, ground, "market_street", 70.0)
	assert_true(spot.is_finite())
	intro.free()


## Builds the whole town as a shift does, with the starter route's bays.
func _built_town() -> Dictionary:
	var route_data := MapLoader.read_json("res://data/packs/colombia/routes/cafeto_c0.json")
	var network := RoadNetwork.from_data(map_data)
	var route := RouteRunner.build(route_data, network, 7, map_data)
	for stop in route.stops:
		if stop.kind == RouteStop.Kind.BAY:
			network.add_bay(stop.road, stop.along, stop.dir)
	var ground := MapLoader.build_ground(map_data, network)
	var city := CityBuilder.new()
	add_child_autofree(city)
	city.build(map_data, network, ground, route)
	return {"city": city, "network": network, "ground": ground}


func test_church_and_mirador_come_from_map_data() -> void:
	var kinds := (map_data["landmarks"] as Array).map(func(entry: Dictionary) -> String: return entry["kind"])
	assert_eq(kinds, ["church", "mirador"])
	var town := _built_town()
	var city: CityBuilder = town["city"]
	assert_eq(city.landmarks.size(), 2, "Both landmarks build")
	var network: RoadNetwork = town["network"]
	var church: Dictionary = city.landmarks[0]
	var mirador: Dictionary = city.landmarks[1]
	assert_lt(church["centre"].distance_to(network.nodes["c"]["position"]), 60.0, "The church is on the Plaza")
	assert_lt(mirador["centre"].distance_to(network.nodes["e"]["position"]), 45.0, "The mirador is at the top of the climb")


func test_landmarks_stand_clear_of_roads_bays_and_the_plaza() -> void:
	var town := _built_town()
	var city: CityBuilder = town["city"]
	var network: RoadNetwork = town["network"]
	for landmark: Dictionary in city.landmarks:
		for point: Vector2 in landmark["footprint"]:
			assert_gt(network.edge_distance(point), GroundSurface.PAVEMENT_WIDTH, "%s at %s is off the asphalt and pavement" % [landmark["kind"], point])


func test_landmarks_do_not_overlap_buildings() -> void:
	var town := _built_town()
	var city: CityBuilder = town["city"]
	assert_gt(city.building_count, 40, "The town still has its houses")
	for landmark: Dictionary in city.landmarks:
		var centre: Vector2 = landmark["centre"]
		for taken: Vector3 in city._taken:
			var other := Vector2(taken.x, taken.y)
			if other == centre:
				continue
			assert_gte(centre.distance_to(other), float(landmark["reach"]) + taken.z - 0.01, "%s clear of the building at %s" % [landmark["kind"], other])


func test_landmarks_stand_on_the_terrain() -> void:
	var town := _built_town()
	var city: CityBuilder = town["city"]
	var ground: GroundSurface = town["ground"]
	for landmark: Dictionary in city.landmarks:
		var kind: String = landmark["kind"]
		for point: Vector2 in landmark["footprint"]:
			var y := ground.terrain_height(point)
			assert_lt(float(landmark["lowest"]), y, "%s reaches into the ground at %s" % [kind, point])
			assert_gt(float(landmark["floor"]), y, "%s floor is above the ground at %s" % [kind, point])
		var centre_y := ground.terrain_height(landmark["centre"])
		assert_lt(float(landmark["floor"]) - centre_y, 4.0, "%s is not floating" % kind)
