class_name GearSwitch
extends TouchZone
## Drive and reverse as two halves of one switch, D on the left and R on the
## right, with the gear in use lit. Tapping a half asks for that gear, so the
## player can see both choices and which one is on, rather than guessing what
## a "D / R" toggle does.

## Asks the bus to swap gear. Only sent when the tapped half is not already on.
signal gear_toggled

const DRIVE_COLOUR := Color(0.2, 0.75, 0.35, 0.95)
const REVERSE_COLOUR := Color(0.98, 0.72, 0.15, 0.95)
const OFF_COLOUR := Color(0.13, 0.15, 0.19, UiStyle.HUD_PANEL_ALPHA)
const TEXT := Color(0.97, 0.98, 1.0)
const DIM_TEXT := Color(1.0, 1.0, 1.0, 0.45)
const INK := Color(0.09, 0.1, 0.13)

## Just the letters, for the small switch beside the speed readout.
var compact: bool = false

## Set from the bus telemetry.
var is_reverse: bool = false:
	set(value):
		is_reverse = value
		queue_redraw()

var _halves: Array[StyleBoxFlat] = []
var _frame := StyleBoxFlat.new()


func _init() -> void:
	super()
	_frame.set_corner_radius_all(20)
	_frame.set_border_width_all(2)
	_frame.border_color = Color(1.0, 1.0, 1.0, 0.32)
	_frame.bg_color = OFF_COLOUR
	for side: int in 2:
		var half := StyleBoxFlat.new()
		half.corner_radius_top_left = 18 if side == 0 else 0
		half.corner_radius_bottom_left = 18 if side == 0 else 0
		half.corner_radius_top_right = 18 if side == 1 else 0
		half.corner_radius_bottom_right = 18 if side == 1 else 0
		_halves.append(half)


## True when the point is on the reverse (right-hand) half.
func is_reverse_half(point: Vector2) -> bool:
	return point.x >= get_global_rect().get_center().x


func _draw() -> void:
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var width := size.x / 2.0
	var font := ThemeDB.fallback_font
	var entries := [["D", "DRIVE", DRIVE_COLOUR, not is_reverse], ["R", "REVERSE", REVERSE_COLOUR, is_reverse]]
	for side: int in 2:
		var entry: Array = entries[side]
		var on: bool = entry[3]
		var area := Rect2(width * side, 0.0, width, size.y).grow(-3.0)
		if on:
			_halves[side].bg_color = entry[2]
			draw_style_box(_halves[side], area)
		var ink := INK if on else DIM_TEXT
		if compact:
			var baseline := (size.y - font.get_height(34)) / 2.0 + font.get_ascent(34)
			draw_string(font, Vector2(area.position.x, baseline), entry[0], HORIZONTAL_ALIGNMENT_CENTER, area.size.x, 34, ink)
			continue
		draw_string(font, Vector2(area.position.x, size.y * 0.55), entry[0], HORIZONTAL_ALIGNMENT_CENTER, area.size.x, 40, ink)
		draw_string(font, Vector2(area.position.x, size.y * 0.85), tr(entry[1]), HORIZONTAL_ALIGNMENT_CENTER, area.size.x, 15, ink)
	draw_line(Vector2(width, 10.0), Vector2(width, size.y - 10.0), Color(1.0, 1.0, 1.0, 0.25), 2.0)


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _touch_down(point: Vector2) -> void:
	if is_reverse_half(point) != is_reverse:
		gear_toggled.emit()
