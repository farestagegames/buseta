extends GutTest
## How cars and motorbikes react to the bus and to things in the road. Each case
## runs TrafficFlow on a small made-up map, once for each driving side.

const DT := 1.0 / 60.0
const SIDES: Array[int] = [1, -1]

var flow: TrafficFlow
var spec: BusSpec
# The scripted bus.
var rear := Vector2.ZERO
var heading := 0.0
var speed := 0.0
var fold := 0.0
var doors_open := false
var props: Array[KnockableProp] = []


func _straight(side: int, map_extra: Dictionary = {}) -> void:
	var data := {
		"nodes": [{"id": "w", "x": -400, "z": 0}, {"id": "e", "x": 400, "z": 0}],
		"roads": [{"id": "main", "from": "w", "to": "e"}],
	}
	data.merge(map_extra)
	_build(data, side)


func _crossroads(side: int) -> void:
	_build({
		"nodes": [{"id": "x", "x": 0, "z": 0}, {"id": "n", "x": 0, "z": -300}, {"id": "s", "x": 0, "z": 300},
			{"id": "e", "x": 300, "z": 0}, {"id": "w", "x": -300, "z": 0}],
		"roads": [{"id": "north", "from": "x", "to": "n"}, {"id": "south", "from": "x", "to": "s"},
			{"id": "east", "from": "x", "to": "e"}, {"id": "west", "from": "w", "to": "x"}],
	}, side)


func _roundabout(side: int) -> void:
	_build({
		"nodes": [{"id": "r", "x": 0, "z": 0, "kind": "roundabout", "radius": 21, "island": 9},
			{"id": "n", "x": 0, "z": -300}, {"id": "e", "x": 300, "z": 0}, {"id": "w", "x": -300, "z": 0}],
		"roads": [{"id": "north", "from": "r", "to": "n"}, {"id": "east", "from": "r", "to": "e"}, {"id": "west", "from": "w", "to": "r"}],
	}, side)


func _build(data: Dictionary, side: int) -> void:
	var network := RoadNetwork.from_data(data, side)
	flow = TrafficFlow.new(LaneGraph.build(network, data), spec if spec != null else BusSpec.new())
	spec = flow.spec
	props = []
	flow.watch_props(props)
	rear = Vector2(5000.0, 5000.0)
	heading = 0.0
	speed = 0.0
	fold = 0.0
	doors_open = false


func before_each() -> void:
	spec = null


func _lane(road: String, end_node: String) -> int:
	for i in flow.graph.lanes.size():
		var lane: TrafficLane = flow.graph.lanes[i]
		if not lane.is_link and lane.road == road and lane.end_node == end_node:
			return i
	return -1


func _add(lane: int, distance: float, start_speed: float, moto := false, cruise := 11.0) -> TrafficAgent:
	var agent := TrafficAgent.new(lane, distance, cruise)
	agent.speed = start_speed
	agent.is_moto = moto
	flow.add_agent(agent)
	return agent


func _kerb(lane: int, distance: float) -> Vector2:
	var forward := (flow.graph.lanes[lane] as TrafficLane).forward_at(distance)
	return Vector2(-forward.y, forward.x) * float(flow.graph.network.traffic_side)


## Puts the bus so its nose is at this lane distance, lateral metres towards the kerb.
func _bus_in_lane(lane: int, nose_at: float, lateral: float, bus_speed: float = 0.0) -> void:
	var road: TrafficLane = flow.graph.lanes[lane]
	var forward := road.forward_at(nose_at)
	heading = RoadNetwork.heading_of(forward)
	rear = road.point_at(nose_at) + _kerb(lane, nose_at) * lateral - forward * (spec.wheelbase + spec.front_overhang)
	speed = bus_speed


func _forward(angle: float) -> Vector2:
	return Vector2(-sin(angle), -cos(angle))


func _trailer() -> Array:
	var hitch := rear - _forward(heading) * spec.hitch_offset
	var trailer_heading := heading + fold
	return [hitch - _forward(trailer_heading) * spec.trailer_wheelbase, trailer_heading]


func _tick(mover: Callable = Callable()) -> void:
	if mover.is_valid():
		mover.call()
	var trailer := _trailer()
	flow.set_bus(rear, heading, speed, trailer[0], trailer[1], doors_open)
	flow.step(DT)


func _touches_bus(index: int) -> bool:
	var agent := flow.agents[index]
	var spot := flow.positions[index]
	var forward := flow.forwards[index]
	var trailer := _trailer()
	if agent.is_moto:
		return BusFootprint.touches(rear, heading, spec, spot, TrafficSystem.MOTO_RADIUS) \
			or (spec.is_articulated() and BusFootprint.touches_trailer(trailer[0], trailer[1], spec, spot, TrafficSystem.MOTO_RADIUS))
	if BusFootprint.touches_car(rear, heading, spec, spot, forward):
		return true
	if spec.is_articulated():
		for along: float in [-BusFootprint.CAR_CIRCLE_OFFSET, BusFootprint.CAR_CIRCLE_OFFSET]:
			if BusFootprint.touches_trailer(trailer[0], trailer[1], spec, spot + forward * along, BusFootprint.CAR_CIRCLE_RADIUS):
				return true
	return false


func _touches_prop(index: int) -> bool:
	var agent := flow.agents[index]
	var spot := flow.positions[index]
	var forward := flow.forwards[index]
	var box := TrafficBox.new()
	box.set_pose(spot, forward, agent.half_length(), agent.half_width())
	for prop in props:
		var at := Vector2(prop.position.x, prop.position.z)
		if TrafficSense.segment_entry(at, at, box, prop.radius - 0.05) >= 0.0:
			return true
	return false


