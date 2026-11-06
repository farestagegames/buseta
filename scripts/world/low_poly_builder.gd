class_name LowPolyBuilder
extends RefCounted
## Collects boxes and wheels into one vertex-coloured mesh, so a whole model or
## set of props costs a single draw call on the phone.

## Set above zero, geometry is split into square cells this many metres wide, so
## the phone only draws the parts of town the camera can see.
var chunk_size: float = 0.0

var _surface := SurfaceTool.new()
var _has_geometry := false
var _chunks: Dictionary = {} ## Cell to SurfaceTool.
## Height where wall textures start, so storeys line up with the ground.
var uv_base_height: float = 0.0


func _init() -> void:
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)


func box(centre: Vector3, size: Vector3, colour: Color) -> void:
	var half := size / 2.0
	for normal: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u := Vector3(normal.y, normal.z, normal.x)
		var v := normal.cross(u)
		var a := centre + (normal - u - v) * half
		var b := centre + (normal + u - v) * half
		var c := centre + (normal + u + v) * half
		var d := centre + (normal - u + v) * half
		_triangle(a, c, b, normal, colour)
		_triangle(a, d, c, normal, colour)


## A box turned around the vertical axis. yaw follows bus heading.
func turned_box(centre: Vector3, size: Vector3, yaw: float, colour: Color) -> void:
	var half := size / 2.0
	var basis := Basis(Vector3.UP, yaw)
	for normal: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u := Vector3(normal.y, normal.z, normal.x)
		var v := normal.cross(u)
		var a := centre + basis * ((normal - u - v) * half)
		var b := centre + basis * ((normal + u - v) * half)
		var c := centre + basis * ((normal + u + v) * half)
		var d := centre + basis * ((normal - u + v) * half)
		var facing := basis * normal
		_triangle(a, c, b, facing, colour)
		_triangle(a, d, c, facing, colour)


## A flat-shaded quad facing up. Corners run anticlockwise seen from above.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
	_triangle(a, c, b, Vector3.UP, colour)
	_triangle(a, d, c, Vector3.UP, colour)


## A flat disc facing up. height_of gives the height at each rim point.
func disc(centre: Vector2, radius: float, lift: float, height_of: Callable, colour: Color, sides: int = 24) -> void:
	var middle := Vector3(centre.x, float(height_of.call(centre)) + lift, centre.y)
	for i in sides:
		var p0 := centre + Vector2.RIGHT.rotated(TAU * i / sides) * radius
		var p1 := centre + Vector2.RIGHT.rotated(TAU * (i + 1) / sides) * radius
		_triangle(middle, Vector3(p0.x, float(height_of.call(p0)) + lift, p0.y),
			Vector3(p1.x, float(height_of.call(p1)) + lift, p1.y), Vector3.UP, colour)


## A rough rounded lump, for tree crowns and hedges. Eight faces per half.
func blob(centre: Vector3, size: Vector3, colour: Color, random: RandomNumberGenerator) -> void:
	var sides := 6
	var rings: Array[Array] = []
	for level: float in [-0.75, 0.05, 0.8]:
		var ring: Array[Vector3] = []
		var reach := sqrt(1.0 - level * level)
		for i in sides:
			var angle := TAU * (float(i) + 0.5 * (level + 1.0)) / sides
			var wobble := random.randf_range(0.85, 1.15)
			ring.append(centre + Vector3(cos(angle) * reach * wobble, level, sin(angle) * reach * wobble) * size)
		rings.append(ring)
	var top := centre + Vector3.UP * size.y * 1.05
	var bottom := centre - Vector3.UP * size.y * 0.95
	for i in sides:
		var j := (i + 1) % sides
		_facet(top, rings[2][i], rings[2][j], colour)
		_facet(bottom, rings[0][j], rings[0][i], colour.darkened(0.2))
		for level in 2:
			var shade := colour.darkened(0.12) if level == 0 else colour
			_facet(rings[level][i], rings[level + 1][j], rings[level + 1][i], shade)
			_facet(rings[level][i], rings[level][j], rings[level + 1][j], shade)


