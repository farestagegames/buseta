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
## Hands sit at ten to two, and follow the wheel this far before they slide on it.
const HAND_SPREAD := deg_to_rad(50.0)
const HAND_FOLLOW := deg_to_rad(70.0)
const RIM_RADIUS := 0.22
const MIRROR_FACE_SCALE := 0.42

const DARK := Color(0.1, 0.1, 0.12)
const TRIM := Color(0.26, 0.27, 0.3)
const SEAT := Color(0.15, 0.25, 0.5)
const POLE := Color(0.9, 0.72, 0.15)
const MACHINE_SCREEN := Color(0.35, 0.85, 0.55)
const LAMP_OFF_RED := Color(0.35, 0.05, 0.05)
const LAMP_OFF_AMBER := Color(0.45, 0.25, 0.05)

@export var spec: BusSpec

var driver_look: DriverLook
var cockpit_anchor: Node3D
var cabin: CabinLayout

var _body: Node3D
var _steering_wheel: Node3D
var _wheel_tilt: Node3D
var _sleeves: Array[MeshInstance3D] = []
var _hands: Array[MeshInstance3D] = []
var _mirror_face: MeshInstance3D
var _front_wheels: Array[Node3D] = []
var _wheel_pivots: Array[Node3D] = [] ## Front left, front right, rear left, rear right.
var _spinners: Array[Node3D] = []
var _door_front: Node3D
var _door_rear: Node3D
var _brake_lamps: MeshInstance3D
var _left_lamps: MeshInstance3D
var _right_lamps: MeshInstance3D
var _wheel_spin: float = 0.0
var _seat_points: Array[Vector3] = []
var _seat_order: Array[Vector3] = []
var _held_seats: Dictionary = {}
var _riders: MultiMesh
var _rider_heads: MultiMesh
var _rider_hair: MultiMesh
var _driver: Node3D
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
	cabin = CabinLayout.new(spec)
	if driver_look == null:
		driver_look = DriverLook.new()

	_body = Node3D.new()
	add_child(_body)
	_build_shell()
	_build_glass()
	_build_cockpit()
	_build_wheels()
	_build_doors()
	_build_lamps()
	_build_riders()
	_build_driver()
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.onboard_changed.connect(_on_onboard_changed)
	GameEvents.camera_view_changed.connect(_on_view_changed)


func visible_riders() -> int:
	return _riders.visible_instance_count


func driver_visible() -> bool:
	return _driver.visible


func hands_visible() -> bool:
	return _hands[0].is_visible_in_tree()


func mirror_face() -> MeshInstance3D:
	return _mirror_face


## The floor people stand on, which moves with the suspension.
func cabin_floor() -> Node3D:
	return _body


## Holds the next seat empty for someone still walking to it. -1 if the bus is full.
func reserve_seat() -> int:
	var index := _riders.visible_instance_count
	if index >= _seat_order.size():
		return -1
	_held_seats[index] = true
	var empty := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), _seat_order[index])
	for batch: MultiMesh in [_riders, _rider_heads, _rider_hair]:
		batch.set_instance_transform(index, empty)
	return index


func seat_is_held(index: int) -> bool:
	return _held_seats.has(index)


func fill_seat(index: int) -> void:
	if index < 0:
		return
	_held_seats.erase(index)
	var place := Transform3D(Basis.IDENTITY, _seat_order[index])
	for batch: MultiMesh in [_riders, _rider_heads, _rider_hair]:
		batch.set_instance_transform(index, place)


## Where a seat is, or the back of the bus if there is no seat to be had.
func seat_position(index: int) -> Vector3:
	return _seat_order[index] if index >= 0 else Vector3(0.0, 0.0, _rear_z - 1.0)


func _on_onboard_changed(count: int) -> void:
	var shown := mini(count, _riders.instance_count)
	_riders.visible_instance_count = shown
	_rider_heads.visible_instance_count = shown
	_rider_hair.visible_instance_count = shown


## The driver would block the player's own view from the cockpit.
func _on_view_changed(view_name: String) -> void:
	_driver.visible = view_name != "Cockpit"


func door_swing_angle() -> float:
	return _door_front.rotation.y


