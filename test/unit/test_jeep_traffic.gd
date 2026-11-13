extends GutTest
## Willys jeeps in the mountain town's traffic: Alto Cafeto turns a share of its
## cars into jeeps, Puerto Marisol keeps its plain sedans, and the jeep mesh
## stays within the car footprint.

const ALTO := "res://data/packs/colombia/maps/alto_cafeto.json"
const MARISOL := "res://data/packs/colombia/maps/puerto_marisol.json"


func _traffic(map_path: String, mix: Variant = null) -> TrafficSystem:
	var map_data := MapLoader.read_json(map_path)
	if mix != null:
		map_data["vehicle_mix"] = mix
	var network := RoadNetwork.from_data(map_data, Country.pack.traffic_side, Country.pack.default_speed_limit())
	var ground := MapLoader.build_ground(map_data, network)
	var traffic := TrafficSystem.new()
	add_child_autofree(traffic)
	traffic.setup(map_data, network, ground, BusSpec.new(), 1.0)
	return traffic


func _car_total(traffic: TrafficSystem) -> int:
	return traffic.agents.filter(func(agent: TrafficAgent) -> bool: return not agent.is_moto).size()


func _jeep_total(traffic: TrafficSystem) -> int:
	return traffic.agents.filter(func(agent: TrafficAgent) -> bool: return agent.is_jeep).size()


func test_vehicle_jeep_share_reads_the_map_field() -> void:
	assert_almost_eq(TrafficSystem.vehicle_jeep_share(MapLoader.read_json(ALTO)), 0.4, 0.001)
	assert_eq(TrafficSystem.vehicle_jeep_share(MapLoader.read_json(MARISOL)), 0.0)
	assert_eq(TrafficSystem.vehicle_jeep_share({}), 0.0, "Missing field means no jeeps")
	assert_eq(TrafficSystem.vehicle_jeep_share({"vehicle_mix": {}}), 0.0, "An empty mix means no jeeps")
	assert_eq(TrafficSystem.vehicle_jeep_share({"vehicle_mix": {"jeep": "some"}}), 0.0, "Bad data falls back")
	assert_eq(TrafficSystem.vehicle_jeep_share({"vehicle_mix": {"jeep": 3.0}}), 1.0, "Shares clamp to one")


func test_alto_cafeto_spawns_jeeps_at_the_configured_share() -> void:
	var traffic := _traffic(ALTO)
	var car_total := _car_total(traffic)
	var jeep_total := _jeep_total(traffic)
	assert_gt(car_total, 0, "The town has cars")
	assert_gt(jeep_total, 0, "Some of them are jeeps")
	assert_lt(jeep_total, car_total, "Not every car is a jeep")
	assert_eq(jeep_total + traffic.agents.filter(func(a: TrafficAgent) -> bool: return not a.is_moto and not a.is_jeep).size(), car_total)
	assert_lt(absf(float(jeep_total) / float(car_total) - 0.4), 0.25, "Roughly the configured share")
	assert_not_null(traffic._jeep_batch, "Jeeps have their own batch")


func test_jeep_batches_and_car_batches_are_contiguous() -> void:
	var traffic := _traffic(ALTO)
	for agent in traffic.agents:
		if agent.is_moto:
			continue
		var index := agent.batch_index
		if agent.is_jeep:
			assert_true(index >= 0 and index < traffic._jeep_batch.instance_count)
		else:
			assert_true(index >= 0 and index < traffic._batch.instance_count)


func test_puerto_marisol_spawns_no_jeeps_and_keeps_its_layout() -> void:
	var plain := _traffic(MARISOL)
	assert_eq(TrafficSystem.vehicle_jeep_share(MapLoader.read_json(MARISOL)), 0.0)
	assert_null(plain._jeep_batch, "No jeep batch without a mix")
	assert_eq(_jeep_total(plain), 0)
	var car_slot := 0
	for agent in plain.agents:
		if agent.is_moto:
			continue
		assert_false(agent.is_jeep)
		assert_eq(agent.batch_index, car_slot, "Batch indices stay as before")
		car_slot += 1
	# A zero share changes nothing: the same cars, the same spawn sequence.
	var zero := _traffic(MARISOL, {"jeep": 0})
	assert_eq(_jeep_total(zero), 0)
	assert_eq(_layout_of(plain), _layout_of(zero), "No extra random numbers are drawn for a zero share")


func test_a_present_mix_is_what_turns_cars_into_jeeps() -> void:
	var plain := _traffic(MARISOL)
	var mixed := _traffic(MARISOL, {"jeep": 0.4})
	assert_eq(_jeep_total(plain), 0)
	assert_gt(_jeep_total(mixed), 0, "The same city with a mix now has jeeps")


func test_the_jeep_mesh_builds_within_the_car_footprint() -> void:
	var field := ObstacleField.new()
	var car: ArrayMesh = field._mesh_for("car").build(LowPolyBuilder.vertex_colour_material())
	var jeep: ArrayMesh = field._mesh_for("jeep").build(LowPolyBuilder.vertex_colour_material())
	field.free()
	var bounds := jeep.get_aabb().size
	assert_lt(bounds.x, 2.0, "No wider than a car (half width under a metre)")
	assert_lt(bounds.z, TrafficAgent.CAR_LENGTH + 0.05, "No longer than a car")
	assert_gt(bounds.y, 0.5, "A real vehicle height")
	assert_lt(bounds.y, 2.0, "Not a van")
	var car_bounds := car.get_aabb().size
	assert_lt(bounds.z, car_bounds.z, "A jeep is shorter than the sedan it replaces")


func _layout_of(traffic: TrafficSystem) -> Array:
	var layout := []
	for agent in traffic.agents:
		layout.append([agent.is_moto, agent.is_jeep, agent.lane, agent.distance, agent.cruise])
	return layout