func _facet(a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	_triangle(a, b, c, normal, colour)


## A gable roof on a rectangle. The ridge runs along the local Z axis.
func gable(centre: Vector3, width: float, length: float, rise: float, yaw: float, colour: Color) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var half_w := width / 2.0
	var half_l := length / 2.0
	var corner := func(x: float, y: float, z: float) -> Vector3: return centre + basis * Vector3(x, y, z)
	var a: Vector3 = corner.call(-half_w, 0.0, -half_l)
	var b: Vector3 = corner.call(half_w, 0.0, -half_l)
	var c: Vector3 = corner.call(half_w, 0.0, half_l)
	var d: Vector3 = corner.call(-half_w, 0.0, half_l)
	var ridge_front: Vector3 = corner.call(0.0, rise, -half_l)
	var ridge_back: Vector3 = corner.call(0.0, rise, half_l)
	_facet(a, ridge_back, d, colour)
	_facet(a, ridge_front, ridge_back, colour)
	_facet(b, c, ridge_back, colour.darkened(0.1))
	_facet(b, ridge_back, ridge_front, colour.darkened(0.1))
	_facet(a, b, ridge_front, colour.darkened(0.05))
	_facet(d, ridge_back, c, colour.darkened(0.05))


## A cylinder lying along the X axis. Alternate hub segments make rolling visible.
func wheel(centre: Vector3, radius: float, width: float, tyre: Color, hub: Color, sides: int = 12) -> void:
	var half := width / 2.0
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(0.0, cos(a0), sin(a0)) * radius
		var p1 := Vector3(0.0, cos(a1), sin(a1)) * radius
		var left := centre + Vector3(-half, 0.0, 0.0)
		var right := centre + Vector3(half, 0.0, 0.0)
		var normal := Vector3(0.0, cos((a0 + a1) / 2.0), sin((a0 + a1) / 2.0))
		_triangle(left + p0, left + p1, right + p1, normal, tyre)
		_triangle(left + p0, right + p1, right + p0, normal, tyre)
		var face := hub if i % 2 == 0 else tyre
		_triangle(right, right + p1 * 0.6, right + p0 * 0.6, Vector3.RIGHT, face)
		_triangle(right + p0 * 0.6, right + p1 * 0.6, right + p1, Vector3.RIGHT, tyre)
		_triangle(right + p0 * 0.6, right + p1, right + p0, Vector3.RIGHT, tyre)
		_triangle(left, left + p0 * 0.6, left + p1 * 0.6, Vector3.LEFT, face)
		_triangle(left + p0 * 0.6, left + p1, left + p1 * 0.6, Vector3.LEFT, tyre)
		_triangle(left + p0 * 0.6, left + p0, left + p1, Vector3.LEFT, tyre)


func build(material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _has_geometry:
		_surface.set_material(material)
		_surface.commit(mesh)
	return mesh


## One mesh per occupied cell, or a single mesh if chunking is off.
func build_all(material: Material) -> Array[ArrayMesh]:
	var meshes: Array[ArrayMesh] = []
	if chunk_size <= 0.0:
		meshes.append(build(material))
		return meshes
	for surface: SurfaceTool in _chunks.values():
		var mesh := ArrayMesh.new()
		surface.set_material(material)
		surface.commit(mesh)
		meshes.append(mesh)
	return meshes


## Standard material that takes its colour from the mesh vertices.
static func vertex_colour_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.75
	return material


func _triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, colour: Color) -> void:
	_has_geometry = true
	var surface := _surface_for((a + b + c) / 3.0)
	for point: Vector3 in [a, b, c]:
		surface.set_color(colour)
		surface.set_normal(normal)
		surface.set_uv(_world_uv(point, normal))
		surface.add_vertex(point)


func _surface_for(point: Vector3) -> SurfaceTool:
	if chunk_size <= 0.0:
		return _surface
	var cell := Vector2i(int(floor(point.x / chunk_size)), int(floor(point.z / chunk_size)))
	if not _chunks.has(cell):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_chunks[cell] = surface
	return _chunks[cell]


## UVs in metres, so textures keep their real size on any shape. Flat surfaces
## map from above and walls wrap around horizontally.
func _world_uv(point: Vector3, normal: Vector3) -> Vector2:
	if absf(normal.y) > 0.6:
		return Vector2(point.x, point.z)
	var along := Vector2(-normal.z, normal.x).normalized()
	return Vector2(point.x * along.x + point.z * along.y, uv_base_height - point.y)
