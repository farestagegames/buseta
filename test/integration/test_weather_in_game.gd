extends GutTest
## The time of day and a downpour in the real city: the events they send and
## what the bus, the timetable, the lights and the report make of them.

const SCENE := preload("res://scenes/main/city_shift.tscn")

var scene: CityShift
var weather: WeatherDirector
var rain_heard: Array[float] = []
var hints: Array[String] = []
var report: Dictionary = {}


func before_each() -> void:
	rain_heard.clear()
	hints.clear()
	report = {}
	GameEvents.rain_changed.connect(_on_rain)
	GameEvents.hint_shown.connect(_on_hint)
	GameEvents.shift_report_ready.connect(_on_report)


func after_each() -> void:
	GameEvents.rain_changed.disconnect(_on_rain)
	GameEvents.hint_shown.disconnect(_on_hint)
	GameEvents.shift_report_ready.disconnect(_on_report)
	CityShift.forced_time = ""
	CityShift.forced_rain = WeatherPlan.FORCE_DRY


func _on_rain(amount: float) -> void:
	rain_heard.append(amount)


func _on_hint(text: String) -> void:
	hints.append(text)


func _on_report(shift_report: Dictionary) -> void:
	report = shift_report


func _start(time_id: String, rain: int) -> void:
	CityShift.forced_time = time_id
	CityShift.forced_rain = rain
	scene = SCENE.instantiate()
	add_child_autofree(scene)
	weather = scene.weather_for_tools()
	# Past the first frames, where night materials are drawn unseen to build them.
	await wait_physics_frames(6)


func test_a_dry_shift_reports_no_rain() -> void:
	await _start("manana", WeatherPlan.FORCE_DRY)
	assert_eq(weather.time.id, "manana")
	await wait_physics_frames(10)
	assert_true(rain_heard.all(func(amount: float) -> bool: return amount == 0.0))
	assert_eq((scene.get_node("Bus") as BusController).model.grip, 1.0)


func test_the_downpour_tells_the_street_sounds_and_shows_a_tip() -> void:
	await _start("mediodia", WeatherPlan.FORCE_RAIN)
	weather.start_downpour()
	await wait_seconds(0.5)
	assert_gt(rain_heard.size(), 0, "rain_changed is sent as the rain builds")
	weather.start_downpour(true)
	await wait_physics_frames(3)
	assert_gt(rain_heard.max(), 0.5)
	assert_true(hints.has("Downpour: brake early"))
	var audio: AudioDirector = scene.get_node("AudioDirector")
	assert_gt(audio.mixer.rain, 0.5, "The rain layer follows")


func test_a_soaked_road_takes_grip_from_the_bus_and_time_from_the_timetable() -> void:
	await _start("mediodia", WeatherPlan.FORCE_RAIN)
	weather.start_downpour(true)
	weather.clock.wetness = 1.0
	await wait_seconds(1.0)
	var bus: BusController = scene.get_node("Bus")
	assert_almost_eq(bus.model.grip, RainSettings.from_pack(Country.pack.data).wet_grip, 0.02)
	var traffic := scene.traffic_for_tools()
	assert_lt(traffic.flow.speed_share, 1.0)
	assert_gt(traffic.flow.gap_scale, 1.0)
	var route := scene.route_system_for_tools()
	assert_gt(route.rain_slack, 0.0)
	assert_lt(route.timetable_clock(), route.clock)


func test_night_switches_on_the_lamps_windows_and_bus_lights() -> void:
	await _start("noche", WeatherPlan.FORCE_DRY)
	var visual: BusVisual = scene.get_node("Bus/Visual")
	assert_true(visual._night_lamps[0].visible, "Headlamps glow")
	assert_eq(visual._headlight.visible, int(GraphicsQuality.current_profile()["bus_lights"]) >= 1)
	var obstacles: ObstacleField = scene.get_node("Obstacles")
	assert_true(obstacles._pools_instance.visible, "Lamp pools on the road")
	var city: CityBuilder = scene.get_node("City")
	var flats: ShaderMaterial = city._facades["flats"]
	assert_gt(float(flats.get_shader_parameter("lit_share")), 0.0)
	assert_eq((scene.get_node("Sun") as DirectionalLight3D).shadow_enabled, false, "No sun shadows at night")


func test_daytime_leaves_the_lights_off() -> void:
	await _start("mediodia", WeatherPlan.FORCE_DRY)
	var visual: BusVisual = scene.get_node("Bus/Visual")
	assert_false(visual._night_lamps[0].visible)
	assert_false(visual._headlight.visible)
	var obstacles: ObstacleField = scene.get_node("Obstacles")
	assert_false(obstacles._pools_instance.visible)


func test_the_wipers_run_in_the_rain_and_rest_when_dry() -> void:
	await _start("mediodia", WeatherPlan.FORCE_RAIN)
	var visual: BusVisual = scene.get_node("Bus/Visual")
	assert_eq(visual._wipers[0].rotation.z, 0.0, "At rest when dry")
	weather.start_downpour(true)
	await wait_seconds(0.5)
	assert_lt(visual._wipers[0].rotation.z, -0.05, "Sweeping")
	assert_eq(BusVisual.wiper_angle(0.0), 0.0)
	assert_almost_eq(BusVisual.wiper_angle(0.5), -BusVisual.WIPER_SWEEP, 0.0001)


func test_the_report_names_the_time_and_the_downpour() -> void:
	await _start("noche", WeatherPlan.FORCE_RAIN)
	weather.start_downpour(true)
	await wait_physics_frames(3)
	GameEvents.finish_shift_requested.emit()
	await wait_physics_frames(2)
	assert_eq(report.get("time_of_day"), "noche")
	assert_true(report.get("downpour"))
	assert_eq(int(report["counts"]["downpours"]), 1)
	assert_eq(int(report["counts"]["clean_downpours"]), 1, "Nothing went wrong while it poured")
	assert_true(String(report["details"]).contains("Downpour survived"))


func test_a_crash_in_the_downpour_loses_the_bonus() -> void:
	await _start("mediodia", WeatherPlan.FORCE_RAIN)
	weather.start_downpour(true)
	await wait_physics_frames(3)
	GameEvents.bus_collided.emit(4.0)
	await wait_physics_frames(2)
	GameEvents.finish_shift_requested.emit()
	await wait_physics_frames(2)
	assert_eq(int(report["counts"]["downpours"]), 1)
	assert_eq(int(report["counts"]["clean_downpours"]), 0)


func test_the_cheat_starts_a_downpour() -> void:
	await _start("manana", WeatherPlan.FORCE_DRY)
	GameEvents.downpour_requested.emit()
	await wait_seconds(1.0)
	assert_ne(weather.clock.phase, WeatherPlan.Phase.DRY)
