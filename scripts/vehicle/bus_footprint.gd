class_name BusFootprint
extends RefCounted
## Tests points against the bus outline, without any physics engine.


## Returns true when a circle touches the bus. rear_axle and point are on the
## ground plane (X, Z). Heading follows BusPhysicsModel.
static func touches(rear_axle: Vector2, heading: float, spec: BusSpec, point: Vector2, radius: float) -> bool:
	var forward := Vector2(-sin(heading), -cos(heading))
	var right := Vector2(-forward.y, forward.x)
	var offset := point - rear_axle
	var along := offset.dot(forward)
	var across := absf(offset.dot(right))
	return along > -spec.rear_overhang - radius \
		and along < spec.wheelbase + spec.front_overhang + radius \
		and across < spec.body_width / 2.0 + radius


## Centre of the body on the ground plane.
static func body_centre(rear_axle: Vector2, heading: float, spec: BusSpec) -> Vector2:
	var forward := Vector2(-sin(heading), -cos(heading))
	return rear_axle + forward * -spec.body_centre_z()
