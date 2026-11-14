class_name CityBuilder
extends Node3D
## Turns map data into the visible city and its solid collision. Everything
## static is merged, so the whole town costs a handful of draw calls.

const GRID_CELL := 12.0
const CHUNK_SIZE := 170.0
const ZEBRA_GAP := 1.2 ## From the edge of a junction to its zebra crossing.
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
const BUSWAY := Color(0.62, 0.3, 0.24) ## Dedicated bus lanes are painted red.
const PAVEMENT := Color(0.62, 0.61, 0.59)
const KERB := Color(0.86, 0.85, 0.8)
const GUTTER := Color(0.22, 0.22, 0.24) ## A dark line where the road meets the kerb, as if it stood proud.
const LINE := Color(0.92, 0.92, 0.88)
const YELLOW := Color(0.95, 0.78, 0.18)
const TANK_BLUE := Color(0.16, 0.28, 0.48)
const TEXTURE_SEA := preload("res://assets/textures/sea.png")
const SEA_DRIFT := Vector3(0.006, 0.0, 0.004)
const FACADE_SHADER := preload("res://assets/shaders/facade.gdshader")
## Where the glass is in each wall texture (left, top, right, bottom of a pane, as
## shares of a tile), how many panes a tile holds, and how many windows are lit
## at full night, as a share of the time of day's own.
const WINDOWS := {
	"flats": {"box": Vector4(0.29, 0.16, 0.71, 0.77), "panes": 1.0, "lit": 1.0},
	"office": {"box": Vector4(0.07, 0.07, 1.0, 0.77), "panes": 2.0, "lit": 0.6},
	"shops": {"box": Vector4(0.08, 0.23, 0.98, 0.9), "panes": 1.0, "lit": 2.0},
}
## A soaked road is darker and shinier. Each is the colour it is tinted to, and
## its roughness, when fully wet.
const WET_ROAD := {"tint": Color(0.52, 0.53, 0.57), "roughness": 0.28}
const WET_PAVEMENT := {"tint": Color(0.7, 0.7, 0.72), "roughness": 0.5}
const WET_LINES := {"tint": Color(0.8, 0.8, 0.82), "roughness": 0.4}
const SHELTER_GLOW := Color(0.62, 0.56, 0.42)
## Share of windows people switch on per unit of lamp light, as under storm clouds.
const STORM_WINDOWS := 0.35
## Baked contact shade: how much darker a wall or trunk is at its foot than at its top.
const WALL_GROUND_SHADE := 0.38
const TRUNK_GROUND_SHADE := 0.45

var building_count: int = 0
## Share of windows lit at this time of day. The level sets it before the lights come on.
var window_share: float = 0.0
var lamp_spots: Array[Dictionary] = [] ## position and yaw, for ObstacleField.
## Each built landmark: kind, centre, reach, footprint (ground points it covers),
## lowest (its lowest point, buried below the ground) and floor (where people stand).
var landmarks: Array[Dictionary] = []

var theme: CityTheme
var _network: RoadNetwork
var _keep: float = 1.0 ## 1 where traffic keeps right, -1 where it keeps left.
var _sea_material: StandardMaterial3D
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
var _road_mesh: LowPolyBuilder
var _scenery_mesh: LowPolyBuilder
var _stop_spots: Array[Vector2] = []
var _signs: Array[Dictionary] = []
var _window_random := RandomNumberGenerator.new() ## Kept apart so the town's layout never changes.
var _facades: Dictionary = {} ## Kind to its ShaderMaterial.
var _wet: Array[Array] = [] ## Material, its dry roughness, and how it looks wet.
var _glow := StandardMaterial3D.new()
var _pool_material := StandardMaterial3D.new()
var _lamps_at_stops: LowPolyBuilder ## Strip lights under shelter roofs.
var _stop_pools: LowPolyBuilder ## Their pools of light on the pavement.
var _night_meshes: Array[MeshInstance3D] = []


func build(map_data: Dictionary, network: RoadNetwork, ground: GroundSurface, route: RouteRunner) -> void:
	_network = network
	theme = CityTheme.from_data(map_data)
	_keep = float(network.traffic_side)
	_ground = ground
	_height_of = ground.terrain_height
	_random.seed = 1187
	_window_random.seed = 2207
	_lamps_at_stops = LowPolyBuilder.new()
	_stop_pools = LowPolyBuilder.new()
	_solid = StaticBody3D.new()
	add_child(_solid)
	_flats = LowPolyBuilder.new()
	_office = LowPolyBuilder.new()
	_shops = LowPolyBuilder.new()
	_lines = LowPolyBuilder.new()
	_pavements = LowPolyBuilder.new()
	_woodland = LowPolyBuilder.new()
	_build_terrain()
	_build_sea()
	_road_mesh = LowPolyBuilder.new()
	_scenery_mesh = LowPolyBuilder.new()
	for builder: LowPolyBuilder in [_flats, _office, _shops, _lines, _pavements, _woodland, _road_mesh, _scenery_mesh]:
		builder.chunk_size = CHUNK_SIZE
	for stop in route.stops:
		if stop.kind != RouteStop.Kind.HAIL:
			_stop_spots.append(stop.position)
	_add_mesh(_build_roads(_road_mesh, map_data, route), _wettable(_textured(TEXTURE_ASPHALT, Vector2(8.0, 8.0)), WET_ROAD), false)
	_add_mesh(_pavements, _wettable(_textured(TEXTURE_PAVEMENT, Vector2(3.2, 3.2)), WET_PAVEMENT), false)
	_add_mesh(_lines, _wettable(LowPolyBuilder.vertex_colour_material(), WET_LINES), false)
	_add_mesh(_build_scenery(_scenery_mesh, route, map_data), LowPolyBuilder.vertex_colour_material())
	_add_mesh(_woodland, LowPolyBuilder.vertex_colour_material(), false)
	_add_mesh(_flats, _facade("flats", TEXTURE_FLATS, Vector2(STOREY, STOREY)))
	_add_mesh(_office, _facade("office", TEXTURE_OFFICE, Vector2(STOREY, STOREY)))
	_add_mesh(_shops, _facade("shops", TEXTURE_SHOPS, Vector2(SHOP_WIDTH, STOREY)))
	_build_stop_lights()
	GameEvents.lighting_changed.connect(_on_lighting)
	GameEvents.weather_updated.connect(_on_weather)


