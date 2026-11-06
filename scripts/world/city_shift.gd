class_name CityShift
extends Node3D
## Level root. Loads the route and map data, then hands each module what it
## needs. This is the only script that knows about all of them.

@export_file("*.json") var route_file: String = "res://data/routes/route_01.json"

@onready var _bus: BusController = $Bus
@onready var _city: CityBuilder = $City
@onready var _obstacles: ObstacleField = $Obstacles
@onready var _route_system: RouteSystem = $RouteSystem
@onready var _crowd: PassengerCrowd = $Crowd
@onready var _beacon: StopBeacon = $Beacon

var network: RoadNetwork
var ground: GroundSurface
var route: RouteRunner


func _ready() -> void:
	var route_data := MapLoader.read_json(route_file)
	var map_data := MapLoader.read_json(route_data["map"])
	network = RoadNetwork.from_data(map_data)
	route = RouteRunner.build(route_data, network)
	for stop in route.stops:
		network.add_bay(stop.road, stop.along, stop.dir)
	ground = MapLoader.build_ground(map_data, network)

	_city.build(map_data, network, ground, route)
	_obstacles.setup(map_data, network, ground, _bus.spec)
	_bus.start_at(ground, route.start_position, route.start_heading)
	_route_system.setup(route, _bus.spec)
	_crowd.setup(route, ground)
	_beacon.setup(ground)
	GameEvents.map_ready.emit(network, route)


func route_system_for_tools() -> RouteSystem:
	return _route_system
