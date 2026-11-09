class_name RouteRunner
extends RefCounted
## Tracks progress along a route: which stop is next, how far away it is and
## which turn is coming. Pure logic. Routes are data files.

const SEARCH_AHEAD := 30
const TURN_WARNING_DISTANCE := 90.0
const TURN_ANGLE := deg_to_rad(35.0)
const TURN_BACK_ANGLE := deg_to_rad(150.0)
const WRONG_WAY_PENALTY := 60.0
const HAZARD_WARNING_DISTANCE := 55.0
const HAZARD_ON_ROUTE_RADIUS := 7.0

var route_name: String = ""
var stops: Array[RouteStop] = []
var polyline: PackedVector2Array = PackedVector2Array()
var distances: PackedFloat32Array = PackedFloat32Array()
var turns: Array[Dictionary] = [] ## distance: float, text: String
var hazards: PackedFloat32Array = PackedFloat32Array() ## Route distance of each bump.
var traffic_side: int = 1
var kind: RouteStop.Kind = RouteStop.Kind.BAY
var start_position: Vector2 = Vector2.ZERO
var start_heading: float = 0.0
var stop_index: int = 0
var progress: float = 0.0

var _cursor: int = 0
## The endless route keeps growing: see extend().
var endless: bool = false
## The leg the route currently ends on, for planning more.
var last_leg: Dictionary = {}
## The last leg's end, whose turn is only known once the route goes on.
var _open_end: int = -1
var _open_end_kind: String = ""
var _hazard_points := PackedVector2Array()
## The endless timetable: seconds per metre between stops, and per stop.
const ENDLESS_PACE := 6.5
const ENDLESS_DWELL := 20.0
const ENDLESS_FIRST_LEGS := 8


static func build(data: Dictionary, network: RoadNetwork, shift_seed: int = 0, map_data: Dictionary = {}) -> RouteRunner:
	var runner := RouteRunner.new()
	runner.route_name = data["name"]
	runner.traffic_side = network.traffic_side
	var service: String = data.get("service", "bays")
	runner.endless = service == "endless" or service == "arcade"
	var legs: Array = data["legs"].duplicate()
	if runner.endless:
		var random := RandomNumberGenerator.new()
		random.seed = shift_seed
		var last: Dictionary = legs[legs.size() - 1]
		legs.append_array(EndlessPlanner.walk(network, last["road"], int(last["dir"]), ENDLESS_FIRST_LEGS, random))
	runner._build_polyline(legs, network)
	var start: Dictionary = data["start"]
	var placed: Dictionary = network.sample(start["road"], start["along"], start["lateral"], start["dir"])
	runner.start_position = placed["position"]
	runner.start_heading = placed["heading"]
	runner._cursor = runner._nearest_from_start(runner.start_position)
	runner._apply_progress(runner.start_position)
	runner.kind = {"informal": RouteStop.Kind.HAIL, "rapid": RouteStop.Kind.STATION, "endless": RouteStop.Kind.HAIL}.get(service, RouteStop.Kind.BAY)
	var entries: Array
	if service == "arcade":
		entries = []
	elif runner.endless:
		entries = EndlessPlanner.hails(legs, data["hail"], network, shift_seed, map_data)
	else:
		entries = HailPlan.fill(data, network, shift_seed, map_data) if service == "informal" else data["stops"]
	for entry: Dictionary in entries:
		runner._add_stop(entry, network)
	if service == "informal":
		runner._share_out_the_timetable()
	if runner.endless and not runner.stops.is_empty():
		runner._pace_timetable(0)
	return runner


## Adds more road and stops to the end of an endless route.
func extend(legs: Array, network: RoadNetwork, entries: Array) -> void:
	var first_new_point := polyline.size() - 1
	var first_new_stop := stops.size()
	_build_polyline(legs, network)
	for point in _hazard_points:
		_add_hazard_from(point, first_new_point)
	for entry: Dictionary in entries:
		_add_stop(entry, network)
	_pace_timetable(first_new_stop)


## Due times on the endless route: a steady pace plus time at each stop.
func _pace_timetable(from_index: int) -> void:
	for i in range(from_index, stops.size()):
		var previous_due := stops[i - 1].due if i > 0 else 0.0
		var previous_distance := stops[i - 1].route_distance if i > 0 else 0.0
		stops[i].due = previous_due + (stops[i].route_distance - previous_distance) / ENDLESS_PACE + ENDLESS_DWELL


