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
const LIFT_KERB := 0.09

const TEXTURE_ASPHALT := preload("res://assets/textures/asphalt.png")
const TEXTURE_PAVEMENT := preload("res://assets/textures/pavement.png")
const TEXTURE_GRASS := preload("res://assets/textures/grass.png")
const TEXTURE_FLATS := preload("res://assets/textures/facade_flats.png")
const TEXTURE_OFFICE := preload("res://assets/textures/facade_office.png")
const TEXTURE_SHOPS := preload("res://assets/textures/facade_shops.png")
const STOREY := 3.2
const SHOP_WIDTH := 6.4

const ASPHALT := Color(0.34, 0.34, 0.36)
const ASPHALT_PATCH := Color(0.27, 0.27, 0.29)
const PAVEMENT := Color(0.62, 0.61, 0.59)
const KERB := Color(0.72, 0.71, 0.68)
const LINE := Color(0.92, 0.92, 0.88)
const YELLOW := Color(0.95, 0.78, 0.18)
const GRASS_A := Color(0.62, 0.66, 0.56)
const GRASS_B := Color(0.68, 0.71, 0.6)
const WALLS: Array[Color] = [
	Color(0.86, 0.66, 0.54), Color(0.74, 0.5, 0.42), Color(0.92, 0.86, 0.74),
	Color(0.8, 0.8, 0.8), Color(0.7, 0.58, 0.5), Color(0.9, 0.8, 0.66),
]
const ROOF_TILES: Array[Color] = [Color(0.42, 0.24, 0.2), Color(0.3, 0.3, 0.34), Color(0.5, 0.3, 0.22)]
const AWNINGS: Array[Color] = [Color(0.7, 0.2, 0.18), Color(0.18, 0.42, 0.3), Color(0.2, 0.3, 0.55), Color(0.85, 0.65, 0.2)]
const TREE_LEAVES: Array[Color] = [Color(0.27, 0.42, 0.2), Color(0.32, 0.47, 0.22), Color(0.22, 0.38, 0.22)]

var building_count: int = 0
var lamp_spots: Array[Dictionary] = [] ## position and yaw, for ObstacleField.

var _network: RoadNetwork
var _ground: GroundSurface
var _random := RandomNumberGenerator.new()
var _solid: StaticBody3D
var _taken: Array[Vector3] = [] ## x, z, radius of placed buildings.
var _height_of: Callable
var _flats: LowPolyBuilder
var _office: LowPolyBuilder
var _shops: LowPolyBuilder
var _lines: LowPolyBuilder
var _pavements: LowPolyBuilder
var _woodland: LowPolyBuilder
var _stop_spots: Array[Vector2] = []
var _signs: Array[Dictionary] = []


func build(map_data: Dictionary, network: RoadNetwork, ground: GroundSurface, route: RouteRunner) -> void:
	_network = network
	_ground = ground
	_height_of = ground.terrain_height
	_random.seed = 1187
	_solid = StaticBody3D.new()
	add_child(_solid)
	_flats = LowPolyBuilder.new()
	_office = LowPolyBuilder.new()
	_shops = LowPolyBuilder.new()
	_lines = LowPolyBuilder.new()
	_pavements = LowPolyBuilder.new()
	_woodland = LowPolyBuilder.new()
	_build_terrain()
	for stop in route.stops:
		_stop_spots.append(stop.position)
	_add_mesh(_build_roads(map_data, route), _textured(TEXTURE_ASPHALT, Vector2(8.0, 8.0)), false)
	_add_mesh(_pavements, _textured(TEXTURE_PAVEMENT, Vector2(3.2, 3.2)), false)
	_add_mesh(_lines, LowPolyBuilder.vertex_colour_material(), false)
	_add_mesh(_build_scenery(route), LowPolyBuilder.vertex_colour_material())
	_add_mesh(_woodland, LowPolyBuilder.vertex_colour_material(), false)
	_add_mesh(_flats, _textured(TEXTURE_FLATS, Vector2(STOREY, STOREY)))
	_add_mesh(_office, _textured(TEXTURE_OFFICE, Vector2(STOREY, STOREY)))
	_add_mesh(_shops, _textured(TEXTURE_SHOPS, Vector2(SHOP_WIDTH, STOREY)))


