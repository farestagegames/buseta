class_name ArcadeRun
extends RefCounted
## The rules of an arcade run, as pure logic: checkpoints along the course that add
## time, boost pads that can each be used once, crashes that cost time, and the
## end when the clock runs out. Distances are along the course, in metres.

## Tuned to forgive (12 Nov feedback): more time to start, more per arch, less per crash.
const START_SECONDS := 75.0
const CHECKPOINT_SECONDS := 22.0
const CRASH_SECONDS := 2.0
const FIRST_CHECKPOINT := 180.0
const CHECKPOINT_SPACING := 280.0
const FIRST_BOOST := 330.0
const BOOST_SPACING := 420.0
const BOOST_SECONDS := 3.0
## A pad counts when the bus passes within this far of its centre, sideways.
const BOOST_REACH := 3.4
## Steering help in the arcade only: a quicker wheel and more cornering grip.
const HANDLING := 1.3

var seconds_left: float = START_SECONDS
var elapsed: float = 0.0
var checkpoints_passed: int = 0
var checkpoints := PackedFloat32Array()
var boosts := PackedFloat32Array()
var boosts_used: Array[bool] = []
var finished: bool = false

var _last_progress: float = 0.0


## Lays out checkpoints and pads up to this far along the course.
func plan_to(course_length: float) -> void:
	var next := FIRST_CHECKPOINT if checkpoints.is_empty() else checkpoints[checkpoints.size() - 1] + CHECKPOINT_SPACING
	while next < course_length - 20.0:
		checkpoints.append(next)
		next += CHECKPOINT_SPACING
	var pad := FIRST_BOOST if boosts.is_empty() else boosts[boosts.size() - 1] + BOOST_SPACING
	while pad < course_length - 20.0:
		boosts.append(pad)
		boosts_used.append(false)
		pad += BOOST_SPACING


func next_checkpoint() -> float:
	return checkpoints[checkpoints_passed] if checkpoints_passed < checkpoints.size() else INF


## Moves the run on. Returns what happened: "checkpoint", "boost", "finished" or "".
## off_line is how far the bus is from the middle of its lane, for the pads.
func update(progress: float, off_line: float, dt: float) -> Array[String]:
	var events: Array[String] = []
	if finished:
		return events
	elapsed += dt
	seconds_left -= dt
	while checkpoints_passed < checkpoints.size() and progress >= checkpoints[checkpoints_passed]:
		checkpoints_passed += 1
		seconds_left += CHECKPOINT_SECONDS
		events.append("checkpoint")
	for i in boosts.size():
		if not boosts_used[i] and _last_progress < boosts[i] and progress >= boosts[i] and off_line < BOOST_REACH:
			boosts_used[i] = true
			events.append("boost")
	_last_progress = maxf(_last_progress, progress)
	if seconds_left <= 0.0:
		seconds_left = 0.0
		finished = true
		events.append("finished")
	return events


func crash() -> void:
	if not finished:
		seconds_left = maxf(seconds_left - CRASH_SECONDS, 0.0)


## Stars for the report: more checkpoints, more stars.
static func stars_for(passed: int) -> int:
	var earned := 1
	for threshold: int in [4, 8, 13, 19]:
		if passed >= threshold:
			earned += 1
	return earned


static func coins_for(passed: int, distance: float) -> int:
	return 30 + passed * 25 + roundi(distance / 100.0) * 2
