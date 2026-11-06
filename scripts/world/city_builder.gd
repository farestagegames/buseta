class_name CityBuilder
extends Node3D
## Turns map data into the visible city and its solid collision. Everything
## static is merged, so the whole town costs a handful of draw calls.

const GRID_CELL := 12.0
const MAP_MARGIN := 160.0
const PAVEMENT_OUTER := RoadNetwork.ROAD_HALF_WIDTH + GroundSurface.PAVEMENT_WIDTH

const LIFT_PAVEMENT := 0.07
const LIFT_ROAD := 0.1
const LIFT_JUNCTION := 0.11
const LIFT_BAY := 0.12
const LIFT_LINE := 0.13

const ASPHALT := Color(0.2, 0.2, 0.22)
const PAVEMENT := Color(0.58, 0.57, 0.54)
const LINE := Color(0.92, 0.92, 0.88)
const YELLOW := Color(0.95, 0.78, 0.18)
const GRASS_A := Color(0.33, 0.42, 0.27)
const GRASS_B := Color(0.37, 0.46, 0.3)
const WALLS: Array[Color] = [
	Color(0.68, 0.58, 0.47), Color(0.56, 0.6, 0.66), Color(0.72, 0.66, 0.54),
	Color(0.62, 0.5, 0.5), Color(0.75, 0.72, 0.68), Color(0.52, 0.55, 0.5),
]
const CAR_COLOURS: Array[Color] = [
	Color(0.2, 0.3, 0.55), Color(0.75, 0.75, 0.78), Color(0.15, 0.15, 0.17),
	Color(0.55, 0.15, 0.15), Color(0.85, 0.82, 0.72),
]

var building_count: int = 0

var _network: RoadNetwork
var _ground: GroundSurface
var _random := RandomNumberGenerator.new()
var _solid: StaticBody3D
var _taken: Array[Vector3] = [] ## x, z, radius of placed buildings.
var _height_of: Callable


func build(map_data: Dictionary, network: RoadNetwork, ground: GroundSurface, route: RouteRunner) -> void:
	_network = network
	_ground = ground
	_height_of = ground.terrain_height
	_random.seed = 1187
	_solid = StaticBody3D.new()
	add_child(_solid)
	_build_terrain()
	_add_mesh(_build_roads(map_data, route))
	_add_mesh(_build_scenery(map_data, route))


func _add_mesh(builder: LowPolyBuilder) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = builder.build(LowPolyBuilder.vertex_colour_material())
	add_child(instance)


func _add_solid(centre: Vector3, size: Vector3, yaw: float) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = centre
	shape.rotation.y = yaw
	_solid.add_child(shape)


