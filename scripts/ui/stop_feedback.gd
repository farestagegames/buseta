class_name StopFeedback
extends Control
## Short pop-up feedback for fares and perfect stops. Never blocks controls.

const FARE_RISE := 46.0
const FARE_TIME := 0.9
const STAMP_TIME := 1.1

var _items: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_fare(text: String, at: Vector2) -> void:
	_items.append({
		"text": text,
		"pos": at,
		"start": at,
		"age": 0.0,
		"duration": FARE_TIME,
		"font_size": 26,
		"color": Color(0.6, 1.0, 0.55),
		"rise": true,
	})
	queue_redraw()


func show_stamp(text: String, at: Vector2) -> void:
	_items.append({
		"text": text,
		"pos": at,
		"start": at,
		"age": 0.0,
		"duration": STAMP_TIME,
		"font_size": 34,
		"color": Color(1.0, 0.93, 0.45),
		"rise": false,
		"pop": 0.0,
	})
	queue_redraw()


func _process(dt: float) -> void:
	if _items.is_empty():
		return
	var alive: Array[Dictionary] = []
	for item: Dictionary in _items:
		item["age"] = float(item["age"]) + dt
		var t := float(item["age"]) / float(item["duration"])
		if t < 1.0:
			if item.get("rise", false):
				item["pos"] = Vector2(float(item["start"].x), float(item["start"].y) - FARE_RISE * t)
			else:
				item["pop"] = minf(float(item["age"]) / 0.12, 1.0)
			alive.append(item)
	_items = alive
	queue_redraw()
	if _items.is_empty():
		set_process(false)


func _draw() -> void:
	if _items.is_empty():
		return
	set_process(true)
	var font := ThemeDB.fallback_font
	for item: Dictionary in _items:
		var t := float(item["age"]) / float(item["duration"])
		var alpha := 1.0 - smoothstep(0.55, 1.0, t)
		var color: Color = item["color"]
		color.a *= alpha
		var text: String = item["text"]
		var fsize: int = item["font_size"]
		if item.has("pop"):
			fsize = roundi(float(fsize) * lerpf(0.85, 1.0, float(item["pop"])))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize).x
		var pos: Vector2 = item["pos"]
		draw_string(font, pos - Vector2(width / 2.0, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, color)
		# subtle outline for readability
		var outline := Color(0.05, 0.05, 0.06, 0.55 * alpha)
		draw_string(font, pos - Vector2(width / 2.0, 0.0) + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, outline)
