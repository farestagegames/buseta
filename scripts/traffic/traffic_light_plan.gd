class_name TrafficLightPlan
extends RefCounted
## Signal timing for one junction: two groups of approaches take turns. Pure
## logic, so red light rules can be tested exactly.

enum Light { GREEN, AMBER, RED }

const GREEN_SECONDS := 13.0
const AMBER_SECONDS := 3.0
const ALL_RED_SECONDS := 2.0
const CYCLE := (GREEN_SECONDS + AMBER_SECONDS + ALL_RED_SECONDS) * 2.0

var offset: float


func _init(start_offset: float = 0.0) -> void:
	offset = start_offset


func state(group: int, time: float) -> Light:
	var half := CYCLE / 2.0
	var phase := fmod(time + offset + (half if group == 1 else 0.0), CYCLE)
	if phase < GREEN_SECONDS:
		return Light.GREEN
	if phase < GREEN_SECONDS + AMBER_SECONDS:
		return Light.AMBER
	return Light.RED
