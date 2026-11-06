class_name PassengerCrowd
extends Node3D
## The people you can see. Purely visual: it follows passenger events and never
## decides who boards. Walkers come from a small pool to keep phones happy.

const MAX_WAITING := 8
const SPAWN_DISTANCE := 260.0
const WALK_SPEED := 1.7
const QUEUE_GAP := 0.75
const LOOK_VARIETY := 18
const LOOK_PACES: Array[float] = [1.0, 1.05, 0.95, 1.1, 1.0, 0.65, 1.0, 1.05, 0.95, 1.1, 1.0, 0.65, 1.0, 1.05, 0.95, 1.1, 1.0, 0.65]

const SKINS: Array[Color] = [
	Color(0.93, 0.77, 0.65), Color(0.85, 0.66, 0.52), Color(0.68, 0.48, 0.34),
	Color(0.48, 0.32, 0.22), Color(0.33, 0.22, 0.16),
]
const HAIRS: Array[Color] = [
	Color(0.12, 0.09, 0.07), Color(0.3, 0.2, 0.12), Color(0.55, 0.38, 0.18),
	Color(0.72, 0.6, 0.35), Color(0.75, 0.75, 0.76), Color(0.45, 0.2, 0.1),
]
const TOPS: Array[Color] = [
	Color(0.2, 0.4, 0.75), Color(0.8, 0.3, 0.25), Color(0.25, 0.55, 0.4), Color(0.85, 0.65, 0.2),
	Color(0.55, 0.35, 0.65), Color(0.28, 0.3, 0.36), Color(0.85, 0.85, 0.82), Color(0.5, 0.32, 0.22),
	Color(0.15, 0.55, 0.6), Color(0.75, 0.45, 0.55),
]
const TROUSERS: Array[Color] = [
	Color(0.16, 0.2, 0.32), Color(0.1, 0.1, 0.12), Color(0.42, 0.36, 0.28),
	Color(0.3, 0.32, 0.36), Color(0.55, 0.5, 0.42),
]
const SHOE := Color(0.08, 0.08, 0.09)
const BAG_COLOURS: Array[Color] = [Color(0.2, 0.2, 0.22), Color(0.5, 0.3, 0.16), Color(0.7, 0.25, 0.25), Color(0.2, 0.35, 0.5)]

## Spawned walkers in each role, in order. Public for tests.
var waiting: Array[Walker] = []
var leaving: Array[Walker] = []
var boarding: Array[Walker] = []

var _route: RouteRunner
var _ground: GroundSurface
var _pool: Array[Walker] = []
var _body_meshes: Array[ArrayMesh] = []
var _leg_meshes: Array[ArrayMesh] = []
var _arm_meshes: Array[ArrayMesh] = []
var _spawned_for: int = -1
var _door: Vector3 = Vector3.ZERO
var _queueing: bool = false
var _random := RandomNumberGenerator.new()


class Walker:
	extends Node3D
	var target: Vector3 = Vector3.ZERO
	var stride: float = 0.0
	var left_leg: Node3D
	var right_leg: Node3D
	var left_arm: Node3D
	var right_arm: Node3D
	var pace: float = 1.0 ## Older people walk more slowly.
	var idle_time: float = 0.0
	var base_yaw: float = 0.0

	func step(dt: float, speed: float, ground: GroundSurface) -> bool:
		var flat := Vector2(target.x - position.x, target.z - position.z)
		var distance := flat.length()
		speed *= pace
		if distance < 0.08:
			_idle(dt)
			return true
		var move := flat.normalized() * minf(speed * dt, distance)
		position.x += move.x
		position.z += move.y
		base_yaw = atan2(-flat.x, -flat.y)
		rotation.y = base_yaw
		stride += dt * speed * 5.5
		var swing := sin(stride) * 0.55
		left_leg.rotation.x = swing
		right_leg.rotation.x = -swing
		left_arm.rotation.x = -swing * 0.8
		right_arm.rotation.x = swing * 0.8
		position.y = ground.height_at(Vector2(position.x, position.z)) + absf(cos(stride)) * 0.04
		return false

	## Standing people shift their weight and glance around, so a queue looks alive.
	func _idle(dt: float) -> void:
		idle_time += dt
		var ease_out := minf(dt * 6.0, 1.0)
		left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.0, ease_out)
		right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.0, ease_out)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.0, ease_out)
		right_arm.rotation.x = lerpf(right_arm.rotation.x, 0.0, ease_out)
		rotation.y = base_yaw + sin(idle_time * 0.7 + stride) * 0.22
		rotation.z = sin(idle_time * 0.45 + stride) * 0.025


