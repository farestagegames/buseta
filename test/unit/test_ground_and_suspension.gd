extends GutTest

const DT := 1.0 / 60.0


func _flat_wheels() -> PackedFloat32Array:
	return PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func test_default_surface_is_flat() -> void:
	var ground := GroundSurface.new()
	assert_eq(ground.height_at(Vector2(123.0, -45.0)), 0.0)


func test_hill_peaks_at_its_centre_and_fades_out() -> void:
	var ground := GroundSurface.new()
	ground.add_hill(Vector2.ZERO, 100.0, 6.0)
	assert_almost_eq(ground.terrain_height(Vector2.ZERO), 6.0, 0.001)
	assert_almost_eq(ground.terrain_height(Vector2(50.0, 0.0)), 3.0, 0.01)
	assert_eq(ground.terrain_height(Vector2(101.0, 0.0)), 0.0)


func test_speed_bump_only_rises_inside_its_strip() -> void:
	var ground := GroundSurface.new()
	ground.add_speed_bump(Vector2.ZERO, Vector2.UP, 0.5, 3.0, 0.1)
	assert_almost_eq(ground.height_at(Vector2.ZERO), 0.1, 0.001)
	assert_eq(ground.height_at(Vector2(0.0, 2.0)), 0.0)
	assert_eq(ground.height_at(Vector2(4.0, 0.0)), 0.0)


func test_pothole_drops_below_ground() -> void:
	var ground := GroundSurface.new()
	ground.add_pothole(Vector2.ZERO, 0.6, 0.08)
	assert_almost_eq(ground.height_at(Vector2.ZERO), -0.08, 0.001)


func test_uphill_slows_the_bus_and_downhill_speeds_it_up() -> void:
	var up := BusPhysicsModel.new(BusSpec.new())
	var down := BusPhysicsModel.new(BusSpec.new())
	var flat := BusPhysicsModel.new(BusSpec.new())
	up.road_slope = 0.08
	down.road_slope = -0.08
	for model: BusPhysicsModel in [up, down, flat]:
		model.speed = 10.0
		for i in 120:
			model.step(0.0, 0.0, 0.0, DT)
	assert_lt(up.speed, flat.speed)
	assert_gt(down.speed, flat.speed)


func test_bus_rolls_back_on_a_hill_without_brakes() -> void:
	var bus := BusPhysicsModel.new(BusSpec.new())
	bus.road_slope = 0.08
	for i in 120:
		bus.step(0.0, 0.0, 0.0, DT)
	assert_lt(bus.speed, 0.0)


func test_brake_holds_the_bus_on_a_hill() -> void:
	var bus := BusPhysicsModel.new(BusSpec.new())
	bus.road_slope = 0.08
	for i in 240:
		bus.step(0.0, 0.0, 1.0, DT)
	assert_eq(bus.speed, 0.0)


func test_open_doors_hold_the_bus_on_a_hill() -> void:
	var bus := BusPhysicsModel.new(BusSpec.new())
	bus.road_slope = 0.08
	bus.drive_enabled = false
	for i in 240:
		bus.step(0.0, 0.0, 0.0, DT)
	assert_eq(bus.speed, 0.0)


func test_bus_can_pull_away_up_the_steepest_planned_hill() -> void:
	var bus := BusPhysicsModel.new(BusSpec.new())
	bus.road_slope = 0.09
	for i in 300:
		bus.step(0.0, 1.0, 0.0, DT)
	assert_gt(bus.speed, 2.0)


func test_suspension_matches_a_constant_slope() -> void:
	var sprung := BusSuspension.new(6.0, 2.2)
	sprung.snap(_flat_wheels())
	var wheels := PackedFloat32Array([0.6, 0.6, 0.0, 0.0])
	for i in 300:
		sprung.update(wheels, DT)
	assert_almost_eq(sprung.pitch, atan2(0.6, 6.0), 0.001)


func test_suspension_leans_toward_the_lower_side() -> void:
	var sprung := BusSuspension.new(6.0, 2.2)
	sprung.snap(_flat_wheels())
	var wheels := PackedFloat32Array([0.12, 0.0, 0.12, 0.0])
	for i in 300:
		sprung.update(wheels, DT)
	assert_gt(sprung.roll, 0.0, "Left wheels raised, so the body leans right")


func test_body_rocks_after_a_bump_then_settles() -> void:
	var sprung := BusSuspension.new(6.0, 2.2)
	sprung.snap(_flat_wheels())
	var peak := 0.0
	for i in 8:
		sprung.update(PackedFloat32Array([0.1, 0.1, 0.0, 0.0]), DT)
		peak = maxf(peak, absf(sprung.pitch))
	for i in 180:
		sprung.update(_flat_wheels(), DT)
		peak = maxf(peak, absf(sprung.pitch))
	assert_gt(peak, 0.005, "Body should visibly move")
	assert_almost_eq(sprung.pitch, 0.0, 0.001, "Body should settle")


