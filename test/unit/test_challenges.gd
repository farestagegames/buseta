extends GutTest
## Daily challenges with conditions, streaks, and achievements with rewards.

var profile: PlayerProfile
var catalog: Catalog


func before_each() -> void:
	profile = PlayerProfile.new()
	catalog = Catalog.new()


func _report(stars: int = 4, counts: Dictionary = {}) -> Dictionary:
	var all := {"collisions": 0, "harsh_brakes": 0, "kerbs": 0, "indicators": 0, "red_lights": 0,
		"knocked": 0, "jolts": 0, "vendors": 0, "ignored_hails": 0}
	all.merge(counts, true)
	return {"score": 80, "stars": stars, "coins": 100, "carried": 20, "fares": 580, "time_of_day": "manana", "counts": all}


func _ids(list: Array) -> Array:
	return list.map(func(item: Dictionary) -> String: return item["id"])


func test_all_conditions_must_hold() -> void:
	var challenge := {"route": "troncal", "min_stars": 3}
	assert_true(DailyChallenge.is_passed(challenge, _report(3), {"route": "troncal"}))
	assert_false(DailyChallenge.is_passed(challenge, _report(3), {"route": "route_01"}), "Wrong route")
	assert_false(DailyChallenge.is_passed(challenge, _report(2), {"route": "troncal"}), "Too few stars")


func test_bus_and_time_conditions() -> void:
	assert_true(DailyChallenge.is_passed({"bus": "chiva", "counter": "collisions", "max": 0}, _report(), {"bus": "chiva"}))
	assert_false(DailyChallenge.is_passed({"bus": "chiva", "counter": "collisions", "max": 0}, _report(), {"bus": "buseta_8"}))
	var night := _report()
	night["time_of_day"] = "noche"
	assert_true(DailyChallenge.is_passed({"time": "noche", "counter": "collisions", "max": 0}, night))
	assert_false(DailyChallenge.is_passed({"time": "noche", "counter": "collisions", "max": 0}, _report()))


func test_minimum_counts_read_counts_and_report_numbers() -> void:
	assert_true(DailyChallenge.is_passed({"counter": "vendors", "min": 2}, _report(4, {"vendors": 2})))
	assert_false(DailyChallenge.is_passed({"counter": "vendors", "min": 2}, _report(4, {"vendors": 1})))
	assert_true(DailyChallenge.is_passed({"counter": "carried", "min": 20}, _report()))
	assert_false(DailyChallenge.is_passed({"counter": "carried", "min": 30}, _report()))


func test_challenges_for_things_not_owned_are_not_offered() -> void:
	var list := [{"id": "ola", "text": "x", "route": "troncal", "min_stars": 3}, {"id": "any", "text": "x", "min_stars": 3}]
	for day in range(1, 29):
		assert_eq(DailyChallenge.for_date("2026-11-%02d" % day, list, profile)["id"], "any")
	profile.owned[Catalog.ROUTES].append("troncal")
	var seen := {}
	for day in range(1, 29):
		seen[DailyChallenge.for_date("2026-11-%02d" % day, list, profile)["id"]] = true
	assert_true(seen.has("ola"), "Offered once the route is owned")


func test_level_gated_challenges_wait_for_the_level() -> void:
	var list := [{"id": "night", "text": "x", "time": "noche", "level": 4, "counter": "collisions", "max": 0}]
	assert_false(DailyChallenge.is_available(list[0], profile))
	profile.xp = DriverLevel.xp_for_level(4)
	assert_true(DailyChallenge.is_available(list[0], profile))


func test_day_before_crosses_months_and_years() -> void:
	assert_eq(DailyChallenge.day_before("2026-11-08"), "2026-11-07")
	assert_eq(DailyChallenge.day_before("2026-03-01"), "2026-02-28")
	assert_eq(DailyChallenge.day_before("2027-01-01"), "2026-12-31")


func test_streak_grows_on_consecutive_days_and_resets_after_a_gap() -> void:
	var list := [{"id": "x", "text": "x", "counter": "collisions", "max": 0}]
	var day1 := ShiftRewards.apply(profile, _report(), "route_01", "2026-11-06", list, [], "buseta_8")
	var day2 := ShiftRewards.apply(profile, _report(), "route_01", "2026-11-07", list, [], "buseta_8")
	assert_eq(int(day1["daily_coins"]), DailyChallenge.REWARD_COINS)
	assert_eq(int(day2["daily_coins"]), DailyChallenge.REWARD_COINS + DailyChallenge.STREAK_BONUS)
	assert_eq(int(day2["daily_streak"]), 2)
	var after_gap := ShiftRewards.apply(profile, _report(), "route_01", "2026-11-10", list, [], "buseta_8")
	assert_eq(int(after_gap["daily_streak"]), 1)
	assert_eq(int(after_gap["daily_coins"]), DailyChallenge.REWARD_COINS)
	assert_eq(int(profile.stats["best_daily_streak"]), 2)
	assert_eq(int(profile.stats["dailies"]), 3)


