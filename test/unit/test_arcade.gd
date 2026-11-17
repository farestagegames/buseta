extends GutTest
## The arcade: checkpoints add time, pads boost once each, crashes cost time,
## the arch bonus shrinks as the run tightens, extra obstacles grow with the
## arches, and the run ends when the clock runs out.


func _arcade_config() -> Dictionary:
	var catalog := Catalog.new()
	var route: Dictionary = MapLoader.read_json(catalog.arcade_route()["file"])
	return route.get("arcade", {})


func _run() -> ArcadeRun:
	var run := ArcadeRun.new()
	run.configure(_arcade_config())
	return run


func test_checkpoints_and_pads_are_laid_out_along_the_course() -> void:
	var run := _run()
	run.plan_to(2000.0)
	assert_eq(run.checkpoints[0], run.first_checkpoint)
	assert_almost_eq(run.checkpoints[1] - run.checkpoints[0], run.checkpoint_spacing, 0.01)
	var count := run.checkpoints.size()
	run.plan_to(3000.0)
	assert_gt(run.checkpoints.size(), count, "More course, more checkpoints")
	assert_eq(run.boosts.size(), run.boosts_used.size())


func test_a_checkpoint_adds_time() -> void:
	var run := _run()
	run.plan_to(2000.0)
	var events := run.update(run.first_checkpoint + 1.0, 0.0, 1.0)
	assert_true(events.has("checkpoint"))
	assert_almost_eq(run.seconds_left, run.start_seconds - 1.0 + run.checkpoint_seconds, 0.01)
	assert_eq(run.checkpoints_passed, 1)
	assert_almost_eq(run.last_bonus, run.checkpoint_seconds, 0.01, "The first arch adds the full bonus")


func test_the_arch_bonus_shrinks_and_stops_at_the_floor() -> void:
	var run := _run()
	assert_almost_eq(run.bonus_for(0), run.checkpoint_seconds, 0.01)
	assert_lt(run.bonus_for(1), run.bonus_for(0), "Each arch adds less than the last")
	var previous := INF
	for passed in range(0, 30):
		var bonus := run.bonus_for(passed)
		assert_lte(bonus, previous, "The bonus never rises")
		assert_gte(bonus, run.checkpoint_floor, "The bonus never goes under the floor")
		previous = bonus
	assert_almost_eq(run.bonus_for(30), run.checkpoint_floor, 0.01, "The floor holds")


func test_a_pad_boosts_once_and_only_when_driven_over() -> void:
	var run := _run()
	run.plan_to(2000.0)
	var pad := run.boosts[0]
	run.update(pad - 5.0, 0.0, 0.1)
	assert_false(run.update(pad + 1.0, run.boost_reach + 1.0, 0.1).has("boost"), "Missed it, too far to the side")
	var second := run.boosts[1]
	run.update(second - 5.0, 0.0, 0.1)
	assert_true(run.update(second + 1.0, 1.0, 0.1).has("boost"))
	assert_false(run.update(second + 2.0, 1.0, 0.1).has("boost"), "Each pad works once")


func test_crashes_cost_time_and_the_clock_ends_the_run() -> void:
	var run := _run()
	run.plan_to(2000.0)
	run.crash()
	assert_almost_eq(run.seconds_left, run.start_seconds - run.crash_seconds, 0.01)
	var events := run.update(10.0, 0.0, 100.0)
	assert_true(events.has("finished"))
	assert_true(run.finished)
	assert_eq(run.update(5000.0, 0.0, 1.0), [] as Array[String], "Nothing happens after the end")


func test_more_checkpoints_mean_more_stars_and_coins() -> void:
	assert_eq(ArcadeRun.stars_for(0), 1)
	assert_eq(ArcadeRun.stars_for(25), 5)
	assert_gt(ArcadeRun.coins_for(10, 3000.0), ArcadeRun.coins_for(5, 1500.0))


