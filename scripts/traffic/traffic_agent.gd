class_name TrafficAgent
extends RefCounted
## One car or motorbike. Follows the Intelligent Driver Model: it keeps a safe time gap to
## whatever is ahead and brakes smoothly, which gives natural queues. Pure logic.

const MAX_ACCEL := 1.6
const COMFORT_BRAKE := 2.6
## Braking planned for speed limits ahead, a little under COMFORT_BRAKE so there
## is room to catch up.
const APPROACH_BRAKE := 2.1
const MAX_BRAKE := 7.0
const TIME_GAP := 1.3
const MIN_GAP := 2.5
const CAR_LENGTH := 4.4
const STUN_SECONDS := 5.0
const MOTO_LENGTH := 2.2
## Motorbikes keep to the kerb side of the lane, which is how they slip past cars.
const MOTO_KERB_SHIFT := 1.35
## Where the lane moves over for parked cars or cones, a moto's kerb line moves
## over by this share of it too, so it eases round them instead of stopping.
const MOTO_KERB_FOLLOW := 0.5
const CAR_HALF_LENGTH := 2.2
const CAR_HALF_WIDTH := 0.9
const MOTO_HALF_LENGTH := 1.0
const MOTO_HALF_WIDTH := 0.4
## Sideways speed when moving over to pass, in m/s, and how much it grows with speed.
## Even a car that has stopped can creep out, which reads as steering round.
const SHIFT_RATE := 0.6
const SHIFT_RATE_PER_SPEED := 0.12
const SHIFT_RATE_MAX := 1.5

var lane: int
var distance: float = 0.0
var speed: float = 0.0
var cruise: float = 11.0
var next_lane: int = -1
var stunned: float = 0.0 ## Seconds it stays stopped after being hit.
var nudge: Vector2 = Vector2.ZERO ## Offset from being shoved by the bus.
var nudge_velocity: Vector2 = Vector2.ZERO
var is_moto: bool = false
var batch_index: int = 0 ## This vehicle's place in its drawn batch.
## Metres moved towards the kerb from where it normally rides. Negative is
## towards the centre line, as when passing something.
var shift: float = 0.0
var shift_target: float = 0.0
var shift_rate: float = 0.0 ## Sideways speed this tick, for drawing it turned.
var waiting: float = 0.0 ## Seconds stopped behind something it could pass.
var honked: bool = false
var passing_bus: bool = false ## True while going round the bus.
## For a moto, how far towards the kerb it rides here. TrafficFlow sets it.
var kerb_shift: float = MOTO_KERB_SHIFT
## Cached ground under it, refreshed every few ticks by the drawing code.
var ground_spot: Vector2 = Vector2(INF, INF)
var ground_height: float = 0.0
var ground_slope: float = 0.0


func _init(start_lane: int, start_distance: float, cruise_speed: float) -> void:
	lane = start_lane
	distance = start_distance
	cruise = cruise_speed


## Acceleration given the free speed and the gap to what is ahead. gap is
## bumper to bumper in metres, and lead_speed is how fast that thing is moving.
## Being over the free speed only ever eases off at the comfortable rate. Only
## something in the way brakes harder.
## gap_scale stretches the following gap, as drivers leave more room on a wet road.
static func acceleration(speed_now: float, free_speed: float, gap: float, lead_speed: float, gap_scale: float = 1.0) -> float:
	var ratio := speed_now / maxf(free_speed, 0.1)
	var free := maxf(MAX_ACCEL * (1.0 - ratio * ratio * ratio * ratio), -COMFORT_BRAKE)
	if gap == INF:
		return free
	var pressure := desired_gap(speed_now, speed_now - lead_speed, gap_scale) / maxf(gap, 0.5)
	return clampf(free - MAX_ACCEL * pressure * pressure, -MAX_BRAKE, MAX_ACCEL)


## The gap a driver wants to what is ahead, in metres, when closing on it at
## closing m/s. The time gap grows fully with gap_scale and the standing gap by half.
static func desired_gap(speed_now: float, closing: float, gap_scale: float = 1.0) -> float:
	var standing := MIN_GAP * (1.0 + (gap_scale - 1.0) * 0.5)
	return standing + maxf(speed_now * TIME_GAP * gap_scale + speed_now * closing / (2.0 * sqrt(MAX_ACCEL * COMFORT_BRAKE)), 0.0)


## The fastest it can go and still slow to target, gently, within distance
## metres. Speed limits ahead are passed through this so they are met in time.
static func approach_speed(target: float, distance: float) -> float:
	return sqrt(target * target + 2.0 * APPROACH_BRAKE * maxf(distance, 0.0))


func drive(free_speed: float, gap: float, lead_speed: float, dt: float, gap_scale: float = 1.0) -> void:
	if stunned > 0.0:
		stunned -= dt
		speed = move_toward(speed, 0.0, MAX_BRAKE * dt)
	else:
		var accel := acceleration(speed, free_speed, gap, lead_speed, gap_scale)
		if speed > free_speed and dt > 0.0:
			# Down to the free speed at the comfortable rate, never harder.
			accel = minf(accel, maxf((free_speed - speed) / dt, -COMFORT_BRAKE))
		speed = maxf(speed + accel * dt, 0.0)
	distance += speed * dt
	_settle_nudge(dt)


## Moves sideways towards shift_target, faster when moving.
func step_shift(dt: float) -> void:
	var rate := minf(SHIFT_RATE + speed * SHIFT_RATE_PER_SPEED, SHIFT_RATE_MAX)
	var before := shift
	shift = move_toward(shift, shift_target, rate * dt)
	shift_rate = (shift - before) / dt if dt > 0.0 else 0.0


## Where it normally rides, in metres towards the kerb from the lane's line.
func base_offset() -> float:
	return kerb_shift if is_moto else 0.0


func offset() -> float:
	return base_offset() + shift


func half_length() -> float:
	return MOTO_HALF_LENGTH if is_moto else CAR_HALF_LENGTH


func half_width() -> float:
	return MOTO_HALF_WIDTH if is_moto else CAR_HALF_WIDTH


func is_passing() -> bool:
	return shift_target != 0.0 or absf(shift) > 0.05


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
