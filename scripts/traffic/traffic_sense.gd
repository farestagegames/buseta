class_name TrafficSense
extends RefCounted
## What a car or motorbike sees and decides, as pure functions: what is in its
## path, how far to move over to pass it, and whether that is allowed. Lateral
## values are metres towards the kerb from the lane's line, so the same rules
## work for left-hand and right-hand traffic.

## Slower than this, a thing counts as standing still.
const STILL_SPEED := 0.5
## Side clearance kept when checking a path.
const LOOK_MARGIN := 0.1
## A moving bus counts as already where it will be this soon.
const BUS_SWEEP_SECONDS := 1.5
## Behind a reversing bus, traffic keeps clear of where it will be this soon.
const REVERSE_SWEEP_SECONDS := 3.0
const REVERSE_STANDOFF := 3.0
## Room kept beside whatever is being passed.
## A moto's crash radius is wider than its body, so it keeps more room.
const CAR_PASS_MARGIN := 0.35
const MOTO_PASS_MARGIN := 0.5
## How far past the centre line a vehicle may go without waiting for a gap in
## oncoming traffic. Oncoming cars keep about a metre clear of it.
const FREE_REACH := 0.5
const ROAD_EDGE_MARGIN := 0.2
const MAX_SHIFT := 4.4

## Index of the path segment the last first_contact call hit, for its direction.
static var last_segment: int = -1


## Where a segment from a to b first enters a box grown by grow metres on every
## side, as a share of the segment from 0 to 1, or -1 when it misses.
static func segment_entry(a: Vector2, b: Vector2, box: TrafficBox, grow: float) -> float:
	var right := Vector2(-box.forward.y, box.forward.x)
	var from := a - box.centre
	var to := b - box.centre
	var x0 := from.dot(right)
	var y0 := from.dot(box.forward)
	var dx := to.dot(right) - x0
	var dy := to.dot(box.forward) - y0
	var enter := 0.0
	var leave := 1.0
	var half := box.half_width + grow
	if absf(dx) < 0.00001:
		if absf(x0) > half:
			return -1.0
	else:
		var t1 := (-half - x0) / dx
		var t2 := (half - x0) / dx
		enter = maxf(enter, minf(t1, t2))
		leave = minf(leave, maxf(t1, t2))
	half = box.half_length + grow
	if absf(dy) < 0.00001:
		if absf(y0) > half:
			return -1.0
	else:
		var t1 := (-half - y0) / dy
		var t2 := (half - y0) / dy
		enter = maxf(enter, minf(t1, t2))
		leave = minf(leave, maxf(t1, t2))
	return enter if enter <= leave else -1.0


## Lays points along the lanes in chain, starting start metres into the first,
## moved lateral metres towards the kerb, until reach metres have been covered.
## side is the network's traffic_side. Returns how many points were written.
## distances gets each point's metres from the start.
static func trace(lanes: Array[TrafficLane], chain: PackedInt32Array, start: float, lateral: float, side: int, reach: float, points: PackedVector2Array, distances: PackedFloat32Array) -> int:
	var count := 0
	var skip := start
	var lane_start := -start ## Path distance of the current lane's first point.
	for link in chain.size():
		var index := chain[link]
		if index < 0:
			break
		var lane := lanes[index]
		if skip >= lane.length:
			skip -= lane.length
			lane_start += lane.length
			continue
		var segment := lane.segment_at(maxf(skip, 0.0))
		if count == 0:
			var heading := lane.points[segment + 1] - lane.points[segment]
			points[0] = lane.point_at(maxf(skip, 0.0)) + _kerb(heading, side) * lateral
			distances[0] = 0.0
			count = 1
		for k in range(segment + 1, lane.points.size()):
			var heading := lane.points[k] - lane.points[k - 1]
			var along := lane_start + lane.lengths[k]
			if along >= reach:
				points[count] = lane.point_at(reach - lane_start) + _kerb(heading, side) * lateral
				distances[count] = reach
				return count + 1
			points[count] = lane.points[k] + _kerb(heading, side) * lateral
			distances[count] = along
			count += 1
			if count >= points.size():
				return count
		lane_start += lane.length
		skip = 0.0
	return count


## Metres along a traced path to where it first comes within grow of a box,
## or INF when it never does.
static func first_contact(points: PackedVector2Array, distances: PackedFloat32Array, count: int, box: TrafficBox, grow: float) -> float:
	if count == 1:
		last_segment = 0
		return 0.0 if segment_entry(points[0], points[0], box, grow) >= 0.0 else INF
	for k in count - 1:
		var share := segment_entry(points[k], points[k + 1], box, grow)
		if share >= 0.0:
			last_segment = k
			return lerpf(distances[k], distances[k + 1], share)
	return INF


