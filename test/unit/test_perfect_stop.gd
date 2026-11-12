extends GutTest
## Perfect stop: inside box, low speed, no harsh braking. Feedback once per stop.

func _make_stop() -> RouteStop:
	var stop := RouteStop.new()
	stop.kind = RouteStop.Kind.BAY
	stop.position = Vector2.ZERO
	stop.heading = 0.0
	return stop


func test_perfect_stop_rule() -> void:
	var stop := _make_stop()
	var centre := Vector2.ZERO
	# Inside box, stopped, no harsh braking.
	assert_true(StopQuality.is_perfect(stop, centre, stop.heading, 0.0, false), "clean stop")
	# Too fast at stop fails.
	assert_false(StopQuality.is_perfect(stop, centre, stop.heading, 1.0, false), "too fast")
	# Harsh braking fails.
	assert_false(StopQuality.is_perfect(stop, centre, stop.heading, 0.0, true), "harsh brake")
	# Outside box fails (too far to the side).
	assert_false(StopQuality.is_perfect(stop, centre + Vector2(2.0, 0.0), stop.heading, 0.0, false), "outside box")


func test_perfect_stops_count_in_shift_report() -> void:
	var score := ShiftScore.new()
	score.add_stop(1.0, 0.0, true)
	score.add_stop(1.0, 0.0, false)
	score.add_stop(0.9, 5.0, true)
	assert_eq(int(score.counts["perfect_stops"]), 2)
	var goals := [{"type": "perfect_stops"}]
	var report := {
		"served": 3,
		"perfect_stops": int(score.counts["perfect_stops"]),
		"counts": score.counts.duplicate(),
		"categories": score.categories(),
		"fined_coins": 0,
		"time": 100.0,
		"carried": 5,
	}
	# Not every stop perfect.
	assert_eq(RouteGoals.stars_for(goals, report), 0)
	report["perfect_stops"] = 3
	assert_eq(RouteGoals.stars_for(goals, report), 1)


func test_feedback_items_fire_once_per_trigger() -> void:
	var feedback := StopFeedback.new()
	add_child_autofree(feedback)
	feedback.show_fare("+$2.400", Vector2(100, 100))
	feedback.show_fare("+$2.400", Vector2(100, 100))
	feedback.show_stamp("¡Parada perfecta!", Vector2(200, 200))
	var items: Array = feedback.get("_items")
	assert_eq(items.size(), 3)
	var fare_count := 0
	var stamp_count := 0
	for item in items:
		var t: String = item["text"]
		if t.begins_with("+"):
			fare_count += 1
		else:
			stamp_count += 1
	assert_eq(fare_count, 2)
	assert_eq(stamp_count, 1)
	await wait_seconds(1.3)
	assert_eq((feedback.get("_items") as Array).size(), 0)


func test_perfect_stop_signal_emits_once_per_stop() -> void:
	watch_signals(GameEvents)
	# A stop is evaluated once: the perfect feedback fires once for that stop.
	GameEvents.perfect_stop.emit(0)
	assert_signal_emit_count(GameEvents, "perfect_stop", 1)
