class_name MainMenu
extends Control
## Home, Routes, Garage, Driver, Achievements and Settings, laid out like the
## owner's prototype: the chosen bus turns on a full-screen stage, a top bar holds
## the level, money, driver and icon buttons, a bus card sits top left, and a
## bottom tab bar opens each tab as a sheet over the stage. Built in code from the
## catalog, so new routes, buses, liveries and drivers appear without changes here.

const SHIFT_SCENE := "res://scenes/main/city_shift.tscn"
const GARAGE_TAB := 2
const DRIVERS_TAB := 3
const SETTINGS_TAB := 5
## Paint dots on the bus card.
const CARD_DOTS := 6
const BACKGROUND := UiStyle.INK
const CARD := UiStyle.CARD
const ACCENT := UiStyle.ACCENT
const GOOD := UiStyle.GOOD
const MUTED := UiStyle.MUTED
## Space between the screen edge and the menu, in view pixels.
const EDGE := 22
## The dark sheet a tab opens over the stage.
const SHEET := Color(0.09, 0.1, 0.13, 0.94)
const SHEET_OUTLINE := Color("#22242D")
## Tab labels on the bottom bar, in tab order (Settings is the gear).
const TAB_LABELS := ["Home", "Routes", "Garage", "Crew", "Achievements"]
const TAB_ICONS := ["home", "routes", "garage", "driver", "trophy"]
## Each tab icon's own cartoon colour, like the stat bars.
const TAB_COLOURS := [Color("#FF7A1A"), Color("#4D96FF"), Color("#6BCB77"), Color("#FF5C5C"), Color("#FFC733")]
## How far the stage slides left in the Garage, as a share of its width, so the
## bus stays in view beside the list.
const GARAGE_STAGE_SHIFT := 0.18 # less than before: the home camera offset already moves the bus left
## How far a new tab's sheet slides up as it fades in, and for how long.
const SLIDE_PIXELS := 24.0
const SLIDE_SECONDS := 0.25

var _content: Control
var _coins_label: Label
var _level_label: Label
var _level_bar: ProgressBar
var _tabs: Array[Button] = []
var _current_tab: int = 0
var _shown_locale: String = ""
var _cheat_taps := Cheats.new()
var _garage_preview: TurntableStage
var _preview_note: Label
var _preview_bus: Dictionary = {}
var _preview_livery: Dictionary = {}
var _preview_decoration: Dictionary = {}
var _drivers_preview: DriverPreview
var _drivers_note: Label
var _frame: MarginContainer
var _horn_preview: AudioStreamPlayer
var _horn_preview_left: float = 0.0
var _horn_preview_db: float = AudioDirector.BUS_HORN_DB
var _stage: TurntableStage
var _top_bar: MenuTopBar
var _tab_bar: MenuTabBar
var _bus_card: MenuBusCard
var _shift_button: MenuShiftButton
var _arrows: Array[Button] = []
var _volume_before_mute: float = 0.7
var _slide: Tween
var _sheet_panel: PanelContainer
## Routes and Crew show a quick-pick tray over the stage instead of their full list.
var _tray := false
var _tab_ghost: Control
## The page being built uses the cartoon card look (Garage, Achievements,
## Settings) rather than the dark sheet the Routes and Crew lists still use.
var _cartoon := false
## Off in the test run, where shifts driven by one test would leave cards over
## the next test's menu.
static var unlock_cards := true


func _ready() -> void:
	# Back at the menu, the next shift is the chosen route again.
	Profile.route_override = ""
	var backing := ColorRect.new()
	backing.color = BACKGROUND
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backing)
	_stage = TurntableStage.new()
	_stage.name = "BusStage"
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	_garage_preview = _stage

	_frame = MarginContainer.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	fit_to_screen(UiStyle.screen_insets(get_viewport_rect().size))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	_frame.add_child(column)
	column.add_child(_header())
	var middle := Control.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	_bus_card = MenuBusCard.new()
	_bus_card.name = "BusCard"
	_bus_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	middle.add_child(_bus_card)
	for side in [-1, 1]:
		middle.add_child(_arrow(side))
	_sheet_panel = PanelContainer.new()
	_sheet_panel.name = "TabSheet"
	_sheet_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	middle.add_child(_sheet_panel)
	_content = MarginContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet_panel.add_child(_content)
	column.add_child(_bottom_row())
	GameSettings.changed.connect(_on_settings_changed)
	_horn_preview = AudioStreamPlayer.new()
	_horn_preview.volume_db = AudioDirector.BUS_HORN_DB
	add_child(_horn_preview)
	show_tab(0)
	if unlock_cards:
		_show_next_unlock.call_deferred()


