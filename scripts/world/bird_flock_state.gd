class_name BirdFlockState
extends RefCounted
## One perched flock's deterministic flight. Distances are horizontal so a bus
## below a tree or rooftop still disturbs the birds. No nodes or physics involved.

enum Phase { PERCHED, OUTBOUND, AWAY, RETURNING }

const TAKEOFF_RANGE := 15.0
const OUTBOUND_SECONDS := 2.8
const AWAY_SECONDS := 5.0
const RETURN_SECONDS := 3.2
const FLIGHT_REACH := 5.0
const FLIGHT_HEIGHT := 3.0

var phase: Phase = Phase.PERCHED
var elapsed: float = 0.0


func update(dt: float, bus_position: Vector3, centre: Vector3) -> void:
	if phase == Phase.PERCHED:
		var bus_flat := Vector2(bus_position.x, bus_position.z)
		var centre_flat := Vector2(centre.x, centre.z)
		if bus_flat.distance_to(centre_flat) <= TAKEOFF_RANGE:
			phase = Phase.OUTBOUND
			elapsed = 0.0
		return
	elapsed += maxf(dt, 0.0)
	match phase:
		Phase.OUTBOUND:
			if elapsed >= OUTBOUND_SECONDS:
				phase = Phase.AWAY
				elapsed = 0.0
		Phase.AWAY:
			if elapsed >= AWAY_SECONDS:
				phase = Phase.RETURNING
				elapsed = 0.0
		Phase.RETURNING:
			if elapsed >= RETURN_SECONDS:
				phase = Phase.PERCHED
				elapsed = 0.0


func is_flying() -> bool:
	return phase != Phase.PERCHED


## A small spread at the perch, then a short individual arc away and back.
func bird_position(index: int, perch: Vector3) -> Vector3:
	var angle := float(index) * 2.399963
	var settled := perch + Vector3(cos(angle) * 0.8, 0.04 * float(index % 2), sin(angle) * 0.8)
	if phase == Phase.PERCHED:
		return settled
	var direction := Vector3(cos(angle + 0.45), 0.0, sin(angle + 0.45))
	var airborne := settled + direction * (FLIGHT_REACH + 0.3 * float(index)) + Vector3.UP * (FLIGHT_HEIGHT + 0.2 * float(index))
	match phase:
		Phase.OUTBOUND:
			var t := clampf(elapsed / OUTBOUND_SECONDS, 0.0, 1.0)
			return settled.lerp(airborne, t) + Vector3.UP * sin(t * PI) * 0.8
		Phase.AWAY:
			var orbit := elapsed * 1.4 + angle
			return airborne + Vector3(cos(orbit), 0.0, sin(orbit)) * 0.8 + Vector3.UP * sin(elapsed * 2.0) * 0.2
		Phase.RETURNING:
			var t := clampf(elapsed / RETURN_SECONDS, 0.0, 1.0)
			return airborne.lerp(settled, t) + Vector3.UP * sin(t * PI) * 0.8
	return settled