func _on_telemetry(data: BusTelemetry) -> void:
	_body.rotation = Vector3(data.body_pitch + data.ground_pitch, 0.0, -data.body_roll - data.ground_roll)
	for i in 4:
		_wheel_pivots[i].position.y = data.wheel_heights[i] - data.body_height + spec.wheel_radius
	_steering_wheel.rotation.y = -data.steer_angle * STEERING_WHEEL_TURNS
	_pose_arms(data.steer_angle * STEERING_WHEEL_TURNS)
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

	# Mirrors on arms, which also make the cockpit view read as a real bus.
	for side: float in [-1.0, 1.0]:
		var mirror_z := _front_z + 0.15
		b.box(Vector3(side * (_half_width + 0.14), 2.3, mirror_z), Vector3(0.3, 0.04, 0.04), DARK)
		b.box(Vector3(side * (_half_width + 0.27), 2.12, mirror_z), Vector3(0.05, 0.36, 0.17), DARK)

	# Saloon seats, so the windows are not looking at an empty box.
	var row_z := _door_far_z + 0.5
	while row_z < _rear_z - 0.8:
		for x: float in [-0.95, -0.5, 0.5, 0.95]:
			b.box(Vector3(x, 0.72, row_z), Vector3(0.4, 0.5, 0.42), SEAT)
			b.box(Vector3(x, 1.12, row_z + 0.18), Vector3(0.4, 0.55, 0.08), SEAT)
			_seat_points.append(Vector3(x, 0.97, row_z))
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
	# The dash runs the full width ahead of the doorway, and is only deep beside the driver.
	var door_side := float(spec.door_side)
	var ahead_of_door := _door_near_z - _front_z - 0.07
	b.box(Vector3(0.0, 1.05, _front_z + 0.07 + ahead_of_door / 2.0), Vector3(spec.body_width - 0.15, 0.2, ahead_of_door), TRIM)
	b.box(Vector3(-door_side * 0.6, 1.05, _front_z + 0.42), Vector3(spec.body_width - 1.2, 0.2, 0.7), TRIM)
	b.box(Vector3(x, 0.72, _front_z + 1.75), Vector3(0.55, 0.5, 0.5), DARK)
	# The ticket machine people pay at, on a pole beside the driver.
	var machine := cabin.machine
	b.box(Vector3(machine.x, (FLOOR_Y + machine.y) / 2.0, machine.z), Vector3(0.05, machine.y - FLOOR_Y, 0.05), POLE)
	b.box(machine, Vector3(0.1, 0.2, 0.16), DARK)
	b.box(machine + Vector3(door_side * 0.055, 0.03, 0.0), Vector3(0.01, 0.09, 0.12), MACHINE_SCREEN)
	# Handrails at the doorway.
	var rail_x := door_side * (_half_width - 0.28)
	var rail_height := _top_y - FLOOR_Y
	b.box(Vector3(rail_x, FLOOR_Y + rail_height / 2.0, _door_far_z + 0.06), Vector3(0.05, rail_height, 0.05), POLE)
	b.box(Vector3(rail_x, FLOOR_Y + rail_height / 2.0, _door_near_z - 0.06), Vector3(0.05, rail_height, 0.05), POLE)
	b.box(Vector3(x, 1.3, _front_z + 2.0), Vector3(0.55, 0.9, 0.1), DARK)
	var dash := MeshInstance3D.new()
	dash.mesh = b.build(LowPolyBuilder.vertex_colour_material())
	_body.add_child(dash)

	_wheel_tilt = Node3D.new()
	_wheel_tilt.position = Vector3(x, 1.38, _front_z + 0.9)
	_wheel_tilt.rotation.x = deg_to_rad(55.0)
	_body.add_child(_wheel_tilt)
	_steering_wheel = Node3D.new()
	_wheel_tilt.add_child(_steering_wheel)
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


## Seated passengers are one instanced batch, filled in a shuffled order so the
## bus does not fill front to back. Only the shirt takes the instance colour.
func _build_riders() -> void:
	_seat_order = _seat_points.duplicate()
	var order := _seat_order
	var random := RandomNumberGenerator.new()
	random.seed = 31
	for i in range(order.size() - 1, 0, -1):
		var swap := random.randi_range(0, i)
		var held: Vector3 = order[i]
		order[i] = order[swap]
		order[swap] = held
	var torso := LowPolyBuilder.new()
	torso.box(Vector3(0.0, 0.3, 0.0), Vector3(0.38, 0.6, 0.22), Color.WHITE)
	torso.box(Vector3(0.0, 0.58, 0.0), Vector3(0.43, 0.09, 0.24), Color.WHITE)
	for side: float in [-0.25, 0.25]:
		torso.box(Vector3(side, 0.32, -0.08), Vector3(0.1, 0.46, 0.12), Color(0.82, 0.82, 0.82))
	var head := LowPolyBuilder.new()
	head.box(Vector3(0.0, 0.66, 0.0), Vector3(0.1, 0.1, 0.1), Color.WHITE)
	head.box(Vector3(0.0, 0.82, 0.0), Vector3(0.21, 0.24, 0.22), Color.WHITE)
	var hair := LowPolyBuilder.new()
	hair.box(Vector3(0.0, 0.96, 0.01), Vector3(0.23, 0.07, 0.24), Color.WHITE)
	hair.box(Vector3(0.0, 0.85, 0.1), Vector3(0.23, 0.2, 0.05), Color.WHITE)
	var designs := Country.pack.passengers()
	_riders = _rider_batch(torso, order.size())
	_rider_heads = _rider_batch(head, order.size())
	_rider_hair = _rider_batch(hair, order.size())
	for i in order.size():
		var place := Transform3D(Basis.IDENTITY, order[i])
		_riders.set_instance_transform(i, place)
		_rider_heads.set_instance_transform(i, place)
		_rider_hair.set_instance_transform(i, place)
		_riders.set_instance_color(i, _design_colour(designs["tops"], i))
		_rider_heads.set_instance_color(i, _design_colour(designs["skins"], i))
		_rider_hair.set_instance_color(i, _design_colour(designs["hairs"], i * 3))


