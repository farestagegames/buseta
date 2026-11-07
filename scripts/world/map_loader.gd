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
