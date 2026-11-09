class_name ShiftEndPanel
extends PanelContainer
## End of shift report. The left column holds the result and the buttons, which
## take a fixed height. Everything that can grow sits in the scrolling part of the
## right column, so a long report can never push the buttons off the screen.

const CATEGORY_NAMES := {
	"punctuality": "Punctuality", "accuracy": "Stopping accuracy", "smoothness": "Smooth driving",
	"rules": "Traffic rules", "satisfaction": "Passenger satisfaction",
}

var stars_shown: int = 0
var menu_button: Button
var again_button: Button
var double_coins_button: Button

var _stars: Label
var _headline: Label
var _coins: Label
var _bars: Dictionary = {}
var _details: Label
var _rewards: Label
var _coins_earned: int = 0


func _ready() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.09, 0.1, 0.13, 0.98)
	backing.set_corner_radius_all(18)
	add_theme_stylebox_override("panel", backing)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	margin.add_child(columns)
	columns.add_child(_result_column())
	columns.add_child(_breakdown_column())


func _result_column() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stars = _centred(_label(52, Color(0.98, 0.72, 0.15)))
	column.add_child(_stars)
	_headline = _centred(_label(25, Color.WHITE))
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_headline)
	_coins = _centred(_label(32, Color(0.98, 0.82, 0.3)))
	column.add_child(_coins)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gap)

	double_coins_button = _action("Watch an ad: double your earnings")
	double_coins_button.pressed.connect(_on_double_coins)
	double_coins_button.visible = false
	column.add_child(double_coins_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	again_button = _action("Drive again")
	again_button.pressed.connect(func() -> void: get_tree().reload_current_scene())
	menu_button = _action("Main menu")
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
		_add_category(grid, key)
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


func _add_category(grid: GridContainer, key: String) -> void:
	var name_label := _label(21, Color.WHITE)
	name_label.text = CATEGORY_NAMES[key]
	grid.add_child(name_label)
	var bar := ProgressBar.new()
	bar.show_percentage = true
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 30.0
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(bar)
	_bars[key] = bar


func show_report(report: Dictionary) -> void:
	stars_shown = report["stars"]
	_stars.text = "★".repeat(stars_shown) + "☆".repeat(5 - stars_shown)
	var minutes := int(report["time"]) / 60
	var seconds := int(report["time"]) % 60
	_headline.text = tr("Shift complete: %d points in %d:%02d") % [report["score"], minutes, seconds]
	if str(report.get("police_stopped", "")) != "":
		_headline.text = tr("Stopped by the transit police: %d points in %d:%02d") % [report["score"], minutes, seconds]
	_coins.text = tr("%s earned") % Country.pack.money(report["coins"])
	var categories: Dictionary = report["categories"]
	for key: String in _bars:
		(_bars[key] as ProgressBar).value = categories[key]
	var tip: String = report.get("tip", "")
	_details.text = "%s\n%s" % [report["details"], tip] if tip != "" else report["details"]
	var rewards: Dictionary = report["rewards"]
	_coins_earned = rewards["coins"]
	_rewards.text = _reward_lines(rewards)
	double_coins_button.visible = Profile.ads.is_available()
	visible = true


func _reward_lines(rewards: Dictionary) -> String:
	var lines: Array[String] = [tr("+%d XP") % rewards["xp"]]
	if rewards["levelled_up"]:
		lines.append(tr("Level %d reached!") % rewards["level"])
	if rewards["new_best"]:
		lines.append(tr("New best score!"))
	if int(rewards["daily_coins"]) > 0:
		var streak := int(rewards.get("daily_streak", 1))
		if streak > 1:
			lines.append(tr("Daily challenge done: +%s (%d-day streak)") % [Country.pack.money(rewards["daily_coins"]), streak])
		else:
			lines.append(tr("Daily challenge done: +%s") % Country.pack.money(rewards["daily_coins"]))
	for entry: Dictionary in rewards["achievements"]:
		lines.append(tr("Achievement: %s") % tr(entry["name"]))
	if int(rewards.get("achievement_coins", 0)) > 0:
		lines.append(tr("Achievements: +%s") % Country.pack.money(rewards["achievement_coins"]))
	return "   ".join(lines)


func _on_double_coins() -> void:
	double_coins_button.visible = false
	Profile.ads.show_rewarded(func(earned: bool) -> void:
		if earned:
			Profile.data.coins += _coins_earned
			Profile.save()
			_coins.text = tr("%s earned") % Country.pack.money(_coins_earned * 2))


func _action(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 76.0)
	button.add_theme_font_size_override("font_size", 25)
	return button


func _centred(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _label(font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
