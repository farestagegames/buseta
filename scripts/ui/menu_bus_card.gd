class_name MenuBusCard
extends PanelContainer
## White card showing a bus: category tag, name, livery dots, and four stat bars.
## Uses the design system colours from the redesign: white #FEFDFB card, ink #22242D
## 3 px outline, shadow Color(0,0,0,0.2) offset (0,4) size 6, corner radius 18.

const CARD_BG := Color(0.996, 0.992, 0.984)  # #FEFDFB
const CARD_OUTLINE := Color(0.133, 0.141, 0.176)  # #22242D
const CARD_SHADOW := Color(0.0, 0.0, 0.0, 0.2)
const TAG_BG := Color(0.957, 0.933, 0.863)  # #F4EEDC
const INK := Color(0.133, 0.141, 0.176)  # #22242D
const MUTED := Color(0.478, 0.502, 0.565)  # #7A8090

const STAT_SPEED_COLOUR := Color(1.0, 0.361, 0.361)   # #FF5C5C
const STAT_STEER_COLOUR := Color(0.302, 0.588, 1.0)    # #4D96FF
const STAT_SEATS_COLOUR := Color(0.420, 0.796, 0.467)  # #6BCB77
const STAT_BRAKES_COLOUR := Color(1.0, 0.851, 0.239)   # #FFD93D
const BAR_BG := Color(0.910, 0.894, 0.855)  # #E8E4DA

const MIN_WIDTH := 300
const CARD_RADIUS := 18
const OUTLINE_WIDTH := 3
const SHADOW_SIZE := 6
const SHADOW_OFFSET := Vector2(0, 4)

const TAG_FONT_SIZE := 14
const NAME_FONT_SIZE := 26
const STAT_ICON_SIZE := 20
const BAR_HEIGHT := 10
const BAR_RADIUS := 5
const DOT_SIZE := 16
const DOT_RING_WIDTH := 2

## Speed stat: map max_drive_accel (m/s²) to 0..1. Range observed in buses: 1.3..1.85.
const SPEED_MIN := 1.0
const SPEED_MAX := 2.0
## Steering stat: map max_steer_degrees to 0..1. Range: 38..42.
const STEER_MIN := 35.0
const STEER_MAX := 45.0
## Seats stat: map capacity to 0..1. Range: 24..120.
const SEATS_MIN := 20.0
const SEATS_MAX := 130.0
## Brakes stat: map max_brake_decel (m/s²) to 0..1. Range: 3.4..4.3.
const BRAKES_MIN := 3.0
const BRAKES_MAX := 5.0

var name_label: Label
var tag_label: Label
var _dots_container: HBoxContainer
var _stat_bars: Array[Control] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Base card styling
	var panel := StyleBoxFlat.new()
	panel.bg_color = CARD_BG
	panel.set_corner_radius_all(CARD_RADIUS)
	panel.border_width_bottom = OUTLINE_WIDTH
	panel.border_width_top = OUTLINE_WIDTH
	panel.border_width_left = OUTLINE_WIDTH
	panel.border_width_right = OUTLINE_WIDTH
	panel.border_color = CARD_OUTLINE
	panel.shadow_size = SHADOW_SIZE
	panel.shadow_offset = SHADOW_OFFSET
	panel.shadow_color = CARD_SHADOW
	add_theme_stylebox_override("panel", panel)
	custom_minimum_size.x = MIN_WIDTH

	# Main vertical layout
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Top row: tag on left, name next to it, dots on right
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)

	# Tag (category)
	tag_label = Label.new()
	tag_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag_label.add_theme_font_size_override("font_size", TAG_FONT_SIZE)
	tag_label.add_theme_color_override("font_color", INK)
	var tag_panel := PanelContainer.new()
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = TAG_BG
	tag_style.set_corner_radius_all(8)
	tag_style.content_margin_left = 10.0
	tag_style.content_margin_right = 10.0
	tag_style.content_margin_top = 4.0
	tag_style.content_margin_bottom = 4.0
	tag_panel.add_theme_stylebox_override("panel", tag_style)
	tag_panel.add_child(tag_label)
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(tag_panel)

	# Bus name
	name_label = Label.new()
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	name_label.add_theme_color_override("font_color", INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_label)

	# Livery dots container (right side)
	_dots_container = HBoxContainer.new()
	_dots_container.add_theme_constant_override("separation", 6)
	_dots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_row.add_child(_dots_container)

	# Four stat rows
	var stat_names := ["speed", "steering", "seats", "brakes"]
	var stat_colours := [STAT_SPEED_COLOUR, STAT_STEER_COLOUR, STAT_SEATS_COLOUR, STAT_BRAKES_COLOUR]
	var stat_icons := ["play", "arrow_right", "driver", "horn"]  # MenuIcon names

	for i in 4:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vbox.add_child(row)

		# MenuIcon for the stat
		var icon := MenuIcon.new()
		icon.icon = stat_icons[i]
		icon.colour = stat_colours[i]
		icon.custom_minimum_size = Vector2(STAT_ICON_SIZE, STAT_ICON_SIZE)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

		var bar := _Bar.new()
		bar.fill = stat_colours[i]
		bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.name = "StatBar%d" % i
		bar.set_meta("value", 0.0)
		row.add_child(bar)
		_stat_bars.append(bar)