func _add_mesh(builder: LowPolyBuilder, material: Material, casts_shadow: bool = true) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = builder.build(material)
	if not casts_shadow:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## Textures tint with vertex colour, so one wall texture covers every building.
func _textured(texture: Texture2D, tile_metres: Vector2) -> StandardMaterial3D:
	var material := LowPolyBuilder.vertex_colour_material()
	material.albedo_texture = texture
	material.uv1_scale = Vector3(1.0 / tile_metres.x, 1.0 / tile_metres.y, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 0.9
	return material


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
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	uvs.resize(columns * rows)
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
			uvs[index] = point
	for row in rows - 1:
		for column in columns - 1:
			var a := row * columns + column
			indices.append_array(PackedInt32Array([a, a + 1, a + columns + 1, a, a + columns + 1, a + columns]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := _textured(TEXTURE_GRASS, Vector2(14.0, 14.0))
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
		_pavements.disc(position, radius + GroundSurface.PAVEMENT_WIDTH, LIFT_PAVEMENT, _height_of, PAVEMENT, 32)
		_lines.disc(position, radius + 0.2, LIFT_KERB, _height_of, KERB, 32)
		b.disc(position, radius, LIFT_JUNCTION, _height_of, ASPHALT, 32)
		var island: float = node["island"]
		if island > 0.0:
			_build_island(position, island)
	for road: Dictionary in _network.roads.values():
		_ribbon(_pavements, road, -PAVEMENT_OUTER, PAVEMENT_OUTER, LIFT_PAVEMENT, PAVEMENT)
		_ribbon(_lines, road, -RoadNetwork.ROAD_HALF_WIDTH - 0.2, RoadNetwork.ROAD_HALF_WIDTH + 0.2, LIFT_KERB, KERB)
		_ribbon(b, road, -RoadNetwork.ROAD_HALF_WIDTH, RoadNetwork.ROAD_HALF_WIDTH, LIFT_ROAD, ASPHALT)
		_road_wear(b, road)
		_markings(road)
		_junction_lines(road)
	for stop in route.stops:
		_bay(b, stop)
	for feature: Dictionary in map_data.get("features", []):
		_feature_visual(feature)
	return b


func _build_island(position: Vector2, island: float) -> void:
	_lines.disc(position, island + 0.5, LIFT_LINE, _height_of, KERB, 24)
	_lines.disc(position, island, 0.26, _height_of, Color(0.34, 0.44, 0.27), 24)
	var height := _ground.terrain_height(position)
	_lines.box(Vector3(position.x, height + 1.0, position.y), Vector3(3.2, 2.0, 3.2), Color(0.62, 0.6, 0.56))
	_lines.box(Vector3(position.x, height + 3.5, position.y), Vector3(1.5, 3.0, 1.5), Color(0.68, 0.66, 0.62))
	_lines.box(Vector3(position.x, height + 5.6, position.y), Vector3(0.9, 1.2, 0.9), Color(0.3, 0.42, 0.4))
	_add_solid(Vector3(position.x, height + 2.0, position.y), Vector3(3.2, 8.0, 3.2), 0.0)
	for i in 8:
		var spot := position + Vector2.RIGHT.rotated(TAU * i / 8.0) * (island - 2.2)
		_lines.blob(Vector3(spot.x, height + 0.8, spot.y), Vector3(1.2, 0.8, 1.2), Color(0.3, 0.45, 0.24), _random)


## Patches and manholes, so roads look used rather than freshly drawn.
func _road_wear(b: LowPolyBuilder, road: Dictionary) -> void:
	var length: float = road["length"]
	var along := _random.randf_range(25.0, 60.0)
	while along < length - 25.0:
		var lateral := _random.randf_range(-2.6, 2.6)
		var span := _random.randf_range(2.0, 7.0)
		var half_width := _random.randf_range(0.5, 1.1)
		_strip(b, road["id"], along, along + span, lateral - half_width, lateral + half_width, ASPHALT_PATCH, LIFT_ROAD + 0.006)
		if _random.randf() < 0.4:
			var spot: Vector2 = _network.sample(road["id"], along + span + 3.0, _random.randf_range(-2.0, 2.0))["position"]
			_lines.disc(spot, 0.42, LIFT_ROAD + 0.012, _height_of, Color(0.13, 0.13, 0.14), 8)
		along += _random.randf_range(30.0, 75.0)


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


func _markings(road: Dictionary) -> void:
	var start_gap: float = float(_network.nodes[road["from"]]["radius"]) + 1.0
	var end_gap: float = float(_network.nodes[road["to"]]["radius"]) + 1.0
	var along := start_gap + 6.0
	var length: float = road["length"]
	while along < length - end_gap - 6.0:
		_strip(_lines, road["id"], along, along + 3.0, -0.07, 0.07, LINE)
		along += 7.0
	for lateral: float in [-3.5, 3.5]:
		var at := start_gap
		while at < length - end_gap:
			_strip(_lines, road["id"], at, minf(at + 6.0, length - end_gap), lateral - 0.06, lateral + 0.06, LINE)
			at += 6.0


## Stop lines where each road meets a junction, and a zebra crossing before it.
func _junction_lines(road: Dictionary) -> void:
	var length: float = road["length"]
	var start: Dictionary = _network.nodes[road["from"]]
	var finish: Dictionary = _network.nodes[road["to"]]
	var start_gap: float = float(start["radius"]) + 1.2
	var end_at: float = length - float(finish["radius"]) - 1.2
	if start["kind"] != "terminal":
		_strip(_lines, road["id"], start_gap, start_gap + 0.4, -RoadNetwork.ROAD_HALF_WIDTH + 0.2, -0.1, LINE)
		_zebra(road["id"], start_gap + 1.4)
	if finish["kind"] != "terminal":
		_strip(_lines, road["id"], end_at - 0.4, end_at, 0.1, RoadNetwork.ROAD_HALF_WIDTH - 0.2, LINE)
		_zebra(road["id"], end_at - 5.0)


func _zebra(road_id: String, along: float) -> void:
	var lateral := -RoadNetwork.ROAD_HALF_WIDTH + 0.3
	while lateral < RoadNetwork.ROAD_HALF_WIDTH - 0.6:
		_strip(_lines, road_id, along, along + 3.0, lateral, lateral + 0.5, LINE)
		lateral += 1.0


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
	var from := stop.along - half
	var to := stop.along + half
	var side := float(stop.dir)
	var inner := edge * side
	var outer := (edge + depth) * side
	var walk := (edge + depth + 3.2) * side
	_strip(b, stop.road, from, to, minf(inner, outer), maxf(inner, outer), ASPHALT_PATCH, LIFT_BAY)
	_taper(b, stop.road, from, from - RoadNetwork.BAY_TAPER, inner, outer)
	_taper(b, stop.road, to, to + RoadNetwork.BAY_TAPER, inner, outer)
	_strip(_pavements, stop.road, from, to, minf(outer, walk), maxf(outer, walk), PAVEMENT, LIFT_PAVEMENT + 0.005)
	var kerb := (edge + depth + 0.1) * side
	_strip(_lines, stop.road, from, to, kerb - 0.15, kerb + 0.15, KERB, LIFT_BAY + 0.005)
	# Painted bus box with zigzag entry lines.
	var line := (edge + depth - 0.25) * side
	_strip(_lines, stop.road, from + 1.0, to - 1.0, line - 0.09, line + 0.09, YELLOW)
	var box := (edge + 0.3) * side
	_strip(_lines, stop.road, from + 7.0, to - 7.0, box - 0.09, box + 0.09, YELLOW)
	for end: float in [from + 7.0, to - 7.0]:
		_strip(_lines, stop.road, end - 0.09, end + 0.09, minf(box, line), maxf(box, line), YELLOW)
	var step := 2.4
	for start: float in [from + 1.0, to - 7.0]:
		var at := start
		var high := true
		while at < start + 6.0 - 0.01:
			var from_lateral := line if high else box
			var to_lateral := box if high else line
			_diagonal(stop.road, at, from_lateral, at + step, to_lateral)
			high = not high
			at += step


func _taper(b: LowPolyBuilder, road_id: String, wide_end: float, narrow_end: float, inner: float, outer: float) -> void:
	var a: Vector2 = _network.sample(road_id, wide_end, inner)["position"]
	var c: Vector2 = _network.sample(road_id, wide_end, outer)["position"]
	var tip: Vector2 = _network.sample(road_id, narrow_end, inner)["position"]
	var first := _lifted(a, LIFT_BAY)
	var second := _lifted(c, LIFT_BAY)
	var third := _lifted(tip, LIFT_BAY)
	# Winding depends on which way the taper points, so draw it from both sides.
	b.quad(first, second, third, third, ASPHALT_PATCH)
	b.quad(first, third, second, second, ASPHALT_PATCH)


func _diagonal(road_id: String, along_a: float, lateral_a: float, along_b: float, lateral_b: float) -> void:
	var a: Vector2 = _network.sample(road_id, along_a, lateral_a)["position"]
	var b: Vector2 = _network.sample(road_id, along_b, lateral_b)["position"]
	var width := (b - a).normalized().orthogonal() * 0.09
	_lines.quad(_lifted(a - width, LIFT_LINE), _lifted(a + width, LIFT_LINE), _lifted(b + width, LIFT_LINE), _lifted(b - width, LIFT_LINE), YELLOW)


func _feature_visual(feature: Dictionary) -> void:
	if feature["type"] == "speed_bump":
		var along: float = feature["along"]
		_strip(_lines, feature["road"], along - 0.45, along + 0.45, -RoadNetwork.ROAD_HALF_WIDTH, RoadNetwork.ROAD_HALF_WIDTH, YELLOW, LIFT_LINE + 0.05)
		for lateral in range(-3, 4, 2):
			_strip(_lines, feature["road"], along - 0.46, along + 0.46, lateral - 0.4, lateral + 0.4, Color(0.1, 0.1, 0.1), LIFT_LINE + 0.06)
		for warning: float in [-1.0, 1.0]:
			_bump_warning(feature["road"], along + warning * 30.0, warning)
	else:
		var placed: Dictionary = _network.sample(feature["road"], feature["along"], feature["lateral"], feature["dir"])
		_lines.disc(placed["position"], MapLoader.POTHOLE_RADIUS, LIFT_LINE, _height_of, Color(0.09, 0.09, 0.1), 9)


## Painted bars across the lane and a warning sign, so a bump is never a surprise.
## approach is -1 for traffic heading along the road, and 1 for the opposite way.
func _bump_warning(road_id: String, along: float, approach: float) -> void:
	var side := -approach
	for i in 3:
		var at := along + approach * float(i) * 2.2
		var low := minf(0.15 * side, 3.4 * side)
		var high := maxf(0.15 * side, 3.4 * side)
		_strip(_lines, road_id, at, at + 0.5, low, high, YELLOW)
	var placed: Dictionary = _network.sample(road_id, along, (RoadNetwork.ROAD_HALF_WIDTH + 0.9) * side)
	var spot: Vector2 = placed["position"]
	var y := _ground.terrain_height(spot)
	_signs.append({"spot": spot, "y": y, "yaw": placed["heading"]})


func _build_scenery(route: RouteRunner) -> LowPolyBuilder:
	var b := LowPolyBuilder.new()
	for stop in route.stops:
		_shelter(b, stop)
	_depot(b)
	for road: Dictionary in _network.roads.values():
		_line_with_buildings(b, road, 0.0)
	for road: Dictionary in _network.roads.values():
		_line_with_buildings(b, road, 24.0)
		_line_with_trees(b, road)
		_line_with_lamps(road)
	_tree_line(b)
	for sign_data: Dictionary in _signs:
		var spot: Vector2 = sign_data["spot"]
		var y: float = sign_data["y"]
		var yaw: float = sign_data["yaw"]
		b.turned_box(_at(spot, y + 1.3), Vector3(0.09, 2.6, 0.09), yaw, Color(0.25, 0.26, 0.28))
		b.turned_box(_at(spot, y + 2.6), Vector3(0.75, 0.75, 0.05), yaw + PI / 4.0, YELLOW)
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


func _line_with_buildings(b: LowPolyBuilder, road: Dictionary, set_back: float) -> void:
	var length: float = road["length"]
	for side: float in [-1.0, 1.0]:
		var along := _random.randf_range(32.0, 48.0)
		while along < length - 32.0:
			var width := _random.randf_range(12.0, 24.0)
			var depth := _random.randf_range(11.0, 17.0)
			var lateral := (PAVEMENT_OUTER + 2.5 + set_back + depth / 2.0) * side
			var placed: Dictionary = _network.sample(road["id"], along, lateral, 1)
			var forward: Vector2 = placed["forward"]
			var to_road := Vector2(-forward.y, forward.x) * -side
			if _try_building(b, placed["position"], placed["heading"], width, depth, to_road, set_back == 0.0):
				building_count += 1
			along += width + _random.randf_range(3.0, 11.0)


func _try_building(b: LowPolyBuilder, centre: Vector2, heading: float, width: float, depth: float, to_road: Vector2, on_street: bool) -> bool:
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
	if not _is_free(centre, reach):
		return false
	_taken.append(Vector3(centre.x, centre.y, reach))

	var kind := _random.randf()
	if kind < 0.3:
		_house(b, centre, heading, width, depth, lowest)
	elif kind < 0.8:
		_block(b, _flats, centre, heading, width, depth, lowest, _random.randi_range(3, 5), to_road, on_street)
	else:
		_block(b, _office, centre, heading, width, depth, lowest, _random.randi_range(5, 7), to_road, on_street)
	return true


func _house(b: LowPolyBuilder, centre: Vector2, heading: float, width: float, depth: float, base: float) -> void:
	var size := Vector3(minf(depth, 11.0), STOREY * 2.0, minf(width, 15.0))
	_walls(_flats, centre, size, heading, base, WALLS[_random.randi_range(0, WALLS.size() - 1)])
	var roof := ROOF_TILES[_random.randi_range(0, ROOF_TILES.size() - 1)]
	b.gable(_at(centre, base + size.y), size.x + 0.7, size.z + 0.7, 3.2, heading, roof)
	var chimney := centre + Vector2(-sin(heading), -cos(heading)) * size.z * 0.3
	b.turned_box(_at(chimney, base + size.y + 2.4), Vector3(0.7, 2.2, 0.7), heading, Color(0.5, 0.35, 0.3))
	_add_solid(_at(centre, base + size.y / 2.0), size + Vector3(0.0, 6.0, 0.0), heading)


func _block(b: LowPolyBuilder, facade: LowPolyBuilder, centre: Vector2, heading: float, width: float, depth: float, base: float, storeys: int, to_road: Vector2, on_street: bool) -> void:
	var height := float(storeys) * STOREY
	var size := Vector3(depth, height, width)
	var wall: Color = WALLS[_random.randi_range(0, WALLS.size() - 1)]
	if facade == _office:
		wall = wall.lerp(Color.WHITE, 0.6)
	_walls(facade, centre, size, heading, base, wall)
	var parapet := wall.darkened(0.25)
	b.turned_box(_at(centre, base + height + 0.25), Vector3(depth + 0.3, 0.5, width + 0.3), heading, parapet)
	b.turned_box(_at(centre, base + height + 0.52), Vector3(depth - 0.4, 0.06, width - 0.4), heading, Color(0.3, 0.3, 0.32))
	for i in _random.randi_range(1, 3):
		var unit := centre + Vector2(_random.randf_range(-3.0, 3.0), _random.randf_range(-3.0, 3.0))
		b.turned_box(_at(unit, base + height + 1.0), Vector3(1.6, 1.0, 1.2), heading, Color(0.6, 0.6, 0.62))
	if on_street and _random.randf() < 0.65:
		_shopfront(b, centre, heading, size, base, to_road)
	_add_solid(_at(centre, base + height / 2.0), size + Vector3(0.0, 6.0, 0.0), heading)


## Walls run a metre below the lowest corner, so they never float on a slope.
func _walls(facade: LowPolyBuilder, centre: Vector2, size: Vector3, heading: float, base: float, colour: Color) -> void:
	facade.uv_base_height = base + size.y
	var depth_below := 1.2
	facade.turned_box(_at(centre, base + (size.y - depth_below) / 2.0), Vector3(size.x, size.y + depth_below, size.z), heading, colour)


func _shopfront(b: LowPolyBuilder, centre: Vector2, heading: float, size: Vector3, base: float, to_road: Vector2) -> void:
	var front := centre + to_road * (size.x / 2.0 + 0.04)
	_shops.uv_base_height = base + STOREY
	var tint := Color(1.0, 1.0, 1.0).lerp(AWNINGS[_random.randi_range(0, AWNINGS.size() - 1)], 0.25)
	_shops.turned_box(_at(front, base + STOREY / 2.0 - 0.6), Vector3(0.1, STOREY + 1.2, size.z - 0.5), heading, tint)
	var awning := centre + to_road * (size.x / 2.0 + 0.7)
	var colour: Color = AWNINGS[_random.randi_range(0, AWNINGS.size() - 1)]
	b.turned_box(_at(awning, base + 2.75), Vector3(1.3, 0.14, size.z - 1.0), heading, colour)


func _line_with_trees(b: LowPolyBuilder, road: Dictionary) -> void:
	var length: float = road["length"]
	for side: float in [-1.0, 1.0]:
		var along := _random.randf_range(20.0, 40.0)
		while along < length - 15.0:
			var placed: Dictionary = _network.sample(road["id"], along, (PAVEMENT_OUTER + 1.2) * side, 1)
			var spot: Vector2 = placed["position"]
			if _network.edge_distance(spot) > 3.1 and _is_free(spot, 1.5):
				_tree(b, spot, true)
			along += _random.randf_range(22.0, 40.0)


func _tree(b: LowPolyBuilder, spot: Vector2, solid: bool) -> void:
	var y := _ground.terrain_height(spot)
	var scale := _random.randf_range(0.8, 1.35)
	var colour: Color = TREE_LEAVES[_random.randi_range(0, TREE_LEAVES.size() - 1)]
	b.box(Vector3(spot.x, y + 1.4 * scale, spot.y), Vector3(0.32, 2.8, 0.32) * scale, Color(0.32, 0.24, 0.18))
	b.blob(Vector3(spot.x, y + 4.0 * scale, spot.y), Vector3(2.3, 2.2, 2.3) * scale, colour, _random)
	b.blob(Vector3(spot.x + 0.9, y + 5.4 * scale, spot.y - 0.5), Vector3(1.5, 1.5, 1.5) * scale, colour.lightened(0.08), _random)
	if solid:
		_add_solid(Vector3(spot.x, y + 2.0, spot.y), Vector3(0.5, 6.0, 0.5), 0.0)


func _line_with_lamps(road: Dictionary) -> void:
	var length: float = road["length"]
	var along := 52.0
	var side := 1.0
	while along < length - 50.0:
		var lateral := (RoadNetwork.ROAD_HALF_WIDTH + 0.5) * side
		var placed: Dictionary = _network.sample(road["id"], along, lateral, 1)
		var spot: Vector2 = placed["position"]
		if _network.edge_distance(spot) > 0.3 and _clear_of_stops(spot):
			_lamp(spot, placed["forward"], side)
		side = -side
		along += 42.0


## Bus bays need their entry and exit clear of anything solid.
func _clear_of_stops(spot: Vector2) -> bool:
	for stop_spot in _stop_spots:
		if spot.distance_to(stop_spot) < RoadNetwork.BAY_LENGTH:
			return false
	return true


## Lamp arms reach out over the road. The lamp mesh has its arm along +X.
func _lamp(spot: Vector2, forward: Vector2, side: float) -> void:
	var to_road := Vector2(-forward.y, forward.x) * -side
	lamp_spots.append({"position": spot, "yaw": atan2(-to_road.y, to_road.x)})


## A ring of woodland hides the edge of the world.
func _tree_line(b: LowPolyBuilder) -> void:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for node: Dictionary in _network.nodes.values():
		var position: Vector2 = node["position"]
		low = Vector2(minf(low.x, position.x), minf(low.y, position.y))
		high = Vector2(maxf(high.x, position.x), maxf(high.y, position.y))
	low -= Vector2.ONE * 110.0
	high += Vector2.ONE * 150.0
	var spacing := 24.0
	var x := low.x
	while x < high.x:
		_tree(_woodland, Vector2(x, low.y + _random.randf_range(-10.0, 10.0)), false)
		_tree(_woodland, Vector2(x, high.y + _random.randf_range(-10.0, 10.0)), false)
		x += spacing
	var z := low.y
	while z < high.y:
		_tree(_woodland, Vector2(low.x + _random.randf_range(-10.0, 10.0), z), false)
		_tree(_woodland, Vector2(high.x + _random.randf_range(-10.0, 10.0), z), false)
		z += spacing


func _is_free(spot: Vector2, radius: float) -> bool:
	for other in _taken:
		if spot.distance_to(Vector2(other.x, other.y)) < radius + other.z:
			return false
	return true
