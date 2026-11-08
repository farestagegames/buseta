extends GutTest
## Runs the real city and exercises a stop end to end.

const SCENE := preload("res://scenes/main/city_shift.tscn")

var scene: CityShift
var bus: BusController
var route_system: RouteSystem
var obstacles: ObstacleField
var crowd: PassengerCrowd
var audio: AudioDirector
var traffic: TrafficSystem
var keeper: ScoreKeeper


func before_all() -> void:
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func before_each() -> void:
	GameSettings.steering_mode = SteeringMapper.Mode.WHEEL
	scene = SCENE.instantiate()
	add_child_autofree(scene)
	bus = scene.get_node("Bus")
	route_system = scene.get_node("RouteSystem")
	obstacles = scene.get_node("Obstacles")
	crowd = scene.get_node("Crowd")
	audio = scene.get_node("AudioDirector")
	traffic = scene.get_node("Traffic")
	keeper = scene.get_node("ScoreKeeper")


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
	assert_eq(route_system.runner.current_stop().stop_name, "Calle de los Almendros")


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


func test_driving_past_someone_flagging_the_bus_counts_against_the_driver() -> void:
	watch_signals(GameEvents)
	var stop: RouteStop = scene.route.stops[0]
	GameEvents.bus_relocate_requested.emit(stop.position + stop.forward() * 35.0, stop.heading)
	await wait_physics_frames(3)
	assert_signal_emitted(GameEvents, "hail_ignored")
	assert_eq(int(keeper.score.counts["ignored_hails"]), stop.waiting)
	assert_eq(route_system.runner.stop_index, 1)
	assert_eq(route_system.runner.stop_index, 1)


func test_stopping_at_the_depot_finishes_the_shift() -> void:
	watch_signals(GameEvents)
	route_system.runner.stop_index = route_system.runner.stops.size() - 1
	_park_at(route_system.runner.current_stop())
	await wait_physics_frames(3)
	assert_signal_emitted(GameEvents, "shift_completed")
	assert_true((scene.get_node("Hud") as DriveHud).shift_panel.visible)
	assert_gt((scene.get_node("Hud") as DriveHud).shift_panel.stars_shown, 0, "Report should show stars")


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
	var bump := scene.network.sample("mill_lane", 205.0, 1.9, 1)
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
	await wait_seconds(0.3)
	assert_true(audio.horn_playing, "It keeps sounding while held")
	GameEvents.horn_changed.emit(false)
	await wait_seconds(HornVoice.FADE_SECONDS + 0.1)
	assert_false(audio.horn_playing, "A short fade, then quiet")


func test_the_bus_sounds_its_own_horn_or_the_one_chosen() -> void:
	assert_eq(audio.horn["id"], Country.pack.bus_horn(CityShift.chosen_bus_item())["id"])
	Profile.data.coins = 1000
	Profile.buy_horn("double_tap")
	Profile.choose_horn("double_tap")
	var second: CityShift = SCENE.instantiate()
	add_child_autofree(second)
	assert_eq((second.get_node("AudioDirector") as AudioDirector).horn["id"], "double_tap")
	Profile.choose_horn("")


func test_the_radio_button_cycles_through_the_stations_and_off() -> void:
	while audio.tuner.is_on():
		audio.cycle_radio()
	var hud: DriveHud = scene.get_node("Hud")
	assert_true(hud.radio_button.visible)
	var stations := Country.pack.radio_stations()
	var names: Array[String] = []
	var listen := func(station_name: String, _frequency: String) -> void: names.append(station_name)
	GameEvents.radio_tuned.connect(listen)
	for i in stations.size() + 1:
		hud.radio_button.pressed_down.emit()
		if i < stations.size():
			assert_true(audio.radio_playing(), "Station %d plays" % i)
			assert_eq(GameSettings.radio_station, stations[i]["id"], "Remembered for the next shift")
			assert_true(hud.station_label.visible)
			assert_string_contains(hud.station_label.text, stations[i]["frequency"])
	GameEvents.radio_tuned.disconnect(listen)
	assert_false(audio.radio_playing(), "Off again after the last station")
	assert_eq(GameSettings.radio_station, "")
	assert_eq(names.size(), stations.size() + 1)
	assert_eq(names[0], stations[0]["name"])
	assert_eq(names[names.size() - 1], "")
	assert_eq(hud.station_label.text, tr("RADIO OFF"))


