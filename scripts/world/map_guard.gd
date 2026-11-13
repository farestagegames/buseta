class_name MapGuard
extends Node
## Keeps the bus in town: off any road over water, or far from every road for a
## moment, it goes back to the route (or the nearest road in the arcade) with a hint.

const CHECK_EVERY := 0.25
## Metres from the nearest asphalt before the bus counts as lost.
const FAR_FROM_ROAD := 30.0
## How long it may stay that far out before it is brought back.
const FAR_SECONDS := 1.5
## Quiet time after a rescue, so one splash gives one hint.
const COOLDOWN := 1.0

var rescues: int = 0

var _bus: BusController
var _ground: GroundSurface
var _network: RoadNetwork
var _on_route: bool = true
var _check_left: float = CHECK_EVERY
var _far_for: float = 0.0
var _cooldown: float = 0.0


func setup(bus: BusController, ground: GroundSurface, network: RoadNetwork, on_route: bool) -> void:
	_bus = bus
	_ground = ground
	_network = network
	_on_route = on_route


## Past the pavement where the ground is under the water line. A wheel up on the
## kerb is not in the river, even where a road runs right down to it.
static func in_water(ground: GroundSurface, network: RoadNetwork, point: Vector2) -> bool:
	if network != null:
		if network.edge_distance(point) <= GroundSurface.PAVEMENT_WIDTH:
			return false
		# A roundabout island is built-up land, even at the ferry landing.
		for node: Dictionary in network.nodes.values():
			if float(node["island"]) > 0.0 and point.distance_to(node["position"]) < float(node["island"]):
				return false
	return ground.terrain_height(point) < GroundSurface.SEA_LEVEL


func _physics_process(dt: float) -> void:
	if _bus == null:
		return
	_cooldown = maxf(_cooldown - dt, 0.0)
	_check_left -= dt
	if _check_left > 0.0:
		return
	_check_left += CHECK_EVERY
	if _cooldown > 0.0:
		return
	var rear := Vector2(_bus.global_position.x, _bus.global_position.z)
	var front := rear + _bus.model.forward_vector() * _bus.spec.wheelbase
	if in_water(_ground, _network, front) or in_water(_ground, _network, rear):
		rescue()
		return
	var centre := (rear + front) / 2.0
	if _network.distance_to_road(centre) > FAR_FROM_ROAD:
		_far_for += CHECK_EVERY
		if _far_for >= FAR_SECONDS:
			rescue()
	else:
		_far_for = 0.0


func rescue() -> void:
	rescues += 1
	_far_for = 0.0
	_cooldown = COOLDOWN
	if _on_route:
		# The same as the Reset button: back onto the route where the bus left it.
		GameEvents.reset_requested.emit()
	else:
		var rear := Vector2(_bus.global_position.x, _bus.global_position.z)
		var pose := _network.nearest_lane_pose(rear)
		GameEvents.bus_relocate_requested.emit(pose["position"], pose["heading"])
	GameEvents.hint_shown.emit("Back on the road")
