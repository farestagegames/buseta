class_name MenuBackdrop
extends Control
## Quiet animated scenery behind the main menu: dusk sky, hills, a small
## town, drifting clouds and a buseta crossing the road now and then.
## Everything is drawn in code and kept low contrast so the cards stay readable.

const SEED := 20240611
const REDRAW_INTERVAL := 1.0 / 30.0
const BUS_PERIOD := 25.0
const BUS_SPEED := 70.0
const CLOUD_COUNT := 4
const SKY_BANDS := 24
const HOUSES := 11

const SKY_TOP := UiStyle.INK
const SKY_LOW := Color(0.2, 0.17, 0.27)
const SUN_ALPHA := 0.16
const HILL_BACK := Color(0.1, 0.12, 0.17, 0.9)
const HILL_FRONT := Color(0.08, 0.1, 0.14, 0.95)
const ROAD := Color(0.06, 0.07, 0.1, 0.95)
const HOUSE := Color(0.07, 0.085, 0.12, 0.95)
const ROOF := Color(0.05, 0.065, 0.095, 0.95)
const WINDOW_LIT := Color(0.98, 0.72, 0.15, 0.4)
const CLOUD := Color(0.75, 0.8, 0.95, 0.07)
const BUS_BODY := Color(0.2, 0.24, 0.31, 0.85)
const BUS_GLASS := Color(0.55, 0.65, 0.8, 0.4)
const BUS_STRIPE := Color(0.98, 0.72, 0.15, 0.45)
const WHEEL := Color(0.03, 0.035, 0.05, 0.95)

## Speeds up or slows down the animation.
var time_scale := 1.0
## Hill silhouettes, rebuilt on resize: back layer then front layer.
var hill_back := PackedVector2Array()
var hill_front := PackedVector2Array()
## Left edge of the buseta, in this control's coordinates.
var bus_x := 0.0

var _time := 0.0
var _since_draw := 0.0
var _road_top := 0.0
var _houses: Array[Rect2] = []
var _lit: Array[Rect2] = []
var _roofs: Array[PackedVector2Array] = []
var _clouds: Array[Vector3] = [] # x fraction, y fraction, scale
var _sun := Vector2.ZERO
var _sun_radius := 0.0
var _bus_w := 0.0
var _bus_h := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_rebuild)


func _ready() -> void:
	_rebuild()


func _process(delta: float) -> void:
	advance(delta)


## Moves the scene on by this many seconds (scaled by time_scale).
func advance(seconds: float) -> void:
	var step := seconds * time_scale
	_time += step
	_since_draw += seconds
	_update_bus()
	if _since_draw >= REDRAW_INTERVAL:
		_since_draw = 0.0
		queue_redraw()


func _update_bus() -> void:
	var travel := size.x + _bus_w * 2.0
	var cycle := maxf(BUS_PERIOD, travel / BUS_SPEED)
	var t := fposmod(_time, cycle)
	bus_x = -_bus_w + t * BUS_SPEED
	if bus_x > size.x:
		bus_x = size.x + 1.0 # parked off screen until the next pass


func _rebuild() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_road_top = h * 0.93
	_bus_h = clampf(h * 0.045, 18.0, 46.0)
	_bus_w = _bus_h * 3.0
	_sun = Vector2(w * 0.78, h * 0.68)
	_sun_radius = minf(w, h) * 0.2
	hill_back = _hill(rng, w, h * 0.66, h * 0.1, h * 0.8)
	hill_front = _hill(rng, w, h * 0.78, h * 0.06, _road_top)
	_houses.clear()
	_lit.clear()
	_roofs.clear()
	var slot := w / float(HOUSES)
	for i in HOUSES:
		var hw := slot * rng.randf_range(0.5, 0.75)
		var hh := hw * rng.randf_range(0.5, 0.75)
		var x := slot * float(i) + rng.randf_range(0.0, slot - hw)
		var base := _surface_y(hill_front, x + hw * 0.5) + 2.0
		var body := Rect2(x, base - hh, hw, hh)
		_houses.append(body)
		var peak := hh * 0.45
		_roofs.append(PackedVector2Array([
			Vector2(x - 3.0, body.position.y),
			Vector2(x + hw * 0.5, body.position.y - peak),
			Vector2(x + hw + 3.0, body.position.y),
		]))
		if rng.randf() < 0.55:
			var ws := minf(hw, hh) * 0.22
			_lit.append(Rect2(x + hw * 0.5 - ws * 0.5, base - hh * 0.6, ws, ws * 1.2))
	_clouds.clear()
	for i in CLOUD_COUNT:
		_clouds.append(Vector3(
			(float(i) + rng.randf()) / float(CLOUD_COUNT),
			rng.randf_range(0.08, 0.38),
			rng.randf_range(0.8, 1.4)))
	queue_redraw()


