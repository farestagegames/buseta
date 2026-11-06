class_name ShiftEndPanel
extends PanelContainer
## Basic end of shift summary. Phase 3 replaces this with the scored report.

var _body: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_child(box)
	add_child(margin)
	var title := Label.new()
	title.text = "Shift complete"
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 26)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body)
	var again := Button.new()
	again.text = "Drive again"
	again.custom_minimum_size = Vector2(200.0, 84.0)
	again.add_theme_font_size_override("font_size", 28)
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	box.add_child(again)


func show_summary(summary: Dictionary) -> void:
	_body.text = "%s\n\nPassengers carried: %d\nStops served: %d\nStops missed: %d\nLeft waiting: %d\nStopping accuracy: %d%%" % [
		summary["route"], summary["carried"], summary["served"], summary["missed"],
		summary["left_behind"], roundi(float(summary["accuracy"]) * 100.0)]
	visible = true