func setup(route: RouteRunner, ground: GroundSurface) -> void:
	_route = route
	_ground = ground
	_random.seed = 77
	_build_meshes()
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.stop_session_started.connect(_on_session_started)
	GameEvents.passenger_boarded.connect(_on_boarded)
	GameEvents.passenger_alighted.connect(_on_alighted)
	GameEvents.stop_served.connect(_on_stop_finished.unbind(3))


func _process(dt: float) -> void:
	for i in waiting.size():
		var walker := waiting[i]
		if _queueing:
			walker.target = _queue_point(i)
		walker.step(dt, WALK_SPEED, _ground)
	for i in range(boarding.size() - 1, -1, -1):
		boarding[i].target = _door
		if boarding[i].step(dt, WALK_SPEED * 1.2, _ground):
			_release(boarding[i])
			boarding.remove_at(i)
	for i in range(leaving.size() - 1, -1, -1):
		if leaving[i].step(dt, WALK_SPEED, _ground):
			_release(leaving[i])
			leaving.remove_at(i)


func _on_telemetry(data: BusTelemetry) -> void:
	_door = data.door_position
	var stop := _route.current_stop()
	if stop == null or _route.stop_index == _spawned_for:
		return
	if Vector2(data.position.x, data.position.z).distance_to(stop.position) < SPAWN_DISTANCE:
		_spawn_waiting(stop)


func _spawn_waiting(stop: RouteStop) -> void:
	_spawned_for = _route.stop_index
	var forward := stop.forward()
	var right := Vector2(-forward.y, forward.x)
	for i in mini(stop.waiting, MAX_WAITING):
		var spot := stop.position + right * (RoadNetwork.BAY_DEPTH / 2.0 + 1.3 + _random.randf_range(0.0, 1.2)) \
			+ forward * (float(i) * 1.1 - 4.0)
		var walker := _take_walker()
		walker.position = Vector3(spot.x, _ground.height_at(spot), spot.y)
		walker.target = walker.position
		walker.base_yaw = stop.heading + PI / 2.0
		walker.rotation.y = walker.base_yaw
		waiting.append(walker)


func _queue_point(place: int) -> Vector3:
	var stop := _route.current_stop()
	if stop == null:
		return _door
	var forward := stop.forward()
	var right := Vector2(-forward.y, forward.x)
	var spot := Vector2(_door.x, _door.z) + right * 0.7 - forward * (float(place) * QUEUE_GAP)
	return Vector3(spot.x, _door.y, spot.y)


func _on_session_started(_stop_index: int, _alighting: int, _boarding: int) -> void:
	_queueing = true


func _on_boarded(_stop_index: int) -> void:
	if not waiting.is_empty():
		boarding.append(waiting.pop_front())


func _on_alighted(_stop_index: int) -> void:
	var stop := _route.current_stop()
	if stop == null:
		return
	var forward := stop.forward()
	var right := Vector2(-forward.y, forward.x)
	var walker := _take_walker()
	walker.position = _door
	var goal := Vector2(_door.x, _door.z) + right * 3.5 + forward * _random.randf_range(-9.0, 9.0)
	walker.target = Vector3(goal.x, _door.y, goal.y)
	leaving.append(walker)


func _on_stop_finished() -> void:
	_queueing = false
	# Anyone left behind stays at the stop and walks back from the kerb.
	for walker in waiting:
		walker.target = walker.position


func _take_walker() -> Walker:
	var walker: Walker
	if _pool.is_empty():
		walker = _build_walker()
		add_child(walker)
	else:
		walker = _pool.pop_back()
	walker.visible = true
	return walker


func _release(walker: Walker) -> void:
	walker.visible = false
	_pool.append(walker)