## One card for each thing the last shift unlocked, in turn, until all are collected.
func _show_next_unlock() -> void:
	if Profile.pending_unlocks.is_empty() or find_child("UnlockPopup", false, false) != null:
		return
	var entry: Dictionary = Profile.pending_unlocks[0]
	var popup := MenuUnlockPopup.new(entry, unlock_art(entry))
	popup.collected.connect(func() -> void:
		Profile.pending_unlocks.pop_front()
		_show_next_unlock.call_deferred())
	add_child(popup)


## The picture on an unlock card: the paint itself, the driver's face, or an icon.
func unlock_art(entry: Dictionary) -> Control:
	var kind: String = entry.get("kind", "")
	var item := Profile.catalog.find(kind, entry.get("id", "")) if kind in Catalog.KINDS else {}
	if kind == Catalog.LIVERIES and not item.is_empty():
		var was := _cartoon
		_cartoon = true
		var swatch := _swatch(item)
		_cartoon = was
		swatch.custom_minimum_size = Vector2(150.0, 96.0)
		return swatch
	if kind == Catalog.DRIVERS and not item.is_empty():
		return DriverBadge.new(DriverLook.from_item(item))
	var icon := MenuIcon.new()
	icon.icon = {Catalog.ROUTES: "routes", Catalog.BUSES: "garage", UnlockNews.HORNS: "horn"}.get(kind, "star")
	icon.colour = MenuCartoon.YELLOW
	return icon


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
	if _top_bar != null:
		_top_bar.set_muted(GameSettings.sound_volume <= 0.0)
	if TranslationServer.get_locale() != _shown_locale:
		_shown_locale = TranslationServer.get_locale()
		_rebuild_tab_bar()
		_refresh_header()
		if _current_tab != SETTINGS_TAB:
			show_tab(_current_tab, _tray)


## What a tab button opens: Routes and Crew start on their quick-pick tray. Tapping
## the tab already open goes back to Home.
func open_tab(index: int) -> void:
	if index == _current_tab and index != 0:
		show_tab(0)
		return
	show_tab(index, index == 1 or index == DRIVERS_TAB)


## Shows a tab's full page, or with [param tray] the quick picks of Routes or Crew.
func show_tab(index: int, tray: bool = false) -> void:
	tray = tray and (index == 1 or index == DRIVERS_TAB)
	# Redrawing the same tab, after buying or selecting, keeps the list where it was.
	var offset := 0
	var old_list := TouchScroll.first_in(_content)
	var same := index == _current_tab and tray == _tray
	if same and old_list != null:
		offset = old_list.scroll_vertical
	_current_tab = index
	_tray = tray
	if index < TAB_LABELS.size():
		_tab_bar.select(index, false)
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var page: Control
	_cartoon = not tray and index != 0
	if index == 0 or index == GARAGE_TAB or tray:
		_show_chosen_bus()
	match index:
		_ when tray:
			page = _quick_tray(index)
		0:
			page = _home_tab()
		1:
			page = _routes_tab()
		GARAGE_TAB:
			page = _garage_tab()
		DRIVERS_TAB:
			page = _drivers_tab()
		4:
			page = _career_tab()
		_:
			var settings := SettingsPanel.new()
			settings.cartoon = true
			settings.tutorial_requested.connect(func() -> void: show_tab(0))
			page = settings
	_content.add_child(page)
	# The stage only renders while it shows: Home and the Garage, where the bus is
	# tried on. Behind a full sheet it would cost the phone's GPU for nothing.
	var stage_shows := index == 0 or index == GARAGE_TAB or tray
	_stage.paused = not stage_shows
	# The cab close-up belongs to the Garage's decorations.
	if index != GARAGE_TAB and _stage.in_cab():
		_stage.set_view("home")
	_shift_stage(GARAGE_STAGE_SHIFT if index == GARAGE_TAB else 0.0)
	# Home and the Garage float over the stage; the other tabs sit in one sheet.
	if stage_shows:
		_sheet_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_sheet_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		_sheet_panel.add_theme_stylebox_override("panel", MenuCartoon.sheet_box() if _cartoon else sheet_box())
		_sheet_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet_panel.theme = MenuCartoon.theme() if _cartoon else null
	_bus_card.visible = stage_shows
	for arrow in _arrows:
		arrow.visible = index == 0
	if not same:
		_slide_in(_sheet_panel)
	var list := TouchScroll.first_in(_content)
	if list != null:
		list.restore_offset(offset)
	_refresh_header()


