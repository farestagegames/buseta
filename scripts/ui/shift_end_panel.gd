class_name ShiftEndPanel
extends PanelContainer
## Celebratory end-of-shift payout. Coins count up one line at a time, stars pop
## in with their goals, the XP bar fills, the next unlock shows, then the buttons.
## A tap anywhere skips to the final state. The whole sequence is under 6 seconds.

const CATEGORY_NAMES := {
	"punctuality": "Punctuality", "accuracy": "Stopping accuracy", "smoothness": "Smooth driving",
	"rules": "Traffic rules", "satisfaction": "Passenger satisfaction",
}

const COIN_LINE_ORDER: Array[String] = ["fares", "tips", "clean", "on_time", "fines"]
const COIN_LINE_LABELS := {
	"fares": "Fares", "tips": "Tips", "clean": "Clean driving",
	"on_time": "On-time bonus", "fines": "Fines",
}
const COIN_LINE_SECONDS := 0.38
const TOTAL_LAND_SECONDS := 0.5
const STAR_SECONDS := 0.42
const XP_SECONDS := 0.55
const UNLOCK_SECONDS := 0.4
const MAX_STARS := 3
const MAX_SLOTS := 5 ## Arcade shows up to five stars.
const FAILED_COLOUR := Color(1.0, 0.42, 0.36) ## The headline when the police end the run.

var stars_shown: int = 0
var menu_button: Button
var again_button: Button
var double_coins_button: Button

var _headline: Label
var _line_labels: Dictionary = {} ## id -> value Label
var _total_label: Label
var _star_labels: Array[Label] = []
var _goal_labels: Array[Label] = []
var _xp_bar: ProgressBar
var _xp_text: Label
var _level_text: Label
var _unlock_header: Label
var _unlock_label: Label
var _unlock_bar: ProgressBar
var _bars: Dictionary = {}
var _details: Label
var _rewards: Label
var _coins_earned: int = 0

var _report: Dictionary = {}
var _breakdown: Dictionary = {}
var _goals: Array = []
var _max_stars: int = MAX_STARS
var _line_amounts: Array[int] = []
var _has_breakdown: bool = false
var _levelled_up: bool = false
var _xp_from: float = 0.0
var _xp_to: float = 0.0

var _t: float = 0.0
var _duration: float = 0.0
var _finished: bool = true
var _tick_count: int = 0
var _total_sounded: bool = false
var _stars_sounded: int = 0
var _level_sounded: bool = false


func _ready() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.09, 0.1, 0.13, 0.98)
	backing.set_corner_radius_all(18)
	add_theme_stylebox_override("panel", backing)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	margin.add_child(columns)
	columns.add_child(_result_column())
	columns.add_child(_breakdown_column())


