class_name UiStyle
extends RefCounted
## The game's look: one theme for every standard control.

const INK := Color(0.09, 0.1, 0.13)
const PANEL := Color(0.13, 0.15, 0.2)
const CARD := Color(0.17, 0.2, 0.26)
const RAISED := Color(0.24, 0.28, 0.35)
const ACCENT := Color(0.98, 0.72, 0.15)
const GOOD := Color(0.5, 0.95, 0.6)
const TEXT := Color(0.96, 0.97, 1.0)
const MUTED := Color(1, 1, 1, 0.65)


## Makes this the look of every control in the game.
static func apply(font: Font) -> void:
	var theme := ThemeDB.get_default_theme()
	theme.default_font = font
	theme.default_font_size = 22
	theme.merge_with(build())


static func build() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _box(RAISED))
	theme.set_stylebox("hover", "Button", _box(RAISED.lightened(0.1)))
	theme.set_stylebox("pressed", "Button", _box(ACCENT))
	theme.set_stylebox("hover_pressed", "Button", _box(ACCENT))
	theme.set_stylebox("disabled", "Button", _box(CARD))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_hover_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("normal", "OptionButton", _box(RAISED))
	theme.set_stylebox("hover", "OptionButton", _box(RAISED.lightened(0.1)))
	theme.set_stylebox("pressed", "OptionButton", _box(RAISED.lightened(0.1)))
	theme.set_stylebox("hover_pressed", "OptionButton", _box(RAISED.lightened(0.1)))
	theme.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", TEXT)
	theme.set_color("font_pressed_color", "OptionButton", TEXT)
	theme.set_color("font_hover_pressed_color", "OptionButton", TEXT)
	theme.set_icon("arrow", "OptionButton", _chevron(30, ACCENT))
	theme.set_constant("arrow_margin", "OptionButton", 16)
	theme.set_stylebox("panel", "PopupMenu", _box(CARD, 14, 10))
	theme.set_stylebox("hover", "PopupMenu", _box(ACCENT, 10, 6))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_font_size("font_size", "PopupMenu", 28)
	theme.set_constant("v_separation", "PopupMenu", 24)
	theme.set_constant("item_start_padding", "PopupMenu", 14)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, 18))
	theme.set_stylebox("background", "ProgressBar", _box(CARD, 8, 0))
	theme.set_stylebox("fill", "ProgressBar", _box(ACCENT, 8, 0))
	theme.set_color("font_color", "ProgressBar", INK)
	theme.set_stylebox("slider", "HSlider", _box(RAISED, 6, 6))
	theme.set_stylebox("grabber_area", "HSlider", _box(ACCENT, 6, 6))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(ACCENT, 6, 6))
	theme.set_icon("grabber", "HSlider", _dot(34, ACCENT))
	theme.set_icon("grabber_highlight", "HSlider", _dot(38, ACCENT.lightened(0.2)))
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return theme


static func _box(colour: Color, radius: int = 14, margin: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box


## A downward arrow, big enough to say "this opens" on a phone.
static func _chevron(size: int, colour: Color) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var middle := float(size - 1) / 2.0
	var thickness := float(size) * 0.16
	for y in size:
		for x in size:
			var line := float(size) * 0.3 + float(size) * 0.42 - absf(float(x) - middle) * 0.84
			var inside := thickness - absf(float(y) - line)
			if absf(float(x) - middle) < float(size) * 0.46:
				image.set_pixel(x, y, Color(colour, clampf(inside, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


static func _dot(size: int, colour: Color) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := float(size - 1) / 2.0
	for y in size:
		for x in size:
			var distance := Vector2(x - centre, y - centre).length()
			var alpha := clampf(centre - distance, 0.0, 1.0)
			image.set_pixel(x, y, Color(colour, alpha))
	return ImageTexture.create_from_image(image)
