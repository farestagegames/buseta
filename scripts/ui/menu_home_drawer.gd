class_name MenuHomeDrawer
extends VBoxContainer
## The small tray on Home: the town's Carrera Express, today's challenge and the
## next thing to unlock, as white cards in the menu's cartoon style.

const CARD_BG := Color("#FEFDFB")
const INK := Color("#22242D")
const MUTED := Color("#7A8090")
const GOOD := Color("#3FA34D")
const ORANGE := Color("#E0650A")
const SHADOW := Color(0.0, 0.0, 0.0, 0.2)
const WIDTH := 300.0
## One spacing for the whole menu (tester Claudio, 17 Nov): GAP between cards,
## rows and the things in a row, PAD inside every card, sheet and pill.
const GAP := 12
const PAD := 14

var daily_title: Label
var daily_text: Label
var daily_detail: Label
var next_text: Label


func _init() -> void:
	custom_minimum_size.x = WIDTH
	add_theme_constant_override("separation", GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var daily := _info_card("DailyCard", "star")
	daily_title = _label(16, MUTED)
	daily_text = _label(18, INK, true)
	daily_detail = _label(16, MUTED)
	for label: Label in [daily_title, daily_text, daily_detail]:
		daily.get_meta("lines").add_child(label)
	daily.set_meta("detail_label", daily_detail)
	add_child(daily)
	var next := _info_card("NextUnlockCard", "lock")
	var next_title := _label(16, MUTED)
	next_title.text = "Next unlock"
	next_text = _label(18, INK, true)
	next.get_meta("lines").add_child(next_title)
	next.get_meta("lines").add_child(next_text)
	add_child(next)


## The white card box used by every piece of the new menu.
static func card_box(fill: Color = CARD_BG, radius: int = 18, margin: int = PAD) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_border_width_all(3)
	box.border_color = INK
	box.shadow_color = SHADOW
	box.shadow_size = 6
	box.shadow_offset = Vector2(0.0, 4.0)
	box.set_content_margin_all(margin)
	return box


## Restyles the menu's ready-made Carrera Express button and puts it on top. Its
## name and children, such as the "New!" badge, stay as they are.
func add_arcade(button: Button) -> void:
	button.custom_minimum_size = Vector2(WIDTH, maxf(button.custom_minimum_size.y, 64.0))
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", card_box())
	button.add_theme_stylebox_override("hover", card_box(CARD_BG.darkened(0.03)))
	button.add_theme_stylebox_override("pressed", card_box(Color("#FFE9D6")))
	button.add_theme_stylebox_override("hover_pressed", card_box(Color("#FFE9D6")))
	button.add_theme_stylebox_override("disabled", card_box(CARD_BG.darkened(0.08)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, ORANGE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	add_child(button)
	move_child(button, 0)


func set_daily(title: String, text: String, detail: String, done: bool) -> void:
	daily_title.text = title
	daily_text.text = text
	daily_detail.text = detail
	daily_detail.add_theme_color_override("font_color", GOOD if done else MUTED)


func set_next_unlock(text: String) -> void:
	next_text.text = text


func _info_card(node_name: String, icon_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = node_name
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", card_box())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	card.add_child(row)
	var icon := MenuIcon.new()
	icon.icon = icon_name
	icon.colour = Color("#FFC733")
	icon.custom_minimum_size = Vector2(32.0, 32.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 0)
	row.add_child(lines)
	card.set_meta("lines", lines)
	return card


func _label(font_size: int, colour: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