func test_the_radio_picks_up_where_the_last_shift_left_it() -> void:
	GameSettings.radio_station = Country.pack.radio_stations()[1]["id"]
	var second: CityShift = SCENE.instantiate()
	add_child_autofree(second)
	var second_audio: AudioDirector = second.get_node("AudioDirector")
	assert_eq(second_audio.tuner.station_id(), GameSettings.radio_station)
	assert_true(second_audio.radio_playing())
	GameSettings.radio_station = ""


func test_the_radio_moves_on_when_a_track_ends() -> void:
	GameSettings.radio_station = ""
	audio.cycle_radio()
	var first := audio.radio_stream()
	audio._on_track_finished()
	assert_ne(audio.radio_stream(), first)
	assert_true(audio.radio_playing())
	GameSettings.radio_station = ""


func test_the_radio_is_muffled_from_outside_the_bus() -> void:
	GameEvents.camera_view_changed.emit("Cockpit")
	assert_false(SoundBuses.radio_muffled())
	GameEvents.camera_view_changed.emit("Far")
	assert_true(SoundBuses.radio_muffled())


func test_the_radio_plays_on_while_the_settings_are_open() -> void:
	GameSettings.radio_station = ""
	audio.cycle_radio()
	var hud: DriveHud = scene.get_node("Hud")
	assert_true(hud.radio_button.lit, "Lit while a station plays")
	hud._open_settings()
	assert_true(get_tree().paused)
	assert_true(audio._radio.can_process(), "The radio is not paused with the game")
	assert_true(audio.radio_playing())
	hud._close_settings()
	while audio.tuner.is_on():
		audio.cycle_radio()
	assert_false(hud.radio_button.lit)
	GameSettings.radio_station = ""


func test_tuning_the_radio_does_not_write_the_save_at_once() -> void:
	GameSettings.radio_station = ""
	Profile.save()
	var before := FileAccess.get_file_as_string("user://test_save_scene.json")
	audio.cycle_radio()
	assert_eq(FileAccess.get_file_as_string("user://test_save_scene.json"), before, "No disk write per tap")
	assert_eq(Profile.data.settings["radio_station"], GameSettings.radio_station, "Saved with the next save")
	while audio.tuner.is_on():
		audio.cycle_radio()
	GameSettings.radio_station = ""


func test_a_horn_let_go_as_the_game_pauses_does_not_blip_on_resume() -> void:
	GameEvents.horn_changed.emit(true)
	await wait_frames(3)
	GameEvents.horn_changed.emit(false)
	var hud: DriveHud = scene.get_node("Hud")
	hud._open_settings()
	assert_false(audio.horn_playing, "Stopped as the game paused")
	hud._close_settings()
	await wait_frames(3)
	assert_false(audio.horn_playing)


func test_a_held_horn_survives_a_pause() -> void:
	GameEvents.horn_changed.emit(true)
	var hud: DriveHud = scene.get_node("Hud")
	hud._open_settings()
	hud._close_settings()
	assert_true(audio.horn_playing, "Still held, so still sounding")
	GameEvents.horn_changed.emit(false)
	await wait_seconds(HornVoice.FADE_SECONDS + 0.1)


func test_a_settled_street_layer_is_left_alone() -> void:
	await wait_seconds(1.0)
	var city: AudioStreamPlayer = audio._street["city"]
	city.volume_db = 3.0
	await wait_frames(10)
	assert_eq(city.volume_db, 3.0, "Its volume is not written every frame")


func test_stalls_and_stops_reach_the_street_sounds_apart() -> void:
	assert_gt(audio._stops.size(), 0)
	var stop: RouteStop = route_system.runner.current_stop()
	_park_at(stop)
	await wait_physics_frames(3)
	assert_lt(audio.mixer.stop_distance, 25.0, "Parked at a stop")


