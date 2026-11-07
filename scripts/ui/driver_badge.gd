class_name DriverBadge
extends Control
## A small portrait of a driver for lists and cards, drawn on a 100 by 100 grid.

const DARK := Color(0.06, 0.06, 0.08)
const SHIRT := Color(0.9, 0.92, 0.95)

var look: DriverLook


func _init(driver_look: DriverLook, side: float = 84.0) -> void:
	look = driver_look
	custom_minimum_size = Vector2(side, side)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _block(left: float, top: float, width: float, height: float, colour: Color) -> void:
	var scale_by := minf(size.x, size.y) / 100.0
	draw_rect(Rect2(left * scale_by, top * scale_by, width * scale_by, height * scale_by), colour)


func _draw() -> void:
	_block(0.0, 0.0, 100.0, 100.0, UiStyle.RAISED)
	_block(14.0, 76.0, 72.0, 24.0, look.uniform)
	_block(42.0, 76.0, 16.0, 24.0, SHIRT)
	_block(47.0, 78.0, 6.0, 22.0, look.trim)
	_block(43.0, 66.0, 14.0, 12.0, look.skin)
	_draw_hair_behind()
	_block(34.0, 28.0, 32.0, 42.0, look.skin)
	_block(40.0, 44.0, 6.0, 5.0, DARK)
	_block(54.0, 44.0, 6.0, 5.0, DARK)
	_draw_hair_front()
	_draw_beard()
	if look.glasses:
		for left: float in [37.0, 51.0]:
			_block(left, 41.0, 12.0, 2.0, DARK)
			_block(left, 50.0, 12.0, 2.0, DARK)
			_block(left, 41.0, 2.0, 11.0, DARK)
			_block(left + 10.0, 41.0, 2.0, 11.0, DARK)
	if look.cap:
		_block(30.0, 17.0, 40.0, 13.0, look.uniform)
		_block(30.0, 28.0, 40.0, 3.0, look.trim)
		_block(28.0, 31.0, 44.0, 3.0, DARK)


func _draw_hair_behind() -> void:
	match look.hair_style:
		"bob":
			_block(29.0, 24.0, 42.0, 50.0, look.hair)
		"afro":
			_block(23.0, 12.0, 54.0, 46.0, look.hair)
		"plait":
			_block(66.0, 34.0, 8.0, 48.0, look.hair)
		"hijab":
			_block(28.0, 20.0, 44.0, 64.0, look.hair)
		"bun":
			_block(42.0, 10.0, 16.0, 14.0, look.hair)


func _draw_hair_front() -> void:
	match look.hair_style:
		"short", "bun", "plait", "bob":
			_block(32.0, 22.0, 36.0, 12.0, look.hair)
		"afro":
			_block(32.0, 22.0, 36.0, 9.0, look.hair)
		"hijab":
			_block(34.0, 24.0, 32.0, 9.0, look.hair)
			_block(34.0, 64.0, 32.0, 8.0, look.hair)


func _draw_beard() -> void:
	match look.beard:
		"moustache":
			_block(42.0, 56.0, 16.0, 4.0, look.hair)
		"full":
			_block(34.0, 54.0, 32.0, 16.0, look.hair)