## Slides the stage sideways by a share of the screen width.
func _shift_stage(share: float) -> void:
	var target := -share * get_viewport_rect().size.x
	if is_equal_approx(_stage.offset_left, target):
		return
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_stage, "offset_left", target, SLIDE_SECONDS)
	tween.tween_property(_stage, "offset_right", target, SLIDE_SECONDS)


## A new tab's page rises a little and fades in.
func _slide_in(page: Control) -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	# Offsets rather than position: setting the position of an anchored control
	# before it is laid out would fix its width at its smallest.
	page.modulate.a = 0.0
	page.offset_top = SLIDE_PIXELS
	page.offset_bottom = SLIDE_PIXELS
	_slide = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(page, "modulate:a", 1.0, SLIDE_SECONDS)
	_slide.tween_property(page, "offset_top", 0.0, SLIDE_SECONDS)
	_slide.tween_property(page, "offset_bottom", 0.0, SLIDE_SECONDS)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _current_tab != 0:
			show_tab(0)
		else:
			Profile.save()
			get_tree().quit()


func _header() -> Control:
	_top_bar = MenuTopBar.new()
	_top_bar.name = "TopBar"
	_level_label = _top_bar.level_label
	_level_bar = _top_bar.level_bar
	_coins_label = _top_bar.coins_label
	if Cheats.available():
		_top_bar.title_label.gui_input.connect(_on_title_input)
	_top_bar.driver_pressed.connect(open_tab.bind(DRIVERS_TAB))
	_top_bar.icon_pressed.connect(_on_icon_pressed)
	_top_bar.set_muted(GameSettings.sound_volume <= 0.0)
	return _top_bar


func _on_icon_pressed(icon_name: String) -> void:
	match icon_name:
		"horn":
			preview_horn({})
		"gear":
			show_tab(SETTINGS_TAB if _current_tab != SETTINGS_TAB else 0)
		"camera":
			_stage.cycle_view()
		"sound":
			toggle_mute()
		"fullscreen":
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


## The sound button silences the game, and a second tap brings back the volume
## it had.
func toggle_mute() -> void:
	if GameSettings.sound_volume > 0.0:
		_volume_before_mute = GameSettings.sound_volume
		GameSettings.sound_volume = 0.0
	else:
		GameSettings.sound_volume = _volume_before_mute if _volume_before_mute > 0.0 else 0.7
	Profile.save()


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
	show_tab(_current_tab, _tray)


func _refresh_header() -> void:
	var xp := Profile.data.xp
	var driver := Profile.selected_item(Catalog.DRIVERS)
	_top_bar.refresh(DriverLevel.level_for(xp), DriverLevel.progress(xp), Country.pack.money(Profile.data.coins),
		str(driver.get("name", "")), CityShift.chosen_look())


## The tab bar, centred in the room left of the big orange TURNO button.
func _bottom_row() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	# A blank as wide as TURNO on the left keeps the tab bar in the middle of the
	# screen, lined up with the trays and the route chip above it.
	_tab_ghost = Control.new()
	_tab_ghost.name = "TabGhost"
	_tab_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_tab_ghost)
	row.add_child(_spacer())
	_tab_bar = MenuTabBar.new()
	_tab_bar.name = "TabBar"
	_tab_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	_tab_bar.tab_selected.connect(open_tab)
	row.add_child(_tab_bar)
	_rebuild_tab_bar()
	row.add_child(_spacer())
	_shift_button = MenuShiftButton.new()
	_shift_button.name = "ShiftButton"
	_shift_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_shift_button.pressed.connect(_start_shift)
	_shift_button.set_pulsing(true)
	row.add_child(_shift_button)
	row.resized.connect(_centre_tab_bar)
	_tab_bar.minimum_size_changed.connect(_centre_tab_bar)
	_shift_button.minimum_size_changed.connect(_centre_tab_bar)
	return row


## Sizes the left blank to TURNO's width, or less when the screen is too narrow
## for both, so the tab bar sits as near the middle as it can.
func _centre_tab_bar() -> void:
	var row := _tab_ghost.get_parent() as Control
	var gaps := 4.0 * float(row.get_theme_constant("separation"))
	_tab_ghost.custom_minimum_size.x = centred_ghost_width(row.size.x, _tab_bar.get_combined_minimum_size().x,
		_shift_button.get_combined_minimum_size().x, gaps)


## The blank's width: TURNO's own, cut down to what the row leaves free.
static func centred_ghost_width(row_width: float, bar_width: float, shift_width: float, gaps: float) -> float:
	return clampf(row_width - bar_width - shift_width - gaps, 0.0, shift_width)


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _rebuild_tab_bar() -> void:
	var items := []
	for i in TAB_LABELS.size():
		var icon := MenuIcon.new()
		icon.icon = TAB_ICONS[i]
		icon.colour = TAB_COLOURS[i]
		items.append({"label": TAB_LABELS[i], "icon": icon})
	_tab_bar.setup(items)
	_tab_bar.select(mini(_current_tab, TAB_LABELS.size() - 1), false)
	_tabs.clear()
	for i in TAB_LABELS.size():
		_tabs.append(_tab_bar.button_at(i))


