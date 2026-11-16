class_name MenuShiftButton
extends Button
## The big orange call to action that starts a shift. It breathes slowly so the
## eye finds it, and holds still while the menu is busy.

const NORMAL_BG := Color(1.0, 0.478, 0.102) ## #FF7A1A
const PRESSED_BG := Color(0.878, 0.396, 0.039) ## #E0650A
const HOVER_BG := Color(1.0, 0.525, 0.18)
const INK := Color(0.133, 0.141, 0.176) ## #22242D
const SHADOW := Color(0.0, 0.0, 0.0, 0.2)

const MIN_SIZE := Vector2(170.0, 68.0)
const RADIUS := 18
const OUTLINE_WIDTH := 3
const SHADOW_SIZE := 6
const SHADOW_OFFSET := Vector2(0, 4)
const FONT_SIZE := 32
const TEXT_OUTLINE := 6
const ICON_SIZE := 30.0
## Space either side of the word and icon, and between the two.
const TEXT_PADDING := 44.0
const PULSE_SCALE := 1.04
const PULSE_SECONDS := 1.6

## "START SHIFT", kept as a child label so the play icon sits beside it.
var label: Label

var _pulse: Tween
var _pulsing: bool = false


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = MIN_SIZE
	add_theme_stylebox_override("normal", _button_style(NORMAL_BG))
	add_theme_stylebox_override("hover", _button_style(HOVER_BG))
	add_theme_stylebox_override("pressed", _button_style(PRESSED_BG))
	add_theme_stylebox_override("hover_pressed", _button_style(PRESSED_BG))
	add_theme_stylebox_override("disabled", _button_style(NORMAL_BG.darkened(0.2)))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var row := HBoxContainer.new()
	row.name = "ContentRow"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	label = Label.new()
	label.name = "ShiftText"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", TEXT_OUTLINE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	var play := MenuIcon.new()
	play.name = "PlayIcon"
	play.icon = "play"
	play.colour = Color.WHITE
	play.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(play)
	_update_text()
	resized.connect(_keep_pivot_centred)


func _ready() -> void:
	_keep_pivot_centred()
	if _pulsing:
		set_pulsing(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and label != null:
		_update_text()


## Starts or stops the slow breathing. Stopping puts the button back at its
## normal size, so a paused menu never leaves it mid-pulse.
func set_pulsing(on: bool) -> void:
	_pulsing = on
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	if not on:
		scale = Vector2.ONE
		return
	if not is_inside_tree():
		return
	_keep_pivot_centred()
	_pulse = create_tween().set_loops()
	_pulse.set_trans(Tween.TRANS_SINE)
	_pulse.set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(self, "scale", Vector2(PULSE_SCALE, PULSE_SCALE), PULSE_SECONDS * 0.5)
	_pulse.tween_property(self, "scale", Vector2.ONE, PULSE_SECONDS * 0.5)


func is_pulsing() -> bool:
	return _pulsing


## Keeps the word and icon in one measured row, and the button wide enough for
## a longer translation than English.
func _update_text() -> void:
	label.text = tr("Start shift").to_upper()
	var font := label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var text_width := 0.0
	if font != null:
		text_width = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	custom_minimum_size = Vector2(maxf(MIN_SIZE.x, text_width + ICON_SIZE + TEXT_PADDING), MIN_SIZE.y)


func _keep_pivot_centred() -> void:
	pivot_offset = size / 2.0


func _button_style(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(RADIUS)
	box.set_border_width_all(OUTLINE_WIDTH)
	box.border_color = INK
	box.shadow_color = SHADOW
	box.shadow_size = SHADOW_SIZE
	box.shadow_offset = SHADOW_OFFSET
	return box
