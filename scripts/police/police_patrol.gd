class_name PolicePatrol
extends RefCounted
## When the transit police turn up and what a fault in front of them costs.
## Pure logic: PoliceSystem tells it the time and whether the patrol is close,
## and it answers with fines.

enum State { AWAY, WATCHING }

## Faults in front of the police within this many seconds count once.
const FAULT_COOLDOWN := 6.0

var state: State = State.AWAY
var offences: int = 0
var fined_coins: int = 0
var run_ended: bool = false

var _difficulty: Difficulty
var _random := RandomNumberGenerator.new()
var _until_next: float = 0.0
var _watch_left: float = 0.0
var _cooldown: float = 0.0


func _init(difficulty: Difficulty, random_seed: int) -> void:
	_difficulty = difficulty
	_random.seed = random_seed
	_until_next = _next_wait()


## Moves time on. Returns true on the tick a patrol turns up.
func update(dt: float) -> bool:
	_cooldown = maxf(_cooldown - dt, 0.0)
	if not _difficulty.has_police() or run_ended:
		return false
	if state == State.WATCHING:
		_watch_left -= dt
		if _watch_left <= 0.0:
			state = State.AWAY
			_until_next = _next_wait()
		return false
	_until_next -= dt
	if _until_next <= 0.0:
		state = State.WATCHING
		_watch_left = _difficulty.police_watch_seconds
		return true
	return false


func is_watching() -> bool:
	return state == State.WATCHING


## A fault the patrol saw. Returns the fine in coins and whether it ends the run,
## or an empty Dictionary if nothing happens.
func witness(near: bool) -> Dictionary:
	if not is_watching() or not near or run_ended or _cooldown > 0.0 or _difficulty.fines.is_empty():
		return {}
	_cooldown = FAULT_COOLDOWN
	var fines := _difficulty.fines
	if _difficulty.police_ends_run and offences >= fines.size():
		offences += 1
		run_ended = true
		return {"fine": 0, "ends_run": true, "offence": offences}
	var fine := fines[mini(offences, fines.size() - 1)]
	offences += 1
	fined_coins += fine
	return {"fine": fine, "ends_run": false, "offence": offences}


## Seconds until the next patrol, for the HUD and tests.
func time_until_next() -> float:
	return _until_next


func _next_wait() -> float:
	return _random.randf_range(_difficulty.police_every.x, _difficulty.police_every.y)