## Walls with windows that light up after dark. Each building's vertex alpha sets
## its own share of lit windows.
func _facade(kind: String, texture: Texture2D, tile_metres: Vector2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FACADE_SHADER
	material.set_shader_parameter("albedo_texture", texture)
	material.set_shader_parameter("tile_metres", tile_metres)
	material.set_shader_parameter("panes", WINDOWS[kind]["panes"])
	material.set_shader_parameter("window_box", WINDOWS[kind]["box"])
	_facades[kind] = material
	return material


func _wettable(material: StandardMaterial3D, wet_look: Dictionary) -> StandardMaterial3D:
	_wet.append([material, material.roughness, wet_look])
	return material


func _on_weather(weather: WeatherClock) -> void:
	for entry: Array in _wet:
		var material: StandardMaterial3D = entry[0]
		var wet_look: Dictionary = entry[2]
		material.albedo_color = Color.WHITE.lerp(wet_look["tint"], weather.wetness)
		material.roughness = lerpf(entry[1], wet_look["roughness"], weather.wetness)


## lights is how dark it is for lamps, 0 to 1. Windows light up with it.
func _on_lighting(lights: float, _headlights: bool) -> void:
	var windows := lights_to_windows(lights)
	for kind: String in _facades:
		var material: ShaderMaterial = _facades[kind]
		material.set_shader_parameter("night", clampf(lights * 1.3, 0.0, 1.0))
		material.set_shader_parameter("lit_share", clampf(windows * float(WINDOWS[kind]["lit"]), 0.0, 1.0))
	_glow.albedo_color = ObstacleField.GLOW_OFF.lerp(ObstacleField.GLOW_ON, clampf(lights * 1.5, 0.0, 1.0))
	_pool_material.albedo_color = Color.WHITE * clampf(lights, 0.0, 1.0)
	for mesh in _night_meshes:
		mesh.visible = lights > 0.02


## Share of windows lit: the time of day's own, or more under dark storm clouds.
func lights_to_windows(lights: float) -> float:
	return maxf(window_share, lights * STORM_WINDOWS) if lights > 0.02 else 0.0


## Strip lights under each shelter roof and a pool of light on the pavement, so a
## stop is easy to find at night. Shown only after dark.
func _build_stop_lights() -> void:
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.albedo_color = ObstacleField.GLOW_OFF
	var strips := MeshInstance3D.new()
	strips.mesh = _lamps_at_stops.build(_glow)
	strips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strips)
	_pool_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pool_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_pool_material.vertex_color_use_as_albedo = true
	_pool_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_pool_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pool_material.disable_fog = true
	_pool_material.albedo_color = Color.BLACK
	var pools := MeshInstance3D.new()
	pools.mesh = _stop_pools.build(_pool_material)
	pools.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pools.visible = false
	add_child(pools)
	_night_meshes.append(pools)


func _add_mesh(builder: LowPolyBuilder, material: Material, casts_shadow: bool = true) -> void:
	for mesh in builder.build_all(material):
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
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
	var low := _town_edges().position - Vector2.ONE * MAP_MARGIN
	var high := _town_edges().end + Vector2.ONE * (MAP_MARGIN + 180.0)
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
			var grass := theme.grass_a if (row * 7 + column * 13) % 5 < 3 else theme.grass_b
			colours[index] = grass.lerp(theme.sand, clampf(_ground.beach_share(point) * 6.0, 0.0, 1.0))
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


## The box around every road and node in town.
func _town_edges() -> Rect2:
	var edges := Rect2(_network.nodes.values()[0]["position"], Vector2.ZERO)
	for node: Dictionary in _network.nodes.values():
		edges = edges.expand(node["position"])
	for road: Dictionary in _network.roads.values():
		for point: Vector2 in road["points"]:
			edges = edges.expand(point)
	return edges


## A flat sea with slowly drifting ripples. It only needs one draw call.
func _build_sea() -> void:
	if _ground.coast_x == GroundSurface.NO_COAST:
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2(1600.0, 3000.0)
	_sea_material = StandardMaterial3D.new()
	_sea_material.albedo_color = theme.sea
	_sea_material.albedo_texture = TEXTURE_SEA
	_sea_material.uv1_scale = Vector3(60.0, 110.0, 1.0)
	_sea_material.roughness = 0.25
	_sea_material.metallic_specular = 0.7
	plane.material = _sea_material
	var sea := MeshInstance3D.new()
	sea.mesh = plane
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position = Vector3(_ground.coast_x + _ground.beach_width + 760.0, GroundSurface.SEA_LEVEL, 0.0)
	add_child(sea)


func _process(dt: float) -> void:
	if _sea_material != null:
		_sea_material.uv1_offset += SEA_DRIFT * dt


func _build_roads(b: LowPolyBuilder, map_data: Dictionary, route: RouteRunner) -> LowPolyBuilder:
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
		_ribbon(_lines, road, -RoadNetwork.ROAD_HALF_WIDTH - 0.35, RoadNetwork.ROAD_HALF_WIDTH + 0.35, LIFT_KERB, KERB)
		for side: float in [-1.0, 1.0]:
			var edge := RoadNetwork.ROAD_HALF_WIDTH * side
			_ribbon(b, road, minf(edge, edge - 0.18 * side), maxf(edge, edge - 0.18 * side), LIFT_ROAD + 0.006, GUTTER)
		var surface := BUSWAY if road["busway"] else ASPHALT
		_ribbon(b, road, -RoadNetwork.ROAD_HALF_WIDTH, RoadNetwork.ROAD_HALF_WIDTH, LIFT_ROAD, surface)
		_road_wear(b, road)
		_markings(road)
		_junction_lines(road)
	for stop in route.stops:
		if stop.kind == RouteStop.Kind.BAY:
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
		_strip(_lines, road["id"], along, along + 3.0, -0.11, 0.11, LINE)
		along += 7.0
	for lateral: float in [-3.5, 3.5]:
		var at := start_gap
		while at < length - end_gap:
			_strip(_lines, road["id"], at, minf(at + 6.0, length - end_gap), lateral - 0.09, lateral + 0.09, LINE)
			at += 6.0


