class_name MenuTabBar
extends PanelContainer
## Bottom navigation bar for the main menu.
## Holds a row of tab buttons in a rounded panel with shadow.

signal tab_selected(index: int)
## Emitted when the user chooses a tab (or when select() is called with emit = true).

const BAR_BG := Color(0.98, 0.97, 0.94)
const BAR_OUTLINE := Color(0.13, 0.14, 0.18)
const BAR_SHADOW := Color(0.0, 0.0, 0.0, 0.35)
const ACTIVE_BG := Color(1.0, 0.78, 0.2)
const ACTIVE_OUTLINE := Color(0.13, 0.14, 0.18)
const LABEL_COLOUR := Color(0.13, 0.14, 0.18)

const BAR_RADIUS := 22
const BAR_OUTLINE_WIDTH := 3
const BAR_SHADOW_SIZE := 6
const BAR_SHADOW_OFFSET := Vector2(0, 4)
const ACTIVE_RADIUS := 16
const ACTIVE_OUTLINE_WIDTH := 3
const BUTTON_MIN_SIZE := Vector2(120, 64)
const ICON_SIZE := Vector2(36, 36)
const LABEL_FONT_SIZE := 20
const BOUNCE_SCALE := 0.92
const BOUNCE_DURATION := 0.18

var _hbox: HBoxContainer
var _items: Array[Dictionary] = []
var _current: int = 0
var _button_refs: Array[Button] = []

## Currently active tab index.
## Setting it restyles the buttons and clamps to valid range.
var current: int:
	get:
		return _current
	set(value):
		_current = clampi(value, 0, _items.size() - 1)
		_apply_styles()

func _init() -> void:
	# Base panel styling
	var panel := StyleBoxFlat.new()
	panel.bg_color = BAR_BG
	panel.set_corner_radius_all(BAR_RADIUS)
	panel.border_width_bottom = BAR_OUTLINE_WIDTH
	panel.border_width_top = BAR_OUTLINE_WIDTH
	panel.border_width_left = BAR_OUTLINE_WIDTH
	panel.border_width_right = BAR_OUTLINE_WIDTH
	panel.border_color = BAR_OUTLINE
	panel.shadow_size = BAR_SHADOW_SIZE
	panel.shadow_offset = BAR_SHADOW_OFFSET
	panel.shadow_color = BAR_SHADOW
	add_theme_stylebox_override("panel", panel)

	# Horizontal container for tabs
	_hbox = HBoxContainer.new()
	_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hbox.offset_left = 12
	_hbox.offset_right = -12
	_hbox.offset_top = 6
	_hbox.offset_bottom = -6
	_hbox.set_h_grow_direction(Control.GROW_DIRECTION_BOTH)
	add_child(_hbox)

func setup(items: Array) -> void:
	## Populate the bar with tabs.
	## Each item: {"label": String, "icon": Control (optional)}
	_items.assign(items)
	_button_refs.clear()

	# Clear existing children of the hbox
	for child in _hbox.get_children():
		child.queue_free()

	for i in _items.size():
		var item := _items[i]
		var btn := _make_button(item, i)
		_button_refs.append(btn)
		_hbox.add_child(btn)

	# Ensure current is valid and apply initial styles
	_current = clampi(_current, 0, _items.size() - 1)
	_apply_styles()

func _make_button(item: Dictionary, index: int) -> Button:
	var btn := Button.new()
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = BUTTON_MIN_SIZE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.set_meta("tab_index", index)
	# Icon on top of the label, in a box that fills the button. A tab without an
	# icon keeps an empty slot so every label sits at the same height.
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: Control = item.get("icon", null)
	if icon == null:
		icon = Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = ICON_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)
	# Translated first, then upper-cased, so the language file keeps normal keys.
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = tr(str(item.get("label", ""))).to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", LABEL_COLOUR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(label)
	btn.add_child(vbox)
	btn.pressed.connect(_on_button_pressed.bind(index))
	return btn

## The bounce tween running on each button, so a new press can stop the old one.
var _bounces: Dictionary = {}


func _on_button_pressed(index: int) -> void:
	select(index, true)
	_play_bounce(_button_refs[index])

func _play_bounce(btn: Button) -> void:
	if not btn or not is_instance_valid(btn):
		return
	# Kill any bounce still running on this button.
	var existing: Tween = _bounces.get(btn)
	if existing != null and existing.is_valid():
		existing.kill()
	btn.pivot_offset = btn.size / 2.0
	var tween := create_tween()
	_bounces[btn] = tween
	tween.set_parallel(false)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(btn, "scale", Vector2(BOUNCE_SCALE, BOUNCE_SCALE), BOUNCE_DURATION / 2.0)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), BOUNCE_DURATION / 2.0)

func select(index: int, emit: bool = true) -> void:
	## Select a tab by index. If emit is true, tab_selected is fired.
	index = clampi(index, 0, _items.size() - 1)
	if index == _current and not emit:
		return
	_current = index
	_apply_styles()
	if emit:
		tab_selected.emit(index)

func _apply_styles() -> void:
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = ACTIVE_BG
	active_style.set_corner_radius_all(ACTIVE_RADIUS)
	active_style.border_width_bottom = ACTIVE_OUTLINE_WIDTH
	active_style.border_width_top = ACTIVE_OUTLINE_WIDTH
	active_style.border_width_left = ACTIVE_OUTLINE_WIDTH
	active_style.border_width_right = ACTIVE_OUTLINE_WIDTH
	active_style.border_color = ACTIVE_OUTLINE

	var inactive_style := StyleBoxFlat.new()
	inactive_style.bg_color = Color(0, 0, 0, 0) # transparent
	inactive_style.set_corner_radius_all(ACTIVE_RADIUS)
	inactive_style.border_width_bottom = 0
	inactive_style.border_width_top = 0
	inactive_style.border_width_left = 0
	inactive_style.border_width_right = 0

	for i in _button_refs.size():
		var btn := _button_refs[i]
		if i == _current:
			btn.add_theme_stylebox_override("normal", active_style)
			btn.add_theme_stylebox_override("hover", active_style)
			btn.add_theme_stylebox_override("pressed", active_style)
			btn.add_theme_stylebox_override("hover_pressed", active_style)
			btn.add_theme_color_override("font_color", LABEL_COLOUR)
			btn.add_theme_color_override("font_hover_color", LABEL_COLOUR)
			btn.add_theme_color_override("font_pressed_color", LABEL_COLOUR)
		else:
			btn.add_theme_stylebox_override("normal", inactive_style)
			btn.add_theme_stylebox_override("hover", inactive_style)
			btn.add_theme_stylebox_override("pressed", inactive_style)
			btn.add_theme_stylebox_override("hover_pressed", inactive_style)
			btn.add_theme_color_override("font_color", LABEL_COLOUR)
			btn.add_theme_color_override("font_hover_color", LABEL_COLOUR)
			btn.add_theme_color_override("font_pressed_color", LABEL_COLOUR)

func button_at(index: int) -> Button:
	## Return the Button for the tab at index, or null if out of range.
	if index < 0 or index >= _button_refs.size():
		return null
	return _button_refs[index]