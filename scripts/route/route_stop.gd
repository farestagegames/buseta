class_name RouteStop
extends RefCounted
## One place the bus can stop, and how well a bus is lined up with it. A bay is
## a marked stop at the kerb, a hail is someone flagging the bus down wherever they
## happen to be, and a station is a platform on a rapid-transit line.

enum Kind { BAY, HAIL, STATION }

const ALONG_TOLERANCE := 5.0
const LATERAL_TOLERANCE := 1.6
## How far from the road's centre the bus should stop, by kind.
const HAIL_LATERAL := 2.2
const STATION_LATERAL := 1.9
const HAIL_ALONG_TOLERANCE := 12.0
const HAIL_LATERAL_TOLERANCE := 1.9
const HAIL_PERFECT_ALONG := 5.0
const HAIL_MISSED_DISTANCE := 15.0
const STATION_ALONG_TOLERANCE := 4.0
const STATION_LATERAL_TOLERANCE := 1.1
const STATION_PERFECT_ALONG := 1.2
const HEADING_TOLERANCE := deg_to_rad(20.0)
## How far past a stop the bus can go before the stop counts as missed.
const MISSED_DISTANCE := 22.0
const MISSED_LATERAL := 14.0
const PERFECT_ALONG := 1.5
const PERFECT_LATERAL := 0.6
const EDGE_ACCURACY := 0.6

var kind: Kind = Kind.BAY
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
var vendor: bool = false ## A street vendor is waiting here too.


## Metres from the road's centre to the middle of where the bus should stop.
func lateral() -> float:
	match kind:
		Kind.HAIL:
			return HAIL_LATERAL
		Kind.STATION:
			return STATION_LATERAL
		_:
			return RoadNetwork.ROAD_HALF_WIDTH + RoadNetwork.BAY_DEPTH / 2.0 - 0.2


## How far people wait from where the bus stops.
func waiting_distance() -> float:
	if kind == Kind.BAY:
		return RoadNetwork.BAY_DEPTH / 2.0 + 1.3
	return RoadNetwork.ROAD_HALF_WIDTH - lateral() + 1.2


func along_tolerance() -> float:
	match kind:
		Kind.HAIL:
			return HAIL_ALONG_TOLERANCE
		Kind.STATION:
			return STATION_ALONG_TOLERANCE
		_:
			return ALONG_TOLERANCE


func lateral_tolerance() -> float:
	match kind:
		Kind.HAIL:
			return HAIL_LATERAL_TOLERANCE
		Kind.STATION:
			return STATION_LATERAL_TOLERANCE
		_:
			return LATERAL_TOLERANCE


func _perfect_along() -> float:
	match kind:
		Kind.HAIL:
			return HAIL_PERFECT_ALONG
		Kind.STATION:
			return STATION_PERFECT_ALONG
		_:
			return PERFECT_ALONG


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
	return absf(offset.x) <= along_tolerance() \
		and absf(offset.y) <= lateral_tolerance() \
		and absf(angle_difference(bus_heading, heading)) <= HEADING_TOLERANCE


func is_passed(bus_centre: Vector2) -> bool:
	var offset := offset_of(bus_centre)
	var missed := HAIL_MISSED_DISTANCE if kind == Kind.HAIL else MISSED_DISTANCE
	return offset.x > missed and absf(offset.y) < MISSED_LATERAL


## 1 anywhere near the middle of the bay, falling gently to a floor at the edge
## of the tolerance. Any stop that lets passengers on is a decent stop.
func accuracy(bus_centre: Vector2) -> float:
	var offset := offset_of(bus_centre)
	var along := inverse_lerp(_perfect_along(), along_tolerance(), absf(offset.x))
	var across := inverse_lerp(PERFECT_LATERAL, lateral_tolerance(), absf(offset.y))
	return lerpf(1.0, EDGE_ACCURACY, clampf(maxf(along, across), 0.0, 1.0))
