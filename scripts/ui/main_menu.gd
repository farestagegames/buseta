class_name MainMenu
extends Control
## Home, Routes, Garage, Drivers, Career and Settings. Built in code from the
## catalog, so new routes, buses, liveries and drivers appear without changes here.

const SHIFT_SCENE := "res://scenes/main/city_shift.tscn"
const DRIVERS_TAB := 3
const SETTINGS_TAB := 5
const BACKGROUND := UiStyle.INK
const CARD := UiStyle.CARD
const ACCENT := UiStyle.ACCENT
const GOOD := UiStyle.GOOD
const MUTED := UiStyle.MUTED
## Space between the screen edge and the menu, in view pixels.
const EDGE := 22

var _content: Control
var _coins_label: Label
var _level_label: Label
var _level_bar: ProgressBar
var _tabs: Array[Button] = []
var _current_tab: int = 0
var _shown_locale: String = ""
var _cheat_taps := Cheats.new()
var _garage_preview: BusPreview
var _preview_note: Label
var _preview_bus: Dictionary = {}
var _preview_livery: Dictionary = {}
var _preview_decoration: Dictionary = {}
var _frame: MarginContainer
var _horn_preview: AudioStreamPlayer
var _horn_preview_left: float = 0.0
var _horn_preview_db: float = AudioDirector.BUS_HORN_DB


func _ready() -> void:
	# Back at the menu, the next shift is the chosen route again.
	Profile.route_override = ""
	var backing := ColorRect.new()
	backing.color = BACKGROUND
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backing)

	_frame = MarginContainer.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	fit_to_screen(UiStyle.screen_insets(get_viewport_rect().size))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_frame.add_child(column)
	column.add_child(_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)
	body.add_child(_navigation())
	_content = MarginContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	GameSettings.changed.connect(_on_settings_changed)
	_horn_preview = AudioStreamPlayer.new()
	_horn_preview.volume_db = AudioDirector.BUS_HORN_DB
	add_child(_horn_preview)
	show_tab(0)


## The horn preview fades over its last moment, so a looping horn ends without a
## click.
func _process(dt: float) -> void:
	if _horn_preview_left > 0.0:
		_horn_preview_left -= dt
		var fade := clampf(_horn_preview_left / HornVoice.FADE_SECONDS, 0.001, 1.0)
		_horn_preview.volume_db = _horn_preview_db + linear_to_db(fade)
		if _horn_preview_left <= 0.0:
			_horn_preview.stop()


## Keeps the tabs and the ends of every list clear of notches and rounded
## corners. Insets are left, top, right and bottom, in view pixels. Each is
## padded on both opposite edges, so turning the phone round keeps it clear.
func fit_to_screen(insets: Vector4) -> void:
	insets = UiStyle.both_ways(insets)
	var sides := {"left": insets.x, "top": insets.y, "right": insets.z, "bottom": insets.w}
	for side: String in sides:
		_frame.add_theme_constant_override("margin_" + side, EDGE + roundi(sides[side]))


## A language change re-reads every formatted line.
func _on_settings_changed() -> void:
	if TranslationServer.get_locale() != _shown_locale:
		_shown_locale = TranslationServer.get_locale()
		_refresh_header()
		if _current_tab != SETTINGS_TAB:
			show_tab(_current_tab)


func show_tab(index: int) -> void:
	# Redrawing the same tab, after buying or selecting, keeps the list where it was.
	var offset := 0
	var old_list := TouchScroll.first_in(_content)
	if index == _current_tab and old_list != null:
		offset = old_list.scroll_vertical
	_current_tab = index
	for i in _tabs.size():
		_tabs[i].button_pressed = i == index
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match index:
		0:
			_content.add_child(_home_tab())
		1:
			_content.add_child(_routes_tab())
		2:
			_content.add_child(_garage_tab())
		DRIVERS_TAB:
			_content.add_child(_drivers_tab())
		4:
			_content.add_child(_career_tab())
		_:
			var settings := SettingsPanel.new()
			settings.tutorial_requested.connect(func() -> void: show_tab(0))
			_content.add_child(settings)
	var list := TouchScroll.first_in(_content)
	if list != null:
		list.restore_offset(offset)
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
	# The game's name stays the same in every language, as it does on the phone.
	var title := _text(ProjectSettings.get_setting("application/config/name"), 36, Color.WHITE)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Cheats.available():
		title.mouse_filter = Control.MOUSE_FILTER_STOP
		title.gui_input.connect(_on_title_input)
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


