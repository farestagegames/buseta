class_name BusVisual
extends Node3D
## Procedural low-poly bus. Reads telemetry to move wheels, doors, lamps and the
## sprung body. It has no effect on the simulation.

const FLOOR_Y := 0.42
const SKIRT_BOTTOM := 0.42
const BELT_Y := 1.3
const DOOR_WIDTH := 1.25
const DOOR_SWING := deg_to_rad(105.0)
const STEERING_WHEEL_TURNS := 3.0
## Hands sit at ten to two, and follow the wheel this far before they slide on it.
const HAND_SPREAD := deg_to_rad(50.0)
const HAND_FOLLOW := deg_to_rad(70.0)
const RIM_RADIUS := 0.22
const MIRROR_FACE_SCALE := 0.42
const MIRROR_GLASS := Vector2(0.41, 0.17)
## Where the face sits from the middle of the glass's front: a little towards the
## driver's side, a little low and just in front, turned to look back at the driver.
## x is for a bus with its doors on the right, and flips with door_side.
const MIRROR_FACE_OFFSET := Vector3(-0.08, -0.02, 0.004)
## A reflection is flat, so the face is squashed to this share of its depth. Then
## it stays inside the glass seen from any seat, in any bus and on either side.
const MIRROR_FLAT := 0.08
## Keeps the little depth that is left from peeping past the frame at a steep angle.
const MIRROR_MARGIN := 0.008
## The front of the glass, from the middle of the mirror.
const MIRROR_GLASS_FRONT := 0.0245
## A reflection is a little dimmer than the face itself.
const MIRROR_TINT := Color(0.88, 0.88, 0.9)

const DARK := Color(0.1, 0.1, 0.12)
const TRIM := Color(0.26, 0.27, 0.3)
const SEAT := Color(0.15, 0.25, 0.5)
const POLE := Color(0.9, 0.72, 0.15)
const WOOD := Color(0.55, 0.36, 0.2)
const CHROME := Color(0.78, 0.8, 0.82)
const MARKER := Color(0.98, 0.6, 0.12)
const BELLOWS := Color(0.16, 0.16, 0.18)
const MACHINE_SCREEN := Color(0.35, 0.85, 0.55)
const LAMP_OFF_RED := Color(0.35, 0.05, 0.05)
const LAMP_OFF_AMBER := Color(0.45, 0.25, 0.05)
const HEADLAMP := Color(1.0, 0.97, 0.86)
const TAIL_LAMP := Color(0.8, 0.07, 0.05)
const CABIN_LAMP := Color(1.0, 0.95, 0.84)
const WINDSCREEN_SHADER := preload("res://assets/shaders/windscreen.gdshader")
## The wipers swing through this angle from lying flat, and take this long for one
## sweep up and back in light rain and in a downpour.
const WIPER_SWEEP := 1.8
const WIPER_SLOW := 2.0
const WIPER_FAST := 1.1
const WIPER_START_RAIN := 0.04
## The bus's own lights are seen only by the bus, so the cabin light costs nothing
## outside it. Every mesh in the bus is on this render layer as well as the first.
const BUS_LAYER := 2

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
var _seat_looks: Array[PassengerLook] = [] ## Who sits in each seat, in filling order.
var _held_seats: Dictionary = {}
var _onboard := 0 ## Everyone aboard, seated or standing.
var _riders: MultiMesh
var _rider_heads: MultiMesh
var _rider_hair: MultiMesh
var _driver: Node3D
var _trailer: Node3D
var _bellows: Node3D
var _trailer_brake: MeshInstance3D
var _trailer_left: MeshInstance3D
var _trailer_right: MeshInstance3D
var _night_lamps: Array[Node3D] = [] ## Headlamps, tail lamps and the cabin strip.
var _headlight: SpotLight3D
var _cabin_light: OmniLight3D
var _wipers: Array[Node3D] = []
var _wiper_phase: float = 0.0 ## Sweeps so far, counted up.
var _rain: float = 0.0
var _drops: MeshInstance3D
var _drops_material: ShaderMaterial
var _lights_on: bool = false
var _drops_allowed: bool = true ## The graphics level draws raindrops on the glass.
## The drops are drawn, unseen, for the first frames, so their shader is built at
## the start of the shift rather than when the rain comes.
var _warm_frames: int = 3
var _front_z: float
var _cab_z: float ## Where the cab starts. A chiva's bonnet sits ahead of it.
var _rear_z: float
var _half_width: float
var _top_y: float
var _door_near_z: float
var _door_far_z: float
var _rear_near_z: float = INF ## The rear doorway, or INF when there is none.
var _rear_far_z: float = INF
var _rear_door_front: Node3D
var _rear_door_rear: Node3D


func _ready() -> void:
	_front_z = -(spec.wheelbase + spec.front_overhang)
	_rear_z = spec.rear_overhang
	_half_width = spec.body_width / 2.0
	_top_y = spec.body_height - 0.22
	_cab_z = _front_z + spec.cab_offset
	_door_near_z = _front_z + spec.door_offset
	_door_far_z = _door_near_z + DOOR_WIDTH
	if spec.has_rear_door():
		_rear_near_z = spec.rear_door_near_z()
		_rear_far_z = spec.rear_door_far_z()
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
	_build_trailer()
	_build_riders()
	_build_driver()
	_build_night_lights()
	_build_wipers()
	_add_to_bus_layer(self)
	_apply_lights()
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.lighting_changed.connect(_on_lighting)
	GameEvents.weather_updated.connect(func(weather: WeatherClock) -> void: _rain = weather.rain)
	GameSettings.changed.connect(_apply_lights)
	GameEvents.onboard_changed.connect(_on_onboard_changed)
	GameEvents.camera_view_changed.connect(_on_view_changed)


