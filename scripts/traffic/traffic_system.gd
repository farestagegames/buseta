class_name TrafficSystem
extends Node3D
## Moves all traffic and runs the signals. Sees the bus only through telemetry.

const CAR_HALF_LENGTH := 2.2
const CAR_HALF_WIDTH := 0.9
const CRUISE_LOW := 9.5
const CRUISE_HIGH := 12.5
const LOOK_AHEAD := 60.0
const AMBER_BRAKE := 3.2 ## Cars go through amber when they could not stop at this rate.
const YIELD_DISTANCE := 12.0
const RING_CLEARANCE := 24.0
const ONCOMING_CLEARANCE := 32.0
const SIGNAL_RANGE := 75.0
const CROSSING_REACH := 5.0 ## Sideways reach of a stop line, in metres.
const LAMP_HEIGHT := 4.3
const CONTACT_CHECK_RADIUS := 14.0
const BUS_FAULT_SPEED := 0.3 ## Slower than this, the bus is not to blame.
const HIT_REPEAT_SECONDS := 1.0
const SEPARATION_PER_TICK := 0.06

const CAR_COLOURS: Array[Color] = [
	Color(0.2, 0.3, 0.55), Color(0.75, 0.75, 0.78), Color(0.17, 0.17, 0.2), Color(0.55, 0.15, 0.15),
	Color(0.85, 0.82, 0.72), Color(0.25, 0.4, 0.35), Color(0.9, 0.9, 0.92), Color(0.6, 0.45, 0.2),
]

var graph: LaneGraph
var agents: Array[TrafficAgent] = []
var plans: Dictionary = {} ## Node id to TrafficLightPlan.
var time: float = 0.0

var _ground: GroundSurface
var _spec: BusSpec
var _bus_position: Vector2 = Vector2.ZERO
var _bus_heading: float = 0.0
var _bus_speed: float = 0.0
var _bus_active: bool = false
var _batch: MultiMesh
var _lamps: MultiMesh
var _heads: Array[Dictionary] = [] ## lane, node, group, first lamp instance.
var _approaches: Array[Dictionary] = [] ## lane, node, group, line, forward.
var _previous_side: Dictionary = {} ## Approach index to sign of bus nose position.
var _cruise_limit: float = 13.0
var _random := RandomNumberGenerator.new()


func setup(map_data: Dictionary, network: RoadNetwork, ground: GroundSurface, spec: BusSpec) -> void:
	_ground = ground
	_spec = spec
	_random.seed = 4242
	graph = LaneGraph.build(network, map_data)
	_build_signals()
	_spawn_cars()
	_build_car_batch()
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)


func light_at(node_id: String, group: int) -> TrafficLightPlan.Light:
	var plan: TrafficLightPlan = plans[node_id]
	return plan.state(group, time)


## The signal the bus is approaching, for the HUD and the autopilot.
## Returns {state, distance} with state -1 when there is none.
func bus_signal() -> Dictionary:
	var forward := Vector2(-sin(_bus_heading), -cos(_bus_heading))
	var nose := _bus_position + forward * (_spec.wheelbase + _spec.front_overhang)
	var best := {"state": -1, "distance": INF}
	for approach in _approaches:
		var direction: Vector2 = approach["forward"]
		if direction.dot(forward) < 0.7:
			continue
		var offset: Vector2 = approach["line"] - nose
		var ahead := offset.dot(direction)
		var across := absf(offset.cross(direction))
		if ahead > -1.0 and ahead < SIGNAL_RANGE and across < CROSSING_REACH and ahead < float(best["distance"]):
			best = {"state": int(light_at(approach["node"], approach["group"])), "distance": ahead}
	return best


## Gap from the bus nose to the nearest car ahead of it, for the autopilot.
func bus_gap_ahead() -> Dictionary:
	var forward := Vector2(-sin(_bus_heading), -cos(_bus_heading))
	var nose := _bus_position + forward * (_spec.wheelbase + _spec.front_overhang)
	var right := Vector2(-forward.y, forward.x)
	var best := {"gap": INF, "speed": 0.0}
	for agent in agents:
		var lane: TrafficLane = graph.lanes[agent.lane]
		var facing := lane.forward_at(agent.distance).dot(forward)
		if facing < -0.5:
			continue
		var offset := _position_of(agent) - nose
		var ahead := offset.dot(forward)
		if ahead > 0.0 and ahead < float(best["gap"]) and absf(offset.dot(right)) < 2.3:
			# A car crossing in front is not going our way, so treat it as stopped.
			best = {"gap": ahead - CAR_HALF_LENGTH, "speed": agent.speed if facing > 0.7 else 0.0}
	return best


