class_name HudGauge
extends Control
## Speed, gear and status readout at the top of the screen.

const METRES_PER_SECOND_TO_KMH := 3.6

var _speed_kmh: int = 0
var _gear_text: String = "D1"
var _view_name: String = ""
var _doors_open: bool = false
var _steer_share: float = 0.0
var _speed_limit: float = 0.0
var _style := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style.bg_color = Color(0.08, 0.09, 0.12, 0.68)
	_style.set_corner_radius_all(16)


func _ready() -> void:
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.camera_view_changed.connect(_on_view_changed)
	GameEvents.route_status_updated.connect(_on_status)


func status_text() -> String:
	return "DOORS OPEN" if _doors_open else _view_name


func _on_status(status: Dictionary) -> void:
	var limit: float = status["speed_limit"]
	if limit != _speed_limit:
		_speed_limit = limit
		queue_redraw()


func _on_view_changed(view: String) -> void:
	_view_name = view
	queue_redraw()


func _on_telemetry(data: BusTelemetry) -> void:
	var kmh := roundi(absf(data.speed) * METRES_PER_SECOND_TO_KMH)
	var gear := "R" if data.is_reverse else "D%d" % data.gear
	var doors_open := not data.doors_closed
	var steer := clampf(data.steer_angle / 0.66, -1.0, 1.0)
	if kmh != _speed_kmh or gear != _gear_text or doors_open != _doors_open or not is_equal_approx(steer, _steer_share):
		_speed_kmh = kmh
		_gear_text = gear
		_doors_open = doors_open
		_steer_share = steer
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _draw() -> void:
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, 62.0), str(_speed_kmh), HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.4, 58, Color.WHITE)
	draw_string(font, Vector2(0.0, 88.0), tr("km/h"), HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.4, 20, Color(1, 1, 1, 0.7))
	draw_string(font, Vector2(size.x * 0.6, 50.0), _gear_text, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.4, 40, Color(0.98, 0.72, 0.15))
	draw_string(font, Vector2(size.x * 0.6, 84.0), tr(status_text()), HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.4, 18, Color(1, 1, 1, 0.8))
	if _speed_limit > 0.0:
		var sign_centre := Vector2(size.x * 0.5 - 8.0, 48.0)
		var over := float(_speed_kmh) > _speed_limit + DrivingMonitor.SPEED_GRACE_KMH
		draw_circle(sign_centre, 28.0, Color(1.0, 0.25, 0.2) if over else Color(0.9, 0.12, 0.1))
		draw_circle(sign_centre, 21.0, Color.WHITE)
		draw_string(font, sign_centre + Vector2(-21.0, 8.0), str(roundi(_speed_limit)), HORIZONTAL_ALIGNMENT_CENTER, 42.0, 22, Color.BLACK)
	var bar_y := size.y - 8.0
	var mid := size.x / 2.0
	draw_line(Vector2(mid - 120.0, bar_y), Vector2(mid + 120.0, bar_y), Color(1, 1, 1, 0.2), 5.0)
	draw_line(Vector2(mid, bar_y), Vector2(mid + _steer_share * 120.0, bar_y), Color(0.98, 0.72, 0.15), 5.0)
