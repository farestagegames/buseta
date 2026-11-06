extends Node
## Developer tool: runs the test scene with scripted input and saves screenshots
## to tools/screens/. Not included in exported builds.

const SCENE := "res://scenes/main/city_shift.tscn"


func _ready() -> void:
	await get_tree().process_frame
	var started := Time.get_ticks_msec()
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	print("load ms ", Time.get_ticks_msec() - started)
	var city: CityShift = scene
	var bus: BusController = scene.get_node("Bus")
	var traffic := city.traffic_for_tools()
	await _frames(30)

	# A signal junction, seen from the approach.
	var approach: Dictionary = traffic._approaches[0]
	for candidate: Dictionary in traffic._approaches:
		if candidate["node"] == "b":
			approach = candidate
	var forward: Vector2 = approach["forward"]
	GameEvents.bus_relocate_requested.emit(approach["line"] - forward * 22.0, RoadNetwork.heading_of(forward))
	await _seconds(7.0)
	await _shot("1_junction")
	GameEvents.camera_cycle_requested.emit()
	await _frames(20)
	await _shot("2_far")
	GameEvents.camera_cycle_requested.emit()
	await _frames(20)
	await _shot("3_cockpit")
	GameEvents.camera_cycle_requested.emit()

	var stop := city.route.stops[1]
	city.route_system_for_tools().runner.stop_index = 1
	GameEvents.bus_relocate_requested.emit(_rear_for(stop, bus.spec), stop.heading)
	await _seconds(0.6)
	GameEvents.door_toggle_requested.emit()
	await _seconds(4.6)
	await _shot("4_boarding")
	await _seconds(7.0)
	await _shot("5_seated")

	GameEvents.penalty_shown.emit("Ran a red light")
	GameEvents.bus_collided.emit(3.0)
	await _frames(3)
	var system := city.route_system_for_tools()
	system.runner.stop_index = system.runner.stops.size() - 1
	var last := city.route.stops[city.route.stops.size() - 1]
	GameEvents.door_toggle_requested.emit()
	await _seconds(1.4)
	GameEvents.bus_relocate_requested.emit(_rear_for(last, bus.spec), last.heading)
	await _seconds(1.0)
	await _shot("6_report")
	get_tree().quit()


func _place(city: CityShift, road: String, along: float, lateral: float, dir: int) -> void:
	var placed := city.network.sample(road, along, lateral, dir)
	GameEvents.bus_relocate_requested.emit(placed["position"], placed["heading"])


func _rear_for(stop: RouteStop, spec: BusSpec) -> Vector2:
	return stop.position + stop.forward() * spec.body_centre_z()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://tools/screens/%s.png" % shot_name)
	image.save_png(path)
	print("saved ", shot_name, " fps=", Engine.get_frames_per_second(),
		" draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		" triangles=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		" objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