func test_a_boost_raises_the_top_speed_and_the_pull() -> void:
	var spec := load(Profile.catalog.find(Catalog.BUSES, "buseta_8")["file"]) as BusSpec
	var plain := BusPhysicsModel.new(spec)
	var boosted := BusPhysicsModel.new(spec)
	boosted.boost = 1.0
	for model: BusPhysicsModel in [plain, boosted]:
		for i in 60 * 40:
			model.step(0.0, 1.0, 0.0, 1.0 / 60.0)
	assert_gt(boosted.speed, plain.speed + 3.0, "A boosted bus goes faster")
	assert_lt(boosted.speed, spec.top_speed * (1.0 + BusPhysicsModel.BOOST_TOP_SPEED) + 0.5)


func test_arcade_handling_steers_quicker_and_corners_harder() -> void:
	var handling := float(_arcade_config().get("handling", 1.0))
	var spec := load(Profile.catalog.find(Catalog.BUSES, "buseta_8")["file"]) as BusSpec
	var plain := BusPhysicsModel.new(spec)
	var helped := BusPhysicsModel.new(spec)
	helped.handling = handling
	for model: BusPhysicsModel in [plain, helped]:
		model.speed = 15.0
		model.step(1.0, 0.0, 0.0, 0.1)
	assert_gt(absf(helped.steer_angle), absf(plain.steer_angle), "The wheel turns quicker")
	assert_gt(helped.steer_limit(), plain.steer_limit(), "More grip in corners")


func test_a_saved_arcade_choice_goes_back_to_a_normal_route() -> void:
	var catalog := Catalog.new()
	var profile := PlayerProfile.new()
	profile.grant_free_items(catalog)
	profile.selected[Catalog.ROUTES] = catalog.arcade_route()["id"]
	profile.repair_choices(catalog)
	assert_ne(profile.selected[Catalog.ROUTES], catalog.arcade_route()["id"], "The arcade has its own button")


func test_the_arcade_opens_at_its_level() -> void:
	var catalog := Catalog.new()
	var profile := PlayerProfile.new()
	var level := int(catalog.arcade_route().get("level", 1))
	assert_gt(level, 1, "Not open on the very first launch")
	profile.xp = DriverLevel.xp_for_level(level) - 1
	assert_false(profile.arcade_unlocked(catalog))
	profile.xp = DriverLevel.xp_for_level(level)
	assert_true(profile.arcade_unlocked(catalog))
	assert_false(profile.arcade_tried(catalog))
	profile.best_scores[catalog.arcade_route()["id"]] = 2
	assert_true(profile.arcade_tried(catalog))


## Every number lives in arcade.json so it can be tuned without code.
func test_arcade_tuning_lives_in_data() -> void:
	var catalog := Catalog.new()
	var route: Dictionary = MapLoader.read_json(catalog.arcade_route()["file"])
	assert_true(route.has("arcade"), "The arcade route carries its tuning")
	var config: Dictionary = route["arcade"]
	for key in ["start_seconds", "checkpoint_seconds", "checkpoint_decay", "checkpoint_floor", "crash_seconds", "first_checkpoint", "checkpoint_spacing", "first_boost", "boost_spacing", "boost_seconds", "boost_reach", "handling"]:
		assert_true(config.has(key), "Arcade tuning needs %s" % key)
	assert_true(config.has("obstacles"), "Arcade tuning needs obstacle rules")
	for key in ["kinds", "first_arch", "every_arches", "sets_per_batch", "cone_count", "cone_spacing", "lateral_min", "lateral_max", "arch_clearance", "pad_clearance", "set_spacing", "min_gap_after_bus"]:
		assert_true((config["obstacles"] as Dictionary).has(key), "Obstacle rules need %s" % key)


