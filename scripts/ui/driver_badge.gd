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
	_draw_neck()
	if look.shoulder == "carriel":
		_draw_carriel()
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
	_draw_eyewear()
	_draw_hat()
	if look.towel:
		_block(66.0, 74.0, 13.0, 4.0, DriverFigure.TOWEL)
		_block(67.0, 77.0, 11.0, 17.0, DriverFigure.TOWEL)
		_block(67.0, 91.0, 11.0, 1.5, DriverFigure.TOWEL.darkened(0.2))


func _draw_clothes() -> void:
	match look.outfit:
		"rojiblanca":
			_block(14.0, 76.0, 72.0, 24.0, DriverFigure.SHIRT_WHITE)
			for i in 4:
				_block(14.0 + float(i) * 18.0, 76.0, 9.0, 24.0, DriverFigure.SHIRT_RED)
			return
		"ruana":
			_block(10.0, 74.0, 80.0, 26.0, look.uniform)
			for top: float in [83.0, 90.0]:
				_block(10.0, top, 80.0, 3.0, look.trim)
			_block(10.0, 97.0, 80.0, 3.0, look.trim)
			return
		"floral":
			_block(14.0, 76.0, 72.0, 24.0, look.uniform)
			for spot: Rect2 in [Rect2(20, 79, 10, 10), Rect2(68, 80, 10, 10), Rect2(44, 89, 10, 9), Rect2(24, 91, 8, 8), Rect2(70, 92, 8, 8)]:
				_block(spot.position.x, spot.position.y, spot.size.x, spot.size.y, look.trim)
				_block(spot.position.x + spot.size.x * 0.3, spot.position.y + spot.size.y * 0.3, spot.size.x * 0.4, spot.size.y * 0.4, Color.WHITE)
			_block(37.0, 76.0, 7.0, 4.0, look.uniform.lightened(0.3))
			_block(56.0, 76.0, 7.0, 4.0, look.uniform.lightened(0.3))
			return
	_block(14.0, 76.0, 72.0, 24.0, look.uniform)
	if look.outfit == "chaleco":
		for left: float in [20.0, 58.0]:
			_block(left, 78.0, 22.0, 22.0, DriverFigure.VEST)
			for top: float in [86.0, 93.0]:
				_block(left, top, 22.0, 3.0, DriverFigure.SILVER)
		return
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


func _draw_neck() -> void:
	match look.neck:
		"gold_chain":
			_block(43.0, 74.0, 14.0, 2.0, HeadParts.GOLD)
			for left: float in [44.0, 54.0]:
				_block(left, 75.0, 2.0, 9.0, HeadParts.GOLD)
			_block(47.0, 83.0, 6.0, 2.0, HeadParts.GOLD)
			_block(48.0, 85.0, 4.0, 4.0, HeadParts.GOLD)
		"rosary":
			for i in 7:
				var t := float(i) / 6.0
				_block(40.0 + t * 20.0 - 1.5, 74.0 + 12.0 * sin(t * PI), 3.0, 3.0, DriverFigure.BEAD_BROWN)
			var cross := DriverFigure.BEAD_BROWN.lightened(0.2)
			_block(49.0, 87.0, 2.0, 8.0, cross)
			_block(46.0, 89.0, 8.0, 2.0, cross)
		"panuelo":
			_block(40.0, 71.0, 20.0, 6.0, DriverFigure.NECKERCHIEF)
			_block(42.0, 76.0, 16.0, 5.0, DriverFigure.NECKERCHIEF)
			_block(45.0, 80.0, 10.0, 5.0, DriverFigure.NECKERCHIEF)
			_block(48.0, 84.0, 4.0, 5.0, DriverFigure.NECKERCHIEF.darkened(0.15))
			_block(47.0, 76.0, 6.0, 5.0, DriverFigure.NECKERCHIEF.darkened(0.15))