## A big yellow arrow at the side of the stage that changes to the next owned bus.
func _arrow(side: int) -> Button:
	var button := Button.new()
	button.name = "NextBus" if side > 0 else "PreviousBus"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(56.0, 80.0)
	var box := MenuHomeDrawer.card_box(Color("#FFC733"), 16, 6)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", MenuHomeDrawer.card_box(Color("#E8AE1C"), 16, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := MenuIcon.new()
	icon.icon = "arrow_right" if side > 0 else "arrow_left"
	icon.colour = Color("#22242D")
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8.0
	icon.offset_right = -8.0
	button.add_child(icon)
	var preset := Control.PRESET_CENTER_RIGHT if side > 0 else Control.PRESET_CENTER_LEFT
	button.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN if side > 0 else Control.GROW_DIRECTION_END
	button.grow_vertical = Control.GROW_DIRECTION_BOTH
	button.pressed.connect(cycle_bus.bind(side))
	_arrows.append(button)
	return button


## The owned buses the arrows go through, in catalog order.
static func owned_buses() -> Array[Dictionary]:
	var buses: Array[Dictionary] = []
	for item: Dictionary in Profile.catalog.items(Catalog.BUSES):
		if not item.get("route_only", false) and Profile.data.owns(Catalog.BUSES, item["id"]):
			buses.append(item)
	return buses


## Selects the next (or previous) owned bus and shows it on the stage.
func cycle_bus(step: int) -> void:
	var buses := owned_buses()
	if buses.size() < 2:
		_stage.bump()
		return
	var chosen: String = Profile.data.selected[Catalog.BUSES]
	var at := 0
	for i in buses.size():
		if buses[i]["id"] == chosen:
			at = i
	Profile.select(Catalog.BUSES, buses[posmod(at + step, buses.size())]["id"])
	_show_chosen_bus()
	_stage.bump()


## The chosen bus on the stage and on the card.
func _show_chosen_bus() -> void:
	var bus := Profile.selected_item(Catalog.BUSES)
	var livery := Profile.selected_item(Catalog.LIVERIES)
	var spec := CityShift.spec_for(bus, livery)
	_stage.show_spec(spec, Profile.selected_item(Catalog.DECORATIONS))
	_preview_bus = bus
	_show_card(bus, livery, spec)


## The bus card for a bus and paint, chosen or only tried on in the Garage.
func _show_card(bus: Dictionary, livery: Dictionary, spec: BusSpec) -> void:
	var dots := card_dots(str(livery.get("id", "")))
	_bus_card.show_bus(str(bus["name"]), tr(bus_category(bus)), MenuBusCard.stats_for(spec), dots["colours"], dots["chosen"])


## The card's paint dots: the owned paints, at most six, with the one shown ringed.
## A paint tried on but not owned joins them, and one past the sixth takes the
## last place, so the ring always shows.
static func card_dots(livery_id: String) -> Dictionary:
	var colours: Array[Color] = []
	var chosen := -1
	var chosen_colour := Color.WHITE
	for item: Dictionary in Profile.catalog.items(Catalog.LIVERIES):
		var body: Array = item["body"]
		var colour := Color(body[0], body[1], body[2])
		if item["id"] == livery_id:
			chosen_colour = colour
			chosen = colours.size()
			colours.append(colour)
		elif Profile.data.owns(Catalog.LIVERIES, item["id"]):
			colours.append(colour)
	if chosen >= CARD_DOTS:
		colours.remove_at(chosen)
		colours.insert(CARD_DOTS - 1, chosen_colour)
		chosen = CARD_DOTS - 1
	return {"colours": colours.slice(0, CARD_DOTS), "chosen": chosen}


## A one-word kind of bus for the card's tag, from its size.
static func bus_category(bus: Dictionary) -> String:
	var spec := load(Country.pack.resolve(bus["file"])) as BusSpec if bus.has("file") else null
	if spec == null:
		return "Buseta"
	if spec.body_style == "chiva":
		return "Chiva"
	var length := spec.full_length()
	if length > 15.0:
		return "Articulated"
	if length > 10.5:
		return "Bus"
	if length > 8.5:
		return "Midibus"
	return "Buseta"


## A tab's content in a dark rounded sheet over the stage.
func _sheet(inner: Control) -> Control:
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", MenuCartoon.sheet_box() if _cartoon else sheet_box())
	sheet.add_child(inner)
	return sheet


