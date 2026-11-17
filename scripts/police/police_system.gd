class_name PoliceSystem
extends Node
## Turns up a transit police patrol now and then, and fines faults it can see.
## PolicePatrol decides; this node finds the patrol car in traffic, checks the
## bus is in its view cone (PoliceSight) with no building in between, and
## listens for faults. It only speaks through GameEvents.

## Eye height above the bus's road level for the sight ray, in metres.
const EYE_HEIGHT := 1.6
## A patrol this far behind is swapped for another car closer by, so it stays around.
const LOST := 180.0
## A lost patrol is looked for again at most this often, so it does not hop between cars.
const REASSIGN_SECONDS := 5.0
## Speeding counts once it has lasted this long.
const SPEEDING_SECONDS := 2.0

var patrol: PolicePatrol

var _traffic: TrafficSystem
var _bus_spot := Vector2.ZERO
var _bus_height: float = 0.0
var _near: bool = false
var _held: bool = false
var _reassign_wait: float = 0.0


func setup(traffic: TrafficSystem, difficulty: Difficulty, random_seed: int) -> void:
	_traffic = traffic
	patrol = PolicePatrol.new(difficulty, random_seed)
	GameEvents.bus_telemetry_updated.connect(func(data: BusTelemetry) -> void:
		_bus_spot = Vector2(data.position.x, data.position.z)
		_bus_height = data.position.y)
	GameEvents.shift_held_changed.connect(func(held: bool) -> void: _held = held)
	GameEvents.red_light_run.connect(_fault.bind("ran a red light"))
	GameEvents.speeding_started.connect(_fault.bind("speeding"))
	GameEvents.bus_collided.connect(func(impact: float) -> void:
		if impact >= ScoreKeeper.LOST_COLLISION_SPEED:
			_fault("collision"))
	GameEvents.obstacle_hit.connect(func(kind: String, _loss: float) -> void:
		if kind == "moto" or kind == "stall":
			_fault("hit a motorbike" if kind == "moto" else "hit a stall"))


func _physics_process(dt: float) -> void:
	if patrol == null or _held:
		return
	if patrol.update(dt):
		if _traffic.assign_police(_bus_spot):
			GameEvents.hint_shown.emit("Transit police about: drive carefully")
	_reassign_wait = maxf(_reassign_wait - dt, 0.0)
	if patrol.is_watching():
		if (_traffic.police_index < 0 or _traffic.police_distance(_bus_spot) > LOST) and _reassign_wait <= 0.0:
			_reassign_wait = REASSIGN_SECONDS
			_traffic.assign_police(_bus_spot)
	elif _traffic.police_index >= 0:
		_traffic.clear_police()
	var near := patrol.is_watching() and _sees_bus()
	if near != _near:
		_near = near
		GameEvents.police_nearby.emit(near)


## True while the patrol can see the bus.
func is_near() -> bool:
	return _near


## The bus is in the patrol car's view cone and range, and no building is in the way.
func _sees_bus() -> bool:
	if _traffic.police_index < 0:
		return false
	var eye := _traffic.police_position()
	if not PoliceSight.in_view(eye, _traffic.police_forward(), _bus_spot):
		return false
	return not _wall_between(eye, _bus_spot)


## A ray at eye height from the patrol to the bus: blocked when it hits the city's
## solid scenery (buildings, posts). The ground has no collider and the bus is not
## static, so the ray only stops early at scenery.
func _wall_between(eye: Vector2, bus: Vector2) -> bool:
	var world := get_viewport().find_world_3d() if is_inside_tree() else null
	if world == null:
		return false
	var height := _bus_height + EYE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(Vector3(eye.x, height, eye.y), Vector3(bus.x, height, bus.y))
	var hit := world.direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] is StaticBody3D


func _fault(reason: String) -> void:
	if _held:
		return
	var result := patrol.witness(_near)
	if result.is_empty():
		return
	if result["ends_run"]:
		GameEvents.police_ended_run.emit(reason)
	else:
		GameEvents.police_fined.emit(int(result["fine"]), reason)