## A strap across the chest to a leather bag at the hip.
func _draw_carriel() -> void:
	for i in 6:
		_block(18.0 + float(i) * 8.5, 76.0 + float(i) * 3.5, 9.0, 6.0, DriverFigure.LEATHER_DARK)
	_block(60.0, 87.0, 20.0, 13.0, DriverFigure.LEATHER)
	_block(60.0, 87.0, 20.0, 5.0, DriverFigure.LEATHER_DARK)
	_block(68.0, 91.0, 4.0, 3.0, HeadParts.GOLD)


func _draw_eyewear() -> void:
	match look.eyewear:
		"aviators":
			for left: float in [37.0, 51.0]:
				_block(left, 41.0, 12.0, 12.0, HeadParts.GOLD)
				_block(left + 1.5, 42.5, 9.0, 9.0, HeadParts.AVIATOR_LENS)
			_block(49.0, 43.0, 2.0, 2.0, HeadParts.GOLD)
		"mirror_shades":
			_block(35.0, 41.0, 30.0, 12.0, HeadParts.SILVER)
			for left: float in [37.0, 52.0]:
				_block(left, 42.5, 11.0, 9.0, HeadParts.MIRROR_LENS)
			_block(39.0, 43.5, 4.0, 2.0, Color.WHITE)
			_block(54.0, 43.5, 4.0, 2.0, Color.WHITE)


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
		"cap", "gorra_ruta":
			_block(35.0, 12.0, 30.0, 4.0, colour)
			_block(31.0, 15.0, 38.0, 14.0, colour)
			_block(48.0, 10.0, 4.0, 2.0, colour.darkened(0.3))
			_block(29.0, 28.0, 42.0, 5.0, colour.darkened(0.2))
			if look.hat == "gorra_ruta":
				_block(45.0, 17.0, 10.0, 8.0, Color.WHITE)
				_block(47.0, 19.0, 6.0, 3.0, look.trim)
		"aguadeno":
			_block(35.0, 9.0, 30.0, 19.0, HeadParts.STRAW_PALE)
			_block(35.0, 19.0, 30.0, 5.0, HeadParts.STRAW_BLACK)
			_block(12.0, 26.0, 76.0, 6.0, HeadParts.STRAW_PALE)
			_block(12.0, 31.0, 76.0, 1.0, HeadParts.STRAW_PALE.darkened(0.15))
		"hard_hat":
			_block(33.0, 10.0, 34.0, 16.0, colour)
			_block(46.0, 8.0, 8.0, 3.0, colour.lightened(0.15))
			_block(27.0, 24.0, 46.0, 5.0, colour.darkened(0.1))
		"sun_hat":
			_block(33.0, 12.0, 34.0, 13.0, colour)
			_block(33.0, 20.0, 34.0, 4.0, look.trim)
			_block(10.0, 24.0, 80.0, 5.0, colour)
		"vueltiao", "vueltiao_tricolor":
			_block(35.0, 7.0, 30.0, 20.0, HeadParts.STRAW)
			_block(35.0, 11.0, 30.0, 2.0, HeadParts.STRAW_BLACK)
			_block(35.0, 19.0, 30.0, 2.0, HeadParts.STRAW_BLACK)
			for left: float in [37.0, 43.0, 49.0, 55.0, 61.0]:
				_block(left, 15.0, 2.0, 2.0, HeadParts.STRAW_BLACK)
			_block(14.0, 25.0, 72.0, 6.0, HeadParts.STRAW)
			_block(18.0, 27.0, 64.0, 1.5, HeadParts.STRAW_BLACK)
			_block(14.0, 30.0, 72.0, 1.0, HeadParts.STRAW_BLACK)
			if look.hat == "vueltiao_tricolor":
				for i in 3:
					var tone: Color = [HeadParts.FLAG_YELLOW, HeadParts.FLAG_BLUE, HeadParts.FLAG_RED][i]
					_block(35.0 + float(i) * 10.0, 14.0, 10.0, 4.0, tone)
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
