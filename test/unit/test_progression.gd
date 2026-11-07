extends GutTest

const PATH := "user://test_save_unit.json"

var profile: PlayerProfile
var catalog: Catalog


func before_each() -> void:
	profile = PlayerProfile.new()
	catalog = Catalog.new()
	for suffix: String in ["", SaveStore.BACKUP_SUFFIX, SaveStore.TEMP_SUFFIX]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _report(score: int = 80, stars: int = 4) -> Dictionary:
	return {"score": score, "stars": stars, "coins": 400, "carried": 20,
		"counts": {"collisions": 0, "harsh_brakes": 0, "kerbs": 0, "indicators": 0, "red_lights": 0, "knocked": 0, "jolts": 0}}


func test_new_player_starts_with_the_free_items() -> void:
	assert_true(profile.owns(Catalog.ROUTES, "route_01"))
	assert_true(profile.owns(Catalog.BUSES, "buseta_8"))
	assert_true(profile.owns(Catalog.LIVERIES, "rojo_caribe"))
	assert_false(profile.owns(Catalog.ROUTES, "route_02"))


func test_every_catalog_item_is_complete_and_loads() -> void:
	for kind: String in [Catalog.ROUTES, Catalog.BUSES]:
		for item: Dictionary in catalog.items(kind):
			assert_true(ResourceLoader.exists(item["file"]) or FileAccess.file_exists(item["file"]), item["id"])
	for item: Dictionary in catalog.items(Catalog.LIVERIES):
		assert_eq((item["body"] as Array).size(), 3)
	assert_gte(catalog.items(Catalog.ROUTES).size(), 2)
	assert_gte(catalog.items(Catalog.BUSES).size(), 2)


func test_buying_takes_coins_and_adds_the_item() -> void:
	profile.coins = 2000
	var route := catalog.find(Catalog.ROUTES, "route_02")
	assert_true(profile.buy(Catalog.ROUTES, route))
	assert_eq(profile.coins, 1500)
	assert_true(profile.owns(Catalog.ROUTES, "route_02"))


func test_cannot_buy_without_enough_coins() -> void:
	profile.coins = 100
	assert_false(profile.buy(Catalog.ROUTES, catalog.find(Catalog.ROUTES, "route_02")))
	assert_eq(profile.coins, 100)


func test_cannot_pay_twice_for_the_same_item() -> void:
	profile.coins = 5000
	var route := catalog.find(Catalog.ROUTES, "route_02")
	profile.buy(Catalog.ROUTES, route)
	assert_false(profile.buy(Catalog.ROUTES, route))
	assert_eq(profile.coins, 4500)


func test_cannot_select_what_you_do_not_own() -> void:
	assert_false(profile.select(Catalog.BUSES, "midi_10"))
	assert_eq(profile.selected[Catalog.BUSES], "buseta_8")


func test_profile_survives_a_round_trip() -> void:
	profile.coins = 1234
	profile.xp = 900
	(profile.owned[Catalog.LIVERIES] as Array).append("verde_manglar")
	profile.select(Catalog.LIVERIES, "verde_manglar")
	profile.achievements.append("first_shift")
	profile.record_best("route_01", 77)
	profile.last_daily = "2026-11-06"
	var copy := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	assert_eq(copy.coins, 1234)
	assert_eq(copy.selected[Catalog.LIVERIES], "verde_manglar")
	assert_eq(copy.achievements.size(), 1)
	assert_eq(int(copy.best_scores["route_01"]), 77)
	assert_eq(copy.last_daily, "2026-11-06")


func test_damaged_save_fields_fall_back_safely() -> void:
	var copy := PlayerProfile.from_dict({"coins": "lots", "xp": -50, "owned": 7, "selected": {"buses": "midi_10"}, "stats": "x", "achievements": [1, "first_shift"]})
	assert_eq(copy.coins, 0)
	assert_eq(copy.xp, 0)
	assert_eq(copy.selected[Catalog.BUSES], "buseta_8", "Cannot select what the save does not own")
	assert_eq(copy.achievements, ["first_shift"] as Array[String])


func test_empty_save_is_a_new_player() -> void:
	var copy := PlayerProfile.from_dict({})
	assert_eq(copy.coins, 0)
	assert_true(copy.owns(Catalog.BUSES, "buseta_8"))


func test_store_writes_and_reads() -> void:
	assert_true(SaveStore.write(PATH, {"coins": 5}))
	assert_eq(int(SaveStore.read(PATH)["coins"]), 5)
	assert_false(FileAccess.file_exists(PATH + SaveStore.TEMP_SUFFIX), "Temp file should be gone")


func test_store_keeps_the_previous_save_as_a_backup() -> void:
	SaveStore.write(PATH, {"coins": 5})
	SaveStore.write(PATH, {"coins": 9})
	assert_eq(int(SaveStore.read_file(PATH + SaveStore.BACKUP_SUFFIX)["coins"]), 5)


func test_corrupt_save_falls_back_to_the_backup() -> void:
	SaveStore.write(PATH, {"coins": 5})
	SaveStore.write(PATH, {"coins": 9})
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	assert_eq(int(SaveStore.read(PATH)["coins"]), 5)


func test_missing_save_reads_empty() -> void:
	assert_true(SaveStore.read(PATH).is_empty())