## The span a box covers across a lane, from its least to its most kerbward
## point, measured from origin along kerb.
static func box_span(box: TrafficBox, origin: Vector2, kerb: Vector2) -> Vector2:
	var middle := (box.centre - origin).dot(kerb)
	var right := Vector2(-box.forward.y, box.forward.x)
	var reach := box.half_length * absf(box.forward.dot(kerb)) + box.half_width * absf(right.dot(kerb))
	return Vector2(middle - reach, middle + reach)


## How far a box reaches past origin along forward.
static func box_front(box: TrafficBox, origin: Vector2, forward: Vector2) -> float:
	var right := Vector2(-box.forward.y, box.forward.x)
	var reach := box.half_length * absf(box.forward.dot(forward)) + box.half_width * absf(right.dot(forward))
	return (box.centre - origin).dot(forward) + reach


## How to get past something spanning span across the lane. base is where the
## vehicle normally rides, and lane_lateral how far the lane's line is from the
## road's centre line. Returns (shift, needs_gap): the shift to make, and 1 when
## that takes it far enough over the centre line to need a gap in oncoming
## traffic. The shift is NAN when there is no room on either side. With
## allow_kerb false only the centre side is tried.
static func pass_target(span: Vector2, base: float, half_width: float, margin: float, lane_lateral: float, allow_kerb: bool = true) -> Vector2:
	var kerb_edge := RoadNetwork.ROAD_HALF_WIDTH - lane_lateral
	var far_edge := -lane_lateral - RoadNetwork.ROAD_HALF_WIDTH
	var best := NAN
	var needs_gap := 0.0
	var centre_side := span.x - margin - half_width
	if centre_side - half_width >= far_edge + ROAD_EDGE_MARGIN and centre_side - base >= -MAX_SHIFT:
		best = minf(centre_side - base, 0.0)
		needs_gap = 1.0 if centre_side - half_width < -lane_lateral - FREE_REACH else 0.0
	var kerb_side := span.y + margin + half_width
	if allow_kerb and kerb_side + half_width <= kerb_edge - ROAD_EDGE_MARGIN:
		var shift := maxf(kerb_side - base, 0.0)
		if is_nan(best) or needs_gap > 0.0 or absf(shift) < absf(best):
			best = shift
			needs_gap = 0.0
	return Vector2(best, needs_gap)


## True when a vehicle may start a pass it has planned. One that only moves over
## within its own side goes at once. Crossing into the oncoming lane needs a
## wait first, a clear road and something that will stay put.
static func may_pass(needs_gap: bool, waited: float, wait_needed: float, oncoming_clear: bool, blocker_parked: bool) -> bool:
	if not needs_gap:
		return true
	return blocker_parked and waited >= wait_needed and oncoming_clear


## Fills front with the bus body and trailer with an articulated bus's rear
## section, each swept to where it will be shortly, so traffic reacts to where
## the bus is going and not only where it is. Returns true when the bus has a
## trailer.
static func bus_boxes(rear_axle: Vector2, heading: float, speed: float, spec: BusSpec, trailer_axle: Vector2, trailer_heading: float, front: TrafficBox, trailer: TrafficBox) -> bool:
	var forward := Vector2(-sin(heading), -cos(heading))
	front.kind = TrafficBox.Kind.BUS
	front.set_pose(rear_axle + forward * -spec.body_centre_z(), forward, spec.overall_length() / 2.0, spec.body_width / 2.0)
	front.velocity = forward * speed
	var articulated := spec.is_articulated()
	if articulated:
		var along := Vector2(-sin(trailer_heading), -cos(trailer_heading))
		var middle := (spec.trailer_wheelbase - spec.trailer_overhang) / 2.0
		trailer.kind = TrafficBox.Kind.TRAILER
		trailer.set_pose(trailer_axle + along * middle, along, (spec.trailer_wheelbase + spec.trailer_overhang) / 2.0, spec.body_width / 2.0)
		trailer.velocity = along * speed
	if speed > STILL_SPEED:
		grow_box(front, speed * BUS_SWEEP_SECONDS)
	elif speed < -STILL_SPEED:
		grow_box(trailer if articulated else front, speed * REVERSE_SWEEP_SECONDS - REVERSE_STANDOFF)
	return articulated


## Stretches a box ahead (metres > 0) or behind (metres < 0).
static func grow_box(box: TrafficBox, metres: float) -> void:
	box.centre += box.forward * metres / 2.0
	box.half_length += absf(metres) / 2.0


static func _kerb(heading: Vector2, side: int) -> Vector2:
	var forward := heading.normalized()
	return Vector2(-forward.y, forward.x) * float(side)
