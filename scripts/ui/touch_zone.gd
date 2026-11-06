class_name TouchZone
extends Control
## Base for on-screen controls. Standard Godot buttons react to one pointer at a
## time, but a driver holds a pedal and the wheel together, so each zone tracks
## its own finger by touch index.

## Extra grab area around the control, so near misses with a thumb still count.
@export var touch_margin: float = 10.0

var _finger: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_touched() -> bool:
	return _finger != -1


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1 and is_visible_in_tree() and _accepts(touch.position):
			_finger = touch.index
			_touch_down(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _finger:
			release_touch()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _finger:
			_touch_move(drag.position)


func _notification(what: int) -> void:
	# A call or a swipe to another app must never leave a pedal stuck down.
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_VISIBILITY_CHANGED:
			if _finger != -1 and (what != NOTIFICATION_VISIBILITY_CHANGED or not is_visible_in_tree()):
				release_touch()


func release_touch() -> void:
	if _finger != -1:
		_finger = -1
		_touch_up()


func _accepts(point: Vector2) -> bool:
	return get_global_rect().grow(touch_margin).has_point(point)


func _touch_down(_point: Vector2) -> void:
	pass


func _touch_move(_point: Vector2) -> void:
	pass


func _touch_up() -> void:
	pass