func visible_riders() -> int:
	return _riders.visible_instance_count


func seat_count() -> int:
	return _riders.instance_count


## How many people are aboard beyond the seats. They stand, so they are not drawn.
func riders_standing() -> int:
	return maxi(0, _onboard - seat_count())


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


## The passenger who walked to this seat sits down in it, looking as they walked.
func fill_seat(index: int, look: PassengerLook = null) -> void:
	if index < 0:
		return
	_held_seats.erase(index)
	if look != null:
		_seat_looks[index] = look
	_seat_rider(index)


## Who sits in a seat, or null if there is no such seat.
func rider_look(index: int) -> PassengerLook:
	return _seat_looks[index] if index >= 0 and index < _seat_looks.size() else null


func _seat_rider(index: int) -> void:
	var look := _seat_looks[index]
	var place := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * look.size), _seat_order[index])
	for batch: MultiMesh in [_riders, _rider_heads, _rider_hair]:
		batch.set_instance_transform(index, place)
	_riders.set_instance_color(index, look.top)
	_rider_heads.set_instance_color(index, look.skin)
	_rider_hair.set_instance_color(index, look.crown_colour())


## Where a seat is, or the back of the bus if there is no seat to be had.
func seat_position(index: int) -> Vector3:
	return _seat_order[index] if index >= 0 else Vector3(0.0, 0.0, _rear_z - 1.0)


func _on_onboard_changed(count: int) -> void:
	_onboard = count
	var shown := mini(count, _riders.instance_count)
	_riders.visible_instance_count = shown
	_rider_heads.visible_instance_count = shown
	_rider_hair.visible_instance_count = shown


## The driver would block the player's own view from the cockpit.
func _on_view_changed(view_name: String) -> void:
	_driver.visible = view_name != "Cockpit"


func door_swing_angle() -> float:
	return _door_front.rotation.y if _door_front != null else 0.0


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
	if _door_front != null:
		var swing := data.door_open_amount * DOOR_SWING * float(spec.door_side)
		_door_front.rotation.y = swing
		_door_rear.rotation.y = -swing
		if _rear_door_front != null:
			_rear_door_front.rotation.y = swing
			_rear_door_rear.rotation.y = -swing
	_brake_lamps.visible = data.brake > 0.05
	_left_lamps.visible = data.indicator_lamp_on and data.indicator_side < 0
	_right_lamps.visible = data.indicator_lamp_on and data.indicator_side > 0
	if _trailer != null:
		_trailer.rotation.y = data.trailer_angle
		_bellows.rotation.y = data.trailer_angle / 2.0
		_trailer_brake.visible = _brake_lamps.visible
		_trailer_left.visible = _left_lamps.visible
		_trailer_right.visible = _right_lamps.visible


func _build_shell() -> void:
	if spec.body_style == "chiva":
		_build_chiva()
		return
	var b := LowPolyBuilder.new()
	var paint := spec.body_colour
	var stripe := spec.stripe_colour
	var length := spec.overall_length()
	var mid_z := (_front_z + _rear_z) / 2.0
	var door_x := _half_width * spec.door_side
	var wall_x := _half_width - 0.04

	# Roof, floor, and solid ends.
	b.box(Vector3(0.0, spec.body_height - 0.11, mid_z), Vector3(spec.body_width, 0.22, length), spec.roof_colour)
	b.box(Vector3(0.0, FLOOR_Y, mid_z), Vector3(spec.body_width - 0.1, 0.06, length - 0.1), TRIM)
	b.box(Vector3(0.0, (SKIRT_BOTTOM + 1.65) / 2.0, _rear_z - 0.04), Vector3(spec.body_width, 1.65 - SKIRT_BOTTOM, 0.08), paint)
	b.box(Vector3(0.0, (SKIRT_BOTTOM + 1.15) / 2.0, _front_z + 0.04), Vector3(spec.body_width, 1.15 - SKIRT_BOTTOM, 0.08), paint)

	# Lower side panels, with the door gap left open on the door side.
	_side_band(b, -door_x, wall_x, SKIRT_BOTTOM, BELT_Y, _front_z, _rear_z, paint)
	_side_band(b, door_x, wall_x, SKIRT_BOTTOM, BELT_Y, _front_z, _door_near_z, paint)
	_door_side_band(b, door_x, wall_x, SKIRT_BOTTOM, BELT_Y, _door_far_z, _rear_z, paint)
	_side_band(b, -door_x, _half_width, 1.16, 1.3, _front_z, _rear_z, stripe)
	_door_side_band(b, door_x, _half_width, 1.16, 1.3, _door_far_z, _rear_z, stripe)

	# Window pillars.
	var z := _door_far_z
	while z < _rear_z:
		for side: float in [-1.0, 1.0]:
			if side * spec.door_side > 0.0 and _in_rear_door(z, 0.1):
				continue
			b.box(Vector3(side * wall_x, (BELT_Y + _top_y) / 2.0, z), Vector3(0.09, _top_y - BELT_Y, 0.14), paint)
		z += 1.9
	if _rear_near_z != INF:
		for edge: float in [_rear_near_z, _rear_far_z]:
			b.box(Vector3(signf(door_x) * wall_x, (BELT_Y + _top_y) / 2.0, edge), Vector3(0.09, _top_y - BELT_Y, 0.14), paint)
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

	_add_seats(b, _door_far_z + 0.5, _rear_z - 0.8, SEAT, true)
	_add_style_details(b)
	_paint_livery(b, 0.5, 1.12)
	_add_mesh(b, _body)