## Where along the route a distance falls, and which way it runs there.
func point_at(distance: float) -> Dictionary:
	var i := clampi(distances.bsearch(distance) - 1, 0, polyline.size() - 2)
	var span := maxf(distances[i + 1] - distances[i], 0.001)
	var forward := (polyline[i + 1] - polyline[i]).normalized()
	return {"position": polyline[i].lerp(polyline[i + 1], clampf((distance - distances[i]) / span, 0.0, 1.0)), "forward": forward}


func length() -> float:
	return distances[distances.size() - 1]


## How far a point is from the route's line near the bus, for the arcade pads.
func distance_from_line(point: Vector2) -> float:
	var i := clampi(_cursor, 0, polyline.size() - 2)
	return Geometry2D.get_closest_point_to_segment(point, polyline[i], polyline[mini(i + 1, polyline.size() - 1)]).distance_to(point)


## The route from here to this far ahead, for the map on the endless route.
func line_ahead(metres: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(maxi(_cursor, 0), polyline.size()):
		if distances[i] > progress + metres:
			break
		out.append(polyline[i])
	return out


## Only the end of an informal route is timed. Each hail gets its share of that, so
## the driver can always see how the shift is going.
func _share_out_the_timetable() -> void:
	var last: RouteStop = stops[stops.size() - 1]
	for stop in stops:
		if stop != last:
			stop.due = last.due * stop.route_distance / last.route_distance


func current_stop() -> RouteStop:
	return stops[stop_index] if stop_index < stops.size() else null


func is_finished() -> bool:
	return stop_index >= stops.size()


func advance_stop() -> void:
	stop_index += 1


## travel is the way the bus faces. A line that runs out and back along one road
## passes every point twice, and only the facing tells the two apart.
func update_position(point: Vector2, travel: Vector2 = Vector2.ZERO) -> void:
	_apply_progress(point, travel)


## Moves straight to the current stop, for skipping ahead.
func jump_to_stop() -> void:
	progress = current_stop().route_distance
	_cursor = clampi(distances.bsearch(progress) - 1, 0, polyline.size() - 2)


func distance_to_next_stop() -> float:
	var stop := current_stop()
	return maxf(stop.route_distance - progress, 0.0) if stop != null else 0.0


## Text for the next turn when it is close, otherwise empty.
func upcoming_turn() -> String:
	for turn: Dictionary in turns:
		var ahead: float = float(turn["distance"]) - progress
		if ahead > -5.0 and ahead < TURN_WARNING_DISTANCE:
			return turn["text"]
	return ""


## Records every place the route crosses this point, for warnings.
func add_hazard(point: Vector2) -> void:
	_hazard_points.append(point)
	_add_hazard_from(point, 0)


func _add_hazard_from(point: Vector2, first: int) -> void:
	for i in range(first, polyline.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(point, polyline[i], polyline[i + 1])
		if closest.distance_to(point) < HAZARD_ON_ROUTE_RADIUS:
			var distance := distances[i] + closest.distance_to(polyline[i])
			if hazards.is_empty() or absf(hazards[hazards.size() - 1] - distance) > 20.0:
				hazards.append(distance)


## True when a bump is coming up on the road ahead.
func hazard_ahead() -> bool:
	for distance in hazards:
		var ahead := distance - progress
		if ahead > 0.0 and ahead < HAZARD_WARNING_DISTANCE:
			return true
	return false


## Nearest point on the route to where the bus is now, for recovery.
func recovery_pose() -> Dictionary:
	var index := clampi(_cursor, 0, polyline.size() - 2)
	var forward := (polyline[index + 1] - polyline[index]).normalized()
	var kerb := Vector2(-forward.y, forward.x) * float(traffic_side)
	return {"position": polyline[index] + kerb * RoadNetwork.LANE_WIDTH / 2.0,
		"heading": RoadNetwork.heading_of(forward)}


## Adds the legs to the end of the route. The turn at the end of the last leg is
## left open until more road is added after it.
func _build_polyline(legs: Array, network: RoadNetwork) -> void:
	var leg_ends := PackedInt32Array()
	var node_kinds: Array[String] = []
	if _open_end >= 0:
		leg_ends.append(_open_end)
		node_kinds.append(_open_end_kind)
	for leg: Dictionary in legs:
		var road: Dictionary = network.roads[leg["road"]]
		var points: PackedVector2Array = road["points"]
		var ordered := points.duplicate()
		var end_node: String = road["to"]
		if int(leg["dir"]) < 0:
			ordered.reverse()
			end_node = road["from"]
		for point in ordered:
			if polyline.is_empty() or polyline[polyline.size() - 1].distance_to(point) > 0.01:
				polyline.append(point)
		leg_ends.append(polyline.size() - 1)
		node_kinds.append(network.nodes[end_node]["kind"])
	distances = PackedFloat32Array([0.0])
	for i in range(1, polyline.size()):
		distances.append(distances[i - 1] + polyline[i].distance_to(polyline[i - 1]))
	for i in leg_ends.size() - 1:
		_add_turn(leg_ends[i], node_kinds[i])
	if not leg_ends.is_empty():
		_open_end = leg_ends[leg_ends.size() - 1]
		_open_end_kind = node_kinds[node_kinds.size() - 1]
	if not legs.is_empty():
		last_leg = legs[legs.size() - 1]


func _add_turn(index: int, node_kind: String) -> void:
	var before := (polyline[index] - polyline[maxi(index - 4, 0)]).normalized()
	var after := (polyline[mini(index + 4, polyline.size() - 1)] - polyline[index]).normalized()
	var angle := before.angle_to(after)
	var text := ""
	if node_kind == "roundabout" and absf(angle) > TURN_BACK_ANGLE:
		turns.append({"distance": distances[index], "text": "Roundabout: turn back", "side": 0})
		return
	if node_kind == "roundabout":
		text = "Roundabout: go straight on" if absf(angle) < TURN_ANGLE else \
			("Roundabout: exit right" if angle > 0.0 else "Roundabout: exit left")
	elif absf(angle) >= TURN_ANGLE:
		text = "Turn right" if angle > 0.0 else "Turn left"
	else:
		text = "Straight on at the junction"
	var side := 0
	if absf(angle) >= TURN_ANGLE:
		side = 1 if angle > 0.0 else -1
	turns.append({"distance": distances[index], "text": text, "side": side})


func _add_stop(entry: Dictionary, network: RoadNetwork) -> void:
	var stop := RouteStop.new()
	stop.kind = kind
	stop.stop_name = entry["name"]
	stop.vendor = entry.get("vendor", false)
	stop.road = entry["road"]
	stop.along = entry["along"]
	stop.dir = int(entry["dir"])
	stop.waiting = int(entry.get("waiting", 0))
	stop.is_final = entry.get("final", false)
	stop.due = float(entry.get("due", 0.0))
	var placed: Dictionary = network.sample(stop.road, stop.along, stop.lateral(), stop.dir)
	stop.position = placed["position"]
	stop.heading = placed["heading"]
	var previous := stops[stops.size() - 1].route_distance if not stops.is_empty() else 0.0
	stop.route_distance = _distance_along_after(stop.position, previous)
	stops.append(stop)


func _distance_along_after(point: Vector2, after: float) -> float:
	var best := INF
	var best_distance := 0.0
	for i in polyline.size() - 1:
		if distances[i + 1] < after:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(point, polyline[i], polyline[i + 1])
		var gap := point.distance_to(closest)
		if gap < best - 0.001:
			best = gap
			best_distance = distances[i] + closest.distance_to(polyline[i])
	return best_distance


func _nearest_from_start(point: Vector2) -> int:
	var best := INF
	var best_index := 0
	for i in mini(polyline.size() - 1, SEARCH_AHEAD * 2):
		var gap := point.distance_to(polyline[i])
		if gap < best:
			best = gap
			best_index = i
	return best_index


func _apply_progress(point: Vector2, travel: Vector2 = Vector2.ZERO) -> void:
	var best := INF
	var best_index := _cursor
	var best_point := polyline[_cursor]
	var last := mini(_cursor + SEARCH_AHEAD, polyline.size() - 2)
	for i in range(maxi(_cursor - 2, 0), last + 1):
		var closest := Geometry2D.get_closest_point_to_segment(point, polyline[i], polyline[i + 1])
		var gap := point.distance_to(closest)
		if (polyline[i + 1] - polyline[i]).dot(travel) < 0.0:
			gap += WRONG_WAY_PENALTY
		if gap < best:
			best = gap
			best_index = i
			best_point = closest
	_cursor = best_index
	progress = maxf(progress, distances[best_index] + best_point.distance_to(polyline[best_index]))