func _result_column() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_headline = _centred(_label(21, Color.WHITE))
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_headline)

	var coins_grid := GridContainer.new()
	coins_grid.columns = 2
	coins_grid.add_theme_constant_override("h_separation", 14)
	coins_grid.add_theme_constant_override("v_separation", 1)
	for id: String in COIN_LINE_ORDER:
		var name_label := _label(18, Color(1, 1, 1, 0.85))
		name_label.text = tr(COIN_LINE_LABELS[id])
		coins_grid.add_child(name_label)
		var value := _label(18, Color.WHITE)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == "fines":
			value.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		coins_grid.add_child(value)
		_line_labels[id] = value
	var total_name := _label(22, Color(0.98, 0.82, 0.3))
	total_name.text = tr("Total")
	coins_grid.add_child(total_name)
	_total_label = _label(22, Color(0.98, 0.82, 0.3))
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coins_grid.add_child(_total_label)
	column.add_child(coins_grid)

	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 14)
	for j in MAX_SLOTS:
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 2)
		var star := _centred(_label(30, Color(0.98, 0.72, 0.15)))
		star.text = "★"
		slot.add_child(star)
		var goal := _centred(_label(13, Color(1, 1, 1, 0.8)))
		goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		goal.custom_minimum_size = Vector2(96.0, 0.0)
		slot.add_child(goal)
		stars_row.add_child(slot)
		_star_labels.append(star)
		_goal_labels.append(goal)
	column.add_child(stars_row)

	var xp_row := VBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 2)
	_level_text = _centred(_label(20, Color(0.98, 0.72, 0.15)))
	xp_row.add_child(_level_text)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size.y = 14.0
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_row.add_child(_xp_bar)
	_xp_text = _centred(_label(15, Color(1, 1, 1, 0.75)))
	xp_row.add_child(_xp_text)
	column.add_child(xp_row)

	var unlock_row := VBoxContainer.new()
	unlock_row.add_theme_constant_override("separation", 2)
	_unlock_header = _centred(_label(19, Color(0.98, 0.72, 0.15)))
	_unlock_header.text = tr("Next unlock")
	unlock_row.add_child(_unlock_header)
	_unlock_label = _centred(_label(15, Color.WHITE))
	_unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unlock_row.add_child(_unlock_label)
	_unlock_bar = ProgressBar.new()
	_unlock_bar.show_percentage = false
	_unlock_bar.custom_minimum_size.y = 10.0
	_unlock_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_row.add_child(_unlock_bar)
	column.add_child(unlock_row)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gap)

	double_coins_button = _action("Watch an ad: double your earnings")
	double_coins_button.pressed.connect(_on_double_coins)
	double_coins_button.visible = false
	column.add_child(double_coins_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	again_button = _action("Next route")
	again_button.pressed.connect(_on_main_action)
	menu_button = _action("Menu")
	menu_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(CityShift.MENU_SCENE))
	for button: Button in [again_button, menu_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	column.add_child(actions)
	return column


func _breakdown_column() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.25
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	for key: String in CATEGORY_NAMES:
		var name_label := _label(21, Color.WHITE)
		name_label.text = tr(CATEGORY_NAMES[key])
		grid.add_child(name_label)
		var bar := ProgressBar.new()
		bar.show_percentage = true
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 30.0
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		_bars[key] = bar
	column.add_child(grid)

	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 10)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rewards = _label(21, Color(0.55, 0.95, 0.65))
	_rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_rewards)
	_details = _label(20, Color(1, 1, 1, 0.8))
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_details)
	scroll.add_child(lines)
	column.add_child(scroll)
	return column


func show_report(report: Dictionary) -> void:
	_report = report
	stars_shown = int(report["stars"])
	_max_stars = MAX_SLOTS if report.has("arcade") else MAX_STARS
	_goals = report.get("goals", [])
	if not (_goals is Array):
		_goals = []
	_breakdown = report.get("coin_breakdown", {})
	_has_breakdown = _breakdown is Dictionary and not (_breakdown as Dictionary).is_empty() and not report.has("arcade")
	_line_amounts.clear()
	if _has_breakdown:
		for id: String in COIN_LINE_ORDER:
			var amount := int((_breakdown as Dictionary).get(id, 0))
			if id == "fines":
				amount = -amount
			_line_amounts.append(amount)

	var minutes := int(report["time"]) / 60
	var seconds := int(report["time"]) % 60
	_headline.text = tr("Shift complete: %d points in %d:%02d") % [report["score"], minutes, seconds]
	if report.has("arcade"):
		_headline.text = tr("Arcade: %d checkpoints, %d m") % [int(report["arcade"]["checkpoints"]), roundi(float(report["arcade"]["distance"]))]
	if report.get("gave_up", false):
		_headline.text = tr("Your passengers have had enough: %d points in %d:%02d") % [report["score"], minutes, seconds]
	_headline.add_theme_color_override("font_color", Color.WHITE)
	var police_failed := str(report.get("police_stopped", "")) != ""
	if police_failed:
		_headline.text = tr("Route failed: stopped by the police %d times") % maxi(int(report.get("police_stops", 0)), 1)
		_headline.add_theme_color_override("font_color", FAILED_COLOUR)

	var categories: Dictionary = report.get("categories", {})
	for key: String in _bars:
		(_bars[key] as ProgressBar).value = categories.get(key, 0.0)
	var detail_text: String = report.get("details", "")
	var tip: String = report.get("tip", "")
	_details.text = "%s\n%s" % [detail_text, tip] if tip != "" else detail_text
	var rewards: Dictionary = report["rewards"]
	_coins_earned = int(rewards.get("coins", int(report["coins"])))
	_rewards.text = _reward_lines(rewards)
	_levelled_up = bool(rewards.get("levelled_up", false))
	var xp_before := int(rewards.get("xp_before", 0))
	var xp_after := int(rewards.get("xp_after", xp_before + int(rewards.get("xp", 0))))
	_xp_from = 0.0 if _levelled_up else DriverLevel.progress(xp_before)
	_xp_to = DriverLevel.progress(xp_after)
	var level := int(rewards.get("level", DriverLevel.level_for(xp_after)))
	_level_text.text = tr("Level %d reached!") % level if _levelled_up else tr("Level %d") % level
	_xp_text.text = tr("+%d XP") % int(rewards.get("xp", 0))

	for j in _goal_labels.size():
		var goal_name := ""
		if j < (_goals as Array).size():
			var entry: Dictionary = (_goals as Array)[j]
			goal_name = str(entry.get("text", ""))
		_goal_labels[j].text = goal_name
	_build_unlock()

	var all_stars := stars_shown >= _max_stars
	if Profile.route_override != "" or police_failed:
		again_button.text = tr("Play again")
	else:
		again_button.text = tr("Next route") if all_stars else tr("Retry for ★★★")
	double_coins_button.visible = Profile.ads.is_available()

	_t = 0.0
	_duration = _unlock_start() + UNLOCK_SECONDS
	_finished = false
	_tick_count = 0
	_total_sounded = false
	_stars_sounded = 0
	_level_sounded = false
	_refresh()
	visible = true


