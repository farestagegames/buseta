extends Node
## Developer tool: drives the arcade course (Carrera Express) like a decent driver
## and reports how many arches it reaches under the current tuning, so the numbers
## can be checked without a phone. Run with tools/arcade_probe.sh. Not exported.
## PROBE_CRUISE overrides the cruise speed in m/s (default 16); PROBE_ROUTE picks
## the arcade by id (arcade_cafeto), default Puerto Marisol's.

const SCENE := "res://scenes/main/city_shift.tscn"
const MAX_SECONDS := 600.0
const CRUISE := 16.0
const LANE := 1.9
const ROUNDABOUT_RING := 15.5
const ROUNDABOUT_ENTRY := 22.0

var _city: CityShift
var _bus: BusController
var _traffic: TrafficSystem
var _path := PackedVector2Array()
var _speeds := PackedFloat32Array()
var _cursor: int = 0
var _sim_time: float = 0.0
var _finished: bool = false
var _arches: int = 0
var _distance: float = 0.0
var _crashes: int = 0
var _knocks: int = 0
var _max_speed: float = 0.0
var _speed_sum: float = 0.0
var _speed_ticks: int = 0
var _bump_spots: Array[Vector2] = []
var _map_data: Dictionary = {}
var _stuck_time: float = 0.0
var _cruise: float = CRUISE


func _ready() -> void:
	CityShift.shift_seed = 7
	var chosen := OS.get_environment("PROBE_CRUISE")
	if chosen != "" and chosen.is_valid_float():
		_cruise = chosen.to_float()
	Profile.load_from("user://arcade_probe_save.json")
	Profile.data.intro_done = true
	# PROBE_ROUTE picks a town's arcade by id (arcade_cafeto); default Puerto Marisol's.
	var arcade_id: String = Profile.catalog.arcade_route()["id"]
	var picked := OS.get_environment("PROBE_ROUTE")
	if picked != "" and Catalog.is_arcade(Profile.catalog.find(Catalog.ROUTES, picked)):
		arcade_id = picked
	(Profile.data.owned[Catalog.ROUTES] as Array).append(arcade_id)
	Profile.data.select(Catalog.ROUTES, arcade_id)
	CityShift.forced_rain = WeatherPlan.FORCE_DRY
	Engine.time_scale = 6.0
	Engine.max_physics_steps_per_frame = 32
	_city = (load(SCENE) as PackedScene).instantiate()
	add_child(_city)
	_bus = _city.get_node("Bus")
	_traffic = _city.get_node("Traffic")
	_build_path()
	GameEvents.route_extended.connect(func(_route: RouteRunner) -> void:
		_path.clear()
		_speeds.clear()
		_build_path())
	for feature: Dictionary in _city.ground.features:
		if feature["kind"] == "bump":
			_bump_spots.append(feature["position"])
	GameEvents.shift_completed.connect(func(summary: Dictionary) -> void:
		if summary.has("arcade"):
			_arches = int(summary["arcade"]["checkpoints"])
			_distance = float(summary["arcade"]["distance"])
			_report("FINISHED"))
	GameEvents.bus_collided.connect(func(speed: float) -> void:
		_crashes += 1
		if OS.get_environment("PROBE_VERBOSE") != "":
			print("PROBE crash %.1f m/s at (%.0f, %.0f), t %.1f" % [speed, _bus.global_position.x, _bus.global_position.z, _sim_time]))
	GameEvents.obstacle_hit.connect(func(_kind: String, _loss: float) -> void: _knocks += 1)


func _physics_process(dt: float) -> void:
	if _finished:
		return
	_sim_time += dt
	var speed := absf(_bus.model.speed)
	_max_speed = maxf(_max_speed, speed)
	_speed_sum += speed
	_speed_ticks += 1
	if _sim_time > MAX_SECONDS:
		_report("TIMED OUT")
		return
	var rear := Vector2(_bus.global_position.x, _bus.global_position.z)
	_stuck_time = _stuck_time + dt if absf(_bus.model.speed) < 0.2 else 0.0
	if _stuck_time > 30.0:
		_report("STUCK")
		return
	_steer(rear)
	_drive()


