class_name StopQuality
extends RefCounted
## Decides whether a stop was "perfect": inside the stop box, low speed at the
## stop, and no harsh braking on the approach. One place for feedback and goals.

const STOP_SPEED := BusPhysicsModel.STOPPED_SPEED


static func is_perfect(stop: RouteStop, bus_centre: Vector2, bus_heading: float, speed: float, harsh_braking: bool) -> bool:
	if harsh_braking:
		return false
	if absf(speed) >= STOP_SPEED:
		return false
	return stop.is_aligned(bus_centre, bus_heading)
