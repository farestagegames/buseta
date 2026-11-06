extends GutTest
## Runs the real city and exercises a stop end to end.

const SCENE := preload("res://scenes/main/city_shift.tscn")

var scene: CityShift
var bus: BusController
var route_system: RouteSystem
var obstacles: ObstacleField
var crowd: PassengerCrowd
var audio: AudioDirector


func before_each() -> void:
	GameSettings.steering_mode = SteeringMapper.Mode.WHEEL
	scene = SCENE.instantiate()
	add_child_autofree(scene)
	bus = scene.get_node("Bus")
	route_system = scene.get_node("RouteSystem")
	obstacles = scene.get_node("Obstacles")
	crowd = scene.get_node("Crowd")
	audio = scene.get_node("AudioDirector")


func after_each() -> void:
	GameEvents.ui_pedals_changed.emit(0.0, 0.0)


func _park_at(stop: RouteStop) -> void:
	var rear := stop.position + stop.forward() * bus.spec.body_centre_z()
	GameEvents.bus_relocate_requested.emit(rear, stop.heading)


func test_city_is_built_with_real_size() -> void:
	var city: CityBuilder = scene.get_node("City")
	assert_gt(city.building_count, 40, "Town should have plenty of buildings")
	assert_gt(scene.network.nodes.size(), 7)


func test_bus_starts_in_the_depot_road_on_the_ground() -> void:
	var start := scene.route.start_position
	assert_almost_eq(bus.global_position.y, scene.ground.height_at(start), 0.2)
	assert_eq(route_system.runner.current_stop().stop_name, "Mill Lane")


func test_bus_rides_on_a_hill() -> void:
	var top := scene.network.sample("market_street", 140.0, 1.9, 1)
	GameEvents.bus_relocate_requested.emit(top["position"], top["heading"])
	await wait_physics_frames(5)
	assert_gt(bus.global_position.y, 4.0, "Market Street crests a hill")


func test_full_stop_alights_boards_and_moves_on() -> void:
	var stop: RouteStop = scene.route.stops[0]
	_park_at(stop)
	await wait_physics_frames(3)
	GameEvents.door_toggle_requested.emit()
	await wait_physics_frames(80)
	assert_not_null(route_system.session, "Doors open in the bay should start the stop")
	for i in 80:
		await wait_physics_frames(30)
		if route_system.session.is_complete():
			break
	assert_true(route_system.session.is_complete())
	assert_eq(route_system.ledger.count(), stop.waiting)
	GameEvents.door_toggle_requested.emit()
	await wait_physics_frames(85)
	assert_eq(route_system.runner.stop_index, 1, "Closing doors should advance the route")


func test_walkers_appear_at_the_next_stop() -> void:
	var stop: RouteStop = scene.route.stops[0]
	_park_at(stop)
	await wait_physics_frames(3)
	assert_eq(crowd.waiting.size(), stop.waiting)


func test_driving_past_a_stop_counts_as_missed() -> void:
	watch_signals(GameEvents)
	var stop: RouteStop = scene.route.stops[0]
	GameEvents.bus_relocate_requested.emit(stop.position + stop.forward() * 35.0, stop.heading)
	await wait_physics_frames(3)
	assert_signal_emitted(GameEvents, "stop_missed")
	assert_eq(route_system.runner.stop_index, 1)


func test_stopping_at_the_depot_finishes_the_shift() -> void:
	watch_signals(GameEvents)
	route_system.runner.stop_index = route_system.runner.stops.size() - 1
	_park_at(route_system.runner.current_stop())
	await wait_physics_frames(3)
	assert_signal_emitted(GameEvents, "shift_completed")
	assert_true((scene.get_node("Hud") as DriveHud).shift_panel.visible)


func test_bus_knocks_a_cone_flying_and_passes() -> void:
	var cone: KnockableProp = null
	for prop in obstacles.props:
		if prop.kind == "cone":
			cone = prop
			break
	var nose := Vector2(cone.position.x, cone.position.z)
	var forward := Vector2(-sin(0.0), -cos(0.0))
	GameEvents.bus_relocate_requested.emit(nose - forward * 10.0, 0.0)
	bus.model.speed = 6.0
	watch_signals(GameEvents)
	await wait_physics_frames(40)
	assert_ne(cone.state, KnockableProp.State.STANDING)
	assert_signal_emitted(GameEvents, "obstacle_hit")
	assert_gt(bus.model.speed, 4.0, "A cone should barely slow a bus")


func test_speed_bump_jolts_a_fast_bus() -> void:
	var bump := scene.network.sample("mill_lane", 70.0, 1.9, 1)
	var forward: Vector2 = bump["forward"]
	GameEvents.bus_relocate_requested.emit(bump["position"] - forward * 16.0, bump["heading"])
	bus.model.speed = 12.0
	watch_signals(GameEvents)
	await wait_physics_frames(90)
	assert_signal_emitted(GameEvents, "bus_jolted")


func test_kerb_rolls_the_body_when_a_wheel_mounts_the_pavement() -> void:
	var edge := scene.network.sample("mill_lane", 40.0, RoadNetwork.ROAD_HALF_WIDTH + 0.1, 1)
	GameEvents.bus_relocate_requested.emit(edge["position"], edge["heading"])
	await wait_physics_frames(60)
	assert_gt(absf(bus.suspension.roll), 0.01)