func test_level_rises_with_xp() -> void:
	assert_eq(DriverLevel.level_for(0), 1)
	assert_eq(DriverLevel.level_for(149), 1)
	assert_eq(DriverLevel.level_for(150), 2)
	assert_gt(DriverLevel.xp_for_level(5) - DriverLevel.xp_for_level(4), DriverLevel.xp_for_level(3) - DriverLevel.xp_for_level(2))


func test_level_progress_is_a_share() -> void:
	assert_almost_eq(DriverLevel.progress(75), 0.5, 0.001)


func test_shift_pays_coins_xp_and_stats() -> void:
	var challenges := [{"id": "x", "text": "x", "min_stars": 5}]
	var rewards := ShiftRewards.apply(profile, _report(), "route_01", "2026-11-06", challenges, [])
	assert_eq(profile.coins, 400)
	assert_eq(int(rewards["xp"]), 120)
	assert_eq(profile.xp, 120)
	assert_eq(int(profile.stats["shifts"]), 1)
	assert_eq(int(profile.stats["passengers"]), 20)
	assert_eq(int(profile.stats["clean_shifts"]), 1)


func test_daily_challenge_pays_once_a_day() -> void:
	var challenges := [{"id": "x", "text": "No crashes", "counter": "collisions", "max": 0}]
	var first := ShiftRewards.apply(profile, _report(), "route_01", "2026-11-06", challenges, [])
	var second := ShiftRewards.apply(profile, _report(), "route_01", "2026-11-06", challenges, [])
	var next_day := ShiftRewards.apply(profile, _report(), "route_01", "2026-11-07", challenges, [])
	assert_eq(int(first["daily_coins"]), DailyChallenge.REWARD_COINS)
	assert_eq(int(second["daily_coins"]), 0)
	assert_eq(int(next_day["daily_coins"]), DailyChallenge.REWARD_COINS)


func test_failed_daily_pays_nothing_and_can_be_retried() -> void:
	var challenges := [{"id": "x", "text": "x", "counter": "collisions", "max": 0}]
	var bad := _report()
	bad["counts"]["collisions"] = 2
	assert_eq(int(ShiftRewards.apply(profile, bad, "route_01", "2026-11-06", challenges, [])["daily_coins"]), 0)
	assert_eq(int(ShiftRewards.apply(profile, _report(), "route_01", "2026-11-06", challenges, [])["daily_coins"]), DailyChallenge.REWARD_COINS)


func test_daily_challenge_is_stable_for_a_date_and_changes_over_days() -> void:
	var list := DailyChallenge.load_list()
	assert_gte(list.size(), 7)
	assert_eq(DailyChallenge.for_date("2026-11-06", list)["id"], DailyChallenge.for_date("2026-11-06", list)["id"])
	var seen := {}
	for day in range(1, 29):
		seen[DailyChallenge.for_date("2026-11-%02d" % day, list)["id"]] = true
	assert_gt(seen.size(), 3)


func test_star_challenge() -> void:
	assert_true(DailyChallenge.is_passed({"min_stars": 4}, _report(80, 4)))
	assert_false(DailyChallenge.is_passed({"min_stars": 4}, _report(60, 3)))


func test_achievement_is_awarded_once() -> void:
	var list := AchievementList.load_list()
	profile.stats["shifts"] = 1
	var first := AchievementList.award_new(profile, list)
	assert_eq(first.size(), 1)
	assert_eq(first[0]["id"], "first_shift")
	assert_eq(AchievementList.award_new(profile, list).size(), 0)


func test_every_achievement_uses_a_real_stat() -> void:
	for entry: Dictionary in AchievementList.load_list():
		assert_true(profile.stats.has(entry["stat"]), entry["id"])


func test_best_score_only_rises() -> void:
	assert_true(profile.record_best("route_01", 60))
	assert_false(profile.record_best("route_01", 50))
	assert_true(profile.record_best("route_01", 70))


func test_level_up_is_reported() -> void:
	profile.xp = 140
	var rewards := ShiftRewards.apply(profile, _report(), "route_01", "2026-11-06", [{"id": "x", "text": "x", "min_stars": 5}], [])
	assert_true(rewards["levelled_up"])


func test_ads_are_off_with_no_sdk() -> void:
	assert_false(AdProvider.new().is_available())


func test_a_few_good_shifts_buy_the_first_unlock() -> void:
	var score := ShiftScore.new()
	for i in 7:
		score.add_stop(0.8, 0.0)
	var per_shift := score.coins(28)
	var route_cost: int = catalog.find(Catalog.ROUTES, "route_02")["cost"]
	var shifts := ceili(float(route_cost) / float(per_shift))
	assert_between(shifts, 1, 3, "Second route should come quickly")


func test_settings_round_trip_and_ignore_bad_values() -> void:
	var saved := GameSettings.to_dict()
	GameSettings.apply_saved({"steering_mode": 99, "sensitivity": 500.0, "invert_tilt": true})
	assert_eq(GameSettings.sensitivity, SteeringMapper.MAX_SENSITIVITY)
	assert_eq(int(GameSettings.steering_mode), int(saved["steering_mode"]))
	GameSettings.apply_saved(saved)


func test_tutorial_flag_survives_saving() -> void:
	profile.intro_done = true
	assert_true(PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict()))).intro_done)
	assert_false(PlayerProfile.from_dict({}).intro_done, "A new player sees the tutorial")
