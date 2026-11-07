extends GutTest
## Hailed stops, stop requests, vendors and fares as pure logic.


func _hail() -> RouteStop:
	var stop := RouteStop.new()
	stop.kind = RouteStop.Kind.HAIL
	stop.heading = 0.0
	stop.position = Vector2.ZERO
	return stop


func test_a_hail_forgives_stopping_a_little_early_or_late() -> void:
	var stop := _hail()
	assert_true(stop.is_aligned(Vector2(0.0, 9.0), 0.0), "Nine metres short")
	assert_true(stop.is_aligned(Vector2(0.0, -9.0), 0.0), "Nine metres past")
	assert_false(stop.is_aligned(Vector2(0.0, 14.0), 0.0))


func test_a_hail_needs_the_bus_near_the_kerb() -> void:
	assert_false(_hail().is_aligned(Vector2(-3.0, 0.0), 0.0))


func test_a_station_wants_a_tighter_stop_than_a_hail() -> void:
	var stop := _hail()
	stop.kind = RouteStop.Kind.STATION
	assert_false(stop.is_aligned(Vector2(0.0, 6.0), 0.0))
	assert_true(stop.is_aligned(Vector2(0.0, 3.0), 0.0))


func test_people_wait_on_the_pavement_whatever_the_stop() -> void:
	for kind: RouteStop.Kind in [RouteStop.Kind.BAY, RouteStop.Kind.HAIL, RouteStop.Kind.STATION]:
		var stop := _hail()
		stop.kind = kind
		assert_gt(stop.lateral() + stop.waiting_distance(), RoadNetwork.ROAD_HALF_WIDTH, str(kind))


func test_stopping_close_beside_a_hail_scores_full_accuracy() -> void:
	assert_eq(_hail().accuracy(Vector2(0.0, 2.0)), 1.0)


func test_ledger_knows_who_wants_off() -> void:
	var ledger := PassengerLedger.new(1, 6)
	ledger.onboard = [2, 3, 2]
	assert_eq(ledger.wanting_off(2), 2)
	assert_eq(ledger.wanting_off(4), 0)


func test_people_carried_past_their_stop_ride_on_to_the_next() -> void:
	var ledger := PassengerLedger.new(1, 6)
	ledger.onboard = [2, 3, 2]
	ledger.carry_on_past(2)
	assert_eq(ledger.wanting_off(2), 0)
	assert_eq(ledger.wanting_off(3), 3)


func test_nobody_is_carried_past_the_end_of_the_line() -> void:
	var ledger := PassengerLedger.new(1, 6)
	ledger.onboard = [6]
	ledger.carry_on_past(6)
	assert_eq(ledger.wanting_off(6), 1)


func test_ignoring_a_request_costs_more_than_ignoring_a_hail() -> void:
	var hail := ShiftScore.new()
	var request := ShiftScore.new()
	hail.add_ignored_hail(1)
	request.add_ignored_request(1)
	assert_gt(hail.categories()["satisfaction"], request.categories()["satisfaction"])


func test_a_vendor_cheers_people_up() -> void:
	var with_vendor := ShiftScore.new()
	var without := ShiftScore.new()
	with_vendor.add_ignored_request(3)
	without.add_ignored_request(3)
	with_vendor.add_vendor()
	assert_gt(with_vendor.categories()["satisfaction"], without.categories()["satisfaction"])
	assert_eq(int(with_vendor.counts["vendors"]), 1)


func test_a_vendor_on_a_perfect_shift_cannot_score_above_full_marks() -> void:
	var score := ShiftScore.new()
	score.add_vendor()
	assert_almost_eq(score.categories()["satisfaction"], 100.0, 0.01)
