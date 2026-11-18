class_name RouteMapView
extends Control
## A big north-up map of one route for the menu's Routes side card: the town's
## roads, the route in yellow, its stops in green and the start in red, like the
## drive's minimap when tapped open. Lines are kept in world metres and fitted to
## the control when drawn, so a resize needs no reload.

const PADDING := 14.0
const BACK := Color("#2B3040")
const OUTLINE := Color("#22242D")
const ROAD := Color(1.0, 1.0, 1.0, 0.35)
const ROUTE := Color(1.0, 0.78, 0.2)
const STOP := Color(0.25, 0.8, 0.4)
const START := Color(0.9, 0.25, 0.2)

var road_lines: Array[PackedVector2Array] = []
var route_line := PackedVector2Array()
var stop_points := PackedVector2Array()
var _low := Vector2.ZERO
var _high := Vector2.ONE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


## Loads a catalog route; anything missing leaves an empty map.
func show_route(route_item: Dictionary) -> void:
	road_lines.clear()
	route_line = PackedVector2Array()
	stop_points = PackedVector2Array()
	var file := str(route_item.get("file", ""))
	if file != "":
		var route_data := MapLoader.read_json(file)
		var map_data := MapLoader.read_map_of(route_data) if not route_data.is_empty() else {}
		if not map_data.is_empty():
			var network := RoadNetwork.from_data(map_data, Country.pack.traffic_side, Country.pack.default_speed_limit())
			var route := RouteRunner.build(route_data, network, 0, map_data)
			for road: Dictionary in network.roads.values():
				road_lines.append(road["points"])
			route_line = route.line_ahead(700.0) if route.endless else route.polyline
			for stop in route.stops:
				stop_points.append(stop.position)
	_low = Vector2(INF, INF)
	_high = Vector2(-INF, -INF)
	for line in road_lines:
		for point in line:
			_low = _low.min(point)
			_high = _high.max(point)
	queue_redraw()


## A world point in control pixels, the whole town fitted and centred.
func to_view(point: Vector2) -> Vector2:
	var span := (_high - _low).max(Vector2.ONE)
	var room := (size - Vector2.ONE * PADDING * 2.0).max(Vector2.ONE)
	var scale := minf(room.x / span.x, room.y / span.y)
	var margin := (size - span * scale) / 2.0
	return (point - _low) * scale + margin


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _view_line(line: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in line:
		out.append(to_view(point))
	return out


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = BACK
	box.set_corner_radius_all(18)
	box.set_border_width_all(3)
	box.border_color = OUTLINE
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	if road_lines.is_empty():
		return
	for line in road_lines:
		if line.size() > 1:
			draw_polyline(_view_line(line), ROAD, 4.0)
	if route_line.size() > 1:
		draw_polyline(_view_line(route_line), ROUTE, 5.0)
	for point in stop_points:
		var at := to_view(point)
		draw_circle(at, 8.0, Color.WHITE)
		draw_circle(at, 6.0, STOP)
	if not route_line.is_empty():
		draw_circle(to_view(route_line[0]), 7.0, START)