func _touch_each_other(a: int, b: int) -> bool:
	var first := TrafficBox.new()
	first.set_pose(flow.positions[a], flow.forwards[a], flow.agents[a].half_length(), flow.agents[a].half_width())
	var second := flow.agents[b]
	for along: float in [-second.half_length(), 0.0, second.half_length()]:
		for across: float in [-second.half_width(), second.half_width()]:
			var forward := flow.forwards[b]
			var corner := flow.positions[b] + forward * along + Vector2(-forward.y, forward.x) * across
			if TrafficSense.segment_entry(corner, corner, first, -0.05) >= 0.0:
				return true
	return false


## How far an agent is ahead of the bus nose along its lane, negative behind.
func _ahead_of_nose(index: int) -> float:
	var nose := rear + _forward(heading) * (spec.wheelbase + spec.front_overhang)
	return (flow.positions[index] - nose).dot(_forward(heading))


## Hardest braking of each vehicle over this tick, in m/s^2, kept in worst.
## speeds holds last tick's speeds.
func _note_braking(speeds: PackedFloat32Array, worst: PackedFloat32Array) -> void:
	if speeds.size() != flow.agents.size():
		speeds.resize(flow.agents.size())
		worst.resize(flow.agents.size())
		for i in flow.agents.size():
			speeds[i] = flow.agents[i].speed
			worst[i] = 0.0
		return
	for i in flow.agents.size():
		worst[i] = maxf(worst[i], (speeds[i] - flow.agents[i].speed) / DT)
		speeds[i] = flow.agents[i].speed


func _cone(at: Vector2, kind := "cone", radius := 0.3) -> void:
	props.append(KnockableProp.new(kind, Vector3(at.x, 0.0, at.y), radius))
	flow.watch_props(props)


# --- Pure geometry ---

func test_a_segment_finds_where_it_enters_a_box() -> void:
	var box := TrafficBox.new()
	box.set_pose(Vector2(0.0, -10.0), Vector2(0.0, -1.0), 2.0, 1.0)
	assert_almost_eq(TrafficSense.segment_entry(Vector2.ZERO, Vector2(0.0, -20.0), box, 0.0), 0.4, 0.001)
	assert_eq(TrafficSense.segment_entry(Vector2(3.0, 0.0), Vector2(3.0, -20.0), box, 0.0), -1.0, "Beside the box")
	assert_gt(TrafficSense.segment_entry(Vector2(3.0, 0.0), Vector2(3.0, -20.0), box, 2.5), 0.0, "Grown enough to touch")


func test_a_traced_path_follows_the_lane_and_its_side_for_both_sides() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		var points := PackedVector2Array()
		var distances := PackedFloat32Array()
		points.resize(16)
		distances.resize(16)
		var chain := PackedInt32Array([lane, -1, -1])
		var count := TrafficSense.trace(flow.graph.lanes, chain, 20.0, 1.0, side, 30.0, points, distances)
		var road: TrafficLane = flow.graph.lanes[lane]
		assert_almost_eq(points[0].distance_to(road.point_at(20.0) + _kerb(lane, 20.0)), 0.0, 0.01)
		assert_almost_eq(distances[count - 1], 30.0, 0.01)
		assert_almost_eq(points[count - 1].distance_to(road.point_at(50.0) + _kerb(lane, 50.0)), 0.0, 0.05)


func test_a_box_span_across_a_lane() -> void:
	var box := TrafficBox.new()
	box.set_pose(Vector2(1.0, 0.0), Vector2(0.0, -1.0), 6.0, 1.25)
	var span := TrafficSense.box_span(box, Vector2.ZERO, Vector2(1.0, 0.0))
	assert_almost_eq(span.x, -0.25, 0.001)
	assert_almost_eq(span.y, 2.25, 0.001)


func test_a_car_must_wait_for_a_gap_to_pass_a_bus_at_the_kerb() -> void:
	# A bus 0.3 m kerbward of the lane line, 2.55 m wide.
	var plan := TrafficSense.pass_target(Vector2(-0.975, 1.575), 0.0, TrafficAgent.CAR_HALF_WIDTH, TrafficSense.CAR_PASS_MARGIN, LaneGraph.LANE_OFFSET)
	assert_lt(plan.x, -2.0, "Well over towards the centre")
	assert_eq(plan.y, 1.0, "Needs a gap in oncoming traffic")


func test_a_moto_squeezes_past_a_bus_without_needing_the_oncoming_lane() -> void:
	var plan := TrafficSense.pass_target(Vector2(-0.975, 1.575), TrafficAgent.MOTO_KERB_SHIFT, TrafficAgent.MOTO_HALF_WIDTH, TrafficSense.MOTO_PASS_MARGIN, LaneGraph.LANE_OFFSET)
	assert_lt(plan.x, -2.5)
	assert_eq(plan.y, 0.0)


func test_a_moto_takes_the_kerb_side_when_there_is_room() -> void:
	# A bin on the centre-line side of the lane.
	var plan := TrafficSense.pass_target(Vector2(-1.4, -0.6), TrafficAgent.MOTO_KERB_SHIFT, TrafficAgent.MOTO_HALF_WIDTH, TrafficSense.MOTO_PASS_MARGIN, LaneGraph.LANE_OFFSET)
	assert_gte(plan.x, 0.0)


func test_no_way_past_something_across_the_whole_road() -> void:
	var plan := TrafficSense.pass_target(Vector2(-5.6, 2.0), 0.0, TrafficAgent.CAR_HALF_WIDTH, TrafficSense.CAR_PASS_MARGIN, LaneGraph.LANE_OFFSET)
	assert_true(is_nan(plan.x))


func test_passing_into_the_oncoming_lane_needs_a_wait_a_gap_and_a_parked_blocker() -> void:
	assert_true(TrafficSense.may_pass(false, 0.0, 2.5, false, false), "Moving over within its own side is fine at once")
	assert_false(TrafficSense.may_pass(true, 1.0, 2.5, true, true), "Not before waiting")
	assert_false(TrafficSense.may_pass(true, 3.0, 2.5, false, true), "Not into oncoming traffic")
	assert_false(TrafficSense.may_pass(true, 3.0, 2.5, true, false), "Not round a bus that is only queueing")
	assert_true(TrafficSense.may_pass(true, 3.0, 2.5, true, true))


