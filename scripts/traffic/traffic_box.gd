class_name TrafficBox
extends RefCounted
## A rectangle on the ground that traffic must not drive into: the bus, its
## trailer, a prop or another vehicle. Boxes are reused every tick, so nothing
## is allocated while driving.

enum Kind { BUS, TRAILER, PROP, VEHICLE }

var kind: Kind = Kind.PROP
var centre: Vector2 = Vector2.ZERO
var forward: Vector2 = Vector2(0.0, -1.0)
var half_length: float = 0.5
var half_width: float = 0.5
var velocity: Vector2 = Vector2.ZERO
var index: int = -1 ## Prop or agent index, for PROP and VEHICLE boxes.


func set_pose(at: Vector2, facing: Vector2, length_half: float, width_half: float) -> void:
	centre = at
	forward = facing
	half_length = length_half
	half_width = width_half


## Rough reach from the centre, for cheap distance checks.
func radius() -> float:
	return half_length + half_width


func is_still() -> bool:
	return velocity.length_squared() < TrafficSense.STILL_SPEED * TrafficSense.STILL_SPEED
