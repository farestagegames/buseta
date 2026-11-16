class_name MenuRouteChip
extends Button
## The chosen route, its time of day and the expected pay in one white pill.
## Tapping it opens the routes tab.

const CARD_BG := Color(0.996, 0.992, 0.984) ## #FEFDFB
const INK := Color(0.133, 0.141, 0.176) ## #22242D
const PRESSED_BG := Color(0.93, 0.92, 0.89)
const SHADOW := Color(0.0, 0.0, 0.0, 0.2)

const RADIUS := 16
const OUTLINE_WIDTH := 3
const SHADOW_SIZE := 6
const SHADOW_OFFSET := Vector2(0, 4)
const CHIP_HEIGHT := 52.0
const CHIP_MIN_WIDTH := 240.0
const FONT_SIZE := 18
const MAX_TEXT_WIDTH := 520.0
const ICON_SIZE := 26.0
const SIDE_MARGIN := 14.0
const GAP := 8

## "ROUTE NAME · TIME · +$PAY", upper case and shrunk to fit a long name.
var label: Label


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(CHIP_MIN_WIDTH, CHIP_HEIGHT)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_stylebox_override("normal", _pill_style(CARD_BG))
	add_theme_stylebox_override("hover", _pill_style(CARD_BG))
	add_theme_stylebox_override("pressed", _pill_style(PRESSED_BG))
	add_theme_stylebox_override("hover_pressed", _pill_style(PRESSED_BG))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var row := HBoxContainer.new()
	row.name = "ContentRow"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = SIDE_MARGIN
	row.offset_right = -SIDE_MARGIN
	row.offset_top = 4.0
	row.offset_bottom = -4.0
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var icon := MenuIcon.new()
	icon.name = "RouteIcon"
	icon.icon = "routes"
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	label = Label.new()
	label.name = "RouteText"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)


## Shows this route in upper case, shrinking the text rather than letting a long
## name spill out of the pill.
func show_route(route_name: String, time_name: String, pay_text: String) -> void:
	var shown := "%s · %s · %s" % [route_name, time_name, pay_text]
	label.text = shown.to_upper()
	var font_size := _fitted_size(label.text)
	label.add_theme_font_size_override("font_size", font_size)
	# The pill grows with its text, up to the widest the text may be.
	var font := label.get_theme_font("font")
	var text_width := MAX_TEXT_WIDTH
	if font != null:
		text_width = minf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, MAX_TEXT_WIDTH)
	custom_minimum_size.x = maxf(CHIP_MIN_WIDTH, text_width + ICON_SIZE + GAP + SIDE_MARGIN * 2.0 + 6.0)


func _fitted_size(text: String) -> int:
	var font := label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return FONT_SIZE
	return UiStyle.fit_font_size(font, text, FONT_SIZE, MAX_TEXT_WIDTH)


func _pill_style(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(RADIUS)
	box.set_border_width_all(OUTLINE_WIDTH)
	box.border_color = INK
	box.shadow_color = SHADOW
	box.shadow_size = SHADOW_SIZE
	box.shadow_offset = SHADOW_OFFSET
	return box
