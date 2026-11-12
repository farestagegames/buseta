class_name TrafficFlow
extends RefCounted
## Drives every car and motorbike: following, signals, giving way, and getting
## round the bus and things in the road. Pure logic with no nodes, so tests can
## run it on a small map. TrafficSystem draws it and checks for crashes.
##
## Each tick a vehicle looks along its own path, as far as it could need to
## stop, and checks that strip against the bus body, the trailer and anything
## standing in the road. Other vehicles come from per-lane lists, so the cost
## grows with the number of vehicles, not its square.

signal horn_sounded(spot: Vector2, kind: int)

## A short toot, a long angry blast, or a motorbike's double beep.
enum Honk { TOOT, LONG, BEEP }

const CRUISE_LOW := 9.5
const CRUISE_HIGH := 12.5
const MOTO_CRUISE_LOW := 10.0
const MOTO_CRUISE_HIGH := 14.0
const LOOK_AHEAD := 60.0 ## How far before a junction its rules start to apply.
const AMBER_BRAKE := 3.2 ## Cars go through amber when they could not stop at this rate.
const YIELD_DISTANCE := 12.0
const RING_CLEARANCE := 24.0
const ONCOMING_CLEARANCE := 32.0
## From this far before a junction, a vehicle checks it for the bus.
const JUNCTION_LOOK := 30.0
## At a roundabout only the start of the way round counts as the junction.
const RING_ENTRY_CHECK := 15.0
## A junction counts as clear only with this much room past it.
const EXIT_CHECK := 6.0
## A bus moving away along the path faster than this is followed, not waited for.
const MOVING_AWAY := 2.0
## How far ahead a vehicle checks its path, in metres and metres per m/s.
const LOOK_BASE := 14.0
const LOOK_PER_SPEED := 2.6
const LOOK_MAX := 50.0
const PATH_POINTS := 48
## Seconds stopped before pulling into the oncoming lane to pass.
const CAR_WAIT := 2.5
const MOTO_WAIT := 0.8
## A bus standing this long counts as parked even with its doors shut.
const BUS_PARKED_SECONDS := 10.0
## Passes are planned from this close, and waiting counts from this close.
const DECIDE_GAP := 18.0
const BLOCKED_GAP := 10.0
const CAR_PASS_SPEED := 7.0
## Within this many metres of the bus's ends, a vehicle passing it keeps to the
## passing speed.
const BESIDE_BUS := 6.0
const MOTO_PASS_SPEED := 4.0
## Width of the strip beside an open-door bus kept clear for passengers, from the
## bus side towards the kerb, and how far it reaches past each end of the bus.
const BOARDING_ZONE_WIDTH := 4.0
const BOARDING_ZONE_REACH := 1.0
## A moto filtering past a car goes at most this much faster than it.
const FILTER_SPEED := 4.0
const FILTER_ROOM := 0.45
## Clear road needed ahead before moving back into the usual line.
const RETURN_CLEAR := 8.0
## Free lane needed past what is being passed, so a pass never ends in a queue.
const ROOM_AHEAD := 12.0
const HORN_AFTER := 7.0
## A second, longer blast comes at this multiple of the first wait.
const SECOND_HORN_SHARE := 2.2
const MOTO_HORN_SHARE := 0.5
## Closer than this to the bus while still moving faster than CUT_IN_SPEED
## means the bus pulled out in front.
const CUT_IN_GAP := 6.0
const CUT_IN_SPEED := 4.0
const PROP_REFRESH := 0.25
## Over the centre line by more than this, a vehicle is checked by oncoming traffic.
const INTRUDE_REACH := 0.3
const ONCOMING_SWEEP_SECONDS := 1.0
## A vehicle over the centre line this close to a junction holds back traffic
## about to come out of it towards it.
const PASSER_WATCH := 50.0
const MAX_BOXES := 32
const VEHICLE_BOXES := 8

var graph: LaneGraph
var agents: Array[TrafficAgent] = []
var plans: Dictionary = {} ## Node id to TrafficLightPlan.
var time: float = 0.0
var spec: BusSpec
var bus_rear: Vector2 = Vector2.ZERO
var bus_heading: float = 0.0
var bus_speed: float = 0.0
var bus_active: bool = false
var bus_doors_open: bool = false
var trailer_axle: Vector2 = Vector2.ZERO
var trailer_heading: float = 0.0
var bus_still_time: float = 0.0
## On a wet road traffic drives slower, as a share of its usual speed, and keeps
## longer gaps, as times its usual gap. WeatherClock sets both.
var speed_share: float = 1.0
var gap_scale: float = 1.0
## Where each vehicle was drawn after its last move, and its lane's direction.
var positions: PackedVector2Array = PackedVector2Array()
var forwards: PackedVector2Array = PackedVector2Array()

