extends GutTest
## Runs the real test scene headless, driving it through the same signals the
## touch controls use.

const SCENE := preload("res://scenes/test/test_drive.tscn")

var scene: Node3D
var bus: BusController
var hud: DriveHud
var camera: CameraRig


func before_all() -> void:
	Profile.load_from("user://test_save_scene.json")


func before_each() -> void:
	GameSettings.steering_mode = SteeringMapper.Mode.WHEEL
	scene = SCENE.instantiate()
	add_child_autofree(scene)
	bus = scene.get_node("Bus")
	hud = scene.get_node("Hud")
	camera = scene.get_node("CameraRig")


func after_each() -> void:
	GameEvents.ui_pedals_changed.emit(0.0, 0.0)
	GameEvents.ui_wheel_changed.emit(0.0)


func _touch(index: int, point: Vector2, pressed: bool, zone: TouchZone) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	zone._input(event)


func test_bus_drives_forward_on_throttle() -> void:
	GameEvents.ui_pedals_changed.emit(1.0, 0.0)
	await wait_physics_frames(90)
	assert_lt(bus.global_position.z, -0.3, "Bus should move toward -Z")
	assert_gt(bus.model.speed, 0.5)


func test_steering_right_moves_bus_right() -> void:
	bus.model.speed = 6.0
	GameEvents.ui_wheel_changed.emit(1.0)
	await wait_physics_frames(60)
	assert_gt(bus.global_position.x, 0.3)
	assert_lt(bus.rotation.y, 0.0)


func test_doors_stop_the_bus_from_driving() -> void:
	GameEvents.door_toggle_requested.emit()
	GameEvents.ui_pedals_changed.emit(1.0, 0.0)
	await wait_physics_frames(45)
	assert_eq(bus.model.speed, 0.0)
	assert_false(bus.doors.is_closed())


func test_doors_refuse_to_open_while_moving() -> void:
	bus.model.speed = 8.0
	GameEvents.door_toggle_requested.emit()
	assert_true(bus.doors.is_closed())


func test_wall_stops_the_bus_and_reports_impact() -> void:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 4.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0.0, 2.0, -14.0)
	add_child_autofree(wall)
	watch_signals(GameEvents)
	bus.model.speed = 6.0
	await wait_physics_frames(90)
	assert_almost_eq(bus.model.speed, 0.0, 0.2, "Wall should stop the bus")
	assert_signal_emitted(GameEvents, "bus_collided")
	assert_gt(bus.global_position.z - bus.spec.wheelbase - bus.spec.front_overhang, -14.6, "Nose should not pass through the wall")


func test_reset_returns_bus_to_start() -> void:
	GameEvents.ui_pedals_changed.emit(1.0, 0.0)
	await wait_physics_frames(90)
	GameEvents.reset_requested.emit()
	assert_eq(bus.global_position, Vector3.ZERO)
	assert_eq(bus.model.speed, 0.0)


func test_camera_cycles_through_three_views_with_one_action() -> void:
	var seen: Array[String] = [camera.view_name()]
	for i in 2:
		GameEvents.camera_cycle_requested.emit()
		seen.append(camera.view_name())
	GameEvents.camera_cycle_requested.emit()
	assert_eq(seen, ["Close", "Far", "Cockpit"] as Array[String])
	assert_eq(camera.view_name(), "Close")


func test_cockpit_camera_sits_inside_the_bus() -> void:
	camera.view_index = 0
	await wait_frames(2)
	var local := bus.global_transform.affine_inverse() * camera.global_position
	assert_lt(absf(local.x), bus.spec.body_width / 2.0)
	assert_between(local.y, 1.0, bus.spec.body_height)


func test_gauge_shows_the_current_camera_view() -> void:
	GameEvents.camera_cycle_requested.emit()
	assert_eq(hud.gauge.status_text(), "Far")


func test_gauge_door_warning_clears_when_doors_close() -> void:
	GameEvents.door_toggle_requested.emit()
	await wait_physics_frames(2)
	assert_eq(hud.gauge.status_text(), "DOORS OPEN")
	bus.doors.open_amount = 0.01
	GameEvents.door_toggle_requested.emit()
	await wait_physics_frames(3)
	assert_eq(hud.gauge.status_text(), "Close")


func test_hud_shows_the_control_for_each_steering_mode() -> void:
	assert_true(hud.wheel.visible)
	GameSettings.steering_mode = SteeringMapper.Mode.BUTTONS
	assert_false(hud.wheel.visible)
	assert_true(hud.left_button.visible)
	GameSettings.steering_mode = SteeringMapper.Mode.TILT
	assert_false(hud.left_button.visible)
	assert_false(hud.wheel.visible)


func test_pedals_work_with_two_fingers_at_once() -> void:
	await wait_frames(2)
	var throttle_point := hud.throttle_pedal.get_global_rect().get_center()
	var brake_point := hud.brake_pedal.get_global_rect().get_center()
	_touch(0, throttle_point, true, hud.throttle_pedal)
	_touch(1, brake_point, true, hud.brake_pedal)
	assert_gt(hud.throttle_pedal.value, 0.0)
	assert_gt(hud.brake_pedal.value, 0.0)
	_touch(0, throttle_point, false, hud.throttle_pedal)
	assert_eq(hud.throttle_pedal.value, 0.0)
	assert_gt(hud.brake_pedal.value, 0.0, "Lifting one finger must not release the other pedal")
	_touch(1, brake_point, false, hud.brake_pedal)


func test_pedal_is_stronger_higher_up() -> void:
	await wait_frames(2)
	var rect := hud.throttle_pedal.get_global_rect()
	assert_gt(hud.throttle_pedal.press_value_at(rect.position), hud.throttle_pedal.press_value_at(rect.end))


func test_leaving_the_app_releases_held_pedals() -> void:
	await wait_frames(2)
	var point := hud.throttle_pedal.get_global_rect().get_center()
	_touch(0, point, true, hud.throttle_pedal)
	hud.throttle_pedal.notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(hud.throttle_pedal.value, 0.0)


func test_touch_targets_are_large_enough() -> void:
	await wait_frames(2)
	for button: TouchZone in [hud.throttle_pedal, hud.brake_pedal, hud.wheel]:
		assert_gte(button.size.x, 90.0)
		assert_gte(button.size.y, 90.0)
