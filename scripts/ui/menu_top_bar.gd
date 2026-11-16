class_name MenuTopBar
extends HBoxContainer
## The top row of the main menu: level, money and driver pills on the left, the
## game's name in the middle and the round icon buttons on the right.

signal driver_pressed
## Emitted when the driver pill is pressed, so the menu can open the drivers tab.

signal icon_pressed(name: String)
## Emitted with "horn", "gear", "camera", "sound" or "fullscreen" when one of
## the icon buttons is pressed.

const CARD_BG := Color(0.996, 0.992, 0.984) ## #FEFDFB
const INK := Color(0.133, 0.141, 0.176) ## #22242D
const ACCENT := Color(1.0, 0.78, 0.2) ## #FFC733
const SHADOW := Color(0.0, 0.0, 0.0, 0.2)

const PILL_RADIUS := 16
const ICON_RADIUS := 14
const OUTLINE_WIDTH := 3
const SHADOW_SIZE := 6
const SHADOW_OFFSET := Vector2(0, 4)
const PILL_HEIGHT := 52.0
const DRIVER_MIN_WIDTH := 160.0
const ICON_BUTTON_SIZE := Vector2(52.0, 52.0)
const ICON_SIZE := 30.0
const COIN_SIZE := 32.0
const BADGE_SIZE := Vector2(34.0, 34.0)
const XP_WIDTH := 120.0
const XP_HEIGHT := 6.0
const TITLE_FONT_SIZE := 26
const TITLE_OUTLINE := 6
const BOUNCE_SCALE := 0.92
const BOUNCE_DURATION := 0.18

## "LEVEL 3", in small capitals next to the yellow level badge.
var level_label: Label
## Progress through the current level, from 0 to 1.
var level_bar: ProgressBar
## The money, already formatted for the current country.
var coins_label: Label
## The game's name, white with an ink outline.
var title_label: Label
## The pill that opens the drivers tab.
var driver_button: Button

var _level_number: Label
var _driver_name_label: Label
var _driver_badge: DriverBadge
var _icons: Dictionary = {}
var _bounces: Dictionary = {}


func _init() -> void:
	add_theme_constant_override("separation", 12)
	custom_minimum_size.y = PILL_HEIGHT
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_build_level_pill())
	add_child(_build_money_pill())
	driver_button = _build_driver_pill()
	add_child(driver_button)
	add_child(_build_title_space())
	add_child(_build_icon_row())
	set_muted(false)


## Reads the current save into the pills. [param progress] is 0 to 1 through the
## level, and [param money_text] is already formatted.
func refresh(level: int, progress: float, money_text: String, driver_name: String, look: DriverLook) -> void:
	level_label.text = (tr("Level %d") % level).to_upper()
	_level_number.text = str(level)
	level_bar.value = clampf(progress, 0.0, 1.0)
	coins_label.text = money_text
	_driver_name_label.text = short_name(driver_name)
	if look != null:
		_driver_badge.look = look
		_driver_badge.queue_redraw()


## Swaps the sound icon for the crossed-out one, so the button shows the state.
func set_muted(muted: bool) -> void:
	var sound := _icons.get("sound") as MenuIcon
	if sound != null:
		sound.icon = "sound_off" if muted else "sound"


## The first name and the first letter of the surname, as a menu pill shows a
## driver: "Wilmer Pertuz" becomes "Wilmer P.". One word stays as it is.
static func short_name(full: String) -> String:
	var words := full.strip_edges().split(" ", false)
	if words.is_empty():
		return ""
	if words.size() == 1:
		return words[0]
	return "%s %s." % [words[0], words[1].substr(0, 1).to_upper()]


func _build_level_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = "LevelPill"
	pill.add_theme_stylebox_override("panel", _pill_style())
	pill.custom_minimum_size = Vector2(0.0, PILL_HEIGHT)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)

	var badge := PanelContainer.new()
	badge.name = "LevelBadge"
	badge.custom_minimum_size = BADGE_SIZE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = ACCENT
	badge_style.set_corner_radius_all(12)
	badge.add_theme_stylebox_override("panel", badge_style)
	_level_number = Label.new()
	_level_number.name = "LevelNumber"
	_level_number.text = "1"
	_level_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_number.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_level_number.add_theme_font_size_override("font_size", 20)
	_level_number.add_theme_color_override("font_color", INK)
	_level_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(_level_number)
	row.add_child(badge)

	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = (tr("Level %d") % 1).to_upper()
	level_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", INK)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(level_label)
	level_bar = ProgressBar.new()
	level_bar.name = "LevelBar"
	level_bar.show_percentage = false
	level_bar.custom_minimum_size = Vector2(XP_WIDTH, XP_HEIGHT)
	level_bar.max_value = 1.0
	level_bar.step = 0.01
	level_bar.value = 0.0
	level_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(INK, 0.14)
	track.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(3)
	level_bar.add_theme_stylebox_override("background", track)
	level_bar.add_theme_stylebox_override("fill", fill)
	lines.add_child(level_bar)
	row.add_child(lines)
	return pill


