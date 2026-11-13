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
	var cluster_ids: Array = (map_data["bird_clusters"] as Array).map(func(c: Dictionary) -> String: return c["id"])
	assert_true(cluster_ids.has("cafetal_entrada"), "Bird cluster exists near coffee grove entrance")
	assert_true(cluster_ids.has("mirador_canopy"), "Bird cluster exists near mirador")
	assert_true(cluster_ids.has("plaza_aromas"), "Bird cluster exists near plaza")
	for cluster: Dictionary in map_data["bird_clusters"]:
		assert_lt(absf(float(cluster["x"])), 300.0, cluster["id"])
		assert_lt(absf(float(cluster["z"])), 300.0, cluster["id"])


func test_fog_scale_is_1_35_at_dawn_and_morning_and_unchanged_elsewhere() -> void:
	var puerto_map := MapLoader.read_json("res://data/packs/colombia/maps/puerto_marisol.json")
	var alto_theme := CityTheme.from_data(map_data)
	var puerto_theme := CityTheme.from_data(puerto_map)
	assert_almost_eq(alto_theme.fog_scale, 1.35, 0.001)
	assert_almost_eq(puerto_theme.fog_scale, 1.0, 0.001)

	var alto_times := TimeOfDay.list_for(Country.pack.data, alto_theme)
	var puerto_times := TimeOfDay.list_for(Country.pack.data, puerto_theme)

	var alto_by_id := {}
	for t in alto_times:
		alto_by_id[t.id] = t
	var puerto_by_id := {}
	for t in puerto_times:
		puerto_by_id[t.id] = t

	# Dawn and morning are scaled by 1.35x on Alto Cafeto
	assert_almost_eq(alto_by_id["madrugada"].fog_scale, puerto_by_id["madrugada"].fog_scale * 1.35, 0.001)
	assert_almost_eq(alto_by_id["manana"].fog_scale, puerto_by_id["manana"].fog_scale * 1.35, 0.001)
	assert_almost_eq(alto_by_id["madrugada"].fog_scale, 2.16, 0.001)
	assert_almost_eq(alto_by_id["manana"].fog_scale, 1.35, 0.001)

	# Midday, sunset, and night are unchanged on Alto Cafeto
	assert_almost_eq(alto_by_id["mediodia"].fog_scale, puerto_by_id["mediodia"].fog_scale, 0.001)
	assert_almost_eq(alto_by_id["atardecer"].fog_scale, puerto_by_id["atardecer"].fog_scale, 0.001)
	assert_almost_eq(alto_by_id["noche"].fog_scale, puerto_by_id["noche"].fog_scale, 0.001)

	# Puerto Marisol is unchanged from the pack values
	assert_almost_eq(puerto_by_id["madrugada"].fog_scale, 1.6, 0.001)
	assert_almost_eq(puerto_by_id["manana"].fog_scale, 1.0, 0.001)
	assert_almost_eq(puerto_by_id["mediodia"].fog_scale, 1.0, 0.001)
	assert_almost_eq(puerto_by_id["atardecer"].fog_scale, 1.2, 0.001)
	assert_almost_eq(puerto_by_id["noche"].fog_scale, 1.0, 0.001)


func test_no_sea_layer_on_alto_cafeto_map() -> void:
	assert_false(map_data.has("coast"))
	var ground := MapLoader.build_ground(map_data, RoadNetwork.from_data(map_data))
	assert_eq(ground.coast_x, GroundSurface.NO_COAST)
	assert_eq(AmbienceMixer.distance_to_sea(0.0, ground.coast_x), INF)
	var sea_layer := {"id": "sea", "rule": "sea", "near": 25.0, "far": 230.0, "volume_db": -9.0}
	var mixer := AmbienceMixer.new([sea_layer])
	mixer.sea_distance = AmbienceMixer.distance_to_sea(0.0, ground.coast_x)
	assert_eq(mixer.gain(sea_layer), 0.0, "Sea is silent without a coast")
	assert_eq(mixer.volume_db(sea_layer), AmbienceMixer.SILENT_DB)


