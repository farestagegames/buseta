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


func test_wing_mirror_shows_only_in_cockpit_view() -> void:
	var mirror := camera.wing_mirror
	await wait_frames(1)
	assert_false(mirror.visible, "No mirror in a follow view")
	assert_eq(mirror.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "Not rendering outside the cockpit")
	while camera.view_name() != "Cockpit":
		GameEvents.camera_cycle_requested.emit()
	await wait_frames(3)
	assert_true(mirror.visible)
	assert_true(mirror.picture.flip_h, "Flipped like a real mirror")
	assert_lte(mirror.viewport.size.x * mirror.viewport.size.y, 256 * 144, "A small render")
	GameEvents.camera_cycle_requested.emit()
	await wait_frames(1)
	assert_false(mirror.visible)
	assert_eq(mirror.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)


func test_wing_mirror_looks_back_from_the_drivers_side() -> void:
	var mirror := camera.wing_mirror
	await wait_frames(1) # After the rig announces its first view.
	mirror.set_active(true)
	await wait_frames(2)
	var local := bus.global_transform.affine_inverse() * mirror.camera.global_transform
	var side := signf(bus.spec.driver_seat_x)
	assert_gt(local.origin.x * side, bus.spec.body_width / 2.0, "Outside the body on the driver's side")
	var looking := -local.basis.z
	assert_gt(looking.z, 0.9, "Looking back down the bus")
	assert_gt(looking.x * side, 0.0, "Turned out, away from the body")
	assert_eq(mirror.on_left, side < 0.0)
	mirror.set_active(false)


