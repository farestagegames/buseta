extends GutTest

const DT := 1.0 / 60.0

var spec: BusSpec
var bus: BusPhysicsModel


func before_each() -> void:
	spec = BusSpec.new()
	bus = BusPhysicsModel.new(spec)


func _run(steer: float, throttle: float, brake: float, seconds: float, dt: float = DT) -> void:
	for i in int(round(seconds / dt)):
		bus.step(steer, throttle, brake, dt)


func _seconds_to_reach(target_speed: float) -> float:
	var time := 0.0
	while bus.speed < target_speed and time < 120.0:
		bus.step(0.0, 1.0, 0.0, DT)
		time += DT
	return time


func test_bus_stays_still_with_no_input() -> void:
	_run(0.0, 0.0, 0.0, 2.0)
	assert_eq(bus.speed, 0.0)
	assert_eq(bus.position, Vector2.ZERO)


func test_reaches_50_kmh_in_a_believable_time() -> void:
	var time := _seconds_to_reach(13.9)
	assert_between(time, 10.0, 20.0, "0-50 km/h should take a heavy bus 10-20 s")


func test_acceleration_builds_up_rather_than_jumping() -> void:
	bus.step(0.0, 1.0, 0.0, DT)
	assert_lt(bus.throttle, 0.1, "Accelerator pedal input should lag")


func test_top_speed_is_never_exceeded() -> void:
	_run(0.0, 1.0, 0.0, 120.0)
	assert_lte(bus.speed, spec.top_speed)
	assert_gt(bus.speed, spec.top_speed * 0.85, "Bus should get close to top speed")


func test_bus_coasts_a_long_way() -> void:
	bus.speed = 13.9
	_run(0.0, 0.0, 0.0, 5.0)
	assert_gt(bus.speed, 10.0, "Momentum should carry the bus when coasting")


func test_coasting_eventually_stops() -> void:
	bus.speed = 5.0
	_run(0.0, 0.0, 0.0, 30.0)
	assert_eq(bus.speed, 0.0)


func test_full_brake_distance_from_50_kmh() -> void:
	bus.speed = 13.9
	var start := bus.position
	while bus.speed > 0.0:
		bus.step(0.0, 0.0, 1.0, DT)
	var distance := bus.position.distance_to(start)
	assert_between(distance, 22.0, 35.0, "Full braking from 50 km/h should need 22-35 m")


func test_braking_stops_without_rolling_backwards() -> void:
	bus.speed = 2.0
	_run(0.0, 0.0, 1.0, 3.0)
	assert_eq(bus.speed, 0.0)


func test_turning_circle_is_wide_at_low_speed() -> void:
	bus.speed = 2.0
	_run(1.0, 0.0, 0.0, 1.5)
	var radius := absf(bus.speed / bus.yaw_rate)
	assert_between(radius, 7.0, 9.0, "Rear axle radius should suit a 12 m bus")


func test_steering_right_turns_right() -> void:
	_run(0.0, 1.0, 0.0, 4.0)
	_run(1.0, 1.0, 0.0, 1.0)
	assert_lt(bus.heading, 0.0, "Right turn lowers heading")
	assert_gt(bus.position.x, 0.0, "Right turn moves toward +X")


func test_steering_takes_time() -> void:
	_run(1.0, 0.0, 0.0, 0.25)
	assert_almost_eq(rad_to_deg(bus.steer_angle), spec.steer_rate_degrees * 0.25, 1.5)


func test_lateral_acceleration_is_limited_at_speed() -> void:
	bus.speed = 15.0
	var highest := 0.0
	for i in 180:
		bus.step(1.0, 0.0, 0.0, DT)
		highest = maxf(highest, absf(bus.lateral_accel))
	assert_lte(highest, spec.max_lateral_accel + 0.01)


func test_reverse_goes_backwards_and_is_slow() -> void:
	assert_true(bus.toggle_direction())
	_run(0.0, 1.0, 0.0, 30.0)
	assert_lt(bus.speed, -1.0)
	assert_gte(bus.speed, -spec.top_speed_reverse)


func test_cannot_select_reverse_while_moving() -> void:
	bus.speed = 5.0
	assert_false(bus.toggle_direction())
	assert_eq(bus.direction, BusPhysicsModel.Direction.FORWARD)


func test_body_rolls_into_outside_of_turn_then_settles() -> void:
	bus.speed = 8.0
	_run(1.0, 0.3, 0.0, 2.0)
	assert_lt(bus.body_roll, -0.01, "Turning right leans the body left")
	_run(0.0, 0.0, 1.0, 6.0)
	assert_almost_eq(bus.body_roll, 0.0, 0.005)


func test_nose_dips_under_braking() -> void:
	bus.speed = 13.0
	_run(0.0, 0.0, 1.0, 1.0)
	assert_lt(bus.body_pitch, 0.0)


func test_no_drive_when_disabled_by_doors() -> void:
	bus.drive_enabled = false
	_run(0.0, 1.0, 0.0, 3.0)
	assert_eq(bus.speed, 0.0)


func test_handling_matches_between_30_and_60_fps() -> void:
	_run(0.3, 1.0, 0.0, 10.0, 1.0 / 60.0)
	var at_60 := bus.position
	bus = BusPhysicsModel.new(spec)
	_run(0.3, 1.0, 0.0, 10.0, 1.0 / 30.0)
	assert_lt(bus.position.distance_to(at_60), 2.5, "Paths should agree within 2.5 m")


func test_rear_overhang_swings_out_in_a_turn() -> void:
	bus.speed = 3.0
	_run(0.0, 0.2, 0.0, 1.0)
	var tail_local := Vector2(0.0, spec.rear_overhang)
	var travel_x := bus.position.x
	_run(1.0, 0.2, 0.0, 2.0)
	var tail_world := bus.position + tail_local.rotated(-bus.heading)
	assert_lt(tail_world.x, bus.position.x, "Tail sits on the outside of a right turn")
	assert_gt(bus.position.x, travel_x)


func test_external_speed_replaces_model_speed() -> void:
	bus.speed = 10.0
	bus.apply_external_speed(1.0)
	assert_eq(bus.speed, 1.0)
