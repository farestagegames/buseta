class_name GoalsHud
extends Control
## Small checklist of the route's three goals during a shift.

var _goals: Array = []
var _status: Array = [] # 0 pending, 1 met, 2 failed
var _style := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style.bg_color = Color(0.08, 0.09, 0.12, 0.55)
	_style.set_corner_radius_all(10)


func set_goals(goals: Array) -> void:
	_goals = goals.duplicate(true)
	_status.resize(_goals.size())
	for i in _status.size():
		_status[i] = 0
	visible = not _goals.is_empty()
	queue_redraw()


func update_status(report_like: Dictionary) -> void:
	if _goals.is_empty():
		return
	var changed := false
	for i in _goals.size():
		var goal: Dictionary = _goals[i]
		var state := _state_for(goal, report_like)
		if i >= _status.size() or _status[i] != state:
			if i < _status.size():
				_status[i] = state
			changed = true
	if changed:
		queue_redraw()


func _state_for(goal: Dictionary, report: Dictionary) -> int:
	if RouteGoals.is_met(goal, report):
		return 1
	return 2 if _is_failed(goal, report) else 0


func _is_failed(goal: Dictionary, report: Dictionary) -> bool:
	var counts: Dictionary = report.get("counts", {})
	match str(goal.get("type", "")):
		"finish_under":
			return float(report.get("time", 0.0)) > float(goal.get("value", 0.0))
		"no_fines":
			return int(counts.get("fines", 0)) > 0 or int(report.get("fined_coins", 0)) > 0
		"no_collisions":
			return int(counts.get("collisions", 0)) > 0
		"no_knocked":
			return int(counts.get("knocked", 0)) > 0
		"vendors":
			# Can't know for sure until end, but can be met early.
			return false
		"perfect_stops":
			var served := int(report.get("served", 0))
			var perfect := int(report.get("perfect_stops", int(counts.get("perfect_stops", 0))))
			return served > perfect
		"satisfaction":
			return false
		"passengers":
			return false
		"no_missed":
			return int(counts.get("missed_stops", 0)) > 0
		_:
			return false


func _draw() -> void:
	if _goals.is_empty():
		return
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	var y := 18.0
	for i in _goals.size():
		var goal: Dictionary = _goals[i]
		var state: int = int(_status[i]) if i < _status.size() else 0
		var mark := "○"
		var colour := Color(1, 1, 1, 0.75)
		if state == 1:
			mark = "✓"
			colour = Color(0.5, 0.95, 0.6)
		elif state == 2:
			mark = "✗"
			colour = Color(1.0, 0.45, 0.35)
		var text := "%s %s" % [mark, RouteGoals.text_for(goal)]
		draw_string(font, Vector2(10.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0,
			UiStyle.fit_font_size(font, text, 16, size.x - 20.0, 11), colour)
		y += 20.0