var _random := RandomNumberGenerator.new()
var _side: int = 1
var _props: Array[KnockableProp] = []
var _prop_boxes: Array[TrafficBox] = []
var _prop_seen := PackedVector2Array()
var _prop_on_road := PackedByteArray()
var _prop_state := PackedByteArray()
## Per lane, the road props beside or in it, five numbers each: from and to
## along the lane, least and most kerbward point across it, and the prop index.
## Props hardly ever move, so this turns checking them into simple sums.
var _lane_props: Array[PackedFloat32Array] = []
var _props_moved: bool = true
var _prop_timer: float = 0.0
var _bus_box := TrafficBox.new()
var _trailer_box := TrafficBox.new()
## The strip between the bus and the kerb while its doors are open, where people
## step on and off. Traffic stops for it instead of riding through them.
var _boarding_box := TrafficBox.new()
var _boarding := false
var _has_trailer: bool = false
var _lane_head := PackedInt32Array() ## Per lane, the first vehicle on it, or -1.
var _lane_next := PackedInt32Array() ## Per vehicle, the next one on its lane.
var _lane_out := PackedInt32Array() ## Per lane, how many of its vehicles are over the centre line.
# Per vehicle, read once a tick so the inner loops call no functions.
var _offset := PackedFloat32Array()
var _half_width := PackedFloat32Array()
var _half_length := PackedFloat32Array()
var _out := PackedByteArray()
var _path := PackedVector2Array()
var _path_s := PackedFloat32Array()
var _path_count: int = 0
var _chain := PackedInt32Array([-1, -1, -1])
var _link_chain := PackedInt32Array([-1, -1, -1])
var _boxes: Array[TrafficBox] = []
var _box_count: int = 0
var _vehicle_boxes: Array[TrafficBox] = []
var _vehicle_count: int = 0
var _leader_box := TrafficBox.new()
# What the vehicle being updated has found ahead.
var _gap: float = INF
var _lead: float = 0.0
var _blocker: TrafficBox = null
var _blocker_span: Vector2 = Vector2.ZERO ## For a prop blocker: its span across the lane.
var _blocker_end: float = 0.0 ## For a prop blocker: its far end, in lane metres.
var _cap: float = INF


func _init(lane_graph: LaneGraph, bus_spec: BusSpec, random_seed: int = 4242) -> void:
	graph = lane_graph
	spec = bus_spec
	_side = graph.network.traffic_side
	_random.seed = random_seed
	_path.resize(PATH_POINTS)
	_path_s.resize(PATH_POINTS)
	_boxes.resize(MAX_BOXES)
	for i in VEHICLE_BOXES:
		var box := TrafficBox.new()
		box.kind = TrafficBox.Kind.VEHICLE
		_vehicle_boxes.append(box)
	_leader_box.kind = TrafficBox.Kind.VEHICLE
	_lane_head.resize(graph.lanes.size())
	_lane_out.resize(graph.lanes.size())
	_lane_props.resize(graph.lanes.size())
	var nodes := graph.signal_nodes()
	for i in nodes.size():
		plans[nodes[i]] = TrafficLightPlan.new(float(i) * 7.0)


func light_at(node_id: String, group: int) -> TrafficLightPlan.Light:
	var plan: TrafficLightPlan = plans[node_id]
	return plan.state(group, time)


## Spreads cars and motorbikes over the road lanes.
func spawn(car_count: int, moto_count: int) -> void:
	var road_lanes: Array[int] = []
	for i in graph.lanes.size():
		if not (graph.lanes[i] as TrafficLane).is_link:
			road_lanes.append(i)
	for i in car_count:
		var lane_index: int = road_lanes[i * road_lanes.size() / car_count]
		var lane: TrafficLane = graph.lanes[lane_index]
		var start := lane.length * (0.25 + 0.5 * _random.randf())
		var car := TrafficAgent.new(lane_index, start, _random.randf_range(CRUISE_LOW, CRUISE_HIGH))
		car.batch_index = i
		add_agent(car)
	for i in moto_count:
		var lane_index: int = road_lanes[(i * road_lanes.size() / moto_count + 3) % road_lanes.size()]
		var lane: TrafficLane = graph.lanes[lane_index]
		var moto := TrafficAgent.new(lane_index, lane.length * _random.randf_range(0.1, 0.8), _random.randf_range(MOTO_CRUISE_LOW, MOTO_CRUISE_HIGH))
		moto.is_moto = true
		moto.batch_index = i
		add_agent(moto)


func add_agent(agent: TrafficAgent) -> void:
	agents.append(agent)
	positions.append(position_of(agent))
	forwards.append((graph.lanes[agent.lane] as TrafficLane).forward_at(agent.distance))


## Props in the road become obstacles: cones, bins, stalls and parked cars.
func watch_props(props: Array[KnockableProp]) -> void:
	_props = props
	_prop_boxes.clear()
	for prop in props:
		var box := TrafficBox.new()
		box.kind = TrafficBox.Kind.PROP
		_prop_boxes.append(box)
	_prop_seen.resize(props.size())
	_prop_seen.fill(Vector2(INF, INF))
	_prop_on_road.resize(props.size())
	_prop_on_road.fill(0)
	_prop_state.resize(props.size())
	_prop_state.fill(255)
	_prop_timer = 0.0
	_props_moved = true


func set_bus(rear_axle: Vector2, heading: float, speed: float, axle: Vector2, axle_heading: float, doors_open: bool) -> void:
	bus_rear = rear_axle
	bus_heading = heading
	bus_speed = speed
	trailer_axle = axle
	trailer_heading = axle_heading
	bus_doors_open = doors_open
	bus_active = true


func position_of(agent: TrafficAgent) -> Vector2:
	var lane: TrafficLane = graph.lanes[agent.lane]
	var forward := lane.forward_at(agent.distance)
	return lane.point_at(agent.distance) + Vector2(-forward.y, forward.x) * float(_side) * agent.offset() + agent.nudge


