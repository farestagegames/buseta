extends GutTest
## Headless soak: run the real traffic on both shipped maps for 5 simulated
## minutes with the bus parked in awkward spots (in a junction, at a roundabout
## entry, in a stop bay) and prove no agent deadlocks: none is stuck over 30 s
## while far from the bus and not at a red light. Anything stuck over 20 s that
## is far from the bus is printed so a stuck behaviour can be traced.

const DT := 1.0 / 60.0
const SOAK_SECONDS := 300.0
const STUCK_LOG := 20.0
const STUCK_LIMIT := 30.0
const FAR_FROM_BUS := 60.0
const MARISOL := "res://data/packs/colombia/maps/puerto_marisol.json"
const ALTO := "res://data/packs/colombia/maps/alto_cafeto.json"

enum Spot { JUNCTION, ROUNDABOUT, BAY }

var _spec: BusSpec
var _network: RoadNetwork
var _flow: TrafficFlow
var _rear := Vector2.ZERO
var _heading := 0.0
var _stuck := PackedFloat32Array()
var _worst := PackedFloat32Array()
var _prev_lane := PackedInt32Array()
var _reported := PackedByteArray()


func _build(map_path: String) -> void:
	var map_data := MapLoader.read_json(map_path)
	_spec = BusSpec.new()
	_network = RoadNetwork.from_data(map_data, Country.pack.traffic_side, Country.pack.default_speed_limit())
	_flow = TrafficFlow.new(LaneGraph.build(_network, map_data), _spec)
	_flow.watch_props([])
	var profile := GraphicsQuality.PROFILES[GraphicsQuality.Level.HIGH]
	var density := TrafficSystem.map_traffic_share(map_data)
	_flow.spawn(TrafficSystem.scaled_count(int(profile["traffic_cars"]), density),
		TrafficSystem.scaled_count(int(profile["traffic_motos"]), density))
	_stuck.resize(_flow.agents.size())
	_stuck.fill(0.0)
	_worst.resize(_flow.agents.size())
	_worst.fill(0.0)
	_prev_lane.resize(_flow.agents.size())
	_prev_lane.fill(-1)
	_reported.resize(_flow.agents.size())
	_reported.fill(0)


func _forward(angle: float) -> Vector2:
	return Vector2(-sin(angle), -cos(angle))


## Puts the bus body centre at world, facing heading, and reports it parked.
func _place(world: Vector2, heading: float, doors_open: bool) -> void:
	_rear = world + _forward(heading) * _spec.body_centre_z()
	_heading = heading
	_flow.set_bus(_rear, heading, 0.0, _rear, heading, doors_open)


func _bus_centre() -> Vector2:
	return _rear + _forward(_heading) * -_spec.body_centre_z()


## First signal junction (three or more roads), and the heading of an approach.
func _junction_spot(map_data: Dictionary) -> Array:
	var nodes := _flow.graph.signal_nodes()
	assert_false(nodes.is_empty(), "Map needs a signal junction")
	var node_id: String = nodes[0]
	var node: Dictionary = _network.nodes[node_id]
	for road: Dictionary in map_data["roads"]:
		if not road.get("traffic", true):
			continue
		if road["to"] == node_id or road["from"] == node_id:
			return [node["position"], _approach_heading(road, node_id)]
	return [node["position"], 0.0]


## A roundabout entry, with the bus nose at the give-way line.
func _roundabout_spot(map_data: Dictionary) -> Array:
	for node_id: String in _network.nodes:
		var node: Dictionary = _network.nodes[node_id]
		if node["kind"] != "roundabout":
			continue
		for road: Dictionary in map_data["roads"]:
			if not road.get("traffic", true) or road["to"] != node_id:
				continue
			var dir := 1
			var heading := _approach_heading(road, node_id)
			var along: float = _network.roads[road["id"]]["length"] - float(node["radius"]) - LaneGraph.STOP_LINE_GAP
			var entry: Vector2 = _network.sample(road["id"], along, 0.0, dir)["position"]
			var nose_at := entry
			var world := nose_at - _forward(heading) * (_spec.wheelbase + _spec.front_overhang)
			return [world, heading]
	return [Vector2.ZERO, 0.0]