static func sheet_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = SHEET
	box.set_corner_radius_all(22)
	box.set_border_width_all(3)
	box.border_color = SHEET_OUTLINE
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0.0, 4.0)
	box.set_content_margin_all(16)
	return box


func _home_tab() -> Control:
	var page := Control.new()
	page.name = "HomePage"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var drawer := MenuHomeDrawer.new()
	drawer.name = "HomeDrawer"
	drawer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	drawer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	drawer.offset_right = -72.0 # clear of the side arrow
	drawer.offset_left = drawer.offset_right - MenuHomeDrawer.WIDTH
	page.add_child(drawer)
	var arcade := _arcade_button()
	if arcade != null:
		drawer.add_arcade(arcade)
	var today := DailyChallenge.today_key()
	var challenge := DailyChallenge.for_date(today, DailyChallenge.load_list(), Profile.data)
	var done := Profile.data.last_daily == today
	# A run carries on if yesterday's challenge was done.
	var alive := done or Profile.data.last_daily == DailyChallenge.day_before(today)
	var streak := Profile.data.daily_streak if alive else 0
	var detail := tr("Done today") if done else tr("Reward: %s") % Country.pack.money(DailyChallenge.reward_for(streak + 1))
	if streak > 0:
		detail += " · " + tr("%d-day streak") % streak
	drawer.set_daily(tr("Daily challenge"), tr(challenge["text"]), detail, done)
	drawer.set_next_unlock(next_unlock_text(Profile.next_unlock()))

	var route := Profile.selected_item(Catalog.ROUTES)
	var chip := MenuRouteChip.new()
	chip.name = "RouteChip"
	var best: int = Profile.data.best_scores.get(route["id"], -1)
	chip.show_route(tr(route["name"]), tr(Profile.chosen_time().name), tr("Best score: %d") % best if best >= 0 else tr("Not driven yet"))
	chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	chip.pressed.connect(open_tab.bind(1))
	page.add_child(chip)
	return page


## The quick picks of Routes or Crew in a row over the stage, above the tab bar.
func _quick_tray(index: int) -> Control:
	var page := Control.new()
	page.name = "QuickPage"
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray := MenuQuickTray.new()
	tray.name = "QuickTray"
	if index == 1:
		_fill_route_tray(tray)
	else:
		_fill_driver_tray(tray)
	tray.more_pressed.connect(show_tab.bind(index))
	tray.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	tray.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tray.grow_vertical = Control.GROW_DIRECTION_BEGIN
	page.add_child(tray)
	return page


## The owned routes of the chosen town, best score on each.
func _fill_route_tray(tray: MenuQuickTray) -> void:
	var routes := Profile.catalog.items(Catalog.ROUTES).filter(func(item: Dictionary) -> bool:
		return not Catalog.is_arcade(item))
	var towns := route_towns(routes)
	var town := Profile.chosen_town()
	var ids := []
	for item: Dictionary in routes:
		if Profile.data.owns(Catalog.ROUTES, item["id"]) and towns.get(item["id"], "") == town:
			ids.append(item["id"])
	var chosen: String = Profile.data.selected[Catalog.ROUTES]
	for id: String in MenuQuickTray.window(ids, chosen):
		var item := Profile.catalog.find(Catalog.ROUTES, id)
		var best: int = Profile.data.best_scores.get(id, -1)
		var detail := tr("Best score: %d") % best if best >= 0 else tr("Not driven yet")
		var icon := MenuIcon.new()
		icon.icon = "routes"
		icon.colour = TAB_COLOURS[1]
		tray.add_pick(id, tr(item["name"]), detail, icon, id == chosen)
	tray.add_more(tr("All routes"), "routes")
	tray.picked.connect(func(id: String) -> void:
		Profile.select(Catalog.ROUTES, id)
		show_tab(1, true))


## The owned drivers, the one at the wheel marked.
func _fill_driver_tray(tray: MenuQuickTray) -> void:
	var ids := []
	for item: Dictionary in Profile.catalog.items(Catalog.DRIVERS):
		if Profile.data.owns(Catalog.DRIVERS, item["id"]):
			ids.append(item["id"])
	var chosen: String = Profile.data.selected[Catalog.DRIVERS]
	for id: String in MenuQuickTray.window(ids, chosen):
		var item := Profile.catalog.find(Catalog.DRIVERS, id)
		var badge := DriverBadge.new(DriverLook.from_item(item), MenuQuickTray.ART)
		tray.add_pick(id, MenuTopBar.short_name(str(item["name"])), tr("Selected") if id == chosen else tr("Select"), badge, id == chosen)
	tray.add_more(tr("All drivers"), "driver")
	tray.picked.connect(func(id: String) -> void:
		Profile.select(Catalog.DRIVERS, id)
		_refresh_header()
		show_tab(DRIVERS_TAB, true))


