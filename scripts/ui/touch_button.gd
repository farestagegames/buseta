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
var base_colour: Color = Color(0.13, 0.15, 0.19, UiStyle.HUD_PANEL_ALPHA)
var lit_colour: Color = Color(0.2, 0.62, 0.95, 0.9)
var font_size: int = 26
## A drawn symbol in place of the text: "pause" or "camera". The text
## stays as the button's name.
var icon: String = "":
	set(value):
		icon = value
		queue_redraw()
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
	if icon != "":
		_draw_icon(size / 2.0, minf(size.x, size.y) * 0.24)
		return
	var font := ThemeDB.fallback_font
	var shown := tr(text)
	var fitted := UiStyle.fit_font_size(font, shown, font_size, size.x - 20.0)
	var line_height := font.get_height(fitted)
	var baseline := (size.y - line_height) / 2.0 + font.get_ascent(fitted)
	draw_string(font, Vector2(0.0, baseline), shown, HORIZONTAL_ALIGNMENT_CENTER, size.x, fitted, TEXT)


## Plain shapes, so no font has to carry the symbol. r is about half the
## symbol's width.
func _draw_icon(centre: Vector2, r: float) -> void:
	match icon:
		"pause":
			for side: float in [-1.0, 1.0]:
				draw_rect(Rect2(centre + Vector2(side * r * 0.45 - r * 0.2, -r), Vector2(r * 0.4, r * 2.0)), TEXT)
		"camera":
			draw_rect(Rect2(centre + Vector2(-r, -r * 0.6), Vector2(r * 2.0, r * 1.4)), TEXT)
			draw_rect(Rect2(centre + Vector2(-r * 0.4, -r * 0.85), Vector2(r * 0.8, r * 0.3)), TEXT)
			draw_arc(centre + Vector2(0.0, r * 0.1), r * 0.36, 0.0, TAU, 20, UiStyle.INK, maxf(2.0, r * 0.16))


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