func _steer(rear: Vector2) -> void:
	var best := INF
	var last := mini(_cursor + 40, _path.size() - 1)
	for i in range(_cursor, last):
		var gap := rear.distance_squared_to(_path[i])
		if gap < best:
			best = gap
			_cursor = i
	var reach := maxf(9.0, absf(_bus.model.speed) * 1.1)
	var index := _cursor
	while index < _path.size() - 1 and _path[index].distance_to(rear) < reach:
		index += 1
	var offset := _path[index] - rear
	var forward := _bus.model.forward_vector()
	var right := Vector2(-forward.y, forward.x)
	var local_x := offset.dot(right)
	var distance := maxf(offset.length(), 0.1)
	var curvature := 2.0 * local_x / (distance * distance)
	var wheel_angle := atan(curvature * _bus.spec.wheelbase)
	var share := clampf(wheel_angle / deg_to_rad(_bus.spec.max_steer_degrees), -1.0, 1.0)
	GameEvents.ui_wheel_changed.emit(signf(share) * pow(absf(share), 1.0 / SteeringMapper.RESPONSE_CURVE))


func _drive() -> void:
	var target: float = _speeds[mini(_cursor, _speeds.size() - 1)]
	target = minf(target, _speed_for_traffic())
	target = minf(target, _speed_for_bumps())
	var error := target - _bus.model.speed
	if error > 0.3:
		GameEvents.ui_pedals_changed.emit(clampf(error * 0.4, 0.35, 0.9), 0.0)
	elif error < -0.8:
		GameEvents.ui_pedals_changed.emit(0.0, clampf(-error * 0.2, 0.35, 0.6))
	else:
		GameEvents.ui_pedals_changed.emit(0.0, 0.0)


func _speed_for_traffic() -> float:
	var ahead := _traffic.bus_gap_ahead()
	if float(ahead["gap"]) == INF:
		return INF
	var gap: float = maxf(float(ahead["gap"]) - 14.0, 0.0)
	var lead: float = ahead["speed"]
	return minf(lead + gap * 0.3, sqrt(lead * lead + gap * 2.2))


func _speed_for_bumps() -> float:
	var rear := Vector2(_bus.global_position.x, _bus.global_position.z)
	var forward := _bus.model.forward_vector()
	var limit := INF
	for spot in _bump_spots:
		var offset: Vector2 = spot - rear
		var ahead := offset.dot(forward)
		if ahead > -8.0 and ahead < 34.0 and absf(offset.dot(Vector2(-forward.y, forward.x))) < 5.0:
			limit = minf(limit, 3.5 + maxf(ahead - 12.0, 0.0) * 0.3)
	return limit


func _build_path() -> void:
	var route := _city.route
	var line := route.polyline
	for i in line.size():
		var along := route.distances[i]
		var before := line[maxi(i - 1, 0)]
		var after := line[mini(i + 1, line.size() - 1)]
		var forward := (after - before).normalized()
		var right := Vector2(-forward.y, forward.x) * float(_city.network.traffic_side)
		_path.append(line[i] + right * _lateral_at(along, line[i], forward, right))
		_speeds.append(_speed_at(i))
	_apply_roundabouts()
	_smooth_junctions()


## The lateral to drive at, dodging the map's cone lines and parked cars.
func _lateral_at(along: float, point: Vector2, forward: Vector2, right: Vector2) -> float:
	var lateral := LANE
	var map_data := _city_map()
	for car: Dictionary in map_data["parked_cars"]:
		var spot: Vector2 = _city.network.sample(car["road"], car["along"], 2.75, car["dir"])["position"]
		if point.distance_to(spot) < 26.0 and (spot - point).dot(right) > 0.0:
			lateral = minf(lateral, 0.45)
	for line: Dictionary in map_data.get("cone_lines", []):
		var from: Vector2 = _city.network.sample(line["road"], line["from"], line["lateral"], line["dir"])["position"]
		var to: Vector2 = _city.network.sample(line["road"], line["to"], line["lateral"], line["dir"])["position"]
		var same_way: bool = (to - from).dot(forward) * float(line["dir"]) > 0.0
		if same_way and Geometry2D.get_closest_point_to_segment(point, from, to).distance_to(point) < 20.0:
			lateral = 0.0
	return lateral