## A jagged ridge across the width, closed along `floor_y`.
func _hill(rng: RandomNumberGenerator, w: float, mid: float, amp: float, floor_y: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 9
	for i in steps + 1:
		var x := w * float(i) / float(steps)
		var y := mid + rng.randf_range(-amp, amp)
		pts.append(Vector2(x, clampf(y, 0.0, floor_y)))
	pts.append(Vector2(w, floor_y))
	pts.append(Vector2(0.0, floor_y))
	return pts


func _surface_y(ridge: PackedVector2Array, x: float) -> float:
	var count := ridge.size() - 2
	for i in count - 1:
		var a := ridge[i]
		var b := ridge[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return ridge[count - 1].y


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0 or hill_back.is_empty():
		return
	for i in SKY_BANDS:
		var t := float(i) / float(SKY_BANDS - 1)
		var band := h / float(SKY_BANDS)
		draw_rect(Rect2(0.0, h - band * float(i + 1), w, band + 1.0), SKY_TOP.lerp(SKY_LOW, t * t))
	var pulse := 1.0 + sin(_time * 0.4) * 0.08
	for ring in 3:
		var a := SUN_ALPHA * (0.35 + 0.3 * float(ring)) * pulse
		draw_circle(_sun, _sun_radius * (1.6 - 0.3 * float(ring)), Color(UiStyle.ACCENT, a * 0.5))
	draw_circle(_sun, _sun_radius, Color(UiStyle.ACCENT, SUN_ALPHA * pulse))
	for c in _clouds:
		_draw_cloud(c, w)
	draw_colored_polygon(hill_back, HILL_BACK)
	draw_colored_polygon(hill_front, HILL_FRONT)
	for i in _houses.size():
		draw_rect(_houses[i], HOUSE)
		draw_colored_polygon(_roofs[i], ROOF)
	for window in _lit:
		var flicker := 0.85 + 0.15 * sin(_time * 1.3 + window.position.x)
		draw_rect(window, Color(WINDOW_LIT, WINDOW_LIT.a * flicker))
	draw_rect(Rect2(0.0, _road_top, w, h - _road_top), ROAD)
	_draw_bus()


func _draw_cloud(c: Vector3, w: float) -> void:
	var span := w + 400.0
	var x := fposmod(c.x * span + _time * (6.0 + c.z * 4.0), span) - 200.0
	var y := c.y * size.y
	var s := 38.0 * c.z
	draw_circle(Vector2(x, y), s, CLOUD)
	draw_circle(Vector2(x + s * 1.0, y - s * 0.3), s * 1.2, CLOUD)
	draw_circle(Vector2(x + s * 2.1, y), s * 0.9, CLOUD)
	draw_rect(Rect2(x, y, s * 2.1, s * 0.9), CLOUD)


func _draw_bus() -> void:
	if bus_x > size.x:
		return
	var y := _road_top + (size.y - _road_top) * 0.5 - _bus_h * 0.5
	var bounce := sin(_time * 14.0) * 0.6
	var body := Rect2(bus_x, y + bounce, _bus_w, _bus_h)
	draw_rect(body, BUS_BODY)
	var gh := _bus_h * 0.28
	draw_rect(Rect2(body.position.x + _bus_w * 0.06, body.position.y + _bus_h * 0.12, _bus_w * 0.88, gh), BUS_GLASS)
	draw_rect(Rect2(body.position.x, body.position.y + _bus_h * 0.55, _bus_w, _bus_h * 0.12), BUS_STRIPE)
	var r := _bus_h * 0.17
	var wy := body.position.y + _bus_h
	draw_circle(Vector2(bus_x + _bus_w * 0.2, wy), r, WHEEL)
	draw_circle(Vector2(bus_x + _bus_w * 0.8, wy), r, WHEEL)
