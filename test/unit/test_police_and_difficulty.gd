extends GutTest
## Difficulty levels, police patrols and fines, and fare dodgers.


func _difficulty(ends_run: bool, fines: Array = [100, 200]) -> Difficulty:
	return Difficulty.from_data({"id": "x", "police_every": [10, 20], "police_watch_seconds": 30,
		"police_ends_run": ends_run, "fines": fines})


func _watching(patrol: PolicePatrol) -> void:
	for i in 1500:
		if patrol.update(0.1):
			return
	fail_test("The patrol never turned up")


func test_the_pack_has_three_difficulties_and_validates() -> void:
	var list := Difficulty.list_for(Country.pack.data)
	assert_eq(list.map(func(d: Difficulty) -> String: return d.id), ["easy", "medium", "hard"])
	assert_eq(Difficulty.check(Country.pack.data["difficulties"], Country.pack.data["default_difficulty"]), [] as Array[String])
	var easy := list[0]
	var hard := list[2]
	assert_lt(easy.penalty_scale, hard.penalty_scale)
	assert_lt(easy.coin_scale, hard.coin_scale)
	assert_false(easy.police_ends_run, "Easy never ends the run")
	assert_eq(easy.dodger_chance, 0.0, "No fare dodgers on Easy")


func test_a_pack_without_difficulties_gets_one_without_police() -> void:
	var list := Difficulty.list_for({})
	assert_eq(list.size(), 1)
	assert_false(list[0].has_police())
	assert_eq(Difficulty.check(null, ""), [] as Array[String])


func test_bad_difficulty_data_is_reported() -> void:
	assert_false(Difficulty.check([{"id": "a", "police_every": [30, 10], "fines": [1]}], "a").is_empty())
	assert_false(Difficulty.check([{"id": "a", "police_every": [10, 30]}], "a").is_empty(), "Police without fines")
	assert_false(Difficulty.check([{"id": "a", "dodger_chance": 0.9}], "a").is_empty())
	assert_false(Difficulty.check([{"id": "a"}], "b").is_empty(), "Unknown default")


func test_the_patrol_turns_up_within_its_window_and_leaves() -> void:
	var patrol := PolicePatrol.new(_difficulty(true), 5)
	var waited := 0.0
	while not patrol.update(0.1):
		waited += 0.1
	assert_between(waited, 9.8, 20.1)
	for i in 299:
		patrol.update(0.1)
	assert_true(patrol.is_watching())
	patrol.update(0.2)
	assert_false(patrol.is_watching(), "Leaves after its watch")


func test_the_same_seed_brings_the_police_at_the_same_time() -> void:
	assert_eq(PolicePatrol.new(_difficulty(true), 9).time_until_next(), PolicePatrol.new(_difficulty(true), 9).time_until_next())


func test_faults_only_count_when_the_patrol_is_near() -> void:
	var patrol := PolicePatrol.new(_difficulty(true), 1)
	assert_eq(patrol.witness(true), {}, "No patrol yet")
	_watching(patrol)
	assert_eq(patrol.witness(false), {}, "Too far away to see")
	assert_eq(int(patrol.witness(true)["fine"]), 100)


func test_fines_grow_and_the_third_fault_ends_the_run() -> void:
	var patrol := PolicePatrol.new(_difficulty(true), 1)
	_watching(patrol)
	assert_eq(int(patrol.witness(true)["fine"]), 100)
	assert_eq(patrol.witness(true), {}, "The same crash only counts once")
	patrol.update(PolicePatrol.FAULT_COOLDOWN)
	assert_eq(int(patrol.witness(true)["fine"]), 200)
	patrol.update(PolicePatrol.FAULT_COOLDOWN)
	var third := patrol.witness(true)
	assert_true(third["ends_run"])
	assert_true(patrol.run_ended)
	assert_eq(patrol.fined_coins, 300)


func test_on_easy_the_police_only_ever_fine() -> void:
	var patrol := PolicePatrol.new(_difficulty(false), 1)
	_watching(patrol)
	var fines: Array[int] = []
	for i in 5:
		var result := patrol.witness(true)
		assert_false(result["ends_run"])
		fines.append(int(result["fine"]))
		patrol.update(PolicePatrol.FAULT_COOLDOWN)
	assert_eq(fines, [100, 200, 200, 200, 200] as Array[int], "The last fine repeats")


func test_fines_come_out_of_the_shift_coins_and_never_below_zero() -> void:
	var score := ShiftScore.new()
	var before := score.coins(10)
	score.add_fine(100)
	assert_lt(score.coins(10), before)
	score.add_fine(100000)
	assert_eq(score.coins(10), 0)
	assert_eq(int(score.counts["fines"]), 2)


func test_difficulty_scales_penalties_and_pay() -> void:
	var easy := ShiftScore.new()
	easy.penalty_scale = 0.6
	var hard := ShiftScore.new()
	hard.penalty_scale = 1.4
	hard.coin_scale = 1.3
	for score: ShiftScore in [easy, hard]:
		score.add_red_light()
		score.add_collision(5.0)
	assert_gt(easy.total(), hard.total(), "The same mistakes cost more on Hard")
	var plain := ShiftScore.new()
	var paid := ShiftScore.new()
	paid.coin_scale = 1.3
	assert_eq(paid.coins(10), roundi(plain.coins(10) * 1.3))


func test_a_dodger_costs_a_little_satisfaction() -> void:
	var score := ShiftScore.new()
	score.add_dodger()
	assert_eq(int(score.counts["dodgers"]), 1)
	assert_lt(score.categories()["satisfaction"], 100.0)


func test_difficulty_choice_survives_saving() -> void:
	var profile := PlayerProfile.new()
	profile.difficulty = "hard"
	assert_eq(PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict()))).difficulty, "hard")
	assert_eq(PlayerProfile.from_dict({}).difficulty, "", "Old saves use the default")
