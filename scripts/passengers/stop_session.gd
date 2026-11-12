class_name StopSession
extends RefCounted
## Runs one stop while the doors are fully open: people get off by the rear door
## and on by the front at the same time, each side one person at a time (the owner
## found waiting for everyone off too slow). The bus can leave early, which leaves
## people behind.

signal passenger_alighted
signal passenger_boarded

enum Stage { ALIGHTING, BOARDING, COMPLETE }

const ALIGHT_SECONDS := 0.9
const BOARD_SECONDS := 1.4 ## Includes paying the driver.
## Gives the queue time to reach the door before the first person boards.
const QUEUE_SECONDS := 1.5

var stage: Stage = Stage.ALIGHTING
var alighting_left: int
var boarding_left: int

var _timer: float = 0.0 ## Until the next person gets off.
var _board_timer: float = 0.0 ## Until the next person gets on.
var _queue_timer: float = QUEUE_SECONDS


func _init(alighting: int, boarding: int) -> void:
	alighting_left = alighting
	boarding_left = boarding
	_timer = ALIGHT_SECONDS
	_update_stage()


func is_complete() -> bool:
	return stage == Stage.COMPLETE


func update(dt: float, doors_open: bool) -> void:
	if not doors_open or is_complete():
		return
	if alighting_left > 0:
		_timer -= dt
		if _timer <= 0.0:
			_timer += ALIGHT_SECONDS
			alighting_left -= 1
			passenger_alighted.emit()
	if boarding_left > 0:
		_queue_timer -= dt
		_board_timer -= dt
		if _queue_timer <= 0.0 and _board_timer <= 0.0:
			_board_timer = BOARD_SECONDS
			boarding_left -= 1
			passenger_boarded.emit()
	_update_stage()


func _update_stage() -> void:
	if alighting_left > 0:
		stage = Stage.ALIGHTING
	elif boarding_left > 0:
		stage = Stage.BOARDING
	else:
		stage = Stage.COMPLETE