func _design_colour(colours: Array, index: int) -> Color:
	var value: Array = colours[index % colours.size()]
	return Color(value[0], value[1], value[2])


func _rider_batch(builder: LowPolyBuilder, count: int) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = builder.build(LowPolyBuilder.vertex_colour_material())
	batch.instance_count = count
	batch.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.custom_aabb = AABB(Vector3(-2.0, 0.0, _front_z), Vector3(4.0, 3.0, spec.overall_length()))
	_body.add_child(instance)
	return batch


func _build_driver() -> void:
	var b := LowPolyBuilder.new()
	var x := spec.driver_seat_x
	var z := _front_z + 1.72
	DriverFigure.add_torso(b, driver_look, Vector3(x, 1.28, z))
	DriverFigure.add_head(b, driver_look, Vector3(x, 1.28 + DriverFigure.HEAD_ABOVE_CHEST, z))
	_driver = MeshInstance3D.new()
	(_driver as MeshInstance3D).mesh = b.build(LowPolyBuilder.vertex_colour_material())
	_body.add_child(_driver)
	_build_arms()
	_build_interior_mirror()
	_pose_arms(0.0)


## The body is hidden in the cockpit, so the hands and the mirror show who is driving.
func _build_arms() -> void:
	var sleeve := DriverFigure.build_sleeve(driver_look)
	var hand := DriverFigure.build_hand(driver_look)
	for i in 2:
		var arm := MeshInstance3D.new()
		arm.mesh = sleeve
		_body.add_child(arm)
		_sleeves.append(arm)
		var grip := MeshInstance3D.new()
		grip.mesh = hand
		_body.add_child(grip)
		_hands.append(grip)


## The wheel can turn further than arms can, so past a point the hands slide on the rim.
func _pose_arms(wheel_turn: float) -> void:
	var held := clampf(wheel_turn, -HAND_FOLLOW, HAND_FOLLOW)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var angle := held + side * HAND_SPREAD
		var hand := _wheel_tilt.transform * Vector3(RIM_RADIUS * sin(angle), 0.0, -RIM_RADIUS * cos(angle))
		var elbow := Vector3(spec.driver_seat_x + side * 0.3, 1.12, _front_z + 1.62)
		var reach := hand - elbow
		var facing := Basis.looking_at(reach, Vector3.UP)
		_sleeves[i].transform = Transform3D(facing * Basis.from_scale(Vector3(1.0, 1.0, reach.length())), elbow)
		_hands[i].transform = Transform3D(facing, hand)


func _build_interior_mirror() -> void:
	var y := _top_y - 0.5
	var z := _front_z + 0.4
	var x := 0.1 * float(spec.door_side)
	var b := LowPolyBuilder.new()
	b.box(Vector3(x, y + 0.2, z), Vector3(0.05, 0.3, 0.05), DARK)
	b.box(Vector3(x, y, z), Vector3(0.46, 0.21, 0.04), DARK)
	b.box(Vector3(x, y, z + 0.022), Vector3(0.41, 0.17, 0.005), Color(0.42, 0.5, 0.56))
	var mirror := MeshInstance3D.new()
	mirror.mesh = b.build(LowPolyBuilder.vertex_colour_material())
	_body.add_child(mirror)
	_mirror_face = MeshInstance3D.new()
	_mirror_face.mesh = DriverFigure.build_head(driver_look)
	_mirror_face.scale = Vector3.ONE * MIRROR_FACE_SCALE
	_mirror_face.position = Vector3(x - 0.08, y - 0.015, z + 0.06)
	_mirror_face.rotation.y = PI
	_body.add_child(_mirror_face)


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
