class_name CabinLayout
extends RefCounted
## Where people walk inside a bus, in the bus's own coordinates. Everyone pays at
## the machine beside the driver, then follows the aisle to their seat row.

const FLOOR_HEIGHT := 0.45
const STEP_HEIGHT := 0.24
## Points left on the boarding path at the moment a passenger reaches the machine.
const POINTS_AFTER_PAYING := 2

var kerb: Vector3 ## Just outside the doorway, at pavement level.
var step: Vector3
var inside_door: Vector3
var pay_point: Vector3
var machine: Vector3 ## The ticket machine itself.
var aisle_front: Vector3
var exit_start: Vector3 ## Where people getting off come into view from the aisle.
var vendor_spot: Vector3 ## Where a vendor stands to sell, part way down the aisle.
## With a rear door, people get off there: the aisle beside it, just inside, the
## step and the kerb. Without one these are the front door's.
var exit_aisle: Vector3
var exit_inside: Vector3
var exit_step: Vector3
var exit_kerb: Vector3
var has_rear_door: bool = false


func _init(spec: BusSpec) -> void:
	var front := -(spec.wheelbase + spec.front_overhang)
	var side := float(spec.door_side)
	var half := spec.body_width / 2.0
	var door_z := front + spec.door_offset + BusVisual.DOOR_WIDTH / 2.0
	var behind_door := front + spec.door_offset + BusVisual.DOOR_WIDTH
	kerb = Vector3((half + 0.3) * side, 0.0, door_z)
	step = Vector3((half - 0.1) * side, STEP_HEIGHT, door_z)
	inside_door = Vector3((half - 0.6) * side, FLOOR_HEIGHT, door_z + 0.05)
	pay_point = Vector3(0.42 * side, FLOOR_HEIGHT, door_z + 0.2)
	machine = Vector3(0.02 * side, 1.28, door_z + 0.05)
	aisle_front = Vector3(0.12 * side, FLOOR_HEIGHT, behind_door + 0.6)
	exit_start = Vector3(0.0, FLOOR_HEIGHT, behind_door + 1.3)
	vendor_spot = Vector3(0.0, 0.0, behind_door + 2.6)
	exit_aisle = aisle_front
	exit_inside = inside_door
	exit_step = step
	exit_kerb = kerb
	has_rear_door = spec.has_rear_door()
	if has_rear_door:
		var rear_z := (spec.rear_door_near_z() + spec.rear_door_far_z()) / 2.0
		exit_aisle = Vector3(0.0, FLOOR_HEIGHT, rear_z - 0.2)
		exit_inside = Vector3((half - 0.6) * side, FLOOR_HEIGHT, rear_z)
		exit_step = Vector3((half - 0.1) * side, STEP_HEIGHT, rear_z)
		exit_kerb = Vector3((half + 0.3) * side, 0.0, rear_z)
		exit_start = Vector3(0.0, FLOOR_HEIGHT, rear_z - 1.2)


## From the kerb, past the machine and along the aisle to a seat's row.
func boarding_path(seat: Vector3) -> Array[Vector3]:
	return [step, inside_door, pay_point, aisle_front, Vector3(0.0, FLOOR_HEIGHT, seat.z)]


## From the aisle to the kerb, by the rear door if there is one.
func alighting_path() -> Array[Vector3]:
	return [exit_aisle, exit_inside, exit_step, exit_kerb]