func _physics_process(dt: float) -> void:
	time += dt
	for i in agents.size():
		_update_agent(i, dt)
	_check_bus_hits()
	_update_lamps()
	if _bus_active:
		_check_red_lights()
		var ahead := bus_signal()
		GameEvents.signal_ahead.emit(ahead["state"], ahead["distance"])


func _on_telemetry(data: BusTelemetry) -> void:
	_bus_position = Vector2(data.position.x, data.position.z)
	_bus_heading = data.heading
	_bus_speed = data.speed
	_bus_active = true


func _position_of(agent: TrafficAgent) -> Vector2:
	return (graph.lanes[agent.lane] as TrafficLane).point_at(agent.distance) + agent.nudge


func _update_agent(index: int, dt: float) -> void:
	var agent: TrafficAgent = agents[index]
	var lane: TrafficLane = graph.lanes[agent.lane]
	if agent.next_lane == -1:
		agent.next_lane = lane.next[_random.randi_range(0, lane.next.size() - 1)]
	var hold := _gap_to_traffic(index, agent, lane)
	var line := _gap_to_stop(agent, lane)
	if line < float(hold["gap"]):
		hold = {"gap": line, "speed": 0.0}
	var bus_gap := _gap_to_bus(agent, lane)
	if bus_gap < float(hold["gap"]):
		hold = {"gap": bus_gap, "speed": maxf(_bus_speed, 0.0)}
	agent.drive(lane.speed_limit(agent.cruise), hold["gap"], hold["speed"], dt)
	if agent.distance >= lane.length:
		agent.distance -= lane.length
		agent.lane = agent.next_lane
		agent.next_lane = -1
		var entered: TrafficLane = graph.lanes[agent.lane]
		agent.distance = minf(agent.distance, entered.length - 0.01)
	_write_car(index, agent)


func _gap_to_traffic(index: int, agent: TrafficAgent, lane: TrafficLane) -> Dictionary:
	var best := {"gap": INF, "speed": 0.0}
	var remaining := lane.length - agent.distance
	for i in agents.size():
		if i == index:
			continue
		var other: TrafficAgent = agents[i]
		var gap := INF
		if other.lane == agent.lane and other.distance > agent.distance:
			gap = other.distance - agent.distance
		elif other.lane == agent.next_lane:
			gap = remaining + other.distance
		elif other.lane != agent.lane and agent.next_lane >= 0:
			var following: TrafficLane = graph.lanes[agent.next_lane]
			if not following.next.is_empty() and other.lane == following.next[0]:
				gap = remaining + following.length + other.distance
		gap -= TrafficAgent.CAR_LENGTH
		if gap < float(best["gap"]):
			best = {"gap": maxf(gap, 0.1), "speed": other.speed}
	return best


func _gap_to_stop(agent: TrafficAgent, lane: TrafficLane) -> float:
	if lane.is_link:
		return INF
	var remaining := lane.length - agent.distance
	if remaining > LOOK_AHEAD:
		return INF
	var node: Dictionary = graph.network.nodes[lane.end_node]
	if plans.has(lane.end_node):
		var light := light_at(lane.end_node, lane.group)
		if light == TrafficLightPlan.Light.RED:
			return remaining
		if light == TrafficLightPlan.Light.AMBER and remaining > agent.speed * agent.speed / (2.0 * AMBER_BRAKE):
			return remaining
		if _must_yield_turning(agent, lane, remaining):
			return remaining
	elif node["kind"] == "roundabout" and remaining < YIELD_DISTANCE and _ring_is_busy(agent, lane):
		return remaining
	return INF


## Left turns give way to oncoming traffic going straight on.
func _must_yield_turning(agent: TrafficAgent, lane: TrafficLane, remaining: float) -> bool:
	if agent.next_lane < 0 or (graph.lanes[agent.next_lane] as TrafficLane).turn != -1 or remaining > YIELD_DISTANCE:
		return false
	var heading := lane.forward_at(lane.length - 0.1)
	for other in agents:
		if other == agent:
			continue
		var other_lane: TrafficLane = graph.lanes[other.lane]
		if other_lane.is_link or other_lane.end_node != lane.end_node:
			continue
		var other_heading := other_lane.forward_at(other_lane.length - 0.1)
		if heading.dot(other_heading) > -0.7:
			continue
		if other_lane.length - other.distance < ONCOMING_CLEARANCE and other.speed > 1.0:
			return true
	return false


