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

var network: RoadNetwork
var ground: GroundSurface
var route: RouteRunner


## Runs before the bus readies, so it builds with the player's choices.
func _enter_tree() -> void:
	var bus_item := Profile.selected_item(Catalog.BUSES)
	var livery := Profile.selected_item(Catalog.LIVERIES)
	var spec: BusSpec = (load(bus_item["file"]) as BusSpec).duplicate()
	spec.body_colour = _colour(livery["body"])
	spec.stripe_colour = _colour(livery["stripe"])
	var bus: BusController = get_node("Bus")
	bus.spec = spec
	(bus.get_node("Visual") as BusVisual).spec = spec


func _colour(values: Array) -> Color:
	return Color(values[0], values[1], values[2])


func _ready() -> void:
	var route_data := MapLoader.read_json(Profile.selected_item(Catalog.ROUTES)["file"])
	var map_data := MapLoader.read_json(route_data["map"])
	network = RoadNetwork.from_data(map_data)
	route = RouteRunner.build(route_data, network)
	for stop in route.stops:
		network.add_bay(stop.road, stop.along, stop.dir)
	ground = MapLoader.build_ground(map_data, network)

	_city.build(map_data, network, ground, route)
	_obstacles.setup(map_data, network, ground, _bus.spec, _city.lamp_spots)
	_bus.start_at(ground, route.start_position, route.start_heading)
	_route_system.setup(route, _bus.spec, network)
	_traffic.setup(map_data, network, ground, _bus.spec)
	_score.setup(network, _bus.spec)
	_crowd.setup(route, ground)
	_beacon.setup(ground)
	GameEvents.map_ready.emit(network, route)


func route_system_for_tools() -> RouteSystem:
	return _route_system


func traffic_for_tools() -> TrafficSystem:
	return _traffic
