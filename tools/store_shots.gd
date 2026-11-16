extends Node
## Developer tool: Play Store screenshots in Colombian Spanish. Not exported.
## Run windowed at the store size, then convert with tools/make_store_art.py:
##   Godot --path . --resolution 1920x1080 res://tools/store_shots.tscn
## Saves raw PNGs to tools/screens/store/. ONLY=substring runs a subset, and
## PAUSED=1 adds a shot of the pause sheet after each drive shot.

const SCENE := "res://scenes/main/city_shift.tscn"
const MENU := "res://scenes/main/main_menu.tscn"
const SPOTS := {
	"market": ["market_street", 50.0, 1.9, 1],
	"malecon": ["river_road", 290.0, 1.9, -1],
	"high": ["high_street", 100.0, 1.9, 1],
	"cafeto_real": ["calle_real", 40.0, 1.9, 1],
	"cafeto_lomas": ["calle_las_lomas", 100.0, 1.9, 1],
	"cafeto_colina": ["carrera_colina", 60.0, 1.9, 1],
}

var dir := ProjectSettings.globalize_path("res://tools/screens/store/")
var shots := [
	{"name": "01_ciudad", "route": "route_01", "bus": "buseta_8", "time": "manana", "rain": false, "view": "Close", "spot": "malecon"},
	{"name": "02_pasajeros", "route": "route_01", "bus": "midi_10", "time": "mediodia", "rain": false, "view": "Close", "spot": "board", "stop": 1},
	{"name": "02b_pasajeros", "route": "route_01", "bus": "midi_10", "time": "mediodia", "rain": false, "view": "Close", "spot": "board", "stop": 2},
	{"name": "02c_pasajeros", "route": "route_02", "bus": "midi_10", "time": "manana", "rain": false, "view": "Close", "spot": "board", "stop": 1},
	{"name": "02d_pasajeros", "route": "route_03", "bus": "buseta_8", "time": "mediodia", "rain": false, "view": "Close", "spot": "board", "stop": 1},
	{"name": "03_chiva", "route": "route_02", "bus": "chiva", "time": "atardecer", "rain": false, "view": "Close", "spot": "market"},
	{"name": "04_articulado", "route": "troncal", "bus": "articulado_18", "time": "mediodia", "rain": false, "view": "Far", "spot": "stop"},
	{"name": "05_aguacero", "route": "route_01", "bus": "city_12", "time": "noche", "rain": true, "view": "Close", "spot": "stop"},
	{"name": "06_cabina", "route": "route_01", "bus": "buseta_8", "time": "atardecer", "rain": true, "view": "Cockpit", "spot": "market"},
	{"name": "07_carrera", "route": "arcade", "bus": "buseta_8", "time": "mediodia", "rain": false, "view": "Far", "spot": "arcade"},
	# Not store shots: checks of the newer towns. "aerial" looks down from that
	# many metres up and back, to see how much of the ground is built on.
	{"name": "11_cafeto_aereo", "route": "cafeto_c0", "bus": "buseta_8", "time": "mediodia", "rain": false, "view": "Far", "spot": "cafeto_real", "aerial": 90.0},
	{"name": "12_cafeto_lomas", "route": "cafeto_c0", "bus": "buseta_8", "time": "mediodia", "rain": false, "view": "Far", "spot": "cafeto_lomas"},
	{"name": "13_cafeto_colina_aereo", "route": "cafeto_c0", "bus": "buseta_8", "time": "manana", "rain": false, "view": "Far", "spot": "cafeto_colina", "aerial": 70.0},
	{"name": "14_cafeto_carrera", "route": "arcade_cafeto", "bus": "buseta_8", "time": "mediodia", "rain": false, "view": "Far", "spot": "arcade"},
	# "hide_controls" drives with the on-screen wheel, pedals and D/R hidden.
	{"name": "15_sin_controles", "route": "route_01", "bus": "buseta_8", "time": "manana", "rain": false, "view": "Close", "spot": "malecon", "hide_controls": true},
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(dir)
	Profile.load_from("user://store_shots_save.json")
	Profile.data = PlayerProfile.new()
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.intro_done = true
	Profile.data.coins = 18450
	Profile.data.xp = 900
	Profile.data.stats["shifts"] = 12
	Profile.data.stats["passengers"] = 286
	Profile.data.achievements.append("first_shift")
	Profile.data.daily_streak = 3
	Profile.data.last_daily = DailyChallenge.day_before(DailyChallenge.today_key())
	GameSettings.language = "es_CO"
	CityShift.shift_seed = 7
	var only := OS.get_environment("ONLY")
	for shot: Dictionary in shots:
		if only == "" or str(shot["name"]).contains(only):
			await _take(shot)
	if only == "" or only == "menu":
		await _menus()
	get_tree().quit()


func _own(kind: String, id: String) -> void:
	if not (Profile.data.owned[kind] as Array).has(id):
		(Profile.data.owned[kind] as Array).append(id)
	Profile.data.select(kind, id)


func _take(shot: Dictionary) -> void:
	_own(Catalog.ROUTES, shot["route"])
	_own(Catalog.BUSES, shot["bus"])
	CityShift.forced_time = shot["time"]
	CityShift.forced_rain = WeatherPlan.FORCE_RAIN if shot["rain"] else WeatherPlan.FORCE_DRY
	var showed_controls := GameSettings.show_drive_controls
	GameSettings.show_drive_controls = not shot.get("hide_controls", false)
	var scene: CityShift = load(SCENE).instantiate()
	add_child(scene)
	await _seconds(1.0)
	var spot: String = shot["spot"]
	var bus: BusController = scene.get_node("Bus")
	if spot == "arcade":
		var arcade := scene.arcade
		var placed: Dictionary = arcade.runner.point_at(arcade.run.boosts[2] - 30.0)
		var fwd: Vector2 = placed["forward"]
		var right := Vector2(-fwd.y, fwd.x)
		GameEvents.bus_relocate_requested.emit(placed["position"] + right * 1.9 - fwd * 6.0, RoadNetwork.heading_of(fwd))
	elif spot == "board":
		var stop: RouteStop = scene.route.stops[int(shot.get("stop", 1))]
		GameEvents.bus_relocate_requested.emit(stop.position + stop.forward() * bus.spec.body_centre_z(), stop.heading)
	elif spot == "stop":
		var target: RouteStop = scene.route.stops[1]
		var p: Dictionary = scene.network.sample(target.road, target.along - 28.0 * target.dir, 1.9, target.dir)
		GameEvents.bus_relocate_requested.emit(p["position"], p["heading"])
	else:
		var s: Array = SPOTS[spot]
		var p: Dictionary = scene.network.sample(s[0], s[1], s[2], s[3])
		GameEvents.bus_relocate_requested.emit(p["position"], p["heading"])
	var rig: CameraRig = scene.get_node("CameraRig")
	while rig.view_name() != shot["view"]:
		rig.next_view()
	if shot["rain"]:
		var weather := scene.weather_for_tools()
		weather.start_downpour(true)
		weather.clock.wetness = 1.0
	await _seconds(1.8)
	if shot.has("aerial"):
		var up := float(shot["aerial"])
		var eye := Camera3D.new()
		eye.far = 900.0
		scene.add_child(eye)
		var at := bus.global_position
		var back := bus.global_transform.basis.z.normalized()
		eye.global_position = at + back * up * 0.9 + Vector3.UP * up
		eye.look_at(at - back * up * 0.6, Vector3.UP)
		eye.make_current()
		await _seconds(0.5)
	if spot == "board":
		GameEvents.door_toggle_requested.emit()
		await _seconds(2.6)
	await _shot(shot["name"])
	if OS.get_environment("PAUSED") != "":
		# PAUSED=1 also saves the pause sheet over the same scene.
		var hud: DriveHud = scene.get_node("Hud")
		hud._open_settings()
		await _frames(4)
		await _shot(shot["name"] + "_pausa")
		hud._close_settings()
	GameSettings.show_drive_controls = showed_controls
	scene.queue_free()
	await _frames(3)


func _menus() -> void:
	# A mid-career player: some buses and routes bought, the rest still for sale.
	Profile.data.owned[Catalog.BUSES] = ["buseta_8", "midi_10", "chiva"]
	Profile.data.owned[Catalog.ROUTES] = ["starter_a", "starter_b", "route_01", "route_02", "libre", "arcade"]
	Profile.data.select(Catalog.ROUTES, "route_01")
	Profile.data.select(Catalog.BUSES, "chiva")
	var menu: MainMenu = load(MENU).instantiate()
	add_child(menu)
	await _seconds(0.8)
	await _shot("08_inicio")
	menu.show_tab(2)
	await _seconds(0.6)
	await _shot("09_garaje")
	menu.show_tab(1)
	await _seconds(0.6)
	await _shot("10_rutas")
	for tab: Array in [[3, "10b_chofer"], [4, "10c_logros"], [5, "10d_ajustes"]]:
		menu.show_tab(tab[0])
		await _seconds(0.6)
		await _shot(tab[1])
	# Home with Alto Cafeto picked on the Routes tab: its own Carrera Express.
	Profile.data.town = "Alto Cafeto"
	menu.show_tab(0)
	await _seconds(0.6)
	await _shot("08b_inicio_cafeto")
	Profile.data.town = ""
	menu.queue_free()
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(dir + shot_name + ".png")
	print("STORE saved ", shot_name, " ", image.get_size())
