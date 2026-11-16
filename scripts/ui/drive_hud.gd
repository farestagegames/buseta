class_name DriveHud
extends CanvasLayer
## Lays out the driving controls for two thumbs in landscape: steering on the
## left, pedals on the right, secondary buttons just above each thumb's home.
## Every control only emits GameEvents. The HUD never touches the bus.

const EDGE := 24.0
const GAP := 16.0
const PERFORMANCE_WINDOW := 1.0
## How long the station name stays up after tuning.
const STATION_SECONDS := 2.5
## The pause and camera buttons in the top corner.
const CORNER_BUTTON := 80.0
const PAUSE_STRIP_WIDTH := 240.0
## The drive and reverse switch, just above the horn on the right thumb's side.
const GEAR_SIZE := Vector2(200.0, 72.0)
## The route's goals checklist, on the left under the pause and camera buttons.
const GOALS_SIZE := Vector2(300.0, 64.0)
const GOALS_TOP := EDGE + CORNER_BUTTON + 12.0

var wheel: SteeringWheelControl
var throttle_pedal: PedalControl
var brake_pedal: BrakeButton
var left_button: TouchButton
var right_button: TouchButton
var settings_panel: SettingsPanel
var gauge: HudGauge
var route_panel: RoutePanel
var minimap: Minimap
var police_notice: Label
## The arcade's clock and next checkpoint, in place of the route panel.
var arcade_clock: Label
var shift_panel: ShiftEndPanel
var penalty_toast: PenaltyToast
var tutorial_panel: TutorialPanel
var goals_hud: GoalsHud
var stop_feedback: StopFeedback
var celebration_banner: CelebrationBanner

var _controls: Control
## Set by the tutorial so the controls it points at show whatever the setting.
var force_drive_controls: bool = false:
	set(value):
		force_drive_controls = value
		if is_node_ready():
			_apply_mode()
var _tilt_hint: Label
var _view_button: TouchButton
var _pause_button: TouchButton
## Camera and radio while paused.
var pause_strip: Control
var _near_stop: bool = false
var _doors_open: bool = false
var _indicator_left: TouchButton
var _indicator_right: TouchButton
var _door_button: TouchButton
var gear_switch: GearSwitch
## In the pause strip. Hidden when the country has no radio stations.
var radio_button: TouchButton
var station_label: Label
var _station_timer: float = 0.0
var _frame_rate: Label
var _worst_frame: float = 0.0
var _frame_timer: float = 0.0


