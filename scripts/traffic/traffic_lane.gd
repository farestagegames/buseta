class_name TrafficLane
extends RefCounted
## One drivable path for traffic: a lane along a road or a link across a junction.

var points: PackedVector2Array = PackedVector2Array()
var lengths: PackedFloat32Array = PackedFloat32Array()
var length: float = 0.0
var next: Array[int] = [] ## Lanes that can follow this one.
var end_node: String = "" ## The junction this lane ends at, for road lanes.
var is_link: bool = false ## True for a path across a junction.
var node: String = "" ## The junction a link crosses.
var turn: int = 0 ## For links: -1 left, 0 straight, 1 right.
var from_lane: int = -1 ## For links: the lane entering it.
var group: int = 0 ## Signal group of a road lane, by its compass axis.
var road: String = ""


func finish() -> void:
	lengths = PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		lengths.append(lengths[i - 1] + points[i].distance_to(points[i - 1]))
	length = lengths[lengths.size() - 1]


func point_at(distance: float) -> Vector2:
	var index := _segment(distance)
	var span := lengths[index + 1] - lengths[index]
	var share := (distance - lengths[index]) / span if span > 0.0 else 0.0
	return points[index].lerp(points[index + 1], clampf(share, 0.0, 1.0))


func forward_at(distance: float) -> Vector2:
	var index := _segment(distance)
	return (points[index + 1] - points[index]).normalized()


## Tightest speed for a car on this lane, in m/s.
func speed_limit(cruise: float) -> float:
	if not is_link:
		return cruise
	return cruise * 0.5 if turn != 0 else cruise * 0.75


func _segment(distance: float) -> int:
	var low := 0
	var high := points.size() - 2
	while low < high:
		var middle := (low + high + 1) / 2
		if lengths[middle] <= distance:
			low = middle
		else:
			high = middle - 1
	return low