func test_streak_reward_is_capped() -> void:
	assert_eq(DailyChallenge.reward_for(50), DailyChallenge.reward_for(DailyChallenge.MAX_STREAK_DAYS))
	assert_gt(DailyChallenge.reward_for(2), DailyChallenge.reward_for(1))


func test_shift_counts_route_bus_vendors_and_fares() -> void:
	ShiftRewards.apply(profile, _report(4, {"vendors": 2}), "troncal", "2026-11-06", [], [], "articulado_18")
	assert_eq(int(profile.stats["route:troncal"]), 1)
	assert_eq(int(profile.stats["bus:articulado_18"]), 1)
	assert_eq(int(profile.stats["vendors"]), 2)
	assert_eq(int(profile.stats["fares"]), 580)
	assert_eq(int(profile.stats["routes_driven"]), 1)


func test_route_and_bus_stats_survive_saving() -> void:
	profile.stats["route:troncal"] = 3
	profile.stats["bus:chiva"] = 2
	profile.daily_streak = 4
	var copy := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	assert_eq(int(copy.stats["route:troncal"]), 3)
	assert_eq(int(copy.stats["bus:chiva"]), 2)
	assert_eq(copy.daily_streak, 4)
	assert_false(PlayerProfile.from_dict({"stats": {"junk": 5}}).stats.has("junk"), "Unknown stats are dropped")


func test_achievement_rewards_are_paid_once() -> void:
	var list := [{"id": "first", "name": "x", "description": "x", "stat": "shifts", "target": 1, "reward": 150}]
	var first := ShiftRewards.apply(profile, _report(), "route_01", "2026-11-06", [], list, "buseta_8")
	assert_eq(int(first["achievement_coins"]), 150)
	assert_eq(profile.coins, 100 + 150)
	var second := ShiftRewards.apply(profile, _report(), "route_01", "2026-11-06", [], list, "buseta_8")
	assert_eq(int(second["achievement_coins"]), 0)


func test_route_achievement_counts_shifts_on_that_route() -> void:
	var list := [{"id": "ola", "name": "x", "description": "x", "stat": "route:troncal", "target": 2}]
	ShiftRewards.apply(profile, _report(), "troncal", "2026-11-06", [], list, "articulado_18")
	assert_false(profile.achievements.has("ola"))
	ShiftRewards.apply(profile, _report(), "route_01", "2026-11-06", [], list, "buseta_8")
	assert_false(profile.achievements.has("ola"), "Other routes do not count")
	ShiftRewards.apply(profile, _report(), "troncal", "2026-11-06", [], list, "articulado_18")
	assert_true(profile.achievements.has("ola"))


func test_shipped_challenges_and_achievements_validate() -> void:
	assert_eq(Country.pack.validate(), [] as Array[String])
	assert_gte(DailyChallenge.load_list().size(), 15)


func test_validation_catches_bad_entries() -> void:
	var routes := ["route_01"]
	var buses := ["buseta_8"]
	assert_false(DailyChallenge.check([{"id": "a", "text": "x"}], routes, buses, []).is_empty(), "No condition")
	assert_false(DailyChallenge.check([{"id": "a", "text": "x", "route": "nowhere", "min_stars": 3}], routes, buses, []).is_empty())
	assert_false(DailyChallenge.check([{"id": "a", "text": "x", "counter": "kerbs"}], routes, buses, []).is_empty(), "Counter without a limit")
	assert_false(AchievementList.check([{"id": "a", "name": "x", "description": "x", "stat": "bus:nope", "target": 1}], routes, buses).is_empty())
	assert_false(AchievementList.check([{"id": "a", "name": "x", "description": "x", "stat": "shifts", "target": 0}], routes, buses).is_empty())
	assert_true(AchievementList.check([{"id": "a", "name": "x", "description": "x", "stat": "route:route_01", "target": 3, "reward": 10}], routes, buses).is_empty())


func test_a_profile_always_gets_some_challenge() -> void:
	for day in range(1, 32):
		assert_false(DailyChallenge.for_date("2026-12-%02d" % day, DailyChallenge.load_list(), profile).is_empty())
