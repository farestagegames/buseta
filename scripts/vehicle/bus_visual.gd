class_name BusVisual
extends Node3D
## Procedural low-poly bus. Reads telemetry to move wheels, doors, lamps and the
## sprung body. It has no effect on the simulation.

const FLOOR_Y := 0.42
const SKIRT_BOTTOM := 0.42
const BELT_Y := 1.3
const DOOR_WIDTH := 1.25
const DOOR_OFFSET := 0.3 ## Doorway start, measured back from the nose.
const DOOR_SWING := deg_to_rad(105.0)
const STEERING_WHEEL_TURNS := 3.0

const DARK := Color(0.1, 0.1, 0.12)
const TRIM := Color(0.26, 0.27, 0.3)
const SEAT := Color(0.15, 0.25, 0.5)
const LAMP_OFF_RED := Color(0.35, 0.05, 0.05)
const LAMP_OFF_AMBER := Color(0.45, 0.25, 0.05)

@export var spec: BusSpec

var cockpit_anchor: Node3D

var _body: Node3D
var _steering_wheel: Node3D
var _front_wheels: Array[Node3D] = []
var _wheel_pivots: Array[Node3D] = [] ## Front left, front right, rear left, rear right.
var _spinners: Array[Node3D] = []
var _door_front: Node3D
var _door_rear: Node3D
var _brake_lamps: MeshInstance3D
var _left_lamps: MeshInstance3D
var _right_lamps: MeshInstance3D
var _wheel_spin: float = 0.0
var _front_z: float
var _rear_z: float
var _half_width: float
var _top_y: float
var _door_near_z: float
var _door_far_z: float


func _ready() -> void:
	_front_z = -(spec.wheelbase + spec.front_overhang)
	_rear_z = spec.rear_overhang
	_half_width = spec.body_width / 2.0
	_top_y = spec.body_height - 0.22
	_door_near_z = _front_z + DOOR_OFFSET
	_door_far_z = _door_near_z + DOOR_WIDTH

	_body = Node3D.new()
	add_child(_body)
	_build_shell()
	_build_glass()
	_build_cockpit()
	_build_wheels()
	_build_doors()
	_build_lamps()
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)


func door_swing_angle() -> float:
	return _door_front.rotation.y


func _on_telemetry(data: BusTelemetry) -> void:
	_body.rotation = Vector3(data.body_pitch + data.ground_pitch, 0.0, -data.body_roll - data.ground_roll)
	for i in 4:
		_wheel_pivots[i].position.y = data.wheel_heights[i] - data.body_height + spec.wheel_radius
	_steering_wheel.rotation.y = -data.steer_angle * STEERING_WHEEL_TURNS
	for wheel in _front_wheels:
		wheel.rotation.y = -data.steer_angle
	_wheel_spin = fmod(_wheel_spin - data.speed * get_physics_process_delta_time() / spec.wheel_radius, TAU)
	for spinner in _spinners:
		spinner.rotation.x = _wheel_spin
	var swing := data.door_open_amount * DOOR_SWING * float(spec.door_side)
	_door_front.rotation.y = swing
	_door_rear.rotation.y = -swing
	_brake_lamps.visible = data.brake > 0.05
	_left_lamps.visible = data.indicator_lamp_on and data.indicator_side < 0
	_right_lamps.visible = data.indicator_lamp_on and data.indicator_side > 0