func step(dt: float) -> void:
	time += dt
	_prepare(dt)
	for i in agents.size():
		_update_agent(i, dt)


func _prepare(dt: float) -> void:
	if positions.size() != agents.size():
		positions.resize(agents.size())
		forwards.resize(agents.size())
		for i in agents.size():
			_store(i)
	_lane_head.fill(-1)
	_lane_out.fill(0)
	var count := agents.size()
	_lane_next.resize(count)
	_offset.resize(count)
	_half_width.resize(count)
	_half_length.resize(count)
	_out.resize(count)
	for i in range(count - 1, -1, -1):
		var agent: TrafficAgent = agents[i]
		var lane := agent.lane
		_lane_next[i] = _lane_head[lane]
		_lane_head[lane] = i
		if agent.is_moto:
			_offset[i] = agent.kerb_shift + agent.shift
			_half_width[i] = TrafficAgent.MOTO_HALF_WIDTH
			_half_length[i] = TrafficAgent.MOTO_HALF_LENGTH
		else:
			_offset[i] = agent.shift
			_half_width[i] = TrafficAgent.CAR_HALF_WIDTH
			_half_length[i] = TrafficAgent.CAR_HALF_LENGTH
		var edge := _offset[i] - _half_width[i]
		var road: TrafficLane = graph.lanes[lane]
		var out := edge < -road.min_lateral - INTRUDE_REACH and edge < -road.lateral_at(agent.distance) - INTRUDE_REACH
		_out[i] = 1 if out else 0
		if out:
			_lane_out[lane] += 1
	if bus_active:
		_has_trailer = TrafficSense.bus_boxes(bus_rear, bus_heading, bus_speed, spec, trailer_axle, trailer_heading, _bus_box, _trailer_box)
	_boarding = bus_active and bus_doors_open
	if _boarding:
		var forward := Vector2(-sin(bus_heading), -cos(bus_heading))
		var kerb := Vector2(-forward.y, forward.x) * float(_side)
		var centre := bus_rear + forward * -spec.body_centre_z()
		# One box for the bus and the strip, so traffic passes it like a wider
		# parked bus, on the road side only.
		_boarding_box.kind = TrafficBox.Kind.BUS
		_boarding_box.set_pose(centre + kerb * (BOARDING_ZONE_WIDTH / 2.0), forward,
			spec.overall_length() / 2.0 + BOARDING_ZONE_REACH, spec.body_width / 2.0 + BOARDING_ZONE_WIDTH / 2.0)
		_boarding_box.velocity = Vector2.ZERO
	bus_still_time = bus_still_time + dt if absf(bus_speed) < TrafficSense.STILL_SPEED else 0.0
	_prop_timer -= dt
	if _prop_timer <= 0.0:
		_prop_timer = PROP_REFRESH
		_refresh_props()


func _update_agent(index: int, dt: float) -> void:
	var agent: TrafficAgent = agents[index]
	var lane: TrafficLane = graph.lanes[agent.lane]
	if agent.next_lane == -1:
		agent.next_lane = lane.next[_random.randi_range(0, lane.next.size() - 1)]
	var following: TrafficLane = graph.lanes[agent.next_lane]
	_chain[0] = agent.lane
	_chain[1] = agent.next_lane
	_chain[2] = following.next[0] if not following.next.is_empty() else -1
	_gap = INF
	_lead = 0.0
	_blocker = null
	_cap = INF
	_follow_traffic(index, agent, lane)
	var line := _gap_to_stop(agent, lane)
	if line < _gap:
		_gap = line
		_lead = 0.0
		_blocker = null
	var reach := clampf(LOOK_BASE + agent.speed * LOOK_PER_SPEED, LOOK_BASE, LOOK_MAX)
	if not _props.is_empty():
		_props_ahead(index, agent, reach)
	_gather(index, agent, lane, reach + agent.half_length())
	if _box_count > 0:
		_look_ahead(agent, reach)
	_consider_passing(index, agent, lane, dt)
	var free := lane.speed_limit(agent.cruise)
	if not lane.is_link:
		# Slows for a turn before reaching it, not on it.
		var turn_speed := (graph.lanes[agent.next_lane] as TrafficLane).speed_limit(agent.cruise)
		if turn_speed < free:
			free = minf(free, TrafficAgent.approach_speed(turn_speed, lane.length - agent.distance))
	if agent.is_passing():
		var to_bus := _to_beside_bus(index)
		var pass_speed := MOTO_PASS_SPEED if agent.is_moto else CAR_PASS_SPEED
		if to_bus <= 0.0 and agent.passing_bus and not _bus_parked() and _behind_bus_middle(index):
			# The bus is leaving: ease to a stop and let it go rather than race its back end.
			free = 0.0
		elif absf(agent.shift - agent.shift_target) > 0.1:
			free = minf(free, pass_speed)
		elif _bus_parked():
			free = minf(free, TrafficAgent.approach_speed(pass_speed, to_bus))
	agent.drive(minf(free * speed_share, _cap), _gap, _lead, dt, gap_scale)
	agent.step_shift(dt)
	if agent.distance >= lane.length:
		agent.distance -= lane.length
		agent.lane = agent.next_lane
		agent.next_lane = -1
		var entered: TrafficLane = graph.lanes[agent.lane]
		agent.distance = minf(agent.distance, entered.length - 0.01)
		if entered.is_link:
			agent.shift_target = 0.0
	_store(index)