func test_door_camera_stays_clear_of_a_wall_beside_the_bus() -> void:
	var side := float(bus.spec.door_side)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 12.0, 60.0)
	shape.shape = box
	wall.add_child(shape)
	var wall_x := side * (bus.spec.body_width / 2.0 + 2.5)
	wall.position = Vector3(wall_x, 6.0, 0.0)
	add_child_autofree(wall)
	GameEvents.door_toggle_requested.emit()
	await wait_seconds(2.5)
	var inner_face := absf(wall_x) - 0.5
	assert_lt(camera.global_position.x * side, inner_face, "Camera on the bus side of the wall")
	var door := Vector3(bus.global_position.x + side * bus.spec.body_width / 2.0, 1.2, bus.global_position.z)
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, door)
	query.exclude = [bus.get_rid()]
	assert_true(camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Nothing between the camera and the doorway")


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


func test_brake_is_a_hold_button_that_firms_up() -> void:
	await wait_frames(2)
	var brake := hud.brake_pedal
	var top := brake.get_global_rect().position + Vector2(20.0, 20.0)
	var bottom := brake.get_global_rect().end - Vector2(20.0, 20.0)
	_touch(0, top, true, brake)
	var from_top := brake.value
	_touch(0, top, false, brake)
	_touch(0, bottom, true, brake)
	assert_eq(brake.value, from_top, "Where the thumb lands makes no difference")
	assert_lt(brake.value, 0.81, "A first press is gentle, below the harsh-braking pull")
	brake.hold(0.5)
	var after_half_second := brake.value
	assert_gt(after_half_second, from_top, "Holding firms the brake up")
	brake.hold(5.0)
	assert_eq(brake.value, 1.0, "A long hold reaches full brake")
	_touch(0, bottom, false, brake)
	assert_eq(brake.value, 0.0)


func test_gear_switch_picks_the_half_that_is_tapped() -> void:
	await wait_frames(2)
	var rect := hud.gear_switch.get_global_rect()
	var drive_half := Vector2(rect.position.x + rect.size.x * 0.25, rect.get_center().y)
	var reverse_half := Vector2(rect.position.x + rect.size.x * 0.75, rect.get_center().y)
	_touch(0, drive_half, true, hud.gear_switch)
	_touch(0, drive_half, false, hud.gear_switch)
	await wait_physics_frames(2)
	assert_eq(bus.model.direction, BusPhysicsModel.Direction.FORWARD, "Tapping D while in drive changes nothing")
	_touch(0, reverse_half, true, hud.gear_switch)
	_touch(0, reverse_half, false, hud.gear_switch)
	await wait_physics_frames(2)
	assert_eq(bus.model.direction, BusPhysicsModel.Direction.REVERSE, "Tapping R puts the bus in reverse")
	assert_true(hud.gear_switch.is_reverse, "and lights R")
	_touch(0, drive_half, true, hud.gear_switch)
	_touch(0, drive_half, false, hud.gear_switch)
	await wait_physics_frames(2)
	assert_false(hud.gear_switch.is_reverse)


func test_gear_switch_is_as_wide_as_the_brake() -> void:
	await wait_frames(2)
	var gear := hud.gear_switch.get_global_rect()
	var brake := hud.brake_pedal.get_global_rect()
	assert_almost_eq(gear.size.x, brake.size.x, 0.5, "D/R spans the same width as FRENO")
	assert_almost_eq(gear.position.x, brake.position.x, 0.5, "and lines up with it")


func test_changing_gear_while_moving_explains_why_not() -> void:
	watch_signals(GameEvents)
	bus.model.speed = 6.0
	GameEvents.gear_toggle_requested.emit()
	assert_signal_emitted_with_parameters(GameEvents, "hint_shown", ["Stop the bus to change gear"])
	await wait_physics_frames(2)
	assert_false(hud.gear_switch.is_reverse)


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
	# Every other control still takes a thumb: at least 48 px, and each half of
	# the gear switch too.
	for zone: TouchZone in hud.find_children("*", "TouchZone", true, false):
		assert_gte(zone.size.x, 48.0, "%s wide enough" % zone.name)
		assert_gte(zone.size.y, 48.0, "%s tall enough" % zone.name)
	assert_gte(hud.gear_switch.size.x / 2.0, 48.0)


func test_goals_checklist_sits_left_under_the_pause_and_camera_buttons() -> void:
	await wait_frames(2)
	var goals := hud.goals_hud.get_global_rect()
	var pause := hud._pause_button.get_global_rect()
	var view := hud._view_button.get_global_rect()
	assert_almost_eq(goals.position.x, pause.position.x, 0.5, "Lined up with the pause button")
	assert_gt(goals.position.y, maxf(pause.end.y, view.end.y), "Below the top buttons")
	assert_lt(goals.end.x, hud.get_viewport().get_visible_rect().size.x / 2.0, "On the left half")
	assert_false(goals.intersects(hud.gauge.get_global_rect()), "Clear of the speed readout")
	assert_lte(goals.end.y, WingMirror.TOP, "The cockpit mirror sits below it")


func _status(near: bool, prompt: String = "") -> Dictionary:
	return {"next_stop": "Parque Norte", "distance": 120.0, "turn": "", "onboard": 0, "fares": 0, "prompt": prompt,
		"stop_position": Vector2.ZERO, "stop_number": 2, "stop_count": 8, "clock": 0.0, "seconds_late": 0.0,
		"speed_limit": 30.0, "near_stop": near}


func test_doors_button_shows_only_near_a_stop_or_with_the_doors_open() -> void:
	await wait_frames(2)
	GameEvents.route_status_updated.emit(_status(false))
	assert_false(hud.doors_button_shown(), "Hidden between stops")
	GameEvents.route_status_updated.emit(_status(true))
	assert_true(hud.doors_button_shown(), "Shown at a stop")
	GameEvents.route_status_updated.emit(_status(false))
	GameEvents.door_toggle_requested.emit()
	await wait_physics_frames(3)
	assert_true(hud.doors_button_shown(), "Shown while the doors are open")


func test_indicator_buttons_follow_the_setting() -> void:
	var was := GameSettings.show_indicator_buttons
	GameSettings.show_indicator_buttons = false
	assert_false(hud.control_rect("indicator").has_area(), "Hidden by default")
	GameSettings.show_indicator_buttons = true
	await wait_frames(1)
	assert_true(hud.control_rect("indicator").has_area())
	GameSettings.show_indicator_buttons = was


func test_stop_panel_is_one_line_with_a_toast_for_the_prompt() -> void:
	await wait_frames(2)
	GameEvents.route_status_updated.emit(_status(true, "Passengers boarding"))
	assert_eq(hud.route_panel.line_text(), "Parque Norte · 2/8 · On time")
	assert_lte(hud.route_panel.size.y, 48.0, "One line")
	assert_true(hud.route_panel.toast_showing())
	await wait_seconds(RoutePanel.TOAST_SECONDS + 0.2)
	assert_false(hud.route_panel.toast_showing(), "The toast fades")


func test_minimap_is_a_small_circle_that_grows_when_tapped() -> void:
	await wait_frames(2)
	hud.minimap.visible = true # The test scene has no map to show it.
	assert_eq(hud.minimap.size.x, Minimap.SMALL)
	var centre := hud.minimap.get_global_rect().get_center()
	_touch(3, centre, true, hud.minimap)
	_touch(3, centre, false, hud.minimap)
	await wait_frames(1)
	assert_eq(hud.minimap.size.x, Minimap.LARGE, "Grows on a tap")
	var width := get_viewport().get_visible_rect().size.x
	assert_lte(hud.minimap.get_global_rect().end.x, width, "Stays on screen")
	hud.minimap.toggle_size()
	await wait_frames(1)
	assert_eq(hud.minimap.size.x, Minimap.SMALL)


func test_one_pause_button_holds_the_camera_and_radio() -> void:
	await wait_frames(2)
	assert_false(hud.pause_strip.is_visible_in_tree())
	assert_true(hud.control_rect("pause").has_area())
	assert_true(hud.control_rect("view").has_area(), "A small camera button stays")
	hud._open_settings()
	assert_true(hud.pause_strip.is_visible_in_tree())
	assert_true(hud.radio_button.is_visible_in_tree() or Country.pack.radio_stations().is_empty())
	hud._close_settings()
	assert_false(hud.pause_strip.is_visible_in_tree())
