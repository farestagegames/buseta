class_name CheatPanel
extends ColorRect
## The hidden test panel over the main menu. English only, as players never see it.

signal changed

const LEVEL_NOTE := "%s, level %d"

var _status: Label


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	color = Color(0.0, 0.0, 0.0, 0.6)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Cheats"
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 22)
	_status.add_theme_color_override("font_color", UiStyle.ACCENT)
	column.add_child(_status)

	# Each add has its take-away beside it, to undo it or test a poorer driver.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for amount: int in [1000, 10000]:
		grid.add_child(_cheat("+" + Country.pack.money(amount), Cheats.add_coins.bind(amount)))
		grid.add_child(_cheat("-" + Country.pack.money(amount), Cheats.add_coins.bind(-amount)))
	grid.add_child(_cheat("+1 level", Cheats.add_levels.bind(1)))
	grid.add_child(_cheat("-1 level", Cheats.add_levels.bind(-1)))
	grid.add_child(_cheat("+5 levels", Cheats.add_levels.bind(5)))
	grid.add_child(_cheat("-5 levels", Cheats.add_levels.bind(-5)))
	grid.add_child(_cheat("Max level", func(profile: PlayerProfile) -> void:
		Cheats.set_level(profile, Cheats.top_level(Profile.catalog, Country.pack.horns(), Profile.times_of_day()))))
	grid.add_child(_cheat("Level 1", Cheats.set_level.bind(1)))
	grid.add_child(_cheat("No money", func(profile: PlayerProfile) -> void: profile.coins = 0))
	column.add_child(grid)
	var unlock := _button("Unlock all")
	unlock.pressed.connect(_apply.bind(func(profile: PlayerProfile) -> void:
		Cheats.unlock_everything(profile, Profile.catalog, Country.pack.horns())))
	column.add_child(unlock)
	var close := _button("Close")
	close.pressed.connect(queue_free)
	column.add_child(close)
	_refresh()


func _cheat(text: String, action: Callable) -> Button:
	var button := _button(text)
	button.custom_minimum_size.x = 210.0
	button.pressed.connect(_apply.bind(action))
	return button


func _apply(action: Callable) -> void:
	action.call(Profile.data)
	Profile.save()
	_refresh()
	changed.emit()


func _refresh() -> void:
	_status.text = LEVEL_NOTE % [Country.pack.money(Profile.data.coins), DriverLevel.level_for(Profile.data.xp)]


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 76.0
	button.add_theme_font_size_override("font_size", 24)
	return button
