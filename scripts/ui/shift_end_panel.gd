class_name ShiftEndPanel
extends PanelContainer
## End of shift report: stars, score, coins and how each category went.

const CATEGORY_NAMES := {
	"punctuality": "Punctuality", "accuracy": "Stopping accuracy", "smoothness": "Smooth driving",
	"rules": "Traffic rules", "satisfaction": "Passenger satisfaction",
}

var stars_shown: int = 0

var _stars: Label
var _headline: Label
var _coins: Label
var _bars: Dictionary = {}
var _details: Label
var _rewards: Label
var _double_coins: Button
var _coins_earned: int = 0


func _ready() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.09, 0.1, 0.13, 0.98)
	backing.set_corner_radius_all(18)
	add_theme_stylebox_override("panel", backing)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_child(box)
	add_child(margin)

	_stars = _label(44, Color(0.98, 0.72, 0.15))
	_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stars)
	_headline = _label(26, Color.WHITE)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_headline)
	_coins = _label(30, Color(0.98, 0.82, 0.3))
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_coins)
	for key: String in CATEGORY_NAMES:
		box.add_child(_category_row(key))
	_details = _label(19, Color(1, 1, 1, 0.8))
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_details)

	_rewards = _label(21, Color(0.55, 0.95, 0.65))
	_rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_rewards)

	_double_coins = _action("Watch an ad: double coins")
	_double_coins.pressed.connect(_on_double_coins)
	_double_coins.visible = false
	box.add_child(_double_coins)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	var again := _action("Drive again")
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	var menu := _action("Main menu")
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file(CityShift.MENU_SCENE))
	for button: Button in [again, menu]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	box.add_child(actions)


func _category_row(key: String) -> Control:
	var row := HBoxContainer.new()
	var name_label := _label(21, Color.WHITE)
	name_label.text = CATEGORY_NAMES[key]
	name_label.custom_minimum_size.x = 270.0
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.show_percentage = true
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 30.0
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	_bars[key] = bar
	return row


func show_report(report: Dictionary) -> void:
	stars_shown = report["stars"]
	_stars.text = "★".repeat(stars_shown) + "☆".repeat(5 - stars_shown)
	var minutes := int(report["time"]) / 60
	var seconds := int(report["time"]) % 60
	_headline.text = tr("Shift complete: %d points in %d:%02d") % [report["score"], minutes, seconds]
	_coins.text = tr("%d coins earned") % report["coins"]
	var categories: Dictionary = report["categories"]
	for key: String in _bars:
		(_bars[key] as ProgressBar).value = categories[key]
	var tip: String = report.get("tip", "")
	_details.text = "%s\n%s" % [report["details"], tip] if tip != "" else report["details"]
	var rewards: Dictionary = report["rewards"]
	_coins_earned = rewards["coins"]
	_rewards.text = _reward_lines(rewards)
	_double_coins.visible = Profile.ads.is_available()
	visible = true


func _reward_lines(rewards: Dictionary) -> String:
	var lines: Array[String] = [tr("+%d XP") % rewards["xp"]]
	if rewards["levelled_up"]:
		lines.append(tr("Level %d reached!") % rewards["level"])
	if rewards["new_best"]:
		lines.append(tr("New best score!"))
	if int(rewards["daily_coins"]) > 0:
		lines.append(tr("Daily challenge done: +%d coins") % rewards["daily_coins"])
	for entry: Dictionary in rewards["achievements"]:
		lines.append(tr("Achievement: %s") % tr(entry["name"]))
	return "   ".join(lines)


func _on_double_coins() -> void:
	_double_coins.visible = false
	Profile.ads.show_rewarded(func(earned: bool) -> void:
		if earned:
			Profile.data.coins += _coins_earned
			Profile.save()
			_coins.text = tr("%d coins earned") % (_coins_earned * 2))


func _action(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200.0, 72.0)
	button.add_theme_font_size_override("font_size", 26)
	return button


func _label(font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label
