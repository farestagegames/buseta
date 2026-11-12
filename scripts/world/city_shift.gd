class_name CityShift
extends Node3D
## Level root. Loads the route and map data, then hands each module what it
## needs. This is the only script that knows about all of them.

const MENU_SCENE := "res://scenes/main/main_menu.tscn"
const SKY_HAZE := 0.15 ## Keeps the sky blue however thick the distance haze is.

## Sets where people flag the bus down and the weather. Tests and tools fix it, and
## play leaves it at -1 so each shift is different.
static var shift_seed: int = -1
## Tests and tools can choose the time of day by its pack id, and force the rain
## with WeatherPlan.FORCE_RAIN or FORCE_DRY. Play leaves both alone.
static var forced_time: String = ""
static var forced_rain: int = WeatherPlan.PLANNED

@onready var _bus: BusController = $Bus
@onready var _city: CityBuilder = $City
@onready var _obstacles: ObstacleField = $Obstacles
@onready var _route_system: RouteSystem = $RouteSystem
@onready var _crowd: PassengerCrowd = $Crowd
@onready var _beacon: StopBeacon = $Beacon
@onready var _traffic: TrafficSystem = $Traffic
@onready var _score: ScoreKeeper = $ScoreKeeper
@onready var _intro: IntroCutscene = $Intro
@onready var _tutorial: TutorialDirector = $Tutorial
var police: PoliceSystem
## How long the weather plans for in the arcade, which has no timetable.
const ARCADE_WEATHER_SECONDS := 300.0
## The arcade mode, when the chosen route is the arcade course; null otherwise.
var arcade: ArcadeSystem
@onready var _hud: DriveHud = $Hud
@onready var _camera: Camera3D = $CameraRig
@onready var _street_life: StreetLife = $StreetLife
@onready var _weather: WeatherDirector = $Weather

var network: RoadNetwork
var ground: GroundSurface
var route: RouteRunner
var time_of_day: TimeOfDay
var bird_ambience: BirdAmbience


## Runs before the bus readies, so it builds with the player's choices.
func _enter_tree() -> void:
	var spec := chosen_spec()
	var bus: BusController = get_node("Bus")
	bus.spec = spec
	var visual: BusVisual = bus.get_node("Visual")
	visual.spec = spec
	visual.driver_look = chosen_look()


## The player's bus in their livery. A copy, so the shared data stays untouched.
static func chosen_spec() -> BusSpec:
	return spec_for(chosen_bus_item(), Profile.selected_item(Catalog.LIVERIES))


## The bus for this shift: the player's, unless the route has a bus of its own.
static func chosen_bus_item() -> Dictionary:
	var route := Profile.selected_item(Catalog.ROUTES)
	if route.has("only_bus"):
		return Profile.catalog.find(Catalog.BUSES, route["only_bus"])
	return Profile.selected_item(Catalog.BUSES)


## A copy, so the shared data stays untouched.
static func spec_for(bus_item: Dictionary, livery: Dictionary) -> BusSpec:
	var spec: BusSpec = (load(bus_item["file"]) as BusSpec).duplicate()
	spec.body_colour = _colour(livery["body"])
	spec.stripe_colour = _colour(livery["stripe"])
	spec.accent_colour = _colour(livery.get("accent", livery["stripe"]))
	spec.roof_colour = _colour(livery.get("roof", livery["body"]))
	spec.pattern = livery.get("pattern", "plain")
	spec.keep_to_side(Country.pack.traffic_side)
	return spec


static func chosen_look() -> DriverLook:
	return DriverLook.from_item(Profile.selected_item(Catalog.DRIVERS))


## The time of day the player picked, if their level has unlocked it.
static func chosen_time(times: Array[TimeOfDay]) -> TimeOfDay:
	if forced_time != "" and TimeOfDay.find(times, forced_time) != null:
		return TimeOfDay.find(times, forced_time)
	return TimeOfDay.pick(times, Profile.data.time_of_day, DriverLevel.level_for(Profile.data.xp))


static func _colour(values: Array) -> Color:
	return Color(values[0], values[1], values[2])


