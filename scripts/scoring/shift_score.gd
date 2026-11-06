class_name ShiftScore
extends RefCounted
## Keeps the score for one shift across the five categories in the brief. Pure
## logic with no scene dependencies. Each deduction is a named constant, so the
## balance of the game is easy to tune in one place.

const WEIGHTS := {
	"punctuality": 0.25, "accuracy": 0.2, "smoothness": 0.2, "rules": 0.2, "satisfaction": 0.15,
}
const STAR_THRESHOLDS: Array[int] = [35, 50, 70, 88] ## Score for 2, 3, 4 and 5 stars.
## How quickly a category falls. Losses level off, so a few bad moments cost a
## lot less than the whole category, and a rough shift can still recover.
const CATEGORY_SOFTNESS := 90.0

const HARSH_BRAKE_POINTS := 2.5
const JOLT_POINTS := 1.0
const JOLT_COOLDOWN := 1.0
## Long stretches of speeding or being off road stop adding up after this much.
const SPEEDING_MAX_POINTS := 10.0
const OFF_ROAD_MAX_POINTS := 15.0

const COLLISION_POINTS := 6.0
const COLLISION_POINTS_PER_SPEED := 0.6 ## Extra per m/s of impact.
const COLLISION_MAX_POINTS := 12.0
const KNOCKED_POINTS := 1.0
const RED_LIGHT_POINTS := 8.0
const SPEEDING_POINTS_PER_SECOND := 0.25
const OFF_ROAD_POINTS_PER_SECOND := 0.6
const KERB_POINTS := 0.5
const INDICATOR_POINTS := 0.75

const SATISFACTION_BRAKE := 1.0
const SATISFACTION_JOLT := 1.0
const SATISFACTION_COLLISION := 3.0
const SATISFACTION_LATE_STOP := 1.5
const SATISFACTION_LEFT_BEHIND := 1.0
const SATISFACTION_MISSED_STOP := 5.0

const BASE_COINS := 50
const COINS_PER_POINT := 2
const COINS_PER_PASSENGER := 3
const COINS_PER_STAR := 40

var counts: Dictionary = {
	"harsh_brakes": 0, "jolts": 0, "collisions": 0, "knocked": 0,
	"red_lights": 0, "kerbs": 0, "indicators": 0, "missed_stops": 0, "left_behind": 0,
}
var speeding_seconds: float = 0.0
var off_road_seconds: float = 0.0

var _punctuality: Array[float] = []
var _accuracy: Array[float] = []
var _smoothness_lost: float = 0.0
var _rules_lost: float = 0.0
var _satisfaction_lost: float = 0.0
var _jolt_cooldown: float = 0.0


func add_stop(accuracy: float, seconds_late: float) -> void:
	_accuracy.append(clampf(accuracy, 0.0, 1.0) * 100.0)
	_punctuality.append(ShiftSchedule.punctuality_score(seconds_late))
	if not ShiftSchedule.is_on_time(seconds_late):
		_satisfaction_lost += SATISFACTION_LATE_STOP


func add_missed_stop() -> void:
	counts["missed_stops"] += 1
	_accuracy.append(0.0)
	_punctuality.append(0.0)
	_satisfaction_lost += SATISFACTION_MISSED_STOP


func add_left_behind(passengers: int) -> void:
	counts["left_behind"] += passengers
	_satisfaction_lost += SATISFACTION_LEFT_BEHIND * passengers


func add_harsh_brake() -> void:
	counts["harsh_brakes"] += 1
	_smoothness_lost += HARSH_BRAKE_POINTS
	_satisfaction_lost += SATISFACTION_BRAKE


## Returns true if this counted. One bump shakes each axle, so repeats are ignored.
func add_jolt() -> bool:
	if _jolt_cooldown > 0.0:
		return false
	_jolt_cooldown = JOLT_COOLDOWN
	counts["jolts"] += 1
	_smoothness_lost += JOLT_POINTS
	_satisfaction_lost += SATISFACTION_JOLT
	return true


func add_collision(impact_speed: float) -> void:
	counts["collisions"] += 1
	_rules_lost += minf(COLLISION_POINTS + impact_speed * COLLISION_POINTS_PER_SPEED, COLLISION_MAX_POINTS)
	_satisfaction_lost += SATISFACTION_COLLISION


func add_knocked() -> void:
	counts["knocked"] += 1
	_rules_lost += KNOCKED_POINTS


func add_red_light() -> void:
	counts["red_lights"] += 1
	_rules_lost += RED_LIGHT_POINTS


func add_kerb() -> void:
	counts["kerbs"] += 1
	_rules_lost += KERB_POINTS


func add_missed_indicator() -> void:
	counts["indicators"] += 1
	_rules_lost += INDICATOR_POINTS


func add_time(dt: float, speeding: bool, off_road: bool) -> void:
	_jolt_cooldown = maxf(_jolt_cooldown - dt, 0.0)
	if speeding:
		speeding_seconds += dt
	if off_road:
		off_road_seconds += dt


## Each category from 0 to 100.
func categories() -> Dictionary:
	return {
		"punctuality": _average(_punctuality),
		"accuracy": _average(_accuracy),
		"smoothness": _after_losses(_smoothness_lost),
		"rules": _after_losses(_rules_lost + _time_losses()),
		"satisfaction": _after_losses(_satisfaction_lost),
	}


func total() -> int:
	var values := categories()
	var sum := 0.0
	for key: String in WEIGHTS:
		sum += float(values[key]) * float(WEIGHTS[key])
	return roundi(sum)


func stars() -> int:
	var score := total()
	var earned := 1
	for threshold in STAR_THRESHOLDS:
		if score >= threshold:
			earned += 1
	return earned


func coins(passengers_carried: int) -> int:
	return BASE_COINS + total() * COINS_PER_POINT + passengers_carried * COINS_PER_PASSENGER + stars() * COINS_PER_STAR


## The category that cost the most points, for the report's advice.
func weakest_category() -> String:
	var values := categories()
	var weakest := ""
	var lowest := INF
	for key: String in WEIGHTS:
		var lost := (100.0 - float(values[key])) * float(WEIGHTS[key])
		if float(values[key]) < 95.0 and -lost < lowest:
			lowest = -lost
			weakest = key
	return weakest


func _time_losses() -> float:
	return minf(speeding_seconds * SPEEDING_POINTS_PER_SECOND, SPEEDING_MAX_POINTS) \
		+ minf(off_road_seconds * OFF_ROAD_POINTS_PER_SECOND, OFF_ROAD_MAX_POINTS)


func _after_losses(lost: float) -> float:
	return 100.0 * exp(-lost / CATEGORY_SOFTNESS)


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 100.0
	var sum := 0.0
	for value in values:
		sum += value
	return sum / float(values.size())