func _build_money_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = "MoneyPill"
	pill.add_theme_stylebox_override("panel", _pill_style())
	pill.custom_minimum_size = Vector2(0.0, PILL_HEIGHT)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var coin := MenuIcon.new()
	coin.name = "CoinIcon"
	coin.icon = "coin"
	coin.custom_minimum_size = Vector2(COIN_SIZE, COIN_SIZE)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	coins_label = Label.new()
	coins_label.name = "CoinsLabel"
	coins_label.text = ""
	coins_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coins_label.add_theme_font_size_override("font_size", 20)
	coins_label.add_theme_color_override("font_color", INK)
	coins_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(coins_label)
	return pill


func _build_driver_pill() -> Button:
	var button := Button.new()
	button.name = "DriverButton"
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(DRIVER_MIN_WIDTH, PILL_HEIGHT)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_stylebox_override("normal", _pill_style())
	button.add_theme_stylebox_override("hover", _pill_style(Color(0.97, 0.96, 0.93)))
	button.add_theme_stylebox_override("pressed", _pill_style(Color(0.93, 0.92, 0.89)))
	button.add_theme_stylebox_override("hover_pressed", _pill_style(Color(0.93, 0.92, 0.89)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_right = -12.0
	row.offset_top = 4.0
	row.offset_bottom = -4.0
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	_driver_badge = DriverBadge.new(DriverLook.new(), 40.0)
	_driver_badge.name = "DriverBadge"
	row.add_child(_driver_badge)
	_driver_name_label = Label.new()
	_driver_name_label.name = "DriverName"
	_driver_name_label.text = ""
	_driver_name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_driver_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_driver_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_driver_name_label.add_theme_font_size_override("font_size", 18)
	_driver_name_label.add_theme_color_override("font_color", INK)
	_driver_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_driver_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_driver_name_label)
	button.pressed.connect(_on_driver_pressed)
	return button


func _build_title_space() -> Control:
	var middle := Control.new()
	middle.name = "TitleSpace"
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = str(ProjectSettings.get_setting("application/config/name"))
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_outline_color", INK)
	title_label.add_theme_constant_override("outline_size", TITLE_OUTLINE)
	# The label takes the taps itself, so a parent can connect to its input and
	# still find the rest of the bar quiet.
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	middle.add_child(title_label)
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return middle


func _build_icon_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "IconRow"
	row.add_theme_constant_override("separation", 8)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.alignment = BoxContainer.ALIGNMENT_END
	_add_icon_button(row, "HornButton", "horn")
	_add_icon_button(row, "GearButton", "gear")
	_add_icon_button(row, "CameraButton", "camera")
	_add_icon_button(row, "SoundButton", "sound")
	_add_icon_button(row, "FullscreenButton", "fullscreen")
	return row


func _add_icon_button(row: HBoxContainer, node_name: String, icon_name: String) -> void:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = ICON_BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _icon_style(CARD_BG))
	button.add_theme_stylebox_override("hover", _icon_style(Color(0.97, 0.96, 0.93)))
	button.add_theme_stylebox_override("pressed", _icon_style(Color(0.93, 0.92, 0.89)))
	button.add_theme_stylebox_override("hover_pressed", _icon_style(Color(0.93, 0.92, 0.89)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := MenuIcon.new()
	icon.name = "%sGlyph" % node_name.trim_suffix("Button")
	icon.icon = icon_name
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(icon)
	button.add_child(centre)
	_icons[icon_name] = icon
	button.pressed.connect(_on_icon_pressed.bind(icon_name, button))
	# There is no browser fullscreen to offer on a phone.
	if icon_name == "fullscreen":
		button.visible = not OS.has_feature("mobile")
	row.add_child(button)


func _on_driver_pressed() -> void:
	driver_pressed.emit()


func _on_icon_pressed(icon_name: String, button: Button) -> void:
	_play_bounce(button)
	icon_pressed.emit(icon_name)


func _play_bounce(button: Button) -> void:
	if not is_inside_tree() or not is_instance_valid(button):
		return
	var existing: Tween = _bounces.get(button)
	if existing != null and existing.is_valid():
		existing.kill()
	button.pivot_offset = button.size / 2.0
	var tween := create_tween()
	_bounces[button] = tween
	tween.set_parallel(false)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(button, "scale", Vector2(BOUNCE_SCALE, BOUNCE_SCALE), BOUNCE_DURATION / 2.0)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), BOUNCE_DURATION / 2.0)


func _pill_style(bg: Color = CARD_BG) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(PILL_RADIUS)
	box.set_border_width_all(OUTLINE_WIDTH)
	box.border_color = INK
	box.shadow_color = SHADOW
	box.shadow_size = SHADOW_SIZE
	box.shadow_offset = SHADOW_OFFSET
	box.content_margin_left = 12.0
	box.content_margin_right = 14.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


func _icon_style(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(ICON_RADIUS)
	box.set_border_width_all(OUTLINE_WIDTH)
	box.border_color = INK
	box.shadow_color = SHADOW
	box.shadow_size = SHADOW_SIZE
	box.shadow_offset = SHADOW_OFFSET
	return box
