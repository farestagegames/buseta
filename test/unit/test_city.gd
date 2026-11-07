extends GutTest
## Puerto Marisol: how the city's look and coast come from its data.

const MAP := "res://data/packs/colombia/maps/puerto_marisol.json"

var map_data: Dictionary


func before_each() -> void:
	map_data = MapLoader.read_json(MAP)


func test_theme_is_read_from_the_map() -> void:
	var theme := CityTheme.from_data(map_data)
	assert_gte(theme.walls.size(), 8, "A colourful city")
	assert_false(theme.chimneys, "Nobody needs a chimney on the Caribbean coast")
	assert_gt(theme.palm_share, 0.5)


func test_a_map_with_no_theme_still_gets_a_look() -> void:
	var theme := CityTheme.from_data({})
	assert_gt(theme.walls.size(), 0)
	assert_eq(theme.palm_share, 0.0)


func test_damaged_theme_values_are_ignored() -> void:
	var theme := CityTheme.from_data({"theme": {"sand": [1], "walls": []}})
	assert_eq(theme.sand, CityTheme.new().sand)
	assert_gt(theme.walls.size(), 0)


func test_city_has_a_coast_to_the_east() -> void:
	var ground := MapLoader.build_ground(map_data, RoadNetwork.from_data(map_data))
	assert_eq(ground.beach_share(Vector2(0.0, 0.0)), 0.0)
	assert_gt(ground.beach_share(Vector2(530.0, 0.0)), 0.0)


func test_ground_falls_below_the_sea_past_the_beach() -> void:
	var ground := MapLoader.build_ground(map_data, RoadNetwork.from_data(map_data))
	assert_lt(ground.terrain_height(Vector2(580.0, 0.0)), GroundSurface.SEA_LEVEL)


func test_every_road_stays_on_dry_land() -> void:
	var network := RoadNetwork.from_data(map_data)
	var ground := MapLoader.build_ground(map_data, network)
	for road: Dictionary in network.roads.values():
		for point: Vector2 in road["points"]:
			assert_eq(ground.beach_share(point + Vector2(RoadNetwork.ROAD_HALF_WIDTH + 3.0, 0.0)), 0.0, road["id"])


func test_a_map_without_a_coast_has_no_beach() -> void:
	var ground := GroundSurface.new()
	assert_eq(ground.beach_share(Vector2(9000.0, 0.0)), 0.0)


func test_city_has_more_speed_bumps_and_potholes_than_a_quiet_town() -> void:
	var bumps := (map_data["features"] as Array).filter(func(entry: Dictionary) -> bool: return entry["type"] == "speed_bump")
	var potholes := (map_data["features"] as Array).filter(func(entry: Dictionary) -> bool: return entry["type"] == "pothole")
	assert_gte(bumps.size(), 4)
	assert_gte(potholes.size(), 12)


func test_street_stalls_stand_on_the_pavement() -> void:
	var network := RoadNetwork.from_data(map_data)
	var stalls := (map_data["knockables"] as Array).filter(func(entry: Dictionary) -> bool: return entry["kind"] == "stall")
	assert_gte(stalls.size(), 20)
	for stall: Dictionary in stalls:
		var spot: Vector2 = network.sample(stall["road"], stall["along"], stall["lateral"], stall["dir"])["position"]
		assert_gt(network.edge_distance(spot), 0.5, "Stall on %s at %s" % [stall["road"], stall["along"]])


func test_palm_builds_a_mesh() -> void:
	var b := LowPolyBuilder.new()
	var random := RandomNumberGenerator.new()
	b.palm(Vector3.ZERO, 8.0, Vector2(0.5, 0.2), Color.BROWN, Color.GREEN, random)
	assert_gt(b.build(LowPolyBuilder.vertex_colour_material()).get_surface_count(), 0)


func test_motorbikes_are_counted_in_every_graphics_level() -> void:
	for level: int in GraphicsQuality.PROFILES:
		var profile: Dictionary = GraphicsQuality.PROFILES[level]
		assert_gt(int(profile["traffic_motos"]), 0)
		assert_gt(int(profile["pedestrians"]), 0)


func test_strollers_walk_and_turn_back_at_the_end_of_a_pavement() -> void:
	var stroller := StreetLife.Stroller.new()
	stroller.path = PackedVector2Array([Vector2.ZERO, Vector2(10.0, 0.0), Vector2(20.0, 0.0)])
	stroller.segment = 0
	stroller.heading = 1
	stroller.speed = 5.0
	stroller.walk(1.0)
	assert_almost_eq(stroller.position().x, 5.0, 0.01)
	for i in 10:
		stroller.walk(1.0)
	assert_between(stroller.position().x, 0.0, 20.0, "Stays on the pavement")