## Carrera Express in one tap, without changing the chosen route. Locked below its
## level, with the best checkpoints once raced and a "New!" badge until then.
func _arcade_button() -> Button:
	var town := Profile.chosen_town()
	var item := Profile.catalog.arcade_route(town)
	if item.is_empty():
		return null
	var button := _button("")
	button.name = "ArcadeButton"
	button.custom_minimum_size.y = 96.0
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", ACCENT)
	var detail := ""
	if not Profile.data.arcade_unlocked(Profile.catalog, town):
		detail = tr("Opens at level %d") % int(item.get("level", 1))
		button.disabled = true
	elif Profile.data.arcade_tried(Profile.catalog, town):
		detail = tr("Best: %d checkpoints") % int(Profile.data.best_scores.get(item["id"], 0))
	# With an arcade in more than one town, the button names the one it races.
	if Profile.catalog.arcade_routes().size() > 1 and town != "":
		detail = tr(town) + (" · " + detail if detail != "" else "")
	button.text = tr("Carrera Express") + ("\n" + detail if detail != "" else "")
	button.pressed.connect(start_arcade)
	if not button.disabled and not Profile.data.arcade_tried(Profile.catalog, town):
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


## Points the next shift at the arcade of the town picked on the Routes tab.
## False while it is still locked.
static func prepare_arcade() -> bool:
	var town := Profile.chosen_town()
	var item := Profile.catalog.arcade_route(town)
	if item.is_empty() or not Profile.data.arcade_unlocked(Profile.catalog, town):
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
		return not Catalog.is_arcade(item)) # Each town's arcade has its own button on Home.
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
			var badge := _text("🔒 %s" % (tr("Level %d") % lock_level), 16, _ink() if _cartoon else Color.WHITE)
			badge.name = "LockBadge"
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var back := PanelContainer.new()
			back.name = "LockBadgePanel"
			back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := StyleBoxFlat.new()
			style.bg_color = MenuCartoon.PALE if _cartoon else Color(0.12, 0.14, 0.18, 0.92)
			style.set_corner_radius_all(8)
			if _cartoon:
				style.set_border_width_all(2)
				style.border_color = MenuCartoon.INK
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
	lines.add_child(_card_heading("Time of day"))
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
		lines.add_child(_wrapped("Downpours are most likely in the afternoon", 19, _soft()))
	card.add_child(lines)
	return card


func _difficulty_card() -> Control:
	var card := _card()
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 10)
	lines.add_child(_card_heading("Difficulty"))
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
	lines.add_child(_wrapped(_difficulty_note(chosen), 19, _soft()))
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
	# The bus on the stage is the preview: the list sits in a sheet on the right.
	var page := HBoxContainer.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_theme_constant_override("separation", 16)
	var side := VBoxContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.alignment = BoxContainer.ALIGNMENT_END
	page.add_child(side)
	var list := _list()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sheet := _sheet(list)
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.size_flags_stretch_ratio = 1.25
	page.add_child(sheet)
	_preview_note = _wrapped("Tap a bus, paint or decoration to try it", 20, MenuCartoon.INK)
	_preview_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var note_back := PanelContainer.new()
	note_back.name = "PreviewNote"
	note_back.add_theme_stylebox_override("panel", MenuHomeDrawer.card_box())
	note_back.add_child(_preview_note)
	note_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(note_back)
	_preview_bus = Profile.selected_item(Catalog.BUSES)
	_preview_livery = Profile.selected_item(Catalog.LIVERIES)
	_preview_decoration = Profile.selected_item(Catalog.DECORATIONS)
	var rows := list.get_child(0)
	rows.add_child(_heading("Buses"))
	for item: Dictionary in Profile.catalog.items(Catalog.BUSES):
		if not item.get("route_only", false):
			rows.add_child(_garage_row(Catalog.BUSES, item, item.get("description", "")))
	rows.add_child(_heading("Liveries"))
	for item: Dictionary in Profile.catalog.items(Catalog.LIVERIES):
		rows.add_child(_garage_row(Catalog.LIVERIES, item, ""))
	if not Profile.catalog.items(Catalog.DECORATIONS).is_empty():
		rows.add_child(_heading("Cab decorations"))
		for item: Dictionary in Profile.catalog.items(Catalog.DECORATIONS):
			rows.add_child(_garage_row(Catalog.DECORATIONS, item, ""))
	rows.add_child(_heading("Horn"))
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
		lines.add_child(_text("The bus's own horn", 26, _ink()))
		lines.add_child(_wrapped("Each bus sounds the horn it came with", 19, _soft()))
	else:
		lines.add_child(_text(item["name"], 26, _ink()))
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
		_paint_in_use(button)
	elif id == "" or Profile.data.owns_horn(id):
		button.text = "Select"
		button.pressed.connect(_on_choose_horn.bind(id))
	elif int(item.get("level", 1)) > DriverLevel.level_for(Profile.data.xp):
		button.text = tr("Level %d") % int(item["level"])
		button.disabled = true
	else:
		button.text = tr("Buy %s") % Country.pack.money(int(item.get("cost", 0)))
		button.disabled = Profile.data.coins < int(item.get("cost", 0))
		_paint_buy(button)
		button.pressed.connect(_on_buy_horn.bind(id))
	return button