func test_arcade_run_reads_tuning_from_data() -> void:
	var config := _arcade_config()
	var run := ArcadeRun.new()
	run.configure(config)
	assert_almost_eq(run.start_seconds, float(config["start_seconds"]), 0.001)
	assert_almost_eq(run.checkpoint_seconds, float(config["checkpoint_seconds"]), 0.001)
	assert_almost_eq(run.checkpoint_decay, float(config["checkpoint_decay"]), 0.001)
	assert_almost_eq(run.checkpoint_floor, float(config["checkpoint_floor"]), 0.001)
	assert_almost_eq(run.crash_seconds, float(config["crash_seconds"]), 0.001)
	assert_almost_eq(run.seconds_left, run.start_seconds, 0.001)


## The new scramble: a tighter clock, not difficulty settings.
func test_the_scramble_tuning_matches_the_brief() -> void:
	var config := _arcade_config()
	var start := float(config["start_seconds"])
	var checkpoint := float(config["checkpoint_seconds"])
	var decay := float(config["checkpoint_decay"])
	var checkpoint_floor := float(config["checkpoint_floor"])
	var crash := float(config["crash_seconds"])
	assert_gte(start, 60.0)
	assert_lte(start, 65.0)
	assert_gte(checkpoint, 19.0)
	assert_lte(checkpoint, 21.0)
	assert_gte(decay, 0.5)
	assert_lte(decay, 1.5)
	assert_gte(checkpoint_floor, 8.0)
	assert_lte(checkpoint_floor, 10.0)
	assert_gte(crash, 3.5)
	assert_lte(crash, 4.5)


func test_obstacle_count_grows_with_arches() -> void:
	var config: Dictionary = _arcade_config()["obstacles"]
	var first := int(config["first_arch"])
	assert_eq(ArcadeObstacles.set_count(0, config), 0, "No obstacles before the first arch")
	assert_eq(ArcadeObstacles.set_count(first - 1, config), 0, "Still none just before the first arch")
	var at_first := ArcadeObstacles.set_count(first, config)
	assert_gt(at_first, 0, "Obstacles begin at the first arch")
	var later := ArcadeObstacles.set_count(first + int(config["every_arches"]) * 4, config)
	assert_gt(later, at_first, "More arches, more obstacles")
	var previous := 0
	for arches in range(0, 20):
		var now := ArcadeObstacles.set_count(arches, config)
		assert_gte(now, previous, "The count never shrinks")
		previous = now


func test_obstacles_stay_clear_of_pads_arches_and_road() -> void:
	var config: Dictionary = _arcade_config()["obstacles"]
	var run := _run()
	run.plan_to(6000.0)
	var placements := ArcadeObstacles.place_sets(200.0, 14, run.checkpoints, run.boosts, config)
	assert_gt(placements.size(), 0, "There are obstacles to check")
	var arch_clearance := float(config["arch_clearance"])
	var pad_clearance := float(config["pad_clearance"])
	var lateral_min := float(config["lateral_min"])
	var lateral_max := float(config["lateral_max"])
	assert_gt(lateral_min, 0.0, "A clear way is left on the road side")
	assert_lt(lateral_max, RoadNetwork.ROAD_HALF_WIDTH, "Obstacles stay inside the lane")
	for placement: Dictionary in placements:
		var distance := float(placement["distance"])
		var lateral := float(placement["lateral"])
		assert_true(["cone", "barrier"].has(placement["kind"]), "Only knockable kinds")
		for arch in run.checkpoints:
			assert_gte(absf(arch - distance), arch_clearance - 0.001, "Never under an arch")
		for pad in run.boosts:
			assert_gte(absf(pad - distance), pad_clearance - 0.001, "Never on a pad")
		assert_gte(lateral, lateral_min - 0.001, "On the kerb side, clear way left")
		assert_lte(lateral, lateral_max + 0.001, "Still inside the lane")


