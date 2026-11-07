class_name CityShift
extends Node3D
## Level root. Loads the route and map data, then hands each module what it
## needs. This is the only script that knows about all of them.

const MENU_SCENE := "res://scenes/main/main_menu.tscn"

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
@onready var _hud: DriveHud = $Hud
@onready var _camera: Camera3D = $CameraRig

var network: RoadNetwork
var ground: GroundSurface
var route: RouteRunner


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
	var bus_item := Profile.selected_item(Catalog.BUSES)
	var livery := Profile.selected_item(Catalog.LIVERIES)
	var spec: BusSpec = (load(bus_item["file"]) as BusSpec).duplicate()
	spec.body_colour = _colour(livery["body"])
	spec.stripe_colour = _colour(livery["stripe"])
	spec.keep_to_side(Country.pack.traffic_side)
	return spec


static func chosen_look() -> DriverLook:
	return DriverLook.from_item(Profile.selected_item(Catalog.DRIVERS))


static func _colour(values: Array) -> Color:
	return Color(values[0], values[1], values[2])


func _ready() -> void:
	var route_data := MapLoader.read_json(Profile.selected_item(Catalog.ROUTES)["file"])
	var map_data := MapLoader.read_map_of(route_data)
	network = RoadNetwork.from_data(map_data, Country.pack.traffic_side, Country.pack.default_speed_limit())
	route = RouteRunner.build(route_data, network)
	for stop in route.stops:
		network.add_bay(stop.road, stop.along, stop.dir)
	ground = MapLoader.build_ground(map_data, network)
	for feature: Dictionary in ground.features:
		if feature["kind"] == "bump":
			route.add_hazard(feature["position"])

	_city.build(map_data, network, ground, route)
	_obstacles.setup(map_data, network, ground, _bus.spec, _city.lamp_spots)
	_bus.start_at(ground, route.start_position, route.start_heading)
	_route_system.setup(route, _bus.spec, network)
	_traffic.setup(map_data, network, ground, _bus.spec)
	_score.setup(network, _bus.spec)
	_crowd.setup(route, ground, _bus.get_node("Visual"))
	_beacon.setup(ground)
	GameEvents.map_ready.emit(network, route)
	_tutorial.setup(_hud, _route_system, _bus.spec)
	_intro.setup(network, ground, _bus, _camera)
	if not Profile.data.intro_done:
		_begin_first_shift.call_deferred()


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
