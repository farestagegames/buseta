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

var kind: String
var position: Vector3
var rotation: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var spin: Vector3 = Vector3.ZERO
var state: State = State.STANDING
var radius: float


func _init(prop_kind: String, start: Vector3, prop_radius: float, yaw: float = 0.0) -> void:
	kind = prop_kind
	position = start
	radius = prop_radius
	rotation.y = yaw


func is_moving() -> bool:
	return state == State.FLYING


## bus_velocity is on the ground plane. away points from the bus to the prop.
func hit(bus_velocity: Vector2, away: Vector2) -> void:
	var speed := bus_velocity.length()
	var push := bus_velocity * 1.15 + away.normalized() * (1.0 + speed * 0.35)
	velocity = Vector3(push.x, clampf(speed * 0.5, MIN_LIFT, MAX_LIFT), push.y)
	spin = Vector3(push.y, 0.0, -push.x) * 0.9
	state = State.FLYING


func update(dt: float, ground_height: float) -> void:
	if state != State.FLYING:
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