func test_the_bus_box_reaches_ahead_when_moving_and_behind_when_reversing() -> void:
	var city := BusSpec.new()
	var front := TrafficBox.new()
	var trailer := TrafficBox.new()
	TrafficSense.bus_boxes(Vector2.ZERO, 0.0, 0.0, city, Vector2.ZERO, 0.0, front, trailer)
	var still_length := front.half_length
	TrafficSense.bus_boxes(Vector2.ZERO, 0.0, 8.0, city, Vector2.ZERO, 0.0, front, trailer)
	assert_almost_eq(front.half_length, still_length + 8.0 * TrafficSense.BUS_SWEEP_SECONDS / 2.0, 0.01)
	assert_lt(front.centre.y, BusFootprint.body_centre(Vector2.ZERO, 0.0, city).y, "Stretched forward, which is -Z")
	TrafficSense.bus_boxes(Vector2.ZERO, 0.0, -1.5, city, Vector2.ZERO, 0.0, front, trailer)
	assert_gt(front.centre.y, BusFootprint.body_centre(Vector2.ZERO, 0.0, city).y, "Stretched backward")


func test_an_articulated_bus_has_a_trailer_box_where_its_rear_section_is() -> void:
	var long_bus: BusSpec = load("res://data/packs/colombia/buses/articulado.tres")
	var front := TrafficBox.new()
	var trailer := TrafficBox.new()
	var axle := Vector2(0.0, long_bus.hitch_offset + long_bus.trailer_wheelbase)
	assert_true(TrafficSense.bus_boxes(Vector2.ZERO, 0.0, 0.0, long_bus, axle, 0.0, front, trailer))
	var tail := axle + Vector2(0.0, long_bus.trailer_overhang - 0.1)
	assert_gte(TrafficSense.segment_entry(tail, tail, trailer, 0.0), 0.0)
	assert_true(BusFootprint.touches_trailer(axle, 0.0, long_bus, tail, 0.0))


func test_sideways_moves_are_gradual_and_quicker_when_moving() -> void:
	var car := TrafficAgent.new(0, 0.0, 11.0)
	car.shift_target = -2.0
	car.step_shift(DT)
	var crawling := -car.shift
	assert_gt(crawling, 0.0)
	assert_lt(crawling, 0.02, "No jump sideways")
	car.shift = 0.0
	car.speed = 6.0
	car.step_shift(DT)
	assert_gt(-car.shift, crawling)


# --- The bus in the lane ---

func test_a_car_waits_behind_a_bus_that_is_only_stopped_in_traffic() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		_bus_in_lane(lane, 300.0, 0.0)
		var car := _add(lane, 250.0, 10.0)
		var touched := false
		for i in 540:
			_tick()
			touched = touched or _touches_bus(0)
		assert_false(touched, "Side %d" % side)
		assert_lt(car.speed, 0.3, "Waiting, side %d" % side)
		assert_eq(car.shift, 0.0, "Stays in lane while the bus may move off, side %d" % side)
		assert_lt(_ahead_of_nose(0), -spec.overall_length(), "Behind the bus")
		# The bus drives off, and the car follows.
		var waited_at := car.distance
		rear = Vector2(5000.0, 5000.0)
		for i in 600:
			_tick()
		assert_gt(car.distance, waited_at + 20.0, "Moves on once the bus has gone, side %d" % side)


func test_a_car_passes_a_bus_at_a_stop_and_never_cuts_back_in_on_it() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		_bus_in_lane(lane, 300.0, RouteStop.HAIL_LATERAL - LaneGraph.LANE_OFFSET)
		doors_open = true
		var car := _add(lane, 220.0, 10.0)
		var touched := false
		var widest := 0.0
		var cut_in := false
		for i in 1500:
			_tick()
			touched = touched or _touches_bus(0)
			widest = minf(widest, car.shift)
			# Moving back towards its lane while still beside the bus is cutting in.
			if car.shift_rate > 0.0 and _ahead_of_nose(0) < car.half_length() + 1.5:
				cut_in = true
		assert_false(touched, "Side %d" % side)
		assert_lt(widest, -1.8, "Went round, side %d" % side)
		assert_false(cut_in, "Side %d" % side)
		assert_gt(_ahead_of_nose(0), 10.0, "Got past, side %d" % side)
		assert_almost_eq(car.shift, 0.0, 0.01, "Back in lane, side %d" % side)


func test_a_car_queues_behind_a_bus_at_a_stop_while_traffic_comes_the_other_way() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		var other_way := _lane("main", "w")
		_bus_in_lane(lane, 300.0, RouteStop.HAIL_LATERAL - LaneGraph.LANE_OFFSET)
		doors_open = true
		var car := _add(lane, 260.0, 8.0)
		var road: TrafficLane = flow.graph.lanes[other_way]
		for i in 13:
			_add(other_way, road.length - 700.0 + i * 40.0, 11.0)
		var touched := false
		for i in 600:
			_tick()
			touched = touched or _touches_bus(0)
		assert_false(touched)
		assert_eq(car.shift_target, 0.0, "No gap, so it queues, side %d" % side)
		assert_lt(car.speed, 0.3)


func test_a_moto_squeezes_past_a_stopped_bus_slowly() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		_bus_in_lane(lane, 300.0, RouteStop.HAIL_LATERAL - LaneGraph.LANE_OFFSET)
		doors_open = true
		var moto := _add(lane, 230.0, 10.0, true)
		var touched := false
		var fastest_beside := 0.0
		for i in 1200:
			_tick()
			touched = touched or _touches_bus(0)
			var beside := _ahead_of_nose(0)
			if beside < 0.0 and beside > -spec.overall_length():
				fastest_beside = maxf(fastest_beside, moto.speed)
		assert_false(touched, "Side %d" % side)
		assert_gt(_ahead_of_nose(0), 5.0, "Got past, side %d" % side)
		assert_lte(fastest_beside, TrafficFlow.MOTO_PASS_SPEED + 0.2, "Slowly beside the bus, side %d" % side)


