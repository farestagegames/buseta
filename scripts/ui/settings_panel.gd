class_name SettingsPanel
extends PanelContainer
## Settings, used from the main menu and, with shift actions, as the pause menu.

signal closed
signal tutorial_requested

## In a shift this is the pause menu. In the main menu it is just the settings.
var in_shift: bool = false

var _mode_buttons: Array[Button] = []
var language_picker: OptionButton
var cheat_row: Control
var _quality_buttons: Dictionary = {}
var _sensitivity_label: Label
var _volume_label: Label
var _cheat_taps := Cheats.new()


func _ready() -> void:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_child(outer)
	add_child(margin)

	var title := _label("Paused" if in_shift else "Settings", 32)
	outer.add_child(title)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	_add_language(box)
	_add_controls(box)
	_add_graphics(box)
	if not in_shift:
		var replay := _button("Replay tutorial")
		replay.pressed.connect(_on_replay_tutorial)
		box.add_child(replay)
	else:
		outer.add_child(_shift_actions())
		if Cheats.available():
			outer.add_child(_shift_cheats())
			title.mouse_filter = Control.MOUSE_FILTER_STOP
			title.gui_input.connect(_on_title_input)

	GameSettings.changed.connect(_refresh)
	_refresh()


func _add_controls(box: Container) -> void:
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	for entry: Array in [["Wheel", SteeringMapper.Mode.WHEEL], ["Tilt", SteeringMapper.Mode.TILT], ["Buttons", SteeringMapper.Mode.BUTTONS]]:
		var mode: SteeringMapper.Mode = entry[1]
		var button := _button(entry[0])
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: GameSettings.steering_mode = mode)
		modes.add_child(button)
		_mode_buttons.append(button)
	box.add_child(modes)

	_sensitivity_label = _label("", 22)
	box.add_child(_sensitivity_label)
	box.add_child(_slider(SteeringMapper.MIN_SENSITIVITY, SteeringMapper.MAX_SENSITIVITY, GameSettings.sensitivity,
		func(value: float) -> void: GameSettings.sensitivity = value))

	var invert := CheckButton.new()
	invert.text = "Invert tilt"
	invert.add_theme_font_size_override("font_size", 22)
	invert.custom_minimum_size.y = 60
	invert.button_pressed = GameSettings.invert_tilt
	invert.toggled.connect(func(on: bool) -> void: GameSettings.invert_tilt = on)
	box.add_child(invert)

	_volume_label = _label("", 22)
	box.add_child(_volume_label)
	box.add_child(_slider(0.0, 1.0, GameSettings.sound_volume,
		func(value: float) -> void: GameSettings.sound_volume = value))


func _add_language(box: Container) -> void:
	box.add_child(_label("Language", 22))
	language_picker = OptionButton.new()
	# Each language shows in its own script, whatever the game is set to.
	language_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_picker.get_popup().auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_picker.custom_minimum_size.y = 70.0
	language_picker.add_theme_font_size_override("font_size", 24)
	for language: Dictionary in Country.pack.languages():
		language_picker.add_item(language["name"])
	language_picker.item_selected.connect(_on_language_chosen)
	box.add_child(language_picker)


func _on_language_chosen(index: int) -> void:
	GameSettings.language = Country.pack.languages()[index]["code"]


func _add_graphics(box: Container) -> void:
	box.add_child(_label("Graphics quality", 22))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var levels := [["Auto", GraphicsQuality.AUTO], ["Low", GraphicsQuality.Level.LOW],
		["Medium", GraphicsQuality.Level.MEDIUM], ["High", GraphicsQuality.Level.HIGH]]
	for entry: Array in levels:
		var level: int = entry[1]
		var button := _button(entry[0])
		button.toggle_mode = true
		button.custom_minimum_size.x = 0.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: GameSettings.graphics_quality = level)
		row.add_child(button)
		_quality_buttons[level] = button
	box.add_child(row)
	var performance := CheckButton.new()
	performance.text = "Show performance"
	performance.add_theme_font_size_override("font_size", 22)
	performance.custom_minimum_size.y = 60
	performance.button_pressed = GameSettings.show_performance
	performance.toggled.connect(func(on: bool) -> void: GameSettings.show_performance = on)
	box.add_child(performance)


func _slider(low: float, high: float, value: float, on_change: Callable) -> HSlider:
	var slider := TouchSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size.y = 56
	slider.value_changed.connect(on_change)
	return slider


func _shift_actions() -> Control:
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	var resume := _button("Resume")
	resume.pressed.connect(func() -> void: closed.emit())
	var recover := _button("Recover bus")
	recover.pressed.connect(func() -> void:
		closed.emit()
		GameEvents.reset_requested.emit())
	var quit := _button("Quit shift")
	quit.pressed.connect(func() -> void:
		get_tree().paused = false
		Profile.save()
		get_tree().change_scene_to_file(CityShift.MENU_SCENE))
	for button: Button in [resume, recover, quit]:
		button.custom_minimum_size.x = 170.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	return actions


## Hidden until the title has been tapped seven times. English only.
func _shift_cheats() -> Control:
	cheat_row = HBoxContainer.new()
	cheat_row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	cheat_row.add_theme_constant_override("separation", 10)
	cheat_row.visible = false
	var skip := _button("Skip to next stop")
	skip.pressed.connect(func() -> void:
		closed.emit()
		GameEvents.skip_stop_requested.emit())
	var finish := _button("Finish shift")
	finish.pressed.connect(func() -> void:
		closed.emit()
		GameEvents.finish_shift_requested.emit())
	for button: Button in [skip, finish]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cheat_row.add_child(button)
	return cheat_row


func _on_title_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		if _cheat_taps.tap(Time.get_ticks_msec() / 1000.0):
			cheat_row.visible = true


func _on_replay_tutorial() -> void:
	Profile.reset_tutorial()
	tutorial_requested.emit()


func _refresh() -> void:
	for i in _mode_buttons.size():
		_mode_buttons[i].set_pressed_no_signal(i == int(GameSettings.steering_mode))
	var chosen := Lang.resolve(GameSettings.language, OS.get_locale_language())
	var languages := Country.pack.languages()
	for i in languages.size():
		if languages[i]["code"] == chosen:
			language_picker.select(i)
	for level: int in _quality_buttons:
		(_quality_buttons[level] as Button).set_pressed_no_signal(level == GameSettings.graphics_quality)
	_sensitivity_label.text = tr("Steering sensitivity: %d%%") % roundi(GameSettings.sensitivity * 100.0)
	_volume_label.text = tr("Sound volume: %d%%") % roundi(GameSettings.sound_volume * 100.0)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150.0, 70.0)
	button.add_theme_font_size_override("font_size", 24)
	return button
