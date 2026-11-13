extends GutTest

const MAPS := [
	"res://data/packs/colombia/maps/puerto_marisol.json",
	"res://data/packs/colombia/maps/alto_cafeto.json",
	"res://data/packs/colombia/maps/puerto_remanso.json",
]


func test_every_stall_in_every_map_gets_exactly_one_vendor() -> void:
	for map_path in MAPS:
		var map_data: Dictionary = MapLoader.read_json(map_path)
		var network := RoadNetwork.from_data(map_data, Country.pack.traffic_side, Country.pack.default_speed_limit())
		var ground := MapLoader.build_ground(map_data, network)
		var obstacles := ObstacleField.new()
		var spec := BusSpec.new()
		obstacles.setup(map_data, network, ground, spec)
		var life := StreetLife.new()
		life.setup(network, ground, null, 1.0, obstacles)

		var stalls := obstacles.stalls()
		assert_gt(stalls.size(), 0, "Map %s has stalls" % map_path)
		assert_eq(life.vendors.size(), stalls.size(), "One vendor per stall on %s" % map_path)
		assert_eq(obstacles.vendors.size(), stalls.size(), "Obstacles references vendors on %s" % map_path)

		for stall in stalls:
			assert_not_null(stall.vendor, "Stall has a vendor")
			var vendor: StreetLife.Vendor = stall.vendor
			assert_eq(vendor.stall, stall, "Vendor references its stall")
			var stall_2d := Vector2(stall.position.x, stall.position.z)
			var dist := vendor.position().distance_to(stall_2d)
			assert_lte(dist, 2.0, "Vendor placed within 2 m of stall on %s" % map_path)
			assert_gt(dist, stall.radius * 0.9, "Vendor stands outside cart body")
			assert_true(vendor.is_on_pavement(network), "Vendor stands on the pavement on %s" % map_path)
			assert_false(vendor.is_in_road(network), "Vendor is not in the road on %s" % map_path)
			assert_false(vendor.is_inside_stall(stall), "Vendor is not inside the stall")
			assert_not_null(vendor.look, "Vendor has an assigned look")

		obstacles.free()
		life.free()


func test_vendors_persist_after_rain_toggle() -> void:
	var map_data: Dictionary = MapLoader.read_json("res://data/packs/colombia/maps/puerto_marisol.json")
	var network := RoadNetwork.from_data(map_data, Country.pack.traffic_side, Country.pack.default_speed_limit())
	var ground := MapLoader.build_ground(map_data, network)
	var obstacles := ObstacleField.new()
	var spec := BusSpec.new()
	obstacles.setup(map_data, network, ground, spec)
	var life := StreetLife.new()
	life.setup(network, ground, null, 1.0, obstacles)

	var stall_count := obstacles.stalls().size()
	assert_eq(life.vendors.size(), stall_count)

	# Toggle rain ON (downpour)
	var rain_settings := RainSettings.from_data(Country.pack.data.get("weather", {}).get("rain", {}))
	var times := TimeOfDay.list_for(Country.pack.data)
	var time_day := TimeOfDay.find(times, "mediodia")
	var plan_wet := WeatherPlan.make(7, time_day, rain_settings, 500.0, WeatherPlan.FORCE_RAIN)
	var wet_clock := WeatherClock.new(plan_wet, rain_settings, time_day)
	wet_clock.rain = 1.0
	life._on_weather(wet_clock)

	assert_eq(life.vendors.size(), stall_count, "Vendors still present in rain")
	assert_gte(life._batches[0].visible_instance_count, stall_count, "All vendors visible in rain")
	assert_gte(life._umbrellas.visible_instance_count, stall_count, "Umbrellas active in rain")
	for vendor in life.vendors:
		assert_true(vendor.carries_umbrella, "Vendor has umbrella in rain")

	# Toggle rain OFF (dry)
	var plan_dry := WeatherPlan.make(7, time_day, rain_settings, 500.0, WeatherPlan.FORCE_DRY)
	var dry_clock := WeatherClock.new(plan_dry, rain_settings, time_day)
	dry_clock.rain = 0.0
	life._on_weather(dry_clock)

	assert_eq(life.vendors.size(), stall_count, "Vendors still present after rain stops")
	assert_gte(life._batches[0].visible_instance_count, stall_count, "All vendors visible when dry")
	assert_eq(life._umbrellas.visible_instance_count, 0, "Umbrellas stowed when dry")
	for vendor in life.vendors:
		assert_false(vendor.carries_umbrella, "Vendor stows umbrella when dry")

	obstacles.free()
	life.free()