## A stop bay on a long road, at the kerb.
func _bay_spot(map_data: Dictionary) -> Array:
	for road: Dictionary in map_data["roads"]:
		if not road.get("traffic", true) or _network.roads[road["id"]]["length"] < 220.0:
			continue
		var dir := 1
		var along: float = minf(150.0, float(_network.roads[road["id"]]["length"]) - 60.0)
		var lateral := RoadNetwork.ROAD_HALF_WIDTH + RoadNetwork.BAY_DEPTH / 2.0 - 0.2
		var placed: Dictionary = _network.sample(road["id"], along, lateral, dir)
		return [placed["position"], placed["heading"]]
	return [Vector2.ZERO, 0.0]


func _approach_heading(road: Dictionary, into_node: String) -> float:
	var dir := 1 if road["to"] == into_node else -1
	var along: float = float(_network.roads[road["id"]]["length"]) - 6.0 if dir == 1 else 6.0
	return _network.sample(road["id"], along, 0.0, dir)["heading"]


## The turn of the lane the agent has chosen next, as text.
func _turn_of(agent: TrafficAgent) -> String:
	if agent.next_lane < 0:
		return "?"
	var link: TrafficLane = _flow.graph.lanes[agent.next_lane]
	return "left" if link.turn < 0 else ("right" if link.turn > 0 else "straight")


## True when the agent is stopped at a red light (a temporary, legitimate stop).
func _at_red(agent: TrafficAgent) -> bool:
	var lane: TrafficLane = _flow.graph.lanes[agent.lane]
	if lane.is_link or not _flow.plans.has(lane.end_node):
		return false
	return _flow.light_at(lane.end_node, lane.group) == TrafficLightPlan.Light.RED \
		and lane.length - agent.distance < TrafficFlow.LOOK_AHEAD


func _spot(map_data: Dictionary, spot: Spot) -> Array:
	match spot:
		Spot.JUNCTION:
			return _junction_spot(map_data)
		Spot.ROUNDABOUT:
			return _roundabout_spot(map_data)
		_:
			return _bay_spot(map_data)


func test_no_deadlock_in_a_five_minute_soak() -> void:
	for map_path: String in [MARISOL, ALTO]:
		var map_data := MapLoader.read_json(map_path)
		for spot: Spot in [Spot.JUNCTION, Spot.ROUNDABOUT, Spot.BAY]:
			_build(map_path)
			var placed := _spot(map_data, spot)
			_place(placed[0], placed[1], true)
			var ticks := int(SOAK_SECONDS / DT)
			var bus_centre := _bus_centre()
			var far_sq := FAR_FROM_BUS * FAR_FROM_BUS
			for _tick in ticks:
				_flow.step(DT)
				for i in _flow.agents.size():
					var agent := _flow.agents[i]
					if agent.speed >= TrafficSense.STILL_SPEED:
						_stuck[i] = 0.0
					else:
						# Stuck counts only when far from the bus and off a red
						# light, and restarts when the breaker moves it lanes.
						var eligible := _flow.positions[i].distance_squared_to(bus_centre) > far_sq \
							and not _at_red(agent)
						_stuck[i] = _stuck[i] + DT if eligible else 0.0
						if agent.lane != _prev_lane[i]:
							_stuck[i] = 0.0
							_prev_lane[i] = agent.lane
					_worst[i] = maxf(_worst[i], _stuck[i])
					if _stuck[i] > STUCK_LOG and _reported[i] == 0:
						_reported[i] = 1
						var lane: TrafficLane = _flow.graph.lanes[agent.lane]
						print("SOAK %s spot=%d agent=%d %s lane=%d (%s) link=%s rem=%.0f dist=%.0f turn=%s" % [
							map_path.get_file(), spot, i, "moto" if agent.is_moto else "car",
							agent.lane, lane.road, lane.is_link, lane.length - agent.distance,
							_flow.positions[i].distance_to(bus_centre), _turn_of(agent)])
			for i in _flow.agents.size():
				assert_lte(_worst[i], STUCK_LIMIT + 1.0,
					"%s spot %d: agent %d stuck %.1f s far from the bus and not at a red light" % [
						map_path.get_file(), spot, i, _worst[i]])
