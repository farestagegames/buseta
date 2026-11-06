extends Node
## Developer tool: drives a whole shift through the real controls and reports
## what happened. Proves the route can be completed by a 12 m bus. Run with
## tools/autopilot.sh. Not included in exported builds.

const SCENE := "res://scenes/main/city_shift.tscn"
const TIME_SCALE := 6.0
const MAX_SECONDS := 900.0
const CRUISE := 11.0
const LANE := 1.9
const ROUNDABOUT_RING := 15.5

var _city: CityShift
var _bus: BusController
var _system: RouteSystem
var _path := PackedVector2Array()
var _speeds := PackedFloat32Array()
var _cursor: int = 0
var _sim_time: float = 0.0
var _collisions: Array[String] = []
var _jolts: int = 0
var _knocks: Array[String] = []
var _missed: Array[String] = []
var _off_road: float = 0.0
var _hold: bool = false
var _finished: bool = false
var _stuck_time: float = 0.0
var _traffic: TrafficSystem
var _keeper: ScoreKeeper
var _arrivals: Array[int] = []
var _report_text: Dictionary = {}
var _red_lights: int = 0
var _braking_for_stop: bool = false
var _bump_spots: Array[Vector2] = []
var _next_turn: int = 0
var _jolt_places: Dictionary = {}
var _off_road_places: Dictionary = {}


func _ready() -> void:
	Engine.time_scale = TIME_SCALE
	Engine.max_physics_steps_per_frame = 32
	_city = (load(SCENE) as PackedScene).instantiate()
	add_child(_city)
	_bus = _city.get_node("Bus")
	_system = _city.get_node("RouteSystem")
	_traffic = _city.get_node("Traffic")
	_keeper = _city.get_node("ScoreKeeper")
	_build_path()
	for feature: Dictionary in _city.ground.features:
		if feature["kind"] == "bump":
			_bump_spots.append(feature["position"])
	GameEvents.stop_arrived.connect(func(_i: int, _a: float, _l: float) -> void: _arrivals.append(roundi(_system.clock)))
	GameEvents.red_light_run.connect(func() -> void: _red_lights += 1)
	GameEvents.shift_report_ready.connect(func(report: Dictionary) -> void: _report_text = report)
	GameEvents.bus_collided.connect(func(speed: float) -> void:
		_collisions.append("%.1f m/s at (%d, %d) near %s" % [speed, _bus.global_position.x, _bus.global_position.z, _system.runner.current_stop().stop_name]))
	GameEvents.bus_jolted.connect(func(_s: float) -> void:
		_jolts += 1
		_tally(_jolt_places, Vector2(_bus.global_position.x, _bus.global_position.z)))
	GameEvents.obstacle_hit.connect(func(kind: String, _l: float) -> void: _knocks.append(kind))
	GameEvents.stop_missed.connect(func(_i: int, stop_name: String) -> void: _missed.append(stop_name))
	GameEvents.shift_report_ready.connect(_on_finished)


func _physics_process(dt: float) -> void:
	if _finished:
		return
	_sim_time += dt
	if _sim_time > MAX_SECONDS:
		_report("TIMED OUT at stop %s" % _system.runner.current_stop().stop_name)
		return
	var rear := Vector2(_bus.global_position.x, _bus.global_position.z)
	var edge := _city.network.edge_distance(rear)
	if edge > 0.0:
		_off_road += dt
		_tally(_off_road_places, rear)
	_watch_for_stuck(dt)
	_run_stop_logic()
	if _hold:
		return
	_signal_turns()
	_steer(rear)
	if not _braking_for_stop:
		_drive()


func _watch_for_stuck(dt: float) -> void:
	_stuck_time = _stuck_time + dt if absf(_bus.model.speed) < 0.2 and not _hold else 0.0
	if _stuck_time > 25.0:
		_report("STUCK at (%d, %d) near %s" % [_bus.global_position.x, _bus.global_position.z, _system.runner.current_stop().stop_name])


