extends GutTest
## Route goals: evaluation, stars and migration.

func _report() -> Dictionary:
	return {
		"time": 200.0,
		"served": 3,
		"carried": 12,
		"perfect_stops": 3,
		"fined_coins": 0,
		"counts": {"fines": 0, "collisions": 0, "knocked": 0, "vendors": 2, "missed_stops": 0, "perfect_stops": 3},
		"categories": {"satisfaction": 85.0},
	}


func test_goals_evaluate_correctly_from_a_fake_shift_report() -> void:
	var goals := [
		{"type": "finish_under", "value": 240},
		{"type": "no_collisions"},
		{"type": "vendors", "value": 2},
	]
	var result := RouteGoals.evaluate(goals, _report())
	assert_eq(result.size(), 3)
	assert_true(result[0]["met"])
	assert_true(result[1]["met"])
	assert_true(result[2]["met"])

	var bad := _report()
	bad["time"] = 300.0
	bad["counts"]["collisions"] = 1
	bad["counts"]["vendors"] = 1
	var failed := RouteGoals.evaluate(goals, bad)
	assert_false(failed[0]["met"])
	assert_false(failed[1]["met"])
	assert_false(failed[2]["met"])


func test_stars_equal_goals_met() -> void:
	var goals := [{"type": "no_collisions"}, {"type": "no_fines"}, {"type": "no_knocked"}]
	var report := _report()
	assert_eq(RouteGoals.stars_for(goals, report), 3)
	report["counts"]["collisions"] = 2
	assert_eq(RouteGoals.stars_for(goals, report), 2)
	report["counts"]["fines"] = 1
	report["fined_coins"] = 500
	assert_eq(RouteGoals.stars_for(goals, report), 1)


func test_save_migration_maps_old_stars_to_three() -> void:
	assert_eq(RouteGoals.migrate_best_stars(5), 3)
	assert_eq(RouteGoals.migrate_best_stars(4), 2)
	assert_eq(RouteGoals.migrate_best_stars(3), 2)
	assert_eq(RouteGoals.migrate_best_stars(2), 1)
	assert_eq(RouteGoals.migrate_best_stars(1), 1)
	assert_eq(RouteGoals.migrate_best_stars(0), 0)


func test_hud_checklist_updates() -> void:
	var hud := GoalsHud.new()
	add_child_autofree(hud)
	var goals := [{"type": "no_collisions"}, {"type": "finish_under", "value": 240}]
	hud.set_goals(goals)
	assert_true(hud.visible)
	hud.update_status(_report())
	# no_collisions met, finish_under met (200 <= 240)
	hud.queue_redraw()
	await wait_physics_frames(1)
	assert_true(hud.visible)
	var bad := _report()
	bad["counts"]["collisions"] = 1
	bad["time"] = 300.0
	hud.update_status(bad)
	await wait_physics_frames(1)
	assert_true(hud.visible)


func test_challenges_with_star_conditions_still_offered() -> void:
	var profile := PlayerProfile.new()
	var catalog := Catalog.new()
	profile.grant_free_items(catalog)
	profile.repair_choices(catalog)
	var list: Array = DailyChallenge.load_list()
	var picked := DailyChallenge.for_date("2026-11-12", list, profile)
	assert_false(picked.is_empty())
	# Star conditions in data now use up to 3 stars and remain passable.
	var star_challenge := {"id": "s", "text": "x", "min_stars": 3}
	assert_true(DailyChallenge.is_available(star_challenge, profile))
	assert_true(DailyChallenge.is_passed(star_challenge, {"stars": 3}))
	assert_false(DailyChallenge.is_passed(star_challenge, {"stars": 2}))