## Plays a horn once through and names it. Empty is the horn of the bus on the
## preview.
func preview_horn(item: Dictionary) -> void:
	if item.is_empty():
		item = Country.pack.bus_horn(_preview_bus)
	if is_instance_valid(_preview_note):
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
	var spec := CityShift.spec_for(_preview_bus, _preview_livery)
	_garage_preview.show_spec(spec, _preview_decoration)
	_show_card(_preview_bus, _preview_livery, spec)
	# Decorations sit inside the cab, so the stage looks in from the driver's seat.
	if kind == Catalog.DECORATIONS:
		_stage.set_view(TurntableStage.CAB_VIEW)
	elif _stage.in_cab():
		_stage.set_view("home")
	var decor_name := tr(_preview_decoration.get("name", "")) if not _preview_decoration.is_empty() else ""
	if kind == Catalog.DECORATIONS:
		_preview_note.text = "%s\n%s" % [tr(item.get("name", "")), tr("Decorations go in the cab: you see them in cockpit view while driving")]
	elif decor_name != "":
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
		list.get_child(0).add_child(_driver_row(item))
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(side)
	_drivers_preview = DriverPreview.new()
	_drivers_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_drivers_preview)
	_drivers_note = _wrapped("", 20, _soft())
	_drivers_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The name sits in a white card under the bust.
	var note_card := _card()
	note_card.add_child(_drivers_note)
	side.add_child(note_card)
	show_driver_note(Profile.selected_item(Catalog.DRIVERS))
	return page


## Tapping a driver row shows them in the preview, owned or not, without buying.
func _driver_row(item: Dictionary) -> Control:
	var row := _shop_row(Catalog.DRIVERS, item, item["bio"])
	TouchScroll.on_tap(row, try_on_driver.bind(item))
	return row


## Shows a driver on the stand and names them, without spending coins or selecting.
func try_on_driver(item: Dictionary) -> void:
	_drivers_preview.show_look(DriverLook.from_item(item))
	show_driver_note(item)


## Names the driver shown, with the price or level while they are not owned.
func show_driver_note(item: Dictionary) -> void:
	if Profile.data.owns(Catalog.DRIVERS, item["id"]):
		_drivers_note.text = item["name"]
		return
	var level := DriverLevel.level_for(Profile.data.xp)
	var detail := ""
	if int(item.get("level", 1)) > level:
		detail = tr("Level %d") % int(item["level"])
	else:
		detail = Country.pack.money(int(item.get("cost", 0)))
	_drivers_note.text = tr("%s · %s") % [item["name"], detail]


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
	lines.add_child(_text(item["name"], 26, _ink()))
	if description != "":
		lines.add_child(_wrapped(description, 19, _soft()))
	if kind == Catalog.ROUTES:
		var goals := _route_goals(item)
		if not goals.is_empty():
			lines.add_child(_wrapped(_goals_text(goals), 17, _soft()))
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
		_paint_in_use(button)
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
		_paint_buy(button)
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
		_outline(panel)
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
	_outline(panel)
	return panel


## A dark outline round a paint swatch on the cartoon cards.
func _outline(swatch: Control) -> void:
	if not _cartoon:
		return
	var frame := Panel.new()
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.set_border_width_all(3)
	box.border_color = MenuCartoon.INK
	box.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", box)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.add_child(frame)


