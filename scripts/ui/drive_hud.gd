class_name DriveHud
extends CanvasLayer
## Lays out the driving controls for two thumbs in landscape: steering on the
## left, pedals on the right, secondary buttons just above each thumb's home.
## Every control only emits GameEvents. The HUD never touches the bus.

const EDGE := 24.0
const GAP := 16.0

var wheel: SteeringWheelControl
var throttle_pedal: PedalControl
var brake_pedal: PedalControl
var left_button: TouchButton
var right_button: TouchButton
var settings_panel: SettingsPanel

var _controls: Control
var _tilt_hint: Label
var _indicator_left: TouchButton
var _indicator_right: TouchButton
var _door_button: TouchButton
var _gear_button: TouchButton
var _frame_rate: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_apply_safe_area(root)

	_controls = Control.new()
	_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_controls)

	_build_steering()
	_build_pedals()
	_build_buttons()

	var gauge := HudGauge.new()
	_place(gauge, Vector2(0.5, 0.0), Vector2(-190.0, 8.0), Vector2(380.0, 112.0))
	root.add_child(gauge)

	_frame_rate = Label.new()
	_frame_rate.add_theme_font_size_override("font_size", 18)
	_place(_frame_rate, Vector2(1.0, 0.0), Vector2(-90.0, 8.0), Vector2(80.0, 24.0))
	root.add_child(_frame_rate)

	settings_panel = SettingsPanel.new()
	settings_panel.visible = false
	settings_panel.closed.connect(_close_settings)
	_place(settings_panel, Vector2(0.5, 0.5), Vector2(-300.0, -280.0), Vector2(600.0, 560.0))
	root.add_child(settings_panel)

	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameSettings.changed.connect(_apply_mode)
	_apply_mode()


func _process(_dt: float) -> void:
	_frame_rate.text = "%d fps" % Engine.get_frames_per_second()


func _build_steering() -> void:
	wheel = SteeringWheelControl.new()
	_place(wheel, Vector2(0.0, 1.0), Vector2(EDGE, -EDGE - 320.0), Vector2(320.0, 320.0))
	_controls.add_child(wheel)

	left_button = _steer_button("◀", 0.0)
	right_button = _steer_button("▶", 190.0)
	var send := func() -> void:
		GameEvents.ui_steer_buttons_changed.emit(left_button.is_touched(), right_button.is_touched())
	for button: TouchButton in [left_button, right_button]:
		button.pressed_down.connect(send)
		button.released.connect(send)

	_tilt_hint = Label.new()
	_tilt_hint.text = "Tilt the phone to steer"
	_tilt_hint.add_theme_font_size_override("font_size", 22)
	_place(_tilt_hint, Vector2(0.0, 1.0), Vector2(EDGE, -EDGE - 40.0), Vector2(320.0, 40.0))
	_controls.add_child(_tilt_hint)


func _steer_button(text: String, x: float) -> TouchButton:
	var button := TouchButton.new()
	button.text = text
	button.font_size = 58
	_place(button, Vector2(0.0, 1.0), Vector2(EDGE + x, -EDGE - 210.0), Vector2(176.0, 210.0))
	_controls.add_child(button)
	return button


func _build_pedals() -> void:
	throttle_pedal = PedalControl.new()
	throttle_pedal.label = "GO"
	throttle_pedal.colour = Color(0.2, 0.75, 0.35)
	_place(throttle_pedal, Vector2(1.0, 1.0), Vector2(-EDGE - 150.0, -EDGE - 340.0), Vector2(150.0, 340.0))
	_controls.add_child(throttle_pedal)

	brake_pedal = PedalControl.new()
	brake_pedal.label = "BRAKE"
	brake_pedal.colour = Color(0.9, 0.22, 0.2)
	_place(brake_pedal, Vector2(1.0, 1.0), Vector2(-EDGE - 150.0 - GAP - 200.0, -EDGE - 230.0), Vector2(200.0, 230.0))
	_controls.add_child(brake_pedal)

	var send := func(_value: float) -> void:
		GameEvents.ui_pedals_changed.emit(throttle_pedal.value, brake_pedal.value)
	throttle_pedal.value_changed.connect(send)
	brake_pedal.value_changed.connect(send)