func test_recover_returns_a_lost_bus_to_the_route() -> void:
	GameEvents.bus_relocate_requested.emit(Vector2(-200.0, 200.0), 1.0)
	await wait_physics_frames(2)
	GameEvents.reset_requested.emit()
	await wait_physics_frames(2)
	var edge := scene.network.edge_distance(Vector2(bus.global_position.x, bus.global_position.z))
	assert_lt(edge, 0.0, "Recovered bus should be on the road")


func test_horn_sound_follows_the_button() -> void:
	GameEvents.horn_changed.emit(true)
	assert_true(audio.horn_playing)
	GameEvents.horn_changed.emit(false)
	assert_false(audio.horn_playing)


func test_door_sound_plays_when_doors_open() -> void:
	GameEvents.door_toggle_requested.emit()
	await wait_physics_frames(3)
	var playing := false
	for child in audio.get_children():
		var player := child as AudioStreamPlayer
		if player != null and player.playing and player.stream == load("res://assets/audio/door_open.wav"):
			playing = true
	assert_true(playing)


func test_open_doors_swing_clear_of_the_body() -> void:
	var visual: BusVisual = bus.get_node("Visual")
	GameEvents.door_toggle_requested.emit()
	await wait_physics_frames(int(bus.spec.door_open_time * 60.0) + 10)
	assert_gt(absf(visual.door_swing_angle()), deg_to_rad(90.0))


func test_open_doors_bring_the_camera_round_to_the_door_side() -> void:
	var camera: CameraRig = scene.get_node("CameraRig")
	await wait_frames(5)
	var before: Vector3 = bus.global_transform.affine_inverse() * camera.global_position
	assert_lt(before.x, 1.0, "Starts behind the bus")
	GameEvents.door_toggle_requested.emit()
	await wait_seconds(2.5)
	var during: Vector3 = bus.global_transform.affine_inverse() * camera.global_position
	assert_gt(during.x, 4.0, "Should be out to the door side")
	assert_lt(during.z, -3.0, "Should be toward the front of the bus")


func _first_car() -> KnockableProp:
	for prop in obstacles.props:
		if prop.kind == "car":
			return prop
	return null


func test_hitting_a_parked_car_shoves_it_and_the_bus_keeps_rolling() -> void:
	var car := _first_car()
	var ground_spot := Vector2(car.position.x, car.position.z)
	var heading := car.rotation.y
	var forward := Vector2(-sin(heading), -cos(heading))
	var start := car.position
	GameEvents.bus_relocate_requested.emit(ground_spot - forward * 12.5, heading)
	bus.model.speed = 8.0
	watch_signals(GameEvents)
	await wait_physics_frames(50)
	assert_signal_emitted(GameEvents, "obstacle_hit")
	assert_gt(car.position.distance_to(start), 1.0, "Car should have moved")
	assert_gt(bus.model.speed, 1.5, "A bus should not stop dead against a car")
	assert_lt(bus.model.speed, 6.5, "A car should cost real speed")
	assert_lt(car.position.distance_to(start), 12.0, "Car should not slide far")


func test_slow_push_moves_a_car_rather_than_blocking() -> void:
	var car := _first_car()
	var ground_spot := Vector2(car.position.x, car.position.z)
	var heading := car.rotation.y
	var forward := Vector2(-sin(heading), -cos(heading))
	var start := car.position
	GameEvents.bus_relocate_requested.emit(ground_spot - forward * 10.2, heading)
	GameEvents.ui_pedals_changed.emit(1.0, 0.0)
	await wait_physics_frames(240)
	assert_gt(car.position.distance_to(start), 0.3)
	assert_gt(bus.model.speed, 0.5)


func test_boarded_passengers_appear_in_the_seats() -> void:
	var visual: BusVisual = bus.get_node("Visual")
	assert_eq(visual.visible_riders(), 0)
	GameEvents.onboard_changed.emit(6)
	assert_eq(visual.visible_riders(), 6)


func test_driver_hides_only_from_the_cockpit() -> void:
	var visual: BusVisual = bus.get_node("Visual")
	var camera: CameraRig = scene.get_node("CameraRig")
	await wait_frames(2)
	assert_true(visual.driver_visible())
	camera.next_view()
	camera.next_view()
	assert_eq(camera.view_name(), "Cockpit")
	assert_false(visual.driver_visible())


func test_volume_setting_reaches_the_audio_bus() -> void:
	GameSettings.sound_volume = 0.5
	assert_almost_eq(AudioServer.get_bus_volume_db(0), linear_to_db(0.5), 0.01)
	GameSettings.sound_volume = 0.7


func test_lamp_post_falls_and_the_bus_keeps_going() -> void:
	var lamp: KnockableProp = null
	for prop in obstacles.props:
		if prop.kind == "lamp":
			lamp = prop
			break
	assert_not_null(lamp, "City should have lamp posts")
	var spot := Vector2(lamp.position.x, lamp.position.z)
	var forward := Vector2(0.0, -1.0)
	GameEvents.bus_relocate_requested.emit(spot - forward * 11.0, 0.0)
	bus.model.speed = 8.0
	await wait_physics_frames(45)
	assert_gt(lamp.tip_angle, 0.5, "Lamp should be falling")
	assert_gt(bus.model.speed, 3.0, "A lamp post should not stop the bus")
