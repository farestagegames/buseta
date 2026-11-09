class_name WeatherDirector
extends Node
## Runs the time of day and the weather for one shift. Sets the sky, sun, fog and
## rain sheet itself, and tells everything else through GameEvents: the street
## sounds, the wet road, the bus's grip, the traffic, the people and the lamps.

## Changes smaller than this are not worth sending on.
const CHANGE_STEP := 0.004
## Rain streaks keep this share of their brightness at full night.
const NIGHT_RAIN_BRIGHTNESS := 0.45

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var camera_path: NodePath

var clock: WeatherClock
var time: TimeOfDay

var _sun: DirectionalLight3D
var _environment: Environment
var _sheet: RainSheet
var _held: bool = false
var _finished: bool = false
var _sent_rain: float = -1.0
var _sent_cloud: float = -1.0
var _sent_wetness: float = -1.0
var _sent_lights: float = -1.0
var _sent_headlights: bool = false
var _profile: Dictionary = {} ## The graphics level, read again when settings change.


func setup(time_of_day: TimeOfDay, plan: WeatherPlan, settings: RainSettings) -> void:
	time = time_of_day
	clock = WeatherClock.new(plan, settings, time_of_day)
	_sun = get_node(sun_path)
	_environment = (get_node(environment_path) as WorldEnvironment).environment
	_sheet = RainSheet.new()
	_sheet.camera = get_node(camera_path)
	add_child(_sheet)
	GameEvents.shift_held_changed.connect(func(held: bool) -> void: _held = held)
	GameEvents.shift_completed.connect(func(_summary: Dictionary) -> void: _finished = true)
	GameEvents.downpour_requested.connect(start_downpour)
	_profile = GraphicsQuality.current_profile()
	GameSettings.changed.connect(_on_settings_changed)
	GameEvents.time_of_day_set.emit(time.id)
	_publish(true)


## Starts the rain now. For the hidden cheat and the screenshot tools.
func start_downpour(skip_build: bool = false) -> void:
	clock.plan.start_now(clock.clock, skip_build)


func _physics_process(dt: float) -> void:
	if clock == null or _held or _finished:
		return
	match clock.advance(dt):
		WeatherClock.Change.DOWNPOUR_STARTED:
			GameEvents.hint_shown.emit("Downpour: brake early")
		WeatherClock.Change.RAIN_STOPPED:
			GameEvents.hint_shown.emit("The rain is easing off")
	_publish(false)


## Sends whatever has changed enough to notice.
func _publish(force: bool) -> void:
	var rain_moved := force or _moved(clock.rain, _sent_rain)
	if not (rain_moved or _moved(clock.cloud, _sent_cloud) or _moved(clock.wetness, _sent_wetness)):
		return
	_sent_rain = clock.rain
	_sent_cloud = clock.cloud
	_sent_wetness = clock.wetness
	_apply_sky()
	if rain_moved:
		GameEvents.rain_changed.emit(clock.rain)
	GameEvents.weather_updated.emit(clock)
	var lights := clock.lights()
	var headlights := clock.headlights()
	if force or absf(lights - _sent_lights) > 0.02 or headlights != _sent_headlights:
		_sent_lights = lights
		_sent_headlights = headlights
		GameEvents.lighting_changed.emit(lights, headlights)


func _on_settings_changed() -> void:
	_profile = GraphicsQuality.current_profile()
	_apply_sky()


## True when a value has changed enough to send, or has just reached zero.
static func _moved(now: float, sent: float) -> bool:
	return absf(now - sent) > CHANGE_STEP or (now == 0.0 and sent != 0.0)


## Sky, sun, fog and rain sheet for the time of day under the current clouds.
func _apply_sky() -> void:
	if clock == null:
		return
	var air := Atmosphere.mix(time, clock.settings, clock.cloud, clock.rain)
	var sky: ProceduralSkyMaterial = _environment.sky.sky_material
	sky.sky_top_color = air.sky_top
	sky.sky_horizon_color = air.sky_horizon
	sky.ground_horizon_color = air.sky_horizon
	sky.ground_bottom_color = air.ground_bottom
	_environment.fog_light_color = air.fog
	_environment.fog_sky_affect = CityShift.SKY_HAZE
	var profile := _profile
	_environment.fog_density = float(profile["fog_density"]) * air.fog_scale + air.fog_extra
	_environment.ambient_light_color = air.ambient
	_environment.ambient_light_energy = air.ambient_energy
	_sun.light_color = air.sun_colour
	_sun.light_energy = air.sun_energy
	_sun.rotation = air.sun_rotation
	_sun.shadow_enabled = bool(profile["shadows"]) and air.shadows
	_sun.shadow_opacity = air.shadow_strength
	var brightness := lerpf(1.0, NIGHT_RAIN_BRIGHTNESS, clampf(time.lights, 0.0, 1.0))
	_sheet.show_rain(clock.rain, brightness, int(profile["rain_layers"]))