## A rounded stat bar that draws its own track and fill from its "value" meta.
class _Bar extends Control:
	var fill := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var radius := size.y / 2.0
		_pill(Rect2(Vector2.ZERO, size), BAR_BG, radius)
		var value := clampf(float(get_meta("value", 0.0)), 0.0, 1.0)
		if value > 0.0:
			_pill(Rect2(Vector2.ZERO, Vector2(maxf(size.x * value, size.y), size.y)), fill, radius)

	func _pill(rect: Rect2, colour: Color, radius: float) -> void:
		draw_rect(Rect2(rect.position + Vector2(radius, 0), Vector2(rect.size.x - radius * 2.0, rect.size.y)), colour)
		draw_circle(rect.position + Vector2(radius, radius), radius, colour)
		draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, colour)


## One livery colour; the chosen one is ringed in ink.
class _Dot extends Control:
	var colour := Color.WHITE
	var chosen := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var centre := size / 2.0
		var radius := minf(size.x, size.y) / 2.0
		draw_circle(centre, radius - 1.0, colour)
		draw_circle(centre, radius - 1.0, INK if chosen else Color(INK, 0.35), false, DOT_RING_WIDTH if chosen else 1.0, true)


func show_bus(name: String, category: String, stats: Array, dots: Array, chosen_dot: int) -> void:
	## Populate the card with bus data.
	## [param name] Bus display name (upper-cased).
	## [param category] Category tag text (upper-cased).
	## [param stats] Array of 4 floats 0..1: [speed, steering, seats, brakes].
	## [param dots] Array of livery colours (up to 6).
	## [param chosen_dot] Index of the selected livery dot (ringed in ink).
	name_label.text = name.to_upper()
	tag_label.text = category.to_upper()

	# Clear existing dots
	for child in _dots_container.get_children():
		child.queue_free()

	# Create up to 6 livery dots
	for i in min(dots.size(), 6):
		var dot := _Dot.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.colour = dots[i]
		dot.chosen = i == chosen_dot
		_dots_container.add_child(dot)

	# Set stat bar values
	for i in min(stats.size(), 4):
		_stat_bars[i].set_meta("value", clampf(stats[i], 0.0, 1.0))
		_stat_bars[i].queue_redraw()

static func stats_for(spec: BusSpec) -> Array[float]:
	## Convert a BusSpec into four 0..1 stat values: [speed, steering, seats, brakes].
	## Speed from max_drive_accel (1.0..2.0 m/s²).
	## Steering from max_steer_degrees (35..45°).
	## Seats from capacity (20..130).
	## Brakes from max_brake_decel (3.0..5.0 m/s²).
	var speed := (spec.max_drive_accel - SPEED_MIN) / (SPEED_MAX - SPEED_MIN)
	var steer := (spec.max_steer_degrees - STEER_MIN) / (STEER_MAX - STEER_MIN)
	var seats := (spec.capacity - SEATS_MIN) / (SEATS_MAX - SEATS_MIN)
	var brakes := (spec.max_brake_decel - BRAKES_MIN) / (BRAKES_MAX - BRAKES_MIN)
	return [
		clampf(speed, 0.0, 1.0),
		clampf(steer, 0.0, 1.0),
		clampf(seats, 0.0, 1.0),
		clampf(brakes, 0.0, 1.0),
	]