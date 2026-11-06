class_name KnockableProp
extends RefCounted
## A light roadside object. It stands still until hit, then flies, tumbles,
## bounces and comes to rest. Simple ballistics keep it cheap on phones and
## repeatable in tests, without a physics body per prop.

enum State { STANDING, FLYING, SETTLED }

const GRAVITY := 9.81
const BOUNCE := 0.35
const GROUND_FRICTION := 0.6
const REST_SPEED := 0.7
const MIN_LIFT := 1.5
const MAX_LIFT := 4.5
## Heavy props, such as cars, stay on their wheels and skid to a stop.
const SKID_DECEL := 9.0
const HEAVY_REST_SPEED := 0.15
const HEAVY_HIT_COOLDOWN := 0.25
## Extra push on top of bus speed, so a slow bus rolls a car along.
const SHOVE_KICK := 0.9
## Share of bus speed a parked car picks up. Its brakes and tyres fight the shove.
const SHOVE_SHARE := 0.75
## Hits this soon after another are the bus still pushing, not a new crash.
const CONTACT_WINDOW := 1.2
## Time for a lamp post to fall over, at the start of its fall.
const TIP_ACCEL := 5.0

var kind: String
var position: Vector3
var rotation: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var spin: Vector3 = Vector3.ZERO
var state: State = State.STANDING
var radius: float
var heavy: bool = false
var cooldown: float = 0.0
var tips_over: bool = false
var tip_angle: float = 0.0

var _contact_timer: float = 0.0
var _tip_axis: Vector3 = Vector3.RIGHT
var _tip_rate: float = 0.0


func _init(prop_kind: String, start: Vector3, prop_radius: float, yaw: float = 0.0) -> void:
	kind = prop_kind
	position = start
	radius = prop_radius
	rotation.y = yaw


## True while this hit is part of the bus already pushing the prop.
func in_contact() -> bool:
	return _contact_timer > 0.0


## Knocks a post over from its base. It stays where it stands and falls away.
func tip(away: Vector2) -> void:
	var fall := away.normalized()
	_tip_axis = Vector3(-fall.y, 0.0, fall.x).normalized() * -1.0
	_tip_rate = 0.8
	state = State.FLYING


func basis() -> Basis:
	var base := Basis.from_euler(rotation)
	if tip_angle > 0.0:
		return Basis(_tip_axis, tip_angle) * base
	return base


func is_moving() -> bool:
	return state == State.FLYING


## bus_velocity is on the ground plane. away points from the bus to the prop.
func hit(bus_velocity: Vector2, away: Vector2) -> void:
	var speed := bus_velocity.length()
	var push := bus_velocity * 1.15 + away.normalized() * (1.0 + speed * 0.35)
	velocity = Vector3(push.x, clampf(speed * 0.5, MIN_LIFT, MAX_LIFT), push.y)
	spin = Vector3(push.y, 0.0, -push.x) * 0.9
	state = State.FLYING


## A shove from the bus, for props too heavy to throw.
func shove(bus_velocity: Vector2, away: Vector2) -> void:
	var speed := bus_velocity.length()
	var push := bus_velocity.normalized() * (speed * SHOVE_SHARE + SHOVE_KICK) + away.normalized() * speed * 0.15
	velocity = Vector3(push.x, 0.0, push.y)
	spin = Vector3(0.0, signf(away.cross(bus_velocity)) * bus_velocity.length() * 0.14, 0.0)
	state = State.FLYING
	cooldown = HEAVY_HIT_COOLDOWN
	_contact_timer = CONTACT_WINDOW


func update(dt: float, ground_height: float) -> void:
	cooldown = maxf(cooldown - dt, 0.0)
	_contact_timer = maxf(_contact_timer - dt, 0.0)
	if state != State.FLYING:
		return
	if tips_over:
		_tip_rate += TIP_ACCEL * dt
		tip_angle = minf(tip_angle + _tip_rate * dt, PI / 2.0 - 0.03)
		if tip_angle >= PI / 2.0 - 0.03:
			state = State.SETTLED
		return
	if heavy:
		_skid(dt, ground_height)
		return
	velocity.y -= GRAVITY * dt
	position += velocity * dt
	rotation += spin * dt
	if position.y <= ground_height:
		position.y = ground_height
		velocity.y = -velocity.y * BOUNCE
		velocity.x *= GROUND_FRICTION
		velocity.z *= GROUND_FRICTION
		spin *= GROUND_FRICTION
		if Vector3(velocity.x, velocity.y, velocity.z).length() < REST_SPEED:
			state = State.SETTLED


## Cars return to STANDING, so the bus can push one again.
func _skid(dt: float, ground_height: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	position += velocity * dt
	position.y = ground_height
	rotation += spin * dt
	var remaining := maxf(speed - SKID_DECEL * dt, 0.0)
	var share := remaining / speed if speed > 0.0 else 0.0
	velocity *= share
	spin *= share
	if remaining < HEAVY_REST_SPEED:
		velocity = Vector3.ZERO
		state = State.STANDING
