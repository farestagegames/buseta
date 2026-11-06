class_name LowPolyBuilder
extends RefCounted
## Collects boxes and wheels into one vertex-coloured mesh, so a whole model or
## set of props costs a single draw call on the phone.

var _surface := SurfaceTool.new()
var _has_geometry := false


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


## Standard material that takes its colour from the mesh vertices.
static func vertex_colour_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.75
	return material


func _triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, colour: Color) -> void:
	_has_geometry = true
	for point: Vector3 in [a, b, c]:
		_surface.set_color(colour)
		_surface.set_normal(normal)
		_surface.add_vertex(point)
