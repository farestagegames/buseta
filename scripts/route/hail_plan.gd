class_name HailPlan
extends RefCounted
## Lays out an informal route for one shift: the named stops, plus people flagging
## the bus down at random spots between them. Every shift is a little different.

const CLEAR_OF_JUNCTIONS := 48.0
const CLEAR_OF_STOPS := 55.0
const CLEAR_OF_BUMPS := 28.0
const CLEAR_OF_PARKED_CARS := 26.0


## The route's stops in driving order, with hails added between them.
## finish false leaves out the end-of-route rules, for the endless route.
static func fill(data: Dictionary, network: RoadNetwork, shift_seed: int, map_data: Dictionary = {}, finish: bool = true) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = shift_seed
	var plan: Dictionary = data["hail"]
	var spacing: Array = plan["spacing"]
	var people: Array = plan["people"]
	var stops: Array = data["stops"]
	var filled: Array = []
	var since_vendor: int = 0
	# Small towns have short streets: a plan can stand people closer to the corners.
	var clear_of_junctions := float(plan.get("clear_of_junctions", CLEAR_OF_JUNCTIONS))
	# Metres driven since the last hail, carried over corners and U-turns.
	var carry := INF
	for leg: Dictionary in data["legs"]:
		var last_on_leg := -1.0
		var road: Dictionary = network.roads[leg["road"]]
		var dir := int(leg["dir"])
		var length: float = road["length"]
		var on_leg: Array = stops.filter(func(stop: Dictionary) -> bool: return stop["road"] == leg["road"] and int(stop["dir"]) == dir)
		var taken: Array[float] = []
		for stop: Dictionary in on_leg:
			taken.append(_driven(float(stop["along"]), length, dir))
		var entries: Array = on_leg.map(func(stop: Dictionary) -> Dictionary:
			var copy := stop.duplicate()
			copy["driven"] = _driven(float(stop["along"]), length, dir)
			return copy)
		if road.get("traffic", true):
			var driven := clear_of_junctions + random.randf_range(0.0, 40.0)
			while driven < length - clear_of_junctions:
				var along := driven if dir > 0 else length - driven
				var gap := carry + driven if last_on_leg < 0.0 else driven - last_on_leg
				if gap >= CLEAR_OF_STOPS and _is_clear(driven, taken) and _is_clear_of_street_things(along, leg["road"], dir, map_data):
					since_vendor += 1
					var hail := {
						"name": road.get("name", road["id"]), "road": leg["road"], "along": along, "dir": dir, "driven": driven,
						"waiting": random.randi_range(int(people[0]), int(people[1])), "due": 0,
					}
					if since_vendor >= int(plan.get("vendor_every", 999)):
						hail["vendor"] = true
						since_vendor = 0
					entries.append(hail)
					taken.append(driven)
					last_on_leg = driven
				driven += random.randf_range(float(spacing[0]), float(spacing[1]))
		carry = length - last_on_leg if last_on_leg >= 0.0 else carry + length
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["driven"]) < float(b["driven"]))
		filled.append_array(entries)
	if finish:
		_finish(filled)
	return filled


## The last stop before the depot is only for getting off, and every shift gets a
## vendor somewhere in its first half.
static func _finish(filled: Array) -> void:
	if filled.size() < 3:
		return
	var last_stop: Dictionary = filled[filled.size() - 2]
	last_stop["waiting"] = 0
	last_stop.erase("vendor")
	if not filled.any(func(entry: Dictionary) -> bool: return entry.get("vendor", false)):
		filled[filled.size() / 2 - 1]["vendor"] = true


static func _driven(along: float, length: float, dir: int) -> float:
	return along if dir > 0 else length - along


static func _is_clear(driven: float, taken: Array[float]) -> bool:
	for other in taken:
		if absf(other - driven) < CLEAR_OF_STOPS:
			return false
	return true


static func _is_clear_of_street_things(along: float, road: String, dir: int, map_data: Dictionary) -> bool:
	for feature: Dictionary in map_data.get("features", []):
		if feature["type"] == "speed_bump" and feature["road"] == road and absf(float(feature["along"]) - along) < CLEAR_OF_BUMPS:
			return false
	for car: Dictionary in map_data.get("parked_cars", []):
		if car["road"] == road and int(car["dir"]) == dir and absf(float(car["along"]) - along) < CLEAR_OF_PARKED_CARS:
			return false
	for prop: Dictionary in map_data.get("knockables", []):
		var on_the_road: bool = prop["kind"] != "stall"
		if on_the_road and prop["road"] == road and int(prop["dir"]) == dir and absf(float(prop["along"]) - along) < CLEAR_OF_PARKED_CARS:
			return false
	for line: Dictionary in map_data.get("cone_lines", []):
		var outside := maxf(float(line["from"]) - along, along - float(line["to"]))
		if line["road"] == road and int(line["dir"]) == dir and outside < CLEAR_OF_BUMPS:
			return false
	return true