var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Thumbs do not change with the language: right-to-left text keeps the wheel on
	# the left and the pedals on the right.
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(_root)
	_apply_safe_area(_root)
	get_viewport().size_changed.connect(_on_viewport_resized)

	_controls = Control.new()
	_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_controls)

	_build_steering()
	_build_pedals()
	_build_buttons()

	gauge = HudGauge.new()
	_place(gauge, Vector2(0.5, 0.0), Vector2(-190.0, 8.0), Vector2(380.0, 112.0))
	_root.add_child(gauge)

	_frame_rate = Label.new()
	_frame_rate.add_theme_font_size_override("font_size", 18)
	_place(_frame_rate, Vector2(0.5, 0.0), Vector2(-190.0, 210.0), Vector2(380.0, 24.0))
	_frame_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frame_rate.visible = false
	_root.add_child(_frame_rate)

	route_panel = RoutePanel.new()
	_place(route_panel, Vector2(0.5, 0.0), Vector2(-280.0, 124.0), Vector2(560.0, 40.0))
	_root.add_child(route_panel)

	goals_hud = GoalsHud.new()
	_place(goals_hud, Vector2(0.0, 0.0), Vector2(EDGE, GOALS_TOP), GOALS_SIZE)
	goals_hud.visible = false
	_root.add_child(goals_hud)

	stop_feedback = StopFeedback.new()
	stop_feedback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(stop_feedback)

	celebration_banner = CelebrationBanner.new()
	_root.add_child(celebration_banner)
	GameEvents.celebration.connect(func(text: String, coins: int) -> void:
		celebration_banner.show_celebration(text, coins))

	penalty_toast = PenaltyToast.new()
	_place(penalty_toast, Vector2(0.5, 0.0), Vector2(-280.0, 280.0), Vector2(560.0, 40.0))
	_root.add_child(penalty_toast)

	minimap = Minimap.new()
	_place_minimap()
	minimap.size_toggled.connect(_place_minimap.unbind(1))
	_root.add_child(minimap)

	arcade_clock = Label.new()
	arcade_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arcade_clock.add_theme_font_size_override("font_size", 30)
	arcade_clock.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06))
	arcade_clock.add_theme_constant_override("outline_size", 8)
	arcade_clock.visible = false
	_place(arcade_clock, Vector2(0.5, 0.0), Vector2(-280.0, 124.0), Vector2(560.0, 84.0))
	_root.add_child(arcade_clock)
	GameEvents.arcade_status.connect(_on_arcade_status)
	GameEvents.map_ready.connect(_on_map_ready)
	GameEvents.score_updated.connect(func(_total: int) -> void: _refresh_goals())
	GameEvents.fare_collected.connect(_on_fare_collected)
	GameEvents.perfect_stop.connect(_on_perfect_stop)

	police_notice = Label.new()
	police_notice.text = "POLICE NEARBY"
	police_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	police_notice.add_theme_font_size_override("font_size", 18)
	police_notice.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	police_notice.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06))
	police_notice.add_theme_constant_override("outline_size", 6)
	police_notice.visible = false
	_place(police_notice, Vector2(1.0, 0.0), Vector2(-EDGE - 190.0, 8.0 + Minimap.SMALL + 6.0), Vector2(190.0, 26.0))
	_root.add_child(police_notice)
	GameEvents.police_nearby.connect(func(near: bool) -> void: police_notice.visible = near)

	tutorial_panel = TutorialPanel.new()
	_root.add_child(tutorial_panel)
	# Clear of the indicators on the left and the horn on the right.
	tutorial_panel.keep_clear_of(EDGE + 166.0 + 150.0 + GAP, EDGE + 150.0 + GAP + 200.0 + GAP)

	settings_panel = SettingsPanel.new()
	settings_panel.in_shift = true
	settings_panel.visible = false
	settings_panel.closed.connect(_close_settings)
	GameEvents.map_ready.connect(func(_network: RoadNetwork, route: RouteRunner) -> void:
		if settings_panel.end_shift_button != null:
			settings_panel.end_shift_button.visible = route.endless)
	settings_panel.layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE
	_place(settings_panel, Vector2(0.5, 0.5), Vector2(-340.0, -340.0), Vector2(680.0, 680.0))
	_root.add_child(settings_panel)
	_build_pause_strip()

	shift_panel = ShiftEndPanel.new()
	shift_panel.visible = false
	shift_panel.layout_direction = Control.LAYOUT_DIRECTION_APPLICATION_LOCALE
	_place(shift_panel, Vector2(0.5, 0.5), Vector2(-600.0, -340.0), Vector2(1200.0, 680.0))
	_root.add_child(shift_panel)
	GameEvents.shift_rewards_ready.connect(_on_shift_report)

	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.route_status_updated.connect(_on_route_status)
	GameEvents.radio_tuned.connect(_on_radio_tuned)
	GameSettings.changed.connect(_apply_mode)
	_apply_mode()