func _on_title_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		if _cheat_taps.tap(Time.get_ticks_msec() / 1000.0):
			open_cheats()


func open_cheats() -> void:
	var panel := CheatPanel.new()
	panel.changed.connect(_on_cheat_used)
	add_child(panel)


func _on_cheat_used() -> void:
	show_tab(_current_tab)


func _refresh_header() -> void:
	var xp := Profile.data.xp
	_level_label.text = tr("Level %d") % DriverLevel.level_for(xp)
	_level_bar.value = DriverLevel.progress(xp)
	_coins_label.text = Country.pack.money(Profile.data.coins)


func _navigation() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size.x = 200.0
	var names := ["Home", "Routes", "Garage", "Drivers", "Career", "Settings"]
	for i in names.size():
		var tab := _button(names[i])
		tab.toggle_mode = true
		tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(show_tab.bind(i))
		column.add_child(tab)
		_tabs.append(tab)
	return column


func _home_tab() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.15
	page.add_child(column)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(side)
	var preview := BusPreview.new()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(preview)
	var route := Profile.selected_item(Catalog.ROUTES)
	var bus := Profile.selected_item(Catalog.BUSES)
	var livery := Profile.selected_item(Catalog.LIVERIES)
	var card := _card()
	var crew := HBoxContainer.new()
	crew.add_theme_constant_override("separation", 14)
	crew.add_child(_driver_button())
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_child(_wrapped(route["name"], 28, Color.WHITE))
	lines.add_child(_text("%s, %s" % [bus["name"], tr(livery["name"])], 22, MUTED))
	lines.add_child(_text(Profile.selected_item(Catalog.DRIVERS)["name"], 22, MUTED))
	lines.add_child(_text(tr("Time: %s") % tr(Profile.chosen_time().name), 22, MUTED))
	var best: int = Profile.data.best_scores.get(route["id"], -1)
	lines.add_child(_text(tr("Best score: %d") % best if best >= 0 else tr("Not driven yet"), 22, MUTED))
	crew.add_child(lines)
	card.add_child(crew)
	column.add_child(card)

	var daily_card := _card()
	var daily_lines := VBoxContainer.new()
	var today := DailyChallenge.today_key()
	var challenge := DailyChallenge.for_date(today, DailyChallenge.load_list(), Profile.data)
	var done := Profile.data.last_daily == today
	# A run carries on if yesterday's challenge was done.
	var alive := done or Profile.data.last_daily == DailyChallenge.day_before(today)
	var streak := Profile.data.daily_streak if alive else 0
	daily_lines.add_child(_text("Daily challenge", 22, ACCENT))
	daily_lines.add_child(_wrapped(challenge["text"], 24, Color.WHITE))
	var next_reward := DailyChallenge.reward_for(streak + 1)
	daily_lines.add_child(_text(tr("Done today") if done else tr("Reward: %s") % Country.pack.money(next_reward), 20, GOOD if done else MUTED))
	if streak > 0:
		daily_lines.add_child(_text(tr("%d-day streak") % streak, 20, ACCENT))
	daily_card.add_child(daily_lines)
	column.add_child(daily_card)

	var next_card := _card()
	var next_lines := VBoxContainer.new()
	next_lines.add_child(_text("Next unlock", 22, ACCENT))
	var next := Profile.next_unlock()
	if next.is_empty():
		next_lines.add_child(_wrapped(tr("All unlocked"), 24, Color.WHITE))
	else:
		next_lines.add_child(_wrapped(next_unlock_text(next), 24, Color.WHITE))
	next_card.add_child(next_lines)
	column.add_child(next_card)

	var start := _button("Start shift")
	start.custom_minimum_size.y = 110.0
	start.add_theme_font_size_override("font_size", 38)
	start.pressed.connect(_start_shift)
	side.add_child(start)
	var arcade := _arcade_button()
	if arcade != null:
		side.add_child(arcade)
	return page


