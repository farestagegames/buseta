class_name PassengerCrowd
extends Node3D
## The people you can see. Purely visual: it follows passenger events and never
## decides who boards. Walkers come from a small pool to keep phones happy, and are
## dressed as one of the pack's passenger looks each time they step out. Once
## aboard they belong to the bus body, so they ride its suspension and leave with
## it, and they stay on their feet until they reach a seat.

const MAX_WAITING := 8
const SPAWN_DISTANCE := 260.0
const WALK_SPEED := 1.7
const CABIN_SPEED := 1.35
const AISLE_GAP := 0.8
const PAY_SECONDS := 0.8
const PAY_ARM_RAISE := 1.35
const WAVE_ARM := 2.7
const QUEUE_GAP := 0.8
## Keep at least this far apart, in metres.
const PERSONAL_SPACE := 0.62
## Two people in the same look still differ a little in height.
const HEIGHT_VARIETY := 0.04

## Spawned walkers in each role, in order. Public for tests.
var waiting: Array[Walker] = []
var leaving: Array[Walker] = []
var boarding: Array[Walker] = []
var aboard: Array[Walker] = [] ## On the bus, heading for a seat.
var getting_off: Array[Walker] = [] ## On the bus, heading for the door.
var selling: Array[Walker] = [] ## Vendors working the aisle.
var vendor_waiting: Walker = null ## A vendor at the stop ahead, not in the queue.

var _route: RouteRunner
var _visual: BusVisual
var _kerb_side: float = 1.0 ## Which side of the bus the pavement is on.
var _cabin: CabinLayout
var _ground: GroundSurface
var _pool: Array[Walker] = []
var _outfits: Array[Outfit] = []
var _vendor_outfits: Array[Outfit] = []
var _outfit_of: Dictionary = {} ## PassengerLook to its Outfit.
var _deck: Array[int] = [] ## Outfits still to deal before shuffling again.
var _spawned_for: int = -1
var _door: Vector3 = Vector3.ZERO
var _doors_shut: bool = true
var _bus_forward: Vector2 = Vector2.UP
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
	var leg_swing: float = 1.0 ## Less in a long skirt.
	var look: PassengerLook
	var idle_time: float = 0.0
	var base_yaw: float = 0.0
	var path: Array[Vector3] = [] ## Points still to walk through the bus.
	var pay_left: float = 0.0
	var seat: int = -1
	var waving: bool = false ## Flagging down the bus.
	var is_vendor: bool = false

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
		_stride(flat, dt, speed)
		position.y = ground.height_at(Vector2(position.x, position.z)) + absf(cos(stride)) * 0.04
		return false

	## Follows the path through the bus, step by step. True once it runs out.
	func walk_path(dt: float, speed: float) -> bool:
		if pay_left > 0.0:
			pay_left -= dt
			right_arm.rotation.x = lerpf(right_arm.rotation.x, PAY_ARM_RAISE, minf(dt * 9.0, 1.0))
			return false
		if path.is_empty():
			return true
		var ahead := path[0] - position
		var flat := Vector2(ahead.x, ahead.z)
		var distance := flat.length()
		speed *= pace
		if distance > 0.001:
			position += ahead * minf(speed * dt / distance, 1.0)
			_stride(flat, dt, speed)
		if distance <= speed * dt:
			position = path[0]
			path.remove_at(0)
		return false

	## At the machine, this is the moment of paying.
	func start_paying() -> void:
		pay_left = PAY_SECONDS

	func hold_still(dt: float) -> void:
		_idle(dt)

	func _stride(direction: Vector2, dt: float, speed: float) -> void:
		base_yaw = atan2(-direction.x, -direction.y)
		rotation.y = base_yaw
		stride += dt * speed * 5.5
		var swing := sin(stride) * 0.55
		left_leg.rotation.x = swing * leg_swing
		right_leg.rotation.x = -swing * leg_swing
		left_arm.rotation.x = -swing * 0.8
		right_arm.rotation.x = swing * 0.8

	## Standing people shift their weight and glance around, so a queue looks alive.
	func _idle(dt: float) -> void:
		idle_time += dt
		var ease_out := minf(dt * 6.0, 1.0)
		left_leg.rotation.x = lerpf(left_leg.rotation.x, 0.0, ease_out)
		right_leg.rotation.x = lerpf(right_leg.rotation.x, 0.0, ease_out)
		left_arm.rotation.x = lerpf(left_arm.rotation.x, 0.0, ease_out)
		var arm_goal := WAVE_ARM + sin(idle_time * 7.0) * 0.28 if waving else 0.0
		right_arm.rotation.x = lerpf(right_arm.rotation.x, arm_goal, ease_out)
		rotation.y = base_yaw + sin(idle_time * 0.7 + stride) * 0.22
		rotation.z = sin(idle_time * 0.45 + stride) * 0.025


