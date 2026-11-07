class_name DriverBadge
extends Control
## A small portrait of a driver for lists and cards, drawn on a 100 by 100 grid.

const DARK := Color(0.06, 0.06, 0.08)

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
	_draw_clothes()
	_block(43.0, 66.0, 14.0, 12.0, look.skin)
	_block(45.0, 76.0, 10.0, 6.0, look.skin)
	# A headwrap covers the hair completely.
	var hair_shows := look.hat != "headwrap"
	if hair_shows:
		_draw_hair_behind()
	_block(34.0, 28.0, 32.0, 42.0, look.skin)
	_block(40.0, 44.0, 6.0, 5.0, DARK)
	_block(54.0, 44.0, 6.0, 5.0, DARK)
	if look.earrings:
		_block(31.0, 52.0, 3.0, 6.0, HeadParts.GOLD)
		_block(66.0, 52.0, 3.0, 6.0, HeadParts.GOLD)
	if hair_shows:
		_draw_hair_front()
		if look.greying:
			_draw_temples()
	_draw_beard()
	if look.glasses:
		for left: float in [37.0, 51.0]:
			_block(left, 41.0, 12.0, 2.0, DARK)
			_block(left, 50.0, 12.0, 2.0, DARK)
			_block(left, 41.0, 2.0, 11.0, DARK)
			_block(left + 10.0, 41.0, 2.0, 11.0, DARK)
	_draw_hat()
	if look.towel:
		_block(66.0, 74.0, 13.0, 4.0, DriverFigure.TOWEL)
		_block(67.0, 77.0, 11.0, 17.0, DriverFigure.TOWEL)
		_block(67.0, 91.0, 11.0, 1.5, DriverFigure.TOWEL.darkened(0.2))


func _draw_clothes() -> void:
	_block(14.0, 76.0, 72.0, 24.0, look.uniform)
	if look.outfit != "guayabera":
		_block(35.0, 75.0, 9.0, 5.0, look.trim)
		_block(56.0, 75.0, 9.0, 5.0, look.trim)
		_block(48.0, 82.0, 4.0, 11.0, look.uniform.darkened(0.12))
		_block(49.0, 84.0, 2.0, 2.0, look.trim)
		_block(49.0, 89.0, 2.0, 2.0, look.trim)
		return
	_block(37.0, 76.0, 7.0, 4.0, look.uniform.lightened(0.3))
	_block(56.0, 76.0, 7.0, 4.0, look.uniform.lightened(0.3))
	_block(49.0, 83.0, 2.0, 17.0, look.uniform.darkened(0.08))
	for left: float in [23.0, 40.0, 58.0, 75.0]:
		_block(left, 80.0, 2.0, 20.0, look.trim)
	_block(27.0, 88.0, 12.0, 7.0, look.trim)
	_block(61.0, 88.0, 12.0, 7.0, look.trim)


func _draw_hair_behind() -> void:
	var hair := look.hair
	match look.hair_style:
		"bob":
			_block(29.0, 24.0, 42.0, 44.0, hair)
		"afro":
			_block(29.0, 16.0, 42.0, 24.0, hair)
			_block(33.0, 11.0, 34.0, 6.0, hair)
		"plait":
			_block(66.0, 34.0, 8.0, 48.0, hair)
		"plaits":
			for left: float in [27.0, 66.0]:
				_block(left, 36.0, 7.0, 34.0, hair)
				_block(left - 1.0, 68.0, 9.0, 4.0, look.accent)
		"ponytail":
			_block(66.0, 30.0, 6.0, 26.0, hair)
			_block(65.0, 30.0, 8.0, 3.0, look.accent)
		"hijab":
			_block(28.0, 20.0, 44.0, 64.0, hair)
		"bun":
			_block(42.0, 10.0, 16.0, 14.0, hair)
		"curly":
			_block(24.0, 16.0, 52.0, 54.0, hair)
			for bump: Rect2 in [Rect2(19, 26, 7, 12), Rect2(74, 26, 7, 12), Rect2(21, 46, 6, 14), Rect2(73, 46, 6, 14),
					Rect2(29, 11, 12, 7), Rect2(44, 9, 12, 7), Rect2(59, 11, 12, 7)]:
				_block(bump.position.x, bump.position.y, bump.size.x, bump.size.y, hair)
		"long":
			# Down the back and over the shoulders, but never under the chin.
			_block(28.0, 24.0, 44.0, 46.0, hair)
			_block(28.0, 66.0, 7.0, 18.0, hair)
			_block(65.0, 66.0, 7.0, 18.0, hair)
		"braids":
			for left: float in [26.0, 30.0, 66.0, 70.0]:
				_block(left, 30.0, 4.0, 46.0, hair)
				_block(left - 0.5, 75.0, 5.0, 5.0, look.accent)


