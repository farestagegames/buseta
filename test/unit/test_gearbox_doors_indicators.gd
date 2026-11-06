extends GutTest

const DT := 1.0 / 60.0


func test_gearbox_starts_in_first() -> void:
	var box := AutomaticGearbox.new(BusSpec.new())
	assert_eq(box.gear, 1)


func test_gearbox_shifts_up_with_speed_and_cuts_drive() -> void:
	var box := AutomaticGearbox.new(BusSpec.new())
	box.update(5.0, DT)
	assert_eq(box.gear, 2)
	assert_true(box.is_shifting())


func test_gearbox_reaches_top_gear() -> void:
	var spec := BusSpec.new()
	var box := AutomaticGearbox.new(spec)
	for i in 300:
		box.update(19.0, DT)
	assert_eq(box.gear, spec.gear_top_speeds.size())


func test_gearbox_does_not_hunt_around_a_shift_point() -> void:
	var box := AutomaticGearbox.new(BusSpec.new())
	box.update(5.0, 1.0)
	box.update(4.5, 1.0)
	assert_eq(box.gear, 2, "Slowing slightly must not drop a gear")


func test_gearbox_shifts_down_when_slowing() -> void:
	var box := AutomaticGearbox.new(BusSpec.new())
	box.update(5.0, 1.0)
	box.update(1.0, 1.0)
	assert_eq(box.gear, 1)


func test_doors_open_only_when_stopped() -> void:
	var doors := BusDoors.new(1.0)
	assert_false(doors.toggle(false))
	assert_true(doors.is_closed())
	assert_true(doors.toggle(true))
	assert_eq(doors.state, BusDoors.State.OPENING)


func test_doors_complete_a_full_cycle() -> void:
	var doors := BusDoors.new(1.0)
	doors.toggle(true)
	doors.update(1.1)
	assert_eq(doors.state, BusDoors.State.OPEN)
	assert_eq(doors.open_amount, 1.0)
	doors.toggle(true)
	assert_false(doors.is_closed(), "Doors still closing count as open")
	doors.update(1.1)
	assert_true(doors.is_closed())


func test_doors_can_reverse_midway() -> void:
	var doors := BusDoors.new(1.0)
	doors.toggle(true)
	doors.update(0.5)
	doors.toggle(true)
	doors.update(0.25)
	assert_almost_eq(doors.open_amount, 0.25, 0.001)


func test_doors_announce_state_changes() -> void:
	var doors := BusDoors.new(1.0)
	watch_signals(doors)
	doors.toggle(true)
	assert_signal_emitted(doors, "state_changed")


func test_indicator_toggles_on_and_off() -> void:
	var ind := BusIndicators.new()
	ind.toggle(BusIndicators.TurnSide.LEFT)
	assert_eq(ind.side, BusIndicators.TurnSide.LEFT)
	ind.toggle(BusIndicators.TurnSide.LEFT)
	assert_eq(ind.side, BusIndicators.TurnSide.OFF)


func test_indicator_switches_side_directly() -> void:
	var ind := BusIndicators.new()
	ind.toggle(BusIndicators.TurnSide.LEFT)
	ind.toggle(BusIndicators.TurnSide.RIGHT)
	assert_eq(ind.side, BusIndicators.TurnSide.RIGHT)


func test_indicator_blinks() -> void:
	var ind := BusIndicators.new()
	ind.toggle(BusIndicators.TurnSide.RIGHT)
	ind.update(0.0, 0.0, 0.1)
	assert_true(ind.lamp_on)
	ind.update(0.0, 0.0, 0.4)
	assert_false(ind.lamp_on)


func test_indicator_cancels_after_a_finished_turn() -> void:
	var ind := BusIndicators.new()
	ind.toggle(BusIndicators.TurnSide.LEFT)
	ind.update(deg_to_rad(90.0), deg_to_rad(20.0), DT)
	assert_eq(ind.side, BusIndicators.TurnSide.LEFT, "Stays on while the wheel is turned")
	ind.update(0.0, 0.0, DT)
	assert_eq(ind.side, BusIndicators.TurnSide.OFF)


func test_indicator_ignores_turning_the_other_way() -> void:
	var ind := BusIndicators.new()
	ind.toggle(BusIndicators.TurnSide.LEFT)
	ind.update(deg_to_rad(-90.0), 0.0, DT)
	assert_eq(ind.side, BusIndicators.TurnSide.LEFT)
