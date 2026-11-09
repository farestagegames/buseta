class_name EndlessPlanner
extends RefCounted
## Plans the road ahead on the endless route: a seeded wander through the city,
## one road after another, never doubling straight back unless the road ends,
## and never on a busway.


## count more legs after the leg (road, dir). Each leg is {road, dir}.
static func walk(network: RoadNetwork, road_id: String, dir: int, count: int, random: RandomNumberGenerator) -> Array:
	var legs: Array = []
	var current := road_id
	var heading := dir
	for i in count:
		var road: Dictionary = network.roads[current]
		var node: String = road["to"] if heading > 0 else road["from"]
		var choices := exits(network, node, current)
		if choices.is_empty():
			# A dead end: turn round and drive back.
			choices = [{"road": current, "dir": -heading}]
		var next: Dictionary = choices[random.randi_range(0, choices.size() - 1)]
		legs.append(next)
		current = next["road"]
		heading = int(next["dir"])
	return legs


## The roads leaving node, other than the one just driven, as {road, dir}.
static func exits(network: RoadNetwork, node: String, came_on: String) -> Array:
	var out: Array = []
	for road: Dictionary in network.roads.values():
		if road["id"] == came_on or road.get("busway", false):
			continue
		if road["from"] == node:
			out.append({"road": road["id"], "dir": 1})
		if road["to"] == node:
			out.append({"road": road["id"], "dir": -1})
	return out


## Stops for these legs: people flagging the bus down along them, named after the
## street, with no last stop. first_index is the index the first new stop gets.
static func hails(legs: Array, plan: Dictionary, network: RoadNetwork, random_seed: int, map_data: Dictionary) -> Array:
	return HailPlan.fill({"legs": legs, "hail": plan, "stops": []}, network, random_seed, map_data, false)