func _add_mesh(b: LowPolyBuilder, parent: Node3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = b.build(LowPolyBuilder.vertex_colour_material())
	parent.add_child(mesh_instance)


## Rows of seats, so the windows are not looking at an empty box. Only seats in the
## main section are counted for riders.
func _add_seats(b: LowPolyBuilder, from_z: float, to_z: float, colour: Color, for_riders: bool) -> void:
	var row_z := from_z
	while row_z < to_z:
		for x: float in [-0.95, -0.5, 0.5, 0.95]:
			# The way out to the rear door is kept clear.
			if x * spec.door_side > 0.0 and _in_rear_door(row_z, 0.35):
				continue
			b.box(Vector3(x, 0.72, row_z), Vector3(0.4, 0.5, 0.42), colour)
			b.box(Vector3(x, 1.12, row_z + 0.18), Vector3(0.4, 0.55, 0.08), colour)
			if for_riders:
				_seat_points.append(Vector3(x, 0.97, row_z))
		row_z += 0.95


func _add_style_details(b: LowPolyBuilder) -> void:
	var top := spec.body_height
	var door_x := _half_width * spec.door_side
	match spec.body_style:
		"buseta":
			b.box(Vector3(0.0, _top_y + 0.02, _front_z - 0.12), Vector3(spec.body_width - 0.2, 0.08, 0.3), spec.stripe_colour)
			b.box(Vector3(0.0, top + 0.08, (_front_z + _rear_z) / 2.0), Vector3(0.9, 0.16, 1.6), spec.accent_colour)
			b.box(Vector3(0.0, 0.52, _front_z - 0.09), Vector3(spec.body_width + 0.06, 0.16, 0.08), CHROME)
			for x: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				b.box(Vector3(x * (_half_width - 0.1), top - 0.02, _front_z + 0.02), Vector3(0.14, 0.06, 0.06), MARKER)
		"articulated":
			# Painted panels mark the doors along the side of a rapid-transit bus.
			var z := _door_far_z + 3.0
			while z < _rear_z - 1.0:
				if _in_rear_door(z, DOOR_WIDTH):
					z += 5.0
					continue
				b.box(Vector3(door_x * 1.004, (SKIRT_BOTTOM + _top_y) / 2.0, z), Vector3(0.03, _top_y - SKIRT_BOTTOM, DOOR_WIDTH), DARK)
				z += 5.0


## The livery's pattern, on the side panels below the windows.
func _paint_livery(b: LowPolyBuilder, low: float, high: float) -> void:
	for side: float in [-1.0, 1.0]:
		var from_z := _door_far_z if side * spec.door_side > 0.0 else _front_z + 0.2
		var to_z := _rear_z - 0.1
		if side * spec.door_side > 0.0 and _rear_near_z != INF:
			_pattern_on_side(b, side * (_half_width + 0.015), from_z, _rear_near_z, low, high)
			from_z = _rear_far_z
		_pattern_on_side(b, side * (_half_width + 0.015), from_z, to_z, low, high)


func _pattern_on_side(b: LowPolyBuilder, x: float, from_z: float, to_z: float, low: float, high: float) -> void:
	var accent := spec.accent_colour
	var stripe := spec.stripe_colour
	var middle := (low + high) / 2.0
	var at := func(z: float, y: float) -> Vector3: return Vector3(x, y, z)
	var z := from_z
	match spec.pattern:
		"bands":
			var third := (high - low) / 3.0
			b.box(Vector3(x, low + third * 0.5, (from_z + to_z) / 2.0), Vector3(0.02, third, to_z - from_z), accent)
			b.box(Vector3(x, low + third * 1.5, (from_z + to_z) / 2.0), Vector3(0.02, third, to_z - from_z), stripe)
		"zigzag":
			while z + 0.7 <= to_z:
				b.flag(at.call(z, low), at.call(z + 0.35, high), at.call(z + 0.7, low), accent)
				b.flag(at.call(z + 0.35, high), at.call(z + 1.05, high), at.call(z + 0.7, low), stripe)
				z += 0.7
		"waves":
			var step := 0.35
			while z + step <= to_z:
				var a := middle + sin(z * 2.4) * 0.14
				var c := middle + sin((z + step) * 2.4) * 0.14
				b.flag(at.call(z, a + 0.11), at.call(z + step, c + 0.11), at.call(z + step, c - 0.11), accent)
				b.flag(at.call(z, a + 0.11), at.call(z + step, c - 0.11), at.call(z, a - 0.11), accent)
				z += step
		"diamonds":
			while z + 0.8 <= to_z:
				var centre := z + 0.4
				var colour := accent if int(z * 2.0) % 2 == 0 else stripe
				b.flag(at.call(centre - 0.34, middle), at.call(centre, high - 0.02), at.call(centre + 0.34, middle), colour)
				b.flag(at.call(centre - 0.34, middle), at.call(centre + 0.34, middle), at.call(centre, low + 0.02), colour)
				z += 0.8
		"chevrons":
			while z + 0.9 <= to_z:
				b.flag(at.call(z, high), at.call(z + 0.3, middle), at.call(z + 0.55, high), accent)
				b.flag(at.call(z, low), at.call(z + 0.55, low), at.call(z + 0.3, middle), accent)
				z += 0.9
		"sunburst":
			var sun := to_z - 1.0
			for ray in 7:
				var angle := PI * (float(ray) + 0.5) / 7.0
				var tip: Vector3 = at.call(sun + cos(angle) * 1.1, low + sin(angle) * (high - low) * 1.0)
				b.flag(at.call(sun - 0.1, low), at.call(sun + 0.1, low), tip, accent if ray % 2 == 0 else stripe)
		"flowers":
			while z + 0.9 <= to_z:
				var centre := z + 0.45
				for petal in 6:
					var turn := TAU * float(petal) / 6.0
					var next := turn + TAU / 6.0
					b.flag(at.call(centre, middle), at.call(centre + cos(turn) * 0.2, middle + sin(turn) * 0.2),
						at.call(centre + cos(next) * 0.2, middle + sin(next) * 0.2), accent if petal % 2 == 0 else stripe)
				z += 0.9


## A chiva: a painted wooden body on a truck chassis, with open sides, a long bonnet
## in front and a loaded roof rack.
func _build_chiva() -> void:
	var b := LowPolyBuilder.new()
	var paint := spec.body_colour
	var stripe := spec.stripe_colour
	var accent := spec.accent_colour
	var bonnet := spec.cab_offset
	var bonnet_mid := _front_z + bonnet / 2.0
	var body_mid := (_cab_z + _rear_z) / 2.0
	var body_length := _rear_z - _cab_z
	var roof_y := spec.body_height - 0.09
	b.box(Vector3(0.0, 1.0, bonnet_mid), Vector3(1.5, 0.95, bonnet), paint)
	b.box(Vector3(0.0, 1.5, bonnet_mid), Vector3(1.2, 0.08, bonnet - 0.2), stripe)
	b.box(Vector3(0.0, 0.92, _front_z - 0.02), Vector3(1.2, 0.72, 0.06), CHROME)
	b.box(Vector3(0.0, 0.5, _front_z - 0.08), Vector3(spec.body_width, 0.16, 0.1), DARK)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 1.0, 0.72, bonnet_mid), Vector3(0.45, 0.1, bonnet), paint.darkened(0.3))
		b.box(Vector3(side * 0.62, 1.08, _front_z - 0.03), Vector3(0.24, 0.2, 0.04), Color(0.95, 0.95, 0.85))
	b.box(Vector3(0.0, FLOOR_Y, body_mid), Vector3(spec.body_width - 0.06, 0.08, body_length), WOOD)
	b.box(Vector3(0.0, (SKIRT_BOTTOM + 1.15) / 2.0, _cab_z + 0.04), Vector3(spec.body_width, 1.15 - SKIRT_BOTTOM, 0.08), paint)
	b.box(Vector3(0.0, (SKIRT_BOTTOM + 1.15) / 2.0, _rear_z - 0.04), Vector3(spec.body_width, 1.15 - SKIRT_BOTTOM, 0.08), paint)
	var door_x := _half_width * spec.door_side
	_side_band(b, -door_x, _half_width - 0.04, SKIRT_BOTTOM, 1.15, _cab_z, _rear_z, paint)
	_side_band(b, door_x, _half_width - 0.04, SKIRT_BOTTOM, 1.15, _cab_z, _door_near_z, paint)
	_side_band(b, door_x, _half_width - 0.04, SKIRT_BOTTOM, 1.15, _door_far_z, _rear_z, paint)
	# A painted post for every bench, and a roof that holds the load.
	var z := _cab_z + 0.05
	var post := 0
	while z < _rear_z:
		for side: float in [-1.0, 1.0]:
			if side * spec.door_side > 0.0 and z > _door_near_z and z < _door_far_z:
				continue
			b.box(Vector3(side * (_half_width - 0.05), (1.15 + roof_y) / 2.0, z), Vector3(0.09, roof_y - 1.15, 0.1), stripe if post % 2 == 0 else accent)
		z += 0.95
		post += 1
	b.box(Vector3(0.0, roof_y, body_mid), Vector3(spec.body_width + 0.12, 0.14, body_length + 0.2), spec.roof_colour)
	b.box(Vector3(0.0, roof_y - 0.13, body_mid), Vector3(spec.body_width + 0.16, 0.12, body_length + 0.24), stripe)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (_half_width - 0.05), roof_y + 0.25, body_mid), Vector3(0.05, 0.05, body_length - 0.4), DARK)
		var rail := _cab_z + 0.4
		while rail < _rear_z - 0.2:
			b.box(Vector3(side * (_half_width - 0.05), roof_y + 0.14, rail), Vector3(0.05, 0.22, 0.05), DARK)
			rail += 1.5
	_add_roof_load(b, roof_y)
	for side: float in [-0.35, 0.35]:
		b.box(Vector3(side, (SKIRT_BOTTOM + roof_y + 0.2) / 2.0, _rear_z + 0.08), Vector3(0.06, roof_y + 0.2 - SKIRT_BOTTOM, 0.06), DARK)
	var rung := 0.6
	while rung < roof_y:
		b.box(Vector3(0.0, rung, _rear_z + 0.08), Vector3(0.7, 0.05, 0.05), DARK)
		rung += 0.35
	_add_seats(b, _door_far_z + 0.5, _rear_z - 0.6, WOOD, true)
	_paint_livery(b, 0.5, 1.1)
	_add_mesh(b, _body)


