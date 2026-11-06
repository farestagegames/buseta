extends GutTest

const DT := 1.0 / 60.0

var mapper: SteeringMapper


func before_each() -> void:
	mapper = SteeringMapper.new()


func _tilt(degrees: float, seconds: float = 1.0) -> float:
	var radians := deg_to_rad(degrees)
	var gravity := Vector3(sin(radians), -cos(radians), 0.0) * 9.8
	var result := 0.0
	for i in int(ceil(seconds / DT)):
		result = mapper.update_tilt(gravity, DT)
	return result


func test_wheel_centre_is_straight() -> void:
	assert_eq(mapper.update_wheel(0.0), 0.0)


func test_wheel_full_rotation_is_full_lock() -> void:
	assert_eq(mapper.update_wheel(1.0), 1.0)
	assert_eq(mapper.update_wheel(-1.0), -1.0)


func test_wheel_curve_gives_finer_control_near_centre() -> void:
	assert_lt(mapper.update_wheel(0.5), 0.5)


func test_wheel_sensitivity_reaches_lock_sooner() -> void:
	mapper.sensitivity = 2.0
	assert_eq(mapper.update_wheel(0.5), 1.0)


func test_sensitivity_is_clamped() -> void:
	mapper.sensitivity = 50.0
	assert_eq(mapper.sensitivity, SteeringMapper.MAX_SENSITIVITY)


func test_tilt_dead_zone_ignores_small_movement() -> void:
	assert_eq(_tilt(1.0), 0.0)


func test_tilt_to_the_right_steers_right() -> void:
	assert_gt(_tilt(15.0), 0.0)


func test_tilt_full_lock() -> void:
	assert_almost_eq(_tilt(40.0), 1.0, 0.001)


func test_tilt_can_be_inverted() -> void:
	mapper.invert_tilt = true
	assert_lt(_tilt(15.0), 0.0)


func test_tilt_works_with_phone_leaned_back() -> void:
	var radians := deg_to_rad(15.0)
	var along_screen := cos(radians) * sqrt(0.5)
	var leaned_back := Vector3(sin(radians), -along_screen, -along_screen) * 9.8
	var upright := _tilt(15.0)
	mapper = SteeringMapper.new()
	var result := 0.0
	for i in 60:
		result = mapper.update_tilt(leaned_back, DT)
	assert_almost_eq(result, upright, 0.01)


func test_tilt_filter_smooths_a_sudden_change() -> void:
	assert_lt(_tilt(30.0, DT), 0.5)


func test_buttons_ramp_up_gradually() -> void:
	mapper.update_buttons(false, true, DT)
	assert_between(mapper.steer, 0.0, 0.1)
	for i in 120:
		mapper.update_buttons(false, true, DT)
	assert_eq(mapper.steer, 1.0)


func test_buttons_recentre_on_release() -> void:
	for i in 60:
		mapper.update_buttons(true, false, DT)
	for i in 120:
		mapper.update_buttons(false, false, DT)
	assert_eq(mapper.steer, 0.0)


func test_both_buttons_cancel_out() -> void:
	for i in 30:
		mapper.update_buttons(true, true, DT)
	assert_eq(mapper.steer, 0.0)


func test_button_sensitivity_changes_ramp_speed() -> void:
	mapper.sensitivity = 2.0
	mapper.update_buttons(false, true, 0.1)
	var fast := mapper.steer
	mapper = SteeringMapper.new()
	mapper.update_buttons(false, true, 0.1)
	assert_gt(fast, mapper.steer)


func test_wheel_tracker_follows_finger() -> void:
	var wheel := WheelTracker.new()
	wheel.press(Vector2(100, 0))
	wheel.drag(Vector2(0, 100)) # Clockwise on screen, Y points down.
	assert_almost_eq(wheel.rotation_degrees, 90.0, 0.01)
	assert_gt(wheel.normalised(), 0.0)


func test_wheel_tracker_grab_does_not_jump() -> void:
	var wheel := WheelTracker.new()
	wheel.press(Vector2(0, 100))
	assert_eq(wheel.rotation_degrees, 0.0)


func test_wheel_tracker_crosses_the_angle_wrap() -> void:
	var wheel := WheelTracker.new()
	wheel.press(Vector2(-100, 10))
	wheel.drag(Vector2(-100, -10))
	assert_almost_eq(wheel.rotation_degrees, 11.4, 0.1)


func test_wheel_tracker_stops_at_the_limit() -> void:
	var wheel := WheelTracker.new()
	wheel.press(Vector2(100, 0))
	for i in range(1, 40):
		wheel.drag(Vector2(100, 0).rotated(deg_to_rad(i * 30.0)))
	assert_eq(wheel.rotation_degrees, WheelTracker.MAX_ROTATION_DEGREES)


func test_wheel_tracker_ignores_finger_near_centre() -> void:
	var wheel := WheelTracker.new()
	wheel.press(Vector2(100, 0))
	wheel.drag(Vector2(0, 2))
	assert_eq(wheel.rotation_degrees, 0.0)


func test_wheel_tracker_recentres_only_after_release() -> void:
	var wheel := WheelTracker.new()
	wheel.press(Vector2(100, 0))
	wheel.drag(Vector2(0, 100))
	wheel.update(1.0)
	assert_almost_eq(wheel.rotation_degrees, 90.0, 0.01)
	wheel.release()
	wheel.update(1.0)
	assert_eq(wheel.rotation_degrees, 0.0)
