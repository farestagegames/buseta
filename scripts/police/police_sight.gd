class_name PoliceSight
extends RefCounted
## What a transit police patrol can see: a cone ahead of the car, out to a range.
## Pure geometry on the ground plane (x, z as Vector2); PoliceSystem adds the ray
## that buildings block.

## How far the patrol sees, in metres.
const RANGE := 70.0
## Half the view cone's width, in degrees either side of straight ahead.
const HALF_ANGLE_DEGREES := 60.0


## True when target is within view_range of eye and inside the cone around forward.
## A zero forward sees nothing; a target on top of the eye is always seen.
static func in_view(eye: Vector2, forward: Vector2, target: Vector2, half_angle_degrees: float = HALF_ANGLE_DEGREES, view_range: float = RANGE) -> bool:
	var offset := target - eye
	var distance := offset.length()
	if distance > view_range:
		return false
	if distance < 0.001:
		return true
	if forward.length_squared() == 0.0:
		return false
	return (offset / distance).dot(forward.normalized()) >= cos(deg_to_rad(half_angle_degrees))
