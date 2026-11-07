class_name TutorialScript
extends RefCounted
## The steps of the first shift. Pure logic: it is given what the bus is doing and
## moves on when the player has done what the step asks.

const STEPS: Array[Dictionary] = [
	{"id": "pull_away", "focus": "go", "text": "Welcome, driver! Check the gear switch shows D, then hold GO to pull away. Press higher up for more power."},
	{"id": "steer", "focus": "steer", "text": "Steer to stay in the right-hand lane."},
	{"id": "brake", "focus": "brake", "text": "Now hold BRAKE to slow down. The longer you hold it, the harder it brakes."},
	{"id": "view", "focus": "view", "text": "Tap VIEW to change the camera."},
	{"id": "indicate", "focus": "indicator", "text": "You turn right ahead. Tap the right indicator to signal."},
	{"id": "follow", "focus": "map", "text": "Follow the orange line on the map to the green beacon."},
	{"id": "bay", "focus": "", "text": "Slow down, pull in to the kerb and stop beside the passengers."},
	{"id": "open", "focus": "doors", "text": "Stopped! Tap DOORS to open them."},
	{"id": "wait", "focus": "", "text": "Passengers get off first, then board and pay. Give them a moment."},
	{"id": "close", "focus": "doors", "text": "All aboard. Tap DOORS to close them."},
	{"id": "finish", "focus": "", "text": "That's it! Keep to the timetable, obey the lights and watch your speed. Good luck!"},
]
const MIN_STEP_SECONDS := 1.0
const OPTIONAL_STEP_SECONDS := 9.0
const FINISH_SECONDS := 6.0
const BEACON_DISTANCE := 70.0

var index: int = 0

var _step_time: float = 0.0


func is_finished() -> bool:
	return index >= STEPS.size()


func step() -> Dictionary:
	return STEPS[index] if not is_finished() else {}


## state holds: speed, steer, brake, view_changes, indicator, turn_passed,
## stop_distance, stop_index, parked, doors_open, doors_closed, session_done.
func update(state: Dictionary, dt: float) -> void:
	if is_finished():
		return
	_step_time += dt
	if int(state["stop_index"]) > 0 and _before_finish():
		index = STEPS.size() - 1
		_step_time = 0.0
		return
	if _step_time >= MIN_STEP_SECONDS and _is_done(state):
		index += 1
		_step_time = 0.0


func _before_finish() -> bool:
	return step()["id"] != "finish"


func _is_done(state: Dictionary) -> bool:
	match step()["id"]:
		"pull_away":
			return float(state["speed"]) >= 2.0
		"steer":
			return absf(float(state["steer"])) > 0.05 or _step_time > OPTIONAL_STEP_SECONDS
		"brake":
			return float(state["brake"]) > 0.25
		"view":
			return int(state["view_changes"]) > 0 or _step_time > OPTIONAL_STEP_SECONDS
		"indicate":
			return int(state["indicator"]) > 0 or state["turn_passed"]
		"follow":
			return float(state["stop_distance"]) < BEACON_DISTANCE
		"bay":
			return state["parked"]
		"open":
			return state["doors_open"]
		"wait":
			return state["session_done"]
		"close":
			return state["doors_closed"]
		_:
			return _step_time >= FINISH_SECONDS
