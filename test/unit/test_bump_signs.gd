extends GutTest
## Speed bump warning signs stand beside their own road on every map, never out
## in a junction or on another road (owner, Alto Cafeto: signs in the road).

const MAPS := ["res://data/packs/colombia/maps/puerto_marisol.json",
	"res://data/packs/colombia/maps/alto_cafeto.json",
	"res://data/packs/colombia/maps/puerto_remanso.json"]


func _bumps(map_data: Dictionary) -> Array:
	return map_data.get("features", []).filter(func(f: Dictionary) -> bool: return f["type"] == "speed_bump")


func test_every_warning_sign_stands_off_the_asphalt() -> void:
	for path: String in MAPS:
		var map_data := MapLoader.read_json(path)
		var network := RoadNetwork.from_data(map_data)
		var signs := 0
		for bump: Dictionary in _bumps(map_data):
			for approach: float in [-1.0, 1.0]:
				var at := CityBuilder.bump_warning_along(network, bump["road"], float(bump["along"]), approach)
				if is_nan(at):
					continue
				var road: Dictionary = network.roads[bump["road"]]
				assert_between(at, float(network.nodes[road["from"]]["radius"]), float(road["length"]) - float(network.nodes[road["to"]]["radius"]),
					"%s %s stays on its own road" % [map_data["name"], bump["road"]])
				for side: float in [-1.0, 1.0]:
					var pose := CityBuilder.bump_sign_pose(network, bump["road"], at, side)
					if pose.is_empty():
						continue
					signs += 1
					assert_gt(network.edge_distance(pose["position"]), 0.0, "%s %s sign off the road" % [map_data["name"], bump["road"]])
		assert_gt(signs, 0, "%s still has its warning signs" % map_data["name"])


## The cause: 30 m before a bump near the start of a short road is past its end.
func test_a_bump_near_a_road_end_pulls_its_warning_back_onto_the_road() -> void:
	var map_data := MapLoader.read_json(MAPS[1])
	var network := RoadNetwork.from_data(map_data)
	var road: Dictionary = network.roads["calle_real"]
	var start := float(network.nodes[road["from"]]["radius"])
	assert_lt(26.0 - 30.0, start, "The old spot was inside the junction")
	var at := CityBuilder.bump_warning_along(network, "calle_real", 26.0, -1.0)
	assert_true(is_nan(at) or at > start, "Now it is on the road or left out")


func test_a_road_too_short_to_warn_ahead_gets_no_sign() -> void:
	var network := RoadNetwork.new()
	network.add_node("a", Vector2.ZERO, "junction", 15.0, 0.0)
	network.add_node("b", Vector2(0.0, 40.0), "junction", 15.0, 0.0)
	network.add_road("r", "a", "b", [] as Array[Vector2])
	assert_true(is_nan(CityBuilder.bump_warning_along(network, "r", 20.0, -1.0)))
