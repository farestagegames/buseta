class_name PassengerLedger
extends RefCounted
## Who is on the bus and where they are getting off. Pure logic, seeded so a
## shift is repeatable.

const CAPACITY := 40

var onboard: Array[int] = [] ## Destination stop index of each passenger.
var carried_total: int = 0

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


## How many of the waiting passengers will fit. Does not board them yet.
func boardable(waiting: int) -> int:
	return mini(waiting, CAPACITY - onboard.size())


func board_one(stop_index: int) -> void:
	if stop_index >= _last_stop or onboard.size() >= CAPACITY:
		return
	onboard.append(_random.randi_range(stop_index + 1, _last_stop))
	carried_total += 1


## Anyone still on board when the shift ends.
func clear() -> void:
	onboard.clear()