## Metres to the stretch beside the bus where passing traffic goes slowly, as a
## passenger could step out or the bus pull away. Zero when in it.
func _to_beside_bus(index: int) -> float:
	if not bus_active:
		return INF
	var spot := positions[index]
	var away := spot.distance_to(_bus_box.centre) - _bus_box.half_length - BESIDE_BUS
	if _has_trailer:
		away = minf(away, spot.distance_to(_trailer_box.centre) - _trailer_box.half_length - BESIDE_BUS)
	return maxf(away, 0.0)


func _bus_parked() -> bool:
	return bus_doors_open or bus_still_time > BUS_PARKED_SECONDS


func _behind_bus_middle(index: int) -> bool:
	var forward := Vector2(-sin(bus_heading), -cos(bus_heading))
	var middle := bus_rear + forward * -spec.body_centre_z()
	return (positions[index] - middle).dot(forward) < 0.0


func _store(index: int) -> void:
	var agent: TrafficAgent = agents[index]
	var lane: TrafficLane = graph.lanes[agent.lane]
	if agent.is_moto:
		agent.kerb_shift = TrafficAgent.MOTO_KERB_SHIFT
		if lane.min_lateral < LaneGraph.LANE_OFFSET - 0.01:
			agent.kerb_shift -= TrafficAgent.MOTO_KERB_FOLLOW * (LaneGraph.LANE_OFFSET - lane.lateral_at(agent.distance))
	var pose := lane.pose_at(agent.distance)
	var shift := float(_side) * agent.offset()
	positions[index] = Vector2(pose.x - pose.w * shift, pose.y + pose.z * shift) + agent.nudge
	forwards[index] = Vector2(pose.z, pose.w)


## The nearest vehicle ahead on this lane and the next two that overlaps this
## one sideways. A moto beside a car in its lane filters past, but only a
## little faster than the car.
func _follow_traffic(index: int, agent: TrafficAgent, lane: TrafficLane) -> void:
	var my_offset := _offset[index]
	var my_half := _half_width[index]
	var my_length := _half_length[index]
	var before := 0.0 ## Metres from this vehicle to the start of the lane being scanned.
	for link in 3:
		var lane_index := _chain[link]
		if lane_index < 0:
			break
		var other_index := _lane_head[lane_index]
		while other_index >= 0:
			if other_index != index:
				var other: TrafficAgent = agents[other_index]
				var gap := (other.distance - agent.distance if link == 0 else before + other.distance) - my_length - _half_length[other_index]
				var apart := absf(_offset[other_index] - my_offset) - _half_width[other_index] - my_half
				if apart < 0.0:
					if (link > 0 or other.distance > agent.distance) and gap < _gap:
						_gap = maxf(gap, 0.1)
						_lead = other.speed
						_blocker = _broken_down(other_index)
				elif agent.is_moto and not other.is_moto and apart < FILTER_ROOM and gap < LOOK_MAX \
						and gap > -2.0 * (my_length + _half_length[other_index]):
					# Eases down in time to be only a little faster once beside it.
					_cap = minf(_cap, TrafficAgent.approach_speed(other.speed + FILTER_SPEED, gap))
			other_index = _lane_next[other_index]
		before = lane.length - agent.distance if link == 0 else before + (graph.lanes[lane_index] as TrafficLane).length


## A vehicle stopped after a crash can be passed like a parked car.
func _broken_down(other_index: int) -> TrafficBox:
	var other: TrafficAgent = agents[other_index]
	if other.stunned <= 0.0 or other.speed > TrafficSense.STILL_SPEED:
		return null
	_leader_box.set_pose(positions[other_index], forwards[other_index], other.half_length(), other.half_width())
	_leader_box.velocity = Vector2.ZERO
	_leader_box.index = other_index
	return _leader_box


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
	elif node["kind"] == "roundabout" and remaining < YIELD_DISTANCE and _ring_is_busy(lane):
		return remaining
	if remaining < JUNCTION_LOOK and (_bus_in_junction(agent, node) or _passer_coming(agent)):
		return remaining
	return INF


## True when a vehicle going round something is over the centre line near the
## start of the lane this one is about to join, coming towards it. This one
## then waits at its line, so the two never meet nose to nose.
func _passer_coming(agent: TrafficAgent) -> bool:
	if agent.next_lane < 0:
		return false
	var link: TrafficLane = graph.lanes[agent.next_lane]
	var facing := (graph.lanes[link.next[0]] as TrafficLane).opposite
	if facing < 0 or _lane_out[facing] == 0:
		return false
	var their_lane: TrafficLane = graph.lanes[facing]
	var other_index := _lane_head[facing]
	while other_index >= 0:
		var other := agents[other_index]
		if other != agent and _out[other_index] == 1 and their_lane.length - other.distance < PASSER_WATCH:
			return true
		other_index = _lane_next[other_index]
	return false


