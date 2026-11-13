class_name RoutePanel
extends Control
## One line for the next stop, how far along the route the bus is and the
## timetable ("Parque Norte · 2/8 · A tiempo"), and under it a short toast for
## what the driver should do now or what is happening at the stop.

## A toast fades this long after its text last changed.
const TOAST_SECONDS := 2.6
const TOAST_FADE := 0.4
const TOAST_TOP := 46.0
const TOAST_HEIGHT := 40.0

var _line_one: String = ""
var _prompt: String = ""
var _time_status: String = ""
var _late: bool = false
var _signal: int = -1
var _toast_left: float = 0.0
var _style := StyleBoxFlat.new()
var _toast_style := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style.bg_color = Color(0.08, 0.09, 0.12, UiStyle.HUD_PANEL_ALPHA)
	_style.set_corner_radius_all(14)
	_toast_style.set_corner_radius_all(14)


func _ready() -> void:
	GameEvents.route_status_updated.connect(_on_status)
	GameEvents.signal_ahead.connect(_on_signal)


func _on_status(status: Dictionary) -> void:
	var one := tr("%s · %d/%d") % [status["next_stop"], status["stop_number"], status["stop_count"]]
	var prompt: String = status["prompt"] if status["prompt"] != "" else tr(status["turn"])
	var late: float = status["seconds_late"]
	var time_status := ShiftSchedule.status_text(late)
	if prompt != _prompt:
		_prompt = prompt
		_toast_left = TOAST_SECONDS if prompt != "" else 0.0
		queue_redraw()
	if one != _line_one or time_status != _time_status:
		_time_status = time_status
		_late = not ShiftSchedule.is_on_time(late)
		_line_one = one
		queue_redraw()


func _process(dt: float) -> void:
	if _toast_left > 0.0:
		_toast_left = maxf(_toast_left - dt, 0.0)
		queue_redraw()


## True while the prompt is on screen as a toast.
func toast_showing() -> bool:
	return _toast_left > 0.0 and _prompt != ""


func line_text() -> String:
	return "%s · %s" % [_line_one, _time_status] if _line_one != "" else ""


func _on_signal(state: int, _distance: float) -> void:
	if state != _signal:
		_signal = state
		queue_redraw()


func prompt_text() -> String:
	return _prompt


func _draw() -> void:
	if _line_one == "":
		return
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	var time_colour := Color(1.0, 0.45, 0.35) if _late else Color(0.5, 0.95, 0.6)
	var head := _line_one + " · "
	var whole := head + _time_status
	var font_size := UiStyle.fit_font_size(font, whole, 22, size.x - 28.0)
	var head_width := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left := (size.x - font.get_string_size(whole, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) / 2.0
	var baseline := (size.y - font.get_height(font_size)) / 2.0 + font.get_ascent(font_size)
	draw_string(font, Vector2(left, baseline), head, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_string(font, Vector2(left + head_width, baseline), _time_status, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, time_colour)
	if _signal >= 0:
		_draw_signal(Vector2(size.x + 8.0, 0.0))
	if toast_showing():
		_draw_toast(font)


func _draw_toast(font: Font) -> void:
	var alpha := clampf(_toast_left / TOAST_FADE, 0.0, 1.0)
	var font_size := UiStyle.fit_font_size(font, _prompt, 24, size.x - 28.0)
	var width := minf(font.get_string_size(_prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 32.0, size.x)
	var area := Rect2((size.x - width) / 2.0, TOAST_TOP, width, TOAST_HEIGHT)
	_toast_style.bg_color = Color(0.08, 0.09, 0.12, 0.7 * alpha)
	draw_style_box(_toast_style, area)
	var baseline := TOAST_TOP + (TOAST_HEIGHT - font.get_height(font_size)) / 2.0 + font.get_ascent(font_size)
	draw_string(font, Vector2(0.0, baseline), _prompt, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(0.98, 0.72, 0.15, alpha))


## A small signal head beside the panel, because the real one can be hidden by
## the bus roof when stopped at the line.
func _draw_signal(corner: Vector2) -> void:
	draw_rect(Rect2(corner, Vector2(34.0, 76.0)), Color(0.05, 0.05, 0.06, 0.9))
	var colours := [Color(0.95, 0.15, 0.1), Color(0.98, 0.7, 0.1), Color(0.2, 0.9, 0.35)]
	var lit := {TrafficLightPlan.Light.RED: 0, TrafficLightPlan.Light.AMBER: 1, TrafficLightPlan.Light.GREEN: 2}
	for i in 3:
		var colour: Color = colours[i] if lit[_signal] == i else Color(colours[i], 0.14)
		draw_circle(corner + Vector2(17.0, 15.0 + 23.0 * i), 9.0, colour)
