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
	Profile.data.intro_done = true
	GameSettings.language = "en"

	var menu: MainMenu = load("res://scenes/main/main_menu.tscn").instantiate()
	add_child(menu)
	await _frames(12)
	await _shot("01_home_en")
	menu.show_tab(2)
	await _frames(8)
	await _shot("02_garage_en")
	menu.show_tab(MainMenu.SETTINGS_TAB)
	await _frames(5)
	await _shot("03_settings_en")
	menu.show_tab(0)
	GameSettings.language = "hi"
	await _frames(8)
	await _shot("04_home_hi")
	GameSettings.language = "ar"
	await _frames(8)
	await _shot("05_home_ar")
	menu.show_tab(MainMenu.SETTINGS_TAB)
	await _frames(5)
	await _shot("06_settings_ar")
	menu.free()

	Profile.data.intro_done = false
	GameSettings.language = "en"
	var scene: Node = load(SCENE).instantiate()
	add_child(scene)
	var city: CityShift = scene
	await _seconds(2.0)
	await _shot("07_intro_a")
	await _seconds(4.0)
	await _shot("08_intro_b")
	await _seconds(6.0)
	await _shot("09_intro_c")
	await _seconds(2.5)
	await _shot("10_tutorial_go")
	city.get_node("Hud").tutorial_panel.hide_panel()
	var tutorial: TutorialDirector = city.get_node("Tutorial")
	tutorial.script_steps.index = 7
	tutorial._shown_step = ""
	var stop := city.route.stops[0]
	var bus: BusController = scene.get_node("Bus")
	GameEvents.bus_relocate_requested.emit(_rear_for(stop, bus.spec), stop.heading)
	await _seconds(1.5)
	await _shot("11_tutorial_doors")
	tutorial.finish()

	GameSettings.language = "ar"
	await _seconds(1.0)
	await _shot("12_hud_ar")
	GameSettings.language = "hi"
	await _seconds(1.0)
	await _shot("13_hud_hi")
	GameSettings.language = "fr"
	await _seconds(1.0)
	await _shot("14_hud_fr")
	GameSettings.language = "ar"
	GameEvents.bus_collided.emit(3.0)
	var system := city.route_system_for_tools()
	system.runner.stop_index = system.runner.stops.size() - 1
	var last := city.route.stops[city.route.stops.size() - 1]
	GameEvents.bus_relocate_requested.emit(_rear_for(last, bus.spec), last.heading)
	await _seconds(1.0)
	await _shot("15_report_ar")
	scene.queue_free()
	await _frames(3)

	GameSettings.language = "en"
	Profile.data.intro_done = true
	for level: int in [GraphicsQuality.Level.HIGH, GraphicsQuality.Level.MEDIUM, GraphicsQuality.Level.LOW]:
		GameSettings.graphics_quality = level
		var quality_scene: Node = load(SCENE).instantiate()
		add_child(quality_scene)
		var quality_city: CityShift = quality_scene
		await _frames(10)
		_place(quality_city, "market_street", 60.0, 1.9, 1)
		await _seconds(2.0)
		await _shot("16_quality_%d" % level)
		quality_scene.queue_free()
		await _frames(3)
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
