class_name LaneGraph
extends RefCounted
## Builds the traffic network from the road map: a lane each way along every
## road, and a link across each junction for every legal movement.

const LANE_OFFSET := 1.9
## Cars wait well back, or a bus turning right would sweep across them.
const STOP_LINE_GAP := 5.4
## Traffic moves towards the centre to pass things parked in its lane.
const PASSING_OFFSET := 0.7
const PASSING_REACH := 13.0
const RING_RADIUS := 15.0
const LINK_SAMPLES := 9
const TURN_ANGLE := deg_to_rad(35.0)

var lanes: Array[TrafficLane] = []
var network: RoadNetwork
var into_node: Dictionary = {} ## Node id to road lanes that end there.
var out_of_node: Dictionary = {} ## Node id to road lanes that start there.
var links_at: Dictionary = {} ## Node id to links crossing it.


static func build(road_network: RoadNetwork, map_data: Dictionary) -> LaneGraph:
	var graph := LaneGraph.new()
	graph.network = road_network
	var blocks := graph._parked_blocks(map_data)
	for road: Dictionary in road_network.roads.values():
		if road.get("traffic", true):
			graph._add_road_lane(road, 1, blocks)
			graph._add_road_lane(road, -1, blocks)
	for node_id: String in road_network.nodes:
		graph._link_node(node_id)
	return graph


## Junctions with signals: where three or more roads meet.
func signal_nodes() -> Array[String]:
	var found: Array[String] = []
	for node_id: String in into_node:
		if network.nodes[node_id]["kind"] == "junction" and (into_node[node_id] as Array).size() >= 3:
			found.append(node_id)
	return found


func _parked_blocks(map_data: Dictionary) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for car: Dictionary in map_data.get("parked_cars", []):
		blocks.append({"road": car["road"], "dir": int(car["dir"]), "from": float(car["along"]) - 3.0, "to": float(car["along"]) + 3.0})
	for line: Dictionary in map_data.get("cone_lines", []):
		blocks.append({"road": line["road"], "dir": int(line["dir"]), "from": float(line["from"]), "to": float(line["to"])})
	return blocks


func _lateral_at(road_id: String, dir: int, along: float, blocks: Array[Dictionary]) -> float:
	var lateral := LANE_OFFSET
	for block in blocks:
		if block["road"] != road_id or block["dir"] != dir:
			continue
		var outside := maxf(float(block["from"]) - along, along - float(block["to"]))
		if outside < PASSING_REACH:
			var share := smoothstep(PASSING_REACH, 3.0, outside)
			lateral = minf(lateral, lerpf(LANE_OFFSET, PASSING_OFFSET, share))
	return lateral


func _add_road_lane(road: Dictionary, dir: int, blocks: Array[Dictionary]) -> void:
	var from_id: String = road["from"] if dir > 0 else road["to"]
	var to_id: String = road["to"] if dir > 0 else road["from"]
	var length: float = road["length"]
	var start_gap: float = float(network.nodes[from_id]["radius"]) + STOP_LINE_GAP
	var end_gap: float = float(network.nodes[to_id]["radius"]) + STOP_LINE_GAP
	var lane := TrafficLane.new()
	lane.road = road["id"]
	lane.end_node = to_id
	var distance := start_gap
	while distance < length - end_gap:
		var along := distance if dir > 0 else length - distance
		var lateral := _lateral_at(road["id"], dir, along, blocks)
		lane.points.append(network.sample(road["id"], along, lateral, dir)["position"])
		distance += RoadNetwork.SAMPLE_SPACING
	var last := length - end_gap if dir > 0 else end_gap
	lane.points.append(network.sample(road["id"], last, LANE_OFFSET, dir)["position"])
	lane.finish()
	var direction := lane.points[lane.points.size() - 1] - lane.points[lane.points.size() - 2]
	lane.group = 0 if absf(direction.x) >= absf(direction.y) else 1
	var index := lanes.size()
	lanes.append(lane)
	if not into_node.has(to_id):
		into_node[to_id] = []
	if not out_of_node.has(from_id):
		out_of_node[from_id] = []
	(into_node[to_id] as Array).append(index)
	(out_of_node[from_id] as Array).append(index)


func _link_node(node_id: String) -> void:
	links_at[node_id] = []
	if not into_node.has(node_id):
		return
	var node: Dictionary = network.nodes[node_id]
	for incoming: int in into_node[node_id]:
		for outgoing: int in out_of_node.get(node_id, []):
			if lanes[incoming].road != lanes[outgoing].road:
				_add_link(node, node_id, incoming, outgoing)
		if lanes[incoming].next.is_empty():
			# A road that ends here. Traffic turns back the way it came.
			for outgoing: int in out_of_node.get(node_id, []):
				_add_link(node, node_id, incoming, outgoing)


func _add_link(node: Dictionary, node_id: String, incoming: int, outgoing: int) -> void:
	var entry := lanes[incoming]
	var exit := lanes[outgoing]
	var start := entry.points[entry.points.size() - 1]
	var finish := exit.points[0]
	var into := entry.forward_at(entry.length - 0.1)
	var out := exit.forward_at(0.1)
	var angle := into.angle_to(out)
	var link := TrafficLane.new()
	link.is_link = true
	link.node = node_id
	link.from_lane = incoming
	link.turn = 0 if absf(angle) < TURN_ANGLE else (1 if angle > 0.0 else -1)
	if node["kind"] == "roundabout":
		_ring_points(link, node["position"], start, finish)
	else:
		_curve_points(link, start, into, finish, out)
	link.finish()
	link.next = [outgoing]
	var index := lanes.size()
	lanes.append(link)
	entry.next.append(index)
	(links_at[node_id] as Array).append(index)


func _curve_points(link: TrafficLane, start: Vector2, into: Vector2, finish: Vector2, out: Vector2) -> void:
	var reach := start.distance_to(finish) * 0.45
	var a := start + into * reach
	var b := finish - out * reach
	for i in LINK_SAMPLES + 1:
		var t := float(i) / float(LINK_SAMPLES)
		link.points.append(start.bezier_interpolate(a, b, finish, t))


## Right-hand traffic circles anticlockwise on the map, so the angle falls.
func _ring_points(link: TrafficLane, centre: Vector2, start: Vector2, finish: Vector2) -> void:
	var from_angle := (start - centre).angle()
	var to_angle := (finish - centre).angle()
	var sweep := wrapf(from_angle - to_angle, 0.0, TAU)
	if sweep < 0.2:
		sweep += TAU
	link.points.append(start)
	var steps := maxi(int(sweep / 0.25), 4)
	for i in range(1, steps):
		var angle := from_angle - sweep * float(i) / float(steps)
		link.points.append(centre + Vector2.RIGHT.rotated(angle) * RING_RADIUS)
	link.points.append(finish)