func _run_stop_logic() -> void:
	var stop := _system.runner.current_stop()
	if _hold and _bus.doors.is_closed() and _system.session == null:
		_hold = false
	if stop == null or stop.is_final:
		return
	var centre := BusFootprint.body_centre(Vector2(_bus.global_position.x, _bus.global_position.z), _bus.model.heading, _bus.spec)
	var aligned := stop.is_aligned(centre, _bus.model.heading)
	var near_middle := absf(stop.offset_of(centre).x) < 2.5
	_braking_for_stop = false
	if not _hold and aligned and near_middle:
		_braking_for_stop = true
		GameEvents.ui_pedals_changed.emit(0.0, 0.45)
		if _bus.model.is_stopped() and _bus.doors.is_closed():
			_hold = true
			GameEvents.ui_wheel_changed.emit(0.0)
			GameEvents.door_toggle_requested.emit()
	elif _hold and _system.session != null and _system.session.is_complete() and _bus.doors.state == BusDoors.State.OPEN:
		GameEvents.door_toggle_requested.emit()


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
	var stop := _system.runner.current_stop()
	if stop != null:
		var ahead: float = _system.runner.distance_to_next_stop()
		if ahead < 60.0:
			target = minf(target, maxf(2.0, ahead * 0.3))
		if stop.is_final and ahead < 1.0:
			target = 0.0
	target = minf(target, _limit_for_road())
	target = minf(target, _speed_for_signal())
	target = minf(target, _speed_for_traffic())
	target = minf(target, _speed_for_bumps())
	var error := target - _bus.model.speed
	if target <= 0.05:
		GameEvents.ui_pedals_changed.emit(0.0, 0.5)
	elif error > 0.3:
		GameEvents.ui_pedals_changed.emit(clampf(error * 0.4, 0.35, 0.72), 0.0)
	elif error < -0.8:
		GameEvents.ui_pedals_changed.emit(0.0, clampf(-error * 0.2, 0.35, 0.5))
	else:
		GameEvents.ui_pedals_changed.emit(0.0, 0.0)


func _tally(places: Dictionary, point: Vector2) -> void:
	var key := Vector2i(int(point.x / 25.0) * 25, int(point.y / 25.0) * 25)
	places[key] = int(places.get(key, 0)) + 1


func _limit_for_road() -> float:
	var rear := Vector2(_bus.global_position.x, _bus.global_position.z)
	var limit := _city.network.speed_limit_at(rear)
	return (limit - 2.0) / 3.6


func _speed_for_signal() -> float:
	var ahead := _traffic.bus_signal()
	if int(ahead["state"]) < 0 or int(ahead["state"]) == TrafficLightPlan.Light.GREEN:
		return INF
	var distance: float = float(ahead["distance"]) - 2.0
	if int(ahead["state"]) == TrafficLightPlan.Light.AMBER and _bus.model.speed * _bus.model.speed / 4.0 > distance:
		return INF
	return maxf(sqrt(maxf(distance, 0.0) * 2.0 * 1.2) - 0.4, 0.0)


func _speed_for_traffic() -> float:
	var ahead := _traffic.bus_gap_ahead()
	if float(ahead["gap"]) == INF:
		return INF
	var gap: float = maxf(float(ahead["gap"]) - 8.0, 0.0)
	var lead: float = ahead["speed"]
	return minf(lead + gap * 0.35, sqrt(lead * lead + gap * 2.4))


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


func _signal_turns() -> void:
	var runner := _system.runner
	if _next_turn >= runner.turns.size():
		return
	var turn: Dictionary = runner.turns[_next_turn]
	var ahead := float(turn["distance"]) - runner.progress
	var side: int = turn["side"]
	if ahead < 55.0 and side != 0 and _bus.indicators.side != side:
		GameEvents.indicator_toggle_requested.emit(side)
	if ahead < -18.0:
		_next_turn += 1