func _ready() -> void:
	var route_data := MapLoader.read_json(Profile.selected_item(Catalog.ROUTES)["file"])
	var map_data := MapLoader.read_map_of(route_data)
	network = RoadNetwork.from_data(map_data, Country.pack.traffic_side, Country.pack.default_speed_limit())
	var hail_seed := shift_seed if shift_seed >= 0 else randi()
	time_of_day = chosen_time(TimeOfDay.list_for(Country.pack.data, CityTheme.from_data(map_data)))
	route = RouteRunner.build(route_data, network, hail_seed, map_data)
	for stop in route.stops:
		if stop.kind == RouteStop.Kind.BAY:
			network.add_bay(stop.road, stop.along, stop.dir)
	ground = MapLoader.build_ground(map_data, network)
	for feature: Dictionary in ground.features:
		if feature["kind"] == "bump":
			route.add_hazard(feature["position"])

	_city.window_share = time_of_day.windows
	_city.build(map_data, network, ground, route)
	_street_life.setup(network, ground, route, time_of_day.pedestrians)
	_obstacles.setup(map_data, network, ground, _bus.spec, _city.lamp_spots)
	_bus.start_at(ground, route.start_position, route.start_heading)
	var is_arcade: bool = route_data.get("service", "") == "arcade"
	if not is_arcade:
		_route_system.setup(route, _bus.spec, network, int(route_data.get("fare", Country.pack.data["currency"]["fare"])))
	_traffic.setup(map_data, network, ground, _bus.spec, time_of_day.traffic)
	_traffic.watch_props(_obstacles.props)
	var difficulty := Profile.chosen_difficulty()
	_score.setup(network, _bus.spec, difficulty, route.goals, route.service)
	_route_system.dodger_chance = difficulty.dodger_chance
	if route.endless and not is_arcade:
		_route_system.endless_plan = route_data["hail"]
		_route_system.endless_map = map_data
		_score.give_up_below = RouteSystem.GIVE_UP_SATISFACTION
	police = PoliceSystem.new()
	add_child(police)
	# No police in the arcade: it is a race against the clock.
	police.setup(_traffic, difficulty if not is_arcade else Difficulty.new(), hail_seed + 17)
	if is_arcade:
		arcade = ArcadeSystem.new()
		add_child(arcade)
		arcade.setup(route, network, ground, hail_seed)
	_crowd.setup(route, ground, _bus.get_node("Visual"))
	_beacon.setup(ground)
	if arcade != null:
		_beacon.visible = false
		_beacon.process_mode = Node.PROCESS_MODE_DISABLED
	bird_ambience = BirdAmbience.new()
	bird_ambience.name = "BirdAmbience"
	add_child(bird_ambience)
	bird_ambience.setup(map_data, ground, time_of_day, hail_seed + 101)
	_setup_audio()
	_setup_weather(hail_seed)
	GameEvents.map_ready.emit(network, route)
	_tutorial.setup(_hud, _route_system, _bus.spec)
	_intro.setup(network, ground, _bus, _camera)
	if not Profile.data.intro_done:
		_begin_first_shift.call_deferred()


## The player's horn, and where the sea, stalls and stops are for the street sounds.
func _setup_audio() -> void:
	var audio: AudioDirector = $AudioDirector
	audio.use_horn(Profile.horn_for(chosen_bus_item()))
	var stalls := PackedVector2Array()
	for prop in _obstacles.props:
		if prop.kind == "stall":
			stalls.append(Vector2(prop.position.x, prop.position.z))
	var stops := PackedVector2Array()
	for stop in route.stops:
		stops.append(stop.position)
	audio.setup_street(ground.coast_x, stalls, stops)


## The time of day and this shift's weather, planned from its seed so the same
## seed brings the same downpour.
func _setup_weather(weather_seed: int) -> void:
	var settings := RainSettings.from_pack(Country.pack.data)
	var shift_seconds: float = route.stops[route.stops.size() - 1].due if not route.stops.is_empty() else ARCADE_WEATHER_SECONDS
	_weather.setup(time_of_day, WeatherPlan.make(weather_seed, time_of_day, settings, shift_seconds, forced_rain), settings)


## A new driver sees the opening scene, then the tutorial, with the clock held.
func _begin_first_shift() -> void:
	GameEvents.shift_held_changed.emit(true)
	_hud.visible = false
	_intro.finished.connect(_on_intro_finished)
	_tutorial.finished.connect(_on_tutorial_finished)
	_intro.play()


func _on_intro_finished() -> void:
	_hud.visible = true
	_tutorial.start()


func _on_tutorial_finished() -> void:
	Profile.finish_tutorial()
	GameEvents.shift_held_changed.emit(false)


func route_system_for_tools() -> RouteSystem:
	return _route_system


func traffic_for_tools() -> TrafficSystem:
	return _traffic


func weather_for_tools() -> WeatherDirector:
	return _weather