## Sacks, crates and bunches of green plantain, as on any working chiva.
func _add_roof_load(b: LowPolyBuilder, roof_y: float) -> void:
	var loads: Array[Color] = [Color(0.72, 0.6, 0.42), Color(0.3, 0.55, 0.22), Color(0.6, 0.42, 0.22), Color(0.2, 0.42, 0.6), Color(0.3, 0.55, 0.22)]
	var z := _cab_z + 0.7
	var i := 0
	while z < _rear_z - 0.7:
		b.box(Vector3(-0.42 + 0.2 * float(i % 3), roof_y + 0.34, z), Vector3(0.75, 0.52, 0.8), loads[i % loads.size()])
		z += 1.05
		i += 1


## The rear half of an articulated bus and the bellows that join it to the front.
func _build_trailer() -> void:
	if not spec.is_articulated():
		return
	_trailer = Node3D.new()
	_trailer.position = Vector3(0.0, 0.0, spec.hitch_offset)
	_body.add_child(_trailer)
	var from_z := 0.55
	var tail := spec.trailer_wheelbase + spec.trailer_overhang
	var mid_z := (from_z + tail) / 2.0
	var length := tail - from_z
	var wall_x := _half_width - 0.04
	var paint := spec.body_colour
	var b := LowPolyBuilder.new()
	b.box(Vector3(0.0, spec.body_height - 0.11, mid_z), Vector3(spec.body_width, 0.22, length), spec.roof_colour)
	b.box(Vector3(0.0, FLOOR_Y, mid_z), Vector3(spec.body_width - 0.1, 0.06, length), TRIM)
	b.box(Vector3(0.0, (SKIRT_BOTTOM + 1.65) / 2.0, tail - 0.04), Vector3(spec.body_width, 1.65 - SKIRT_BOTTOM, 0.08), paint)
	for side: float in [-1.0, 1.0]:
		_side_band(b, side, wall_x, SKIRT_BOTTOM, BELT_Y, from_z, tail, paint)
		_side_band(b, side, _half_width, 1.16, 1.3, from_z, tail, spec.stripe_colour)
		b.box(Vector3(side * wall_x, 0.68, spec.trailer_wheelbase), Vector3(0.1, 0.56, 1.3), DARK)
		var z := from_z + 0.1
		while z < tail:
			b.box(Vector3(side * wall_x, (BELT_Y + _top_y) / 2.0, z), Vector3(0.09, _top_y - BELT_Y, 0.14), paint)
			z += 1.9
		b.box(Vector3(side * (_half_width + 0.016), (SKIRT_BOTTOM + _top_y) / 2.0, 2.4), Vector3(0.03, _top_y - SKIRT_BOTTOM, DOOR_WIDTH), DARK)
		_pattern_on_side(b, side * (_half_width + 0.015), 3.2, tail - 0.1, 0.5, 1.12)
	_add_seats(b, from_z + 3.4, tail - 0.9, SEAT, false)
	_add_mesh(b, _trailer)

	var glass := LowPolyBuilder.new()
	var band_height := _top_y - BELT_Y
	var band_y := (BELT_Y + _top_y) / 2.0
	var tint := Color(0.5, 0.65, 0.75, 0.28)
	for side: float in [-1.0, 1.0]:
		glass.box(Vector3(side * (_half_width - 0.05), band_y, mid_z), Vector3(0.03, band_height, length), tint)
	glass.box(Vector3(0.0, (1.65 + _top_y) / 2.0, tail - 0.05), Vector3(spec.body_width - 0.1, _top_y - 1.65, 0.03), tint)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.15
	var panes := MeshInstance3D.new()
	panes.mesh = glass.build(material)
	panes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trailer.add_child(panes)

	var wheels := LowPolyBuilder.new()
	wheels.wheel(Vector3.ZERO, spec.wheel_radius, 0.36, Color(0.07, 0.07, 0.08), Color(0.7, 0.7, 0.72))
	var wheel_mesh := wheels.build(LowPolyBuilder.vertex_colour_material())
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * (_half_width - 0.2), spec.wheel_radius, spec.trailer_wheelbase)
		_trailer.add_child(pivot)
		var spinner := MeshInstance3D.new()
		spinner.mesh = wheel_mesh
		pivot.add_child(spinner)
		_spinners.append(spinner)

	_bellows = Node3D.new()
	_bellows.position = Vector3(0.0, 0.0, spec.hitch_offset)
	_body.add_child(_bellows)
	var folds := LowPolyBuilder.new()
	var ridge := -0.5
	while ridge <= 0.5:
		folds.box(Vector3(0.0, (SKIRT_BOTTOM + _top_y) / 2.0, ridge), Vector3(spec.body_width - 0.08, _top_y - SKIRT_BOTTOM, 0.09), BELLOWS)
		ridge += 0.17
	_add_mesh(folds, _bellows)

	var brake := LowPolyBuilder.new()
	var left := LowPolyBuilder.new()
	var right := LowPolyBuilder.new()
	for side: float in [-1.0, 1.0]:
		var x := side * (_half_width - 0.24)
		brake.box(Vector3(x, 1.05, tail + 0.03), Vector3(0.34, 0.16, 0.03), Color.WHITE)
		(left if side < 0.0 else right).box(Vector3(x, 1.28, tail + 0.03), Vector3(0.34, 0.16, 0.03), Color.WHITE)
	_trailer_brake = _lit_lamp(brake, Color(1.0, 0.1, 0.08), _trailer)
	_trailer_left = _lit_lamp(left, Color(1.0, 0.65, 0.1), _trailer)
	_trailer_right = _lit_lamp(right, Color(1.0, 0.65, 0.1), _trailer)


