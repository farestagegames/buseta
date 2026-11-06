class_name RouteRunner
extends RefCounted
## Tracks progress along a route: which stop is next, how far away it is and
## which turn is coming. Pure logic. Routes are data files.

const SEARCH_AHEAD := 30
const TURN_WARNING_DISTANCE := 90.0
const TURN_ANGLE := deg_to_rad(35.0)

var route_name: String = ""
var stops: Array[RouteStop] = []
var polyline: PackedVector2Array = PackedVector2Array()
var distances: PackedFloat32Array = PackedFloat32Array()
var turns: Array[Dictionary] = [] ## distance: float, text: String
var start_position: Vector2 = Vector2.ZERO
var start_heading: float = 0.0
var stop_index: int = 0
var progress: float = 0.0

var _cursor: int = 0


static func build(data: Dictionary, network: RoadNetwork) -> RouteRunner:
	var runner := RouteRunner.new()
	runner.route_name = data["name"]
	runner._build_polyline(data["legs"], network)
	var start: Dictionary = data["start"]
	var placed: Dictionary = network.sample(start["road"], start["along"], start["lateral"], start["dir"])
	runner.start_position = placed["position"]
	runner.start_heading = placed["heading"]
	runner._cursor = runner._nearest_from_start(runner.start_position)
	runner._apply_progress(runner.start_position)
	for entry: Dictionary in data["stops"]:
		runner._add_stop(entry, network)
	return runner


func current_stop() -> RouteStop:
	return stops[stop_index] if stop_index < stops.size() else null


func is_finished() -> bool:
	return stop_index >= stops.size()


func advance_stop() -> void:
	stop_index += 1


func update_position(point: Vector2) -> void:
	_apply_progress(point)


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


## Nearest point on the route to where the bus is now, for recovery.
func recovery_pose() -> Dictionary:
	var index := clampi(_cursor, 0, polyline.size() - 2)
	var forward := (polyline[index + 1] - polyline[index]).normalized()
	var right := Vector2(-forward.y, forward.x)
	return {"position": polyline[index] + right * RoadNetwork.LANE_WIDTH / 2.0,
		"heading": RoadNetwork.heading_of(forward)}


func _build_polyline(legs: Array, network: RoadNetwork) -> void:
	var leg_ends := PackedInt32Array()
	var node_kinds: Array[String] = []
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


func _add_turn(index: int, node_kind: String) -> void:
	var before := (polyline[index] - polyline[maxi(index - 4, 0)]).normalized()
	var after := (polyline[mini(index + 4, polyline.size() - 1)] - polyline[index]).normalized()
	var angle := before.angle_to(after)
	var text := ""
	if node_kind == "roundabout":
		text = "Roundabout: go straight on" if absf(angle) < TURN_ANGLE else \
			("Roundabout: exit right" if angle > 0.0 else "Roundabout: exit left")
	elif absf(angle) >= TURN_ANGLE:
		text = "Turn right" if angle > 0.0 else "Turn left"
	else:
		text = "Straight on at the junction"
	turns.append({"distance": distances[index], "text": text})


func _add_stop(entry: Dictionary, network: RoadNetwork) -> void:
	var stop := RouteStop.new()
	stop.stop_name = entry["name"]
	stop.road = entry["road"]
	stop.along = entry["along"]
	stop.dir = int(entry["dir"])
	stop.waiting = int(entry.get("waiting", 0))
	stop.is_final = entry.get("final", false)
	var lateral := RoadNetwork.ROAD_HALF_WIDTH + RoadNetwork.BAY_DEPTH / 2.0 - 0.2
	var placed: Dictionary = network.sample(stop.road, stop.along, lateral, stop.dir)
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


func _apply_progress(point: Vector2) -> void:
	var best := INF
	var best_index := _cursor
	var best_point := polyline[_cursor]
	var last := mini(_cursor + SEARCH_AHEAD, polyline.size() - 2)
	for i in range(maxi(_cursor - 2, 0), last + 1):
		var closest := Geometry2D.get_closest_point_to_segment(point, polyline[i], polyline[i + 1])
		var gap := point.distance_to(closest)
		if gap < best:
			best = gap
			best_index = i
			best_point = closest
	_cursor = best_index
	progress = maxf(progress, distances[best_index] + best_point.distance_to(polyline[best_index]))