func test_the_sea_is_heard_on_the_malecon_and_not_in_town() -> void:
	var town := scene.network.sample("mill_lane", 100.0, 1.9, 1)
	GameEvents.bus_relocate_requested.emit(town["position"], town["heading"])
	await wait_seconds(1.0)
	assert_lt(audio.street_level("sea"), 0.05, "Inland")
	assert_gt(audio.street_level("city"), 0.9, "The city is always there")
	var malecon := scene.network.sample("river_road", 200.0, 1.9, 1)
	GameEvents.bus_relocate_requested.emit(malecon["position"], malecon["heading"])
	await wait_seconds(1.0)
	assert_gt(audio.street_level("sea"), 0.5, "On the Malecón")


func test_rain_has_a_hook_for_the_weather() -> void:
	GameEvents.rain_changed.emit(1.0)
	await wait_seconds(0.8)
	assert_gt(audio.street_level("rain"), 0.9)
	assert_lt(audio.street_level("birds"), 0.05)
	GameEvents.rain_changed.emit(0.0)


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
	assert_gt(car.position.distance_to(start), 1.0, "Car should roll ahead of the bus")
	var nose := Vector2(bus.global_position.x, bus.global_position.z) + forward * (bus.spec.wheelbase + bus.spec.front_overhang)
	var car_now := Vector2(car.position.x, car.position.z)
	assert_gt((car_now - nose).dot(forward), -1.0, "Bus must not drive through the car")
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


func test_traffic_runs_and_keeps_moving() -> void:
	assert_eq(traffic.agents.size(), int(GraphicsQuality.current_profile()["traffic_cars"]) + int(GraphicsQuality.current_profile()["traffic_motos"]))
	var start: Array[Vector2] = []
	for agent in traffic.agents:
		start.append(traffic._position_of(agent))
	await wait_physics_frames(180)
	var moved := 0
	for i in traffic.agents.size():
		if traffic._position_of(traffic.agents[i]).distance_to(start[i]) > 2.0:
			moved += 1
	assert_gt(moved, traffic.agents.size() / 2, "Most cars should be driving")


func test_car_stops_behind_the_bus() -> void:
	var lane_index := -1
	for i in traffic.graph.lanes.size():
		var candidate: TrafficLane = traffic.graph.lanes[i]
		if candidate.road == "high_street":
			lane_index = i
			break
	var lane: TrafficLane = traffic.graph.lanes[lane_index]
	var agent: TrafficAgent = traffic.agents[0]
	agent.lane = lane_index
	agent.distance = 40.0
	agent.speed = 10.0
	agent.next_lane = -1
	var ahead := lane.point_at(100.0)
	GameEvents.bus_relocate_requested.emit(ahead, RoadNetwork.heading_of(lane.forward_at(100.0)))
	await wait_physics_frames(540)
	assert_lt(agent.speed, 0.5, "Car should wait behind the stopped bus")
	var hit := BusFootprint.touches(ahead, RoadNetwork.heading_of(lane.forward_at(100.0)), bus.spec, traffic._position_of(agent), 0.2)
	assert_false(hit)


func _line_of_node(node_id: String) -> Dictionary:
	for approach in traffic._approaches:
		if approach["node"] == node_id:
			return approach
	return {}


func test_running_a_red_light_is_penalised() -> void:
	var approach := _line_of_node("b")
	var forward: Vector2 = approach["forward"]
	var plan: TrafficLightPlan = traffic.plans["b"]
	while plan.state(approach["group"], traffic.time) != TrafficLightPlan.Light.RED:
		traffic.time += 0.5
	var heading := RoadNetwork.heading_of(forward)
	var nose_to_rear: float = bus.spec.wheelbase + bus.spec.front_overhang
	GameEvents.bus_relocate_requested.emit(approach["line"] - forward * (nose_to_rear + 3.0), heading)
	await wait_physics_frames(2)
	bus.model.speed = 6.0
	watch_signals(GameEvents)
	await wait_physics_frames(50)
	assert_signal_emitted(GameEvents, "red_light_run")
	assert_eq(int(keeper.score.counts["red_lights"]), 1)