func _draw_hair_front() -> void:
	var hair := look.hair
	match look.hair_style:
		"short", "bun", "plait", "plaits", "bob", "ponytail":
			_block(32.0, 22.0, 36.0, 12.0, hair)
		"afro":
			_block(33.0, 22.0, 34.0, 7.0, hair)
		"fade":
			_block(33.0, 23.0, 34.0, 7.0, hair)
			var faded := hair.lerp(look.skin, 0.45)
			_block(32.0, 28.0, 3.0, 12.0, faded)
			_block(65.0, 28.0, 3.0, 12.0, faded)
		"hijab":
			_block(34.0, 24.0, 32.0, 9.0, hair)
			_block(34.0, 64.0, 32.0, 8.0, hair)
		"curly":
			_block(32.0, 20.0, 36.0, 11.0, hair)
			_block(35.0, 30.0, 7.0, 4.0, hair)
			_block(58.0, 30.0, 7.0, 4.0, hair)
		"long":
			_block(32.0, 22.0, 36.0, 9.0, hair)
			_block(49.0, 22.0, 2.0, 7.0, look.skin)
			_block(32.0, 30.0, 4.0, 36.0, hair)
			_block(64.0, 30.0, 4.0, 36.0, hair)
		"braids":
			_block(32.0, 22.0, 36.0, 10.0, hair)
			for left: float in [38.0, 45.0, 53.0, 60.0]:
				_block(left, 24.0, 2.0, 7.0, hair.lightened(0.15))


## Grey at the temples, where hair greys first.
func _draw_temples() -> void:
	var grey := look.temple_colour()
	_block(32.0, 27.0, 3.0, 13.0, grey)
	_block(65.0, 27.0, 3.0, 13.0, grey)


func _draw_beard() -> void:
	var colour := look.beard_colour()
	match look.beard:
		"moustache":
			_block(42.0, 56.0, 16.0, 4.0, colour)
		"thin_moustache":
			_block(43.0, 57.0, 14.0, 2.0, colour)
		"goatee":
			_block(43.0, 57.0, 14.0, 2.0, colour)
			_block(47.0, 66.0, 6.0, 4.0, colour)
		"full":
			_block(34.0, 54.0, 32.0, 16.0, colour)


func _draw_hat() -> void:
	var colour := look.hat_colour()
	match look.hat:
		"cap":
			_block(35.0, 12.0, 30.0, 4.0, colour)
			_block(31.0, 15.0, 38.0, 14.0, colour)
			_block(48.0, 10.0, 4.0, 2.0, colour.darkened(0.3))
			_block(29.0, 28.0, 42.0, 5.0, colour.darkened(0.2))
		"vueltiao":
			_block(35.0, 7.0, 30.0, 20.0, HeadParts.STRAW)
			_block(35.0, 11.0, 30.0, 2.0, HeadParts.STRAW_BLACK)
			_block(35.0, 19.0, 30.0, 2.0, HeadParts.STRAW_BLACK)
			for left: float in [37.0, 43.0, 49.0, 55.0, 61.0]:
				_block(left, 15.0, 2.0, 2.0, HeadParts.STRAW_BLACK)
			_block(14.0, 25.0, 72.0, 6.0, HeadParts.STRAW)
			_block(18.0, 27.0, 64.0, 1.5, HeadParts.STRAW_BLACK)
			_block(14.0, 30.0, 72.0, 1.0, HeadParts.STRAW_BLACK)
		"headwrap":
			# Rounded and rising, with a fold of the second fabric crossing the
			# front and a knot at one side.
			_block(37.0, 5.0, 26.0, 4.0, colour)
			_block(32.0, 8.0, 36.0, 5.0, colour)
			_block(29.0, 12.0, 42.0, 20.0, colour)
			for step in 6:
				_block(36.0 + step * 3.0, 13.0 + step * 3.0, 4.0, 3.0, look.trim)
			_block(57.0, 18.0, 10.0, 9.0, look.trim)
			_block(62.0, 15.0, 5.0, 5.0, colour.lightened(0.15))
