class_name RoutePanel
extends Control
## Next stop, distance, turn hint and what the driver should do now.

var _line_one: String = ""
var _line_two: String = ""
var _prompt: String = ""
var _style := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style.bg_color = Color(0.08, 0.09, 0.12, 0.62)
	_style.set_corner_radius_all(14)


func _ready() -> void:
	GameEvents.route_status_updated.connect(_on_status)


func _on_status(status: Dictionary) -> void:
	var one := "Next: %s  (%d m)" % [status["next_stop"], roundi(float(status["distance"]) / 10.0) * 10]
	var two := "Stop %d of %d   On board: %d" % [status["stop_number"], status["stop_count"], status["onboard"]]
	var prompt: String = status["prompt"] if status["prompt"] != "" else status["turn"]
	if one != _line_one or two != _line_two or prompt != _prompt:
		_line_one = one
		_line_two = two
		_prompt = prompt
		visible = true
		queue_redraw()


func prompt_text() -> String:
	return _prompt


func _draw() -> void:
	if _line_one == "":
		return
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, 24.0), _line_one, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color.WHITE)
	draw_string(font, Vector2(0.0, 46.0), _line_two, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color(1, 1, 1, 0.75))
	draw_string(font, Vector2(0.0, 74.0), _prompt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.98, 0.72, 0.15))