func test_green_light_is_not_penalised() -> void:
	var approach := _line_of_node("b")
	var forward: Vector2 = approach["forward"]
	var plan: TrafficLightPlan = traffic.plans["b"]
	while plan.state(approach["group"], traffic.time) != TrafficLightPlan.Light.GREEN or plan.state(approach["group"], traffic.time + 4.0) != TrafficLightPlan.Light.GREEN:
		traffic.time += 0.5
	var heading := RoadNetwork.heading_of(forward)
	var nose_to_rear: float = bus.spec.wheelbase + bus.spec.front_overhang
	GameEvents.bus_relocate_requested.emit(approach["line"] - forward * (nose_to_rear + 3.0), heading)
	await wait_physics_frames(2)
	bus.model.speed = 6.0
	await wait_physics_frames(50)
	assert_eq(int(keeper.score.counts["red_lights"]), 0)


func test_bus_signal_reports_the_light_ahead() -> void:
	var approach := _line_of_node("b")
	var forward: Vector2 = approach["forward"]
	var heading := RoadNetwork.heading_of(forward)
	GameEvents.bus_relocate_requested.emit(approach["line"] - forward * 30.0, heading)
	await wait_physics_frames(3)
	var ahead := traffic.bus_signal()
	assert_gte(int(ahead["state"]), 0)
	assert_lt(float(ahead["distance"]), 30.0)


func test_hard_braking_and_a_crash_show_in_the_score() -> void:
	bus.model.speed = 12.0
	GameEvents.ui_pedals_changed.emit(0.0, 1.0)
	await wait_physics_frames(80)
	assert_eq(int(keeper.score.counts["harsh_brakes"]), 1)
	GameEvents.bus_collided.emit(4.0)
	assert_eq(int(keeper.score.counts["collisions"]), 1)


func test_driving_along_the_pavement_is_off_road() -> void:
	var spot := scene.network.sample("mill_lane", 40.0, RoadNetwork.ROAD_HALF_WIDTH + 1.6, 1)
	GameEvents.bus_relocate_requested.emit(spot["position"], spot["heading"])
	await wait_physics_frames(40)
	assert_gt(keeper.score.off_road_seconds, 0.2)


func test_speed_limit_reaches_the_hud_status() -> void:
	watch_signals(GameEvents)
	await wait_physics_frames(20)
	assert_signal_emitted(GameEvents, "route_status_updated")
	var params: Array = get_signal_parameters(GameEvents, "route_status_updated")
	assert_eq(float(params[0]["speed_limit"]), 30.0, "Depot road is 30")


func test_passengers_vary_and_have_working_arms() -> void:
	var stop: RouteStop = scene.route.stops[1]
	var rear := stop.position + stop.forward() * bus.spec.body_centre_z()
	route_system.runner.stop_index = 1
	GameEvents.bus_relocate_requested.emit(rear, stop.heading)
	await wait_physics_frames(3)
	var looks := {}
	var sizes := {}
	for walker in crowd.waiting:
		looks[(walker.get_child(0) as MeshInstance3D).mesh] = true
		sizes[walker.scale.x] = true
		assert_not_null(walker.left_arm)
	assert_gt(looks.size(), 2, "People should not all look the same")
	assert_gt(sizes.size(), 2, "People should not all be the same height")


func test_waiting_people_take_their_height_and_pace_from_their_look() -> void:
	var stop: RouteStop = scene.route.stops[1]
	route_system.runner.stop_index = 1
	GameEvents.bus_relocate_requested.emit(stop.position + stop.forward() * bus.spec.body_centre_z(), stop.heading)
	await wait_physics_frames(3)
	assert_gt(crowd.waiting.size(), 0)
	for walker in crowd.waiting:
		assert_almost_eq(walker.scale.x / walker.look.size, 1.0, PassengerCrowd.HEIGHT_VARIETY + 0.001, walker.look.id)
		assert_eq(walker.pace, walker.look.pace)


