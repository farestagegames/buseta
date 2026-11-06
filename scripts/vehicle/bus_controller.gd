class_name BusController
extends CharacterBody3D
## Connects the pure handling model to the scene: runs it each physics tick,
## moves the body, follows the ground, feeds collisions back and publishes
## telemetry.

const WHEEL_TRACK_INSET := 0.2
const COLLISION_CLEARANCE := 0.45

@export var spec: BusSpec

var model: BusPhysicsModel
var doors: BusDoors
var indicators: BusIndicators
var suspension: BusSuspension
var surface: GroundSurface = GroundSurface.new()

var _steer: float = 0.0
var _throttle: float = 0.0
var _brake: float = 0.0
var _start_position: Vector2
var _start_heading: float
var _telemetry := BusTelemetry.new()
var _wheels: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


func _ready() -> void:
	model = BusPhysicsModel.new(spec)
	doors = BusDoors.new(spec.door_open_time)
	indicators = BusIndicators.new()
	suspension = BusSuspension.new(spec.wheelbase, wheel_track())
	_start_position = Vector2(global_position.x, global_position.z)
	_start_heading = rotation.y
	_place(_start_position, _start_heading)
	_build_collision()

	GameEvents.drive_input_changed.connect(_on_drive_input)
	GameEvents.door_toggle_requested.connect(_on_door_toggle)
	GameEvents.indicator_toggle_requested.connect(_on_indicator_toggle)
	GameEvents.gear_toggle_requested.connect(_on_gear_toggle)
	GameEvents.reset_requested.connect(reset_to_start)
	GameEvents.bus_relocate_requested.connect(_place)
	GameEvents.obstacle_hit.connect(_on_obstacle_hit)


## Called by the level before play. The bus starts here and resets to here.
func start_at(surface_to_use: GroundSurface, start_position: Vector2, start_heading: float) -> void:
	surface = surface_to_use
	_start_position = start_position
	_start_heading = start_heading
	_place(start_position, start_heading)


func wheel_track() -> float:
	return spec.body_width - WHEEL_TRACK_INSET * 2.0


func _physics_process(dt: float) -> void:
	var previous_heading := model.heading
	_sample_ground()
	model.road_slope = _slope_along_heading()
	model.drive_enabled = doors.is_closed()
	model.step(_steer, _throttle, _brake, dt)
	doors.update(dt)
	indicators.update(model.heading - previous_heading, model.steer_angle, dt)

	rotation.y = model.heading
	var planar_velocity := model.velocity()
	velocity = Vector3(planar_velocity.x, 0.0, planar_velocity.y)
	move_and_slide()
	_resolve_collisions()

	_sample_ground()
	suspension.update(_wheels, dt)
	global_position.y = suspension.height
	if suspension.is_jolt():
		GameEvents.bus_jolted.emit(suspension.jolt)
	_publish_telemetry()


func reset_to_start() -> void:
	_place(_start_position, _start_heading)


func _place(new_position: Vector2, new_heading: float) -> void:
	model.reset(new_position, new_heading)
	global_position = Vector3(new_position.x, 0.0, new_position.y)
	rotation.y = new_heading
	velocity = Vector3.ZERO
	_sample_ground()
	suspension.snap(_wheels)
	global_position.y = suspension.height
	reset_physics_interpolation()


func _sample_ground() -> void:
	var forward := model.forward_vector()
	var right := Vector2(-forward.y, forward.x)
	var rear := Vector2(global_position.x, global_position.z)
	var front := rear + forward * spec.wheelbase
	var half_track := right * wheel_track() / 2.0
	_wheels[0] = surface.height_at(front - half_track)
	_wheels[1] = surface.height_at(front + half_track)
	_wheels[2] = surface.height_at(rear - half_track)
	_wheels[3] = surface.height_at(rear + half_track)


## Uses smooth terrain only, so a kerb rocks the body but does not stop the bus.
func _slope_along_heading() -> float:
	var rear := Vector2(global_position.x, global_position.z)
	var front := rear + model.forward_vector() * spec.wheelbase
	return (surface.terrain_height(front) - surface.terrain_height(rear)) / spec.wheelbase


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
	var data := _telemetry
	data.speed = model.speed
	data.gear = model.gearbox.gear
	data.rpm = model.gearbox.rpm
	data.is_reverse = model.direction == BusPhysicsModel.Direction.REVERSE
	data.steer_angle = model.steer_angle
	data.throttle = model.throttle
	data.brake = model.brake
	data.longitudinal_accel = model.longitudinal_accel
	data.lateral_accel = model.lateral_accel
	data.body_roll = model.body_roll
	data.body_pitch = model.body_pitch
	data.door_open_amount = doors.open_amount
	data.doors_closed = doors.is_closed()
	data.indicator_side = indicators.side
	data.indicator_lamp_on = indicators.lamp_on
	data.position = global_position
	data.heading = model.heading
	data.door_position = _door_position()
	data.body_height = suspension.height
	data.ground_pitch = suspension.pitch
	data.ground_roll = suspension.roll
	for i in 4:
		data.wheel_heights[i] = _wheels[i]
	GameEvents.bus_telemetry_updated.emit(data)


func _door_position() -> Vector3:
	var forward := model.forward_vector()
	var right := Vector2(-forward.y, forward.x)
	var ground := Vector2(global_position.x, global_position.z)
	ground += forward * (spec.wheelbase + spec.front_overhang - BusVisual.DOOR_OFFSET - BusVisual.DOOR_WIDTH / 2.0)
	ground += right * (spec.body_width / 2.0 + 0.3) * float(spec.door_side)
	return Vector3(ground.x, surface.height_at(ground), ground.y)


func _build_collision() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(spec.body_width, spec.body_height - COLLISION_CLEARANCE, spec.overall_length())
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = Vector3(0.0, COLLISION_CLEARANCE + box.size.y / 2.0, spec.body_centre_z())
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


func _on_obstacle_hit(_kind: String, speed_loss: float) -> void:
	var slowed := maxf(absf(model.speed) - speed_loss, 0.0)
	model.apply_external_speed(slowed * signf(model.speed))