## Carrera Express in one tap, without changing the chosen route. Locked below its
## level, with the best checkpoints once raced and a "New!" badge until then.
func _arcade_button() -> Button:
	var item := Profile.catalog.arcade_route()
	if item.is_empty():
		return null
	var button := _button("")
	button.name = "ArcadeButton"
	button.custom_minimum_size.y = 96.0
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", ACCENT)
	var detail := ""
	if not Profile.data.arcade_unlocked(Profile.catalog):
		detail = tr("Opens at level %d") % int(item.get("level", 1))
		button.disabled = true
	elif Profile.data.arcade_tried(Profile.catalog):
		detail = tr("Best: %d checkpoints") % int(Profile.data.best_scores.get(item["id"], 0))
	button.text = tr("Carrera Express") + ("\n" + detail if detail != "" else "")
	button.pressed.connect(start_arcade)
	if not button.disabled and not Profile.data.arcade_tried(Profile.catalog):
		var badge := _text("New!", 18, BACKGROUND)
		badge.name = "NewBadge"
		var back := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = ACCENT
		style.set_corner_radius_all(10)
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		back.add_theme_stylebox_override("panel", style)
		back.add_child(badge)
		back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		back.position = Vector2(-8.0, 6.0)
		back.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(back)
	return button


func start_arcade() -> void:
	if prepare_arcade():
		get_tree().change_scene_to_file(SHIFT_SCENE)


## Points the next shift at the arcade. False while it is still locked.
static func prepare_arcade() -> bool:
	var item := Profile.catalog.arcade_route()
	if item.is_empty() or not Profile.data.arcade_unlocked(Profile.catalog):
		return false
	if not Profile.data.owns(Catalog.ROUTES, item["id"]):
		(Profile.data.owned[Catalog.ROUTES] as Array).append(item["id"])
	Profile.route_override = item["id"]
	Profile.save()
	return true


## A short line for the next item to work towards, with what is missing.
static func next_unlock_text(info: Dictionary) -> String:
	if info.is_empty():
		return TranslationServer.translate("All unlocked")
	var name := TranslationServer.translate(str(info.get("name", "")))
	var coins_missing := int(info.get("coins_missing", 0))
	var levels_missing := int(info.get("levels_missing", 0))
	if coins_missing <= 0 and levels_missing <= 0:
		return TranslationServer.translate("%s: ready") % name
	if coins_missing > 0 and levels_missing > 0:
		return TranslationServer.translate("%s: %s more, level %d") % [name, Country.pack.money(coins_missing), int(info.get("level", 1))]
	if levels_missing > 0:
		return TranslationServer.translate("%s: level %d") % [name, int(info.get("level", 1))]
	return TranslationServer.translate("%s: %s more") % [name, Country.pack.money(coins_missing)]