func _process(dt: float) -> void:
	if _station_timer > 0.0:
		_station_timer -= dt
		station_label.modulate.a = clampf(_station_timer / 0.5, 0.0, 1.0)
		station_label.visible = _station_timer > 0.0
	_frame_rate.visible = GameSettings.show_performance and not shift_panel.visible
	if not _frame_rate.visible:
		return
	_worst_frame = maxf(_worst_frame, dt)
	_frame_timer -= dt
	if _frame_timer <= 0.0:
		_frame_timer = PERFORMANCE_WINDOW
		_frame_rate.text = tr("%d fps  low %d  %dk tris  %d draws") % [
			Engine.get_frames_per_second(), roundi(1.0 / maxf(_worst_frame, 0.001)),
			roundi(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
		_worst_frame = 0.0


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

	brake_pedal = BrakeButton.new()
	_place(brake_pedal, Vector2(1.0, 1.0), Vector2(-EDGE - 150.0 - GAP - 200.0, -EDGE - 230.0), Vector2(200.0, 230.0))
	_controls.add_child(brake_pedal)

	var send := func(_value: float) -> void:
		GameEvents.ui_pedals_changed.emit(throttle_pedal.value, brake_pedal.value)
	throttle_pedal.value_changed.connect(send)
	brake_pedal.value_changed.connect(send)


func _build_buttons() -> void:
	# One pause button and the camera, which is used often while driving.
	_pause_button = _action_button("MENU", Vector2(0.0, 0.0), Vector2(EDGE, EDGE), Vector2(CORNER_BUTTON, CORNER_BUTTON))
	_pause_button.icon = "pause"
	_pause_button.pressed_down.connect(_open_settings)
	_view_button = _action_button("VIEW", Vector2(0.0, 0.0), Vector2(EDGE + CORNER_BUTTON + 12.0, EDGE), Vector2(CORNER_BUTTON, CORNER_BUTTON))
	_view_button.icon = "camera"
	_view_button.pressed_down.connect(GameEvents.camera_cycle_requested.emit)

	_indicator_left = _action_button("◀ IND", Vector2(0.0, 1.0), Vector2(EDGE, -EDGE - 320.0 - GAP - 96.0), Vector2(150.0, 96.0))
	_indicator_right = _action_button("IND ▶", Vector2(0.0, 1.0), Vector2(EDGE + 166.0, -EDGE - 320.0 - GAP - 96.0), Vector2(150.0, 96.0))
	_indicator_left.lit_colour = Color(0.95, 0.6, 0.1, 0.95)
	_indicator_right.lit_colour = Color(0.95, 0.6, 0.1, 0.95)
	_indicator_left.pressed_down.connect(func() -> void: GameEvents.indicator_toggle_requested.emit(BusIndicators.TurnSide.LEFT))
	_indicator_right.pressed_down.connect(func() -> void: GameEvents.indicator_toggle_requested.emit(BusIndicators.TurnSide.RIGHT))

	var above_pedals := -EDGE - 340.0 - GAP - 100.0
	# Only near a stop or while the doors are open; it keeps its words, as the
	# call to action at a stop.
	_door_button = _action_button("DOORS", Vector2(1.0, 1.0), Vector2(-EDGE - 150.0, above_pedals), Vector2(150.0, 100.0))
	_door_button.pressed_down.connect(GameEvents.door_toggle_requested.emit)
	_door_button.visible = false
	var horn := _action_button("HORN", Vector2(1.0, 1.0), Vector2(-EDGE - 150.0 - GAP - 200.0, -EDGE - 230.0 - GAP - 96.0), Vector2(200.0, 96.0))
	# Kept in words: a drawn horn reads as a volume button.
	horn.pressed_down.connect(func() -> void: GameEvents.horn_changed.emit(true))
	horn.released.connect(func() -> void: GameEvents.horn_changed.emit(false))
	gear_switch = GearSwitch.new()
	gear_switch.compact = true
	var horn_left := -EDGE - 150.0 - GAP - 200.0
	_place(gear_switch, Vector2(1.0, 1.0), Vector2(horn_left + (200.0 - GEAR_SIZE.x) / 2.0,
		-EDGE - 230.0 - GAP - 96.0 - GAP - GEAR_SIZE.y), GEAR_SIZE)
	gear_switch.gear_toggled.connect(GameEvents.gear_toggle_requested.emit)
	_controls.add_child(gear_switch)


## Camera and radio while paused, in a column beside the pause sheet.
func _build_pause_strip() -> void:
	pause_strip = Control.new()
	pause_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_strip.visible = false
	_place(pause_strip, Vector2(0.5, 0.5), Vector2(-340.0 - GAP - PAUSE_STRIP_WIDTH, -340.0), Vector2(PAUSE_STRIP_WIDTH, 680.0))
	_root.add_child(pause_strip)
	var camera := TouchButton.new()
	camera.text = "VIEW"
	_place(camera, Vector2.ZERO, Vector2.ZERO, Vector2(PAUSE_STRIP_WIDTH, 96.0))
	camera.pressed_down.connect(GameEvents.camera_cycle_requested.emit)
	pause_strip.add_child(camera)
	radio_button = TouchButton.new()
	radio_button.text = "RADIO"
	_place(radio_button, Vector2.ZERO, Vector2(0.0, 96.0 + GAP), Vector2(PAUSE_STRIP_WIDTH, 96.0))
	radio_button.pressed_down.connect(GameEvents.radio_cycle_requested.emit)
	radio_button.visible = not Country.pack.radio_stations().is_empty()
	pause_strip.add_child(radio_button)
	station_label = Label.new()
	# Station names are names, the same in every language.
	station_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	station_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	station_label.add_theme_font_size_override("font_size", 22)
	station_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06))
	station_label.add_theme_constant_override("outline_size", 6)
	station_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	station_label.visible = false
	_place(station_label, Vector2.ZERO, Vector2(0.0, 2.0 * (96.0 + GAP)), Vector2(PAUSE_STRIP_WIDTH, 34.0))
	pause_strip.add_child(station_label)


