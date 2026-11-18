class_name MenuCartoon
extends RefCounted
## The menu's cartoon look for whole pages: white cards with a thick dark
## outline and a drop shadow, yellow for what is chosen or on offer, green for
## what is in use. [method theme] restyles every Button, CheckButton, slider,
## dropdown and label under a page, so the Garage, Achievements and Settings
## match Home without restyling each control by hand.

const INK := MenuHomeDrawer.INK
const MUTED := MenuHomeDrawer.MUTED
const GOOD := MenuHomeDrawer.GOOD
const ORANGE := MenuHomeDrawer.ORANGE
const CARD_BG := MenuHomeDrawer.CARD_BG
const YELLOW := Color("#FFC733")
const PALE := Color("#EEF0F4")
## The sheet behind a page's cards, a shade warmer than the cards.
const SHEET_BG := Color("#F4EFE4")
const OUTLINE := 3
const GAP := MenuHomeDrawer.GAP
const PAD := MenuHomeDrawer.PAD

static var _theme: Theme


## A page's backing sheet: cream, outlined, rounder than its cards.
static func sheet_box() -> StyleBoxFlat:
	return MenuHomeDrawer.card_box(SHEET_BG, 24, PAD)


## A row card inside a sheet.
static func card_box(fill: Color = CARD_BG) -> StyleBoxFlat:
	var box := MenuHomeDrawer.card_box(fill, 16, PAD)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0.0, 3.0)
	return box


## A button face: outlined, with a smaller shadow than a card.
static func button_box(fill: Color, border: Color = INK) -> StyleBoxFlat:
	var box := MenuHomeDrawer.card_box(fill, 14, 10)
	box.border_color = border
	box.shadow_size = 3
	box.shadow_offset = Vector2(0.0, 3.0)
	return box


## Gives one button its own fill, such as yellow for "Buy" or green for the one
## in use. The theme's white stays for everything else.
static func paint_button(button: Button, fill: Color, text: Color = INK) -> void:
	button.add_theme_stylebox_override("normal", button_box(fill))
	button.add_theme_stylebox_override("hover", button_box(fill.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", button_box(fill.darkened(0.12)))
	button.add_theme_stylebox_override("hover_pressed", button_box(fill.darkened(0.12)))
	button.add_theme_stylebox_override("disabled", button_box(fill, INK))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(state, text)


## A section heading: a short yellow bar and dark bold-sized text.
static func heading(text: String, font_size: int = 24) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := Panel.new()
	var bar_box := StyleBoxFlat.new()
	bar_box.bg_color = YELLOW
	bar_box.set_corner_radius_all(4)
	bar_box.set_border_width_all(2)
	bar_box.border_color = INK
	bar.add_theme_stylebox_override("panel", bar_box)
	bar.custom_minimum_size = Vector2(10.0, 28.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	row.add_child(label)
	return row


## The theme a cartoon page sets on its root. Built once.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", card_box())
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	# Buttons: white faces, yellow when pressed or toggled on, pale when disabled.
	for kind: String in ["Button", "OptionButton"]:
		t.set_stylebox("normal", kind, button_box(CARD_BG))
		t.set_stylebox("hover", kind, button_box(CARD_BG.darkened(0.03)))
		t.set_stylebox("pressed", kind, button_box(YELLOW))
		t.set_stylebox("hover_pressed", kind, button_box(YELLOW))
		t.set_stylebox("disabled", kind, button_box(PALE, MUTED))
		t.set_stylebox("focus", kind, StyleBoxEmpty.new())
		t.set_color("font_color", kind, INK)
		t.set_color("font_hover_color", kind, INK)
		t.set_color("font_pressed_color", kind, INK)
		t.set_color("font_hover_pressed_color", kind, INK)
		t.set_color("font_focus_color", kind, INK)
		t.set_color("font_disabled_color", kind, MUTED)
	# A dropdown stays white while open; the list is the yellow part.
	t.set_stylebox("pressed", "OptionButton", button_box(CARD_BG.darkened(0.03)))
	t.set_stylebox("hover_pressed", "OptionButton", button_box(CARD_BG.darkened(0.03)))
	t.set_icon("arrow", "OptionButton", UiStyle._chevron(30, INK))
	t.set_constant("arrow_margin", "OptionButton", 16)
	var popup := MenuHomeDrawer.card_box(CARD_BG, 14, 10)
	t.set_stylebox("panel", "PopupMenu", popup)
	var hover := StyleBoxFlat.new()
	hover.bg_color = YELLOW
	hover.set_corner_radius_all(10)
	hover.set_content_margin_all(6)
	t.set_stylebox("hover", "PopupMenu", hover)
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_font_size("font_size", "PopupMenu", 28)
	t.set_constant("v_separation", "PopupMenu", 24)
	t.set_constant("item_start_padding", "PopupMenu", 14)
	# Toggles: a white card row with a drawn switch.
	t.set_stylebox("normal", "CheckButton", card_box())
	t.set_stylebox("hover", "CheckButton", card_box(CARD_BG.darkened(0.03)))
	t.set_stylebox("pressed", "CheckButton", card_box())
	t.set_stylebox("hover_pressed", "CheckButton", card_box(CARD_BG.darkened(0.03)))
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "CheckButton", INK)
	t.set_icon("checked", "CheckButton", switch_texture(true))
	t.set_icon("unchecked", "CheckButton", switch_texture(false))
	t.set_icon("checked_disabled", "CheckButton", switch_texture(true))
	t.set_icon("unchecked_disabled", "CheckButton", switch_texture(false))
	# Sliders: a pale outlined track, a yellow fill and an outlined yellow knob.
	var track := StyleBoxFlat.new()
	track.bg_color = PALE
	track.set_corner_radius_all(8)
	track.set_border_width_all(2)
	track.border_color = INK
	track.set_content_margin_all(7)
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = YELLOW
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", knob_texture(36, YELLOW))
	t.set_icon("grabber_highlight", "HSlider", knob_texture(40, YELLOW.lightened(0.2)))
	t.set_icon("grabber_disabled", "HSlider", knob_texture(36, YELLOW))
	_theme = t
	return t


## A round knob with a dark outline.
static func knob_texture(size: int, colour: Color) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := float(size - 1) / 2.0
	var radius := centre
	for y in size:
		for x in size:
			var distance := Vector2(x - centre, y - centre).length()
			var alpha := clampf(radius - distance, 0.0, 1.0)
			var tone := INK if distance > radius - 3.0 else colour
			image.set_pixel(x, y, Color(tone, alpha))
	return ImageTexture.create_from_image(image)


## An on/off switch: a pill with a white knob, green when on.
static func switch_texture(on: bool) -> ImageTexture:
	var w := 68
	var h := 38
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := float(h) / 2.0 - 0.5
	var left := Vector2(r + 0.5, float(h) / 2.0 - 0.5)
	var right := Vector2(float(w) - r - 1.0, left.y)
	var knob := right if on else left
	var track := GOOD if on else Color("#C9CDD6")
	for y in h:
		for x in w:
			var p := Vector2(x, y)
			var along := clampf(p.x, left.x, right.x)
			var edge := r - p.distance_to(Vector2(along, left.y))
			if edge <= -1.0:
				continue
			var colour := INK if edge < 2.5 else track
			var knob_edge := (r - 5.0) - p.distance_to(knob)
			if knob_edge > 0.0:
				colour = INK if knob_edge < 2.0 else Color.WHITE
			image.set_pixel(x, y, Color(colour, clampf(edge + 1.0, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)
