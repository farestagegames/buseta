extends Node
## Developer tool: runs the test scene with scripted input and saves screenshots
## to tools/screens/. Not included in exported builds.

const SCENE := "res://scenes/main/city_shift.tscn"


func _ready() -> void:
	await get_tree().process_frame
	Profile.load_from("user://shots_save.json")
	Profile.data = PlayerProfile.new()
	Profile.data.coins = 3120
	Profile.data.xp = 640
	Profile.data.achievements.append("first_shift")
	Profile.data.stats["shifts"] = 6
	Profile.data.stats["passengers"] = 151
	Profile.data.best_scores["route_01"] = 74
	var menu: MainMenu = load("res://scenes/main/main_menu.tscn").instantiate()
	add_child(menu)
	await _frames(10)
	await _shot("1_home")
	menu.show_tab(1)
	await _frames(5)
	await _shot("2_routes")
	menu.show_tab(2)
	await _frames(5)
	await _shot("3_garage")
	menu.show_tab(3)
	await _frames(5)
	await _shot("4_driver")
	menu.show_tab(4)
	await _frames(5)
	await _shot("5_settings")
	menu.free()

	Profile.buy(Catalog.LIVERIES, "harbour_blue")
	Profile.select(Catalog.LIVERIES, "harbour_blue")
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	var city: CityShift = scene
	var bus: BusController = scene.get_node("Bus")
	await _frames(20)
	var stop := city.route.stops[1]
	city.route_system_for_tools().runner.stop_index = 1
	GameEvents.bus_relocate_requested.emit(_rear_for(stop, bus.spec), stop.heading)
	await _seconds(0.6)
	GameEvents.door_toggle_requested.emit()
	await _seconds(4.8)
	await _shot("6_queue")
	var system := city.route_system_for_tools()
	system.runner.stop_index = system.runner.stops.size() - 1
	var last := city.route.stops[city.route.stops.size() - 1]
	GameEvents.bus_relocate_requested.emit(_rear_for(last, bus.spec), last.heading)
	await _seconds(1.0)
	await _shot("7_report")
	Profile.load_from("user://shots_save_unused.json")
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