## One look's meshes, built once and shared by every walker wearing it.
class Outfit:
	var look: PassengerLook
	var body: ArrayMesh
	var arm: ArrayMesh
	var leg: ArrayMesh

	func _init(passenger: PassengerLook, material: Material) -> void:
		look = passenger
		body = PassengerFigure.build_body(look, material)
		arm = PassengerFigure.build_arm(look, material)
		leg = PassengerFigure.build_leg(look, material)


func setup(route: RouteRunner, ground: GroundSurface, visual: BusVisual) -> void:
	_route = route
	_ground = ground
	_visual = visual
	_cabin = visual.cabin
	_kerb_side = float(visual.spec.door_side)
	_random.seed = 77
	_build_meshes()
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.stop_session_started.connect(_on_session_started)
	GameEvents.passenger_boarded.connect(_on_boarded)
	GameEvents.passenger_alighted.connect(_on_alighted)
	GameEvents.stop_served.connect(_on_stop_finished.unbind(3))
	GameEvents.shift_completed.connect(_on_shift_completed.unbind(1))
	GameEvents.vendor_boarded.connect(_on_vendor_boarded)
	GameEvents.vendor_left.connect(_on_vendor_left)


## Moves two people apart along the line between them. Pure, so it can be tested.
## Returns how far each should move, as a pair of offsets.
static func separation(a: Vector2, b: Vector2, space: float) -> Array[Vector2]:
	var gap := b - a
	var distance := gap.length()
	if distance >= space:
		return [Vector2.ZERO, Vector2.ZERO]
	var direction := gap / distance if distance > 0.001 else Vector2.RIGHT
	var push := direction * (space - distance) / 2.0
	return [-push, push]


## People join the queue in the order they stand from the door, so nobody cuts in.
static func queue_order(door: Vector2, spots: Array[Vector2]) -> Array[int]:
	var order: Array[int] = []
	for i in spots.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return door.distance_squared_to(spots[a]) < door.distance_squared_to(spots[b]))
	return order


func _process(dt: float) -> void:
	for i in waiting.size():
		var walker := waiting[i]
		if _queueing:
			walker.target = _queue_point(i)
		walker.step(dt, WALK_SPEED, _ground)
	for i in range(boarding.size() - 1, -1, -1):
		var walker := boarding[i]
		walker.target = _door
		if _doors_shut or walker.step(dt, WALK_SPEED * 1.2, _ground):
			boarding.remove_at(i)
			_step_aboard(walker)
	_walk_to_seats(dt)
	_walk_to_door(dt)
	for vendor in selling:
		vendor.hold_still(dt)
	for i in range(leaving.size() - 1, -1, -1):
		if leaving[i].step(dt, WALK_SPEED, _ground):
			_release(leaving[i])
			leaving.remove_at(i)
	_keep_apart()


## People keep their place in the aisle, so the next in line waits behind whoever
## is paying.
func _walk_to_seats(dt: float) -> void:
	var ahead: Walker = null
	for walker: Walker in aboard.duplicate():
		if ahead != null and walker.position.distance_to(ahead.position) < AISLE_GAP:
			walker.hold_still(dt)
			ahead = walker
			continue
		var points_left := walker.path.size()
		if walker.walk_path(dt, CABIN_SPEED):
			_sit_down(walker)
			continue
		var at_machine := points_left > walker.path.size() and walker.path.size() == CabinLayout.POINTS_AFTER_PAYING
		if at_machine and _route.kind != RouteStop.Kind.STATION and not walker.is_vendor:
			walker.start_paying()
			GameEvents.passenger_paid.emit()
		ahead = walker


func _walk_to_door(dt: float) -> void:
	for walker: Walker in getting_off.duplicate():
		if _doors_shut:
			getting_off.erase(walker)
			_release(walker)
		elif walker.walk_path(dt, CABIN_SPEED):
			getting_off.erase(walker)
			_walk_away(walker)


func _keep_apart() -> void:
	var everyone: Array[Walker] = []
	everyone.append_array(waiting)
	everyone.append_array(boarding)
	everyone.append_array(leaving)
	for i in everyone.size():
		for j in range(i + 1, everyone.size()):
			var first := everyone[i]
			var second := everyone[j]
			var moves := separation(Vector2(first.position.x, first.position.z), Vector2(second.position.x, second.position.z), PERSONAL_SPACE)
			first.position += Vector3(moves[0].x, 0.0, moves[0].y)
			second.position += Vector3(moves[1].x, 0.0, moves[1].y)


