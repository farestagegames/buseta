class_name DrivingMonitor
extends RefCounted
## Watches for emergency stops. Pure logic. Normal braking, even firm braking,
## never counts: only a near full pedal stop that lasts a moment.

signal harsh_brake

const HARSH_BRAKE_DECEL := 3.5
const HARSH_BRAKE_SECONDS := 0.4
const RESET_DECEL := 1.5 ## Must ease below this before another stop counts.
const SPEED_GRACE_KMH := 5.0

var _brake_time: float = 0.0
var _brake_armed: bool = true


func update(acceleration: float, dt: float) -> void:
	_brake_time = _brake_time + dt if acceleration < -HARSH_BRAKE_DECEL else 0.0
	if _brake_armed and _brake_time >= HARSH_BRAKE_SECONDS:
		_brake_armed = false
		harsh_brake.emit()
	if acceleration > -RESET_DECEL:
		_brake_armed = true


static func is_speeding(speed_ms: float, limit_kmh: float) -> bool:
	return absf(speed_ms) * 3.6 > limit_kmh + SPEED_GRACE_KMH
