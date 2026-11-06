class_name BusDoors
extends RefCounted
## Door state machine. Doors only open at a standstill and the bus only drives
## with them fully closed.

signal state_changed(new_state: State)

enum State { CLOSED, OPENING, OPEN, CLOSING }

var state: State = State.CLOSED
var open_amount: float = 0.0 ## 0 closed, 1 fully open.

var _travel_time: float


func _init(travel_time: float) -> void:
	_travel_time = travel_time


func is_closed() -> bool:
	return state == State.CLOSED


func toggle(bus_is_stopped: bool) -> bool:
	match state:
		State.CLOSED, State.CLOSING:
			if not bus_is_stopped:
				return false
			_set_state(State.OPENING)
		State.OPEN, State.OPENING:
			_set_state(State.CLOSING)
	return true


func update(dt: float) -> void:
	if state == State.OPENING:
		open_amount = minf(open_amount + dt / _travel_time, 1.0)
		if open_amount >= 1.0:
			_set_state(State.OPEN)
	elif state == State.CLOSING:
		open_amount = maxf(open_amount - dt / _travel_time, 0.0)
		if open_amount <= 0.0:
			_set_state(State.CLOSED)


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)