func _ring_is_busy(agent: TrafficAgent, lane: TrafficLane) -> bool:
	var entry := lane.points[lane.points.size() - 1]
	for other in agents:
		if other == agent:
			continue
		var other_lane: TrafficLane = graph.lanes[other.lane]
		if other_lane.is_link and other_lane.node == lane.end_node:
			if _position_of(other).distance_to(entry) < RING_CLEARANCE:
				return true
	var ring_centre: Vector2 = graph.network.nodes[lane.end_node]["position"]
	var body := BusFootprint.body_centre(_bus_position, _bus_heading, _spec)
	return body.distance_to(ring_centre) < 24.0 and body.distance_to(entry) < RING_CLEARANCE


func _gap_to_bus(agent: TrafficAgent, lane: TrafficLane) -> float:
	var forward := lane.forward_at(agent.distance)
	return BusFootprint.gap_ahead(_bus_position, _bus_heading, _spec, _position_of(agent), forward, CAR_HALF_LENGTH, CAR_HALF_WIDTH)


## Any contact between the bus and a car counts, whoever is moving. Only a bus
## that was moving is at fault. A car running into a parked bus just stops.
func _check_bus_hits() -> void:
	var forward := Vector2(-sin(_bus_heading), -cos(_bus_heading))
	var bus_velocity := forward * _bus_speed
	var centre := BusFootprint.body_centre(_bus_position, _bus_heading, _spec)
	for agent in agents:
		var spot := _position_of(agent)
		if spot.distance_squared_to(centre) > CONTACT_CHECK_RADIUS * CONTACT_CHECK_RADIUS:
			continue
		var car_forward := (graph.lanes[agent.lane] as TrafficLane).forward_at(agent.distance)
		if not BusFootprint.touches_car(_bus_position, _bus_heading, _spec, spot, car_forward):
			continue
		var away := (spot - centre).normalized()
		var closing := (bus_velocity - car_forward * agent.speed).length()
		if absf(_bus_speed) >= BUS_FAULT_SPEED and agent.stunned <= TrafficAgent.STUN_SECONDS - HIT_REPEAT_SECONDS:
			agent.hit_by_bus(bus_velocity)
			var loss := absf(_bus_speed) * ObstacleField.CAR_LOSS_HEAD_ON * 0.7
			GameEvents.obstacle_hit.emit("car", loss)
			if loss > 0.5:
				GameEvents.bus_collided.emit(loss)
		elif closing > 0.0:
			agent.stop_against_bus(away * SEPARATION_PER_TICK)


func _check_red_lights() -> void:
	var forward := Vector2(-sin(_bus_heading), -cos(_bus_heading))
	var nose := _bus_position + forward * (_spec.wheelbase + _spec.front_overhang)
	for i in _approaches.size():
		var approach: Dictionary = _approaches[i]
		var direction: Vector2 = approach["forward"]
		var offset: Vector2 = nose - approach["line"]
		var side := signf(offset.dot(direction))
		var was: float = _previous_side.get(i, side)
		_previous_side[i] = side
		if was < 0.0 and side > 0.0 and absf(offset.cross(direction)) < CROSSING_REACH and direction.dot(forward) > 0.5:
			if light_at(approach["node"], approach["group"]) == TrafficLightPlan.Light.RED:
				GameEvents.red_light_run.emit()


func _spawn_cars() -> void:
	var road_lanes: Array[int] = []
	for i in graph.lanes.size():
		if not (graph.lanes[i] as TrafficLane).is_link:
			road_lanes.append(i)
	var car_count: int = GraphicsQuality.current_profile()["traffic_cars"]
	for i in car_count:
		var lane_index: int = road_lanes[i * road_lanes.size() / car_count]
		var lane: TrafficLane = graph.lanes[lane_index]
		var start := lane.length * (0.25 + 0.5 * _random.randf())
		agents.append(TrafficAgent.new(lane_index, start, _random.randf_range(CRUISE_LOW, CRUISE_HIGH)))