func _build_shell() -> void:
	var b := LowPolyBuilder.new()
	var paint := spec.body_colour
	var stripe := spec.stripe_colour
	var length := spec.overall_length()
	var mid_z := (_front_z + _rear_z) / 2.0
	var door_x := _half_width * spec.door_side
	var wall_x := _half_width - 0.04

	# Roof, floor, and solid ends.
	b.box(Vector3(0.0, spec.body_height - 0.11, mid_z), Vector3(spec.body_width, 0.22, length), paint)
	b.box(Vector3(0.0, FLOOR_Y, mid_z), Vector3(spec.body_width - 0.1, 0.06, length - 0.1), TRIM)
	b.box(Vector3(0.0, (SKIRT_BOTTOM + 1.65) / 2.0, _rear_z - 0.04), Vector3(spec.body_width, 1.65 - SKIRT_BOTTOM, 0.08), paint)
	b.box(Vector3(0.0, (SKIRT_BOTTOM + 1.15) / 2.0, _front_z + 0.04), Vector3(spec.body_width, 1.15 - SKIRT_BOTTOM, 0.08), paint)

	# Lower side panels, with the door gap left open on the door side.
	_side_band(b, -door_x, wall_x, SKIRT_BOTTOM, BELT_Y, _front_z, _rear_z, paint)
	_side_band(b, door_x, wall_x, SKIRT_BOTTOM, BELT_Y, _front_z, _door_near_z, paint)
	_side_band(b, door_x, wall_x, SKIRT_BOTTOM, BELT_Y, _door_far_z, _rear_z, paint)
	_side_band(b, -door_x, _half_width, 1.16, 1.3, _front_z, _rear_z, stripe)
	_side_band(b, door_x, _half_width, 1.16, 1.3, _door_far_z, _rear_z, stripe)

	# Window pillars.
	var z := _door_far_z
	while z < _rear_z:
		for side: float in [-1.0, 1.0]:
			b.box(Vector3(side * wall_x, (BELT_Y + _top_y) / 2.0, z), Vector3(0.09, _top_y - BELT_Y, 0.14), paint)
		z += 1.9
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * wall_x, (BELT_Y + _top_y) / 2.0, _front_z + 0.05), Vector3(0.09, _top_y - BELT_Y, 0.1), paint)
	b.box(Vector3(signf(door_x) * wall_x, (BELT_Y + _top_y) / 2.0, _door_near_z), Vector3(0.09, _top_y - BELT_Y, 0.14), paint)

	# Bumpers, destination board, headlamps, wheel arches.
	b.box(Vector3(0.0, 0.52, _front_z - 0.03), Vector3(spec.body_width + 0.02, 0.26, 0.1), DARK)
	b.box(Vector3(0.0, 0.52, _rear_z + 0.03), Vector3(spec.body_width + 0.02, 0.26, 0.1), DARK)
	b.box(Vector3(0.0, _top_y - 0.1, _front_z + 0.02), Vector3(1.9, 0.26, 0.04), Color(0.95, 0.6, 0.1))
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 0.95, 0.82, _front_z - 0.005), Vector3(0.36, 0.16, 0.03), Color(0.95, 0.95, 0.85))
		for axle_z: float in [0.0, -spec.wheelbase]:
			b.box(Vector3(side * wall_x, 0.68, axle_z), Vector3(0.1, 0.56, 1.3), DARK)

	# Saloon seats, so the windows are not looking at an empty box.
	var row_z := _door_far_z + 0.5
	while row_z < _rear_z - 0.8:
		for x: float in [-0.95, -0.5, 0.5, 0.95]:
			b.box(Vector3(x, 0.72, row_z), Vector3(0.4, 0.5, 0.42), SEAT)
			b.box(Vector3(x, 1.12, row_z + 0.18), Vector3(0.4, 0.55, 0.08), SEAT)
		row_z += 0.95

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = b.build(LowPolyBuilder.vertex_colour_material())
	_body.add_child(mesh_instance)


func _side_band(b: LowPolyBuilder, side: float, x: float, y0: float, y1: float, z0: float, z1: float, colour: Color) -> void:
	var size := Vector3(0.09, y1 - y0, z1 - z0)
	b.box(Vector3(signf(side) * x, (y0 + y1) / 2.0, (z0 + z1) / 2.0), size, colour)


