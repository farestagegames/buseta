class_name BusPhysicsModel
extends RefCounted
## Bus handling as plain maths, with no scene dependencies, so it can be unit
## tested headless. A kinematic bicycle model pivoting on the rear axle: the
## long body behind the axle swings out in turns, which gives the rear overhang
## for free. Weight comes from pedal lag, a limited steering rate and body
## movement on a spring.
##
## Conventions: heading 0 faces -Z, positive heading turns left. Positive steer
## turns right. Speed is signed along the heading.

enum Direction { FORWARD = 1, REVERSE = -1 }

## Below this speed the bus counts as stopped for gear changes and doors.
const STOPPED_SPEED := 0.3
const GRAVITY := 9.81
## How far a joint can fold before the rear section is dragged round with it.
const MAX_ARTICULATION := deg_to_rad(52.0)

## Arcade boost, 0 to 1: a higher top speed and more pull while it lasts.
var boost: float = 0.0
const BOOST_TOP_SPEED := 0.35
const BOOST_PUSH := 0.9
const BOOST_THRUST_FLOOR := 0.6
var position: Vector2 = Vector2.ZERO ## X and Z on the ground plane.
var heading: float = 0.0
var speed: float = 0.0
var steer_angle: float = 0.0 ## Road wheel angle in radians.
var direction: Direction = Direction.FORWARD
var drive_enabled: bool = true ## Cleared by the door interlock.
var road_slope: float = 0.0 ## Rise per metre along the heading. Positive is uphill.
## Tyre grip as a share of a dry road. A wet road lowers it, which lengthens
## braking and widens the turns the bus can hold at speed.
var grip: float = 1.0
## Steering help, 1 for a normal shift: scales the wheel speed and cornering grip.
var handling: float = 1.0

var throttle: float = 0.0 ## Pedal after lag.
var brake: float = 0.0 ## Pedal after lag.
var longitudinal_accel: float = 0.0
var lateral_accel: float = 0.0
var yaw_rate: float = 0.0
var body_roll: float = 0.0 ## Radians, positive leans to the right.
var body_pitch: float = 0.0 ## Radians, positive is nose up.

var trailer_axle: Vector2 = Vector2.ZERO ## Only moves on an articulated bus.
var trailer_heading: float = 0.0

var gearbox: AutomaticGearbox

var _spec: BusSpec
var _roll_velocity: float = 0.0
var _pitch_velocity: float = 0.0


func _init(spec: BusSpec) -> void:
	_spec = spec
	gearbox = AutomaticGearbox.new(spec)
	_line_up_trailer()


func is_stopped() -> bool:
	return absf(speed) < STOPPED_SPEED


func forward_vector() -> Vector2:
	return Vector2(-sin(heading), -cos(heading))


func velocity() -> Vector2:
	return forward_vector() * speed


## Flips between drive and reverse. Refused while the bus is moving.
func toggle_direction() -> bool:
	if not is_stopped():
		return false
	direction = Direction.REVERSE if direction == Direction.FORWARD else Direction.FORWARD
	return true


func step(steer_input: float, throttle_input: float, brake_input: float, dt: float) -> void:
	var previous_speed := speed
	_update_pedals(clampf(throttle_input, 0.0, 1.0), clampf(brake_input, 0.0, 1.0), dt)
	_update_steering(clampf(steer_input, -1.0, 1.0), dt)
	gearbox.update(speed, dt)
	speed = _integrate_speed(dt)
	longitudinal_accel = (speed - previous_speed) / dt

	yaw_rate = -speed * tan(steer_angle) / _spec.wheelbase
	heading += yaw_rate * dt
	position += velocity() * dt
	lateral_accel = -yaw_rate * speed
	_follow_with_trailer()
	_update_body(dt)


## Called after the world has blocked the bus, with the speed it really had.
func apply_external_speed(actual_speed: float) -> void:
	speed = actual_speed


func reset(new_position: Vector2, new_heading: float) -> void:
	position = new_position
	heading = new_heading
	speed = 0.0
	steer_angle = 0.0
	throttle = 0.0
	brake = 0.0
	direction = Direction.FORWARD
	body_roll = 0.0
	body_pitch = 0.0
	_roll_velocity = 0.0
	_pitch_velocity = 0.0
	_line_up_trailer()


## Angle between the two sections. Zero is straight.
func articulation() -> float:
	return angle_difference(heading, trailer_heading)


