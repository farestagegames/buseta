class_name BusController
extends CharacterBody3D
## Connects the pure handling model to the scene: runs it each physics tick,
## moves the body, feeds collisions back and publishes telemetry.

@export var spec: BusSpec

var model: BusPhysicsModel
var doors: BusDoors
var indicators: BusIndicators

var _steer: float = 0.0
var _throttle: float = 0.0
var _brake: float = 0.0
var _start_transform: Transform3D
var _telemetry := BusTelemetry.new()


func _ready() -> void:
	model = BusPhysicsModel.new(spec)
	doors = BusDoors.new(spec.door_open_time)
	indicators = BusIndicators.new()
	_start_transform = global_transform
	model.reset(Vector2(global_position.x, global_position.z), rotation.y)
	_build_collision()

	GameEvents.drive_input_changed.connect(_on_drive_input)
	GameEvents.door_toggle_requested.connect(_on_door_toggle)
	GameEvents.indicator_toggle_requested.connect(_on_indicator_toggle)
	GameEvents.gear_toggle_requested.connect(_on_gear_toggle)
	GameEvents.reset_requested.connect(reset_to_start)


func _physics_process(dt: float) -> void:
	var previous_heading := model.heading
	model.drive_enabled = doors.is_closed()
	model.step(_steer, _throttle, _brake, dt)
	doors.update(dt)
	indicators.update(model.heading - previous_heading, model.steer_angle, dt)

	rotation.y = model.heading
	var planar_velocity := model.velocity()
	velocity = Vector3(planar_velocity.x, 0.0, planar_velocity.y)
	move_and_slide()
	_resolve_collisions()
	_publish_telemetry()


func reset_to_start() -> void:
	global_transform = _start_transform
	velocity = Vector3.ZERO
	model.reset(Vector2(global_position.x, global_position.z), rotation.y)
	reset_physics_interpolation()


func _resolve_collisions() -> void:
	model.position = Vector2(global_position.x, global_position.z)
	if get_slide_collision_count() == 0:
		return
	var forward := -global_transform.basis.z
	var actual_speed := get_real_velocity().dot(forward)
	var impact := absf(model.speed - actual_speed)
	model.apply_external_speed(actual_speed)
	if impact > 0.5:
		GameEvents.bus_collided.emit(impact)


func _publish_telemetry() -> void:
	_telemetry.speed = model.speed
	_telemetry.gear = model.gearbox.gear
	_telemetry.rpm = model.gearbox.rpm
	_telemetry.is_reverse = model.direction == BusPhysicsModel.Direction.REVERSE
	_telemetry.steer_angle = model.steer_angle
	_telemetry.throttle = model.throttle
	_telemetry.brake = model.brake
	_telemetry.longitudinal_accel = model.longitudinal_accel
	_telemetry.lateral_accel = model.lateral_accel
	_telemetry.body_roll = model.body_roll
	_telemetry.body_pitch = model.body_pitch
	_telemetry.door_open_amount = doors.open_amount
	_telemetry.doors_closed = doors.is_closed()
	_telemetry.indicator_side = indicators.side
	_telemetry.indicator_lamp_on = indicators.lamp_on
	GameEvents.bus_telemetry_updated.emit(_telemetry)


func _build_collision() -> void:
	# Raised off the ground so the box never catches on flat surfaces.
	var ground_clearance := 0.35
	var box := BoxShape3D.new()
	box.size = Vector3(spec.body_width, spec.body_height - ground_clearance, spec.overall_length())
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0.0, ground_clearance + box.size.y / 2.0, spec.body_centre_z())
	add_child(shape)


func _on_drive_input(steer: float, throttle: float, brake: float) -> void:
	_steer = steer
	_throttle = throttle
	_brake = brake


func _on_door_toggle() -> void:
	doors.toggle(model.is_stopped())


func _on_indicator_toggle(side: int) -> void:
	indicators.toggle(side as BusIndicators.TurnSide)


func _on_gear_toggle() -> void:
	model.toggle_direction()