## Normal shifts are untouched by the arcade's tighter numbers.
func test_normal_routes_carry_no_arcade_tuning() -> void:
	var catalog := Catalog.new()
	for item: Dictionary in catalog.items(Catalog.ROUTES):
		if str(item.get("mode", "")) == "arcade":
			continue
		var route: Dictionary = MapLoader.read_json(item["file"])
		assert_false(route.has("arcade"), "%s should carry no arcade tuning" % item["id"])
		assert_ne(str(route.get("service", "")), "arcade")


## Each town has its own Carrera Express, found by the town's (map's) name.
func test_each_town_has_its_own_arcade() -> void:
	var catalog := Catalog.new()
	var marisol := catalog.arcade_route("Puerto Marisol")
	var cafeto := catalog.arcade_route("Alto Cafeto")
	assert_eq(marisol.get("id", ""), "arcade")
	assert_eq(cafeto.get("id", ""), "arcade_cafeto")
	assert_eq(catalog.arcade_route().get("id", ""), "arcade", "No town means Puerto Marisol's")
	assert_true(catalog.arcade_route("Puerto Remanso").is_empty(), "An archived town has none")
	var route: Dictionary = MapLoader.read_json(cafeto["file"])
	assert_eq(str(route["service"]), "arcade")
	assert_string_contains(str(route["map"]), "alto_cafeto")
	assert_true(route.has("arcade"), "Its tuning lives in its own file")
	assert_gte(int(cafeto.get("level", 1)), Profile.town_lock_level("Alto Cafeto"), "Not open before the town")


func test_arcade_flags_are_kept_per_town() -> void:
	var catalog := Catalog.new()
	var profile := PlayerProfile.new()
	var cafeto := catalog.arcade_route("Alto Cafeto")
	profile.xp = DriverLevel.xp_for_level(int(cafeto["level"])) - 1
	assert_true(profile.arcade_unlocked(catalog, "Puerto Marisol"))
	assert_false(profile.arcade_unlocked(catalog, "Alto Cafeto"), "Opens with its town")
	profile.xp = DriverLevel.xp_for_level(int(cafeto["level"]))
	assert_true(profile.arcade_unlocked(catalog, "Alto Cafeto"))
	profile.best_scores["arcade"] = 4
	assert_true(profile.arcade_tried(catalog, "Puerto Marisol"))
	assert_false(profile.arcade_tried(catalog, "Alto Cafeto"), "Racing one town's arcade leaves the other new")
	profile.grant_free_items(catalog)
	profile.selected[Catalog.ROUTES] = "arcade_cafeto"
	profile.repair_choices(catalog)
	assert_ne(profile.selected[Catalog.ROUTES], "arcade_cafeto", "No arcade stays the chosen route")


func test_next_unlock_never_names_an_arcade() -> void:
	var catalog := Catalog.new()
	var profile := PlayerProfile.new()
	profile.xp = DriverLevel.xp_for_level(5)
	profile.coins = 100000000
	profile.owned[Catalog.ROUTES] = []
	var next := UnlockProgress.next(profile, catalog, Country.pack)
	assert_false(str(next.get("id", "")).begins_with("arcade"), "Arcades open by level, not by unlock")


## Alto Cafeto's clock is as tight as Puerto Marisol's (owner, 17 Nov: the
## longer 80 s / 26 s clock was far too generous).
func test_the_cafeto_clock_is_as_tight_as_the_coast() -> void:
	var coast := _arcade_config()
	var file := ""
	for item: Dictionary in Catalog.new().arcade_routes():
		if item["id"] == "arcade_cafeto":
			file = item["file"]
	assert_ne(file, "", "Alto Cafeto has an arcade")
	var route: Dictionary = MapLoader.read_json(file)
	var cafeto: Dictionary = route.get("arcade", {})
	assert_lte(float(cafeto["start_seconds"]), float(coast["start_seconds"]) + 4.0)
	assert_lte(float(cafeto["checkpoint_seconds"]), float(coast["checkpoint_seconds"]))
	assert_lte(float(cafeto["checkpoint_floor"]), float(coast["checkpoint_floor"]))