func _build_car_batch() -> void:
	var field := ObstacleField.new()
	_batch = MultiMesh.new()
	_batch.transform_format = MultiMesh.TRANSFORM_3D
	_batch.use_colors = true
	_batch.mesh = field._mesh_for("car").build(LowPolyBuilder.vertex_colour_material())
	field.free()
	_batch.instance_count = agents.size()
	for i in agents.size():
		_batch.set_instance_color(i, CAR_COLOURS[i % CAR_COLOURS.size()])
		_write_car(i, agents[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _batch
	instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	instance.custom_aabb = AABB(Vector3(-2000.0, -200.0, -2000.0), Vector3(4000.0, 400.0, 4000.0))
	add_child(instance)


func _write_car(index: int, agent: TrafficAgent) -> void:
	var lane: TrafficLane = graph.lanes[agent.lane]
	var spot := _position_of(agent)
	var forward := lane.forward_at(agent.distance)
	var height := _ground.terrain_height(spot) + 0.12
	var ahead := _ground.terrain_height(spot + forward * 2.0)
	var pitch := atan2(ahead + 0.12 - height, 2.0)
	var basis := Basis(Vector3.UP, RoadNetwork.heading_of(forward)) * Basis(Vector3.RIGHT, pitch)
	_batch.set_instance_transform(index, Transform3D(basis, Vector3(spot.x, height, spot.y)))


func _build_signals() -> void:
	var nodes := graph.signal_nodes()
	for i in nodes.size():
		var node_id: String = nodes[i]
		plans[node_id] = TrafficLightPlan.new(float(i) * 7.0)
		for lane_index: int in graph.into_node[node_id]:
			var lane: TrafficLane = graph.lanes[lane_index]
			var line := lane.points[lane.points.size() - 1]
			var forward := lane.forward_at(lane.length - 0.1)
			_approaches.append({"lane": lane_index, "node": node_id, "group": lane.group, "line": line, "forward": forward})
	var housing := LowPolyBuilder.new()
	var lens := LowPolyBuilder.new()
	lens.box(Vector3.ZERO, Vector3(0.24, 0.24, 0.05), Color.WHITE)
	_lamps = MultiMesh.new()
	_lamps.transform_format = MultiMesh.TRANSFORM_3D
	_lamps.use_colors = true
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamps.mesh = lens.build(material)
	_lamps.instance_count = _approaches.size() * 3
	for i in _approaches.size():
		_build_signal_head(housing, i)
	var lamps_instance := MultiMeshInstance3D.new()
	lamps_instance.multimesh = _lamps
	lamps_instance.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	lamps_instance.custom_aabb = AABB(Vector3(-2000.0, -200.0, -2000.0), Vector3(4000.0, 400.0, 4000.0))
	lamps_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lamps_instance)
	var poles := MeshInstance3D.new()
	poles.mesh = housing.build(LowPolyBuilder.vertex_colour_material())
	add_child(poles)


## Each approach has a pole at the near-side corner, facing oncoming drivers.
func _build_signal_head(housing: LowPolyBuilder, index: int) -> void:
	var approach: Dictionary = _approaches[index]
	var forward: Vector2 = approach["forward"]
	var right := Vector2(-forward.y, forward.x)
	var spot: Vector2 = approach["line"] + right * 2.6
	var y := _ground.terrain_height(spot)
	var yaw := RoadNetwork.heading_of(forward)
	var pole := Color(0.15, 0.16, 0.18)
	housing.turned_box(Vector3(spot.x, y + 2.2, spot.y), Vector3(0.13, 4.4, 0.13), yaw, pole)
	var head := Vector3(spot.x, y + LAMP_HEIGHT, spot.y)
	housing.turned_box(head, Vector3(0.42, 1.1, 0.2), yaw, Color(0.05, 0.05, 0.06))
	var facing := Vector3(-forward.x, 0.0, -forward.y) * 0.13
	var basis := Basis(Vector3.UP, yaw)
	for lamp in 3:
		var at := head + facing + Vector3.UP * (0.32 - 0.32 * lamp)
		_lamps.set_instance_transform(index * 3 + lamp, Transform3D(basis, at))


func _update_lamps() -> void:
	var dim := Color(0.12, 0.12, 0.13)
	for i in _approaches.size():
		var approach: Dictionary = _approaches[i]
		var light := light_at(approach["node"], approach["group"])
		_lamps.set_instance_color(i * 3, Color(1.0, 0.15, 0.1) if light == TrafficLightPlan.Light.RED else dim)
		_lamps.set_instance_color(i * 3 + 1, Color(1.0, 0.7, 0.1) if light == TrafficLightPlan.Light.AMBER else dim)
		_lamps.set_instance_color(i * 3 + 2, Color(0.15, 1.0, 0.4) if light == TrafficLightPlan.Light.GREEN else dim)
