class_name PedalControl
extends TouchZone
## Analogue pedal. Press low for gentle input and high for full, sliding freely
## while held, which is how a player brakes smoothly on a touch screen.

signal value_changed(value: float)

const MIN_PRESS := 0.35

var label: String = ""
var colour: Color = Color(0.2, 0.75, 0.35)
var value: float = 0.0

var _style := StyleBoxFlat.new()
var _fill_style := StyleBoxFlat.new()


func _init() -> void:
	super()
	_style.set_corner_radius_all(22)
	_style.set_border_width_all(3)
	_style.border_color = Color(1.0, 1.0, 1.0, 0.35)
	_style.bg_color = Color(0.13, 0.15, 0.19, UiStyle.HUD_PANEL_ALPHA)
	_fill_style.set_corner_radius_all(20)


func press_value_at(point: Vector2) -> float:
	var rect := get_global_rect()
	var height_share := clampf((rect.end.y - point.y) / rect.size.y, 0.0, 1.0)
	return lerpf(MIN_PRESS, 1.0, height_share)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_style, rect)
	if value > 0.0:
		var fill_height := size.y * value
		_fill_style.bg_color = Color(colour, 0.85)
		draw_style_box(_fill_style, Rect2(0.0, size.y - fill_height, size.x, fill_height))
	var font := ThemeDB.fallback_font
	var text := tr(label)
	var font_size := UiStyle.fit_font_size(font, text, 26, size.x - 20.0)
	draw_string(font, Vector2(0.0, size.y / 2.0 + 10.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color.WHITE)


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _touch_down(point: Vector2) -> void:
	_set_value(press_value_at(point))


func _touch_move(point: Vector2) -> void:
	_set_value(press_value_at(point))


func _touch_up() -> void:
	_set_value(0.0)


func _set_value(new_value: float) -> void:
	value = new_value
	queue_redraw()
	value_changed.emit(value)