## Shows the station for a moment after tuning, or that the radio is off. The
## button stays lit while the radio plays.
func _on_radio_tuned(station_name: String, frequency: String) -> void:
	radio_button.lit = station_name != ""
	station_label.text = "%s  %s" % [station_name, frequency] if station_name != "" else tr("RADIO OFF")
	station_label.add_theme_font_size_override("font_size",
		UiStyle.fit_font_size(station_label.get_theme_font("font"), station_label.text, 22, PAUSE_STRIP_WIDTH))
	station_label.modulate.a = 1.0
	station_label.visible = true
	_station_timer = STATION_SECONDS


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


## A small circle in the top corner, or a larger one after a tap.
func _place_minimap() -> void:
	var across := minimap.diameter()
	_place(minimap, Vector2(1.0, 0.0), Vector2(-EDGE - across, 8.0), Vector2(across, across))


func _apply_mode() -> void:
	_indicator_left.visible = GameSettings.show_indicator_buttons
	_indicator_right.visible = GameSettings.show_indicator_buttons
	# The movement controls can be hidden in Settings (keyboard or gamepad
	# drivers); the tutorial always shows them, since it points at them.
	var drive := drive_controls_shown()
	var mode := GameSettings.steering_mode
	wheel.visible = drive and mode == SteeringMapper.Mode.WHEEL
	left_button.visible = drive and mode == SteeringMapper.Mode.BUTTONS
	right_button.visible = drive and mode == SteeringMapper.Mode.BUTTONS
	_tilt_hint.visible = drive and mode == SteeringMapper.Mode.TILT
	throttle_pedal.visible = drive
	brake_pedal.visible = drive
	gear_switch.visible = drive
	if not drive:
		# Nothing stays pressed under a control that went away.
		GameEvents.ui_pedals_changed.emit(0.0, 0.0)
		GameEvents.ui_steer_buttons_changed.emit(false, false)


## Whether the wheel, pedals and D/R are on screen.
func drive_controls_shown() -> bool:
	return GameSettings.show_drive_controls or force_drive_controls


## Pauses the shift, including the timetable.
func _open_settings() -> void:
	if shift_panel.visible:
		return
	_controls.visible = false
	settings_panel.visible = true
	pause_strip.visible = true
	GameEvents.ui_pedals_changed.emit(0.0, 0.0)
	get_tree().paused = true


func _close_settings() -> void:
	settings_panel.visible = false
	pause_strip.visible = false
	_controls.visible = true
	get_tree().paused = false


## Where a control is on screen, for the tutorial's highlight.
func control_rect(focus: String) -> Rect2:
	match focus:
		"go":
			return throttle_pedal.get_global_rect()
		"brake":
			return brake_pedal.get_global_rect()
		"steer":
			if GameSettings.steering_mode == SteeringMapper.Mode.BUTTONS:
				return left_button.get_global_rect().merge(right_button.get_global_rect())
			return wheel.get_global_rect() if GameSettings.steering_mode == SteeringMapper.Mode.WHEEL else Rect2()
		"view":
			return _view_button.get_global_rect()
		"pause":
			return _pause_button.get_global_rect()
		"indicator":
			return _indicator_right.get_global_rect() if _indicator_right.visible else Rect2()
		"doors":
			return _door_button.get_global_rect()
		"gear":
			return gear_switch.get_global_rect()
		"map":
			return minimap.get_global_rect()
		_:
			return Rect2()


