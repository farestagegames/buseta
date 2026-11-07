extends GutTest
## The Colombian fleet: buses, the articulated joint and painted liveries.

var catalog: Catalog


func before_each() -> void:
	catalog = Catalog.new()


func _spec(id: String) -> BusSpec:
	return load(catalog.find(Catalog.BUSES, id)["file"])


func test_starter_bus_is_a_free_buseta() -> void:
	var item := catalog.find(Catalog.BUSES, PlayerProfile.DEFAULT_BUS)
	assert_eq(int(item["cost"]), 0)
	assert_eq(_spec(PlayerProfile.DEFAULT_BUS).body_style, "buseta")
	assert_lt(_spec(PlayerProfile.DEFAULT_BUS).overall_length(), 9.0)


func test_chiva_is_a_special_unlock() -> void:
	var item := catalog.find(Catalog.BUSES, "chiva")
	assert_gt(int(item["cost"]), 0)
	assert_gt(int(item["level"]), 1)
	assert_eq(_spec("chiva").body_style, "chiva")


func test_chiva_needs_the_level_as_well_as_the_money() -> void:
	var profile := PlayerProfile.new()
	var item := catalog.find(Catalog.BUSES, "chiva")
	profile.coins = 100000
	assert_false(profile.buy(Catalog.BUSES, item), "Level 1 cannot buy it")
	profile.xp = DriverLevel.xp_for_level(int(item["level"]))
	assert_true(profile.buy(Catalog.BUSES, item))


func test_articulated_bus_is_18_metres() -> void:
	var spec := _spec("articulado_18")
	assert_true(spec.is_articulated())
	assert_between(spec.full_length(), 17.5, 19.0)


func test_no_real_bus_brands_in_the_catalog() -> void:
	var text := FileAccess.get_file_as_string(Country.pack.content_path("catalog")).to_lower()
	for brand: String in ["mercedes", "volvo", "scania", "hino", "chevrolet", "busscar", "marcopolo", "superpolo", "transmilenio", "transmetro", "transcaribe", "mio ", "megabús"]:
		assert_false(text.contains(brand), brand)


func test_at_least_eight_liveries_with_patterns() -> void:
	var liveries: Array = catalog.items(Catalog.LIVERIES)
	assert_gte(liveries.size(), 8)
	var patterns := {}
	for item: Dictionary in liveries:
		patterns[item["pattern"]] = true
		assert_true(item.has("accent"), item["id"])
	assert_gte(patterns.size(), 5, "Decorated, not just recoloured")


func test_every_pattern_paints_every_body() -> void:
	var patterns := ["plain", "bands", "zigzag", "waves", "diamonds", "chevrons", "sunburst", "flowers"]
	for item: Dictionary in catalog.items(Catalog.BUSES):
		for pattern: String in patterns:
			var spec: BusSpec = (load(item["file"]) as BusSpec).duplicate()
			spec.pattern = pattern
			var visual := BusVisual.new()
			visual.spec = spec
			add_child_autofree(visual)
			assert_gt(visual.get_child_count(), 0, "%s %s" % [item["id"], pattern])


func test_spec_takes_the_paint_from_a_livery() -> void:
	var spec := CityShift.spec_for(catalog.find(Catalog.BUSES, "buseta_8"), catalog.find(Catalog.LIVERIES, "carnaval"))
	assert_eq(spec.pattern, "zigzag")
	assert_almost_eq(spec.body_colour.r, 0.86, 0.01)


func test_spec_is_a_copy_of_the_shared_data() -> void:
	CityShift.spec_for(catalog.find(Catalog.BUSES, "buseta_8"), catalog.find(Catalog.LIVERIES, "carnaval"))
	assert_ne(_spec("buseta_8").pattern, "zigzag")


func _articulated() -> BusPhysicsModel:
	return BusPhysicsModel.new(_spec("articulado_18"))


func test_trailer_starts_straight_behind() -> void:
	var bus := _articulated()
	bus.reset(Vector2(10.0, 20.0), 0.0)
	assert_almost_eq(bus.articulation(), 0.0, 0.001)
	assert_gt(bus.trailer_axle.y, bus.position.y, "Behind the front section, which faces -Z")


func test_trailer_keeps_its_length_from_the_joint() -> void:
	var bus := _articulated()
	var spec := _spec("articulado_18")
	for i in 600:
		bus.step(0.6, 0.4, 0.0, 1.0 / 60.0)
	var joint := bus.position - bus.forward_vector() * spec.hitch_offset
	assert_almost_eq(joint.distance_to(bus.trailer_axle), spec.trailer_wheelbase, 0.02)


func test_trailer_folds_in_a_turn_and_never_past_the_limit() -> void:
	var bus := _articulated()
	var most := 0.0
	for i in 900:
		bus.step(1.0, 0.5, 0.0, 1.0 / 60.0)
		most = maxf(most, absf(bus.articulation()))
	assert_gt(most, 0.2, "The joint folds")
	assert_lte(most, BusPhysicsModel.MAX_ARTICULATION + 0.001)


func test_trailer_straightens_out_again() -> void:
	var bus := _articulated()
	bus.speed = 6.0
	for i in 200:
		bus.step(0.8, 0.4, 0.0, 1.0 / 60.0)
	for i in 900:
		bus.step(0.0, 0.5, 0.0, 1.0 / 60.0)
	assert_almost_eq(bus.articulation(), 0.0, 0.03)


func test_rigid_buses_have_no_trailer_to_move() -> void:
	var bus := BusPhysicsModel.new(_spec("buseta_8"))
	var before := bus.trailer_axle
	for i in 60:
		bus.step(0.5, 1.0, 0.0, 1.0 / 60.0)
	assert_eq(bus.trailer_axle, before)


func test_rear_section_can_be_hit() -> void:
	var spec := _spec("articulado_18")
	assert_true(BusFootprint.touches_trailer(Vector2.ZERO, 0.0, spec, Vector2(1.0, 2.0), 0.1), "Beside the tail")
	assert_false(BusFootprint.touches_trailer(Vector2.ZERO, 0.0, spec, Vector2(3.0, 0.0), 0.1), "Clear to one side")