func _reward_lines(rewards: Dictionary) -> String:
	var lines: Array[String] = []
	if rewards.get("new_best", false):
		lines.append(tr("New best score!"))
	if int(rewards.get("daily_coins", 0)) > 0:
		var streak := int(rewards.get("daily_streak", 1))
		if streak > 1:
			lines.append(tr("Daily challenge done: +%s (%d-day streak)") % [Country.pack.money(rewards["daily_coins"]), streak])
		else:
			lines.append(tr("Daily challenge done: +%s") % Country.pack.money(rewards["daily_coins"]))
	for entry: Dictionary in rewards.get("unlocked_routes", []):
		lines.append(tr("New route: %s") % tr(entry["name"]))
	for entry: Dictionary in rewards["achievements"]:
		lines.append(tr("Achievement: %s") % tr(entry["name"]))
	if int(rewards.get("achievement_coins", 0)) > 0:
		lines.append(tr("Achievements: +%s") % Country.pack.money(rewards["achievement_coins"]))
	return "   ".join(lines)


func _build_unlock() -> void:
	var next := Profile.next_unlock()
	if next.is_empty():
		_unlock_label.text = tr("All unlocked")
		_unlock_bar.value = 100.0
	else:
		_unlock_label.text = MainMenu.next_unlock_text(next)
		var cost := maxi(int(next.get("cost", 0)), 1)
		var missing := int(next.get("coins_missing", 0))
		_unlock_bar.value = clampf(1.0 - float(missing) / float(cost), 0.0, 1.0) * 100.0


func _total_start() -> float:
	return COIN_LINE_ORDER.size() * COIN_LINE_SECONDS if _has_breakdown else 0.0


func _stars_start() -> float:
	return _total_start() + TOTAL_LAND_SECONDS


func _xp_start() -> float:
	return _stars_start() + _max_stars * STAR_SECONDS


func _unlock_start() -> float:
	return _xp_start() + XP_SECONDS


func _process(dt: float) -> void:
	if _finished:
		return
	_t += dt
	_emit_beats()
	_refresh()
	if _t >= _duration:
		_finished = true
		_refresh()


