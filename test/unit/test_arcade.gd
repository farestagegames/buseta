extends GutTest
## The arcade: checkpoints add time, pads boost once each, crashes cost time,
## and the run ends when the clock runs out.


func test_checkpoints_and_pads_are_laid_out_along_the_course() -> void:
	var run := ArcadeRun.new()
	run.plan_to(2000.0)
	assert_eq(run.checkpoints[0], ArcadeRun.FIRST_CHECKPOINT)
	assert_almost_eq(run.checkpoints[1] - run.checkpoints[0], ArcadeRun.CHECKPOINT_SPACING, 0.01)
	var count := run.checkpoints.size()
	run.plan_to(3000.0)
	assert_gt(run.checkpoints.size(), count, "More course, more checkpoints")
	assert_eq(run.boosts.size(), run.boosts_used.size())


func test_a_checkpoint_adds_time() -> void:
	var run := ArcadeRun.new()
	run.plan_to(2000.0)
	var events := run.update(ArcadeRun.FIRST_CHECKPOINT + 1.0, 0.0, 1.0)
	assert_true(events.has("checkpoint"))
	assert_almost_eq(run.seconds_left, ArcadeRun.START_SECONDS - 1.0 + ArcadeRun.CHECKPOINT_SECONDS, 0.01)
	assert_eq(run.checkpoints_passed, 1)


func test_a_pad_boosts_once_and_only_when_driven_over() -> void:
	var run := ArcadeRun.new()
	run.plan_to(2000.0)
	var pad := run.boosts[0]
	run.update(pad - 5.0, 0.0, 0.1)
	assert_false(run.update(pad + 1.0, ArcadeRun.BOOST_REACH + 1.0, 0.1).has("boost"), "Missed it, too far to the side")
	var second := run.boosts[1]
	run.update(second - 5.0, 0.0, 0.1)
	assert_true(run.update(second + 1.0, 1.0, 0.1).has("boost"))
	assert_false(run.update(second + 2.0, 1.0, 0.1).has("boost"), "Each pad works once")


func test_crashes_cost_time_and_the_clock_ends_the_run() -> void:
	var run := ArcadeRun.new()
	run.plan_to(2000.0)
	run.crash()
	assert_almost_eq(run.seconds_left, ArcadeRun.START_SECONDS - ArcadeRun.CRASH_SECONDS, 0.01)
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
