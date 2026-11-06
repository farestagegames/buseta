class_name SettingsPanel
extends PanelContainer
## In-drive controls menu: steering mode, sensitivity and tilt direction.

signal closed

var _mode_buttons: Array[Button] = []
var _sensitivity_label: Label
var _volume_label: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_child(box)
	add_child(margin)

	box.add_child(_label("Controls", 34))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 12)
	for entry: Array in [["Wheel", SteeringMapper.Mode.WHEEL], ["Tilt", SteeringMapper.Mode.TILT], ["Buttons", SteeringMapper.Mode.BUTTONS]]:
		var mode: SteeringMapper.Mode = entry[1]
		var button := _button(entry[0])
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: GameSettings.steering_mode = mode)
		modes.add_child(button)
		_mode_buttons.append(button)
	box.add_child(modes)

	_sensitivity_label = _label("", 24)
	box.add_child(_sensitivity_label)
	var slider := HSlider.new()
	slider.min_value = SteeringMapper.MIN_SENSITIVITY
	slider.max_value = SteeringMapper.MAX_SENSITIVITY
	slider.step = 0.05
	slider.value = GameSettings.sensitivity
	slider.custom_minimum_size.y = 60
	slider.value_changed.connect(func(value: float) -> void: GameSettings.sensitivity = value)
	box.add_child(slider)

	var invert := CheckButton.new()
	invert.text = "Invert tilt"
	invert.add_theme_font_size_override("font_size", 24)
	invert.custom_minimum_size.y = 60
	invert.button_pressed = GameSettings.invert_tilt
	invert.toggled.connect(func(on: bool) -> void: GameSettings.invert_tilt = on)
	box.add_child(invert)

	_volume_label = _label("", 24)
	box.add_child(_volume_label)
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = GameSettings.sound_volume
	volume.custom_minimum_size.y = 60
	volume.value_changed.connect(func(value: float) -> void: GameSettings.sound_volume = value)
	box.add_child(volume)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	var reset := _button("Recover bus")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void:
		GameEvents.reset_requested.emit()
		closed.emit())
	var close := _button("Close")
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func() -> void: closed.emit())
	actions.add_child(reset)
	actions.add_child(close)
	box.add_child(actions)

	GameSettings.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for i in _mode_buttons.size():
		_mode_buttons[i].set_pressed_no_signal(i == int(GameSettings.steering_mode))
	_sensitivity_label.text = "Steering sensitivity: %.2f" % GameSettings.sensitivity
	_volume_label.text = "Sound volume: %d%%" % roundi(GameSettings.sound_volume * 100.0)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150.0, 76.0)
	button.add_theme_font_size_override("font_size", 26)
	return button
