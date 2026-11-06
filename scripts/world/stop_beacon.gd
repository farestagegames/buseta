class_name StopBeacon
extends MeshInstance3D
## Tall translucent marker over the next stop, so it can be seen from a distance.

var _ground: GroundSurface


func setup(ground: GroundSurface) -> void:
	_ground = ground
	var column := CylinderMesh.new()
	column.top_radius = 2.2
	column.bottom_radius = 2.2
	column.height = 26.0
	column.radial_segments = 10
	column.rings = 1
	column.cap_top = false
	column.cap_bottom = false
	mesh = column
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.95, 0.5, 0.2)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	GameEvents.route_status_updated.connect(_on_status)
	GameEvents.shift_completed.connect(func(_summary: Dictionary) -> void: visible = false)


func _on_status(status: Dictionary) -> void:
	var spot: Vector2 = status["stop_position"]
	global_position = Vector3(spot.x, _ground.terrain_height(spot) + 13.0, spot.y)
	visible = float(status["distance"]) > 18.0