## A side band on the door side, with a gap for the rear door if there is one.
func _door_side_band(b: LowPolyBuilder, side: float, x: float, y0: float, y1: float, z0: float, z1: float, colour: Color) -> void:
	if _rear_near_z == INF or _rear_far_z <= z0 or _rear_near_z >= z1:
		_side_band(b, side, x, y0, y1, z0, z1, colour)
		return
	_side_band(b, side, x, y0, y1, z0, _rear_near_z, colour)
	_side_band(b, side, x, y0, y1, _rear_far_z, z1, colour)


func _in_rear_door(z: float, margin: float) -> bool:
	return _rear_near_z != INF and z > _rear_near_z - margin and z < _rear_far_z + margin


func _side_band(b: LowPolyBuilder, side: float, x: float, y0: float, y1: float, z0: float, z1: float, colour: Color) -> void:
	var size := Vector3(0.09, y1 - y0, z1 - z0)
	b.box(Vector3(signf(side) * x, (y0 + y1) / 2.0, (z0 + z1) / 2.0), size, colour)


func _build_glass() -> void:
	var b := LowPolyBuilder.new()
	var tint := Color(0.5, 0.65, 0.75, 0.28)
	if spec.body_style == "chiva":
		b.box(Vector3(0.0, (1.15 + _top_y) / 2.0, _cab_z + 0.05), Vector3(spec.body_width - 0.1, _top_y - 1.15, 0.03), tint)
		_add_glass(b)
		return
	var band_height := _top_y - BELT_Y
	var band_y := (BELT_Y + _top_y) / 2.0
	var door_x := _half_width * spec.door_side
	var pane_x := _half_width - 0.05
	var full_length := _rear_z - _front_z
	b.box(Vector3(-signf(door_x) * pane_x, band_y, (_front_z + _rear_z) / 2.0), Vector3(0.03, band_height, full_length), tint)
	if _rear_near_z == INF:
		b.box(Vector3(signf(door_x) * pane_x, band_y, (_door_far_z + _rear_z) / 2.0), Vector3(0.03, band_height, _rear_z - _door_far_z), tint)
	else:
		b.box(Vector3(signf(door_x) * pane_x, band_y, (_door_far_z + _rear_near_z) / 2.0), Vector3(0.03, band_height, _rear_near_z - _door_far_z), tint)
		b.box(Vector3(signf(door_x) * pane_x, band_y, (_rear_far_z + _rear_z) / 2.0), Vector3(0.03, band_height, _rear_z - _rear_far_z), tint)
	b.box(Vector3(signf(door_x) * pane_x, band_y, (_front_z + _door_near_z) / 2.0), Vector3(0.03, band_height, _door_near_z - _front_z), tint)
	b.box(Vector3(0.0, (1.15 + _top_y) / 2.0, _front_z + 0.05), Vector3(spec.body_width - 0.1, _top_y - 1.15, 0.03), tint)

	b.box(Vector3(0.0, (1.65 + _top_y) / 2.0, _rear_z - 0.05), Vector3(spec.body_width - 0.1, _top_y - 1.65, 0.03), tint)
	_add_glass(b)


