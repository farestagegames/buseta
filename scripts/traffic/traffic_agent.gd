class_name TrafficAgent
extends RefCounted
## One car. Follows the Intelligent Driver Model: it keeps a safe time gap to
## whatever is ahead and brakes smoothly, which gives natural queues. Pure logic.

const MAX_ACCEL := 1.6
const COMFORT_BRAKE := 2.6
const MAX_BRAKE := 7.0
const TIME_GAP := 1.3
const MIN_GAP := 2.5
const CAR_LENGTH := 4.4
const STUN_SECONDS := 5.0

var lane: int
var distance: float = 0.0
var speed: float = 0.0
var cruise: float = 11.0
var next_lane: int = -1
var stunned: float = 0.0 ## Seconds it stays stopped after being hit.
var nudge: Vector2 = Vector2.ZERO ## Offset from being shoved by the bus.
var nudge_velocity: Vector2 = Vector2.ZERO


func _init(start_lane: int, start_distance: float, cruise_speed: float) -> void:
	lane = start_lane
	distance = start_distance
	cruise = cruise_speed


## Acceleration given the free speed and the gap to what is ahead. gap is
## bumper to bumper in metres, and lead_speed is how fast that thing is moving.
static func acceleration(speed_now: float, free_speed: float, gap: float, lead_speed: float) -> float:
	var ratio := speed_now / maxf(free_speed, 0.1)
	var free := 1.0 - ratio * ratio * ratio * ratio
	if gap == INF:
		return MAX_ACCEL * free
	var closing := speed_now - lead_speed
	var desired := MIN_GAP + maxf(speed_now * TIME_GAP + speed_now * closing / (2.0 * sqrt(MAX_ACCEL * COMFORT_BRAKE)), 0.0)
	var pressure := desired / maxf(gap, 0.5)
	return clampf(MAX_ACCEL * (free - pressure * pressure), -MAX_BRAKE, MAX_ACCEL)


func drive(free_speed: float, gap: float, lead_speed: float, dt: float) -> void:
	if stunned > 0.0:
		stunned -= dt
		speed = move_toward(speed, 0.0, MAX_BRAKE * dt)
	else:
		speed = maxf(speed + acceleration(speed, free_speed, gap, lead_speed) * dt, 0.0)
	distance += speed * dt
	_settle_nudge(dt)


func hit_by_bus(bus_velocity: Vector2) -> void:
	stunned = STUN_SECONDS
	speed *= 0.3
	nudge_velocity = bus_velocity * 0.75


## Touching the bus without a real crash: stop, and be pushed back out of it.
func stop_against_bus(push: Vector2) -> void:
	stunned = maxf(stunned, 1.5)
	speed = 0.0
	nudge += push


func _settle_nudge(dt: float) -> void:
	nudge += nudge_velocity * dt
	var remaining := maxf(nudge_velocity.length() - KnockableProp.SKID_DECEL * dt, 0.0)
	nudge_velocity = nudge_velocity.normalized() * remaining if remaining > 0.0 else Vector2.ZERO