func _emit_beats() -> void:
	for i in _line_amounts.size():
		var end := (i + 1) * COIN_LINE_SECONDS
		if _t >= end and i >= _tick_count:
			GameEvents.payout_tick.emit()
			_tick_count = i + 1
	if not _total_sounded and _t >= _total_start() + TOTAL_LAND_SECONDS:
		GameEvents.payout_total.emit()
		_total_sounded = true
	for j in _max_stars:
		var end := _stars_start() + (j + 1) * STAR_SECONDS
		if _t >= end and j >= _stars_sounded:
			GameEvents.payout_star.emit()
			_stars_sounded = j + 1
	if _levelled_up and not _level_sounded and _t >= _xp_start() + XP_SECONDS:
		GameEvents.payout_level_up.emit()
		_level_sounded = true


func _refresh() -> void:
	if _has_breakdown:
		for i in _line_amounts.size():
			var id := COIN_LINE_ORDER[i]
			var amount := _line_amounts[i]
			var start := i * COIN_LINE_SECONDS
			var progress := clampf((_t - start) / COIN_LINE_SECONDS, 0.0, 1.0)
			(_line_labels[id] as Label).text = Country.pack.money(roundi(amount * progress))
	var total := int(_report.get("coins", 0))
	var total_progress := clampf((_t - _total_start()) / TOTAL_LAND_SECONDS, 0.0, 1.0)
	_total_label.text = Country.pack.money(roundi(total * total_progress))
	for j in _star_labels.size():
		if j >= _max_stars:
			_star_labels[j].visible = false
			_goal_labels[j].visible = false
			continue
		var start := _stars_start() + j * STAR_SECONDS
		var s := clampf((_t - start) / STAR_SECONDS, 0.0, 1.0)
		var scale: float
		if s <= 0.0:
			scale = 0.0
		elif s < 0.6:
			scale = lerpf(0.0, 1.3, s / 0.6)
		else:
			scale = lerpf(1.3, 1.0, (s - 0.6) / 0.4)
		_star_labels[j].scale = Vector2.ONE * scale
		_star_labels[j].visible = scale > 0.02
		_goal_labels[j].visible = s >= 1.0
	var xp_s := clampf((_t - _xp_start()) / XP_SECONDS, 0.0, 1.0)
	_xp_bar.value = lerpf(_xp_from, _xp_to, xp_s) * 100.0
	var xp_alpha := clampf((_t - _xp_start()) / 0.15, 0.0, 1.0)
	_level_text.modulate.a = xp_alpha
	_xp_bar.modulate.a = xp_alpha
	_xp_text.modulate.a = xp_alpha
	var u_alpha := clampf((_t - _unlock_start()) / 0.15, 0.0, 1.0)
	_unlock_header.modulate.a = u_alpha
	_unlock_label.modulate.a = u_alpha
	_unlock_bar.modulate.a = u_alpha


func skip() -> void:
	if _finished:
		return
	_t = _duration
	_finished = true
	_refresh()


func is_finished() -> bool:
	return _finished


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		skip()


func _on_main_action() -> void:
	if stars_shown >= _max_stars and Profile.route_override == "":
		_next_route()
	else:
		get_tree().reload_current_scene()


func _next_route() -> void:
	var routes := Profile.catalog.items(Catalog.ROUTES)
	var current := str(Profile.selected_item(Catalog.ROUTES).get("id", ""))
	var index := -1
	for i in routes.size():
		if str((routes[i] as Dictionary).get("id", "")) == current:
			index = i
			break
	for i in range(index + 1, routes.size()):
		var id := str((routes[i] as Dictionary).get("id", ""))
		if Profile.data.can_play_route(id, Profile.catalog) and not Catalog.is_arcade(routes[i]):
			Profile.select(Catalog.ROUTES, id)
			get_tree().reload_current_scene()
			return
	get_tree().change_scene_to_file(CityShift.MENU_SCENE)


func _on_double_coins() -> void:
	double_coins_button.visible = false
	Profile.ads.show_rewarded(func(earned: bool) -> void:
		if earned:
			Profile.data.coins += _coins_earned
			Profile.save()
			_coins_earned *= 2
			_total_label.text = Country.pack.money(_coins_earned))


func _action(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 72.0)
	button.add_theme_font_size_override("font_size", 24)
	return button


func _centred(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _label(font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
