class_name RoadNetwork
extends RefCounted
## The road map as data: junction nodes joined by roads with sampled centre
## lines. Answers geometry questions for the world builder, the route and the
## ground. Vectors are on the ground plane as (X, Z), and -Z is north.

const LANE_WIDTH := 3.75
const DEFAULT_SPEED_LIMIT := 50.0 ## km/h
## Wide flared junctions, so a 12 m bus can turn without climbing the kerb.
const JUNCTION_RADIUS := 15.0
const ROAD_HALF_WIDTH := LANE_WIDTH
const SAMPLE_SPACING := 6.0
const CELL_SIZE := 16.0
## How far outside the asphalt edge_distance needs to be accurate.
const EDGE_REACH := 4.0
const BAY_LENGTH := 32.0
const BAY_DEPTH := 3.3
const BAY_TAPER := 10.0

var traffic_side: int = 1 ## 1 where traffic keeps right, -1 where it keeps left.
var nodes: Dictionary = {} ## id to {id, position, kind, radius, island}
var roads: Dictionary = {} ## id to {id, from, to, points, lengths, length}

var _capsules: Array[Dictionary] = [] ## a, b, radius
var _grid: Dictionary = {} ## Cell key to PackedInt32Array of capsule indices.


static func from_data(data: Dictionary, side: int = 1, default_limit: float = DEFAULT_SPEED_LIMIT) -> RoadNetwork:
	var network := RoadNetwork.new()
	network.traffic_side = side
	for entry: Dictionary in data["nodes"]:
		network.add_node(entry["id"], Vector2(entry["x"], entry["z"]), entry.get("kind", "junction"),
			entry.get("radius", JUNCTION_RADIUS), entry.get("island", 0.0))
	for entry: Dictionary in data["roads"]:
		var via: Array[Vector2] = []
		for point: Array in entry.get("via", []):
			via.append(Vector2(point[0], point[1]))
		network.add_road(entry["id"], entry["from"], entry["to"], via)
		network.roads[entry["id"]]["speed_limit"] = entry.get("speed_limit", default_limit)
		network.roads[entry["id"]]["traffic"] = entry.get("traffic", true)
	return network


func add_node(id: String, position: Vector2, kind: String, radius: float, island: float) -> void:
	nodes[id] = {"id": id, "position": position, "kind": kind, "radius": radius, "island": island}
	_add_capsule(position, position, radius)


func add_road(id: String, from_node: String, to_node: String, via: Array[Vector2]) -> void:
	var controls: Array[Vector2] = [nodes[from_node]["position"]]
	controls.append_array(via)
	controls.append(nodes[to_node]["position"])
	var points := _sample_controls(controls)
	var lengths := PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		lengths.append(lengths[i - 1] + points[i].distance_to(points[i - 1]))
		_add_capsule(points[i - 1], points[i], ROAD_HALF_WIDTH, id)
	roads[id] = {"id": id, "from": from_node, "to": to_node, "points": points, "lengths": lengths,
		"length": lengths[lengths.size() - 1]}


## Road space to world. along is metres from the road's first node.
## Given a dir, 1 travelling first node to last or -1 reversed, lateral is metres
## towards the kerb that traffic keeps to, so everything placed this way swaps
## sides in a left-hand country. With no dir, lateral is metres to the right of
## the road's own direction.
## Returns {position: Vector2, forward: Vector2, heading: float}.
func sample(road_id: String, along: float, lateral: float = 0.0, dir: int = 0) -> Dictionary:
	var road: Dictionary = roads[road_id]
	var points: PackedVector2Array = road["points"]
	var lengths: PackedFloat32Array = road["lengths"]
	var distance := clampf(along, 0.0, road["length"])
	var index := 0
	while index < points.size() - 2 and lengths[index + 1] < distance:
		index += 1
	var span := lengths[index + 1] - lengths[index]
	var share := (distance - lengths[index]) / span if span > 0.0 else 0.0
	var centre := points[index].lerp(points[index + 1], share)
	var forward := (points[index + 1] - points[index]).normalized() * float(1 if dir == 0 else dir)
	var right := Vector2(-forward.y, forward.x)
	var kerb_side := 1.0 if dir == 0 else float(traffic_side)
	return {"position": centre + right * lateral * kerb_side, "forward": forward, "heading": heading_of(forward)}


static func heading_of(forward: Vector2) -> float:
	return atan2(-forward.x, -forward.y)


