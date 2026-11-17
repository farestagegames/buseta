class_name MenuUnlockPopup
extends Control
## A card over the menu for one thing a shift unlocked: "Unlocked!", its picture,
## name and a line about it, and a big green button to collect it. It pops in,
## and a tap on the button sends [signal collected] and closes it.

signal collected

const CARD_WIDTH := 440.0
const ART_SIZE := Vector2(150.0, 96.0)
const BUTTON_HEIGHT := 76.0
const POP_SECONDS := 0.3

var card: PanelContainer
var collect_button: Button
var name_label: Label


## [param art] is the picture: a paint swatch, a driver's portrait or an icon.
func _init(entry: Dictionary = {}, art: Control = null) -> void:
	name = "UnlockPopup"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.09, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	card = PanelContainer.new()
	card.name = "UnlockCard"
	card.custom_minimum_size.x = CARD_WIDTH
	card.add_theme_stylebox_override("panel", MenuHomeDrawer.card_box(MenuCartoon.CARD_BG, 26, 22))
	centre.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	column.add_child(_ribbon(tr("Unlocked!")))
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame_box := MenuCartoon.card_box(Color("#FFF4D1"))
	frame_box.set_content_margin_all(14)
	frame.add_theme_stylebox_override("panel", frame_box)
	if art == null:
		art = MenuIcon.new()
		(art as MenuIcon).icon = "star"
		(art as MenuIcon).colour = MenuCartoon.YELLOW
	art.custom_minimum_size = art.custom_minimum_size.max(Vector2(ART_SIZE.y, ART_SIZE.y) if art is MenuIcon else ART_SIZE)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)
	column.add_child(frame)
	name_label = _label(tr(str(entry.get("name", ""))), 32, MenuCartoon.INK)
	column.add_child(name_label)
	var level := int(entry.get("level", 0))
	if level > 0:
		column.add_child(_label(tr("Level %d reached!") % level, 20, MenuCartoon.ORANGE))
	var about := _label(tr(str(entry.get("description", ""))), 20, MenuCartoon.MUTED)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = CARD_WIDTH - 60.0
	column.add_child(about)
	collect_button = Button.new()
	collect_button.name = "CollectButton"
	collect_button.text = "Collect"
	collect_button.custom_minimum_size = Vector2(CARD_WIDTH - 80.0, BUTTON_HEIGHT)
	collect_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	collect_button.focus_mode = Control.FOCUS_NONE
	collect_button.add_theme_font_size_override("font_size", 30)
	MenuCartoon.paint_button(collect_button, MenuCartoon.GOOD, Color.WHITE)
	collect_button.pressed.connect(_on_collect)
	column.add_child(collect_button)


func _ready() -> void:
	card.pivot_offset = card.size / 2.0
	card.resized.connect(func() -> void: card.pivot_offset = card.size / 2.0)
	card.scale = Vector2(0.6, 0.6)
	modulate.a = 0.0
	var pop := create_tween().set_parallel(true)
	pop.tween_property(self, "modulate:a", 1.0, POP_SECONDS * 0.6)
	pop.tween_property(card, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_collect() -> void:
	collect_button.disabled = true
	# Out of the tree first, so the next card can take this one's name and place.
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
	collected.emit()


func _ribbon(text: String) -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = MenuCartoon.YELLOW
	box.set_corner_radius_all(16)
	box.set_border_width_all(3)
	box.border_color = MenuCartoon.INK
	box.content_margin_left = 22.0
	box.content_margin_right = 22.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	pill.add_theme_stylebox_override("panel", box)
	pill.add_child(_label(text, 24, MenuCartoon.INK))
	return pill


func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
