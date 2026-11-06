class_name SteeringMapper
extends RefCounted
## Turns each control style into one steering value from -1 (left) to 1 (right).
## Pure logic: callers pass in raw readings, so all three modes are testable.

enum Mode { WHEEL, TILT, BUTTONS }

const MIN_SENSITIVITY := 0.5
const MAX_SENSITIVITY := 2.0

## Phone tilt in degrees that gives full lock at sensitivity 1.
const TILT_FULL_LOCK_DEGREES := 30.0
const TILT_DEAD_ZONE_DEGREES := 1.5
## Time constant of the tilt filter, which hides sensor jitter.
const TILT_SMOOTHING_SECONDS := 0.07
## Above 1, small inputs get finer control and full lock stays reachable.
const RESPONSE_CURVE := 1.5

const BUTTON_RAMP_PER_SECOND := 1.1
const BUTTON_RETURN_PER_SECOND := 1.8

var sensitivity: float = 1.0:
	set(value):
		sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
var invert_tilt: bool = false
var steer: float = 0.0

var _filtered_tilt_degrees: float = 0.0


## normalised_wheel is the on-screen wheel position, -1 to 1.
func update_wheel(normalised_wheel: float) -> float:
	steer = _apply_curve(clampf(normalised_wheel * sensitivity, -1.0, 1.0))
	return steer


## gravity is the phone's gravity vector with X along the screen's long edge.
func update_tilt(gravity: Vector3, dt: float) -> float:
	var flat := Vector2(gravity.y, gravity.z).length()
	var tilt_degrees := rad_to_deg(atan2(gravity.x, flat))
	if invert_tilt:
		tilt_degrees = -tilt_degrees
	var blend := clampf(dt / TILT_SMOOTHING_SECONDS, 0.0, 1.0)
	_filtered_tilt_degrees = lerpf(_filtered_tilt_degrees, tilt_degrees, blend)

	var live_degrees := maxf(absf(_filtered_tilt_degrees) - TILT_DEAD_ZONE_DEGREES, 0.0)
	var full_lock := TILT_FULL_LOCK_DEGREES / sensitivity
	var amount := clampf(live_degrees / full_lock, 0.0, 1.0)
	steer = _apply_curve(amount * signf(_filtered_tilt_degrees))
	return steer


func update_buttons(left: bool, right: bool, dt: float) -> float:
	if left == right:
		steer = move_toward(steer, 0.0, BUTTON_RETURN_PER_SECOND * dt)
	else:
		var target := -1.0 if left else 1.0
		var rate := BUTTON_RAMP_PER_SECOND * sensitivity
		# Steering back across the centre should be as quick as a release.
		if signf(steer) == -target:
			rate += BUTTON_RETURN_PER_SECOND
		steer = move_toward(steer, target, rate * dt)
	return steer


func _apply_curve(value: float) -> float:
	return signf(value) * pow(absf(value), RESPONSE_CURVE)
