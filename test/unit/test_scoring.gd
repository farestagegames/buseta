extends GutTest

const DT := 1.0 / 60.0

var score: ShiftScore


func before_each() -> void:
	score = ShiftScore.new()


func _clean_stops(count: int = 7) -> void:
	for i in count:
		score.add_stop(1.0, 0.0)


func test_perfect_shift_is_five_stars() -> void:
	_clean_stops()
	assert_eq(score.total(), 100)
	assert_eq(score.stars(), 5)


func test_on_time_window() -> void:
	assert_true(ShiftSchedule.is_on_time(0.0))
	assert_true(ShiftSchedule.is_on_time(25.0))
	assert_true(ShiftSchedule.is_on_time(-25.0))
	assert_false(ShiftSchedule.is_on_time(60.0))
	assert_false(ShiftSchedule.is_on_time(-40.0))


func test_punctuality_falls_with_lateness() -> void:
	assert_eq(ShiftSchedule.punctuality_score(25.0), 100.0)
	assert_almost_eq(ShiftSchedule.punctuality_score(105.0), 50.0, 0.01)
	assert_eq(ShiftSchedule.punctuality_score(600.0), 0.0)


func test_schedule_measures_lateness() -> void:
	var schedule := ShiftSchedule.new(PackedFloat32Array([60.0, 120.0]))
	assert_eq(schedule.seconds_late(1, 150.0), 30.0)
	assert_eq(schedule.seconds_late(0, 45.0), -15.0)


func test_status_text() -> void:
	assert_eq(ShiftSchedule.status_text(10.0), "On time")
	assert_eq(ShiftSchedule.status_text(65.0), "1:05 late")
	assert_eq(ShiftSchedule.status_text(-90.0), "1:30 early")


func test_collision_costs_rule_points_and_satisfaction() -> void:
	_clean_stops()
	score.add_collision(4.0)
	var values := score.categories()
	assert_gt(float(values["rules"]), 80.0)
	assert_lt(float(values["rules"]), 95.0)
	assert_lt(float(values["satisfaction"]), 100.0)


func test_harder_collision_costs_more_but_is_capped() -> void:
	var soft := ShiftScore.new()
	var hard := ShiftScore.new()
	var extreme := ShiftScore.new()
	soft.add_collision(1.0)
	hard.add_collision(8.0)
	extreme.add_collision(50.0)
	assert_lt(float(hard.categories()["rules"]), float(soft.categories()["rules"]))
	var capped := ShiftScore.new()
	capped.add_collision(ShiftScore.COLLISION_MAX_POINTS * 4.0)
	assert_eq(float(extreme.categories()["rules"]), float(capped.categories()["rules"]))


func test_off_road_costs_more_than_a_kerb_strike() -> void:
	var kerb := ShiftScore.new()
	var pavement := ShiftScore.new()
	kerb.add_kerb()
	for i in 300:
		pavement.add_time(DT, false, true)
	assert_lt(float(pavement.categories()["rules"]), float(kerb.categories()["rules"]))
	assert_almost_eq(pavement.off_road_seconds, 5.0, 0.05)


func test_red_light_costs_more_than_a_knocked_cone() -> void:
	assert_gt(ShiftScore.RED_LIGHT_POINTS, ShiftScore.KNOCKED_POINTS * 3.0)


func test_speeding_costs_points_over_time() -> void:
	for i in 600:
		score.add_time(DT, true, false)
	assert_lt(float(score.categories()["rules"]), 100.0)
	assert_gt(float(score.categories()["rules"]), 90.0, "Ten seconds should not be a disaster")


func test_one_bump_counts_once() -> void:
	assert_true(score.add_jolt())
	assert_false(score.add_jolt(), "Rear axle over the same bump")
	for i in 90:
		score.add_time(DT, false, false)
	assert_true(score.add_jolt())
	assert_eq(int(score.counts["jolts"]), 2)


func test_missed_stop_hurts_punctuality_and_accuracy() -> void:
	_clean_stops(3)
	score.add_missed_stop()
	var values := score.categories()
	assert_almost_eq(float(values["accuracy"]), 75.0, 0.01)
	assert_almost_eq(float(values["punctuality"]), 75.0, 0.01)