func is_paused() -> bool:
	return settings_panel.visible


## A call, a swipe away or the back button pauses rather than loses the shift.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if OS.has_feature("mobile") and is_inside_tree() and settings_panel != null:
				_open_settings()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if settings_panel != null:
				_open_settings()


func _on_shift_report(report: Dictionary) -> void:
	_controls.visible = false
	settings_panel.visible = false
	pause_strip.visible = false
	for readout: Control in [gauge, route_panel, minimap, penalty_toast, _frame_rate]:
		readout.visible = false
		readout.process_mode = Node.PROCESS_MODE_DISABLED
	GameEvents.ui_pedals_changed.emit(0.0, 1.0)
	shift_panel.show_report(report)


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
	_doors_open = door_lit
	_show_doors()
	if gear_switch.is_reverse != data.is_reverse:
		gear_switch.is_reverse = data.is_reverse


func _on_route_status(status: Dictionary) -> void:
	_near_stop = bool(status.get("near_stop", false))
	_show_doors()


## The doors button shows near a stop or while the doors are open.
func _show_doors() -> void:
	var wanted := _near_stop or _doors_open
	if _door_button.visible != wanted:
		_door_button.visible = wanted


func doors_button_shown() -> bool:
	return _door_button.visible


func _on_map_ready(_network: RoadNetwork, route: RouteRunner) -> void:
	if route.service == "endless" or route.service == "arcade" or route.goals.is_empty():
		goals_hud.visible = false
		return
	goals_hud.set_goals(route.goals)
	_refresh_goals()


func _refresh_goals() -> void:
	if not goals_hud.visible or shift_panel.visible:
		return
	var shift := get_tree().current_scene
	if shift == null or not shift.has_node("ScoreKeeper") or not shift.has_node("RouteSystem"):
		return
	var keeper: ScoreKeeper = shift.get_node("ScoreKeeper")
	var system: RouteSystem = shift.get_node("RouteSystem")
	goals_hud.update_status(keeper.live_report(system.timetable_clock(), system.served_count(), system.carried_count()))


func _on_fare_collected(amount: int) -> void:
	if shift_panel.visible:
		return
	# Rise from the fare/gauge area at the top centre.
	var hud_size: Vector2 = get_viewport().get_visible_rect().size
	var at := Vector2(hud_size.x * 0.58, 78.0)
	stop_feedback.show_fare("+%s" % Country.pack.money(amount), at)


func _on_perfect_stop(_stop_index: int) -> void:
	if shift_panel.visible:
		return
	# A short stamp kept clear of controls and the tutorial ring.
	var hud_size: Vector2 = get_viewport().get_visible_rect().size
	var at := Vector2(hud_size.x * 0.5, hud_size.y * 0.38)
	stop_feedback.show_stamp(tr("Perfect stop!"), at)


func _on_arcade_status(seconds_left: float, checkpoint: int, distance: float, _position: Vector2, boosting: bool) -> void:
	route_panel.visible = false
	if goals_hud != null:
		goals_hud.visible = false
	arcade_clock.visible = not shift_panel.visible
	var low := seconds_left < 10.0
	arcade_clock.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if low else (Color(1.0, 0.6, 0.2) if boosting else Color.WHITE))
	var line := tr("TIME %d") % ceili(seconds_left)
	if boosting:
		line += "   " + tr("BOOST!")
	arcade_clock.text = "%s\n%s" % [line, tr("Checkpoint %d: %d m") % [checkpoint, roundi(distance)]]


## Keeps controls clear of notches and rounded corners on both sides, so
## turning the phone round keeps them clear.
func _apply_safe_area(root: Control) -> void:
	var insets := UiStyle.screen_insets(root.get_viewport_rect().size)
	root.offset_left = insets.x
	root.offset_right = -insets.z
	root.offset_top = 0.0
	root.offset_bottom = 0.0


func _on_viewport_resized() -> void:
	if _root != null:
		_apply_safe_area(_root)