func _on_telemetry(data: BusTelemetry) -> void:
	_door = data.door_position
	_doors_shut = data.doors_closed
	_bus_forward = Vector2(-sin(data.heading), -cos(data.heading))
	var stop := _route.current_stop()
	if stop == null or _route.stop_index == _spawned_for:
		return
	if Vector2(data.position.x, data.position.z).distance_to(stop.position) < SPAWN_DISTANCE:
		_spawn_waiting(stop)


func _spawn_waiting(stop: RouteStop) -> void:
	_spawned_for = _route.stop_index
	# Anyone still here was left at the last stop, and that stop is well behind.
	for walker in waiting:
		_release(walker)
	waiting.clear()
	_queueing = false
	if vendor_waiting != null:
		_release(vendor_waiting)
		vendor_waiting = null
	var forward := stop.forward()
	var right := Vector2(-forward.y, forward.x) * _kerb_side
	if stop.vendor:
		var pitch := stop.position + right * (stop.waiting_distance() + 0.6) + forward * 5.0
		vendor_waiting = _take_walker(_vendor_outfits[_random.randi_range(0, _vendor_outfits.size() - 1)])
		vendor_waiting.is_vendor = true
		vendor_waiting.position = Vector3(pitch.x, _ground.height_at(pitch), pitch.y)
		vendor_waiting.target = vendor_waiting.position
	for i in mini(stop.waiting, MAX_WAITING):
		var spot := stop.position + right * (stop.waiting_distance() + _random.randf_range(0.0, 1.2)) \
			+ forward * (float(i) * 1.1 - 4.0)
		var walker := _take_walker()
		walker.position = Vector3(spot.x, _ground.height_at(spot), spot.y)
		walker.target = walker.position
		walker.base_yaw = stop.heading + PI / 2.0 * _kerb_side
		walker.rotation.y = walker.base_yaw
		walker.waving = stop.kind == RouteStop.Kind.HAIL
		waiting.append(walker)


func _queue_point(place: int) -> Vector3:
	var stop := _route.current_stop()
	if stop == null:
		return _door
	var forward := stop.forward()
	var right := Vector2(-forward.y, forward.x) * _kerb_side
	var spot := Vector2(_door.x, _door.z) + right * 0.6 - forward * (float(place + 1) * QUEUE_GAP)
	return Vector3(spot.x, _door.y, spot.y)


func _on_session_started(_stop_index: int, _alighting: int, _boarding: int) -> void:
	_queueing = true
	for walker in waiting:
		walker.waving = false
	var spots: Array[Vector2] = []
	for walker in waiting:
		spots.append(Vector2(walker.position.x, walker.position.z))
	var ordered: Array[Walker] = []
	for index in queue_order(Vector2(_door.x, _door.z), spots):
		ordered.append(waiting[index])
	waiting = ordered


func _on_boarded(_stop_index: int) -> void:
	if waiting.is_empty():
		return
	var walker: Walker = waiting.pop_front()
	walker.seat = _visual.reserve_seat()
	boarding.append(walker)


## Through the door and into the bus. If the doors shut first, they squeezed on.
func _step_aboard(walker: Walker) -> void:
	walker.reparent(_visual.cabin_floor(), false)
	var goal := _visual.seat_position(walker.seat) if not walker.is_vendor else _cabin.vendor_spot
	walker.path = _cabin.boarding_path(goal)
	if _doors_shut:
		walker.position = _cabin.pay_point
		walker.path = walker.path.slice(-CabinLayout.POINTS_AFTER_PAYING)
	else:
		walker.position = _cabin.kerb
	aboard.append(walker)


func _sit_down(walker: Walker) -> void:
	aboard.erase(walker)
	if walker.is_vendor:
		selling.append(walker)
		return
	_visual.fill_seat(walker.seat, walker.look)
	_release(walker)


## A vendor gets on once everyone else is aboard.
func _on_vendor_boarded() -> void:
	if vendor_waiting == null:
		return
	vendor_waiting.seat = -1
	boarding.append(vendor_waiting)
	vendor_waiting = null


## They finish working the aisle and head for the door at the next chance.
func _on_vendor_left() -> void:
	for vendor in selling:
		vendor.path = _cabin.alighting_path()
		getting_off.append(vendor)
	selling.clear()


