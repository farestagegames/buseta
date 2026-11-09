extends GutTest
## Board at the front, get off at the back.

const BUSES := ["buseta_8", "midi_10", "city_12", "articulado_18"]


func _spec(id: String) -> BusSpec:
	return load(Profile.catalog.find(Catalog.BUSES, id)["file"]) as BusSpec


func test_every_bus_but_the_chiva_has_a_rear_door() -> void:
	for id: String in BUSES:
		assert_true(_spec(id).has_rear_door(), id)
	assert_false(_spec("chiva").has_rear_door(), "The chiva has an open step")


func test_the_rear_door_is_behind_the_front_door_and_ahead_of_the_wheels() -> void:
	for id: String in BUSES:
		var spec := _spec(id)
		var front_door_end := -(spec.wheelbase + spec.front_overhang) + spec.door_offset + BusVisual.DOOR_WIDTH
		assert_gt(spec.rear_door_near_z(), front_door_end + 1.0, "%s: room between the doors" % id)
		assert_lt(spec.rear_door_far_z(), -0.6, "%s: clear of the rear wheel arch" % id)


func test_people_board_at_the_front_and_leave_by_the_rear() -> void:
	for id: String in BUSES:
		var spec := _spec(id)
		var cabin := CabinLayout.new(spec)
		var board := cabin.boarding_path(Vector3(0.5, 0.97, 0.0))
		var leave := cabin.alighting_path()
		assert_lt(board[0].z, spec.rear_door_near_z() - 1.0, "%s: boarding starts at the front door" % id)
		var out: Vector3 = leave[leave.size() - 1]
		assert_between(out.z, spec.rear_door_near_z(), spec.rear_door_far_z(), "%s: gets off by the rear door" % id)
		assert_gt(out.x * float(spec.door_side), spec.body_width / 2.0, "%s: ends outside on the kerb side" % id)


func test_without_a_rear_door_people_leave_by_the_front() -> void:
	var spec := _spec("chiva")
	var cabin := CabinLayout.new(spec)
	assert_eq(cabin.alighting_path()[cabin.alighting_path().size() - 1], cabin.kerb)
