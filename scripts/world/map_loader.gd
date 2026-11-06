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


static func build_ground(map_data: Dictionary, network: RoadNetwork) -> GroundSurface:
	var ground := GroundSurface.new()
	ground.network = network
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
