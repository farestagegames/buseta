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


## Metres from a car's nose to the bus along the car's lane, or INF when the bus
## is not in its path. car_position is the car's centre.
static func gap_ahead(rear_axle: Vector2, heading: float, spec: BusSpec, car_position: Vector2, car_forward: Vector2, car_half_length: float, car_half_width: float) -> float:
	var centre := body_centre(rear_axle, heading, spec)
	var bus_forward := Vector2(-sin(heading), -cos(heading))
	var car_right := Vector2(-car_forward.y, car_forward.x)
	var offset := centre - car_position
	var along := offset.dot(car_forward)
	if along < 0.0:
		return INF
	var half_length := spec.overall_length() / 2.0
	var half_width := spec.body_width / 2.0
	var facing := absf(bus_forward.dot(car_forward))
	var sideways := absf(bus_forward.dot(car_right))
	var reach_along := half_length * facing + half_width * sideways
	var reach_across := half_length * sideways + half_width * facing
	if absf(offset.dot(car_right)) > reach_across + car_half_width + 0.5:
		return INF
	return maxf(along - reach_along - car_half_length, 0.0)
