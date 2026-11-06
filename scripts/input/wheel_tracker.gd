class_name WheelTracker
extends RefCounted
## Tracks a finger dragging around the on-screen wheel. The wheel follows the
## change in finger angle, so grabbing it anywhere never makes it jump, and it
## self-centres on release like a real power-steered wheel.

## Rotation either way from centre, in degrees.
const MAX_ROTATION_DEGREES := 200.0
const RETURN_DEGREES_PER_SECOND := 420.0
## Fingers closer to the centre than this give unreliable angles.
const MIN_RADIUS := 18.0

var rotation_degrees: float = 0.0
var is_held: bool = false

var _last_finger_degrees: float = 0.0


func press(finger_from_centre: Vector2) -> void:
	is_held = true
	_last_finger_degrees = rad_to_deg(finger_from_centre.angle())


func drag(finger_from_centre: Vector2) -> void:
	if not is_held or finger_from_centre.length() < MIN_RADIUS:
		return
	var finger_degrees := rad_to_deg(finger_from_centre.angle())
	var change := wrapf(finger_degrees - _last_finger_degrees, -180.0, 180.0)
	_last_finger_degrees = finger_degrees
	rotation_degrees = clampf(rotation_degrees + change, -MAX_ROTATION_DEGREES, MAX_ROTATION_DEGREES)


func release() -> void:
	is_held = false


func update(dt: float) -> void:
	if not is_held:
		rotation_degrees = move_toward(rotation_degrees, 0.0, RETURN_DEGREES_PER_SECOND * dt)


func normalised() -> float:
	return rotation_degrees / MAX_ROTATION_DEGREES