func _city_map() -> Dictionary:
	if _map_data.is_empty():
		_map_data = MapLoader.read_map_of(MapLoader.read_json(Profile.selected_item(Catalog.ROUTES)["file"]))
	return _map_data


func _speed_at(index: int) -> float:
	var line := _city.route.polyline
	var limit := _cruise
	for look in [2, 5, 8]:
		var i := mini(index + look, line.size() - 2)
		if i < 1:
			continue
		var turn := absf((line[i] - line[i - 1]).angle_to(line[i + 1] - line[i]))
		if turn > deg_to_rad(4.0):
			limit = minf(limit, 13.0)
		if turn > deg_to_rad(25.0):
			limit = 8.0
	return limit


func _smooth_junctions() -> void:
	for node: Dictionary in _city.network.nodes.values():
		if node["kind"] != "junction":
			continue
		var centre: Vector2 = node["position"]
		var i := 0
		while i < _path.size():
			if _path[i].distance_to(centre) >= 22.0:
				i += 1
				continue
			var first := i
			while i < _path.size() and _path[i].distance_to(centre) < 22.0:
				i += 1
			_curve_through(first, i - 1)


func _curve_through(first: int, last: int) -> void:
	if first < 2 or last > _path.size() - 3 or last <= first:
		return
	var start := _path[first]
	var finish := _path[last]
	var into := (_path[first] - _path[first - 2]).normalized()
	var out := (_path[last + 2] - _path[last]).normalized()
	var reach := start.distance_to(finish) * 0.42
	var steps := last - first
	var turning := absf(into.angle_to(out)) > deg_to_rad(30.0)
	for i in steps + 1:
		var t := float(i) / float(steps)
		_path[first + i] = start.bezier_interpolate(start + into * reach, finish - out * reach, finish, t)
		if turning:
			_speeds[first + i] = minf(_speeds[first + i], 5.0)


func _apply_roundabouts() -> void:
	for node: Dictionary in _city.network.nodes.values():
		if node["kind"] != "roundabout":
			continue
		var centre: Vector2 = node["position"]
		var inside := func(i: int) -> bool: return _path[i].distance_to(centre) < ROUNDABOUT_ENTRY
		var i := _path.size() - 1
		while i >= 0:
			if not inside.call(i):
				i -= 1
				continue
			var last := i
			while i > 0 and inside.call(i - 1):
				i -= 1
			_circle_island(i, last, centre)
			i -= 1


func _circle_island(first: int, last: int, centre: Vector2) -> void:
	var from_angle := (_path[first] - centre).angle()
	var to_angle := (_path[last] - centre).angle()
	var spin := float(_city.network.traffic_side)
	while (to_angle - from_angle) * spin >= 0.0:
		to_angle -= TAU * spin
	var steps := ceili(absf(from_angle - to_angle) * ROUNDABOUT_RING / 3.0)
	var ring := PackedVector2Array()
	var speeds := PackedFloat32Array()
	for step in steps + 1:
		var angle := lerpf(from_angle, to_angle, float(step) / float(steps))
		ring.append(centre + Vector2.from_angle(angle) * ROUNDABOUT_RING)
		speeds.append(6.0)
	_path = _path.slice(0, first) + ring + _path.slice(last + 1)
	_speeds = _speeds.slice(0, first) + speeds + _speeds.slice(last + 1)


func _report(outcome: String) -> void:
	if _finished:
		return
	_finished = true
	print("PROBE %s" % outcome)
	print("PROBE cruise %.1f m/s, time %.1f s" % [_cruise, _sim_time])
	print("PROBE arches %d, distance %.0f m, crashes %d, knocks %d" % [_arches, _distance, _crashes, _knocks])
	print("PROBE speed avg %.1f m/s, max %.1f m/s" % [_speed_sum / maxf(_speed_ticks, 1), _max_speed])
	get_tree().quit.call_deferred()
