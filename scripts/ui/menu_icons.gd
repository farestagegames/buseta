class_name MenuIcon
extends Control
## A chunky cartoon icon built from shapes, sized to fit the control.
##
## Every icon is drawn on a unit square, so it stays crisp from 32 to 64 px
## without a texture or a font.

const NAMES: Array[String] = ["home", "routes", "garage", "driver", "trophy",
	"gear", "camera", "horn", "sound", "sound_off", "fullscreen", "arrow_left",
	"arrow_right", "coin", "play", "star", "sun", "lock"]

## Which shape to show. Unknown names draw nothing.
@export var icon: String = "":
	set(value):
		if icon == value:
			return
		icon = value
		queue_redraw()

## Main ink of the icon.
@export var colour: Color = Color(0.13, 0.14, 0.18):
	set(value):
		colour = value
		queue_redraw()

## Stroke width in pixels around the main shapes; zero keeps them flat.
@export var outline: float = 0.0:
	set(value):
		outline = value
		queue_redraw()

var _side: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _ink: Color = Color.BLACK
var _stroke: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Whether [param name] is one of the shapes this control can draw.
static func has_icon(name: String) -> bool:
	return NAMES.has(name)


func _draw() -> void:
	_side = minf(size.x, size.y)
	if _side <= 0.0 or not has_icon(icon):
		return
	_origin = (size - Vector2(_side, _side)) * 0.5
	_ink = colour.darkened(0.55)
	_stroke = maxf(outline, 0.0)
	match icon:
		"home":
			_draw_home()
		"routes":
			_draw_routes()
		"garage":
			_draw_garage()
		"driver":
			_draw_driver()
		"trophy":
			_draw_trophy()
		"gear":
			_draw_gear()
		"camera":
			_draw_camera()
		"horn":
			_draw_horn()
		"sound":
			_draw_sound()
		"sound_off":
			_draw_sound_off()
		"fullscreen":
			_draw_fullscreen()
		"arrow_left":
			_draw_arrow_left()
		"arrow_right":
			_draw_arrow_right()
		"coin":
			_draw_coin()
		"play":
			_draw_play()
		"star":
			_draw_star()
		"sun":
			_draw_sun()
		"lock":
			_draw_lock()


## Unit point placed in the control.
func _at(x: float, y: float) -> Vector2:
	return _origin + Vector2(x, y) * _side


## Unit point at [param angle] and [param radius] from the middle.
func _polar(angle: float, radius: float) -> Vector2:
	return _at(0.5 + cos(angle) * radius, 0.5 + sin(angle) * radius)


## Box in unit space.
func _box(left: float, top: float, width: float, height: float, fill: Color, lined: bool = true) -> void:
	var rect := Rect2(_at(left, top), Vector2(width, height) * _side)
	draw_rect(rect, fill)
	if lined and _stroke > 0.0:
		draw_rect(rect, _ink, false, _stroke)


## Disc in unit space.
func _disc(cx: float, cy: float, radius: float, fill: Color, lined: bool = true) -> void:
	var centre := _at(cx, cy)
	draw_circle(centre, radius * _side, fill)
	if lined and _stroke > 0.0:
		draw_arc(centre, radius * _side, 0.0, TAU, 48, _ink, _stroke, true)


## Filled polygon from unit points.
func _poly(points: PackedVector2Array, fill: Color, lined: bool = true) -> void:
	draw_polygon(points, PackedColorArray([fill]))
	if lined and _stroke > 0.0:
		var loop := points.duplicate()
		loop.append(points[0])
		draw_polyline(loop, _ink, _stroke, true)


## Open path from unit points; [param width] is also in unit space.
func _path(points: PackedVector2Array, width: float, fill: Color) -> void:
	draw_polyline(points, fill, width * _side, true)


## Open arc in unit space.
func _ring_arc(cx: float, cy: float, radius: float, from: float, to: float, width: float, fill: Color) -> void:
	draw_arc(_at(cx, cy), radius * _side, from, to, 24, fill, width * _side, true)