func _build_path() -> void:
	var route := _city.route
	var line := route.polyline
	for i in line.size():
		var along := route.distances[i]
		var before := line[maxi(i - 1, 0)]
		var after := line[mini(i + 1, line.size() - 1)]
		var forward := (after - before).normalized()
		var right := Vector2(-forward.y, forward.x)
		var point := line[i] + right * _lateral_at(along, line[i])
		_path.append(point)
		_speeds.append(_speed_at(i))
	_apply_roundabouts()
	_smooth_junctions()


func _lateral_at(along: float, point: Vector2) -> float:
	var lateral := LANE
	for stop in _city.route.stops:
		var relative := along - stop.route_distance
		if relative > -30.0 and relative < 30.0:
			var share := smoothstep(-30.0, -10.0, relative)
			share = minf(share, 1.0 - smoothstep(8.0, 30.0, relative))
			lateral = lerpf(LANE, RoadNetwork.ROAD_HALF_WIDTH + 1.25, share)
	var map_data := MapLoader.read_json("res://data/maps/city_01.json")
	for car: Dictionary in map_data["parked_cars"]:
		var spot: Vector2 = _city.network.sample(car["road"], car["along"])["position"]
		if point.distance_to(spot) < 26.0:
			lateral = minf(lateral, 0.45)
	for line: Dictionary in map_data["cone_lines"]:
		var from: Vector2 = _city.network.sample(line["road"], line["from"])["position"]
		var to: Vector2 = _city.network.sample(line["road"], line["to"])["position"]
		if Geometry2D.get_closest_point_to_segment(point, from, to).distance_to(point) < 20.0:
			lateral = 0.0
	return lateral


func _speed_at(index: int) -> float:
	var line := _city.route.polyline
	var limit := CRUISE
	for look in [2, 5, 8]:
		var i := mini(index + look, line.size() - 2)
		if i < 1:
			continue
		var turn := absf((line[i] - line[i - 1]).angle_to(line[i + 1] - line[i]))
		if turn > deg_to_rad(4.0):
			limit = minf(limit, 7.0)
		if turn > deg_to_rad(25.0):
			limit = 3.5
	return limit


## A driver sweeps through a junction on a curve rather than a sharp corner.
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
			_speeds[first + i] = minf(_speeds[first + i], 4.5)


func _apply_roundabouts() -> void:
	for node: Dictionary in _city.network.nodes.values():
		if node["kind"] != "roundabout":
			continue
		var centre: Vector2 = node["position"]
		for i in _path.size():
			var offset := _path[i] - centre
			if absf(offset.x) < ROUNDABOUT_RING and absf(offset.y) < 8.0:
				var angle := acos(clampf(offset.x / ROUNDABOUT_RING, -1.0, 1.0))
				_path[i] = centre + Vector2(cos(angle), sin(angle)) * ROUNDABOUT_RING
				_speeds[i] = 5.0


func _on_finished(report: Dictionary) -> void:
	_report("FINISHED: score %d, %d stars, %d coins, carried %d" % [report["score"], report["stars"], report["coins"], report["carried"]])
	print("AUTOPILOT categories ", report["categories"])
	print("AUTOPILOT details ", report["details"])


func _report(outcome: String) -> void:
	if _finished:
		return
	_finished = true
	print("AUTOPILOT ", outcome)
	print("AUTOPILOT shift time %d:%02d (%d s)" % [int(_sim_time) / 60, int(_sim_time) % 60, _sim_time])
	print("AUTOPILOT collisions ", _collisions.size())
	for line in _collisions.slice(0, 12):
		print("AUTOPILOT   ", line)
	print("AUTOPILOT jolts ", _jolts, ", props knocked ", _knocks, ", missed ", _missed)
	print("AUTOPILOT rear axle off road for %.1f s" % _off_road)
	print("AUTOPILOT arrivals ", _arrivals, " red lights ", _red_lights)
	print("AUTOPILOT jolt places ", _top(_jolt_places))
	print("AUTOPILOT off road places ", _top(_off_road_places))
	get_tree().quit.call_deferred()


func _top(places: Dictionary) -> Array:
	var rows: Array = []
	for key: Vector2i in places:
		rows.append([places[key], key])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return rows.slice(0, 10)
