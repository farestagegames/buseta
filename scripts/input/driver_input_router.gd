class_name DriverInputRouter
extends Node
## Merges touch controls, tilt and keyboard into one drive input per physics
## tick. Nothing else reads raw input, so the bus has no idea which device is
## being used.

var mapper := SteeringMapper.new()

var _wheel: float = 0.0
var _button_left: bool = false
var _button_right: bool = false
var _touch_throttle: float = 0.0
var _touch_brake: float = 0.0


func _ready() -> void:
	process_physics_priority = -10 # Input first, so the bus sees it this tick.
	GameEvents.ui_wheel_changed.connect(func(value: float) -> void: _wheel = value)
	GameEvents.ui_steer_buttons_changed.connect(_on_steer_buttons)
	GameEvents.ui_pedals_changed.connect(_on_pedals)
	GameSettings.changed.connect(_apply_settings)
	_apply_settings()


func _physics_process(dt: float) -> void:
	var key_left := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var key_right := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var key_throttle := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var key_brake := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_SPACE)

	var steer: float
	if key_left or key_right:
		steer = mapper.update_buttons(key_left, key_right, dt)
	else:
		match GameSettings.steering_mode:
			SteeringMapper.Mode.WHEEL:
				steer = mapper.update_wheel(_wheel)
			SteeringMapper.Mode.TILT:
				steer = mapper.update_tilt(_read_gravity(), dt)
			_:
				steer = mapper.update_buttons(_button_left, _button_right, dt)

	var throttle := 1.0 if key_throttle else _touch_throttle
	var brake := 1.0 if key_brake else _touch_brake
	GameEvents.drive_input_changed.emit(steer, throttle, brake)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	if key.physical_keycode == KEY_H:
		GameEvents.horn_changed.emit(key.pressed)
	if not key.pressed:
		return
	match key.physical_keycode:
		KEY_F:
			GameEvents.door_toggle_requested.emit()
		KEY_C:
			GameEvents.camera_cycle_requested.emit()
		KEY_R:
			GameEvents.gear_toggle_requested.emit()
		KEY_Q:
			GameEvents.indicator_toggle_requested.emit(BusIndicators.TurnSide.LEFT)
		KEY_E:
			GameEvents.indicator_toggle_requested.emit(BusIndicators.TurnSide.RIGHT)
		KEY_BACKSPACE:
			GameEvents.reset_requested.emit()


func _read_gravity() -> Vector3:
	var gravity := Input.get_gravity()
	return gravity if gravity != Vector3.ZERO else Input.get_accelerometer()


func _apply_settings() -> void:
	mapper.sensitivity = GameSettings.sensitivity
	mapper.invert_tilt = GameSettings.invert_tilt


func _on_steer_buttons(left: bool, right: bool) -> void:
	_button_left = left
	_button_right = right


func _on_pedals(throttle: float, brake: float) -> void:
	_touch_throttle = throttle
	_touch_brake = brake