func _hitch() -> Vector2:
	return position - forward_vector() * _spec.hitch_offset


func _line_up_trailer() -> void:
	trailer_heading = heading
	trailer_axle = _hitch() - forward_vector() * _spec.trailer_wheelbase


## The rear section's axle can only roll where it points, so it trails behind the
## joint the way a real one does, cutting in on bends.
func _follow_with_trailer() -> void:
	if not _spec.is_articulated():
		return
	var hitch := _hitch()
	var pull := (hitch - trailer_axle).normalized()
	var angle := RoadNetwork.heading_of(pull)
	var fold := clampf(angle_difference(heading, angle), -MAX_ARTICULATION, MAX_ARTICULATION)
	trailer_heading = heading + fold
	var along := Vector2(-sin(trailer_heading), -cos(trailer_heading))
	trailer_axle = hitch - along * _spec.trailer_wheelbase


## Largest road wheel angle the tyres can hold at the current speed.
func steer_limit() -> float:
	var full_lock := deg_to_rad(_spec.max_steer_degrees)
	var speed_squared := speed * speed
	if speed_squared < 0.01:
		return full_lock
	return minf(full_lock, atan(_spec.max_lateral_accel * grip * handling * _spec.wheelbase / speed_squared))


func _update_pedals(throttle_input: float, brake_input: float, dt: float) -> void:
	var throttle_rate := _spec.throttle_rise_rate if throttle_input > throttle else _spec.throttle_fall_rate
	throttle = move_toward(throttle, throttle_input, throttle_rate * dt)
	var brake_rate := _spec.brake_rise_rate if brake_input > brake else _spec.brake_fall_rate
	brake = move_toward(brake, brake_input, brake_rate * dt)


func _update_steering(steer_input: float, dt: float) -> void:
	var limit := steer_limit()
	var target := clampf(steer_input * deg_to_rad(_spec.max_steer_degrees), -limit, limit)
	steer_angle = move_toward(steer_angle, target, deg_to_rad(_spec.steer_rate_degrees) * handling * dt)
	steer_angle = clampf(steer_angle, -limit, limit)


func _integrate_speed(dt: float) -> float:
	var signed_thrust := _drive_accel() * float(direction)
	var new_speed := speed + (signed_thrust - GRAVITY * road_slope) * dt
	var resistance := _spec.rolling_decel + _spec.drag_coefficient * speed * speed
	resistance += brake * _spec.max_brake_decel * grip
	# The door interlock also applies the stop brake, so an open bus holds on a hill.
	if not drive_enabled:
		resistance += _spec.max_brake_decel * grip
	if throttle < 0.01:
		resistance += _spec.coast_decel
	var slowdown := resistance * dt
	if absf(new_speed) <= slowdown:
		return 0.0
	return new_speed - signf(new_speed) * slowdown


func _drive_accel() -> float:
	if not drive_enabled or gearbox.is_shifting():
		return 0.0
	# Going against the selected direction, drive still pushes the bus back.
	var limit := _spec.top_speed if direction == Direction.FORWARD else _spec.top_speed_reverse
	var push := 1.0
	if direction == Direction.FORWARD and boost > 0.0:
		limit *= 1.0 + BOOST_TOP_SPEED * boost
		push += BOOST_PUSH * boost
	var along_direction := speed * float(direction)
	var governor := clampf((limit - along_direction) / (limit * 0.08), 0.0, 1.0)
	# A boost keeps pulling past the top gear, where thrust would fade.
	var thrust := maxf(gearbox.thrust_share(), BOOST_THRUST_FLOOR * boost)
	return _spec.max_drive_accel * thrust * throttle * governor * push


func _update_body(dt: float) -> void:
	# The body leans away from the turn. Positive lateral_accel is a right turn.
	var roll_target := -deg_to_rad(_spec.roll_degrees_per_accel) * lateral_accel
	var pitch_target := deg_to_rad(_spec.pitch_degrees_per_accel) * longitudinal_accel
	_roll_velocity += (_spec.suspension_stiffness * (roll_target - body_roll) - _spec.suspension_damping * _roll_velocity) * dt
	_pitch_velocity += (_spec.suspension_stiffness * (pitch_target - body_pitch) - _spec.suspension_damping * _pitch_velocity) * dt
	body_roll += _roll_velocity * dt
	body_pitch += _pitch_velocity * dt