func test_a_moto_beside_the_bus_lets_it_pull_away_from_the_stop() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		_bus_in_lane(lane, 300.0, RouteStop.HAIL_LATERAL - LaneGraph.LANE_OFFSET)
		doors_open = true
		var moto := _add(lane, 240.0, 10.0, true)
		var leaving := [false]
		var touched := false
		for i in 1200:
			_tick(func() -> void:
				var beside := _ahead_of_nose(0)
				if not leaving[0] and moto.shift < -2.0 and beside > -spec.overall_length() and beside < -spec.overall_length() / 2.0:
					leaving[0] = true
					doors_open = false
				if leaving[0]:
					# Pulls out, nose towards the centre of the road, as a driver who did not look.
					speed = minf(speed + 1.2 * DT, 4.0)
					heading = RoadNetwork.heading_of((flow.graph.lanes[lane] as TrafficLane).forward_at(250.0).rotated(-0.12 * float(side)))
					rear += _forward(heading) * speed * DT)
			touched = touched or _touches_bus(0)
		assert_true(leaving[0], "The moto came alongside, side %d" % side)
		assert_false(touched, "Side %d" % side)


func test_traffic_slows_behind_a_bus_pulling_out_from_the_kerb() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		_bus_in_lane(lane, 250.0, 1.4)
		heading += 0.22 * float(side) # Nose towards the centre of the road.
		speed = 2.0
		var car := _add(lane, 200.0, 11.0)
		var touched := false
		for i in 600:
			_tick(func() -> void: rear += _forward(heading) * speed * DT)
			touched = touched or _touches_bus(0)
		assert_false(touched, "Side %d" % side)
		assert_lt(car.speed, 4.0, "Held back to the bus's pace, side %d" % side)


func test_a_car_stops_for_a_bus_turning_across_its_lane() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		var road: TrafficLane = flow.graph.lanes[lane]
		var into_road := -_kerb(lane, 250.0)
		heading = RoadNetwork.heading_of(into_road.rotated(0.4 * float(side)))
		# The nose is 1.5 m into the lane.
		rear = road.point_at(250.0) - into_road * (spec.wheelbase + spec.front_overhang - 1.5)
		var car := _add(lane, 180.0, 11.0)
		var touched := false
		for i in 900:
			_tick()
			touched = touched or _touches_bus(0)
		assert_false(touched, "Side %d" % side)
		assert_lt(car.speed, 0.3)


func test_a_car_stops_for_the_trailer_of_an_articulated_bus_across_its_lane() -> void:
	spec = load("res://data/packs/colombia/buses/articulado.tres")
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		var road: TrafficLane = flow.graph.lanes[lane]
		var across := -_kerb(lane, 250.0)
		heading = RoadNetwork.heading_of(across)
		# The front body is already out of the lane: only the trailer is in it.
		rear = road.point_at(250.0) + across * 4.5
		speed = 0.6
		var car := _add(lane, 190.0, 11.0)
		var touched := false
		for i in 600:
			_tick(func() -> void: rear += _forward(heading) * speed * DT)
			touched = touched or _touches_bus(0)
		assert_false(touched, "Side %d" % side)


func test_a_car_stops_for_a_trailer_swinging_into_its_lane() -> void:
	spec = load("res://data/packs/colombia/buses/articulado.tres")
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		# Front in the other lane, rear section folded out across this one.
		_bus_in_lane(lane, 260.0, -3.6)
		var touched_somewhere := false
		for swing: float in [0.55, -0.55]:
			fold = swing
			var trailer := _trailer()
			var box := TrafficBox.new()
			TrafficSense.bus_boxes(rear, heading, 0.0, spec, trailer[0], trailer[1], TrafficBox.new(), box)
			var road: TrafficLane = flow.graph.lanes[lane]
			if TrafficSense.segment_entry(road.point_at(200.0), road.point_at(259.0), box, 1.0) >= 0.0:
				touched_somewhere = true
				break
		assert_true(touched_somewhere, "The trailer reaches into the lane")
		var car := _add(lane, 190.0, 11.0)
		var touched := false
		for i in 600:
			_tick()
			touched = touched or _touches_bus(0)
		assert_false(touched, "Side %d" % side)
		assert_lt(car.speed, 0.3)


func test_a_car_keeps_well_back_from_a_reversing_bus() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		_bus_in_lane(lane, 260.0, 0.0)
		speed = -1.5
		var car := _add(lane, 200.0, 10.0)
		var touched := false
		for i in 300:
			_tick(func() -> void: rear += _forward(heading) * speed * DT)
			touched = touched or _touches_bus(0)
		assert_false(touched, "Side %d" % side)
		var tail_gap := -_ahead_of_nose(0) - spec.overall_length() - car.half_length()
		assert_gt(tail_gap, TrafficSense.REVERSE_STANDOFF, "Stopped well short, side %d" % side)


func test_a_car_brakes_when_the_bus_cuts_in_ahead_after_overtaking() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		var road: TrafficLane = flow.graph.lanes[lane]
		var car := _add(lane, 100.0, 8.0, false, 8.0)
		var start := 100.0 + car.half_length() + 4.0 + spec.rear_overhang
		var clock := [0.0]
		var touched := false
		var slowest := 8.0
		for i in 360:
			_tick(func() -> void:
				clock[0] += DT
				var t: float = clock[0]
				var lateral := -3.8 * (1.0 - clampf(t / 2.0, 0.0, 1.0))
				var along := start + 8.5 * t
				heading = RoadNetwork.heading_of(road.forward_at(along))
				rear = road.point_at(along) + _kerb(lane, along) * lateral
				speed = 8.5)
			touched = touched or _touches_bus(0)
			slowest = minf(slowest, car.speed)
		assert_false(touched, "Side %d" % side)
		assert_lt(slowest, 7.5, "Eased off, side %d" % side)