func test_alto_cafeto_has_quieter_street_bed() -> void:
	var alto_overrides: Dictionary = map_data.get("ambience", {})
	assert_true(alto_overrides.has("city"), "Alto Cafeto defines ambience override for city bed")
	assert_lt(float(alto_overrides["city"]["volume_db"]), -12.0, "Street bed is quieter than Puerto Marisol (-12 dB)")
	assert_almost_eq(float(alto_overrides["city"]["volume_db"]), -16.0, 0.001)


func test_motorbike_ambience_remains_rare() -> void:
	var layers := Country.pack.ambience_layers()
	var moto_layer: Dictionary = {}
	for layer: Dictionary in layers:
		if layer.get("id") == "motorbike":
			moto_layer = layer
			break
	assert_false(moto_layer.is_empty(), "Motorbike layer exists")
	var every: Array = moto_layer.get("every", [])
	assert_eq(every.size(), 2)
	assert_gte(float(every[0]), 30.0, "Shortest interval is at least 30s")
	assert_gte(float(every[1]), 70.0, "Longest interval is at least 70s")
	assert_lte(float(moto_layer.get("volume_db", 0.0)), -15.0, "Motorbike volume is subtle")


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
	for route_id: String in ["cafeto_c0", "cafeto_c1", "cafeto_c2"]:
		var data := MapLoader.read_json(catalog.find(Catalog.ROUTES, route_id)["file"])
		for stop: Dictionary in data["stops"]:
			if stop.get("final", false):
				continue
			var road: Dictionary = network.roads[stop["road"]]
			var reach := RoadNetwork.BAY_LENGTH / 2.0 + RoadNetwork.BAY_TAPER
			var start_clear := float(network.nodes[road["from"]]["radius"])
			var end_clear := float(road["length"]) - float(network.nodes[road["to"]]["radius"])
			assert_gt(float(stop["along"]) - reach, start_clear, "%s: %s" % [route_id, stop["name"]])
			assert_lt(float(stop["along"]) + reach, end_clear, "%s: %s" % [route_id, stop["name"]])
			for car: Dictionary in map_data["parked_cars"]:
				if car["road"] == stop["road"] and int(car["dir"]) == int(stop["dir"]):
					assert_gt(absf(float(car["along"]) - float(stop["along"])), 21.0, "%s: %s" % [route_id, stop["name"]])


func test_mountain_routes_c1_and_c2_load_with_goals_and_stops() -> void:
	for route_id: String in ["cafeto_c1", "cafeto_c2"]:
		var item := catalog.find(Catalog.ROUTES, route_id)
		assert_false(item.is_empty(), route_id)
		var data := MapLoader.read_json(item["file"])
		assert_eq(data["map"], "maps/alto_cafeto.json", route_id)
		var goals: Array = data["goals"]
		assert_eq(goals.size(), 3, "%s goals count" % route_id)
		assert_eq(goals[0]["type"], "finish_under", "%s has time goal" % route_id)
		assert_gt(int(goals[0]["value"]), 450, "%s finish_under reasonable" % route_id)
		var runner := RouteRunner.build(data, RoadNetwork.from_data(map_data), 7, map_data)
		assert_eq(runner.stops.size(), 6, "%s stops count" % route_id)
		assert_eq(runner.stops[runner.stops.size() - 1].stop_name, "Patio Cafeto")
		assert_true(runner.stops[runner.stops.size() - 1].is_final)
		assert_gt(runner.stops[runner.stops.size() - 1].route_distance, 1500.0)


