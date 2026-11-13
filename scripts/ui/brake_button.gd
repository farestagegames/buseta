class_name BrakeButton
extends TouchZone
## Hold to brake. It starts gently and grows firmer the longer it is held, so a
## quick press eases the bus down and a long hold stops it hard. Where the thumb
## lands does not matter, which players found easier than a slider.

signal value_changed(value: float)

## Brake on first touch: a soft slow-down, well under the harsh-braking limit.
const START := 0.45
## How fast the brake firms up while held, per second. Full brake after about 1.5 s.
const RAMP_RATE := 0.37

var label: String = "BRAKE"
var colour: Color = Color(0.9, 0.22, 0.2)
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


func _process(dt: float) -> void:
	if is_touched() and value < 1.0:
		hold(dt)


## Firms the brake up as if held for dt more seconds.
func hold(dt: float) -> void:
	_set_value(minf(value + RAMP_RATE * dt, 1.0))


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	_style.border_color = Color(colour, 0.9) if is_touched() else Color(1.0, 1.0, 1.0, 0.35)
	draw_style_box(_style, rect)
	if value > 0.0:
		var fill_height := size.y * value
		_fill_style.bg_color = Color(colour, 0.85)
		draw_style_box(_fill_style, Rect2(0.0, size.y - fill_height, size.x, fill_height))
	var font := ThemeDB.fallback_font
	var text := tr(label)
	var hold := tr("HOLD")
	draw_string(font, Vector2(0.0, size.y / 2.0 + 10.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x,
		UiStyle.fit_font_size(font, text, 28, size.x - 20.0), Color.WHITE)
	draw_string(font, Vector2(0.0, size.y / 2.0 + 40.0), hold, HORIZONTAL_ALIGNMENT_CENTER, size.x,
		UiStyle.fit_font_size(font, hold, 16, size.x - 20.0), Color(1.0, 1.0, 1.0, 0.6))


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _touch_down(_point: Vector2) -> void:
	_set_value(START)


func _touch_up() -> void:
	_set_value(0.0)


func _set_value(new_value: float) -> void:
	value = new_value
	queue_redraw()
	value_changed.emit(value)