## A zebra crossing where each road meets a junction, and a stop line back from it.
func _junction_lines(road: Dictionary) -> void:
	var length: float = road["length"]
	var start: Dictionary = _network.nodes[road["from"]]
	var finish: Dictionary = _network.nodes[road["to"]]
	var start_gap: float = float(start["radius"]) + ZEBRA_GAP
	var end_at: float = length - float(finish["radius"]) - ZEBRA_GAP
	var near := minf(0.1 * _keep, (RoadNetwork.ROAD_HALF_WIDTH - 0.2) * _keep)
	var far := maxf(0.1 * _keep, (RoadNetwork.ROAD_HALF_WIDTH - 0.2) * _keep)
	if start["kind"] != "terminal":
		var line_at := float(start["radius"]) + LaneGraph.STOP_LINE_GAP
		_strip(_lines, road["id"], line_at - 0.4, line_at, -far, -near, LINE)
		_zebra(road["id"], start_gap)
	if finish["kind"] != "terminal":
		var line_at := length - float(finish["radius"]) - LaneGraph.STOP_LINE_GAP
		_strip(_lines, road["id"], line_at, line_at + 0.4, near, far, LINE)
		_zebra(road["id"], end_at - 3.0)


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
	var side := float(stop.dir) * _keep
	var inner := edge * side
	var outer := (edge + depth) * side
	var walk := (edge + depth + 3.2) * side
	_strip(b, stop.road, from, to, minf(inner, outer), maxf(inner, outer), ASPHALT_PATCH, LIFT_BAY)
	_taper(b, stop.road, from, from - RoadNetwork.BAY_TAPER, inner, outer)
	_taper(b, stop.road, to, to + RoadNetwork.BAY_TAPER, inner, outer)
	_strip(_pavements, stop.road, from, to, minf(outer, walk), maxf(outer, walk), PAVEMENT, LIFT_PAVEMENT + 0.005)
	var kerb := (edge + depth + 0.1) * side
	_strip(_lines, stop.road, from, to, kerb - 0.2, kerb + 0.2, YELLOW, LIFT_BAY + 0.005)
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
	var side := -approach * _keep
	for i in 3:
		var at := along + approach * float(i) * 2.2
		var low := minf(0.15 * side, 3.4 * side)
		var high := maxf(0.15 * side, 3.4 * side)
		_strip(_lines, road_id, at, at + 0.5, low, high, YELLOW)
	var placed: Dictionary = _network.sample(road_id, along, (RoadNetwork.ROAD_HALF_WIDTH + 0.9) * side)
	var spot: Vector2 = placed["position"]
	var y := _ground.terrain_height(spot)
	_signs.append({"spot": spot, "y": y, "yaw": placed["heading"]})


func _build_scenery(b: LowPolyBuilder, route: RouteRunner, map_data: Dictionary) -> LowPolyBuilder:
	for stop in route.stops:
		_shelter(b, stop)
	_depot(b)
	_build_landmarks(b, map_data)
	for road: Dictionary in _network.roads.values():
		_line_with_buildings(b, road, 0.0)
	for road: Dictionary in _network.roads.values():
		_line_with_buildings(b, road, 24.0)
		_line_with_trees(b, road)
		_line_with_lamps(road)
		_line_with_bunting(road)
	_tree_line(b)
	_beach_palms(b)
	for sign_data: Dictionary in _signs:
		var spot: Vector2 = sign_data["spot"]
		var y: float = sign_data["y"]
		var yaw: float = sign_data["yaw"]
		b.turned_box(_at(spot, y + 1.3), Vector3(0.09, 2.6, 0.09), yaw, Color(0.25, 0.26, 0.28))
		_warning_sign(b, spot, y + 2.6, yaw)
	return b


## A diamond in Colombia. Each country's pack picks its own shape and colour.
func _warning_sign(b: LowPolyBuilder, spot: Vector2, height: float, yaw: float) -> void:
	var colour := Country.pack.colour("signage", "warning_colour", YELLOW)
	var tilt := PI / 4.0 if Country.pack.data["signage"].get("warning_shape") == "diamond" else 0.0
	b.turned_box(_at(spot, height), Vector3(0.75, 0.75, 0.05), yaw + tilt, colour)


func _shelter(b: LowPolyBuilder, stop: RouteStop) -> void:
	var forward := stop.forward()
	var right := Vector2(-forward.y, forward.x) * _keep
	var spot := stop.position + right * (RoadNetwork.BAY_DEPTH / 2.0 + 2.6)
	var y := _ground.terrain_height(spot)
	var yaw := stop.heading
	if stop.is_final or stop.kind == RouteStop.Kind.HAIL:
		return
	if stop.kind == RouteStop.Kind.STATION:
		_station(b, stop, right)
		return
	b.turned_box(Vector3(spot.x, y + 2.5, spot.y), Vector3(1.4, 0.12, 5.0), yaw, Color(0.25, 0.3, 0.38))
	_lamps_at_stops.turned_box(Vector3(spot.x, y + 2.42, spot.y), Vector3(0.3, 0.05, 4.2), yaw, Color.WHITE)
	_stop_pools.glow_disc(_at(spot, y), 4.5, SHELTER_GLOW, 16, _height_of, LIFT_PAVEMENT + 0.1)
	b.turned_box(_at(spot + right * 0.6, y + 1.3), Vector3(0.1, 2.4, 5.0), yaw, Color(0.3, 0.42, 0.5))
	for end: float in [-2.4, 2.4]:
		b.turned_box(_at(spot + forward * end, y + 1.3), Vector3(1.2, 2.4, 0.1), yaw, Color(0.3, 0.42, 0.5))
	var pole := stop.position + forward * 8.0 + right * (RoadNetwork.BAY_DEPTH / 2.0 + 0.8)
	b.turned_box(_at(pole, y + 1.6), Vector3(0.12, 3.2, 0.12), yaw, Color(0.2, 0.2, 0.25))
	b.turned_box(_at(pole, y + 3.1), Vector3(0.1, 0.7, 0.8), yaw, Country.pack.colour("signage", "bus_stop_colour", Color(0.1, 0.4, 0.8)))


## A rapid-transit platform: a long canopy on posts with a glass wall behind.
func _station(b: LowPolyBuilder, stop: RouteStop, right: Vector2) -> void:
	var forward := stop.forward()
	var yaw := stop.heading
	var spot := stop.position + right * (RoadNetwork.ROAD_HALF_WIDTH - RouteStop.STATION_LATERAL + 1.6)
	var y := _ground.terrain_height(spot)
	var teal := Color(0.08, 0.5, 0.62)
	b.turned_box(_at(spot, y + 3.4), Vector3(4.2, 0.18, 26.0), yaw, teal)
	_lamps_at_stops.turned_box(_at(spot, y + 3.3), Vector3(0.4, 0.05, 24.0), yaw, Color.WHITE)
	for along: float in [-8.0, 0.0, 8.0]:
		_stop_pools.glow_disc(_at(spot + forward * along, y), 5.0, SHELTER_GLOW, 16, _height_of, LIFT_PAVEMENT + 0.1)
	b.turned_box(_at(spot + right * 1.5, y + 1.45), Vector3(0.08, 2.5, 26.0), yaw, Color(0.6, 0.78, 0.84))
	var along := -12.5
	while along <= 12.5:
		b.turned_box(_at(spot + forward * along + right * 1.5, y + 1.7), Vector3(0.16, 3.4, 0.16), yaw, Color(0.9, 0.92, 0.94))
		along += 5.0
	var mark := spot + forward * 14.5
	b.turned_box(_at(mark, y + 2.2), Vector3(0.14, 4.4, 0.14), yaw, Color(0.2, 0.2, 0.25))
	b.turned_box(_at(mark, y + 4.5), Vector3(0.12, 1.0, 1.0), yaw, teal)
	b.turned_box(_at(mark, y + 4.5), Vector3(0.16, 0.2, 0.8), yaw, Color(0.96, 0.96, 0.9))


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