## Turns across the oncoming lane give way to traffic going straight on, and
## to a bus coming the other way.
func _must_yield_turning(agent: TrafficAgent, lane: TrafficLane, remaining: float) -> bool:
	var across_traffic := -graph.network.traffic_side
	if agent.next_lane < 0 or (graph.lanes[agent.next_lane] as TrafficLane).turn != across_traffic or remaining > YIELD_DISTANCE:
		return false
	var heading := lane.forward_at(lane.length - 0.1)
	for lane_index: int in graph.into_node[lane.end_node]:
		var other_lane: TrafficLane = graph.lanes[lane_index]
		if heading.dot(other_lane.forward_at(other_lane.length - 0.1)) > -0.7:
			continue
		var other_index := _lane_head[lane_index]
		while other_index >= 0:
			var other: TrafficAgent = agents[other_index]
			if other_lane.length - other.distance < ONCOMING_CLEARANCE and other.speed > 1.0:
				return true
			other_index = _lane_next[other_index]
	if bus_active and bus_speed > 1.0 and _bus_box.forward.dot(heading) < -0.7:
		var middle: Vector2 = graph.network.nodes[lane.end_node]["position"]
		var nose := bus_rear + _bus_box.forward * (spec.wheelbase + spec.front_overhang)
		var ahead := (middle - nose).dot(_bus_box.forward)
		return ahead > 0.0 and ahead < ONCOMING_CLEARANCE + float(graph.network.nodes[lane.end_node]["radius"])
	return false


func _ring_is_busy(lane: TrafficLane) -> bool:
	var entry := lane.points[lane.points.size() - 1]
	for link_index: int in graph.links_at[lane.end_node]:
		var other_index := _lane_head[link_index]
		while other_index >= 0:
			if positions[other_index].distance_to(entry) < RING_CLEARANCE:
				return true
			other_index = _lane_next[other_index]
	return false


## True when the bus is in, or about to be in, the part of the junction this
## vehicle is about to cross. It then waits at the line instead of entering.
func _bus_in_junction(agent: TrafficAgent, node: Dictionary) -> bool:
	if not bus_active or agent.next_lane < 0:
		return false
	var middle: Vector2 = node["position"]
	var near := float(node["radius"]) + JUNCTION_LOOK
	var front_near := _bus_box.centre.distance_to(middle) < near + _bus_box.radius()
	var rear_near := _has_trailer and _trailer_box.centre.distance_to(middle) < near + _trailer_box.radius()
	if not front_near and not rear_near:
		return false
	var link: TrafficLane = graph.lanes[agent.next_lane]
	var reach := link.length + EXIT_CHECK
	if node["kind"] == "roundabout":
		reach = minf(link.length, RING_ENTRY_CHECK)
	_link_chain[0] = agent.next_lane
	_link_chain[1] = link.next[0] if not link.next.is_empty() else -1
	_path_count = TrafficSense.trace(graph.lanes, _link_chain, 0.0, agent.base_offset(), _side, reach, _path, _path_s)
	var grow := agent.half_width() + TrafficSense.LOOK_MARGIN
	if front_near and _blocks_path(_bus_box, grow):
		return true
	return rear_near and _blocks_path(_trailer_box, grow)


## A bus on the path blocks it, unless it is further along and driving away,
## when it is simply followed. A bus coming round a roundabout towards the
## entry moves the same way as the path, but it is behind, so it blocks.
func _blocks_path(box: TrafficBox, grow: float) -> bool:
	if TrafficSense.first_contact(_path, _path_s, _path_count, box, grow) == INF:
		return false
	var k := TrafficSense.last_segment
	if k + 1 >= _path_count:
		return true
	var direction := (_path[k + 1] - _path[k]).normalized()
	return (box.centre - _path[k]).dot(direction) < 0.0 or box.velocity.dot(direction) < MOVING_AWAY


## Speed of a box along the path where the last contact check hit it.
func _speed_along(box: TrafficBox) -> float:
	var k := TrafficSense.last_segment
	if k < 0 or k + 1 >= _path_count:
		return 0.0
	var direction := (_path[k + 1] - _path[k]).normalized()
	return box.velocity.dot(direction)


## Props in the vehicle's strip on this lane and the next two.
func _props_ahead(index: int, agent: TrafficAgent, reach: float) -> void:
	var low := _offset[index] - _half_width[index] - TrafficSense.LOOK_MARGIN
	var high := _offset[index] + _half_width[index] + TrafficSense.LOOK_MARGIN
	var nose := agent.distance + _half_length[index]
	var tail := agent.distance - _half_length[index]
	var start := 0.0
	for link in 3:
		var lane_index := _chain[link]
		if lane_index < 0:
			break
		var entries := _lane_props[lane_index]
		var k := 0
		while k < entries.size():
			if entries[k + 3] > low and entries[k + 2] < high and start + entries[k + 1] > tail:
				var gap := start + entries[k] - nose
				if gap < _gap and gap < reach:
					_gap = maxf(gap, 0.1)
					_lead = 0.0
					_blocker = _prop_boxes[int(entries[k + 4])]
					_blocker_span = Vector2(entries[k + 2], entries[k + 3])
					_blocker_end = start + entries[k + 1]
			k += 5
		start += (graph.lanes[lane_index] as TrafficLane).length