## Bays follow the road, so one on a bend is several short pieces.
func add_bay(road_id: String, along: float, dir: int) -> void:
	var middle := ROAD_HALF_WIDTH + BAY_DEPTH / 2.0 - 0.1
	var pieces := int(ceil(BAY_LENGTH / SAMPLE_SPACING))
	var piece_length := BAY_LENGTH / float(pieces)
	for i in pieces:
		var start := along + (float(i) * piece_length - BAY_LENGTH / 2.0) * dir
		var a: Vector2 = sample(road_id, start, middle, dir)["position"]
		var b: Vector2 = sample(road_id, start + piece_length * dir, middle, dir)["position"]
		_add_capsule(a, b, BAY_DEPTH / 2.0 + 0.1)
	for end: float in [-1.0, 1.0]:
		_add_bay_taper(road_id, along + end * BAY_LENGTH / 2.0 * dir, end * dir, middle, dir)


## Lead-in and lead-out, so a bus can ease in and out of the bay.
func _add_bay_taper(road_id: String, start: float, outward: float, middle: float, dir: int) -> void:
	var steps := 5
	var piece := BAY_TAPER / float(steps)
	for i in steps:
		var share := float(i + 1) / float(steps)
		var lateral := lerpf(middle, ROAD_HALF_WIDTH - BAY_DEPTH / 2.0, share)
		var a: Vector2 = sample(road_id, start + outward * piece * float(i), lateral, dir)["position"]
		var b: Vector2 = sample(road_id, start + outward * piece * float(i + 1), lateral, dir)["position"]
		_add_capsule(a, b, BAY_DEPTH / 2.0)


## Metres outside the asphalt. Zero or less is on the road, and roundabout
## islands count as outside. Far from any road it returns INF.
func edge_distance(point: Vector2) -> float:
	for node: Dictionary in nodes.values():
		var island: float = node["island"]
		if island > 0.0 and point.distance_to(node["position"]) < island:
			return island - point.distance_to(node["position"])
	var key := _cell_key(int(floor(point.x / CELL_SIZE)), int(floor(point.y / CELL_SIZE)))
	if not _grid.has(key):
		return INF
	var nearest := INF
	var candidates: PackedInt32Array = _grid[key]
	for index in candidates:
		var capsule: Dictionary = _capsules[index]
		var closest := Geometry2D.get_closest_point_to_segment(point, capsule["a"], capsule["b"])
		nearest = minf(nearest, point.distance_to(closest) - float(capsule["radius"]))
	return nearest


## Speed limit in km/h at this point. Off any road, the town default applies.
func speed_limit_at(point: Vector2) -> float:
	var key := _cell_key(int(floor(point.x / CELL_SIZE)), int(floor(point.y / CELL_SIZE)))
	if not _grid.has(key):
		return DEFAULT_SPEED_LIMIT
	var nearest := INF
	var limit := DEFAULT_SPEED_LIMIT
	var candidates: PackedInt32Array = _grid[key]
	for index in candidates:
		var capsule: Dictionary = _capsules[index]
		var road_id: String = capsule["road"]
		if road_id == "":
			continue
		var closest := Geometry2D.get_closest_point_to_segment(point, capsule["a"], capsule["b"])
		var distance := point.distance_to(closest)
		if distance < nearest:
			nearest = distance
			limit = roads[road_id].get("speed_limit", DEFAULT_SPEED_LIMIT)
	return limit


func _add_capsule(a: Vector2, b: Vector2, radius: float, road_id: String = "") -> void:
	var index := _capsules.size()
	_capsules.append({"a": a, "b": b, "radius": radius, "road": road_id})
	var reach := radius + EDGE_REACH
	var low := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * reach
	var high := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * reach
	for cell_x in range(int(floor(low.x / CELL_SIZE)), int(floor(high.x / CELL_SIZE)) + 1):
		for cell_z in range(int(floor(low.y / CELL_SIZE)), int(floor(high.y / CELL_SIZE)) + 1):
			var key := _cell_key(cell_x, cell_z)
			if not _grid.has(key):
				_grid[key] = PackedInt32Array()
			var cell: PackedInt32Array = _grid[key]
			cell.append(index)
			_grid[key] = cell


func _cell_key(cell_x: int, cell_z: int) -> int:
	return (cell_x + 32768) * 65536 + (cell_z + 32768)


## Straight roads are subdivided so they can follow hills. Roads with via points
## become smooth Catmull-Rom curves through them.
func _sample_controls(controls: Array[Vector2]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in controls.size() - 1:
		var p0 := controls[maxi(i - 1, 0)]
		var p1 := controls[i]
		var p2 := controls[i + 1]
		var p3 := controls[mini(i + 2, controls.size() - 1)]
		var steps := maxi(int(ceil(p1.distance_to(p2) / SAMPLE_SPACING)), 1)
		for step in steps:
			points.append(_catmull_rom(p0, p1, p2, p3, float(step) / float(steps)))
	points.append(controls[controls.size() - 1])
	return points


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	return p1.cubic_interpolate(p2, p0, p3, t)
