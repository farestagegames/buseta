class_name Minimap
extends TouchZone
## Small north-up map of the roads, the route, the bus and the next stop, in a
## circle in the corner. A tap grows it, and another tap shrinks it back.

signal size_toggled(expanded: bool)

const SMALL := 128.0
const LARGE := 260.0
const PADDING := 12.0
const REDRAW_SECONDS := 0.2
## On the endless route the map shows only this far of the road ahead.
const ENDLESS_LINE_AHEAD := 700.0

var _road_lines: Array[PackedVector2Array] = []
var _route_line: PackedVector2Array = PackedVector2Array()
var _low: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _offset: Vector2 = Vector2.ONE * PADDING
var _bus: Vector2 = Vector2.ZERO
var _bus_heading: float = 0.0
var _stop: Vector2 = Vector2.ZERO
var _has_stop: bool = false
var _timer: float = 0.0
var _route: RouteRunner
var _network: RoadNetwork
var _span: float = 1.0
var expanded: bool = false


func _init() -> void:
	super()
	visible = false
	clip_contents = false


func diameter() -> float:
	return LARGE if expanded else SMALL


func toggle_size() -> void:
	expanded = not expanded
	_fit()
	size_toggled.emit(expanded)


func _touch_down(_point: Vector2) -> void:
	toggle_size()


func _accepts(point: Vector2) -> bool:
	var centre := get_global_rect().get_center()
	return point.distance_to(centre) <= diameter() / 2.0 + touch_margin


func _ready() -> void:
	GameEvents.map_ready.connect(_on_map_ready)
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.route_status_updated.connect(_on_status)
	GameEvents.arcade_status.connect(func(_left: float, _number: int, _distance: float, spot: Vector2, _boost: bool) -> void:
		_stop = spot
		_has_stop = true)


func _on_map_ready(network: RoadNetwork, route: RouteRunner) -> void:
	var high := Vector2(-INF, -INF)
	_low = Vector2(INF, INF)
	for road: Dictionary in network.roads.values():
		var points: PackedVector2Array = road["points"]
		for point in points:
			_low = Vector2(minf(_low.x, point.x), minf(_low.y, point.y))
			high = Vector2(maxf(high.x, point.x), maxf(high.y, point.y))
	_span = maxf(maxf(high.x - _low.x, high.y - _low.y), 1.0)
	_network = network
	_route = route
	_fit()
	visible = true


## Map lines for the current size. The whole map fits the square inside the circle.
func _fit() -> void:
	if _network == null:
		return
	var inner := size.x / sqrt(2.0)
	_scale = (inner - PADDING) / _span
	_offset = Vector2.ONE * (size.x - inner + PADDING) / 2.0
	_road_lines.clear()
	for road: Dictionary in _network.roads.values():
		_road_lines.append(_to_map_line(road["points"]))
	_route_line = _to_map_line(_route.line_ahead(ENDLESS_LINE_AHEAD) if _route.endless else _route.polyline)
	queue_redraw()


func _to_map_line(points: PackedVector2Array) -> PackedVector2Array:
	var line := PackedVector2Array()
	if points.is_empty():
		return line
	var step := maxi(points.size() / 24, 1)
	for i in range(0, points.size(), step):
		line.append(_to_map(points[i]))
	line.append(_to_map(points[points.size() - 1]))
	return line


func _to_map(point: Vector2) -> Vector2:
	return (point - _low) * _scale + _offset


func _on_telemetry(data: BusTelemetry) -> void:
	_bus = Vector2(data.position.x, data.position.z)
	_bus_heading = data.heading
	_timer -= get_physics_process_delta_time()
	if _timer <= 0.0 and visible:
		_timer = REDRAW_SECONDS
		if _route != null and _route.endless:
			_route_line = _to_map_line(_route.line_ahead(ENDLESS_LINE_AHEAD))
		queue_redraw()


func _on_status(status: Dictionary) -> void:
	_stop = status["stop_position"]
	_has_stop = true


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_RESIZED:
		_fit()


func _draw() -> void:
	var middle := size / 2.0
	draw_circle(middle, size.x / 2.0, Color(0.08, 0.09, 0.12, 0.55))
	draw_arc(middle, size.x / 2.0 - 1.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.32), 2.0)
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