## Even star from five outer points and five inner ones.
func _star_points(outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: int in 10:
		var angle := -PI * 0.5 + float(point) * PI / 5.0
		var radius := outer if point % 2 == 0 else inner
		points.append(_polar(angle, radius))
	return points


func _draw_home() -> void:
	var dark := colour.darkened(0.32)
	_box(0.18, 0.44, 0.64, 0.48, colour)
	_poly(PackedVector2Array([_at(0.50, 0.06), _at(0.96, 0.44), _at(0.04, 0.44)]), colour)
	_box(0.42, 0.62, 0.16, 0.30, dark, false)
	_box(0.26, 0.53, 0.12, 0.12, dark, false)
	_box(0.62, 0.53, 0.12, 0.12, dark, false)


func _draw_routes() -> void:
	var dark := colour.darkened(0.35)
	var stops := PackedVector2Array([
		_at(0.14, 0.84), _at(0.34, 0.84), _at(0.44, 0.64),
		_at(0.28, 0.46), _at(0.46, 0.30), _at(0.74, 0.30),
	])
	_path(stops, 0.11, colour)
	_disc(0.14, 0.84, 0.12, colour)
	_disc(0.14, 0.84, 0.05, dark, false)
	_disc(0.76, 0.28, 0.16, colour)
	_disc(0.76, 0.28, 0.07, dark, false)


func _draw_garage() -> void:
	var dark := colour.darkened(0.35)
	var light := colour.lightened(0.45)
	_box(0.08, 0.20, 0.84, 0.10, colour)
	_box(0.14, 0.28, 0.72, 0.66, colour)
	_box(0.24, 0.40, 0.52, 0.46, dark, false)
	for row: int in 4:
		_box(0.24, 0.46 + float(row) * 0.10, 0.52, 0.04, light, false)


func _draw_driver() -> void:
	var dark := colour.darkened(0.4)
	var skin := colour.lightened(0.35)
	_poly(PackedVector2Array([
		_at(0.08, 0.94), _at(0.16, 0.72), _at(0.34, 0.62),
		_at(0.66, 0.62), _at(0.84, 0.72), _at(0.94, 0.94),
	]), colour)
	_box(0.44, 0.54, 0.12, 0.10, skin, false)
	_disc(0.50, 0.40, 0.21, skin)
	_poly(PackedVector2Array([
		_at(0.30, 0.38), _at(0.32, 0.27), _at(0.50, 0.22),
		_at(0.68, 0.27), _at(0.70, 0.38),
	]), dark, false)
	_box(0.20, 0.36, 0.36, 0.07, dark, false)
	_disc(0.43, 0.47, 0.03, dark, false)
	_disc(0.57, 0.47, 0.03, dark, false)
	_ring_arc(0.50, 0.49, 0.08, 0.35, PI - 0.35, 0.035, dark)


func _draw_trophy() -> void:
	var dark := colour.darkened(0.35)
	var light := colour.lightened(0.45)
	_ring_arc(0.28, 0.28, 0.14, PI * 0.5, PI * 1.5, 0.07, colour)
	_ring_arc(0.72, 0.28, 0.14, -PI * 0.5, PI * 0.5, 0.07, colour)
	_poly(PackedVector2Array([
		_at(0.26, 0.08), _at(0.74, 0.08), _at(0.68, 0.44),
		_at(0.58, 0.55), _at(0.42, 0.55), _at(0.32, 0.44),
	]), colour)
	_box(0.24, 0.06, 0.52, 0.08, colour)
	_box(0.40, 0.17, 0.06, 0.22, light, false)
	_box(0.45, 0.55, 0.10, 0.12, dark, false)
	_box(0.32, 0.66, 0.36, 0.09, colour)
	_box(0.24, 0.75, 0.52, 0.09, colour)


func _draw_gear() -> void:
	var dark := colour.darkened(0.45)
	var points := PackedVector2Array()
	var step := TAU / 8.0
	for tooth: int in 8:
		var base := float(tooth) * step
		points.append(_polar(base + step * 0.06, 0.31))
		points.append(_polar(base + step * 0.16, 0.45))
		points.append(_polar(base + step * 0.34, 0.45))
		points.append(_polar(base + step * 0.44, 0.31))
	_poly(points, colour)
	_ring_arc(0.50, 0.50, 0.15, 0.0, TAU, 0.12, dark)


func _draw_camera() -> void:
	var dark := colour.darkened(0.35)
	var light := colour.lightened(0.5)
	_box(0.34, 0.16, 0.20, 0.12, colour)
	_box(0.08, 0.24, 0.84, 0.60, colour)
	_disc(0.50, 0.54, 0.24, dark, false)
	_disc(0.50, 0.54, 0.15, light, false)
	_disc(0.44, 0.47, 0.05, colour, false)
	_box(0.64, 0.30, 0.15, 0.07, dark, false)
	_disc(0.22, 0.33, 0.04, light, false)


func _draw_horn() -> void:
	var dark := colour.darkened(0.38)
	_poly(PackedVector2Array([
		_at(0.08, 0.22), _at(0.42, 0.36), _at(0.42, 0.64), _at(0.08, 0.78),
	]), colour)
	_box(0.42, 0.45, 0.30, 0.10, colour)
	_disc(0.76, 0.50, 0.13, colour)
	_box(0.26, 0.68, 0.08, 0.16, dark, false)
	_ring_arc(0.75, 0.50, 0.07, 0.0, TAU, 0.04, dark)


func _draw_sound() -> void:
	var cone := PackedVector2Array([
		_at(0.10, 0.38), _at(0.30, 0.38), _at(0.50, 0.18),
		_at(0.50, 0.82), _at(0.30, 0.62), _at(0.10, 0.62),
	])
	_poly(cone, colour)
	_ring_arc(0.52, 0.50, 0.18, -0.85, 0.85, 0.07, colour)
	_ring_arc(0.52, 0.50, 0.31, -0.85, 0.85, 0.07, colour)


func _draw_sound_off() -> void:
	var cone := PackedVector2Array([
		_at(0.10, 0.38), _at(0.30, 0.38), _at(0.50, 0.18),
		_at(0.50, 0.82), _at(0.30, 0.62), _at(0.10, 0.62),
	])
	_poly(cone, colour)
	_path(PackedVector2Array([_at(0.66, 0.34), _at(0.88, 0.66)]), 0.09, colour)
	_path(PackedVector2Array([_at(0.88, 0.34), _at(0.66, 0.66)]), 0.09, colour)


func _draw_fullscreen() -> void:
	var corners: Array[PackedVector2Array] = [
		PackedVector2Array([_at(0.10, 0.36), _at(0.10, 0.10), _at(0.36, 0.10)]),
		PackedVector2Array([_at(0.64, 0.10), _at(0.90, 0.10), _at(0.90, 0.36)]),
		PackedVector2Array([_at(0.90, 0.64), _at(0.90, 0.90), _at(0.64, 0.90)]),
		PackedVector2Array([_at(0.36, 0.90), _at(0.10, 0.90), _at(0.10, 0.64)]),
	]
	for corner: PackedVector2Array in corners:
		_path(corner, 0.10, colour)


func _draw_arrow_left() -> void:
	_poly(PackedVector2Array([
		_at(0.10, 0.50), _at(0.42, 0.18), _at(0.42, 0.36),
		_at(0.90, 0.36), _at(0.90, 0.64), _at(0.42, 0.64),
		_at(0.42, 0.82),
	]), colour)


func _draw_arrow_right() -> void:
	_poly(PackedVector2Array([
		_at(0.90, 0.50), _at(0.58, 0.18), _at(0.58, 0.36),
		_at(0.10, 0.36), _at(0.10, 0.64), _at(0.58, 0.64),
		_at(0.58, 0.82),
	]), colour)


func _draw_coin() -> void:
	var dark := colour.darkened(0.4)
	_disc(0.50, 0.50, 0.44, colour)
	_ring_arc(0.50, 0.50, 0.33, 0.0, TAU, 0.05, dark)
	_path(PackedVector2Array([
		_at(0.61, 0.35), _at(0.53, 0.29), _at(0.44, 0.31),
		_at(0.40, 0.38), _at(0.44, 0.46), _at(0.56, 0.52),
		_at(0.60, 0.60), _at(0.56, 0.67), _at(0.46, 0.70),
		_at(0.38, 0.64),
	]), 0.06, dark)
	_path(PackedVector2Array([_at(0.50, 0.24), _at(0.50, 0.76)]), 0.045, dark)


func _draw_play() -> void:
	_poly(PackedVector2Array([_at(0.24, 0.10), _at(0.88, 0.50), _at(0.24, 0.90)]), colour)


func _draw_star() -> void:
	_poly(_star_points(0.47, 0.21), colour)


func _draw_sun() -> void:
	var light := colour.lightened(0.2)
	for ray: int in 8:
		var angle := float(ray) * TAU / 8.0
		_path(PackedVector2Array([_polar(angle, 0.28), _polar(angle, 0.44)]), 0.08, colour)
	_disc(0.50, 0.50, 0.21, colour)
	_disc(0.50, 0.50, 0.10, light, false)


func _draw_lock() -> void:
	var dark := colour.darkened(0.4)
	_ring_arc(0.50, 0.42, 0.20, PI, TAU, 0.10, colour)
	_box(0.27, 0.42, 0.08, 0.10, colour)
	_box(0.65, 0.42, 0.08, 0.10, colour)
	_box(0.14, 0.46, 0.72, 0.44, colour)
	_disc(0.50, 0.63, 0.07, dark, false)
	_box(0.46, 0.65, 0.08, 0.14, dark, false)