func test_alto_cafeto_unlock_chain() -> void:
	var profile := PlayerProfile.new()
	profile.grant_free_items(catalog)
	# Below level 5: locked
	assert_false(profile.can_play_route("cafeto_c0", catalog))
	assert_false(profile.can_play_route("cafeto_c1", catalog))
	assert_false(profile.can_play_route("cafeto_c2", catalog))
	# Reach level 5
	profile.xp = DriverLevel.xp_for_level(5)
	assert_true(profile.can_play_route("cafeto_c0", catalog), "C0 playable at level 5")
	assert_false(profile.can_play_route("cafeto_c1", catalog), "C1 locked until C0 complete")
	assert_false(profile.can_play_route("cafeto_c2", catalog), "C2 locked until bought")
	# Complete C0
	(profile.completed_routes as Array).append("cafeto_c0")
	var unlocked := catalog.unlocked_by("cafeto_c0", profile)
	assert_eq(unlocked.size(), 1)
	assert_eq(unlocked[0]["id"], "cafeto_c1")
	(profile.owned[Catalog.ROUTES] as Array).append("cafeto_c1")
	assert_true(profile.can_play_route("cafeto_c1", catalog), "C1 playable after C0 completed")
	# Buy C2 for 1,200 coins
	var c2_item := catalog.find(Catalog.ROUTES, "cafeto_c2")
	assert_eq(int(c2_item["cost"]), 1200)
	assert_eq(int(c2_item["level"]), 5)
	profile.coins = 1199
	assert_false(profile.buy(Catalog.ROUTES, c2_item))
	profile.coins = 1200
	assert_true(profile.buy(Catalog.ROUTES, c2_item))
	assert_true(profile.can_play_route("cafeto_c2", catalog), "C2 playable after purchase")


func test_mountain_routes_goals_score() -> void:
	var c1_data := MapLoader.read_json(catalog.find(Catalog.ROUTES, "cafeto_c1")["file"])
	var c1_good := {
		"time": 460.0,
		"counts": {"knocked": 0, "vendors": 2},
	}
	assert_eq(RouteGoals.stars_for(c1_data["goals"], c1_good), 3)
	var c1_bad := {
		"time": 580.0,
		"counts": {"knocked": 1, "vendors": 1},
	}
	assert_eq(RouteGoals.stars_for(c1_data["goals"], c1_bad), 0)

	var c2_data := MapLoader.read_json(catalog.find(Catalog.ROUTES, "cafeto_c2")["file"])
	var c2_good := {
		"time": 540.0,
		"counts": {"missed_stops": 0},
		"categories": {"satisfaction": 88.0},
	}
	assert_eq(RouteGoals.stars_for(c2_data["goals"], c2_good), 3)
	var c2_bad := {
		"time": 680.0,
		"counts": {"missed_stops": 1},
		"categories": {"satisfaction": 70.0},
	}
	assert_eq(RouteGoals.stars_for(c2_data["goals"], c2_bad), 0)


func test_alto_cafeto_opens_at_driver_level_five() -> void:
	var item := catalog.find(Catalog.ROUTES, "cafeto_c0")
	assert_eq(int(item["level"]), 5)
	assert_eq(int(item["cost"]), 0)
	var profile := PlayerProfile.new()
	profile.grant_free_items(catalog)
	assert_false(profile.can_play_route("cafeto_c0", catalog), "Locked for a new driver")
	profile.xp = DriverLevel.xp_for_level(5) - 1
	assert_false(profile.can_play_route("cafeto_c0", catalog))
	profile.xp = DriverLevel.xp_for_level(5)
	assert_true(profile.can_play_route("cafeto_c0", catalog), "Open at level 5")


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
	assert_eq(towns["cafeto_c1"], "Alto Cafeto")
	assert_eq(towns["cafeto_c2"], "Alto Cafeto")


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


func test_map_ambience_override_does_not_leak_into_the_pack() -> void:
	var director := AudioDirector.new()
	add_child_autofree(director)
	director.setup_street(0.0, PackedVector2Array(), PackedVector2Array(), map_data)
	var local_db := 0.0
	for layer: Dictionary in director.mixer.layers:
		if layer["id"] == "city":
			local_db = float(layer["volume_db"])
	assert_almost_eq(local_db, -16.0, 0.001, "the shift's street bed is quieter")
	for layer: Dictionary in Country.pack.ambience_layers():
		if layer["id"] == "city":
			assert_ne(float(layer["volume_db"]), -16.0, "the pack's own street bed is untouched")