func test_snap_starts_at_rest() -> void:
	var sprung := BusSuspension.new(6.0, 2.2)
	sprung.snap(PackedFloat32Array([3.0, 3.0, 2.4, 2.4]))
	assert_almost_eq(sprung.height, 2.4, 0.001)
	sprung.update(PackedFloat32Array([3.0, 3.0, 2.4, 2.4]), DT)
	assert_eq(sprung.jolt, 0.0)


func _drive_over_bump(speed: float) -> float:
	var ground := GroundSurface.new()
	ground.add_speed_bump(Vector2(0.0, 5.0), Vector2.UP, 0.45, 3.0, 0.1)
	var sprung := BusSuspension.new(6.0, 2.2)
	sprung.snap(_flat_wheels())
	var hardest := 0.0
	var position := 0.0
	while position < 12.0:
		position += speed * DT
		var front := ground.height_at(Vector2(0.0, position))
		var rear := ground.height_at(Vector2(0.0, position - 6.0))
		sprung.update(PackedFloat32Array([front, front, rear, rear]), DT)
		hardest = maxf(hardest, sprung.jolt)
	return hardest


func test_faster_over_a_bump_is_a_harder_jolt() -> void:
	var slow := _drive_over_bump(2.0)
	var fast := _drive_over_bump(12.0)
	assert_gt(fast, slow * 3.0)
	assert_gt(fast, BusSuspension.JOLT_THRESHOLD)
	assert_lt(slow, BusSuspension.JOLT_THRESHOLD, "A careful driver should not be jolted")


func test_climbing_a_smooth_hill_fast_is_not_a_jolt() -> void:
	var sprung := BusSuspension.new(6.0, 2.2)
	sprung.snap(_flat_wheels(), _flat_wheels())
	var height := 0.0
	for i in 120:
		height += 0.09 * 12.0 * DT
		var wheels := PackedFloat32Array([height + 0.54, height + 0.54, height, height])
		sprung.update(wheels, DT, _flat_wheels())
		assert_false(sprung.is_jolt())


func test_footprint_covers_nose_and_tail_only() -> void:
	var spec := BusSpec.new()
	var rear := Vector2.ZERO
	assert_true(BusFootprint.touches(rear, 0.0, spec, Vector2(0.0, -8.5), 0.1), "Near the nose")
	assert_true(BusFootprint.touches(rear, 0.0, spec, Vector2(0.0, 3.0), 0.1), "Rear overhang")
	assert_false(BusFootprint.touches(rear, 0.0, spec, Vector2(0.0, 5.0), 0.1), "Behind the bus")
	assert_false(BusFootprint.touches(rear, 0.0, spec, Vector2(3.0, -3.0), 0.1), "Beside the bus")


func test_footprint_turns_with_the_bus() -> void:
	var spec := BusSpec.new()
	assert_true(BusFootprint.touches(Vector2.ZERO, -PI / 2.0, spec, Vector2(6.0, 0.0), 0.1), "Facing +X")


func test_knocked_prop_flies_lands_and_rests() -> void:
	var prop := KnockableProp.new("cone", Vector3.ZERO, 0.3)
	prop.hit(Vector2(0.0, -8.0), Vector2(0.0, -1.0))
	assert_true(prop.is_moving())
	var highest := 0.0
	for i in 600:
		prop.update(DT, 0.0)
		highest = maxf(highest, prop.position.y)
	assert_gt(highest, 0.3, "Should leave the ground")
	assert_eq(prop.state, KnockableProp.State.SETTLED)
	assert_lt(prop.position.z, -1.0, "Should land ahead of the bus")


func test_faster_hit_throws_a_prop_further() -> void:
	var distances: Array[float] = []
	for speed: float in [2.0, 12.0]:
		var prop := KnockableProp.new("bin", Vector3.ZERO, 0.4)
		prop.hit(Vector2(speed, 0.0), Vector2.RIGHT)
		for i in 600:
			prop.update(DT, 0.0)
		distances.append(prop.position.x)
	assert_gt(distances[1], distances[0] * 2.0)


func test_standing_prop_does_not_move_on_its_own() -> void:
	var prop := KnockableProp.new("cone", Vector3(1.0, 0.0, 1.0), 0.3)
	prop.update(1.0, 0.0)
	assert_eq(prop.position, Vector3(1.0, 0.0, 1.0))
