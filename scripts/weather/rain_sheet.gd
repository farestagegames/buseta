class_name RainSheet
extends Node3D
## Rain around the camera: one or two open cylinders with falling streaks drawn
## by a shader. They stay upright and centred on the camera, so the rain always
## surrounds the player at the cost of one transparent draw each.

const SHADER := preload("res://assets/shaders/rain.gdshader")
## Radius, spacing between streaks, streak width and opacity of each layer.
const LAYERS: Array[Dictionary] = [
	{"radius": 5.5, "spacing": 0.2, "width": 0.045, "opacity": 0.55},
	{"radius": 13.0, "spacing": 0.16, "width": 0.05, "opacity": 0.4},
]
const HEIGHT := 22.0

var camera: Camera3D

var _materials: Array[ShaderMaterial] = []
var _layers: Array[MeshInstance3D] = []
## Drawn unseen for the first frames, so the shader is built at the start of the
## shift and not with a stutter when the first drops fall.
var _warm_frames: int = 3
var _wanted: bool = false


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for layer in LAYERS:
		var mesh := CylinderMesh.new()
		mesh.top_radius = layer["radius"]
		mesh.bottom_radius = layer["radius"]
		mesh.height = HEIGHT
		mesh.radial_segments = 20
		mesh.rings = 0
		mesh.cap_top = false
		mesh.cap_bottom = false
		var material := ShaderMaterial.new()
		material.shader = SHADER
		for key: String in layer:
			material.set_shader_parameter(key, layer[key])
		mesh.material = material
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.custom_aabb = AABB(Vector3(-20.0, -15.0, -20.0), Vector3(40.0, 30.0, 40.0))
		add_child(instance)
		_layers.append(instance)
		_materials.append(material)
	visible = false


## amount 0 to 1; brightness dims the streaks after dark; layers is how many to draw.
func show_rain(amount: float, brightness: float, layers: int) -> void:
	_wanted = amount > 0.01
	visible = _wanted or _warm_frames > 0
	for i in _layers.size():
		_layers[i].visible = i < layers
		_materials[i].set_shader_parameter("amount", amount)
		_materials[i].set_shader_parameter("tint", Color(0.8, 0.84, 0.9) * brightness)
		_materials[i].set_shader_parameter("opacity", LAYERS[i]["opacity"] if _wanted else 0.0)


func _process(_dt: float) -> void:
	if _warm_frames > 0:
		_warm_frames -= 1
		visible = true
		for layer in _layers:
			layer.visible = true
		if _warm_frames == 0:
			visible = _wanted
	if visible and camera != null:
		global_position = camera.global_position