func test_an_oncoming_car_stops_for_the_bus_overtaking_in_its_lane() -> void:
	for side in SIDES:
		_straight(side)
		var own := _lane("main", "e")
		var other_way := _lane("main", "w")
		_bus_in_lane(own, 200.0, -2.0 * LaneGraph.LANE_OFFSET, 0.0)
		var road: TrafficLane = flow.graph.lanes[other_way]
		var car := _add(other_way, road.length - 260.0, 11.0)
		var touched := false
		for i in 900:
			_tick()
			touched = touched or _touches_bus(0)
		assert_false(touched, "Side %d" % side)
		assert_lt(car.speed, 0.3, "Stopped short of the bus in its lane, side %d" % side)


func test_a_car_kept_waiting_gives_one_short_toot() -> void:
	_straight(1)
	var lane := _lane("main", "e")
	var other_way := _lane("main", "w")
	_bus_in_lane(lane, 300.0, 0.0)
	_add(lane, 283.0, 0.0)
	var road: TrafficLane = flow.graph.lanes[other_way]
	for i in 16:
		_add(other_way, road.length - 900.0 + i * 40.0, 11.0)
	watch_signals(flow)
	for i in int((TrafficFlow.HORN_AFTER + 5.0) / DT):
		_tick()
	assert_signal_emit_count(flow, "horn_sounded", 1)


# --- Junctions ---

func test_cars_wait_at_the_line_while_the_bus_blocks_the_junction() -> void:
	for side in SIDES:
		_crossroads(side)
		var centre: Vector2 = flow.graph.network.nodes["x"]["position"]
		heading = RoadNetwork.heading_of(Vector2(0.6, -0.8).normalized())
		rear = centre - _forward(heading) * 4.0
		var watched: Array[int] = []
		for lane_index: int in flow.graph.into_node["x"]:
			var lane: TrafficLane = flow.graph.lanes[lane_index]
			_add(lane_index, lane.length - 40.0, 10.0)
			watched.append(flow.agents.size() - 1)
		for i in 900:
			flow.time = 1.0 # Hold the lights.
			_tick()
			for index in watched:
				assert_false(_touches_bus(index), "Side %d" % side)
		var lanes_at_wait: Array[int] = []
		for index in watched:
			var agent := flow.agents[index]
			assert_false((flow.graph.lanes[agent.lane] as TrafficLane).is_link, "Did not enter, side %d" % side)
			lanes_at_wait.append(agent.lane)
		# The bus leaves and the lights run again: every car gets through in time.
		rear = Vector2(5000.0, 5000.0)
		for i in int(TrafficLightPlan.CYCLE / DT):
			_tick()
		for k in watched.size():
			assert_ne(flow.agents[watched[k]].lane, lanes_at_wait[k], "Moved on after the bus left, side %d" % side)


func test_a_car_lets_the_bus_go_round_the_roundabout_first() -> void:
	for side in SIDES:
		_roundabout(side)
		var entry_lane := _lane("west", "r")
		var lane: TrafficLane = flow.graph.lanes[entry_lane]
		var centre: Vector2 = flow.graph.network.nodes["r"]["position"]
		var entry := lane.points[lane.points.size() - 1]
		var radial := (entry - centre).normalized()
		# Ring traffic goes anticlockwise on the map when it keeps right.
		var along_ring := Vector2(radial.y, -radial.x) * float(side)
		var on_ring := centre + radial.rotated(0.9 * float(side)) * 15.0
		heading = RoadNetwork.heading_of(along_ring.rotated(0.9 * float(side)))
		rear = on_ring
		speed = 3.0
		var car := _add(entry_lane, lane.length - 35.0, 10.0)
		var angle := [0.9 * float(side)]
		var touched := false
		var entered_at := INF
		for i in 600:
			_tick(func() -> void:
				angle[0] -= float(side) * speed / 15.0 * DT
				var radial_now := radial.rotated(angle[0])
				rear = centre + radial_now * 15.0
				heading = RoadNetwork.heading_of(Vector2(radial_now.y, -radial_now.x) * float(side)))
			touched = touched or _touches_bus(0)
			if entered_at == INF and (flow.graph.lanes[car.lane] as TrafficLane).is_link:
				entered_at = angle[0] * float(side)
		assert_false(touched, "Side %d" % side)
		assert_lt(entered_at, -0.3, "Entered only once the bus had gone by, side %d" % side)


# --- Things in the road ---

func test_traffic_passes_a_cone_line_without_touching_it() -> void:
	for side in SIDES:
		_straight(side, {"cone_lines": [{"road": "main", "from": 300, "to": 350, "lateral": 1.7, "dir": 1, "spacing": 5}]})
		var along := 300.0
		while along <= 350.0:
			_cone(flow.graph.network.sample("main", along, 1.7, 1)["position"])
			along += 5.0
		_cone(flow.graph.network.sample("main", 325.0, 2.9, 1)["position"], "barrier", 0.75)
		var lane := _lane("main", "e")
		var car := _add(lane, 600.0, 11.0)
		var moto := _add(lane, 610.0, 11.0, true)
		car.distance = 250.0
		moto.distance = 260.0
		var touched := [false, false]
		for i in 900:
			_tick()
			touched[0] = touched[0] or _touches_prop(0)
			touched[1] = touched[1] or _touches_prop(1)
		assert_false(touched[0], "Car, side %d" % side)
		assert_false(touched[1], "Moto, side %d" % side)
		var last: Dictionary = flow.graph.network.sample("main", 350.0, 1.7, 1)
		assert_gt((flow.positions[0] - last["position"]).dot(last["forward"]), 5.0, "Car got through, side %d" % side)
		assert_gt((flow.positions[1] - last["position"]).dot(last["forward"]), 5.0, "Moto got through, side %d" % side)


