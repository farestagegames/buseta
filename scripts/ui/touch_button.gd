class_name TouchButton
extends TouchZone
## Large rounded multi-touch button.

signal pressed_down
signal released

const TEXT := Color(0.97, 0.98, 1.0)

var text: String = "":
	set(value):
		text = value
		queue_redraw()
var base_colour: Color = Color(0.13, 0.15, 0.19, 0.72)
var lit_colour: Color = Color(0.2, 0.62, 0.95, 0.9)
var font_size: int = 26
## Keeps the button lit, for example while an indicator is on.
var lit: bool = false:
	set(value):
		lit = value
		queue_redraw()

var _style := StyleBoxFlat.new()


func _init() -> void:
	super()
	_style.set_corner_radius_all(20)
	_style.set_border_width_all(2)
	_style.border_color = Color(1.0, 1.0, 1.0, 0.32)


func _draw() -> void:
	_style.bg_color = lit_colour if lit or is_touched() else base_colour
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	var shown := tr(text)
	var fitted := UiStyle.fit_font_size(font, shown, font_size, size.x - 20.0)
	var line_height := font.get_height(fitted)
	var baseline := (size.y - line_height) / 2.0 + font.get_ascent(fitted)
	draw_string(font, Vector2(0.0, baseline), shown, HORIZONTAL_ALIGNMENT_CENTER, size.x, fitted, TEXT)


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _touch_down(_point: Vector2) -> void:
	queue_redraw()
	pressed_down.emit()


func _touch_up() -> void:
	queue_redraw()
	released.emit()