func _build_glass() -> void:
	var b := LowPolyBuilder.new()
	var tint := Color(0.5, 0.65, 0.75, 0.28)
	var band_height := _top_y - BELT_Y
	var band_y := (BELT_Y + _top_y) / 2.0
	var door_x := _half_width * spec.door_side
	var pane_x := _half_width - 0.05
	var full_length := _rear_z - _front_z
	b.box(Vector3(-signf(door_x) * pane_x, band_y, (_front_z + _rear_z) / 2.0), Vector3(0.03, band_height, full_length), tint)
	b.box(Vector3(signf(door_x) * pane_x, band_y, (_door_far_z + _rear_z) / 2.0), Vector3(0.03, band_height, _rear_z - _door_far_z), tint)
	b.box(Vector3(signf(door_x) * pane_x, band_y, (_front_z + _door_near_z) / 2.0), Vector3(0.03, band_height, _door_near_z - _front_z), tint)
	b.box(Vector3(0.0, (1.15 + _top_y) / 2.0, _front_z + 0.05), Vector3(spec.body_width - 0.1, _top_y - 1.15, 0.03), tint)

	b.box(Vector3(0.0, (1.65 + _top_y) / 2.0, _rear_z - 0.05), Vector3(spec.body_width - 0.1, _top_y - 1.65, 0.03), tint)

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.15
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = b.build(material)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mesh_instance)


func _build_cockpit() -> void:
	var x := spec.driver_seat_x
	var b := LowPolyBuilder.new()
	b.box(Vector3(0.0, 1.05, _front_z + 0.42), Vector3(spec.body_width - 0.15, 0.2, 0.7), TRIM)
	b.box(Vector3(x, 0.72, _front_z + 1.75), Vector3(0.55, 0.5, 0.5), DARK)
	b.box(Vector3(x, 1.3, _front_z + 2.0), Vector3(0.55, 0.9, 0.1), DARK)
	var dash := MeshInstance3D.new()
	dash.mesh = b.build(LowPolyBuilder.vertex_colour_material())
	_body.add_child(dash)

	var tilt := Node3D.new()
	tilt.position = Vector3(x, 1.38, _front_z + 0.9)
	tilt.rotation.x = deg_to_rad(55.0)
	_body.add_child(tilt)
	_steering_wheel = Node3D.new()
	tilt.add_child(_steering_wheel)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.2
	rim.outer_radius = 0.24
	rim.rings = 16
	rim.ring_segments = 6
	var rim_instance := MeshInstance3D.new()
	rim_instance.mesh = rim
	rim_instance.material_override = _flat_material(DARK)
	_steering_wheel.add_child(rim_instance)
	var spoke := MeshInstance3D.new()
	var spoke_mesh := BoxMesh.new()
	spoke_mesh.size = Vector3(0.42, 0.02, 0.05)
	spoke.mesh = spoke_mesh
	spoke.material_override = rim_instance.material_override
	_steering_wheel.add_child(spoke)

	cockpit_anchor = Node3D.new()
	cockpit_anchor.position = Vector3(x, 2.0, _front_z + 1.6)
	_body.add_child(cockpit_anchor)


func _build_wheels() -> void:
	var b := LowPolyBuilder.new()
	b.wheel(Vector3.ZERO, spec.wheel_radius, 0.36, Color(0.07, 0.07, 0.08), Color(0.7, 0.7, 0.72))
	var wheel_mesh := b.build(LowPolyBuilder.vertex_colour_material())
	var wheel_x := _half_width - 0.2
	for axle_z: float in [-spec.wheelbase, 0.0]:
		for side: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * wheel_x, spec.wheel_radius, axle_z)
			add_child(pivot)
			var spinner := MeshInstance3D.new()
			spinner.mesh = wheel_mesh
			pivot.add_child(spinner)
			_spinners.append(spinner)
			_wheel_pivots.append(pivot)
			if axle_z < 0.0:
				_front_wheels.append(pivot)


