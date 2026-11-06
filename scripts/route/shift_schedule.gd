class_name ShiftSchedule
extends RefCounted
## The timetable for a shift: when each stop is due, in seconds from the start.
## Pure logic. Times come from the route file.

## Arriving this early or late still counts as on time.
const ON_TIME_EARLY := 30.0
const ON_TIME_LATE := 30.0
## Punctuality reaches zero this far outside the on-time window.
const ZERO_SCORE_MARGIN := 300.0

var due_times: PackedFloat32Array = PackedFloat32Array()


func _init(times: PackedFloat32Array) -> void:
	due_times = times


## Positive is late, negative is early.
func seconds_late(stop_index: int, clock: float) -> float:
	return clock - due_times[stop_index]


static func is_on_time(late: float) -> bool:
	return late >= -ON_TIME_EARLY and late <= ON_TIME_LATE


## 100 when on time or ahead of time, falling gently the later the bus runs.
static func punctuality_score(late: float) -> float:
	var outside := maxf(late - ON_TIME_LATE, 0.0)
	return clampf(100.0 * (1.0 - outside / ZERO_SCORE_MARGIN), 0.0, 100.0)


## Readable lateness for the driver, such as "On time" or "1:05 late".
static func status_text(late: float) -> String:
	if is_on_time(late):
		return "On time"
	var seconds := absi(roundi(late))
	return "%d:%02d %s" % [seconds / 60, seconds % 60, "late" if late > 0.0 else "early"]