func _career_tab() -> Control:
	var list := _list()
	var rows := list.get_child(0)
	var stats := Profile.data.stats
	var card := _card()
	card.name = "CareerCard"
	var lines := VBoxContainer.new()
	lines.add_child(_text(tr("Level %d driver, %d XP") % [DriverLevel.level_for(Profile.data.xp), Profile.data.xp], 26, _ink()))
	var facts := GridContainer.new()
	facts.columns = 2
	facts.add_theme_constant_override("h_separation", 28)
	facts.add_child(_text(tr("Shifts completed: %d") % stats["shifts"], 22, _soft()))
	facts.add_child(_text(tr("Passengers carried: %d") % stats["passengers"], 22, _soft()))
	facts.add_child(_text(tr("Best stars: %d") % stats["best_stars"], 22, _soft()))
	facts.add_child(_text(tr("Shifts with no collisions: %d") % stats["clean_shifts"], 22, _soft()))
	facts.add_child(_text(tr("Downpours driven through: %d") % stats["rain_shifts"], 22, _soft()))
	lines.add_child(facts)
	card.add_child(lines)
	rows.add_child(card)
	rows.add_child(_heading("Achievements"))
	for entry: Dictionary in AchievementList.load_list():
		var route := AchievementList.route_of(entry)
		if route != "" and not Profile.data.owns(Catalog.ROUTES, route) and not Profile.data.achievements.has(entry["id"]):
			continue
		var earned := Profile.data.achievements.has(entry["id"])
		var row := _card()
		if earned:
			row.add_theme_stylebox_override("panel", MenuCartoon.card_box(Color("#F1FAEF")))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		var badge := MenuIcon.new()
		badge.icon = "trophy"
		badge.colour = MenuCartoon.YELLOW if earned else Color("#C9CDD6")
		badge.custom_minimum_size = Vector2(40.0, 40.0)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(badge)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_text(entry["name"], 24, _ink()))
		text.add_child(_wrapped(entry["description"], 19, _soft()))
		line.add_child(text)
		var side := VBoxContainer.new()
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		side.custom_minimum_size.x = 170.0
		if earned:
			side.add_child(_pill(tr("Earned"), MenuCartoon.GOOD, Color.WHITE))
		else:
			var target := int(entry["target"])
			var done := mini(AchievementList.progress(Profile.data, entry), target)
			var count := _text(achievement_progress_text(str(entry.get("stat", "")), done, target), 20, _soft())
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			side.add_child(count)
			side.add_child(_progress(done, target))
			if AchievementList.reward_of(entry) > 0:
				side.add_child(_pill(Country.pack.money(AchievementList.reward_of(entry)), MenuCartoon.YELLOW, MenuCartoon.INK))
		line.add_child(side)
		row.add_child(line)
		rows.add_child(row)
	return list


## A small rounded tag, such as "Earned" or a reward.
func _pill(value: String, fill: Color, colour: Color) -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(12)
	box.set_border_width_all(2)
	box.border_color = MenuCartoon.INK
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	pill.add_theme_stylebox_override("panel", box)
	pill.add_child(_text(value, 20, colour))
	return pill


## A thin outlined bar for progress towards an achievement.
func _progress(done: int, target: int) -> Control:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxi(target, 1)
	bar.value = done
	bar.custom_minimum_size = Vector2(150.0, 14.0)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var back := StyleBoxFlat.new()
	back.bg_color = MenuCartoon.PALE
	back.set_corner_radius_all(7)
	back.set_border_width_all(2)
	back.border_color = MenuCartoon.INK
	var fill := StyleBoxFlat.new()
	fill.bg_color = MenuCartoon.YELLOW
	fill.set_corner_radius_all(7)
	fill.set_border_width_all(2)
	fill.border_color = MenuCartoon.INK
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _list() -> TouchScroll:
	var scroll := TouchScroll.new()
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	return scroll


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	if _cartoon:
		card.add_theme_stylebox_override("panel", MenuCartoon.card_box())
		return card
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)
	return card


## Title text: dark on the cartoon cards, white on the dark sheet.
func _ink() -> Color:
	return MenuCartoon.INK if _cartoon else Color.WHITE


func _soft() -> Color:
	return MenuCartoon.MUTED if _cartoon else MUTED


func _good() -> Color:
	return MenuCartoon.GOOD if _cartoon else GOOD


## A heading inside a card, such as "Time of day".
func _card_heading(value: String) -> Control:
	return MenuCartoon.heading(value, 24) if _cartoon else _text(value, 24, ACCENT)


func _heading(value: String) -> Control:
	return MenuCartoon.heading(value, 26) if _cartoon else _text(value, 26, ACCENT)


## The item in use: green on the cartoon pages.
func _paint_in_use(button: Button) -> void:
	if _cartoon:
		MenuCartoon.paint_button(button, MenuCartoon.GOOD, Color.WHITE)


## Something to buy: yellow on the cartoon pages, unless it costs too much.
func _paint_buy(button: Button) -> void:
	if _cartoon and not button.disabled:
		MenuCartoon.paint_button(button, MenuCartoon.YELLOW)


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