func test_a_moto_threads_past_parked_cars_without_touching_them() -> void:
	for side in SIDES:
		_straight(side, {"parked_cars": [{"road": "main", "along": 300, "dir": 1}, {"road": "main", "along": 307, "dir": 1}]})
		for along: float in [300.0, 307.0]:
			var placed: Dictionary = flow.graph.network.sample("main", along, RoadNetwork.ROAD_HALF_WIDTH - 1.0, 1)
			var car_prop := KnockableProp.new("car", Vector3(placed["position"].x, 0.0, placed["position"].y), 1.25, placed["heading"])
			car_prop.heavy = true
			props.append(car_prop)
		flow.watch_props(props)
		var lane := _lane("main", "e")
		var moto := _add(lane, 250.0, 11.0, true)
		var touched := false
		var slowest := INF
		for i in 600:
			_tick()
			slowest = minf(slowest, moto.speed)
			var spot := flow.positions[0]
			for prop in props:
				var forward := Vector2(-sin(prop.rotation.y), -cos(prop.rotation.y))
				var box := TrafficBox.new()
				box.set_pose(Vector2(prop.position.x, prop.position.z), forward, 2.15, 0.9)
				touched = touched or TrafficSense.segment_entry(spot, spot, box, TrafficAgent.MOTO_HALF_WIDTH - 0.05) >= 0.0
		assert_false(touched, "Side %d" % side)
		var last: Dictionary = flow.graph.network.sample("main", 307.0, 0.0, 1)
		assert_gt((flow.positions[0] - last["position"]).dot(last["forward"]), 5.0, "Got past, side %d" % side)
		assert_gt(slowest, 3.0, "Eased round without stopping, side %d" % side)


func test_a_car_goes_round_a_bin_knocked_into_its_lane() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		var road: TrafficLane = flow.graph.lanes[lane]
		_cone(road.point_at(300.0), "bin", 0.42)
		props[0].state = KnockableProp.State.SETTLED
		var car := _add(lane, 240.0, 10.0)
		var touched := false
		var widest := 0.0
		for i in 1200:
			_tick()
			touched = touched or _touches_prop(0)
			widest = maxf(widest, absf(car.shift))
		assert_false(touched, "Side %d" % side)
		assert_gt(widest, 1.0, "Went round, side %d" % side)
		assert_gt(car.distance, 310.0, "Got past, side %d" % side)


func test_a_car_goes_round_a_bin_on_the_side_away_from_a_parked_car() -> void:
	for side in SIDES:
		_straight(side, {"parked_cars": [{"road": "main", "along": 320, "dir": 1}]})
		var placed: Dictionary = flow.graph.network.sample("main", 320.0, RoadNetwork.ROAD_HALF_WIDTH - 1.0, 1)
		var parked := KnockableProp.new("car", Vector3(placed["position"].x, 0.0, placed["position"].y), 1.25, placed["heading"])
		parked.heavy = true
		props.append(parked)
		var lane := _lane("main", "e")
		var bin_spot: Vector2 = flow.graph.network.sample("main", 320.0, 0.6, 1)["position"]
		_cone(bin_spot, "bin", 0.42)
		props[1].state = KnockableProp.State.SETTLED
		flow.watch_props(props)
		var car := _add(lane, 250.0, 10.0)
		var touched := false
		for i in 1200:
			_tick()
			touched = touched or _touches_prop(0)
		assert_false(touched, "Side %d" % side)
		assert_gt((flow.positions[0] - bin_spot).dot(placed["forward"]), 5.0, "Got past, side %d" % side)
		assert_eq(car.shift, 0.0, "Back in lane, side %d" % side)


func test_lanes_know_the_lane_beside_them_and_how_far_they_moved_over() -> void:
	_straight(1, {"parked_cars": [{"road": "main", "along": 300, "dir": 1}]})
	var lane: TrafficLane = flow.graph.lanes[_lane("main", "e")]
	assert_eq(lane.opposite, _lane("main", "w"))
	assert_almost_eq(lane.lateral_at(10.0), LaneGraph.LANE_OFFSET, 0.01)
	assert_almost_eq(lane.min_lateral, LaneGraph.PASSING_OFFSET, 0.01, "Moved over beside the parked car")


func test_a_flattened_cone_is_driven_over() -> void:
	_straight(1)
	var lane := _lane("main", "e")
	_cone((flow.graph.lanes[lane] as TrafficLane).point_at(300.0))
	props[0].state = KnockableProp.State.SETTLED
	var car := _add(lane, 260.0, 10.0)
	for i in 300:
		_tick()
	assert_gt(car.distance, 300.0)
	assert_eq(car.shift, 0.0)


# --- Motorbikes and cars ---

func test_a_moto_filters_past_a_stopped_car_but_not_quickly() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		var car := _add(lane, 300.0, 0.0, false, 0.01)
		var moto := _add(lane, 250.0, 12.0, true)
		var touched := false
		var fastest_beside := 0.0
		for i in 900:
			_tick()
			touched = touched or _touch_each_other(1, 0)
			if absf(moto.distance - car.distance) < 3.5:
				fastest_beside = maxf(fastest_beside, moto.speed)
		assert_false(touched, "Side %d" % side)
		assert_gt(moto.distance, car.distance + 5.0, "Got past, side %d" % side)
		assert_lte(fastest_beside, TrafficFlow.FILTER_SPEED + 0.3, "Side %d" % side)


func test_a_moto_does_not_ride_through_a_car_in_its_line() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		var car := _add(lane, 300.0, 3.0, false, 3.0)
		_add(lane, 250.0, 12.0, true)
		var touched := false
		for i in 900:
			_tick(func() -> void:
				# Held over at the kerb, in the moto's line.
				car.shift = TrafficAgent.MOTO_KERB_SHIFT
				car.shift_target = car.shift)
			touched = touched or _touch_each_other(1, 0)
		assert_false(touched, "Side %d" % side)


# --- Braking ---

