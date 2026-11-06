class_name PassengerCrowd
extends Node3D
## The people you can see. Purely visual: it follows passenger events and never
## decides who boards. Walkers come from a small pool to keep phones happy.

const MAX_WAITING := 8
const SPAWN_DISTANCE := 260.0
const WALK_SPEED := 1.7
const QUEUE_GAP := 0.75
const SHIRTS: Array[Color] = [
	Color(0.2, 0.4, 0.75), Color(0.8, 0.3, 0.25), Color(0.25, 0.6, 0.4),
	Color(0.85, 0.65, 0.2), Color(0.55, 0.35, 0.65), Color(0.3, 0.3, 0.35),
]

## Spawned walkers in each role, in order. Public for tests.
var waiting: Array[Walker] = []
var leaving: Array[Walker] = []
var boarding: Array[Walker] = []

var _route: RouteRunner
var _ground: GroundSurface
var _pool: Array[Walker] = []
var _body_meshes: Array[ArrayMesh] = []
var _leg_mesh: ArrayMesh
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

	func step(dt: float, speed: float, ground: GroundSurface) -> bool:
		var flat := Vector2(target.x - position.x, target.z - position.z)
		var distance := flat.length()
		if distance < 0.08:
			left_leg.rotation.x = 0.0
			right_leg.rotation.x = 0.0
			return true
		var move := flat.normalized() * minf(speed * dt, distance)
		position.x += move.x
		position.z += move.y
		rotation.y = atan2(-flat.x, -flat.y)
		stride += dt * speed * 6.0
		var swing := sin(stride) * 0.6
		left_leg.rotation.x = swing
		right_leg.rotation.x = -swing
		position.y = ground.height_at(Vector2(position.x, position.z)) + absf(cos(stride)) * 0.04
		return false


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
		walker.rotation.y = stop.heading + PI / 2.0
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
	var body := MeshInstance3D.new()
	body.mesh = _body_meshes[_random.randi_range(0, _body_meshes.size() - 1)]
	walker.add_child(body)
	walker.left_leg = _build_leg(-0.11)
	walker.right_leg = _build_leg(0.11)
	walker.add_child(walker.left_leg)
	walker.add_child(walker.right_leg)
	return walker


func _build_leg(x: float) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(x, 0.85, 0.0)
	var leg := MeshInstance3D.new()
	leg.mesh = _leg_mesh
	hip.add_child(leg)
	return hip


func _build_meshes() -> void:
	var material := LowPolyBuilder.vertex_colour_material()
	for shirt in SHIRTS:
		var b := LowPolyBuilder.new()
		b.box(Vector3(0.0, 1.2, 0.0), Vector3(0.44, 0.62, 0.24), shirt)
		b.box(Vector3(0.0, 1.66, 0.0), Vector3(0.24, 0.26, 0.24), Color(0.85, 0.68, 0.55))
		for side: float in [-0.27, 0.27]:
			b.box(Vector3(side, 1.18, 0.0), Vector3(0.1, 0.56, 0.12), shirt)
		_body_meshes.append(b.build(material))
	var leg := LowPolyBuilder.new()
	leg.box(Vector3(0.0, -0.42, 0.0), Vector3(0.17, 0.85, 0.2), Color(0.18, 0.2, 0.28))
	_leg_mesh = leg.build(material)
