extends GutTest
## The celebratory payout: coin categories add up, the skip lands on the final
## state, the main button label follows the stars, and it finishes under 6 seconds.

func before_each() -> void:
	Profile.load_from("user://test_save_payout.json")
	Profile.data = PlayerProfile.new()


func after_all() -> void:
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func _report(stars: int = 3) -> Dictionary:
	return {
		"stars": stars, "time": 200.0, "score": 100, "coins": 451, "carried": 12, "fares": 348,
		"coin_breakdown": {"fares": 36, "tips": 201, "clean": 50, "on_time": 164, "fines": 0, "total": 451},
		"goals": [
			{"text": "Finish under 5:00", "met": true},
			{"text": "No collisions", "met": true},
			{"text": "Every stop perfect", "met": true},
		],
		"categories": {"punctuality": 90.0, "accuracy": 90.0, "smoothness": 90.0, "rules": 90.0, "satisfaction": 90.0},
		"counts": {"collisions": 0},
		"details": "12 passengers carried", "tip": "", "fined_coins": 0,
		"rewards": {"coins": 451, "xp": 151, "xp_before": 0, "xp_after": 151, "levelled_up": false,
			"level": 1, "new_best": true, "daily_coins": 0, "achievements": []},
	}


func test_coin_breakdown_sums_exactly_to_the_reward() -> void:
	var score := ShiftScore.new()
	for i in 7:
		score.add_stop(1.0, 0.0)
	score.add_fine(120)
	for carried: int in [0, 1, 12, 34]:
		for stars: int in [0, 1, 3]:
			var breakdown := score.coin_breakdown(carried, stars)
			var total := int(breakdown["total"])
			assert_eq(total, score.coins(carried, stars), "breakdown total matches coins()")
			var line_sum := int(breakdown["fares"]) + int(breakdown["tips"]) + int(breakdown["clean"]) \
				+ int(breakdown["on_time"]) - int(breakdown["fines"])
			assert_eq(line_sum, total, "lines sum exactly to the total")
			assert_true(int(breakdown["fares"]) >= 0 and int(breakdown["tips"]) >= 0 \
				and int(breakdown["clean"]) >= 0 and int(breakdown["on_time"]) >= 0)


func test_fines_cannot_take_the_total_below_zero() -> void:
	var score := ShiftScore.new()
	score.add_stop(0.0, 900.0)
	score.add_fine(100000)
	var breakdown := score.coin_breakdown(0, 0)
	assert_eq(int(breakdown["total"]), 0)
	assert_eq(score.coins(0, 0), 0)


func test_skip_shows_the_final_state() -> void:
	var panel := ShiftEndPanel.new()
	add_child_autofree(panel)
	await wait_physics_frames(2)
	panel.show_report(_report())
	panel.skip()
	assert_true(panel.is_finished())
	assert_eq(panel._total_label.text, Country.pack.money(int(_report()["coins"])))
	for j in 3:
		assert_true(panel._star_labels[j].visible, "star %d shown" % j)
	assert_true(panel.menu_button.visible)
	assert_true(panel.again_button.visible)


func test_button_label_depends_on_stars() -> void:
	var panel := ShiftEndPanel.new()
	add_child_autofree(panel)
	await wait_physics_frames(2)
	panel.show_report(_report(3))
	assert_eq(panel.again_button.text, tr("Next route"))
	panel.show_report(_report(2))
	assert_eq(panel.again_button.text, tr("Retry for ★★★"))


func test_sequence_finishes_under_six_seconds() -> void:
	var panel := ShiftEndPanel.new()
	add_child_autofree(panel)
	await wait_physics_frames(2)
	panel.show_report(_report())
	var elapsed := 0.0
	var step := 1.0 / 60.0
	while elapsed < 6.0 and not panel.is_finished():
		panel._process(step)
		elapsed += step
	assert_true(panel.is_finished(), "payout finishes within 6 s of game time")


func test_a_police_stop_shows_a_failed_route_in_red() -> void:
	var panel := ShiftEndPanel.new()
	add_child_autofree(panel)
	await wait_physics_frames(2)
	var report := _report(0)
	report["police_stopped"] = "speeding"
	report["police_stops"] = 3
	panel.show_report(report)
	assert_eq(panel._headline.text, tr("Route failed: stopped by the police %d times") % 3)
	assert_eq(panel._headline.get_theme_color("font_color"), ShiftEndPanel.FAILED_COLOUR)
	assert_eq(panel.again_button.text, tr("Play again"))
	panel.show_report(_report())
	assert_eq(panel._headline.get_theme_color("font_color"), Color.WHITE, "a normal shift is white again")