func _add_glass(b: LowPolyBuilder) -> void:
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
	var ahead_of_door := minf(_door_near_z - _cab_z - 0.07, 0.7)
	b.box(Vector3(0.0, 1.05, _cab_z + 0.07 + ahead_of_door / 2.0), Vector3(spec.body_width - 0.15, 0.2, ahead_of_door), TRIM)
	b.box(Vector3(-door_side * 0.6, 1.05, _cab_z + 0.42), Vector3(spec.body_width - 1.2, 0.2, 0.7), TRIM)
	b.box(Vector3(x, 0.72, _cab_z + 1.75), Vector3(0.55, 0.5, 0.5), DARK)
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
	b.box(Vector3(x, 1.3, _cab_z + 2.0), Vector3(0.55, 0.9, 0.1), DARK)
	var dash := MeshInstance3D.new()
	dash.mesh = b.build(LowPolyBuilder.vertex_colour_material())
	_body.add_child(dash)

	_wheel_tilt = Node3D.new()
	_wheel_tilt.position = Vector3(x, 1.38, _cab_z + 0.9)
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
	cockpit_anchor.position = Vector3(x, 2.0, _cab_z + 1.6)
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
	if spec.body_style == "chiva":
		return # A chiva has an open step, not a door.
	# Two leaves hinged at the edges of the doorway. They swing out from the
	# side of the bus, so an open door can be seen from behind.
	var leaf_length := DOOR_WIDTH / 2.0 - 0.02
	var x := (_half_width - 0.03) * spec.door_side
	_door_front = _door_leaf(Vector3(x, 0.0, _door_near_z), leaf_length)
	_door_rear = _door_leaf(Vector3(x, 0.0, _door_far_z), -leaf_length)
	if _rear_near_z != INF:
		_rear_door_front = _door_leaf(Vector3(x, 0.0, _rear_near_z), leaf_length)
		_rear_door_rear = _door_leaf(Vector3(x, 0.0, _rear_far_z), -leaf_length)


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


## Seated passengers are instanced batches for clothes, skin and hair, filled in a
## shuffled order so the bus does not fill front to back. Each seat starts with one
## of the pack's passenger looks, and takes on the look of whoever sits in it.
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
	# Arms rest in front, on the lap, as a window seat on a narrow buseta leaves no
	# room beside the body before the wall.
	var torso := LowPolyBuilder.new()
	torso.box(Vector3(0.0, 0.3, 0.0), Vector3(0.38, 0.6, 0.22), Color.WHITE)
	torso.box(Vector3(0.0, 0.58, 0.0), Vector3(0.4, 0.09, 0.24), Color.WHITE)
	for side: float in [-0.15, 0.15]:
		torso.box(Vector3(side, 0.3, -0.135), Vector3(0.075, 0.44, 0.05), Color(0.82, 0.82, 0.82))
	var head := LowPolyBuilder.new()
	head.box(Vector3(0.0, 0.66, 0.0), Vector3(0.1, 0.1, 0.1), Color.WHITE)
	head.box(Vector3(0.0, 0.82, 0.0), Vector3(0.21, 0.24, 0.22), Color.WHITE)
	var hair := LowPolyBuilder.new()
	hair.box(Vector3(0.0, 0.96, 0.01), Vector3(0.23, 0.07, 0.24), Color.WHITE)
	hair.box(Vector3(0.0, 0.85, 0.1), Vector3(0.23, 0.2, 0.05), Color.WHITE)
	var looks := Country.pack.passenger_looks().looks
	_riders = _rider_batch(torso, order.size())
	_rider_heads = _rider_batch(head, order.size())
	_rider_hair = _rider_batch(hair, order.size())
	for i in order.size():
		_seat_looks.append(looks[random.randi_range(0, looks.size() - 1)])
		_seat_rider(i)


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
	var z := _cab_z + 1.72
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
		var elbow := Vector3(spec.driver_seat_x + side * 0.3, 1.12, _cab_z + 1.62)
		var reach := hand - elbow
		var facing := Basis.looking_at(reach, Vector3.UP)
		_sleeves[i].transform = Transform3D(facing * Basis.from_scale(Vector3(1.0, 1.0, reach.length())), elbow)
		_hands[i].transform = Transform3D(facing, hand)