func test_leaving_people_behind_upsets_satisfaction() -> void:
	score.add_left_behind(3)
	assert_lt(float(score.categories()["satisfaction"]), 100.0)
	assert_eq(int(score.counts["left_behind"]), 3)


func test_losses_level_off_rather_than_hitting_zero() -> void:
	for i in 6:
		score.add_collision(4.0)
	var after_six := float(score.categories()["rules"])
	assert_gt(after_six, 40.0, "Six crashes should hurt but not wipe out the category")
	for i in 100:
		score.add_red_light()
	assert_gte(float(score.categories()["rules"]), 0.0)


func test_a_rough_but_finished_shift_earns_a_fair_score() -> void:
	_clean_stops()
	for i in 3:
		score.add_collision(4.0)
	for i in 6:
		score.add_knocked()
		score.add_kerb()
	for i in 4:
		score.add_harsh_brake()
		score.add_jolt()
		score.add_time(2.0, false, false)
	score.add_red_light()
	assert_gt(score.total(), 70, "A messy but completed shift should still reach 3 or 4 stars")


func test_star_bands() -> void:
	var expected := {100: 5, 88: 5, 87: 4, 70: 4, 69: 3, 50: 3, 49: 2, 35: 2, 34: 1, 0: 1}
	for points: int in expected:
		var earned := 1
		for threshold in ShiftScore.STAR_THRESHOLDS:
			if points >= threshold:
				earned += 1
		assert_eq(earned, expected[points], "%d points" % points)


func test_coins_reward_score_passengers_and_stars() -> void:
	_clean_stops()
	var rich := score.coins(30)
	assert_eq(rich, 50 + 200 + 90 + 200)
	var poor := ShiftScore.new()
	poor.add_stop(0.0, 900.0)
	assert_lt(poor.coins(0), rich)


func test_weights_add_up() -> void:
	var sum := 0.0
	for key: String in ShiftScore.WEIGHTS:
		sum += float(ShiftScore.WEIGHTS[key])
	assert_almost_eq(sum, 1.0, 0.001)


func test_monitor_needs_a_sustained_stop_to_count_as_harsh() -> void:
	var monitor := DrivingMonitor.new()
	watch_signals(monitor)
	monitor.update(-4.0, DT)
	assert_signal_not_emitted(monitor, "harsh_brake")
	for i in 20:
		monitor.update(-4.0, DT)
	assert_signal_emit_count(monitor, "harsh_brake", 1)


func test_monitor_ignores_normal_braking() -> void:
	var monitor := DrivingMonitor.new()
	watch_signals(monitor)
	for i in 120:
		monitor.update(-2.0, DT)
	assert_signal_not_emitted(monitor, "harsh_brake")


func test_monitor_counts_one_event_per_hard_stop() -> void:
	var monitor := DrivingMonitor.new()
	watch_signals(monitor)
	for i in 120:
		monitor.update(-3.5, DT)
	assert_signal_emit_count(monitor, "harsh_brake", 1)
	for i in 10:
		monitor.update(0.0, DT)
	for i in 20:
		monitor.update(-3.5, DT)
	assert_signal_emit_count(monitor, "harsh_brake", 2)


func test_monitor_sees_harsh_acceleration() -> void:
	var monitor := DrivingMonitor.new()
	watch_signals(monitor)
	for i in 180:
		monitor.update(1.5, DT)
	assert_signal_emit_count(monitor, "harsh_accel", 1)


func test_normal_pulling_away_is_not_harsh() -> void:
	var monitor := DrivingMonitor.new()
	watch_signals(monitor)
	for i in 600:
		monitor.update(1.2, DT)
	for i in 100:
		monitor.update(1.5, DT)
	assert_signal_not_emitted(monitor, "harsh_accel")


func test_harsh_acceleration_cannot_repeat_straight_away() -> void:
	var monitor := DrivingMonitor.new()
	watch_signals(monitor)
	for launch in 3:
		for i in 180:
			monitor.update(1.5, DT)
		for i in 60:
			monitor.update(0.0, DT)
	assert_signal_emit_count(monitor, "harsh_accel", 1)


func test_speeding_has_a_small_grace() -> void:
	assert_false(DrivingMonitor.is_speeding(50.0 / 3.6, 50.0))
	assert_false(DrivingMonitor.is_speeding(54.0 / 3.6, 50.0))
	assert_true(DrivingMonitor.is_speeding(56.0 / 3.6, 50.0))