## True when a prop lies in the strip from low to high across the lane, between
## from and to along the chain of lanes.
func _props_in(low: float, high: float, from: float, to: float) -> bool:
	var start := 0.0
	for link in 3:
		var lane_index := _chain[link]
		if lane_index < 0 or start > to:
			break
		var entries := _lane_props[lane_index]
		var k := 0
		while k < entries.size():
			if entries[k + 3] > low and entries[k + 2] < high and start + entries[k + 1] > from and start + entries[k] < to:
				return true
			k += 5
		start += (graph.lanes[lane_index] as TrafficLane).length
	return false


## Collects the boxes near enough to matter: the bus, its trailer, and oncoming
## vehicles when either side is over the centre line.
func _gather(index: int, agent: TrafficAgent, lane: TrafficLane, reach: float) -> void:
	_box_count = 0
	_vehicle_count = 0
	var spot := positions[index]
	if _boarding:
		_consider(_boarding_box, spot, reach)
	if bus_active:
		_consider(_bus_box, spot, reach)
		if _has_trailer:
			_consider(_trailer_box, spot, reach)
	if lane.is_link or lane.opposite < 0:
		return
	var mine_out := _out[index] == 1
	if not mine_out and _lane_out[lane.opposite] == 0:
		return
	var other_index := _lane_head[lane.opposite]
	while other_index >= 0 and _vehicle_count < VEHICLE_BOXES:
		var other: TrafficAgent = agents[other_index]
		if (mine_out or _out[other_index] == 1) and positions[other_index].distance_to(spot) < reach + other.speed * ONCOMING_SWEEP_SECONDS + other.half_length():
			var box := _vehicle_boxes[_vehicle_count]
			_vehicle_count += 1
			box.set_pose(positions[other_index], forwards[other_index], other.half_length(), other.half_width())
			box.velocity = forwards[other_index] * other.speed
			box.index = other_index
			TrafficSense.grow_box(box, other.speed * ONCOMING_SWEEP_SECONDS)
			_add_box(box)
		other_index = _lane_next[other_index]


func _consider(box: TrafficBox, spot: Vector2, reach: float) -> void:
	var limit := reach + box.radius()
	if spot.distance_squared_to(box.centre) < limit * limit:
		_add_box(box)


func _add_box(box: TrafficBox) -> void:
	if _box_count < MAX_BOXES:
		_boxes[_box_count] = box
		_box_count += 1


## Checks the strip the vehicle will drive along, at its own width, against
## every gathered box. The trace starts just short of its nose, so the gap
## found is bumper to bumper.
func _look_ahead(agent: TrafficAgent, reach: float) -> void:
	var grow := agent.half_width() + TrafficSense.LOOK_MARGIN
	var start := agent.distance + agent.half_length() - grow
	_path_count = TrafficSense.trace(graph.lanes, _chain, start, agent.offset(), _side, reach, _path, _path_s)
	for k in _box_count:
		var box := _boxes[k]
		var at := TrafficSense.first_contact(_path, _path_s, _path_count, box, grow)
		if at < _gap:
			_gap = maxf(at, 0.1)
			_lead = maxf(_speed_along(box), 0.0)
			_blocker = box


## Kept waiting behind the bus: a toot, then a longer blast if it goes on.
## Motorbikes are less patient and beep sooner.
func _honk_while_waiting(index: int, agent: TrafficAgent) -> void:
	var first := HORN_AFTER * (MOTO_HORN_SHARE if agent.is_moto else 1.0) + float(agent.batch_index % 3)
	if not agent.honked and agent.waiting > first:
		agent.honked = true
		agent.honk_cooldown = TrafficAgent.HONK_COOLDOWN
		horn_sounded.emit(positions[index], Honk.BEEP if agent.is_moto else Honk.TOOT)
	elif agent.honked and not agent.honked_twice and not agent.is_moto and agent.waiting > first * SECOND_HORN_SHARE:
		agent.honked_twice = true
		agent.honk_cooldown = TrafficAgent.HONK_COOLDOWN
		horn_sounded.emit(positions[index], Honk.LONG)


## A driver the bus has just hit leans on the horn.
func honk_after_hit(index: int) -> void:
	var agent := agents[index]
	agent.honk_cooldown = 0.0
	if agent.try_honk():
		horn_sounded.emit(positions[index], Honk.BEEP if agent.is_moto else Honk.LONG)