func _build_interior_mirror() -> void:
	var y := _top_y - 0.5
	var z := _cab_z + 0.4
	var x := 0.1 * float(spec.door_side)
	var b := LowPolyBuilder.new()
	b.box(Vector3(x, y + 0.2275, z), Vector3(0.05, 0.245, 0.05), DARK)
	b.box(Vector3(x, y, z), Vector3(0.46, 0.21, 0.04), DARK)
	b.box(Vector3(x, y, z + 0.022), Vector3(MIRROR_GLASS.x, MIRROR_GLASS.y, 0.005), Color(0.42, 0.5, 0.56))
	var mirror := MeshInstance3D.new()
	mirror.mesh = b.build(LowPolyBuilder.vertex_colour_material())
	_body.add_child(mirror)
	_mirror_face = MeshInstance3D.new()
	_mirror_face.mesh = DriverFigure.build_head(driver_look, mirror_window(spec.door_side))
	# The mirror shows the face as the windscreen lights it, not the cab's shade, so
	# every skin tone stays readable.
	var reflection := LowPolyBuilder.vertex_colour_material()
	reflection.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	reflection.albedo_color = MIRROR_TINT
	_mirror_face.material_override = reflection
	_mirror_face.transform = Transform3D(Basis.IDENTITY, Vector3(x, y, z)) * mirror_face_transform(spec.door_side)
	_body.add_child(_mirror_face)


## The face from the middle of the mirror: scaled down, squashed flat and turned
## to look back at the driver.
static func mirror_face_transform(door_side: int) -> Transform3D:
	var turned := Basis(Vector3.UP, PI) * Basis.from_scale(Vector3(1.0, 1.0, MIRROR_FLAT) * MIRROR_FACE_SCALE)
	var offset := Vector3(MIRROR_FACE_OFFSET.x * float(door_side), MIRROR_FACE_OFFSET.y, MIRROR_GLASS_FRONT + MIRROR_FACE_OFFSET.z)
	return Transform3D(turned, offset)


## The part of the head that the glass can show, measured on the head itself, so
## a tall hat or long braids stop at the frame. The head is turned to face the
## driver, so its sides and its back are the other way round in the bus.
static func mirror_window(door_side: int) -> AABB:
	var place := mirror_face_transform(door_side).origin
	var half := MIRROR_GLASS / 2.0 - Vector2.ONE * MIRROR_MARGIN
	var depth := MIRROR_FLAT * MIRROR_FACE_SCALE
	var low := Vector3((place.x - half.x) / MIRROR_FACE_SCALE, (-half.y - place.y) / MIRROR_FACE_SCALE, -1.0)
	var high := Vector3((place.x + half.x) / MIRROR_FACE_SCALE, (half.y - place.y) / MIRROR_FACE_SCALE, (place.z - MIRROR_GLASS_FRONT) / depth)
	return AABB(low, high - low)


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


func _lit_lamp(builder: LowPolyBuilder, colour: Color, parent: Node3D = null) -> MeshInstance3D:
	var lamp := MeshInstance3D.new()
	lamp.mesh = builder.build(_flat_material(colour))
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.visible = false
	(_body if parent == null else parent).add_child(lamp)
	return lamp


func _flat_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


## Headlamps and tail lamps that glow, a strip light along the cabin roof, and
## up to two real lights, as the graphics level allows: a headlight beam on the
## road and a cabin light that only lights the bus itself.
func _build_night_lights() -> void:
	var heads := LowPolyBuilder.new()
	var tails := LowPolyBuilder.new()
	var cabin := LowPolyBuilder.new()
	var chiva := spec.body_style == "chiva"
	for side: float in [-1.0, 1.0]:
		if chiva:
			heads.box(Vector3(side * 0.62, 1.08, _front_z - 0.045), Vector3(0.24, 0.2, 0.03), Color.WHITE)
		else:
			heads.box(Vector3(side * 0.95, 0.82, _front_z - 0.012), Vector3(0.36, 0.16, 0.03), Color.WHITE)
		if _trailer == null:
			tails.box(Vector3(side * (_half_width - 0.24), 1.05, _rear_z + 0.012), Vector3(0.34, 0.16, 0.03), Color.WHITE)
	var roof := spec.body_height - (0.32 if chiva else 0.26)
	var from_z := _cab_z + 0.6
	var to_z := _rear_z - 0.6
	cabin.box(Vector3(0.0, roof, (from_z + to_z) / 2.0), Vector3(0.18, 0.03, to_z - from_z), Color.WHITE)
	_night_lamps.append(_lit_lamp(heads, HEADLAMP))
	_night_lamps.append(_lit_lamp(tails, TAIL_LAMP))
	_night_lamps.append(_lit_lamp(cabin, CABIN_LAMP))
	if _trailer != null:
		var tail := spec.trailer_wheelbase + spec.trailer_overhang
		var trailer_tails := LowPolyBuilder.new()
		var trailer_cabin := LowPolyBuilder.new()
		for side: float in [-1.0, 1.0]:
			trailer_tails.box(Vector3(side * (_half_width - 0.24), 1.05, tail + 0.02), Vector3(0.34, 0.16, 0.03), Color.WHITE)
		trailer_cabin.box(Vector3(0.0, roof, (1.2 + tail - 0.6) / 2.0), Vector3(0.18, 0.03, tail - 1.8), Color.WHITE)
		_night_lamps.append(_lit_lamp(trailer_tails, TAIL_LAMP, _trailer))
		_night_lamps.append(_lit_lamp(trailer_cabin, CABIN_LAMP, _trailer))
	_headlight = SpotLight3D.new()
	_headlight.position = Vector3(0.0, 1.0, _front_z - 0.1)
	_headlight.rotation.x = deg_to_rad(-3.5)
	_headlight.spot_range = 45.0
	_headlight.spot_angle = 30.0
	_headlight.spot_attenuation = 0.25
	_headlight.spot_angle_attenuation = 0.6
	_headlight.light_energy = 5.0
	_headlight.light_color = HEADLAMP
	_headlight.shadow_enabled = false
	_headlight.visible = false
	_body.add_child(_headlight)
	_cabin_light = OmniLight3D.new()
	_cabin_light.position = Vector3(0.0, roof - 0.15, (_cab_z + _rear_z) / 2.0)
	_cabin_light.omni_range = maxf(spec.overall_length() * 0.6, 5.0)
	_cabin_light.light_energy = 0.9
	_cabin_light.light_color = CABIN_LAMP
	_cabin_light.light_cull_mask = 1 << (BUS_LAYER - 1)
	_cabin_light.shadow_enabled = false
	_cabin_light.visible = false
	_body.add_child(_cabin_light)