func test_speed_limits_ahead_are_met_with_gentle_braking() -> void:
	for side in SIDES:
		# A moto filtering past a stopped car.
		_straight(side)
		var lane := _lane("main", "e")
		_add(lane, 300.0, 0.0, false, 0.01)
		_add(lane, 230.0, 13.0, true, 14.0)
		var speeds := PackedFloat32Array()
		var worst := PackedFloat32Array()
		for i in 900:
			_tick()
			_note_braking(speeds, worst)
		assert_lte(worst[1], TrafficAgent.COMFORT_BRAKE + 0.05, "Filtering moto, side %d" % side)
		# A moto squeezing past a bus at a stop: slowing for the bus itself may
		# be firmer, but never past the hardest braking.
		_straight(side)
		_bus_in_lane(lane, 300.0, RouteStop.HAIL_LATERAL - LaneGraph.LANE_OFFSET)
		doors_open = true
		_add(lane, 220.0, 12.0, true, 14.0)
		speeds = PackedFloat32Array()
		worst = PackedFloat32Array()
		for i in 900:
			_tick()
			_note_braking(speeds, worst)
		assert_lte(worst[0], TrafficAgent.MAX_BRAKE + 0.01, "Moto past the bus, side %d" % side)
		# A car going round a bin knocked into its lane.
		_straight(side)
		_cone((flow.graph.lanes[lane] as TrafficLane).point_at(300.0), "bin", 0.42)
		props[0].state = KnockableProp.State.SETTLED
		_add(lane, 200.0, 12.0, false, 12.0)
		speeds = PackedFloat32Array()
		worst = PackedFloat32Array()
		for i in 900:
			_tick()
			_note_braking(speeds, worst)
		assert_lte(worst[0], TrafficAgent.MAX_BRAKE + 0.01, "Car round a bin, side %d" % side)


func test_being_over_the_free_speed_only_eases_off_gently() -> void:
	assert_almost_eq(TrafficAgent.acceleration(12.0, 4.0, INF, 0.0), -TrafficAgent.COMFORT_BRAKE, 0.001)
	var car := TrafficAgent.new(0, 0.0, 12.0)
	car.speed = 12.0
	car.drive(0.0, INF, 0.0, DT)
	assert_almost_eq(car.speed, 12.0 - TrafficAgent.COMFORT_BRAKE * DT, 0.001, "Told to stop, it brakes, it does not halt")


func test_a_car_slows_for_a_turn_before_it_reaches_it() -> void:
	for side in SIDES:
		_crossroads(side)
		var lane_index := _lane("west", "x")
		var lane: TrafficLane = flow.graph.lanes[lane_index]
		var turn := -1
		for link_index: int in lane.next:
			if (flow.graph.lanes[link_index] as TrafficLane).turn == side:
				turn = link_index
		assert_gt(turn, -1, "A turn towards the kerb side")
		var car := _add(lane_index, lane.length - 70.0, 11.0)
		car.next_lane = turn
		var speeds := PackedFloat32Array()
		var worst := PackedFloat32Array()
		var turning_at := -1.0
		for i in 600:
			flow.time = 1.0 # Green for this approach.
			_tick()
			_note_braking(speeds, worst)
			if turning_at < 0.0 and car.lane == turn:
				turning_at = car.speed
		assert_gt(turning_at, 0.0, "Made the turn, side %d" % side)
		var turn_speed := (flow.graph.lanes[turn] as TrafficLane).speed_limit(car.cruise)
		assert_lte(turning_at, turn_speed + 0.3, "Already slow at the turn, side %d" % side)
		assert_lte(worst[0], TrafficAgent.COMFORT_BRAKE + 0.05, "Gently, side %d" % side)


# --- Meeting oncoming traffic ---

func test_a_car_does_not_pass_into_traffic_coming_out_of_the_junction_ahead() -> void:
	for side in SIDES:
		_build({
			"nodes": [{"id": "w", "x": -300, "z": 0}, {"id": "e", "x": 0, "z": 0}, {"id": "f", "x": 300, "z": 0}],
			"roads": [{"id": "main", "from": "w", "to": "e"}, {"id": "beyond", "from": "e", "to": "f"}],
		}, side)
		var lane := _lane("main", "e")
		var road: TrafficLane = flow.graph.lanes[lane]
		_bus_in_lane(lane, road.length - 30.0, RouteStop.HAIL_LATERAL - LaneGraph.LANE_OFFSET)
		doors_open = true
		var car := _add(lane, road.length - 60.0, 0.0)
		var inbound := _lane("beyond", "e")
		var far: TrafficLane = flow.graph.lanes[inbound]
		for k in 5:
			_add(inbound, far.length - 10.0 - k * 50.0, 11.0)
		var face_off := false
		var touched := false
		var got_past := false
		for i in 3600:
			_tick()
			touched = touched or _touches_bus(0)
			got_past = got_past or (car.lane == lane and _ahead_of_nose(0) > 5.0)
			if car.speed < 0.2 and car.shift < -1.0:
				for k in range(1, flow.agents.size()):
					if flow.positions[k].distance_to(flow.positions[0]) < 15.0:
						face_off = true
			for k in range(1, flow.agents.size()):
				touched = touched or _touch_each_other(0, k)
		assert_false(face_off, "Never stuck nose to nose, side %d" % side)
		assert_false(touched, "Side %d" % side)
		assert_true(got_past, "Got past once the road was clear, side %d" % side)


func test_lanes_narrowed_on_both_sides_at_once_are_found() -> void:
	var data := {"parked_cars": [{"road": "main", "dir": 1, "along": 400.0}, {"road": "main", "dir": -1, "along": 405.0}],
		"cone_lines": [{"road": "main", "dir": 1, "from": 100.0, "to": 140.0}, {"road": "main", "dir": -1, "from": 140.0 + LaneGraph.BLOCK_SPACING + 0.5, "to": 220.0}]}
	var clashes := LaneGraph.clashing_blocks(data)
	assert_eq(clashes.size(), 1, str(clashes))