## Whoever stands up from the last seat walks out, looking as they did sitting.
## While more are aboard than there are seats, someone standing gets off instead,
## no seat empties, and they are dressed from the deck.
func _on_alighted(_stop_index: int) -> void:
	var outfit: Outfit = null
	if _visual.riders_standing() == 0:
		outfit = _outfit_of.get(_visual.rider_look(_visual.visible_riders() - 1)) as Outfit
	var walker := _take_walker(outfit)
	walker.reparent(_visual.cabin_floor(), false)
	walker.position = _cabin.exit_start
	walker.path = _cabin.alighting_path()
	getting_off.append(walker)


## Queue is behind the door, so people getting off walk forward and clear of it.
func _walk_away(walker: Walker) -> void:
	walker.reparent(self, false)
	walker.position = _door
	var right := Vector2(-_bus_forward.y, _bus_forward.x) * _kerb_side
	var goal := Vector2(_door.x, _door.z) + right * _random.randf_range(2.6, 4.0) + _bus_forward * _random.randf_range(3.0, 10.0)
	walker.target = Vector3(goal.x, _door.y, goal.y)
	leaving.append(walker)


## Everyone is off at the depot, and nobody is left standing in the bus.
func _on_shift_completed() -> void:
	for walker: Walker in aboard + getting_off + selling:
		_release(walker)
	aboard.clear()
	getting_off.clear()
	selling.clear()


func _on_stop_finished() -> void:
	_queueing = false
	# Anyone left behind stays at the stop and walks back from the kerb.
	for walker in waiting:
		walker.target = walker.position


## Someone from the pool, dressed in the given outfit or the next from the deck.
func _take_walker(outfit: Outfit = null) -> Walker:
	var walker: Walker
	if _pool.is_empty():
		walker = _build_walker()
		add_child(walker)
	else:
		walker = _pool.pop_back()
	_dress(walker, outfit if outfit != null else _next_outfit())
	walker.visible = true
	return walker


## Deals looks from a shuffled deck, so a queue rarely shows the same person twice.
func _next_outfit() -> Outfit:
	if _deck.is_empty():
		for i in _outfits.size():
			_deck.append(i)
		for i in range(_deck.size() - 1, 0, -1):
			var swap := _random.randi_range(0, i)
			var held := _deck[i]
			_deck[i] = _deck[swap]
			_deck[swap] = held
	return _outfits[_deck.pop_back()]


func _dress(walker: Walker, outfit: Outfit) -> void:
	walker.look = outfit.look
	(walker.get_child(0) as MeshInstance3D).mesh = outfit.body
	for leg: Node3D in [walker.left_leg, walker.right_leg]:
		(leg.get_child(0) as MeshInstance3D).mesh = outfit.leg
	for arm: Node3D in [walker.left_arm, walker.right_arm]:
		(arm.get_child(0) as MeshInstance3D).mesh = outfit.arm
	walker.scale = Vector3.ONE * outfit.look.size * _random.randf_range(1.0 - HEIGHT_VARIETY, 1.0 + HEIGHT_VARIETY)
	walker.pace = outfit.look.pace
	walker.leg_swing = PassengerFigure.leg_swing(outfit.look)


func _release(walker: Walker) -> void:
	walker.visible = false
	walker.path = []
	walker.pay_left = 0.0
	walker.seat = -1
	walker.waving = false
	walker.is_vendor = false
	if walker.get_parent() != self:
		walker.reparent(self, false)
	_pool.append(walker)


func _build_walker() -> Walker:
	var walker := Walker.new()
	walker.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	walker.add_child(MeshInstance3D.new())
	var hip := PassengerFigure.HIP
	var shoulder := PassengerFigure.SHOULDER
	walker.left_leg = _limb(Vector3(-hip.x, hip.y, hip.z))
	walker.right_leg = _limb(hip)
	walker.left_arm = _limb(Vector3(-shoulder.x, shoulder.y, shoulder.z))
	walker.right_arm = _limb(shoulder)
	for limb: Node3D in [walker.left_leg, walker.right_leg, walker.left_arm, walker.right_arm]:
		walker.add_child(limb)
	walker.stride = _random.randf_range(0.0, TAU)
	return walker


func _limb(pivot: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.position = pivot
	joint.add_child(MeshInstance3D.new())
	return joint


## Every look in the pack, built once with one shared material.
func _build_meshes() -> void:
	var material := LowPolyBuilder.vertex_colour_material()
	var cast := Country.pack.passenger_looks()
	for look in cast.looks:
		var outfit := Outfit.new(look, material)
		_outfits.append(outfit)
		_outfit_of[look] = outfit
	for look in cast.vendors:
		_vendor_outfits.append(_outfit_of[look] if _outfit_of.has(look) else Outfit.new(look, material))