## Plans a way round something standing in the lane, or a way back after it.
func _consider_passing(index: int, agent: TrafficAgent, lane: TrafficLane, dt: float) -> void:
	if lane.is_link:
		agent.shift_target = 0.0
		agent.passing_bus = false
		agent.waiting = 0.0
		return
	if agent.shift_target != 0.0:
		if _can_return(index, agent):
			agent.shift_target = 0.0
			agent.passing_bus = false
		return
	var blocked := _blocker != null and _gap < BLOCKED_GAP and agent.speed < TrafficSense.STILL_SPEED and _blocker.is_still()
	agent.waiting = agent.waiting + dt if blocked else 0.0
	if not blocked:
		agent.honked = false
		agent.honked_twice = false
	elif _is_bus(_blocker):
		_honk_while_waiting(index, agent)
	# The bus pulled in close in front of a moving car.
	if _blocker != null and _is_bus(_blocker) and _gap < CUT_IN_GAP and agent.speed > CUT_IN_SPEED and agent.try_honk():
		horn_sounded.emit(positions[index], Honk.BEEP if agent.is_moto else Honk.TOOT)
	if _blocker == null or _gap > DECIDE_GAP or not _blocker.is_still() or not _is_parked(_blocker):
		return
	var hit := agent.distance + agent.half_length() + _gap
	if hit >= lane.length:
		return
	var span := _blocker_span
	var far_end := _blocker_end
	if _blocker.kind != TrafficBox.Kind.PROP:
		var origin := lane.point_at(hit)
		var forward := lane.forward_at(hit)
		span = TrafficSense.box_span(_blocker, origin, Vector2(-forward.y, forward.x) * float(_side))
		far_end = hit + TrafficSense.box_front(_blocker, origin, forward)
	var margin := TrafficSense.MOTO_PASS_MARGIN if agent.is_moto else TrafficSense.CAR_PASS_MARGIN
	var lane_lateral := lane.lateral_at(hit)
	var plan := TrafficSense.pass_target(span, agent.base_offset(), agent.half_width(), margin, lane_lateral)
	var clear_at := far_end + agent.half_length() * 2.0 + 2.0
	# The kerb side may be blocked by something else, such as a parked car.
	if plan.x > 0.0 and _corridor_has_props(index, agent, plan.x, clear_at):
		plan = TrafficSense.pass_target(span, agent.base_offset(), agent.half_width(), margin, lane_lateral, false)
	if is_nan(plan.x) or absf(plan.x) < 0.05 or _corridor_has_props(index, agent, plan.x, clear_at):
		return
	if clear_at > lane.length - 2.0 or not _room_ahead(agent, hit, clear_at + ROOM_AHEAD):
		return
	var needs_gap := plan.y > 0.0
	var wait := MOTO_WAIT if agent.is_moto else CAR_WAIT
	var clear := needs_gap and agent.waiting >= wait and _oncoming_clear(index, lane, clear_at - agent.distance)
	if TrafficSense.may_pass(needs_gap, agent.waiting, wait, clear, true) and _side_clear(index, agent, plan.x):
		agent.shift_target = plan.x
		agent.passing_bus = _is_bus(_blocker)


## True when a prop stands in the line the vehicle would take with this shift.
func _corridor_has_props(index: int, agent: TrafficAgent, shift: float, until: float) -> bool:
	if _props.is_empty():
		return false
	var middle := agent.base_offset() + shift
	var half := _half_width[index] + TrafficSense.LOOK_MARGIN
	return _props_in(middle - half, middle + half, agent.distance - _half_length[index], until)


func _is_bus(box: TrafficBox) -> bool:
	return box.kind == TrafficBox.Kind.BUS or box.kind == TrafficBox.Kind.TRAILER


## Only something that will stay put is worth going round: a prop, a crashed
## car, or a bus with its doors open or that has stood a while. A bus stopped
## in a queue is waited for.
func _is_parked(box: TrafficBox) -> bool:
	match box.kind:
		TrafficBox.Kind.BUS, TrafficBox.Kind.TRAILER:
			return _bus_parked()
		TrafficBox.Kind.VEHICLE:
			return box == _leader_box
	return true


## No vehicle in the lane between from and to, so a pass has somewhere to end.
func _room_ahead(agent: TrafficAgent, from: float, to: float) -> bool:
	var other_index := _lane_head[agent.lane]
	while other_index >= 0:
		var other: TrafficAgent = agents[other_index]
		if other != agent and other.distance > from and other.distance < to and other.stunned <= 0.0:
			return false
		other_index = _lane_next[other_index]
	return true


## Nothing coming the other way that could reach the pass before it is done,
## including traffic still crossing the junction ahead or about to.
func _oncoming_clear(index: int, lane: TrafficLane, needed: float) -> bool:
	var seconds := needed / CAR_PASS_SPEED + 3.0
	var spot := positions[index]
	var forward := forwards[index]
	if lane.opposite >= 0:
		var other_index := _lane_head[lane.opposite]
		while other_index >= 0:
			var along := (positions[other_index] - spot).dot(forward)
			if along > -6.0 and along < needed + agents[other_index].speed * seconds + 10.0:
				return false
			other_index = _lane_next[other_index]
		var to_end := lane.length - agents[index].distance
		for link_index: int in graph.links_at[lane.end_node]:
			var link: TrafficLane = graph.lanes[link_index]
			if link.next[0] != lane.opposite:
				continue
			if not _clear_on(index, link_index, -1, to_end + link.length, needed, seconds):
				return false
			var feeder: TrafficLane = graph.lanes[link.from_lane]
			if not _clear_on(index, link.from_lane, link_index, to_end + link.length + feeder.length, needed, seconds):
				return false
	if bus_active and _bus_box.forward.dot(forward) < -0.5:
		var offset := _bus_box.centre - spot
		var along := offset.dot(forward)
		if along > -6.0 and along < needed + absf(bus_speed) * seconds + 15.0 and absf(offset.cross(forward)) < 6.0:
			return false
	return true


## No vehicle on this lane that could reach the pass in time. far is how far
## the lane's start is along the road from the passer. With via set, only
## vehicles going that way, or not yet decided, count.
func _clear_on(index: int, lane_index: int, via: int, far: float, needed: float, seconds: float) -> bool:
	var other_index := _lane_head[lane_index]
	while other_index >= 0:
		var other := agents[other_index]
		if other_index != index and (via < 0 or other.next_lane == via or other.next_lane == -1):
			if far - other.distance < needed + other.speed * seconds + 10.0:
				return false
		other_index = _lane_next[other_index]
	return true


