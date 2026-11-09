class_name PoliceSystem
extends Node
## Turns up a transit police patrol now and then, and fines faults made in front
## of it. PolicePatrol decides; this node finds the patrol car in traffic and
## listens for faults. It only speaks through GameEvents.

## The patrol sees faults this close, in metres.
const NEAR := 70.0
## A patrol this far behind is swapped for another car closer by, so it stays around.
const LOST := 180.0
## A lost patrol is looked for again at most this often, so it does not hop between cars.
const REASSIGN_SECONDS := 5.0
## Speeding counts once it has lasted this long.
const SPEEDING_SECONDS := 2.0

var patrol: PolicePatrol

var _traffic: TrafficSystem
var _bus_spot := Vector2.ZERO
var _near: bool = false
var _held: bool = false
var _reassign_wait: float = 0.0


func setup(traffic: TrafficSystem, difficulty: Difficulty, random_seed: int) -> void:
	_traffic = traffic
	patrol = PolicePatrol.new(difficulty, random_seed)
	GameEvents.bus_telemetry_updated.connect(func(data: BusTelemetry) -> void: _bus_spot = Vector2(data.position.x, data.position.z))
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
	var near := patrol.is_watching() and _traffic.police_distance(_bus_spot) < NEAR
	if near != _near:
		_near = near
		GameEvents.police_nearby.emit(near)


func is_near() -> bool:
	return _near


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