func _build_doors() -> void:
	# Two leaves hinged at the edges of the doorway. They swing out from the
	# side of the bus, so an open door can be seen from behind.
	var leaf_length := DOOR_WIDTH / 2.0 - 0.02
	var x := (_half_width - 0.03) * spec.door_side
	_door_front = _door_leaf(Vector3(x, 0.0, _door_near_z), leaf_length)
	_door_rear = _door_leaf(Vector3(x, 0.0, _door_far_z), -leaf_length)


## length is signed along Z, from the hinge to the door's free edge.
func _door_leaf(hinge: Vector3, length: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = hinge
	_body.add_child(pivot)
	var height := _top_y - SKIRT_BOTTOM
	var mid_y := (SKIRT_BOTTOM + _top_y) / 2.0
	var size_z := absf(length)
	var centre := Vector3(0.0, mid_y, length / 2.0)
	var frame := LowPolyBuilder.new()
	frame.box(centre + Vector3(0.0, -height / 2.0 + 0.2, 0.0), Vector3(0.06, 0.4, size_z), spec.stripe_colour)
	frame.box(centre + Vector3(0.0, height / 2.0 - 0.05, 0.0), Vector3(0.06, 0.1, size_z), spec.stripe_colour)
	frame.box(Vector3(0.0, mid_y, length - signf(length) * 0.04), Vector3(0.06, height, 0.08), DARK)
	frame.box(Vector3(0.0, mid_y, signf(length) * 0.04), Vector3(0.06, height, 0.08), DARK)
	var leaf := MeshInstance3D.new()
	leaf.mesh = frame.build(LowPolyBuilder.vertex_colour_material())
	pivot.add_child(leaf)

	var pane := LowPolyBuilder.new()
	pane.box(centre + Vector3(0.0, 0.15, 0.0), Vector3(0.02, height - 0.5, size_z - 0.1), Color(0.5, 0.65, 0.75, 0.28))
	var glass_material := StandardMaterial3D.new()
	glass_material.vertex_color_use_as_albedo = true
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var glass := MeshInstance3D.new()
	glass.mesh = pane.build(glass_material)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(glass)
	return pivot


func _build_lamps() -> void:
	# Dim lenses are part of the body. Lit versions sit on top and are toggled.
	var lenses := LowPolyBuilder.new()
	var brake := LowPolyBuilder.new()
	var left := LowPolyBuilder.new()
	var right := LowPolyBuilder.new()
	for side: float in [-1.0, 1.0]:
		var x := side * (_half_width - 0.24)
		var brake_pos := Vector3(x, 1.05, _rear_z + 0.005)
		var rear_pos := Vector3(x, 1.28, _rear_z + 0.005)
		var front_pos := Vector3(side * (_half_width - 0.2), 0.98, _front_z - 0.005)
		var size := Vector3(0.34, 0.16, 0.03)
		lenses.box(brake_pos, size, LAMP_OFF_RED)
		lenses.box(rear_pos, size, LAMP_OFF_AMBER)
		lenses.box(front_pos, size, LAMP_OFF_AMBER)
		brake.box(brake_pos + Vector3(0.0, 0.0, 0.02), size, Color.WHITE)
		var lit := left if side < 0.0 else right
		lit.box(rear_pos + Vector3(0.0, 0.0, 0.02), size, Color.WHITE)
		lit.box(front_pos + Vector3(0.0, 0.0, -0.02), size, Color.WHITE)
	var lens_instance := MeshInstance3D.new()
	lens_instance.mesh = lenses.build(LowPolyBuilder.vertex_colour_material())
	_body.add_child(lens_instance)
	_brake_lamps = _lit_lamp(brake, Color(1.0, 0.1, 0.08))
	_left_lamps = _lit_lamp(left, Color(1.0, 0.65, 0.1))
	_right_lamps = _lit_lamp(right, Color(1.0, 0.65, 0.1))


func _lit_lamp(builder: LowPolyBuilder, colour: Color) -> MeshInstance3D:
	var lamp := MeshInstance3D.new()
	lamp.mesh = builder.build(_flat_material(colour))
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.visible = false
	_body.add_child(lamp)
	return lamp


func _flat_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