## Today's driver. Tapping the portrait goes to the choice of drivers.
func _driver_button() -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(112.0, 112.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(show_tab.bind(DRIVERS_TAB))
	var badge := DriverBadge.new(CityShift.chosen_look(), 96.0)
	badge.position = Vector2(8.0, 8.0)
	button.add_child(badge)
	return button


func _start_shift() -> void:
	Profile.route_override = ""
	Profile.save()
	get_tree().change_scene_to_file(SHIFT_SCENE)


func _routes_tab() -> Control:
	var list := _list()
	list.get_child(0).add_child(_time_card())
	if Profile.difficulties().size() > 1:
		list.get_child(0).add_child(_difficulty_card())
	var routes := Profile.catalog.items(Catalog.ROUTES).filter(func(item: Dictionary) -> bool:
		return item != Profile.catalog.arcade_route()) # The arcade has its own button on Home.
	var towns := route_towns(routes)
	var town_list := town_info_list(routes)
	var chosen_town := Profile.chosen_town()
	if town_list.size() > 1:
		list.get_child(0).add_child(_town_row(town_list, chosen_town))
	for item: Dictionary in routes:
		var town: String = towns.get(item["id"], "")
		if town_list.size() > 1 and town != chosen_town:
			continue
		list.get_child(0).add_child(_shop_row(Catalog.ROUTES, item, item.get("description", "")))
	return list


func _town_row(town_list: Array[Dictionary], chosen_town: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "TownSelector"
	row.add_theme_constant_override("separation", 10)
	var player_level := DriverLevel.level_for(Profile.data.xp)
	for town: Dictionary in town_list:
		var town_name: String = town["name"]
		var lock_level: int = int(town["level"])
		var is_locked := lock_level > player_level
		var button := _button(tr(town_name))
		button.name = "Town%s" % town_name.replace(" ", "")
		button.custom_minimum_size = Vector2(0.0, 64.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_pressed = (town_name == chosen_town)
		if is_locked:
			button.tooltip_text = "🔒 %s" % (tr("Level %d") % lock_level)
			var badge := _text("🔒 %s" % (tr("Level %d") % lock_level), 16, Color.WHITE)
			badge.name = "LockBadge"
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var back := PanelContainer.new()
			back.name = "LockBadgePanel"
			back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.12, 0.14, 0.18, 0.92)
			style.set_corner_radius_all(8)
			style.content_margin_left = 8.0
			style.content_margin_right = 8.0
			style.content_margin_top = 2.0
			style.content_margin_bottom = 2.0
			back.add_theme_stylebox_override("panel", style)
			back.add_child(badge)
			back.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			back.offset_left = -10.0
			back.offset_top = 8.0
			button.add_child(back)
		button.pressed.connect(func() -> void:
			var scroll := TouchScroll.find_list(button)
			if scroll != null and scroll.taps_blocked():
				button.button_pressed = (town_name == Profile.chosen_town())
				return
			if town_name == Profile.chosen_town():
				button.button_pressed = true
				return
			Profile.choose_town(town_name)
			show_tab(_current_tab)
		)
		row.add_child(button)
	return row


## Information about each town present in the routes catalog: name, lowest route level.
## Preserves the order in which towns first appear in the routes list.
static func town_info_list(routes: Array) -> Array[Dictionary]:
	var towns_map := route_towns(routes)
	var list: Array[Dictionary] = []
	var index_by_name := {}
	for item: Dictionary in routes:
		var town_name: String = towns_map.get(item["id"], "")
		if town_name == "":
			continue
		var route_level: int = int(item.get("level", 1))
		if not index_by_name.has(town_name):
			index_by_name[town_name] = list.size()
			list.append({
				"name": town_name,
				"level": route_level,
			})
		else:
			var idx: int = index_by_name[town_name]
			list[idx]["level"] = mini(int(list[idx]["level"]), route_level)
	return list


## Route id to the name of the town (map) it runs in, so the Routes tab can group
## them under a heading once there is more than one town.
static func route_towns(routes: Array) -> Dictionary:
	var names := {}
	var towns := {}
	for item: Dictionary in routes:
		if not item.has("file"):
			continue
		var map_path := str(MapLoader.read_json(item["file"]).get("map", ""))
		if map_path == "":
			continue
		if not names.has(map_path):
			names[map_path] = str(MapLoader.read_json(Country.pack.resolve(map_path)).get("name", ""))
		towns[item["id"]] = names[map_path]
	return towns


## The time of day for the next shift. Later times open as the driver levels up.
func _time_card() -> Control:
	var card := _card()
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 10)
	lines.add_child(_text("Time of day", 24, ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var level := DriverLevel.level_for(Profile.data.xp)
	var chosen := Profile.chosen_time()
	for time in Profile.times_of_day():
		var button := _button(tr(time.name) if time.is_unlocked(level) else "%s\n%s" % [tr(time.name), tr("Level %d") % time.level])
		button.custom_minimum_size = Vector2(0.0, 76.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 22 if time.is_unlocked(level) else 18)
		button.toggle_mode = true
		button.button_pressed = time.id == chosen.id
		button.disabled = not time.is_unlocked(level)
		button.pressed.connect(_on_choose_time.bind(time))
		row.add_child(button)
	lines.add_child(row)
	if Country.pack.data.has("weather"):
		lines.add_child(_wrapped("Downpours are most likely in the afternoon", 19, MUTED))
	card.add_child(lines)
	return card


func _difficulty_card() -> Control:
	var card := _card()
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 10)
	lines.add_child(_text("Difficulty", 24, ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var chosen := Profile.chosen_difficulty()
	for difficulty in Profile.difficulties():
		var button := _button(tr(difficulty.name))
		button.custom_minimum_size = Vector2(0.0, 76.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_pressed = difficulty.id == chosen.id
		button.pressed.connect(func() -> void:
			Profile.choose_difficulty(difficulty)
			show_tab(_current_tab))
		row.add_child(button)
	lines.add_child(row)
	lines.add_child(_wrapped(_difficulty_note(chosen), 19, MUTED))
	card.add_child(lines)
	return card


## One line on what the chosen difficulty means.
func _difficulty_note(difficulty: Difficulty) -> String:
	if not difficulty.has_police():
		return tr("Mistakes cost less. Pays %d%%.") % roundi(difficulty.coin_scale * 100.0)
	if difficulty.police_ends_run:
		return tr("Transit police about: a third fine ends the run. Pays %d%%.") % roundi(difficulty.coin_scale * 100.0)
	return tr("Transit police give fines but never end the run. Pays %d%%.") % roundi(difficulty.coin_scale * 100.0)


func _on_choose_time(time: TimeOfDay) -> void:
	Profile.choose_time(time)
	show_tab(_current_tab)


func _garage_tab() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	var list := _list()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio = 1.5
	page.add_child(list)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(side)
	_garage_preview = BusPreview.new()
	_garage_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_garage_preview)
	_preview_note = _wrapped("Tap a bus, paint or decoration to try it", 20, MUTED)
	_preview_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(_preview_note)
	_preview_bus = Profile.selected_item(Catalog.BUSES)
	_preview_livery = Profile.selected_item(Catalog.LIVERIES)
	_preview_decoration = Profile.selected_item(Catalog.DECORATIONS)
	var rows := list.get_child(0)
	rows.add_child(_text("Buses", 26, ACCENT))
	for item: Dictionary in Profile.catalog.items(Catalog.BUSES):
		if not item.get("route_only", false):
			rows.add_child(_garage_row(Catalog.BUSES, item, item.get("description", "")))
	rows.add_child(_text("Liveries", 26, ACCENT))
	for item: Dictionary in Profile.catalog.items(Catalog.LIVERIES):
		rows.add_child(_garage_row(Catalog.LIVERIES, item, ""))
	if not Profile.catalog.items(Catalog.DECORATIONS).is_empty():
		rows.add_child(_text("Cab decorations", 26, ACCENT))
		for item: Dictionary in Profile.catalog.items(Catalog.DECORATIONS):
			rows.add_child(_garage_row(Catalog.DECORATIONS, item, ""))
	rows.add_child(_text("Horn", 26, ACCENT))
	Profile.data.settle_horns(Country.pack.horns())
	rows.add_child(_horn_row({}))
	for item: Dictionary in Country.pack.horns():
		rows.add_child(_horn_row(item))
	return page


## A horn to listen to and fit. An empty item is "each bus's own horn".
func _horn_row(item: Dictionary) -> Control:
	var id: String = item.get("id", "")
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var listen := _button("▶")
	listen.custom_minimum_size = Vector2(90.0, 72.0)
	listen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	listen.pressed.connect(func() -> void: preview_horn(item))
	row.add_child(listen)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if id == "":
		lines.add_child(_text("The bus's own horn", 26, Color.WHITE))
		lines.add_child(_wrapped("Each bus sounds the horn it came with", 19, MUTED))
	else:
		lines.add_child(_text(item["name"], 26, Color.WHITE))
	row.add_child(lines)
	row.add_child(_horn_button(item))
	card.add_child(row)
	# Like the bus and paint rows, a tap anywhere on the row tries it: here, a listen.
	# A tap on the button may reach the row too, which only starts the horn again.
	TouchScroll.on_tap(card, preview_horn.bind(item))
	return card


func _horn_button(item: Dictionary) -> Button:
	var id: String = item.get("id", "")
	var button := _button("")
	button.custom_minimum_size = Vector2(170.0, 72.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if Profile.data.horn == id:
		button.text = "Selected"
		button.disabled = true
	elif id == "" or Profile.data.owns_horn(id):
		button.text = "Select"
		button.pressed.connect(_on_choose_horn.bind(id))
	elif int(item.get("level", 1)) > DriverLevel.level_for(Profile.data.xp):
		button.text = tr("Level %d") % int(item["level"])
		button.disabled = true
	else:
		button.text = tr("Buy %s") % Country.pack.money(int(item.get("cost", 0)))
		button.disabled = Profile.data.coins < int(item.get("cost", 0))
		button.pressed.connect(_on_buy_horn.bind(id))
	return button


## Plays a horn once through and names it. Empty is the horn of the bus on the
## preview.
func preview_horn(item: Dictionary) -> void:
	if item.is_empty():
		item = Country.pack.bus_horn(_preview_bus)
	_preview_note.text = tr(item["name"])
	_horn_preview.stream = load(Country.pack.resolve(item["file"]))
	_horn_preview_db = AudioDirector.BUS_HORN_DB + float(item.get("volume_db", 0.0))
	_horn_preview.volume_db = _horn_preview_db
	_horn_preview.play()
	_horn_preview_left = _horn_preview.stream.get_length()


func horn_preview_playing() -> bool:
	return _horn_preview.playing


func _on_choose_horn(id: String) -> void:
	Profile.choose_horn(id)
	show_tab(_current_tab)


func _on_buy_horn(id: String) -> void:
	if Profile.buy_horn(id):
		Profile.choose_horn(id)
	show_tab(_current_tab)


## Tapping a row tries it on the preview bus, owned or not.
func _garage_row(kind: String, item: Dictionary, description: String) -> Control:
	var row := _shop_row(kind, item, description)
	TouchScroll.on_tap(row, try_on.bind(kind, item))
	return row


func try_on(kind: String, item: Dictionary) -> void:
	if kind == Catalog.BUSES:
		_preview_bus = item
	elif kind == Catalog.LIVERIES:
		_preview_livery = item
	elif kind == Catalog.DECORATIONS:
		_preview_decoration = item
	_garage_preview.show_spec(CityShift.spec_for(_preview_bus, _preview_livery), _preview_decoration)
	var decor_name := tr(_preview_decoration.get("name", "")) if not _preview_decoration.is_empty() else ""
	if decor_name != "":
		_preview_note.text = "%s, %s, %s" % [_preview_bus["name"], tr(_preview_livery["name"]), decor_name]
	else:
		_preview_note.text = "%s, %s" % [_preview_bus["name"], tr(_preview_livery["name"])]


func _drivers_tab() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	var list := _list()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio = 2.0
	page.add_child(list)
	for item: Dictionary in Profile.catalog.items(Catalog.DRIVERS):
		list.get_child(0).add_child(_shop_row(Catalog.DRIVERS, item, item["bio"]))
	var preview := DriverPreview.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(preview)
	return page


func _shop_row(kind: String, item: Dictionary, description: String) -> Control:
	var card := _card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	if item.has("body") or item.has("colour"):
		row.add_child(_swatch(item))
	if kind == Catalog.DRIVERS:
		row.add_child(DriverBadge.new(DriverLook.from_item(item)))
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_child(_text(item["name"], 26, Color.WHITE))
	if description != "":
		lines.add_child(_wrapped(description, 19, MUTED))
	if kind == Catalog.ROUTES:
		var goals := _route_goals(item)
		if not goals.is_empty():
			lines.add_child(_wrapped(_goals_text(goals), 17, MUTED))
	row.add_child(lines)
	row.add_child(_shop_button(kind, item))
	card.add_child(row)
	return card


func _route_goals(item: Dictionary) -> Array:
	if not item.has("file"):
		return []
	var data := MapLoader.read_json(item["file"])
	return data.get("goals", [])


func _goals_text(goals: Array) -> String:
	var parts: Array[String] = []
	for goal: Variant in goals:
		if goal is Dictionary:
			parts.append("• %s" % RouteGoals.text_for(goal))
	return "\n".join(parts)


func _shop_button(kind: String, item: Dictionary) -> Button:
	var id: String = item["id"]
	var button := _button("")
	button.custom_minimum_size = Vector2(170.0, 72.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var level := DriverLevel.level_for(Profile.data.xp)
	var town_name := Profile.town_for_route(item) if kind == Catalog.ROUTES else ""
	var town_level := Profile.town_lock_level(town_name) if town_name != "" else 1
	var route_level := maxi(int(item.get("level", 1)), town_level) if kind == Catalog.ROUTES else int(item.get("level", 1))
	if Profile.data.selected[kind] == id:
		button.text = "Selected"
		button.disabled = true
	elif kind == Catalog.ROUTES and route_level > level:
		button.text = tr("Level %d") % route_level
		button.disabled = true
	elif Profile.data.owns(kind, id):
		button.text = "Select"
		button.pressed.connect(_on_select.bind(kind, id))
	elif kind == Catalog.ROUTES and not Profile.catalog.requirement_met(item, Profile.data):
		var need := Profile.catalog.find(Catalog.ROUTES, Profile.catalog.requires(item))
		button.text = tr("Locked")
		button.tooltip_text = tr("Finish %s first") % tr(need.get("name", ""))
		button.disabled = true
	elif int(item.get("level", 1)) > level:
		button.text = tr("Level %d") % int(item["level"])
		button.disabled = true
	else:
		button.text = tr("Buy %s") % Country.pack.money(item["cost"])
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
	if item.has("body"):
		var body: Array = item["body"]
		var stripe: Array = item.get("stripe", item["body"])
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
	var colour: Array = item.get("colour", [0.5, 0.5, 0.5])
	var accent: Array = item.get("accent", item.get("trim", colour))
	var panel := ColorRect.new()
	panel.color = Color(colour[0], colour[1], colour[2])
	panel.custom_minimum_size = Vector2(90.0, 56.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var band := ColorRect.new()
	band.color = Color(accent[0], accent[1], accent[2])
	band.anchor_right = 1.0
	band.anchor_top = 0.5
	band.anchor_bottom = 0.5
	band.offset_top = -7.0
	band.offset_bottom = 7.0
	panel.add_child(band)
	return panel


func _career_tab() -> Control:
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
	lines.add_child(_text(tr("Downpours driven through: %d") % stats["rain_shifts"], 22, MUTED))
	card.add_child(lines)
	rows.add_child(card)
	rows.add_child(_text("Achievements", 26, ACCENT))
	for entry: Dictionary in AchievementList.load_list():
		var route := AchievementList.route_of(entry)
		if route != "" and not Profile.data.owns(Catalog.ROUTES, route) and not Profile.data.achievements.has(entry["id"]):
			continue
		var earned := Profile.data.achievements.has(entry["id"])
		var row := _card()
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_text(entry["name"], 24, GOOD if earned else Color.WHITE))
		text.add_child(_wrapped(entry["description"], 19, MUTED))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.add_child(text)
		var side := VBoxContainer.new()
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		if earned:
			side.add_child(_text("Earned", 20, GOOD))
		else:
			var target := int(entry["target"])
			var done := mini(AchievementList.progress(Profile.data, entry), target)
			side.add_child(_text(achievement_progress_text(str(entry.get("stat", "")), done, target), 20, MUTED))
			if AchievementList.reward_of(entry) > 0:
				side.add_child(_text(Country.pack.money(AchievementList.reward_of(entry)), 20, ACCENT))
		line.add_child(side)
		row.add_child(line)
		rows.add_child(row)
	return list


func _list() -> TouchScroll:
	var scroll := TouchScroll.new()
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


## "5 / 10", or for the fares stat, which counts coins, the same money the
## description names: "$552.400 / $1.000.000".
static func achievement_progress_text(stat: String, done: int, target: int) -> String:
	if stat == "fares":
		return "%s / %s" % [Country.pack.money(done), Country.pack.money(target)]
	return TranslationServer.translate("%d / %d") % [done, target]
