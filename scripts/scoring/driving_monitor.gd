class_name DrivingMonitor
extends RefCounted
## Watches acceleration and speed and reports driving events. Pure logic. An
## event must last a moment to count, so one rough frame is never penalised.

signal harsh_brake
signal harsh_accel

const HARSH_BRAKE_DECEL := 2.7
const HARSH_BRAKE_SECONDS := 0.2
## Only a sustained full-pedal launch counts. Normal pulling away never should.
const HARSH_ACCEL := 1.4
const HARSH_ACCEL_SECONDS := 2.5
const HARSH_ACCEL_REPEAT_SECONDS := 25.0
const RESET_ACCEL := 0.9 ## Must ease below this before another event counts.
const SPEED_GRACE_KMH := 5.0

var _brake_time: float = 0.0
var _accel_time: float = 0.0
var _brake_armed: bool = true
var _accel_armed: bool = true
var _accel_repeat: float = 0.0


func update(acceleration: float, dt: float) -> void:
	_accel_repeat = maxf(_accel_repeat - dt, 0.0)
	_brake_time = _brake_time + dt if acceleration < -HARSH_BRAKE_DECEL else 0.0
	_accel_time = _accel_time + dt if acceleration > HARSH_ACCEL else 0.0
	if _brake_armed and _brake_time >= HARSH_BRAKE_SECONDS:
		_brake_armed = false
		harsh_brake.emit()
	if _accel_armed and _accel_repeat <= 0.0 and _accel_time >= HARSH_ACCEL_SECONDS:
		_accel_armed = false
		_accel_repeat = HARSH_ACCEL_REPEAT_SECONDS
		harsh_accel.emit()
	if acceleration > -RESET_ACCEL:
		_brake_armed = true
	if acceleration < RESET_ACCEL:
		_accel_armed = true


static func is_speeding(speed_ms: float, limit_kmh: float) -> bool:
	return absf(speed_ms) * 3.6 > limit_kmh + SPEED_GRACE_KMH
