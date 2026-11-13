class_name ArcadeObstacles
extends RefCounted
## Lays out the extra cones and barriers that appear as an arcade run tightens.
## Pure logic: given the arches passed and the run's checkpoint and pad distances,
## it returns where each prop sits along the course. Every prop sits on the kerb
## side of the bus's own lane, so a clear way is always left on the road side,
## and none is ever placed on a boost pad or under a checkpoint arch.


## How many obstacle sets should exist after this many arches. Sets start after
## first_arch, and every_arches more arches adds sets_per_batch more.
static func set_count(arches: int, config: Dictionary) -> int:
	var first := int(config.get("first_arch", 2))
	var every := maxi(int(config.get("every_arches", 3)), 1)
	var per := int(config.get("sets_per_batch", 2))
	if arches < first:
		return 0
	return per * (int((arches - first) / every) + 1)


## Places `count` new sets forwards from start_distance. Each set is a short line
## of cones or a single barrier, all on the kerb side of the lane. Returns each
## prop as {distance: float, kind: String, lateral: float}, where lateral is metres
## from the road centre line towards the kerb.
static func place_sets(start_distance: float, count: int, checkpoints: PackedFloat32Array, boosts: PackedFloat32Array, config: Dictionary) -> Array[Dictionary]:
	var kinds: Array = config.get("kinds", ["cone", "barrier"])
	if kinds.is_empty():
		kinds = ["cone"]
	var set_spacing := float(config.get("set_spacing", 90.0))
	var cone_count := int(config.get("cone_count", 3))
	var cone_spacing := float(config.get("cone_spacing", 3.0))
	var out: Array[Dictionary] = []
	var distance := start_distance
	for i in count:
		var kind := str(kinds[i % kinds.size()])
		var extent := float(cone_count - 1) * cone_spacing if kind == "cone" else 0.0
		distance = next_clear(distance, extent, checkpoints, boosts, config)
		var lateral := lateral_at(i, config)
		if kind == "cone":
			for j in cone_count:
				out.append({"distance": distance + float(j) * cone_spacing, "kind": "cone", "lateral": lateral})
		else:
			out.append({"distance": distance, "kind": "barrier", "lateral": lateral})
		distance += set_spacing
	return out


## A deterministic lateral in the kerb-side band, so sets spread across it.
static func lateral_at(set_index: int, config: Dictionary) -> float:
	var lo := float(config.get("lateral_min", 2.2))
	var hi := float(config.get("lateral_max", 3.2))
	return lo + (hi - lo) * float(set_index % 3) / 2.0


## Advances distance until a set spanning [distance, distance + extent] stays
## clear of every pad and arch by the configured clearance.
static func next_clear(distance: float, extent: float, checkpoints: PackedFloat32Array, boosts: PackedFloat32Array, config: Dictionary) -> float:
	var arch_clearance := float(config.get("arch_clearance", 24.0))
	var pad_clearance := float(config.get("pad_clearance", 26.0))
	while blocked(distance, extent, checkpoints, arch_clearance) or blocked(distance, extent, boosts, pad_clearance):
		distance += 4.0
	return distance


## True when any point sits within clearance of the set's span along the course.
static func blocked(distance: float, extent: float, points: PackedFloat32Array, clearance: float) -> bool:
	for point in points:
		if point > distance - clearance and point < distance + extent + clearance:
			return true
	return false