## Landmarks come from the map's "landmarks" list, each at x, z with its front
## turned towards the node named in "face". They go before the houses, so the
## houses keep clear of them, and use no random numbers, so other towns stay the same.
func _build_landmarks(b: LowPolyBuilder, map_data: Dictionary) -> void:
	for entry: Dictionary in map_data.get("landmarks", []):
		var centre := Vector2(float(entry["x"]), float(entry["z"]))
		var facing := centre + Vector2.UP
		if _network.nodes.has(entry.get("face", "")):
			facing = _network.nodes[entry["face"]]["position"]
		var forward := (facing - centre).normalized()
		var heading := atan2(-forward.x, -forward.y)
		match entry.get("kind", ""):
			"church":
				_church(b, centre, heading)
			"mirador":
				_mirador(b, centre, heading)
			"ferry":
				_ferry(b, centre, heading)


## A point on a landmark's own grid: side to its right, ahead towards its front.
func _local(centre: Vector2, heading: float, side: float, ahead: float) -> Vector2:
	var forward := Vector2(-sin(heading), -cos(heading))
	return centre + Vector2(-forward.y, forward.x) * side + forward * ahead


## Ground points across a rectangle on a landmark's grid, corners and edges.
func _footprint(centre: Vector2, heading: float, low: Vector2, high: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 5:
		for j in 5:
			points.append(_local(centre, heading, lerpf(low.x, high.x, i / 4.0), lerpf(low.y, high.y, j / 4.0)))
	return points


func _ground_range(points: PackedVector2Array) -> Vector2:
	var range_y := Vector2(INF, -INF)
	for point in points:
		var y := _ground.terrain_height(point)
		range_y = Vector2(minf(range_y.x, y), maxf(range_y.y, y))
	return range_y


## The parish church: whitewashed nave under a clay-tile roof, a bell tower with an
## open arched belfry at the front left, and a stone forecourt. No cross on it.
func _church(b: LowPolyBuilder, centre: Vector2, heading: float) -> void:
	var white := Color(0.95, 0.94, 0.9)
	var trim := Color(0.86, 0.72, 0.44)
	var tile := Color(0.72, 0.36, 0.22)
	var stone := Color(0.66, 0.64, 0.6)
	var dark := Color(0.16, 0.14, 0.13)
	var wood := Color(0.4, 0.24, 0.14)
	var footprint := _footprint(centre, heading, Vector2(-8.5, -12.0), Vector2(8.5, 15.0))
	var ground := _ground_range(footprint)
	var base := ground.y + 0.3 ## The floor is level with the highest ground; walls run down the slope.
	var below := base - ground.x + 1.2
	var at := func(side: float, y: float, ahead: float) -> Vector3:
		return _at(_local(centre, heading, side, ahead), base + y)
	# Stone plinth and forecourt steps.
	b.turned_box(at.call(0.0, -below / 2.0, 1.5), Vector3(17.0, below, 27.0), heading, stone)
	for step in 3:
		var tread := -0.15 - 0.3 * step
		b.turned_box(at.call(2.5, tread - below / 2.0, 13.5 + 0.6 * step), Vector3(6.0 - step, below, 0.6), heading, stone.darkened(0.05 * step))
	# Nave, banded at the foot and the eaves.
	var nave_side := 2.5
	b.turned_box(at.call(nave_side, 4.0, 0.0), Vector3(11.0, 8.0, 22.0), heading, white)
	b.turned_box(at.call(nave_side, 0.4, 0.0), Vector3(11.2, 0.8, 22.2), heading, trim)
	b.turned_box(at.call(nave_side, 7.8, 0.0), Vector3(11.4, 0.4, 22.4), heading, trim)
	b.gable(at.call(nave_side, 8.0, 0.0), 12.4, 23.4, 3.6, heading, tile)
	# Front: a gable end, pilasters, an arched door and a round window.
	var front := 11.05 ## Just proud of the nave's front wall.
	b.flag(at.call(nave_side - 6.0, 8.05, 11.75), at.call(nave_side + 6.0, 8.05, 11.75), at.call(nave_side, 11.45, 11.75), white) ## Whitewashed gable end.
	for pilaster: float in [-3.6, 3.6]:
		b.turned_box(at.call(nave_side + pilaster, 4.0, front + 0.1), Vector3(0.7, 8.0, 0.3), heading, trim)
	b.turned_box(at.call(nave_side, 1.8, front + 0.06), Vector3(2.4, 3.6, 0.1), heading, wood)
	b.turned_box(at.call(nave_side, 3.8, front + 0.06), Vector3(1.6, 0.5, 0.1), heading, wood)
	b.turned_box(at.call(nave_side, 4.25, front + 0.06), Vector3(0.8, 0.4, 0.1), heading, wood)
	b.turned_box(at.call(nave_side, 4.3, front + 0.12), Vector3(3.4, 0.3, 0.12), heading, trim)
	b.turned_box(at.call(nave_side, 6.3, front + 0.06), Vector3(1.2, 1.2, 0.1), heading, dark)
	b.turned_box(at.call(nave_side, 6.3, front + 0.06), Vector3(1.6, 0.6, 0.08), heading, dark)
	b.turned_box(at.call(nave_side, 6.3, front + 0.06), Vector3(0.6, 1.6, 0.08), heading, dark)
	# Tall arched windows down both sides.
	for wall: float in [-5.53, 5.53]:
		for ahead: float in [-7.0, -1.5, 4.0]:
			b.turned_box(at.call(nave_side + wall, 4.0, ahead), Vector3(0.1, 2.8, 1.2), heading, dark)
			b.turned_box(at.call(nave_side + wall, 5.55, ahead), Vector3(0.1, 0.3, 0.7), heading, dark)
	# Bell tower: shaft, cornices, open belfry with a bell, and a tiled spire.
	var tower := Vector2(-5.5, 8.5)
	var shaft := 15.0
	b.turned_box(at.call(tower.x, shaft / 2.0, tower.y), Vector3(5.0, shaft, 5.0), heading, white)
	b.turned_box(at.call(tower.x, 0.4, tower.y), Vector3(5.2, 0.8, 5.2), heading, trim)
	for band: float in [8.0, shaft]:
		b.turned_box(at.call(tower.x, band, tower.y), Vector3(5.5, 0.4, 5.5), heading, trim)
	for level: float in [3.5, 10.5]:
		b.turned_box(at.call(tower.x, level, tower.y + 2.53), Vector3(0.8, 1.4, 0.1), heading, dark)
	var belfry := shaft + 0.2
	var open := 3.6
	for corner_x: float in [-2.1, 2.1]:
		for corner_z: float in [-2.1, 2.1]:
			b.turned_box(at.call(tower.x + corner_x, belfry + open / 2.0, tower.y + corner_z), Vector3(0.8, open, 0.8), heading, white)
	# Each opening's arch: haunches either side and a keystone band across the top.
	for face in 4:
		var turn := heading + PI / 2.0 * face
		var outward := Vector2(-sin(turn), -cos(turn))
		var face_centre := _local(centre, heading, tower.x, tower.y) + outward * 2.2
		var across := Vector2(-outward.y, outward.x)
		for side: float in [-1.0, 1.0]:
			b.turned_box(_at(face_centre + across * side * 1.35, base + belfry + open - 0.55), Vector3(0.7, 0.5, 0.4), turn, white)
			b.turned_box(_at(face_centre + across * side * 1.5, base + belfry + open - 0.95), Vector3(0.4, 0.4, 0.4), turn, white)
		b.turned_box(_at(face_centre, base + belfry + open - 0.15), Vector3(3.6, 0.3, 0.4), turn, white)
	b.turned_box(at.call(tower.x, belfry + 1.9, tower.y), Vector3(1.1, 1.2, 1.1), heading, Color(0.66, 0.5, 0.22))
	b.turned_box(at.call(tower.x, belfry + 1.25, tower.y), Vector3(1.4, 0.2, 1.4), heading, Color(0.6, 0.45, 0.2))
	b.turned_box(at.call(tower.x, belfry + 2.65, tower.y), Vector3(4.2, 0.25, 0.25), heading, wood)
	b.turned_box(at.call(tower.x, belfry + open + 0.25, tower.y), Vector3(5.6, 0.5, 5.6), heading, trim)
	b.pyramid(at.call(tower.x, belfry + open + 0.5, tower.y), 5.2, 4.2, heading, tile)
	_add_solid(at.call(nave_side, 4.0, 0.0), Vector3(11.0, 14.0, 22.0), heading)
	_add_solid(at.call(tower.x, shaft / 2.0, tower.y), Vector3(5.0, shaft + 6.0, 5.0), heading)
	_record_landmark("church", centre, 16.5, footprint, base - below, base)


## The mirador: an octagonal plank deck on posts, railed all round but for the
## steps at the front, with benches looking out and a coin telescope.
func _mirador(b: LowPolyBuilder, centre: Vector2, heading: float) -> void:
	var timber := Color(0.5, 0.33, 0.2)
	var plank := Color(0.62, 0.43, 0.26)
	var plank_dark := Color(0.55, 0.37, 0.22)
	var radius := 6.5
	var sides := 8
	var corners := PackedVector2Array()
	for i in sides:
		corners.append(centre + Vector2.RIGHT.rotated(-heading - PI / 2.0 + TAU * (i + 0.5) / sides) * radius)
	var footprint := corners.duplicate()
	footprint.append(centre)
	var steps := _mirador_steps(centre, heading, radius)
	footprint.append_array(steps)
	var ground := _ground_range(footprint)
	var floor_y := ground.y + 1.6
	var lowest := ground.x - 0.6
	for i in sides:
		b.quad(_at(centre, floor_y), _at(corners[(i + 1) % sides], floor_y), _at(corners[i], floor_y), _at(corners[i], floor_y), plank_dark)
	var inner := radius * cos(PI / sides)
	var across := -inner + 0.25
	var stripe := 0
	while across < inner:
		var half := sqrt(maxf(inner * inner - across * across, 0.0)) * 0.98
		b.turned_box(_at(_local(centre, heading, across, 0.0), floor_y + 0.03), Vector3(0.44, 0.06, half * 2.0), heading, plank if stripe % 2 == 0 else plank.lightened(0.06))
		across += 0.5
		stripe += 1
	for i in sides:
		var a := corners[i]
		var c := corners[(i + 1) % sides]
		var middle := (a + c) / 2.0
		var run := c - a
		var yaw := atan2(run.x, run.y)
		b.turned_box(_at(middle, floor_y - 0.18), Vector3(0.25, 0.36, run.length()), yaw, timber)
		var post_height := floor_y + 1.1 - lowest
		b.box(_at(a, lowest + post_height / 2.0), Vector3(0.3, post_height, 0.3), timber)
		if i == sides - 1:
			continue ## The front edge is open to the steps.
		for rail: float in [0.55, 1.05]:
			b.turned_box(_at(middle, floor_y + rail), Vector3(0.12, 0.12, run.length()), yaw, timber.lightened(0.08))
		var bench := middle + (centre - middle).normalized() * 0.7
		if i in [2, 3, 4]:
			_bench(b, bench, yaw, floor_y, (middle - centre).normalized(), timber)
	var mid_height := floor_y - 0.2 - lowest
	b.box(_at(centre, lowest + mid_height / 2.0), Vector3(0.4, mid_height, 0.4), timber)
	for i in 4:
		var brace := centre.lerp(corners[i * 2], 0.5)
		b.box(_at(brace, lowest + mid_height / 2.0), Vector3(0.25, mid_height, 0.25), timber.darkened(0.1))
	for i in steps.size():
		var foot := _ground.terrain_height(steps[i])
		var tread_y := lerpf(floor_y, foot + 0.1, float(i + 1) / float(steps.size()))
		var rise := tread_y - foot + 0.4
		b.turned_box(_at(steps[i], tread_y - rise / 2.0), Vector3(2.4, rise, 0.6), heading, plank_dark)
	var scope := _local(centre, heading, 0.0, -radius * 0.55)
	b.box(_at(scope, floor_y + 0.6), Vector3(0.18, 1.2, 0.18), Color(0.3, 0.32, 0.34))
	b.turned_box(_at(scope, floor_y + 1.3), Vector3(0.3, 0.3, 0.8), heading, Color(0.22, 0.42, 0.5))
	_add_solid(_at(centre, (floor_y + lowest) / 2.0), Vector3(radius * 1.5, floor_y - lowest, radius * 1.5), heading)
	_record_landmark("mirador", centre, radius + 3.0, footprint, lowest, floor_y)


## The river ferry moored off the end of the ramp, its bow ramp let down
## towards the shore: a flat steel barge with a wheelhouse at the stern, two
## trucks' worth of cargo, rails along the sides and a canoe tied alongside.
func _ferry(b: LowPolyBuilder, centre: Vector2, heading: float) -> void:
	var hull := Color(0.2, 0.36, 0.44)
	var deck := Color(0.46, 0.45, 0.42)
	var trim := Color(0.86, 0.72, 0.2)
	var width := 9.0
	var length := 22.0
	var water := GroundSurface.SEA_LEVEL
	var deck_y := water + 0.9
	b.turned_box(_at(centre, water + 0.1), Vector3(width, 1.6, length), heading, hull)
	b.turned_box(_at(centre, deck_y + 0.03), Vector3(width - 0.4, 0.06, length - 0.4), heading, deck)
	for side: float in [-1.0, 1.0]:
		b.turned_box(_at(_local(centre, heading, side * (width / 2.0 - 0.1), 0.0), deck_y + 0.2), Vector3(0.2, 0.4, length), heading, trim)
		b.turned_box(_at(_local(centre, heading, side * (width / 2.0 - 0.1), -1.0), deck_y + 1.0), Vector3(0.08, 0.08, length - 4.0), heading, Color(0.85, 0.86, 0.84))
		for post in 5:
			var ahead := lerpf(-length / 2.0 + 2.0, length / 2.0 - 4.0, post / 4.0)
			b.turned_box(_at(_local(centre, heading, side * (width / 2.0 - 0.1), ahead), deck_y + 0.5), Vector3(0.1, 1.0, 0.1), heading, Color(0.85, 0.86, 0.84))
	# The bow ramp, let down onto the slipway.
	var bow := _local(centre, heading, 0.0, length / 2.0 + 1.6)
	b.turned_box(_at(bow, deck_y - 0.25), Vector3(width - 1.6, 0.15, 3.4), heading, trim.darkened(0.2))
	# Wheelhouse at the stern, to one side.
	var house := _local(centre, heading, -width / 2.0 + 2.0, -length / 2.0 + 2.4)
	b.turned_box(_at(house, deck_y + 1.3), Vector3(3.0, 2.6, 3.2), heading, Color(0.93, 0.92, 0.86))
	b.turned_box(_at(house, deck_y + 2.2), Vector3(3.06, 0.7, 3.26), heading, Color(0.25, 0.45, 0.6))
	b.turned_box(_at(house, deck_y + 2.7), Vector3(3.5, 0.2, 3.7), heading, Color(0.75, 0.2, 0.18))
	b.box(_at(_local(centre, heading, -width / 2.0 + 3.0, -length / 2.0 + 1.2), deck_y + 3.5), Vector3(0.3, 1.4, 0.3), Color(0.2, 0.2, 0.22))
	# Cargo: a covered truck bed and stacked plantain sacks.
	var cargo := _local(centre, heading, 1.6, 1.0)
	b.turned_box(_at(cargo, deck_y + 1.1), Vector3(2.4, 2.2, 5.5), heading, Color(0.3, 0.55, 0.32))
	b.turned_box(_at(_local(centre, heading, 1.6, 4.6), deck_y + 0.8), Vector3(2.3, 1.6, 1.8), heading, Color(0.82, 0.32, 0.22))
	for i in 3:
		b.turned_box(_at(_local(centre, heading, -2.0, 2.0 + i * 1.1), deck_y + 0.35), Vector3(1.0, 0.7, 0.9), heading, Color(0.7, 0.58, 0.36).darkened(0.05 * i))
	# A long wooden canoe tied alongside.
	var canoe := _local(centre, heading, width / 2.0 + 1.4, -3.0)
	b.turned_box(_at(canoe, water + 0.15), Vector3(1.1, 0.5, 8.0), heading, Color(0.45, 0.28, 0.16))
	b.turned_box(_at(canoe, water + 0.42), Vector3(0.9, 0.06, 7.0), heading, Color(0.6, 0.42, 0.25))
	b.turned_box(_at(_local(centre, heading, width / 2.0 + 1.4, -6.6), water + 0.6), Vector3(0.4, 0.5, 0.5), heading, Color(0.2, 0.2, 0.22))
	# The hull only: the let-down ramp reaches the slipway on purpose.
	var corners := _footprint(centre, heading, Vector2(-width / 2.0, -length / 2.0), Vector2(width / 2.0, length / 2.0))
	_add_solid(_at(centre, deck_y), Vector3(width, 2.4, length), heading)
	_record_landmark("ferry", centre, length / 2.0 + 4.0, corners, water - 0.7, deck_y)


## Treads leading from the deck's open front edge down towards the road.
func _mirador_steps(centre: Vector2, heading: float, radius: float) -> PackedVector2Array:
	var steps := PackedVector2Array()
	var edge := radius * cos(PI / 8.0)
	for i in 4:
		steps.append(_local(centre, heading, 0.0, edge + 0.3 + 0.6 * i))
	return steps


## A slatted bench facing out from the deck.
func _bench(b: LowPolyBuilder, spot: Vector2, yaw: float, floor_y: float, outward: Vector2, timber: Color) -> void:
	b.turned_box(_at(spot, floor_y + 0.45), Vector3(0.5, 0.08, 1.8), yaw, timber.lightened(0.12))
	b.turned_box(_at(spot - outward * 0.24, floor_y + 0.75), Vector3(0.06, 0.4, 1.8), yaw, timber.lightened(0.12))
	for end: float in [-0.75, 0.75]:
		var leg := spot + Vector2(sin(yaw), cos(yaw)) * end
		b.box(_at(leg, floor_y + 0.22), Vector3(0.1, 0.44, 0.1), timber)


func _record_landmark(kind: String, centre: Vector2, reach: float, footprint: PackedVector2Array, lowest: float, floor_y: float) -> void:
	_taken.append(Vector3(centre.x, centre.y, reach))
	landmarks.append({"kind": kind, "centre": centre, "reach": reach, "footprint": footprint, "lowest": lowest, "floor": floor_y})


func _line_with_buildings(b: LowPolyBuilder, road: Dictionary, set_back: float) -> void:
	var length: float = road["length"]
	for side: float in [-1.0, 1.0]:
		var along := _random.randf_range(32.0, 48.0)
		while along < length - 32.0:
			var width := _random.randf_range(theme.width_low, theme.width_high)
			var depth := _random.randf_range(11.0, 17.0)
			var lateral := (PAVEMENT_OUTER + theme.street_gap + set_back + depth / 2.0) * side
			var placed: Dictionary = _network.sample(road["id"], along, lateral, 1)
			var forward: Vector2 = placed["forward"]
			var to_road := Vector2(-forward.y, forward.x) * -side
			if _try_building(b, placed["position"], placed["heading"], width, depth, to_road, set_back == 0.0):
				building_count += 1
			along += width + _random.randf_range(theme.gap_low, theme.gap_high)


func _try_building(b: LowPolyBuilder, centre: Vector2, heading: float, width: float, depth: float, to_road: Vector2, on_street: bool) -> bool:
	var forward := Vector2(-sin(heading), -cos(heading))
	var right := Vector2(-forward.y, forward.x)
	var clear := GroundSurface.PAVEMENT_WIDTH + minf(theme.street_gap, 1.0) - 0.05
	var lowest := INF
	for along_share: float in [-0.5, 0.0, 0.5]:
		for across_share: float in [-0.5, 0.0, 0.5]:
			var corner := centre + forward * width * along_share + right * depth * across_share
			if _network.edge_distance(corner) < clear or _ground.beach_share(corner) > 0.0:
				return false
			lowest = minf(lowest, _ground.terrain_height(corner))
	var reach := depth * 0.55
	if not _is_free(centre, reach):
		return false
	_taken.append(Vector3(centre.x, centre.y, reach))

	var kind := _random.randf()
	if kind < theme.house_share:
		_house(b, centre, heading, width, depth, lowest)
	elif kind < 1.0 - theme.office_share:
		var storeys := _random.randi_range(theme.lowest_storeys, theme.highest_storeys)
		_block(b, _flats, centre, heading, width, depth, lowest, storeys, to_road, on_street)
	else:
		_block(b, _office, centre, heading, width, depth, lowest, theme.highest_storeys + _random.randi_range(1, 3), to_road, on_street)
	return true


func _house(b: LowPolyBuilder, centre: Vector2, heading: float, width: float, depth: float, base: float) -> void:
	var size := Vector3(minf(depth, 11.0), STOREY * 2.0, minf(width, 15.0))
	var wall := _pick(theme.walls)
	_walls(_flats, centre, size, heading, base, wall)
	_trims(b, centre, heading, size, base, wall, 2, false)
	var roof := _pick(theme.roofs)
	b.turned_box(_at(centre, base + size.y + 0.08), Vector3(size.x + 0.9, 0.16, size.z + 0.9), heading, roof.darkened(0.3))
	b.gable(_at(centre, base + size.y + 0.16), size.x + 0.7, size.z + 0.7, 3.2, heading, roof)
	if theme.chimneys:
		var chimney := centre + Vector2(-sin(heading), -cos(heading)) * size.z * 0.3
		b.turned_box(_at(chimney, base + size.y + 2.4), Vector3(0.7, 2.2, 0.7), heading, Color(0.5, 0.35, 0.3))
	_add_solid(_at(centre, base + size.y / 2.0), size + Vector3(0.0, 6.0, 0.0), heading)


func _block(b: LowPolyBuilder, facade: LowPolyBuilder, centre: Vector2, heading: float, width: float, depth: float, base: float, storeys: int, to_road: Vector2, on_street: bool) -> void:
	var height := float(storeys) * STOREY
	var size := Vector3(depth, height, width)
	var wall := _pick(theme.walls)
	if facade == _office:
		wall = wall.lerp(Color.WHITE, 0.6)
	_walls(facade, centre, size, heading, base, wall)
	_trims(b, centre, heading, size, base, wall, storeys, true)
	var parapet := wall.darkened(0.25)
	b.turned_box(_at(centre, base + height + 0.2), Vector3(depth + 0.7, 0.24, width + 0.7), heading, wall.lightened(0.3))
	b.turned_box(_at(centre, base + height + 0.5), Vector3(depth + 0.3, 0.6, width + 0.3), heading, parapet)
	b.turned_box(_at(centre, base + height + 0.82), Vector3(depth + 0.42, 0.1, width + 0.42), heading, parapet.lightened(0.2))
	b.turned_box(_at(centre, base + height + 0.52), Vector3(depth - 0.4, 0.06, width - 0.4), heading, Color(0.3, 0.3, 0.32))
	for i in _random.randi_range(1, 3):
		var unit := centre + Vector2(_random.randf_range(-3.0, 3.0), _random.randf_range(-3.0, 3.0))
		b.turned_box(_at(unit, base + height + 1.0), Vector3(1.6, 1.0, 1.2), heading, Color(0.6, 0.6, 0.62))
	if not theme.chimneys:
		var tank := centre + Vector2(_random.randf_range(-2.0, 2.0), _random.randf_range(-2.0, 2.0))
		b.turned_box(_at(tank, base + height + 1.1), Vector3(1.3, 1.2, 1.3), heading, TANK_BLUE)
	if on_street and _random.randf() < 0.65:
		_shopfront(b, centre, heading, size, base, to_road)
	if on_street and storeys > 1:
		_balcony(b, centre, heading, size, base, to_road, wall)
	_add_solid(_at(centre, base + height / 2.0), size + Vector3(0.0, 6.0, 0.0), heading)


## Chunky toy trims on a building: a darker plinth at street level, a ledge at
## each storey line and square pilasters at the corners (blocks only). They take
## no random numbers, so the town's layout never changes.
func _trims(b: LowPolyBuilder, centre: Vector2, heading: float, size: Vector3, base: float, wall: Color, storeys: int, pilasters: bool) -> void:
	var plinth := wall.darkened(0.32)
	plinth.a = 1.0
	b.turned_box(_at(centre, base + 0.2), Vector3(size.x + 0.24, 1.4, size.z + 0.24), heading, plinth)
	var ledge := wall.lightened(0.28)
	ledge.a = 1.0
	for storey in range(1, storeys):
		b.turned_box(_at(centre, base + STOREY * storey - 0.06), Vector3(size.x + 0.22, 0.16, size.z + 0.22), heading, ledge)
	if not pilasters:
		return
	var post := wall.darkened(0.1)
	post.a = 1.0
	for side: float in [-0.5, 0.5]:
		for ahead: float in [-0.5, 0.5]:
			var corner := _local(centre, heading, (size.x - 0.3) * side, (size.z - 0.3) * ahead)
			b.turned_box(_at(corner, base + size.y / 2.0 - 0.3), Vector3(0.62, size.y + 0.6, 0.62), heading, post)


## Walls run a metre below the lowest corner, so they never float on a slope.
## The vertex alpha carries the building's own share of lit windows at night.
func _walls(facade: LowPolyBuilder, centre: Vector2, size: Vector3, heading: float, base: float, colour: Color) -> void:
	facade.uv_base_height = base + size.y
	var depth_below := 1.2
	colour.a = _window_random.randf()
	facade.bottom_shade = WALL_GROUND_SHADE
	facade.turned_box(_at(centre, base + (size.y - depth_below) / 2.0), Vector3(size.x, size.y + depth_below, size.z), heading, colour)
	facade.bottom_shade = 0.0


## A slab with a low wall across the front of the first floor, for the heat.
func _balcony(b: LowPolyBuilder, centre: Vector2, heading: float, size: Vector3, base: float, to_road: Vector2, wall: Color) -> void:
	var front := centre + to_road * (size.x / 2.0 + 0.5)
	var y := base + STOREY + 0.2
	b.turned_box(_at(front, y), Vector3(1.0, 0.12, size.z * 0.7), heading, wall.lightened(0.25))
	b.turned_box(_at(front + to_road * 0.46, y + 0.5), Vector3(0.08, 0.9, size.z * 0.7), heading, _pick(theme.awnings))


func _pick(colours: Array[Color]) -> Color:
	return colours[_random.randi_range(0, colours.size() - 1)]


func _shopfront(b: LowPolyBuilder, centre: Vector2, heading: float, size: Vector3, base: float, to_road: Vector2) -> void:
	var front := centre + to_road * (size.x / 2.0 + 0.04)
	_shops.uv_base_height = base + STOREY
	var tint := Color(1.0, 1.0, 1.0).lerp(_pick(theme.awnings), 0.35)
	tint.a = _window_random.randf_range(0.5, 1.0)
	_shops.turned_box(_at(front, base + STOREY / 2.0 - 0.6), Vector3(0.1, STOREY + 1.2, size.z - 0.5), heading, tint)
	var awning := centre + to_road * (size.x / 2.0 + 0.7)
	b.turned_box(_at(awning, base + 2.75), Vector3(1.3, 0.14, size.z - 1.0), heading, _pick(theme.awnings))


func _line_with_trees(b: LowPolyBuilder, road: Dictionary) -> void:
	var length: float = road["length"]
	for side: float in [-1.0, 1.0]:
		var along := _random.randf_range(34.0, 50.0)
		var from_edge := RoadNetwork.ROAD_HALF_WIDTH + 1.5 if theme.trees_on_pavement else PAVEMENT_OUTER + 1.2
		var clear := 1.2 if theme.trees_on_pavement else 3.1
		while along < length - 34.0:
			var placed: Dictionary = _network.sample(road["id"], along, from_edge * side, 1)
			var spot: Vector2 = placed["position"]
			if _network.edge_distance(spot) > clear and _clear_of_stops(spot) and _is_free(spot, 1.0):
				_street_tree(b, spot)
			along += _random.randf_range(22.0, 40.0)


func _street_tree(b: LowPolyBuilder, spot: Vector2) -> void:
	if _random.randf() < theme.palm_share:
		_palm(b, spot, true)
	else:
		_tree(b, spot, true)


func _palm(b: LowPolyBuilder, spot: Vector2, solid: bool) -> void:
	var y := _ground.terrain_height(spot)
	var height := _random.randf_range(6.0, 10.0)
	var lean := Vector2(_random.randf_range(-1.0, 1.0), _random.randf_range(-1.0, 1.0))
	b.palm(Vector3(spot.x, y, spot.y), height, lean, theme.palm_trunk, theme.palm_leaf, _random)
	if solid:
		_add_solid(Vector3(spot.x, y + 2.0, spot.y), Vector3(0.45, 6.0, 0.45), 0.0)


## Strings of little flags across the street.
func _line_with_bunting(road: Dictionary) -> void:
	if theme.bunting_every <= 0.0:
		return
	var along := 60.0
	var length: float = road["length"]
	while along < length - 50.0:
		_bunting(road["id"], along)
		along += theme.bunting_every * _random.randf_range(0.8, 1.3)


func _bunting(road_id: String, along: float) -> void:
	var from: Vector2 = _network.sample(road_id, along, -RoadNetwork.ROAD_HALF_WIDTH - 2.5)["position"]
	var to: Vector2 = _network.sample(road_id, along, RoadNetwork.ROAD_HALF_WIDTH + 2.5)["position"]
	var top := _ground.terrain_height(from) + 6.6
	var pieces := 12
	for i in pieces:
		var start := float(i) / float(pieces)
		var finish := float(i + 1) / float(pieces)
		var sag := 0.9 * (1.0 - pow(2.0 * start - 1.0, 2.0))
		var a := from.lerp(to, start)
		var b := from.lerp(to, finish)
		var c := from.lerp(to, (start + finish) / 2.0)
		_lines.flag(_at(a, top - sag), _at(b, top - sag), _at(c, top - sag - 0.55), _pick(theme.bunting))


## Palms along the sand, between the seafront and the water.
func _beach_palms(b: LowPolyBuilder) -> void:
	if _ground.coast_x == GroundSurface.NO_COAST:
		return
	var edges := _town_edges()
	var z := edges.position.y - 40.0
	while z < edges.end.y + 40.0:
		_palm(b, Vector2(_ground.coast_x + _random.randf_range(-6.0, 14.0), z), false)
		z += _random.randf_range(9.0, 19.0)


func _tree(b: LowPolyBuilder, spot: Vector2, solid: bool) -> void:
	var y := _ground.terrain_height(spot)
	var scale := _random.randf_range(0.8, 1.35)
	var colour := _pick(theme.leaves)
	b.bottom_shade = TRUNK_GROUND_SHADE
	b.box(Vector3(spot.x, y + 1.4 * scale, spot.y), Vector3(0.32, 2.8, 0.32) * scale, Color(0.32, 0.24, 0.18))
	b.bottom_shade = 0.0
	b.crown(Vector3(spot.x, y + 4.0 * scale, spot.y), Vector3(2.3, 2.2, 2.3) * scale, colour, _random)
	b.crown(Vector3(spot.x + 0.9, y + 5.0 * scale, spot.y - 0.5), Vector3(1.5, 1.5, 1.5) * scale, colour.lightened(0.08), _random)
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
	var low := _town_edges().position - Vector2.ONE * 110.0
	var high := _town_edges().end + Vector2.ONE * 150.0
	var spacing := 24.0
	var x := low.x
	while x < high.x:
		_edge_tree(Vector2(x, low.y + _random.randf_range(-10.0, 10.0)))
		_edge_tree(Vector2(x, high.y + _random.randf_range(-10.0, 10.0)))
		x += spacing
	var z := low.y
	while z < high.y:
		_edge_tree(Vector2(low.x + _random.randf_range(-10.0, 10.0), z))
		_edge_tree(Vector2(high.x + _random.randf_range(-10.0, 10.0), z))
		z += spacing


## The edge of town needs hiding everywhere except on the beach.
func _edge_tree(spot: Vector2) -> void:
	if _ground.beach_share(spot) > 0.0:
		return
	if _random.randf() < theme.palm_share:
		_palm(_woodland, spot, false)
	else:
		_tree(_woodland, spot, false)


func _is_free(spot: Vector2, radius: float) -> bool:
	for other in _taken:
		if spot.distance_to(Vector2(other.x, other.y)) < radius + other.z:
			return false
	return true
