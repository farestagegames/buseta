class_name PassengerLedger
extends RefCounted
## Who is on the bus and where they are getting off. Pure logic, seeded so a
## shift is repeatable.

const CAPACITY := 40

var capacity: int = CAPACITY
var onboard: Array[int] = [] ## Destination stop index of each passenger.
var carried_total: int = 0
## Longest ride in stops, or 0 for any stop to the end. The endless route sets it.
var max_ride: int = 0

var _random := RandomNumberGenerator.new()
var _last_stop: int


## last_passenger_stop is the final stop where anyone can get off.
func _init(random_seed: int, last_passenger_stop: int) -> void:
	_random.seed = random_seed
	_last_stop = last_passenger_stop


func count() -> int:
	return onboard.size()


## How many get off here. Removes them from the bus.
func alight_at(stop_index: int) -> int:
	var staying: Array[int] = []
	for destination in onboard:
		if destination > stop_index:
			staying.append(destination)
	var leaving := onboard.size() - staying.size()
	onboard = staying
	return leaving


## How many want to get off at this stop.
func wanting_off(stop_index: int) -> int:
	return onboard.count(stop_index)


## The bus went past someone's stop, so they ride on to the next one.
func carry_on_past(stop_index: int) -> void:
	for i in onboard.size():
		if onboard[i] == stop_index:
			onboard[i] = mini(stop_index + 1, _last_stop)


## How many of the waiting passengers will fit. Does not board them yet.
func boardable(waiting: int) -> int:
	return mini(waiting, capacity - onboard.size())


func board_one(stop_index: int) -> void:
	if stop_index >= _last_stop or onboard.size() >= capacity:
		return
	var furthest := _last_stop if max_ride <= 0 else mini(_last_stop, stop_index + max_ride)
	onboard.append(_random.randi_range(stop_index + 1, furthest))
	carried_total += 1


## Anyone still on board when the shift ends.
func clear() -> void:
	onboard.clear()