## Every mesh in the bus is also drawn on BUS_LAYER, so the cabin light reaches it.
func _add_to_bus_layer(node: Node) -> void:
	for child in node.get_children():
		if child is VisualInstance3D:
			(child as VisualInstance3D).set_layer_mask_value(BUS_LAYER, true)
		_add_to_bus_layer(child)


func _on_lighting(_lights: float, headlights: bool) -> void:
	_lights_on = headlights
	_apply_lights()


func _apply_lights() -> void:
	for lamp in _night_lamps:
		lamp.visible = _lights_on
	var profile := GraphicsQuality.current_profile()
	var allowed: int = profile["bus_lights"]
	_headlight.visible = _lights_on and allowed >= 1
	_cabin_light.visible = _lights_on and allowed >= 2
	_drops_allowed = profile["windscreen_drops"]


## Two blades on the windscreen, and raindrops on the glass that they wipe away.
func _build_wipers() -> void:
	var glass_z := (_cab_z if spec.body_style == "chiva" else _front_z) + 0.05
	var bottom := 1.15
	var width := spec.body_width - 0.1
	var height := _top_y - bottom
	var blade := spec.body_width * 0.32
	var pivots: Array[Vector2] = [Vector2(-spec.body_width * 0.1, 0.06), Vector2(spec.body_width * 0.34, 0.06)]
	var arm := LowPolyBuilder.new()
	arm.box(Vector3(-blade / 2.0, 0.0, 0.0), Vector3(blade, 0.025, 0.02), DARK)
	arm.box(Vector3(-blade * 0.55, 0.0, -0.012), Vector3(blade * 0.9, 0.04, 0.015), Color(0.05, 0.05, 0.06))
	var mesh := arm.build(LowPolyBuilder.vertex_colour_material())
	for pivot in pivots:
		var wiper := MeshInstance3D.new()
		wiper.mesh = mesh
		wiper.position = Vector3(pivot.x, bottom + pivot.y, glass_z - 0.035)
		wiper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(wiper)
		_wipers.append(wiper)
	_drops_material = ShaderMaterial.new()
	_drops_material.shader = WINDSCREEN_SHADER
	_drops_material.set_shader_parameter("pane_size", Vector2(width, height))
	_drops_material.set_shader_parameter("pivot_a", pivots[0])
	_drops_material.set_shader_parameter("pivot_b", pivots[1])
	_drops_material.set_shader_parameter("blade", blade)
	_drops_material.set_shader_parameter("sweep", WIPER_SWEEP)
	var pane := QuadMesh.new()
	pane.size = Vector2(width, height)
	_drops = MeshInstance3D.new()
	_drops.mesh = pane
	_drops.material_override = _drops_material
	_drops.position = Vector3(0.0, bottom + height / 2.0, glass_z + 0.025)
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_drops.visible = false
	_body.add_child(_drops)


## Wipers run while it rains, faster as it pours, and finish their sweep to rest
## when it stops.
func _process(dt: float) -> void:
	if _wipers.is_empty():
		return
	var running := _rain > WIPER_START_RAIN
	var resting := is_zero_approx(fmod(_wiper_phase, 1.0))
	if running or not resting:
		var period := lerpf(WIPER_SLOW, WIPER_FAST, clampf(_rain, 0.0, 1.0))
		var before := _wiper_phase
		_wiper_phase += dt / period
		if not running and floorf(_wiper_phase) > floorf(before):
			_wiper_phase = floorf(_wiper_phase)
		_drops_material.set_shader_parameter("wiper_period", period)
	var angle := wiper_angle(_wiper_phase)
	for wiper in _wipers:
		wiper.rotation.z = angle
	var show_drops := _rain > 0.0 and _drops_allowed
	if _warm_frames > 0:
		_warm_frames -= 1
		show_drops = true
	_drops.visible = show_drops
	if show_drops:
		_drops_material.set_shader_parameter("wet", _rain)
		_drops_material.set_shader_parameter("wiper_phase", _wiper_phase)


## Blade rotation for a count of sweeps: flat at whole numbers, fully up at halves.
static func wiper_angle(phase: float) -> float:
	return -WIPER_SWEEP * (1.0 - cos(TAU * phase)) / 2.0