func _build_buttons() -> void:
	var camera := _action_button("VIEW", Vector2(0.0, 0.0), Vector2(EDGE, EDGE), Vector2(130.0, 96.0))
	camera.pressed_down.connect(GameEvents.camera_cycle_requested.emit)
	var menu := _action_button("MENU", Vector2(0.0, 0.0), Vector2(EDGE + 146.0, EDGE), Vector2(130.0, 96.0))
	menu.pressed_down.connect(_open_settings)

	_indicator_left = _action_button("◀ IND", Vector2(0.0, 1.0), Vector2(EDGE, -EDGE - 320.0 - GAP - 96.0), Vector2(150.0, 96.0))
	_indicator_right = _action_button("IND ▶", Vector2(0.0, 1.0), Vector2(EDGE + 166.0, -EDGE - 320.0 - GAP - 96.0), Vector2(150.0, 96.0))
	_indicator_left.lit_colour = Color(0.95, 0.6, 0.1, 0.95)
	_indicator_right.lit_colour = Color(0.95, 0.6, 0.1, 0.95)
	_indicator_left.pressed_down.connect(func() -> void: GameEvents.indicator_toggle_requested.emit(BusIndicators.TurnSide.LEFT))
	_indicator_right.pressed_down.connect(func() -> void: GameEvents.indicator_toggle_requested.emit(BusIndicators.TurnSide.RIGHT))

	var above_pedals := -EDGE - 340.0 - GAP - 100.0
	_door_button = _action_button("DOORS", Vector2(1.0, 1.0), Vector2(-EDGE - 150.0, above_pedals), Vector2(150.0, 100.0))
	_door_button.pressed_down.connect(GameEvents.door_toggle_requested.emit)
	var horn := _action_button("HORN", Vector2(1.0, 1.0), Vector2(-EDGE - 150.0 - GAP - 200.0, above_pedals), Vector2(200.0, 100.0))
	horn.pressed_down.connect(func() -> void: GameEvents.horn_changed.emit(true))
	horn.released.connect(func() -> void: GameEvents.horn_changed.emit(false))
	_gear_button = _action_button("D / R", Vector2(1.0, 1.0), Vector2(-EDGE - 150.0 - GAP - 200.0, -EDGE - 230.0 - GAP - 94.0), Vector2(200.0, 94.0))
	_gear_button.pressed_down.connect(GameEvents.gear_toggle_requested.emit)


func _action_button(text: String, anchor: Vector2, offset: Vector2, button_size: Vector2) -> TouchButton:
	var button := TouchButton.new()
	button.text = text
	_place(button, anchor, offset, button_size)
	_controls.add_child(button)
	return button


func _place(control: Control, anchor: Vector2, offset: Vector2, control_size: Vector2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = offset.x
	control.offset_top = offset.y
	control.offset_right = offset.x + control_size.x
	control.offset_bottom = offset.y + control_size.y


func _apply_mode() -> void:
	var mode := GameSettings.steering_mode
	wheel.visible = mode == SteeringMapper.Mode.WHEEL
	left_button.visible = mode == SteeringMapper.Mode.BUTTONS
	right_button.visible = mode == SteeringMapper.Mode.BUTTONS
	_tilt_hint.visible = mode == SteeringMapper.Mode.TILT


func _open_settings() -> void:
	_controls.visible = false
	settings_panel.visible = true
	GameEvents.ui_pedals_changed.emit(0.0, 1.0) # Hold the bus while in the menu.


func _close_settings() -> void:
	settings_panel.visible = false
	_controls.visible = true
	GameEvents.ui_pedals_changed.emit(0.0, 0.0)


func _on_telemetry(data: BusTelemetry) -> void:
	var left_on := data.indicator_side < 0 and data.indicator_lamp_on
	var right_on := data.indicator_side > 0 and data.indicator_lamp_on
	if _indicator_left.lit != left_on:
		_indicator_left.lit = left_on
	if _indicator_right.lit != right_on:
		_indicator_right.lit = right_on
	var door_lit := not data.doors_closed
	if _door_button.lit != door_lit:
		_door_button.lit = door_lit
	if _gear_button.lit != data.is_reverse:
		_gear_button.lit = data.is_reverse


## Keeps controls clear of notches and rounded corners.
func _apply_safe_area(root: Control) -> void:
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if screen.x <= 0 or safe.size.x <= 0:
		return
	var scale_x := root.get_viewport_rect().size.x / float(screen.x)
	root.offset_left = float(safe.position.x) * scale_x
	root.offset_right = -float(screen.x - safe.end.x) * scale_x
