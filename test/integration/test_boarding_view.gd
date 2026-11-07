extends GutTest
## Watching people board from the driver's seat, and what happens on the bus.

const CITY := preload("res://scenes/main/city_shift.tscn")

var scene: CityShift
var bus: BusController
var crowd: PassengerCrowd
var system: RouteSystem
var visual: BusVisual
var camera: CameraRig
var payments: int = 0


func before_each() -> void:
	Profile.load_from("user://test_save_boarding.json")
	Profile.data = PlayerProfile.new()
	Profile.data.intro_done = true
	scene = CITY.instantiate()
	add_child_autofree(scene)
	bus = scene.get_node("Bus")
	crowd = scene.get_node("Crowd")
	system = scene.get_node("RouteSystem")
	visual = bus.get_node("Visual")
	camera = scene.get_node("CameraRig")
	payments = 0
	GameEvents.passenger_paid.connect(_on_paid)
	await wait_physics_frames(2)


func after_each() -> void:
	GameEvents.passenger_paid.disconnect(_on_paid)


func after_all() -> void:
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func _on_paid() -> void:
	payments += 1


func _cockpit() -> void:
	while camera.view_name() != "Cockpit":
		camera.next_view()


func _open_doors_at_first_stop() -> RouteStop:
	var stop: RouteStop = scene.route.stops[0]
	GameEvents.bus_relocate_requested.emit(stop.position + stop.forward() * bus.spec.body_centre_z(), stop.heading)
	await wait_physics_frames(3)
	GameEvents.door_toggle_requested.emit()
	return stop


## How far the camera has turned towards the side of the bus with the door.
func _look_towards_door() -> float:
	var look := -camera.global_transform.basis.z
	var right := bus.global_transform.basis.x * float(bus.spec.door_side)
	return look.dot(right)


func _wait_until(done: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0 and not done.call():
		await wait_physics_frames(6)
		left -= 0.1
	return done.call()


func test_cockpit_view_looks_ahead_until_the_doors_open() -> void:
	_cockpit()
	await wait_frames(3)
	assert_almost_eq(_look_towards_door(), 0.0, 0.1)


func test_cockpit_view_turns_to_the_doorway_while_the_doors_are_open() -> void:
	_cockpit()
	await _open_doors_at_first_stop()
	assert_true(await _wait_until(func() -> bool: return _look_towards_door() > 0.8, 4.0))


func test_cockpit_view_turns_back_once_the_doors_are_shut() -> void:
	_cockpit()
	await _open_doors_at_first_stop()
	await _wait_until(func() -> bool: return _look_towards_door() > 0.8, 4.0)
	GameEvents.door_toggle_requested.emit()
	assert_true(await _wait_until(func() -> bool: return _look_towards_door() < 0.1, 6.0))


func test_boarders_pay_inside_the_bus_then_take_a_seat() -> void:
	var stop := await _open_doors_at_first_stop()
	assert_true(await _wait_until(func() -> bool: return not crowd.aboard.is_empty(), 12.0), "Someone steps aboard")
	var walker: PassengerCrowd.Walker = crowd.aboard[0]
	assert_eq(walker.get_parent(), visual.cabin_floor(), "They ride with the bus")
	assert_true(await _wait_until(func() -> bool: return payments > 0, 6.0), "They pay at the machine")
	assert_almost_eq(walker.position.y, CabinLayout.FLOOR_HEIGHT, 0.02, "They climbed the step")
	assert_true(await _wait_until(func() -> bool: return crowd.aboard.is_empty() and crowd.boarding.is_empty() and system.session != null and system.session.is_complete(), 40.0))
	assert_eq(payments, stop.waiting, "Everyone pays once")
	assert_eq(visual.visible_riders(), stop.waiting)


func test_seat_stays_empty_until_its_passenger_reaches_it() -> void:
	await _open_doors_at_first_stop()
	await _wait_until(func() -> bool: return not crowd.boarding.is_empty(), 12.0)
	var seat: int = crowd.boarding[0].seat
	assert_gte(seat, 0)
	assert_true(visual.seat_is_held(seat))
	assert_true(await _wait_until(func() -> bool: return not visual.seat_is_held(seat), 12.0))


func test_shutting_the_doors_early_never_leaves_someone_chasing_the_bus() -> void:
	await _open_doors_at_first_stop()
	await _wait_until(func() -> bool: return not crowd.boarding.is_empty(), 12.0)
	GameEvents.door_toggle_requested.emit()
	assert_true(await _wait_until(func() -> bool: return crowd.boarding.is_empty(), 4.0))


func test_nobody_stays_standing_at_the_end_of_a_shift() -> void:
	await _open_doors_at_first_stop()
	await _wait_until(func() -> bool: return not crowd.aboard.is_empty(), 12.0)
	GameEvents.finish_shift_requested.emit()
	await wait_frames(2)
	assert_eq(crowd.aboard.size(), 0)


func test_people_getting_off_walk_out_through_the_door() -> void:
	crowd.getting_off.clear()
	GameEvents.onboard_changed.emit(3)
	await _open_doors_at_first_stop()
	GameEvents.passenger_alighted.emit(0)
	assert_eq(crowd.getting_off.size(), 1)
	assert_true(await _wait_until(func() -> bool: return crowd.getting_off.is_empty() and not crowd.leaving.is_empty(), 5.0))
	assert_eq(crowd.leaving[0].get_parent(), crowd, "Back on the pavement")


func test_people_left_at_a_stop_do_not_follow_the_bus_to_the_next_one() -> void:
	var first: RouteStop = scene.route.stops[0]
	GameEvents.bus_relocate_requested.emit(first.position + first.forward() * bus.spec.body_centre_z(), first.heading)
	await wait_physics_frames(3)
	assert_eq(crowd.waiting.size(), first.waiting)
	var second: RouteStop = scene.route.stops[1]
	system.runner.stop_index = 1
	GameEvents.bus_relocate_requested.emit(second.position + second.forward() * bus.spec.body_centre_z(), second.heading)
	await wait_physics_frames(3)
	assert_eq(crowd.waiting.size(), second.waiting)
	for walker in crowd.waiting:
		assert_lt(Vector2(walker.position.x, walker.position.z).distance_to(second.position), 20.0)
