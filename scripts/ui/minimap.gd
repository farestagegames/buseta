class_name Minimap
extends Control
## Small north-up map of the roads, the route, the bus and the next stop.

const PADDING := 12.0
const REDRAW_SECONDS := 0.2

var _road_lines: Array[PackedVector2Array] = []
var _route_line: PackedVector2Array = PackedVector2Array()
var _low: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _bus: Vector2 = Vector2.ZERO
var _bus_heading: float = 0.0
var _stop: Vector2 = Vector2.ZERO
var _has_stop: bool = false
var _timer: float = 0.0
var _style := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_style.bg_color = Color(0.08, 0.09, 0.12, 0.66)
	_style.set_corner_radius_all(14)


func _ready() -> void:
	GameEvents.map_ready.connect(_on_map_ready)
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.route_status_updated.connect(_on_status)


func _on_map_ready(network: RoadNetwork, route: RouteRunner) -> void:
	var high := Vector2(-INF, -INF)
	_low = Vector2(INF, INF)
	for road: Dictionary in network.roads.values():
		var points: PackedVector2Array = road["points"]
		for point in points:
			_low = Vector2(minf(_low.x, point.x), minf(_low.y, point.y))
			high = Vector2(maxf(high.x, point.x), maxf(high.y, point.y))
	var span := maxf(high.x - _low.x, high.y - _low.y)
	_scale = (size.x - PADDING * 2.0) / span
	_road_lines.clear()
	for road: Dictionary in network.roads.values():
		_road_lines.append(_to_map_line(road["points"]))
	_route_line = _to_map_line(route.polyline)
	visible = true
	queue_redraw()


func _to_map_line(points: PackedVector2Array) -> PackedVector2Array:
	var line := PackedVector2Array()
	var step := maxi(points.size() / 24, 1)
	for i in range(0, points.size(), step):
		line.append(_to_map(points[i]))
	line.append(_to_map(points[points.size() - 1]))
	return line


func _to_map(point: Vector2) -> Vector2:
	return (point - _low) * _scale + Vector2.ONE * PADDING


func _on_telemetry(data: BusTelemetry) -> void:
	_bus = Vector2(data.position.x, data.position.z)
	_bus_heading = data.heading
	_timer -= get_physics_process_delta_time()
	if _timer <= 0.0 and visible:
		_timer = REDRAW_SECONDS
		queue_redraw()


func _on_status(status: Dictionary) -> void:
	_stop = status["stop_position"]
	_has_stop = true


func _draw() -> void:
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	for line in _road_lines:
		draw_polyline(line, Color(1, 1, 1, 0.28), 3.0)
	if _route_line.size() > 1:
		draw_polyline(_route_line, Color(0.98, 0.72, 0.15, 0.85), 3.0)
	if _has_stop:
		draw_circle(_to_map(_stop), 6.0, Color(0.25, 0.85, 0.45))
	var bus := _to_map(_bus)
	var forward := Vector2(-sin(_bus_heading), -cos(_bus_heading))
	var right := Vector2(-forward.y, forward.x)
	draw_colored_polygon(PackedVector2Array([bus + forward * 9.0, bus - forward * 6.0 + right * 6.0,
		bus - forward * 6.0 - right * 6.0]), Color(1.0, 0.3, 0.25))
