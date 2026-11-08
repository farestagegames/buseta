class_name TutorialPanel
extends Control
## The tutorial message and a pulsing ring around the control it is talking about.

signal skip_requested

const PANEL_SIZE := Vector2(620.0, 96.0)
const PANEL_TOP := 214.0
const PULSE_SPEED := 5.0

var _message: Label
var _panel: PanelContainer
var _ring_rect: Rect2 = Rect2()
var _ring_style := StyleBoxFlat.new()
var _time: float = 0.0
var _left_clear: float = 0.0
var _right_clear: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ring_style.draw_center = false
	_ring_style.set_corner_radius_all(24)
	_ring_style.set_border_width_all(7)
	_panel = PanelContainer.new()
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.09, 0.1, 0.13, 0.94)
	backing.set_corner_radius_all(16)
	backing.set_border_width_all(3)
	backing.border_color = UiStyle.ACCENT
	backing.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", backing)
	_panel.offset_top = PANEL_TOP
	_panel.offset_bottom = PANEL_TOP + PANEL_SIZE.y
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.add_theme_font_size_override("font_size", 22)
	row.add_child(_message)
	var skip := Button.new()
	skip.text = "Skip tutorial"
	skip.custom_minimum_size = Vector2(150.0, 60.0)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.add_theme_font_size_override("font_size", 18)
	skip.pressed.connect(func() -> void: skip_requested.emit())
	row.add_child(skip)
	_layout()


## Keeps the message between the buttons at each side of the screen, so on a
## narrow phone it gets narrower and taller instead of covering them.
func keep_clear_of(left: float, right: float) -> void:
	_left_clear = left
	_right_clear = right
	_layout()


func _layout() -> void:
	if _panel == null:
		return
	var room := maxf(size.x - _left_clear - _right_clear, 0.0)
	var width := minf(PANEL_SIZE.x, room) if room > 0.0 else PANEL_SIZE.x
	var left := clampf((size.x - width) / 2.0, _left_clear, maxf(size.x - _right_clear - width, _left_clear))
	_panel.offset_left = left
	_panel.offset_right = left + width
	# Back to the base height, so it grows only as far as the current message needs.
	_panel.offset_bottom = PANEL_TOP + PANEL_SIZE.y


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func show_step(text: String, ring: Rect2) -> void:
	_message.text = text
	_panel.offset_bottom = PANEL_TOP + PANEL_SIZE.y
	_ring_rect = ring
	visible = true
	queue_redraw()


func hide_panel() -> void:
	visible = false


func ring() -> Rect2:
	return _ring_rect


func _process(dt: float) -> void:
	if visible and _ring_rect.has_area():
		_time += dt
		queue_redraw()


func _draw() -> void:
	if not _ring_rect.has_area():
		return
	var pulse := 0.5 + 0.5 * sin(_time * PULSE_SPEED)
	_ring_style.border_color = Color(UiStyle.ACCENT, 0.5 + 0.5 * pulse)
	draw_style_box(_ring_style, _ring_rect.grow(8.0 + 5.0 * pulse))
