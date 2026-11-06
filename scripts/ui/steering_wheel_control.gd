class_name SteeringWheelControl
extends TouchZone
## On-screen wheel. Publishes its position each frame while it is in use.

var tracker := WheelTracker.new()

var _last_sent: float = 0.0


func _process(dt: float) -> void:
	tracker.update(dt)
	var value := tracker.normalised()
	if not is_equal_approx(value, _last_sent):
		_last_sent = value
		GameEvents.ui_wheel_changed.emit(value)
		queue_redraw()


func _accepts(point: Vector2) -> bool:
	return (point - get_global_rect().get_center()).length() <= size.x / 2.0 + touch_margin


func _draw() -> void:
	var centre := size / 2.0
	var radius := size.x / 2.0 - 12.0
	var rim := Color(0.93, 0.95, 1.0, 0.82) if is_touched() else Color(0.93, 0.95, 1.0, 0.6)
	draw_circle(centre, radius, Color(0.08, 0.09, 0.12, 0.4))
	draw_arc(centre, radius, 0.0, TAU, 56, rim, 22.0, true)
	var angle := deg_to_rad(tracker.rotation_degrees)
	var across := Vector2.RIGHT.rotated(angle)
	var down := Vector2.DOWN.rotated(angle)
	draw_line(centre - across * radius, centre + across * radius, rim, 16.0, true)
	draw_line(centre, centre + down * radius, rim, 16.0, true)
	draw_circle(centre, radius * 0.24, Color(0.14, 0.16, 0.2, 0.95))
	var top := centre - down * radius
	draw_circle(top, 11.0, Color(0.98, 0.72, 0.15))


func _touch_down(point: Vector2) -> void:
	tracker.press(point - get_global_rect().get_center())
	queue_redraw()


func _touch_move(point: Vector2) -> void:
	tracker.drag(point - get_global_rect().get_center())


func _touch_up() -> void:
	tracker.release()
	queue_redraw()
