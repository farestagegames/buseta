class_name RoutePanel
extends Control
## Next stop, distance, turn hint and what the driver should do now.

var _line_one: String = ""
var _line_two: String = ""
var _prompt: String = ""
var _time_status: String = ""
var _late: bool = false
var _signal: int = -1
var _style := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style.bg_color = Color(0.08, 0.09, 0.12, 0.62)
	_style.set_corner_radius_all(14)


func _ready() -> void:
	GameEvents.route_status_updated.connect(_on_status)
	GameEvents.signal_ahead.connect(_on_signal)


func _on_status(status: Dictionary) -> void:
	var one := "Next: %s  (%d m)" % [status["next_stop"], roundi(float(status["distance"]) / 10.0) * 10]
	var two := "Stop %d of %d   On board: %d" % [status["stop_number"], status["stop_count"], status["onboard"]]
	var prompt: String = status["prompt"] if status["prompt"] != "" else status["turn"]
	var late: float = status["seconds_late"]
	var time_status := ShiftSchedule.status_text(late)
	if one != _line_one or two != _line_two or prompt != _prompt or time_status != _time_status:
		_time_status = time_status
		_late = not ShiftSchedule.is_on_time(late)
		_line_one = one
		_line_two = two
		_prompt = prompt
		queue_redraw()


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
	draw_string(font, Vector2(0.0, 24.0), _line_one, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color.WHITE)
	var time_colour := Color(1.0, 0.45, 0.35) if _late else Color(0.5, 0.95, 0.6)
	draw_string(font, Vector2(14.0, 46.0), _line_two, HORIZONTAL_ALIGNMENT_LEFT, size.x, 17, Color(1, 1, 1, 0.75))
	draw_string(font, Vector2(0.0, 46.0), _time_status, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 14.0, 18, time_colour)
	if _signal >= 0:
		_draw_signal(Vector2(size.x + 8.0, 4.0))
	draw_string(font, Vector2(0.0, 74.0), _prompt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.98, 0.72, 0.15))


## A small signal head beside the panel, because the real one can be hidden by
## the bus roof when stopped at the line.
func _draw_signal(corner: Vector2) -> void:
	draw_rect(Rect2(corner, Vector2(34.0, 76.0)), Color(0.05, 0.05, 0.06, 0.9))
	var colours := [Color(0.95, 0.15, 0.1), Color(0.98, 0.7, 0.1), Color(0.2, 0.9, 0.35)]
	var lit := {TrafficLightPlan.Light.RED: 0, TrafficLightPlan.Light.AMBER: 1, TrafficLightPlan.Light.GREEN: 2}
	for i in 3:
		var colour: Color = colours[i] if lit[_signal] == i else Color(colours[i], 0.14)
		draw_circle(corner + Vector2(17.0, 15.0 + 23.0 * i), 9.0, colour)