func test_vendors_at_low_graphics_quality() -> void:
	var prev_quality: int = GameSettings.graphics_quality
	GameSettings.graphics_quality = GraphicsQuality.Level.LOW

	var map_data: Dictionary = MapLoader.read_json("res://data/packs/colombia/maps/alto_cafeto.json")
	var network := RoadNetwork.from_data(map_data, Country.pack.traffic_side, Country.pack.default_speed_limit())
	var ground := MapLoader.build_ground(map_data, network)
	var obstacles := ObstacleField.new()
	var spec := BusSpec.new()
	obstacles.setup(map_data, network, ground, spec)
	var life := StreetLife.new()
	life.setup(network, ground, null, 1.0, obstacles)

	var stall_count := obstacles.stalls().size()
	assert_eq(life.vendors.size(), stall_count, "LOW quality keeps every stall vendor")
	for vendor in life.vendors:
		assert_true(vendor.is_on_pavement(network), "Vendor remains on pavement at LOW quality")

	GameSettings.graphics_quality = prev_quality
	obstacles.free()
	life.free()


func test_knocked_stall_vendor_steps_back_out_of_the_way() -> void:
	for map_path in MAPS:
		var map_data: Dictionary = MapLoader.read_json(map_path)
		var network := RoadNetwork.from_data(map_data, Country.pack.traffic_side, Country.pack.default_speed_limit())
		var ground := MapLoader.build_ground(map_data, network)
		var obstacles := ObstacleField.new()
		var spec := BusSpec.new()
		obstacles.setup(map_data, network, ground, spec)
		var life := StreetLife.new()
		life.setup(network, ground, null, 1.0, obstacles)

		for stall in obstacles.stalls():
			var vendor: StreetLife.Vendor = stall.vendor
			var initial_stall_pos := Vector2(stall.position.x, stall.position.z)
			var standing_vendor_pos := vendor.position()

			# Bus knocks the stall
			stall.hit(Vector2(6.0, 0.0), Vector2(1.0, 0.0))

			assert_true(stall.is_knocked(), "Stall is knocked")
			assert_true(vendor.stepped_back, "Vendor stepped back on knock")
			assert_ne(vendor.position(), standing_vendor_pos, "Vendor moved away from standing spot")
			assert_false(vendor.is_inside_stall(stall), "Vendor is not inside the stall")
			assert_false(vendor.is_in_road(network), "Vendor is not inside the road on %s" % map_path)
			assert_lte(vendor.position().distance_to(initial_stall_pos), 2.0, "Vendor stays near the stall (within 2 m)")

		obstacles.free()
		life.free()


func test_reused_instanced_batches_no_extra_draw_calls() -> void:
	var map_data: Dictionary = MapLoader.read_json("res://data/packs/colombia/maps/puerto_marisol.json")
	var network := RoadNetwork.from_data(map_data, Country.pack.traffic_side, Country.pack.default_speed_limit())
	var ground := MapLoader.build_ground(map_data, network)
	var obstacles := ObstacleField.new()
	var spec := BusSpec.new()
	obstacles.setup(map_data, network, ground, spec)
	var life := StreetLife.new()
	life.setup(network, ground, null, 1.0, obstacles)

	# Batches are clothes, skin, hair
	assert_eq(life._batches.size(), 3, "Exactly three person batches reused")
	var expected_total := life.vendors.size() + life.strollers.size()
	assert_eq(life._batches[0].instance_count, expected_total, "Batches combine vendors and strollers")
	assert_eq(life._umbrellas.instance_count, expected_total, "Umbrellas batch covers vendors and strollers")

	obstacles.free()
	life.free()