func test_one_long_scrape_counts_as_one_collision() -> void:
	await wait_physics_frames(2)
	for i in 8:
		GameEvents.bus_collided.emit(3.0)
		await wait_physics_frames(10)
	assert_eq(int(keeper.score.counts["collisions"]), 1)


func test_bus_can_pass_a_parked_car_at_the_road_centre() -> void:
	var car := _first_car()
	var heading := car.rotation.y
	var forward := Vector2(-sin(heading), -cos(heading))
	var right := Vector2(-forward.y, forward.x)
	var spot := Vector2(car.position.x, car.position.z)
	var clear_lateral := -2.3
	assert_false(BusFootprint.touches_car(spot + right * clear_lateral - forward * 3.0, heading, bus.spec, spot, forward))
	assert_true(BusFootprint.touches_car(spot - forward * 3.0, heading, bus.spec, spot, forward))


func test_report_reads_naturally_and_clears_the_hud() -> void:
	var hud: DriveHud = scene.get_node("Hud")
	GameEvents.bus_collided.emit(3.0)
	route_system.runner.stop_index = route_system.runner.stops.size() - 1
	_park_at(route_system.runner.current_stop())
	await wait_physics_frames(3)
	assert_string_contains(keeper._details({"carried": 1}), "1 collision")
	assert_false(keeper._details({"carried": 1}).contains("1 collisions"))
	assert_false(hud.gauge.visible, "The report should not sit over the HUD")


func _car_touching_bus() -> TrafficAgent:
	var heading := bus.model.heading
	var forward := Vector2(-sin(heading), -cos(heading))
	var rear := Vector2(bus.global_position.x, bus.global_position.z)
	var agent: TrafficAgent = traffic.agents[0]
	var lane_index := 0
	for i in traffic.graph.lanes.size():
		if (traffic.graph.lanes[i] as TrafficLane).road == "high_street":
			lane_index = i
			break
	agent.lane = lane_index
	agent.next_lane = -1
	agent.distance = 60.0
	var lane: TrafficLane = traffic.graph.lanes[lane_index]
	var spot := lane.point_at(60.0)
	var along := lane.forward_at(60.0)
	GameEvents.bus_relocate_requested.emit(spot - along * 1.0, RoadNetwork.heading_of(along))
	return agent


func test_car_driving_into_a_stopped_bus_stops_and_it_is_not_the_drivers_fault() -> void:
	var agent := _car_touching_bus()
	agent.speed = 6.0
	await wait_physics_frames(3)
	assert_eq(agent.speed, 0.0, "Car should stop on contact")
	assert_eq(int(keeper.score.counts["collisions"]), 0)


func test_reversing_slowly_into_a_car_counts_as_a_hit() -> void:
	var agent := _car_touching_bus()
	agent.speed = 0.0
	await wait_physics_frames(2)
	bus.model.speed = -1.5
	await wait_physics_frames(2)
	assert_gt(agent.stunned, 1.0, "Car should react to the contact")


func test_finishing_a_shift_banks_rewards_and_saves() -> void:
	var coins_before := Profile.data.coins
	var shifts_before := int(Profile.data.stats["shifts"])
	route_system.runner.stop_index = route_system.runner.stops.size() - 1
	_park_at(route_system.runner.current_stop())
	await wait_physics_frames(3)
	assert_gt(Profile.data.coins, coins_before)
	assert_eq(int(Profile.data.stats["shifts"]), shifts_before + 1)
	var saved := PlayerProfile.from_dict(SaveStore.read("user://test_save_scene.json"))
	assert_eq(saved.coins, Profile.data.coins, "Rewards should reach the disk at once")


func test_pausing_stops_the_clock_and_resuming_restarts_it() -> void:
	var hud: DriveHud = scene.get_node("Hud")
	await wait_physics_frames(3)
	hud._open_settings()
	assert_true(get_tree().paused)
	assert_true(hud.is_paused())
	hud._close_settings()
	assert_false(get_tree().paused)


class FakeAds:
	extends AdProvider

	func is_available() -> bool:
		return true

	func show_rewarded(on_finished: Callable) -> void:
		on_finished.call(true)


