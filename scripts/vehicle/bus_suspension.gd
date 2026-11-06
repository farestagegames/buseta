class_name BusSuspension
extends RefCounted
## Sprung body riding on four wheels. The wheels follow the ground exactly and
## the body chases them through springs, so hills tilt it smoothly while kerbs
## and bumps make it rock and settle. Pure maths, so it is testable headless.

const STIFFNESS := 95.0
const DAMPING := 12.0
## Wheel movement faster than this, in m/s, counts as a jolt for passengers.
const JOLT_THRESHOLD := 0.8

var height: float = 0.0 ## Body height at the rear axle.
var pitch: float = 0.0 ## Radians, positive is nose up.
var roll: float = 0.0 ## Radians, positive leans right.
var jolt: float = 0.0 ## Hardest wheel movement this step, in m/s.

var _wheelbase: float
var _track: float
var _height_velocity: float = 0.0
var _pitch_velocity: float = 0.0
var _roll_velocity: float = 0.0
var _last_wheels: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _previous_targets: Vector3 = Vector3.ZERO


func _init(wheelbase: float, track: float) -> void:
	_wheelbase = wheelbase
	_track = track


## wheels is front left, front right, rear left, rear right.
func snap(wheels: PackedFloat32Array, detail: PackedFloat32Array = PackedFloat32Array()) -> void:
	var targets := _targets(wheels)
	height = targets.x
	pitch = targets.y
	roll = targets.z
	_height_velocity = 0.0
	_pitch_velocity = 0.0
	_roll_velocity = 0.0
	_previous_targets = targets
	_last_wheels = (wheels if detail.is_empty() else detail).duplicate()
	jolt = 0.0


## detail is the part of each wheel height from kerbs, bumps and potholes. Only
## this can jolt passengers, because a smooth hill is not a jolt however fast
## the bus climbs it. Left empty, the whole wheel height counts.
func update(wheels: PackedFloat32Array, dt: float, detail: PackedFloat32Array = PackedFloat32Array()) -> void:
	var felt := wheels if detail.is_empty() else detail
	jolt = 0.0
	for i in 4:
		jolt = maxf(jolt, absf(felt[i] - _last_wheels[i]) / dt)
		_last_wheels[i] = felt[i]

	var targets := _targets(wheels)
	var rates := (targets - _previous_targets) / dt
	_previous_targets = targets
	_height_velocity += _spring(targets.x - height, rates.x - _height_velocity) * dt
	_pitch_velocity += _spring(targets.y - pitch, rates.y - _pitch_velocity) * dt
	_roll_velocity += _spring(targets.z - roll, rates.z - _roll_velocity) * dt
	height += _height_velocity * dt
	pitch += _pitch_velocity * dt
	roll += _roll_velocity * dt


func is_jolt() -> bool:
	return jolt > JOLT_THRESHOLD


func _spring(offset: float, relative_rate: float) -> float:
	return STIFFNESS * offset + DAMPING * relative_rate


func _targets(wheels: PackedFloat32Array) -> Vector3:
	var front := (wheels[0] + wheels[1]) / 2.0
	var rear := (wheels[2] + wheels[3]) / 2.0
	var left := (wheels[0] + wheels[2]) / 2.0
	var right := (wheels[1] + wheels[3]) / 2.0
	return Vector3(rear, atan2(front - rear, _wheelbase), atan2(left - right, _track))