func test_no_shipped_map_narrows_both_lanes_at_once() -> void:
	# Two cars meeting where both lanes have moved in would overlap, so maps
	# keep parked cars and cones on opposite sides apart.
	var checked := 0
	for pack in DirAccess.get_directories_at("res://data/packs"):
		var folder := "res://data/packs/%s/maps" % pack
		for file in DirAccess.get_files_at(folder):
			if not file.ends_with(".json"):
				continue
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "/" + file))
			var clashes := LaneGraph.clashing_blocks(data)
			assert_eq(clashes.size(), 0, "%s: %s" % [file, clashes])
			checked += 1
	assert_gt(checked, 0)


# --- After a hit ---

func test_a_shoved_car_never_ends_up_far_off_its_line() -> void:
	var agent := TrafficAgent.new(0, 10.0, 11.0)
	agent.hit_by_bus(Vector2(40.0, 0.0))
	for i in 600:
		agent.drive(11.0, INF, 0.0, DT)
		assert_lte(agent.nudge.length(), TrafficAgent.MAX_NUDGE + 0.001)
	for i in 30:
		agent.stop_against_bus(Vector2(0.5, 0.0))
	assert_lte(agent.nudge.length(), TrafficAgent.MAX_NUDGE + 0.001, "Pushing against the bus is capped too")


func test_a_shoved_car_steers_back_onto_its_line_and_drives_on() -> void:
	var agent := TrafficAgent.new(0, 10.0, 11.0)
	agent.speed = 8.0
	agent.hit_by_bus(Vector2(6.0, 0.0))
	var top_while_off := 0.0
	for i in int(20.0 / DT):
		agent.drive(11.0, INF, 0.0, DT)
		if agent.is_recovering() and agent.stunned <= 0.0:
			top_while_off = maxf(top_while_off, agent.speed)
	assert_almost_eq(agent.nudge.length(), 0.0, 0.01, "Back on its line")
	assert_gt(agent.speed, 8.0, "Driving normally again")
	assert_lte(top_while_off, TrafficAgent.RECOVERING_SPEED + 0.01, "Eases back in slowly")


# --- Horns ---

func test_kept_waiting_long_gives_a_longer_blast() -> void:
	_straight(1)
	var lane := _lane("main", "e")
	var other_way := _lane("main", "w")
	_bus_in_lane(lane, 300.0, 0.0)
	_add(lane, 283.0, 0.0)
	var road: TrafficLane = flow.graph.lanes[other_way]
	# A car stopped opposite the bus, so there is never room to pass.
	_add(other_way, road.length - 300.0, 0.0, false, 0.0)
	var kinds: Array[int] = []
	flow.horn_sounded.connect(func(_spot: Vector2, kind: int) -> void: kinds.append(kind))
	for i in int((TrafficFlow.HORN_AFTER + 2.0) * TrafficFlow.SECOND_HORN_SHARE / DT):
		_tick()
	assert_eq(kinds, [TrafficFlow.Honk.TOOT, TrafficFlow.Honk.LONG] as Array[int])


func test_motorbikes_beep_sooner_than_cars() -> void:
	_straight(1)
	var lane := _lane("main", "e")
	var other_way := _lane("main", "w")
	_bus_in_lane(lane, 300.0, 0.0)
	var road: TrafficLane = flow.graph.lanes[other_way]
	for i in 30:
		_add(other_way, road.length - 1400.0 + i * 40.0, 11.0)
	var moto := _add(lane, 286.0, 0.0, true)
	moto.kerb_shift = 0.0
	var kinds: Array[int] = []
	flow.horn_sounded.connect(func(_spot: Vector2, kind: int) -> void: kinds.append(kind))
	for i in int((TrafficFlow.HORN_AFTER * TrafficFlow.MOTO_HORN_SHARE + 2.5) / DT):
		_tick()
	assert_true(kinds.has(TrafficFlow.Honk.BEEP), "A moto stuck behind the bus beeps before a car would toot")


func test_a_hit_driver_leans_on_the_horn() -> void:
	_straight(1)
	_add(_lane("main", "e"), 100.0, 5.0)
	_tick()
	var kinds: Array[int] = []
	flow.horn_sounded.connect(func(_spot: Vector2, kind: int) -> void: kinds.append(kind))
	flow.honk_after_hit(0)
	flow.honk_after_hit(0)
	assert_eq(kinds.size(), 2, "A new hit always gets a honk")
	assert_eq(kinds[0], TrafficFlow.Honk.LONG)


func test_honks_fade_with_distance_and_stop_out_of_earshot() -> void:
	assert_eq(AudioDirector.car_horn_db(5.0), AudioDirector.CAR_HORN_DB)
	assert_almost_eq(AudioDirector.car_horn_db(20.0), AudioDirector.CAR_HORN_DB - 6.0, 0.01)
	assert_eq(AudioDirector.car_horn_db(AudioDirector.CAR_HORN_RANGE + 1.0), -INF)


## Hailed from the lane, the bus stops away from the kerb and people walk across
## the gap. A moto riding up the kerb side used to ride straight through them.
func test_a_moto_waits_for_people_boarding_between_the_bus_and_the_kerb() -> void:
	for side in SIDES:
		_straight(side)
		var lane := _lane("main", "e")
		_bus_in_lane(lane, 300.0, -0.6)
		doors_open = true
		var moto := _add(lane, 240.0, 10.0, true)
		var kerb := _kerb(lane, 290.0)
		var centre := rear + _forward(heading) * -spec.body_centre_z()
		var entered := false
		for i in 900:
			_tick()
			var offset := flow.positions[0] - centre
			var along := absf(offset.dot(_forward(heading)))
			var across := offset.dot(kerb)
			if along < spec.overall_length() / 2.0 and across > spec.body_width / 2.0 and across < spec.body_width / 2.0 + 3.0:
				entered = true
		assert_false(entered, "Kept out of the boarding strip, side %d" % side)
		assert_false(_touches_bus(0), "Side %d" % side)
		doors_open = false
		for i in 900:
			_tick()
		assert_gt(moto.distance, 245.0, "Rides on once the doors shut, side %d" % side)
