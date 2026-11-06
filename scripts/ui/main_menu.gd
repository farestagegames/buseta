class_name MainMenu
extends Control
## Home, Routes, Garage, Driver and Settings. Built in code from the catalog, so
## new routes, buses and liveries appear without any changes here.

const SHIFT_SCENE := "res://scenes/main/city_shift.tscn"
const BACKGROUND := Color(0.1, 0.12, 0.16)
const CARD := Color(0.16, 0.19, 0.24)
const ACCENT := Color(0.98, 0.72, 0.15)
const GOOD := Color(0.5, 0.95, 0.6)
const MUTED := Color(1, 1, 1, 0.65)

var _content: Control
var _coins_label: Label
var _level_label: Label
var _level_bar: ProgressBar
var _tabs: Array[Button] = []
var _current_tab: int = 0


func _ready() -> void:
	var backing := ColorRect.new()
	backing.color = BACKGROUND
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backing)

	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 22)
	add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	frame.add_child(column)
	column.add_child(_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)
	body.add_child(_navigation())
	_content = MarginContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	show_tab(0)


func show_tab(index: int) -> void:
	_current_tab = index
	for i in _tabs.size():
		_tabs[i].button_pressed = i == index
	for child in _content.get_children():
		child.queue_free()
	match index:
		0:
			_content.add_child(_home_tab())
		1:
			_content.add_child(_routes_tab())
		2:
			_content.add_child(_garage_tab())
		3:
			_content.add_child(_driver_tab())
		_:
			_content.add_child(SettingsPanel.new())
	_refresh_header()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _current_tab != 0:
			show_tab(0)
		else:
			Profile.save()
			get_tree().quit()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	var title := _text("City Bus Shift", 36, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_level_label = _text("", 24, Color.WHITE)
	row.add_child(_level_label)
	_level_bar = ProgressBar.new()
	_level_bar.show_percentage = false
	_level_bar.custom_minimum_size = Vector2(160.0, 18.0)
	_level_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level_bar.max_value = 1.0
	row.add_child(_level_bar)
	_coins_label = _text("", 28, ACCENT)
	row.add_child(_coins_label)
	return row


func _refresh_header() -> void:
	var xp := Profile.data.xp
	_level_label.text = tr("Level %d") % DriverLevel.level_for(xp)
	_level_bar.value = DriverLevel.progress(xp)
	_coins_label.text = tr("%d coins") % Profile.data.coins


func _navigation() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size.x = 200.0
	var names := ["Home", "Routes", "Garage", "Driver", "Settings"]
	for i in names.size():
		var tab := _button(names[i])
		tab.toggle_mode = true
		tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(show_tab.bind(i))
		column.add_child(tab)
		_tabs.append(tab)
	return column


func _home_tab() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	var route := Profile.selected_item(Catalog.ROUTES)
	var bus := Profile.selected_item(Catalog.BUSES)
	var livery := Profile.selected_item(Catalog.LIVERIES)
	var card := _card()
	var lines := VBoxContainer.new()
	lines.add_child(_text(route["name"], 30, Color.WHITE))
	lines.add_child(_text("%s, %s" % [bus["name"], tr(livery["name"])], 22, MUTED))
	var best: int = Profile.data.best_scores.get(route["id"], -1)
	lines.add_child(_text(tr("Best score: %d") % best if best >= 0 else tr("Not driven yet"), 22, MUTED))
	card.add_child(lines)
	column.add_child(card)

	var daily_card := _card()
	var daily_lines := VBoxContainer.new()
	var today := DailyChallenge.today_key()
	var challenge := DailyChallenge.for_date(today, DailyChallenge.load_list())
	var done := Profile.data.last_daily == today
	daily_lines.add_child(_text("Daily challenge", 22, ACCENT))
	daily_lines.add_child(_wrapped(challenge["text"], 24, Color.WHITE))
	daily_lines.add_child(_text(tr("Done today") if done else tr("Reward: %d coins") % DailyChallenge.REWARD_COINS, 20, GOOD if done else MUTED))
	daily_card.add_child(daily_lines)
	column.add_child(daily_card)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var start := _button("Start shift")
	start.custom_minimum_size.y = 110.0
	start.add_theme_font_size_override("font_size", 38)
	start.pressed.connect(_start_shift)
	column.add_child(start)
	return column


func _start_shift() -> void:
	Profile.save()
	get_tree().change_scene_to_file(SHIFT_SCENE)


func _routes_tab() -> Control:
	var list := _list()
	for item: Dictionary in Profile.catalog.items(Catalog.ROUTES):
		list.get_child(0).add_child(_shop_row(Catalog.ROUTES, item, item.get("description", "")))
	return list


func _garage_tab() -> Control:
	var list := _list()
	var rows := list.get_child(0)
	rows.add_child(_text("Buses", 26, ACCENT))
	for item: Dictionary in Profile.catalog.items(Catalog.BUSES):
		rows.add_child(_shop_row(Catalog.BUSES, item, item.get("description", "")))
	rows.add_child(_text("Liveries", 26, ACCENT))
	for item: Dictionary in Profile.catalog.items(Catalog.LIVERIES):
		rows.add_child(_shop_row(Catalog.LIVERIES, item, ""))
	return list


func _shop_row(kind: String, item: Dictionary, description: String) -> Control:
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	if item.has("body"):
		row.add_child(_swatch(item))
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_child(_text(item["name"], 26, Color.WHITE))
	if description != "":
		lines.add_child(_wrapped(description, 19, MUTED))
	row.add_child(lines)
	row.add_child(_shop_button(kind, item))
	card.add_child(row)
	return card


func _shop_button(kind: String, item: Dictionary) -> Button:
	var id: String = item["id"]
	var button := _button("")
	button.custom_minimum_size = Vector2(190.0, 76.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if Profile.data.selected[kind] == id:
		button.text = "Selected"
		button.disabled = true
	elif Profile.data.owns(kind, id):
		button.text = "Select"
		button.pressed.connect(_on_select.bind(kind, id))
	else:
		button.text = tr("Buy %d") % item["cost"]
		button.disabled = Profile.data.coins < int(item["cost"])
		button.pressed.connect(_on_buy.bind(kind, id))
	return button


func _on_select(kind: String, id: String) -> void:
	Profile.select(kind, id)
	show_tab(_current_tab)


func _on_buy(kind: String, id: String) -> void:
	if Profile.buy(kind, id):
		Profile.select(kind, id)
	show_tab(_current_tab)


func _swatch(item: Dictionary) -> Control:
	var body: Array = item["body"]
	var stripe: Array = item["stripe"]
	var panel := ColorRect.new()
	panel.color = Color(body[0], body[1], body[2])
	panel.custom_minimum_size = Vector2(90.0, 56.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var band := ColorRect.new()
	band.color = Color(stripe[0], stripe[1], stripe[2])
	band.anchor_right = 1.0
	band.anchor_top = 0.5
	band.anchor_bottom = 0.5
	band.offset_top = -5.0
	band.offset_bottom = 5.0
	panel.add_child(band)
	return panel


func _driver_tab() -> Control:
	var list := _list()
	var rows := list.get_child(0)
	var stats := Profile.data.stats
	var card := _card()
	var lines := VBoxContainer.new()
	lines.add_child(_text(tr("Level %d driver, %d XP") % [DriverLevel.level_for(Profile.data.xp), Profile.data.xp], 26, Color.WHITE))
	lines.add_child(_text(tr("Shifts completed: %d") % stats["shifts"], 22, MUTED))
	lines.add_child(_text(tr("Passengers carried: %d") % stats["passengers"], 22, MUTED))
	lines.add_child(_text(tr("Best stars: %d") % stats["best_stars"], 22, MUTED))
	lines.add_child(_text(tr("Shifts with no collisions: %d") % stats["clean_shifts"], 22, MUTED))
	card.add_child(lines)
	rows.add_child(card)
	rows.add_child(_text("Achievements", 26, ACCENT))
	for entry: Dictionary in AchievementList.load_list():
		var earned := Profile.data.achievements.has(entry["id"])
		var row := _card()
		var text := VBoxContainer.new()
		text.add_child(_text(entry["name"], 24, GOOD if earned else Color.WHITE))
		text.add_child(_text(entry["description"], 19, MUTED))
		row.add_child(text)
		rows.add_child(row)
	return list


func _list() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	return scroll


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)
	return card


func _button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 76.0
	button.add_theme_font_size_override("font_size", 26)
	return button


func _text(value: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


func _wrapped(value: String, font_size: int, colour: Color) -> Label:
	var label := _text(value, font_size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
