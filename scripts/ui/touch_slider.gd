class_name TouchSlider
extends HSlider
## A slider for a scrolling list. It follows the finger only once the finger has
## gone sideways, so an up or down drag that starts on it scrolls the list and
## leaves the value alone. A tap still sets the value where it lands.
##
## Godot's own slider jumps on the first touch, so it is switched off with
## editable = false and this script moves the value instead.

var _from := Vector2.INF
var _sliding := false


func _init() -> void:
	editable = false
	mouse_filter = Control.MOUSE_FILTER_PASS


func is_sliding() -> bool:
	return _sliding


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		if mouse.pressed:
			_from = mouse.global_position
			_sliding = false
		elif _from != Vector2.INF:
			if _sliding or _from.distance_to(mouse.global_position) <= TouchScroll.DEADZONE:
				value = value_at(mouse.position.x)
			_from = Vector2.INF
			_sliding = false
		return
	var motion := event as InputEventMouseMotion
	if motion == null or _from == Vector2.INF:
		return
	var moved := motion.global_position - _from
	if not _sliding and absf(moved.x) > TouchScroll.DEADZONE and absf(moved.x) > absf(moved.y):
		_sliding = true
	if _sliding:
		value = value_at(motion.position.x)
		# Keeps the list still while the slider moves.
		accept_event()


## The value under a point on the slider, measured like Godot's own slider.
func value_at(x: float) -> float:
	var grab := get_theme_icon("grabber").get_width()
	var track := maxf(size.x - grab, 1.0)
	return min_value + clampf((x - grab / 2.0) / track, 0.0, 1.0) * (max_value - min_value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN and not _sliding:
		_from = Vector2.INF