func _build_terrain() -> void:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for node: Dictionary in _network.nodes.values():
		var position: Vector2 = node["position"]
		low = Vector2(minf(low.x, position.x), minf(low.y, position.y))
		high = Vector2(maxf(high.x, position.x), maxf(high.y, position.y))
	low -= Vector2.ONE * MAP_MARGIN
	high += Vector2.ONE * (MAP_MARGIN + 180.0)
	var columns := int((high.x - low.x) / GRID_CELL) + 1
	var rows := int((high.y - low.y) / GRID_CELL) + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(columns * rows)
	normals.resize(columns * rows)
	colours.resize(columns * rows)
	var step := GRID_CELL
	for row in rows:
		for column in columns:
			var point := low + Vector2(column, row) * GRID_CELL
			var height := _ground.terrain_height(point)
			var index := row * columns + column
			vertices[index] = Vector3(point.x, height, point.y)
			var east := _ground.terrain_height(point + Vector2(step, 0.0))
			var south := _ground.terrain_height(point + Vector2(0.0, step))
			normals[index] = Vector3(height - east, step, height - south).normalized()
			colours[index] = GRASS_A if (row * 7 + column * 13) % 5 < 3 else GRASS_B
	for row in rows - 1:
		for column in columns - 1:
			var a := row * columns + column
			indices.append_array(PackedInt32Array([a, a + 1, a + columns + 1, a, a + columns + 1, a + columns]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := LowPolyBuilder.vertex_colour_material()
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _build_roads(map_data: Dictionary, route: RouteRunner) -> LowPolyBuilder:
	var b := LowPolyBuilder.new()
	for node: Dictionary in _network.nodes.values():
		var position: Vector2 = node["position"]
		var radius: float = node["radius"]
		b.disc(position, radius + GroundSurface.PAVEMENT_WIDTH, LIFT_PAVEMENT, _height_of, PAVEMENT, 28)
		b.disc(position, radius, LIFT_JUNCTION, _height_of, ASPHALT, 28)
		var island: float = node["island"]
		if island > 0.0:
			b.disc(position, island + 0.5, LIFT_LINE, _height_of, PAVEMENT, 24)
			b.disc(position, island, 0.26, _height_of, GRASS_B, 24)
			var height := _ground.terrain_height(position)
			b.box(Vector3(position.x, height + 2.0, position.y), Vector3(2.4, 4.0, 2.4), Color(0.45, 0.45, 0.5))
			b.box(Vector3(position.x, height + 4.6, position.y), Vector3(1.2, 1.2, 1.2), Color(0.8, 0.65, 0.2))
			_add_solid(Vector3(position.x, height + 2.0, position.y), Vector3(2.4, 8.0, 2.4), 0.0)
	for road: Dictionary in _network.roads.values():
		_ribbon(b, road, -PAVEMENT_OUTER, PAVEMENT_OUTER, LIFT_PAVEMENT, PAVEMENT)
		_ribbon(b, road, -RoadNetwork.ROAD_HALF_WIDTH, RoadNetwork.ROAD_HALF_WIDTH, LIFT_ROAD, ASPHALT)
		_markings(b, road)
	for stop in route.stops:
		_bay(b, stop)
	for feature: Dictionary in map_data.get("features", []):
		_feature_visual(b, feature)
	return b


func _ribbon(b: LowPolyBuilder, road: Dictionary, left: float, right: float, lift: float, colour: Color) -> void:
	var points: PackedVector2Array = road["points"]
	for i in points.size() - 1:
		var before := (points[i] - points[maxi(i - 1, 0)]) + (points[i + 1] - points[i])
		var after := (points[i + 1] - points[i]) + (points[mini(i + 2, points.size() - 1)] - points[i + 1])
		var side_a := Vector2(-before.y, before.x).normalized()
		var side_b := Vector2(-after.y, after.x).normalized()
		b.quad(_lifted(points[i] + side_a * left, lift), _lifted(points[i] + side_a * right, lift),
			_lifted(points[i + 1] + side_b * right, lift), _lifted(points[i + 1] + side_b * left, lift), colour)


func _lifted(point: Vector2, lift: float) -> Vector3:
	return Vector3(point.x, _ground.terrain_height(point) + lift, point.y)


func _markings(b: LowPolyBuilder, road: Dictionary) -> void:
	var start_gap: float = float(_network.nodes[road["from"]]["radius"]) + 2.0
	var end_gap: float = float(_network.nodes[road["to"]]["radius"]) + 2.0
	var along := start_gap
	var length: float = road["length"]
	while along < length - end_gap:
		_strip(b, road["id"], along, along + 3.0, -0.08, 0.08, LINE)
		along += 7.0
	for lateral: float in [-3.5, 3.5]:
		var at := start_gap
		while at < length - end_gap:
			_strip(b, road["id"], at, minf(at + 6.0, length - end_gap), lateral - 0.07, lateral + 0.07, LINE)
			at += 6.0


func _strip(b: LowPolyBuilder, road_id: String, from: float, to: float, left: float, right: float, colour: Color, lift: float = LIFT_LINE) -> void:
	var a: Dictionary = _network.sample(road_id, from)
	var c: Dictionary = _network.sample(road_id, to)
	var fwd_a: Vector2 = a["forward"]
	var fwd_c: Vector2 = c["forward"]
	var side_a := Vector2(-fwd_a.y, fwd_a.x)
	var side_c := Vector2(-fwd_c.y, fwd_c.x)
	var pa: Vector2 = a["position"]
	var pc: Vector2 = c["position"]
	b.quad(_lifted(pa + side_a * left, lift), _lifted(pa + side_a * right, lift),
		_lifted(pc + side_c * right, lift), _lifted(pc + side_c * left, lift), colour)


func _bay(b: LowPolyBuilder, stop: RouteStop) -> void:
	var half := RoadNetwork.BAY_LENGTH / 2.0
	var depth := RoadNetwork.BAY_DEPTH
	var edge := RoadNetwork.ROAD_HALF_WIDTH - 0.1
	var signed_half := half * float(stop.dir)
	var from := stop.along - signed_half
	var to := stop.along + signed_half
	var lateral_sign := float(stop.dir)
	var inner := edge * lateral_sign
	var outer := (edge + depth) * lateral_sign
	_strip(b, stop.road, minf(from, to), maxf(from, to), minf(inner, outer), maxf(inner, outer), Color(0.24, 0.24, 0.27), LIFT_BAY)
	var walk := (edge + depth + 3.2) * lateral_sign
	_strip(b, stop.road, minf(from, to), maxf(from, to), minf(outer, walk), maxf(outer, walk), PAVEMENT, LIFT_PAVEMENT)
	var line := (edge + depth - 0.1) * lateral_sign
	_strip(b, stop.road, minf(from, to), maxf(from, to), line - 0.1, line + 0.1, YELLOW, LIFT_LINE)
	for end: float in [from, to]:
		_strip(b, stop.road, end - 0.1, end + 0.1, minf(inner, outer), maxf(inner, outer), YELLOW, LIFT_LINE)


func _feature_visual(b: LowPolyBuilder, feature: Dictionary) -> void:
	if feature["type"] == "speed_bump":
		var along: float = feature["along"]
		_strip(b, feature["road"], along - 0.45, along + 0.45, -RoadNetwork.ROAD_HALF_WIDTH, RoadNetwork.ROAD_HALF_WIDTH, YELLOW, LIFT_LINE + 0.05)
		for lateral in range(-3, 4, 2):
			_strip(b, feature["road"], along - 0.46, along + 0.46, lateral - 0.4, lateral + 0.4, Color(0.1, 0.1, 0.1), LIFT_LINE + 0.06)
	else:
		var placed: Dictionary = _network.sample(feature["road"], feature["along"], feature["lateral"], feature["dir"])
		b.disc(placed["position"], MapLoader.POTHOLE_RADIUS, LIFT_LINE, _height_of, Color(0.09, 0.09, 0.1), 9)


func _build_scenery(map_data: Dictionary, route: RouteRunner) -> LowPolyBuilder:
	var b := LowPolyBuilder.new()
	for stop in route.stops:
		_shelter(b, stop)
	_depot(b)
	for road: Dictionary in _network.roads.values():
		_line_with_buildings(b, road)
		_line_with_trees(b, road)
	for car: Dictionary in map_data.get("parked_cars", []):
		_parked_car(b, car)
	return b


func _shelter(b: LowPolyBuilder, stop: RouteStop) -> void:
	var forward := stop.forward()
	var right := Vector2(-forward.y, forward.x)
	var spot := stop.position + right * (RoadNetwork.BAY_DEPTH / 2.0 + 2.6)
	var y := _ground.terrain_height(spot)
	var yaw := stop.heading
	if stop.is_final:
		return
	b.turned_box(Vector3(spot.x, y + 2.5, spot.y), Vector3(1.4, 0.12, 5.0), yaw, Color(0.25, 0.3, 0.38))
	b.turned_box(_at(spot + right * 0.6, y + 1.3), Vector3(0.1, 2.4, 5.0), yaw, Color(0.3, 0.42, 0.5))
	for end: float in [-2.4, 2.4]:
		b.turned_box(_at(spot + forward * end, y + 1.3), Vector3(1.2, 2.4, 0.1), yaw, Color(0.3, 0.42, 0.5))
	var pole := stop.position + forward * 8.0 + right * (RoadNetwork.BAY_DEPTH / 2.0 + 0.8)
	b.turned_box(_at(pole, y + 1.6), Vector3(0.12, 3.2, 0.12), yaw, Color(0.2, 0.2, 0.25))
	b.turned_box(_at(pole, y + 3.1), Vector3(0.1, 0.7, 0.8), yaw, Color(0.1, 0.4, 0.8))


func _at(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x, height, point.y)


func _depot(b: LowPolyBuilder) -> void:
	var node: Dictionary = _network.nodes["depot"]
	var position: Vector2 = node["position"]
	var centre := position + Vector2(0.0, 38.0)
	var y := _ground.terrain_height(centre)
	b.box(Vector3(centre.x, y + 5.0, centre.y), Vector3(60.0, 10.0, 26.0), Color(0.45, 0.48, 0.55))
	b.box(Vector3(centre.x, y + 10.4, centre.y), Vector3(62.0, 0.8, 28.0), Color(0.3, 0.32, 0.36))
	b.box(Vector3(centre.x, y + 3.5, centre.y - 13.05), Vector3(14.0, 7.0, 0.1), Color(0.2, 0.22, 0.26))
	_add_solid(Vector3(centre.x, y + 5.0, centre.y), Vector3(60.0, 14.0, 26.0), 0.0)
	_taken.append(Vector3(centre.x, centre.y, 42.0))


func _line_with_buildings(b: LowPolyBuilder, road: Dictionary) -> void:
	var length: float = road["length"]
	for side: float in [-1.0, 1.0]:
		var along := _random.randf_range(30.0, 45.0)
		while along < length - 30.0:
			var width := _random.randf_range(13.0, 24.0)
			var depth := _random.randf_range(11.0, 17.0)
			var height := _random.randf_range(6.5, 19.0)
			var lateral := (PAVEMENT_OUTER + 2.5 + depth / 2.0) * side
			var placed: Dictionary = _network.sample(road["id"], along, lateral, 1)
			if _try_building(b, placed["position"], placed["heading"], width, depth, height):
				building_count += 1
			along += width + _random.randf_range(4.0, 14.0)


func _try_building(b: LowPolyBuilder, centre: Vector2, heading: float, width: float, depth: float, height: float) -> bool:
	var forward := Vector2(-sin(heading), -cos(heading))
	var right := Vector2(-forward.y, forward.x)
	var clear := PAVEMENT_OUTER - RoadNetwork.ROAD_HALF_WIDTH + 1.0
	var lowest := INF
	for along_share: float in [-0.5, 0.0, 0.5]:
		for across_share: float in [-0.5, 0.0, 0.5]:
			var corner := centre + forward * width * along_share + right * depth * across_share
			if _network.edge_distance(corner) < clear:
				return false
			lowest = minf(lowest, _ground.terrain_height(corner))
	var reach := maxf(width, depth) * 0.6
	for other in _taken:
		if centre.distance_to(Vector2(other.x, other.y)) < reach + other.z:
			return false
	_taken.append(Vector3(centre.x, centre.y, reach))

	var wall: Color = WALLS[_random.randi_range(0, WALLS.size() - 1)]
	var total := height + 2.0
	var mid := lowest - 1.0 + total / 2.0
	b.turned_box(_at(centre, mid), Vector3(depth, total, width), heading, wall)
	b.turned_box(_at(centre, lowest + height + 1.2), Vector3(depth + 0.5, 0.4, width + 0.5), heading, wall.darkened(0.3))
	var level := lowest + 2.3
	while level < lowest + height - 1.0:
		b.turned_box(_at(centre, level), Vector3(depth + 0.1, 0.95, width + 0.1), heading, Color(0.3, 0.37, 0.45))
		level += 3.4
	_add_solid(_at(centre, mid), Vector3(depth, total + 6.0, width), heading)
	return true


func _line_with_trees(b: LowPolyBuilder, road: Dictionary) -> void:
	var length: float = road["length"]
	for side: float in [-1.0, 1.0]:
		var along := _random.randf_range(20.0, 40.0)
		while along < length - 15.0:
			var placed: Dictionary = _network.sample(road["id"], along, (PAVEMENT_OUTER + 1.2) * side, 1)
			var spot: Vector2 = placed["position"]
			if _network.edge_distance(spot) > 3.1 and _is_free(spot, 1.5):
				var y := _ground.terrain_height(spot)
				b.box(Vector3(spot.x, y + 1.2, spot.y), Vector3(0.4, 2.4, 0.4), Color(0.35, 0.24, 0.16))
				var size := _random.randf_range(2.4, 3.4)
				b.box(Vector3(spot.x, y + 3.4, spot.y), Vector3(size, 2.4, size), Color(0.2, 0.42, 0.2))
				b.box(Vector3(spot.x, y + 4.9, spot.y), Vector3(size * 0.6, 1.4, size * 0.6), Color(0.24, 0.48, 0.23))
				_add_solid(Vector3(spot.x, y + 2.0, spot.y), Vector3(0.5, 6.0, 0.5), 0.0)
			along += _random.randf_range(28.0, 46.0)


func _is_free(spot: Vector2, radius: float) -> bool:
	for other in _taken:
		if spot.distance_to(Vector2(other.x, other.y)) < radius + other.z:
			return false
	return true


func _parked_car(b: LowPolyBuilder, car: Dictionary) -> void:
	var placed: Dictionary = _network.sample(car["road"], car["along"], RoadNetwork.ROAD_HALF_WIDTH - 1.15, car["dir"])
	var spot: Vector2 = placed["position"]
	var yaw: float = placed["heading"]
	var y := _ground.terrain_height(spot) + LIFT_ROAD
	var colour: Color = CAR_COLOURS[_random.randi_range(0, CAR_COLOURS.size() - 1)]
	b.turned_box(Vector3(spot.x, y + 0.6, spot.y), Vector3(1.8, 0.7, 4.3), yaw, colour)
	b.turned_box(Vector3(spot.x, y + 1.2, spot.y), Vector3(1.55, 0.55, 2.2), yaw, Color(0.15, 0.2, 0.26))
	var forward: Vector2 = placed["forward"]
	var right := Vector2(-forward.y, forward.x)
	for along: float in [-1.35, 1.35]:
		for across: float in [-0.85, 0.85]:
			var wheel := spot + forward * along + right * across
			b.turned_box(Vector3(wheel.x, y + 0.3, wheel.y), Vector3(0.24, 0.6, 0.6), yaw, Color(0.06, 0.06, 0.07))
	_add_solid(Vector3(spot.x, y + 0.9, spot.y), Vector3(1.8, 2.0, 4.3), yaw)