func _build_walker() -> Walker:
	var walker := Walker.new()
	walker.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var look := _random.randi_range(0, _body_meshes.size() - 1)
	var body := MeshInstance3D.new()
	body.mesh = _body_meshes[look]
	walker.add_child(body)
	var leg_mesh := _leg_meshes[_random.randi_range(0, _leg_meshes.size() - 1)]
	walker.left_leg = _limb(leg_mesh, Vector3(-0.1, 0.86, 0.0))
	walker.right_leg = _limb(leg_mesh, Vector3(0.1, 0.86, 0.0))
	var arm_mesh := _arm_meshes[look]
	walker.left_arm = _limb(arm_mesh, Vector3(-0.27, 1.46, 0.0))
	walker.right_arm = _limb(arm_mesh, Vector3(0.27, 1.46, 0.0))
	for limb: Node3D in [walker.left_leg, walker.right_leg, walker.left_arm, walker.right_arm]:
		walker.add_child(limb)
	var size := _random.randf_range(0.9, 1.08)
	walker.scale = Vector3.ONE * size
	walker.stride = _random.randf_range(0.0, TAU)
	walker.pace = LOOK_PACES[look]
	return walker


func _limb(mesh: ArrayMesh, pivot: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.position = pivot
	var limb := MeshInstance3D.new()
	limb.mesh = mesh
	joint.add_child(limb)
	return joint


func _pick(colours: Array[Color]) -> Color:
	return colours[_random.randi_range(0, colours.size() - 1)]


## A fixed set of people, mixing skin, hair, clothes, build and what they carry.
func _build_meshes() -> void:
	var material := LowPolyBuilder.vertex_colour_material()
	for i in LOOK_VARIETY:
		var top := _pick(TOPS)
		var skin := _pick(SKINS)
		var older := i % 6 == 5
		var hair := HAIRS[4] if older else _pick(HAIRS)
		var long_hair := i % 3 == 1
		var wears_skirt := i % 6 == 1
		var b := LowPolyBuilder.new()
		b.box(Vector3(0.0, 1.26, 0.0), Vector3(0.42, 0.56, 0.23), top)
		b.box(Vector3(0.0, 1.5, 0.0), Vector3(0.47, 0.1, 0.25), top)
		b.box(Vector3(0.0, 0.99, 0.0), Vector3(0.4, 0.14, 0.23), top.darkened(0.25))
		b.box(Vector3(0.0, 1.58, 0.0), Vector3(0.1, 0.1, 0.1), skin)
		b.box(Vector3(0.0, 1.73, 0.0), Vector3(0.21, 0.24, 0.22), skin)
		b.box(Vector3(0.0, 1.87, 0.01), Vector3(0.23, 0.07, 0.24), hair)
		b.box(Vector3(0.0, 1.76, 0.1), Vector3(0.23, 0.2, 0.05), hair)
		for side: float in [-0.055, 0.055]:
			b.box(Vector3(side, 1.76, -0.112), Vector3(0.035, 0.03, 0.01), Color(0.06, 0.06, 0.08))
		if long_hair:
			b.box(Vector3(0.0, 1.57, 0.12), Vector3(0.24, 0.32, 0.05), hair)
		if wears_skirt:
			b.box(Vector3(0.0, 0.78, 0.0), Vector3(0.42, 0.38, 0.28), _pick(TROUSERS))
		match i % 5:
			1:
				b.box(Vector3(0.0, 1.27, 0.17), Vector3(0.32, 0.42, 0.12), _pick(BAG_COLOURS))
			2:
				b.box(Vector3(0.33, 0.95, 0.0), Vector3(0.1, 0.24, 0.26), _pick(BAG_COLOURS))
			3:
				b.box(Vector3(0.0, 1.92, 0.0), Vector3(0.25, 0.08, 0.26), _pick(TOPS))
				b.box(Vector3(0.0, 1.89, -0.13), Vector3(0.22, 0.03, 0.1), _pick(TOPS))
		if older:
			b.box(Vector3(0.36, 0.5, -0.1), Vector3(0.04, 1.0, 0.04), Color(0.3, 0.2, 0.12))
		_body_meshes.append(b.build(material))
		var arm := LowPolyBuilder.new()
		arm.box(Vector3(0.0, -0.22, 0.0), Vector3(0.1, 0.46, 0.11), top)
		arm.box(Vector3(0.0, -0.5, 0.0), Vector3(0.09, 0.12, 0.1), skin)
		_arm_meshes.append(arm.build(material))
	for colour in TROUSERS:
		var leg := LowPolyBuilder.new()
		leg.box(Vector3(0.0, -0.39, 0.0), Vector3(0.16, 0.74, 0.18), colour)
		leg.box(Vector3(0.0, -0.8, -0.03), Vector3(0.16, 0.1, 0.26), SHOE)
		_leg_meshes.append(leg.build(material))
