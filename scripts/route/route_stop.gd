class_name RouteStop
extends RefCounted
## One bus stop: where it is and how well a bus is lined up with it.

const ALONG_TOLERANCE := 5.0
const LATERAL_TOLERANCE := 1.6
const HEADING_TOLERANCE := deg_to_rad(20.0)
## How far past a stop the bus can go before the stop counts as missed.
const MISSED_DISTANCE := 22.0
const MISSED_LATERAL := 14.0
const PERFECT_ALONG := 1.5
const PERFECT_LATERAL := 0.6
const EDGE_ACCURACY := 0.6

var stop_name: String = ""
var road: String = ""
var along: float = 0.0
var dir: int = 1
var position: Vector2 = Vector2.ZERO ## Middle of the bay.
var heading: float = 0.0
var waiting: int = 0
var is_final: bool = false
var due: float = 0.0 ## Seconds after the shift starts.
var route_distance: float = 0.0


func forward() -> Vector2:
	return Vector2(-sin(heading), -cos(heading))


## Positive along means the bus centre is ahead of the bay's middle, and
## positive lateral means it is to the right of it.
func offset_of(bus_centre: Vector2) -> Vector2:
	var fwd := forward()
	var right := Vector2(-fwd.y, fwd.x)
	var offset := bus_centre - position
	return Vector2(offset.dot(fwd), offset.dot(right))


func is_aligned(bus_centre: Vector2, bus_heading: float) -> bool:
	var offset := offset_of(bus_centre)
	return absf(offset.x) <= ALONG_TOLERANCE \
		and absf(offset.y) <= LATERAL_TOLERANCE \
		and absf(angle_difference(bus_heading, heading)) <= HEADING_TOLERANCE


func is_passed(bus_centre: Vector2) -> bool:
	var offset := offset_of(bus_centre)
	return offset.x > MISSED_DISTANCE and absf(offset.y) < MISSED_LATERAL


## 1 anywhere near the middle of the bay, falling gently to a floor at the edge
## of the tolerance. Any stop that lets passengers on is a decent stop.
func accuracy(bus_centre: Vector2) -> float:
	var offset := offset_of(bus_centre)
	var along := inverse_lerp(PERFECT_ALONG, ALONG_TOLERANCE, absf(offset.x))
	var lateral := inverse_lerp(PERFECT_LATERAL, LATERAL_TOLERANCE, absf(offset.y))
	return lerpf(1.0, EDGE_ACCURACY, clampf(maxf(along, lateral), 0.0, 1.0))
