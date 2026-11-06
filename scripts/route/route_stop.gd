class_name RouteStop
extends RefCounted
## One bus stop: where it is and how well a bus is lined up with it.

const ALONG_TOLERANCE := 5.0
const LATERAL_TOLERANCE := 1.6
const HEADING_TOLERANCE := deg_to_rad(20.0)
## How far past a stop the bus can go before the stop counts as missed.
const MISSED_DISTANCE := 22.0
const MISSED_LATERAL := 14.0

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


## 1 is perfect, 0 is at the edge of the tolerance. Scoring uses this later.
func accuracy(bus_centre: Vector2) -> float:
	var offset := offset_of(bus_centre)
	var along_share := absf(offset.x) / ALONG_TOLERANCE
	var lateral_share := absf(offset.y) / LATERAL_TOLERANCE
	return clampf(1.0 - maxf(along_share, lateral_share), 0.0, 1.0)
