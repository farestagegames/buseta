class_name AutomaticGearbox
extends RefCounted
## Picks a gear from road speed, with a brief drive cut during each shift.

const IDLE_RPM := 650.0
const MAX_RPM := 2300.0
## Downshift below this share of the lower gear's limit, to stop gear hunting.
const DOWNSHIFT_RATIO := 0.6
const UPSHIFT_RATIO := 0.97

var gear: int = 1
var rpm: float = IDLE_RPM

var _spec: BusSpec
var _shift_timer: float = 0.0


func _init(spec: BusSpec) -> void:
	_spec = spec


func is_shifting() -> bool:
	return _shift_timer > 0.0


func gear_count() -> int:
	return _spec.gear_top_speeds.size()


func thrust_share() -> float:
	return _spec.gear_thrust[gear - 1]


func update(road_speed: float, dt: float) -> void:
	var speed := absf(road_speed)
	_shift_timer = maxf(_shift_timer - dt, 0.0)
	if not is_shifting():
		if gear < gear_count() and speed >= _spec.gear_top_speeds[gear - 1] * UPSHIFT_RATIO:
			_shift_to(gear + 1)
		elif gear > 1 and speed < _spec.gear_top_speeds[gear - 2] * DOWNSHIFT_RATIO:
			_shift_to(gear - 1)
	var ratio := clampf(speed / _spec.gear_top_speeds[gear - 1], 0.0, 1.0)
	rpm = lerpf(IDLE_RPM, MAX_RPM, ratio)


func _shift_to(new_gear: int) -> void:
	gear = new_gear
	_shift_timer = _spec.shift_time