func test_rewarded_ad_doubles_coins_only_through_the_interface() -> void:
	var hud: DriveHud = scene.get_node("Hud")
	Profile.ads = FakeAds.new()
	route_system.runner.stop_index = route_system.runner.stops.size() - 1
	_park_at(route_system.runner.current_stop())
	await wait_physics_frames(3)
	var before := Profile.data.coins
	hud.shift_panel._on_double_coins()
	Profile.ads = AdProvider.new()
	assert_gt(Profile.data.coins, before)


func test_no_ad_button_without_a_provider() -> void:
	var hud: DriveHud = scene.get_node("Hud")
	route_system.runner.stop_index = route_system.runner.stops.size() - 1
	_park_at(route_system.runner.current_stop())
	await wait_physics_frames(3)
	assert_false(hud.shift_panel.double_coins_button.visible)


func test_right_to_left_language_keeps_the_driving_controls_in_place() -> void:
	await wait_frames(2)
	var wheel_x := (scene.get_node("Hud") as DriveHud).wheel.get_global_rect().position.x
	GameSettings.language = "ar"
	await wait_frames(3)
	var hud: DriveHud = scene.get_node("Hud")
	var width := get_viewport().get_visible_rect().size.x
	assert_lt(hud.wheel.get_global_rect().get_center().x, width / 2.0, "Wheel stays on the left")
	assert_gt(hud.throttle_pedal.get_global_rect().get_center().x, width / 2.0, "Pedals stay on the right")
	assert_eq(hud.wheel.get_global_rect().position.x, wheel_x)
	GameSettings.language = "en"


func test_changing_language_updates_prompts_live() -> void:
	GameSettings.language = "es_CO"
	await wait_physics_frames(20)
	var hud: DriveHud = scene.get_node("Hud")
	assert_string_contains(hud.route_panel._line_one, "Próximo")
	GameSettings.language = "en"


func test_city_has_motorbikes_and_cars_in_its_traffic() -> void:
	var traffic: TrafficSystem = scene.traffic_for_tools()
	var motos := traffic.agents.filter(func(agent: TrafficAgent) -> bool: return agent.is_moto)
	assert_gt(motos.size(), 0)
	assert_gt(traffic.agents.size() - motos.size(), 0)


func test_a_moto_rides_nearer_the_kerb_than_a_car_in_its_lane() -> void:
	var traffic: TrafficSystem = scene.traffic_for_tools()
	var moto: TrafficAgent = traffic.agents.filter(func(agent: TrafficAgent) -> bool: return agent.is_moto)[0]
	var lane: TrafficLane = traffic.graph.lanes[moto.lane]
	assert_almost_eq(traffic._position_of(moto).distance_to(lane.point_at(moto.distance)), TrafficAgent.MOTO_KERB_SHIFT, 0.5)


func test_street_life_walks_the_pavements() -> void:
	var life: StreetLife = scene.get_node("StreetLife")
	assert_gt(life.strollers.size(), 0)
	var before := life.strollers[0].position()
	await wait_frames(20)
	assert_ne(life.strollers[0].position(), before)


func test_people_on_the_pavement_are_the_passengers_looks() -> void:
	var life: StreetLife = scene.get_node("StreetLife")
	var looks := Country.pack.passenger_looks().looks
	for stroller in life.strollers:
		assert_true(looks.has(stroller.look))
	assert_eq(life._batches.size(), 3, "Clothes, skin and hair")


func test_hitting_a_motorbike_counts_as_a_collision() -> void:
	var traffic: TrafficSystem = scene.traffic_for_tools()
	var moto: TrafficAgent = traffic.agents.filter(func(agent: TrafficAgent) -> bool: return agent.is_moto)[0]
	var spot: Vector2 = traffic._position_of(moto)
	traffic._bus_position = spot
	traffic._bus_speed = 5.0
	traffic._check_moto_hit(moto, spot, Vector2(5.0, 0.0))
	await wait_physics_frames(2)
	assert_gt(int(keeper.score.counts["collisions"]) + int(keeper.score.counts["knocked"]), 0)
