class_name MenuQuickTray
extends HBoxContainer
## A row of white cards over the bus stage for quick picks, like the prototype's
## RUTAS and CHOFER trays: a few owned routes or drivers, the chosen one ringed in
## yellow, and a last card that opens the full list.

signal picked(id: String)
signal more_pressed

const CARD_SIZE := Vector2(150.0, 128.0)
const ART := 32.0
const MAX_PICKS := 4
const RING := Color("#FFC733")
const PILL := Color("#EEF0F4")
const PILL_CHOSEN := Color("#FFE9A8")


func _init() -> void:
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER


## Up to [constant MAX_PICKS] ids from [param ids], in their order, with
## [param chosen] always in: the first few, or the run that ends at the chosen one.
static func window(ids: Array, chosen: String) -> Array:
	var at := maxi(ids.find(chosen), 0)
	var start := maxi(at - MAX_PICKS + 1, 0)
	return ids.slice(start, start + MAX_PICKS)


## A card for one pick: an icon or portrait, a name and a short detail pill.
func add_pick(id: String, title: String, detail: String, art: Control, chosen: bool) -> Button:
	var card := _card("Pick_" + id, chosen)
	var lines := card.get_meta("lines") as VBoxContainer
	art.custom_minimum_size = Vector2(ART, ART)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(art)
	lines.add_child(_title(title))
	lines.add_child(_pill(detail, chosen))
	card.pressed.connect(func() -> void: picked.emit(id))
	add_child(card)
	return card


## The last card: opens the full list.
func add_more(title: String, icon_name: String) -> Button:
	var card := _card("MoreCard", false)
	var lines := card.get_meta("lines") as VBoxContainer
	var icon := MenuIcon.new()
	icon.icon = icon_name
	icon.colour = MenuHomeDrawer.MUTED
	icon.custom_minimum_size = Vector2(ART, ART)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(icon)
	lines.add_child(_title(title))
	card.pressed.connect(func() -> void: more_pressed.emit())
	add_child(card)
	return card


func _card(node_name: String, chosen: bool) -> Button:
	var card := Button.new()
	card.name = node_name
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	var box := MenuHomeDrawer.card_box(MenuHomeDrawer.CARD_BG, 18, 8)
	if chosen:
		box.border_color = RING
		box.set_border_width_all(5)
	var pressed_box := box.duplicate() as StyleBoxFlat
	pressed_box.bg_color = PILL
	card.add_theme_stylebox_override("normal", box)
	card.add_theme_stylebox_override("hover", box)
	card.add_theme_stylebox_override("pressed", pressed_box)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var lines := VBoxContainer.new()
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = 8.0
	lines.offset_right = -8.0
	lines.offset_top = 8.0
	lines.offset_bottom = -8.0
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 4)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lines)
	card.set_meta("lines", lines)
	return card


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Two lines at most: a long route name wraps rather than shrinking to nothing.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.custom_minimum_size = Vector2(CARD_SIZE.x - 20.0, 40.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", MenuHomeDrawer.INK)
	label.add_theme_constant_override("line_spacing", -2)
	label.add_theme_font_size_override("font_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _pill(text: String, chosen: bool) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = PILL_CHOSEN if chosen else PILL
	box.set_corner_radius_all(10)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 1.0
	pill.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", MenuHomeDrawer.INK if chosen else MenuHomeDrawer.MUTED)
	label.add_theme_font_size_override("font_size", _fitted(label, text, 14, CARD_SIZE.x - 40.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(label)
	return pill


func _fitted(label: Label, text: String, wanted: int, width: float) -> int:
	var font := label.get_theme_font("font")
	if font == null:
		return wanted
	return UiStyle.fit_font_size(font, text, wanted, width, 11)