## Nothing beside the vehicle in the strip it would slide across.
func _side_clear(index: int, agent: TrafficAgent, target: float) -> bool:
	var low := minf(agent.offset(), agent.base_offset() + target) - agent.half_width()
	var high := maxf(agent.offset(), agent.base_offset() + target) + agent.half_width()
	var other_index := _lane_head[agent.lane]
	while other_index >= 0:
		if other_index != index:
			var other: TrafficAgent = agents[other_index]
			if absf(other.distance - agent.distance) < agent.half_length() + _half_length[other_index] + 1.5:
				var middle := _offset[other_index]
				if middle + _half_width[other_index] > low and middle - _half_width[other_index] < high:
					return false
		other_index = _lane_next[other_index]
	return true


## Back into the usual line only once nothing is there from just behind the
## tail to as far ahead as a pass is planned, so a pass never cuts in on the
## bus and never ends just to start again. Something ahead that is driving away
## is fine: the vehicle drops in behind it.
func _can_return(index: int, agent: TrafficAgent) -> bool:
	if not _side_clear(index, agent, 0.0):
		return false
	var grow := agent.half_width() + TrafficSense.LOOK_MARGIN
	var start := maxf(agent.distance - agent.half_length() - 1.0, 0.0)
	var nose := agent.distance + agent.half_length() - start
	var reach := nose + maxf(RETURN_CLEAR, DECIDE_GAP + 2.0)
	if not _props.is_empty() and _props_in(agent.base_offset() - grow, agent.base_offset() + grow, start, start + reach):
		return false
	if _box_count == 0:
		return true
	_path_count = TrafficSense.trace(graph.lanes, _chain, start, agent.base_offset(), _side, reach, _path, _path_s)
	for k in _box_count:
		var box := _boxes[k]
		if box.kind == TrafficBox.Kind.VEHICLE:
			continue
		var at := TrafficSense.first_contact(_path, _path_s, _path_count, box, grow)
		if at == INF or (at > nose + 1.0 and _speed_along(box) > 1.0):
			continue
		return false
	return true


## Finds the props standing in the road and files each under the lanes it is
## near. Only props that have moved are checked again, and the lists are only
## rebuilt when something moved.
func _refresh_props() -> void:
	for k in _props.size():
		var prop := _props[k]
		# Lamp posts stand off the road, and a fallen one is driven over.
		if prop.tips_over:
			continue
		var at := Vector2(prop.position.x, prop.position.z)
		var box := _prop_boxes[k]
		box.velocity = Vector2(prop.velocity.x, prop.velocity.z)
		if at.distance_squared_to(_prop_seen[k]) < 0.0025 and _prop_state[k] == prop.state:
			continue
		_props_moved = true
		_prop_seen[k] = at
		_prop_state[k] = prop.state
		# A knocked-over cone lies flat and is driven over.
		var flat := prop.radius < 0.35 and prop.state != KnockableProp.State.STANDING
		_prop_on_road[k] = 1 if not flat and graph.network.edge_distance(at) < prop.radius else 0
		if prop.heavy:
			box.set_pose(at, Vector2(-sin(prop.rotation.y), -cos(prop.rotation.y)), TrafficAgent.CAR_HALF_LENGTH - 0.05, TrafficAgent.CAR_HALF_WIDTH)
		else:
			box.set_pose(at, Vector2(0.0, -1.0), prop.radius, prop.radius)
		box.index = k
	if not _props_moved:
		return
	_props_moved = false
	for lane in graph.lanes.size():
		if not _lane_props[lane].is_empty():
			_lane_props[lane] = PackedFloat32Array()
	for k in _props.size():
		if _prop_on_road[k] == 0:
			continue
		var at := _prop_seen[k]
		for lane in graph.lanes.size():
			if (graph.lanes[lane] as TrafficLane).bounds.has_point(at):
				_file_prop(lane, k)


## Measures a prop against one lane and files it there if it is close by.
func _file_prop(lane_index: int, k: int) -> void:
	var lane: TrafficLane = graph.lanes[lane_index]
	var box := _prop_boxes[k]
	var nearest := INF
	var along := 0.0
	var segment := 0
	for i in lane.points.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(box.centre, lane.points[i], lane.points[i + 1])
		var gap := closest.distance_squared_to(box.centre)
		if gap < nearest:
			nearest = gap
			along = lane.lengths[i] + lane.points[i].distance_to(closest)
			segment = i
	if nearest > 36.0:
		return
	var forward := (lane.points[segment + 1] - lane.points[segment]).normalized()
	var origin := lane.point_at(along)
	var length_span := TrafficSense.box_span(box, origin, forward)
	# Past either end of the lane, the next or last lane files it instead.
	if (along >= lane.length - 0.01 and length_span.x > 0.5) or (along <= 0.01 and length_span.y < -0.5):
		return
	var span := TrafficSense.box_span(box, origin, Vector2(-forward.y, forward.x) * float(_side))
	# Packed arrays are copied on write, so the list is stored back.
	var entries := _lane_props[lane_index]
	entries.append_array(PackedFloat32Array([along + length_span.x, along + length_span.y, span.x, span.y, float(k)]))
	_lane_props[lane_index] = entries
