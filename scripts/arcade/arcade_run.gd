class_name ArcadeRun
extends RefCounted
## The rules of an arcade run, as pure logic: checkpoints along the course that add
## time, boost pads that can each be used once, crashes that cost time, and the
## end when the clock runs out. Distances are along the course, in metres.
##
## Every number is read from the route's "arcade" config block (arcade.json), so
## the tuning lives in data. The constants below are fallbacks for a pack that
## ships no config; Colombia's arcade.json always sets them.

const START_SECONDS := 62.0
const CHECKPOINT_SECONDS := 20.0
const CHECKPOINT_DECAY := 1.0
const CHECKPOINT_FLOOR := 9.0
const CRASH_SECONDS := 4.0
const FIRST_CHECKPOINT := 180.0
const CHECKPOINT_SPACING := 280.0
const FIRST_BOOST := 330.0
const BOOST_SPACING := 420.0
const BOOST_SECONDS := 3.0
## A pad counts when the bus passes within this far of its centre, sideways.
const BOOST_REACH := 3.4
## Steering help in the arcade only: a quicker wheel and more cornering grip.
const HANDLING := 1.3

var start_seconds: float = START_SECONDS
var checkpoint_seconds: float = CHECKPOINT_SECONDS
var checkpoint_decay: float = CHECKPOINT_DECAY
var checkpoint_floor: float = CHECKPOINT_FLOOR
var crash_seconds: float = CRASH_SECONDS
var first_checkpoint: float = FIRST_CHECKPOINT
var checkpoint_spacing: float = CHECKPOINT_SPACING
var first_boost: float = FIRST_BOOST
var boost_spacing: float = BOOST_SPACING
var boost_seconds: float = BOOST_SECONDS
var boost_reach: float = BOOST_REACH
var handling: float = HANDLING

var seconds_left: float = START_SECONDS
var elapsed: float = 0.0
var checkpoints_passed: int = 0
## The time the most recently passed arch added, for the "+N s" pop.
var last_bonus: float = 0.0
var checkpoints := PackedFloat32Array()
var boosts := PackedFloat32Array()
var boosts_used: Array[bool] = []
var finished: bool = false

var _last_progress: float = 0.0


## Reads the run's tuning from the route's "arcade" config block. Anything the
## block leaves out keeps its fallback, so an old or foreign pack still runs.
func configure(config: Dictionary) -> void:
	start_seconds = _number(config, "start_seconds", START_SECONDS)
	checkpoint_seconds = _number(config, "checkpoint_seconds", CHECKPOINT_SECONDS)
	checkpoint_decay = _number(config, "checkpoint_decay", CHECKPOINT_DECAY)
	checkpoint_floor = _number(config, "checkpoint_floor", CHECKPOINT_FLOOR)
	crash_seconds = _number(config, "crash_seconds", CRASH_SECONDS)
	first_checkpoint = _number(config, "first_checkpoint", FIRST_CHECKPOINT)
	checkpoint_spacing = _number(config, "checkpoint_spacing", CHECKPOINT_SPACING)
	first_boost = _number(config, "first_boost", FIRST_BOOST)
	boost_spacing = _number(config, "boost_spacing", BOOST_SPACING)
	boost_seconds = _number(config, "boost_seconds", BOOST_SECONDS)
	boost_reach = _number(config, "boost_reach", BOOST_REACH)
	handling = _number(config, "handling", HANDLING)
	seconds_left = start_seconds


## The time the arch at index passed (0-based) adds: the base bonus, less the
## decay for every arch already passed, down to the floor. So each arch gives a
## little less than the last until the floor holds it there.
func bonus_for(passed: int) -> float:
	return maxf(checkpoint_seconds - float(passed) * checkpoint_decay, checkpoint_floor)


## Lays out checkpoints and pads up to this far along the course.
func plan_to(course_length: float) -> void:
	var next := first_checkpoint if checkpoints.is_empty() else checkpoints[checkpoints.size() - 1] + checkpoint_spacing
	while next < course_length - 20.0:
		checkpoints.append(next)
		next += checkpoint_spacing
	var pad := first_boost if boosts.is_empty() else boosts[boosts.size() - 1] + boost_spacing
	while pad < course_length - 20.0:
		boosts.append(pad)
		boosts_used.append(false)
		pad += boost_spacing


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
		last_bonus = bonus_for(checkpoints_passed)
		seconds_left += last_bonus
		checkpoints_passed += 1
		events.append("checkpoint")
	for i in boosts.size():
		if not boosts_used[i] and _last_progress < boosts[i] and progress >= boosts[i] and off_line < boost_reach:
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
		seconds_left = maxf(seconds_left - crash_seconds, 0.0)


## Stars for the report: more checkpoints, more stars.
static func stars_for(passed: int) -> int:
	var earned := 1
	for threshold: int in [4, 8, 13, 19]:
		if passed >= threshold:
			earned += 1
	return earned


static func coins_for(passed: int, distance: float) -> int:
	return 30 + passed * 25 + roundi(distance / 100.0) * 2


static func _number(config: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = config.get(key)
	return float(value) if value is float or value is int else fallback
