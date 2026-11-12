class_name MapLoader
extends RefCounted
## Reads a map data file into its logic objects.

const POTHOLE_RADIUS := 0.65
const POTHOLE_DEPTH := 0.09
const BUMP_HALF_LENGTH := 0.45
const BUMP_HEIGHT := 0.09


static func read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(parsed is Dictionary, "Could not read %s" % path)
	return parsed


## The map a route runs on, wherever its country pack keeps it.
static func read_map_of(route_data: Dictionary) -> Dictionary:
	return read_json(Country.pack.resolve(route_data["map"]))


## Optional bird clusters: sound everywhere, with visuals only where flock is set.
static func check_bird_clusters(entries: Variant) -> Array[String]:
	var problems: Array[String] = []
	if entries == null:
		return problems
	if not entries is Array:
		problems.append("bird_clusters must be a list")
		return problems
	var ids := {}
	for entry: Variant in entries:
		if not entry is Dictionary:
			problems.append("Bird clusters need to be objects")
			continue
		var label := str(entry.get("id", ""))
		if not entry.get("id") is String or label.strip_edges().is_empty():
			problems.append("Bird cluster needs id as some text")
		elif ids.has(label):
			problems.append("Bird clusters have %s twice" % label)
		ids[label] = true
		for key: String in ["x", "z", "perch", "flock", "range"]:
			if not (entry.get(key) is float or entry.get(key) is int):
				problems.append("Bird cluster %s needs %s as a number" % [label, key])
		if (entry.get("perch") is float or entry.get("perch") is int) and float(entry["perch"]) < 0.0:
			problems.append("Bird cluster %s needs perch at or above zero" % label)
		if (entry.get("flock") is float or entry.get("flock") is int):
			var flock := float(entry["flock"])
			if flock != floorf(flock) or not (flock == 0.0 or (flock >= 3.0 and flock <= 6.0)):
				problems.append("Bird cluster %s needs flock as 0 or 3 to 6" % label)
		if (entry.get("range") is float or entry.get("range") is int) and not (float(entry["range"]) >= 25.0 and float(entry["range"]) <= 35.0):
			problems.append("Bird cluster %s needs range from 25 to 35" % label)
	return problems


static func build_ground(map_data: Dictionary, network: RoadNetwork) -> GroundSurface:
	var ground := GroundSurface.new()
	ground.network = network
	var coast: Dictionary = map_data.get("coast", {})
	if not coast.is_empty():
		ground.coast_x = coast["x"]
		ground.beach_width = coast["beach"]
	for hill: Dictionary in map_data.get("hills", []):
		ground.add_hill(Vector2(hill["x"], hill["z"]), hill["radius"], hill["height"])
	for feature: Dictionary in map_data.get("features", []):
		if feature["type"] == "speed_bump":
			var placed: Dictionary = network.sample(feature["road"], feature["along"])
			ground.add_speed_bump(placed["position"], placed["forward"], BUMP_HALF_LENGTH, RoadNetwork.ROAD_HALF_WIDTH, BUMP_HEIGHT)
		else:
			var placed: Dictionary = network.sample(feature["road"], feature["along"], feature["lateral"], feature["dir"])
			ground.add_pothole(placed["position"], POTHOLE_RADIUS, POTHOLE_DEPTH)
	return ground
