extends GutTest
## Times of day and tropical downpours: the data, the seeded plan, how wet the road
## gets, and what the wet does to the bus, the traffic and the score.

const DT := 1.0 / 60.0
const SPANISH := "res://data/packs/colombia/lang/es_CO.json"

var settings: RainSettings
var times: Array[TimeOfDay]


func before_each() -> void:
	settings = RainSettings.from_pack(Country.pack.data)
	times = TimeOfDay.list_for(Country.pack.data)


func _time(time_id: String) -> TimeOfDay:
	return TimeOfDay.find(times, time_id)


func _rainy(chance: float = 1.0) -> TimeOfDay:
	var time := TimeOfDay.new()
	time.rain_chance = chance
	return time


# --- Times of day ---

func test_colombia_offers_five_times_of_day_from_dawn_to_night() -> void:
	var ids := times.map(func(time: TimeOfDay) -> String: return time.id)
	assert_eq(ids, ["madrugada", "manana", "mediodia", "atardecer", "noche"])


func test_morning_is_the_default_and_open_from_the_start() -> void:
	var first := TimeOfDay.default_of(times)
	assert_eq(first.id, "manana")
	assert_true(first.is_unlocked(1))


func test_later_times_open_with_driver_level() -> void:
	assert_false(_time("atardecer").is_unlocked(1))
	assert_true(_time("atardecer").is_unlocked(2))
	assert_false(_time("noche").is_unlocked(3))
	assert_true(_time("noche").is_unlocked(4))


func test_a_locked_choice_falls_back_to_the_default() -> void:
	assert_eq(TimeOfDay.pick(times, "noche", 1).id, "manana")
	assert_eq(TimeOfDay.pick(times, "noche", 4).id, "noche")
	assert_eq(TimeOfDay.pick(times, "no_such_time", 9).id, "manana")
	assert_eq(TimeOfDay.pick(times, "", 9).id, "manana")


func test_night_lights_the_lamps_and_switches_off_the_sun_shadows() -> void:
	var night := _time("noche")
	assert_true(night.is_dark())
	assert_false(night.shadows)
	assert_gt(night.windows, 0.0)
	assert_false(_time("mediodia").is_dark())
	assert_true(_time("mediodia").shadows)


func test_the_afternoon_is_the_most_likely_to_rain() -> void:
	var sunset := _time("atardecer")
	for time in times:
		assert_lte(time.rain_chance, sunset.rain_chance, time.id)
	assert_gt(_time("mediodia").rain_chance, _time("manana").rain_chance)


func test_night_is_quieter_and_rush_hour_busier() -> void:
	assert_lt(_time("noche").traffic, 1.0)
	assert_lt(_time("madrugada").pedestrians, _time("manana").pedestrians)
	assert_gt(_time("atardecer").traffic, 1.0)


func test_night_shifts_are_counted_for_the_achievement() -> void:
	assert_eq(_time("noche").stat, "night_shifts")
	assert_true(PlayerProfile.new().stats.has("night_shifts"))


func test_every_time_of_day_has_a_spanish_name() -> void:
	var strings := MapLoader.read_json(SPANISH)
	for time in times:
		assert_true(strings.has(time.name), time.name)
	assert_true(strings.has(TimeOfDay.new().name), "The fallback day")


func test_a_pack_without_times_gets_one_day_from_its_map() -> void:
	var theme := CityTheme.new()
	theme.sky_top = Color(0.1, 0.2, 0.3)
	var plain := TimeOfDay.list_for({}, theme)
	assert_eq(plain.size(), 1)
	assert_eq(plain[0].id, TimeOfDay.FALLBACK_ID)
	assert_eq(plain[0].sky_top, Color(0.1, 0.2, 0.3))
	assert_eq(plain[0].rain_chance, 0.0)
	assert_true(plain[0].is_unlocked(1))


func test_the_left_hand_test_pack_still_validates_without_weather() -> void:
	var pack := CountryPack.read("res://test/fixtures/packs/testland/pack.json")
	assert_false(pack.data.has("times_of_day"))
	assert_eq(pack.validate(), [] as Array[String])


func test_time_of_day_checks_catch_bad_data() -> void:
	assert_eq(TimeOfDay.check(Country.pack.data["times_of_day"]), [] as Array[String])
	assert_eq(TimeOfDay.check(null), [] as Array[String])
	assert_false(TimeOfDay.check("night").is_empty())
	var good: Dictionary = (Country.pack.data["times_of_day"] as Array)[1].duplicate(true)
	var twice := [good, good]
	assert_true(_mentions(TimeOfDay.check(twice), "twice"))
	var broken := good.duplicate(true)
	broken.erase("sky_top")
	assert_true(_mentions(TimeOfDay.check([broken]), "sky_top"))
	var bright := good.duplicate(true)
	bright["lights"] = 3
	assert_true(_mentions(TimeOfDay.check([bright]), "lights"))
	var locked := good.duplicate(true)
	locked["level"] = 3
	assert_true(_mentions(TimeOfDay.check([locked]), "level 1"))
	var odd := good.duplicate(true)
	odd["shadows"] = "yes"
	assert_true(_mentions(TimeOfDay.check([odd]), "shadows"))


func test_the_pack_names_an_unknown_time_stat() -> void:
	var pack := CountryPack.read("res://data/packs/colombia/pack.json")
	(pack.data["times_of_day"] as Array)[4]["stat"] = "moon_shifts"
	assert_true(_mentions(pack.validate(), "moon_shifts"))


func _mentions(problems: Array[String], text: String) -> bool:
	return problems.any(func(problem: String) -> bool: return problem.contains(text))


# --- Rain settings ---

func test_rain_settings_read_the_pack_and_keep_defaults_for_the_rest() -> void:
	assert_almost_eq(settings.wet_grip, 0.7, 0.001)
	assert_gt(settings.traffic_gap, 1.0)
	var plain := RainSettings.from_data({"wet_grip": 0.8})
	assert_almost_eq(plain.wet_grip, 0.8, 0.001)
	assert_eq(plain.build_seconds, RainSettings.new().build_seconds)


func test_rain_settings_checks_catch_bad_data() -> void:
	assert_eq(RainSettings.check(Country.pack.data["weather"]), [] as Array[String])
	assert_eq(RainSettings.check(null), [] as Array[String])
	assert_true(_mentions(RainSettings.check({"rain": {"build_seconds": [30, 10]}}), "build_seconds"))
	assert_true(_mentions(RainSettings.check({"rain": {"wet_grip": 1.5}}), "wet_grip"))
	assert_true(_mentions(RainSettings.check({"rain": {"traffic_gap": 0.5}}), "traffic_gap"))
	assert_true(_mentions(RainSettings.check({"rain": {"strength": [0.5, 2]}}), "strength"))
	assert_false(RainSettings.check("wet").is_empty())


# --- The weather plan ---

func test_the_same_seed_brings_the_same_downpour() -> void:
	var first := WeatherPlan.make(42, _rainy(), settings, 560.0)
	var again := WeatherPlan.make(42, _rainy(), settings, 560.0)
	assert_true(first.rains)
	assert_eq(first.start, again.start)
	assert_eq(first.build, again.build)
	assert_eq(first.length, again.length)
	assert_eq(first.strength, again.strength)
	for t: float in [first.start + 5.0, first.start + 60.0, first.end() - 3.0]:
		assert_eq(first.rain_at(t), again.rain_at(t))


func test_different_seeds_bring_different_weather() -> void:
	var starts := {}
	for seed_value in 20:
		starts[snappedf(WeatherPlan.make(seed_value, _rainy(), settings, 560.0).start, 0.01)] = true
	assert_gt(starts.size(), 15)


func test_the_chance_of_rain_follows_the_time_of_day() -> void:
	var wet := 0
	for seed_value in 400:
		if WeatherPlan.make(seed_value, _time("atardecer"), settings, 560.0).rains:
			wet += 1
	assert_between(float(wet) / 400.0, _time("atardecer").rain_chance - 0.08, _time("atardecer").rain_chance + 0.08)
	for seed_value in 50:
		assert_false(WeatherPlan.make(seed_value, _rainy(0.0), settings, 560.0).rains)


func test_tests_and_tools_can_force_the_weather() -> void:
	for seed_value in 30:
		assert_true(WeatherPlan.make(seed_value, _rainy(0.0), settings, 560.0, WeatherPlan.FORCE_RAIN).rains)
		assert_false(WeatherPlan.make(seed_value, _rainy(1.0), settings, 560.0, WeatherPlan.FORCE_DRY).rains)


func test_forcing_keeps_the_timing_of_the_seed() -> void:
	var planned := WeatherPlan.make(9, _rainy(1.0), settings, 560.0)
	var forced := WeatherPlan.make(9, _rainy(0.0), settings, 560.0, WeatherPlan.FORCE_RAIN)
	assert_eq(planned.start, forced.start)
	assert_eq(planned.length, forced.length)


func test_the_downpour_lands_mid_shift_and_lasts_a_few_minutes() -> void:
	for seed_value in 50:
		var plan := WeatherPlan.make(seed_value, _rainy(), settings, 560.0)
		assert_between(plan.start, 560.0 * settings.start_share.x, 560.0 * settings.start_share.y)
		assert_between(plan.build, settings.build_seconds.x, settings.build_seconds.y)
		assert_between(plan.length, settings.rain_seconds.x, settings.rain_seconds.y)
		assert_between(plan.duration(), 120.0, 260.0)


func test_rain_builds_quickly_pours_then_stops_and_the_sun_returns() -> void:
	var plan := WeatherPlan.make(3, _rainy(), settings, 560.0)
	assert_eq(plan.rain_at(plan.start - 1.0), 0.0)
	assert_eq(plan.phase_at(plan.start - 1.0), WeatherPlan.Phase.DRY)
	assert_eq(plan.phase_at(plan.start + 1.0), WeatherPlan.Phase.BUILDING)
	var last := -1.0
	var t := plan.start
	while t < plan.start + plan.build:
		var rain := plan.rain_at(t)
		assert_gte(rain, last, "Rain only grows in the build-up")
		assert_gte(plan.cloud_at(t), rain - 0.0001, "The sky darkens ahead of the rain")
		last = rain
		t += 0.5
	assert_lt(plan.rain_at(plan.start + plan.build * 0.4), 0.15, "First drops, not a deluge")
	for share: float in [0.1, 0.5, 0.9]:
		var pouring := plan.start + plan.build + plan.length * share
		assert_eq(plan.phase_at(pouring), WeatherPlan.Phase.RAINING)
		assert_between(plan.rain_at(pouring), plan.strength * 0.85, 1.0)
	assert_eq(plan.phase_at(plan.end() - 1.0), WeatherPlan.Phase.CLEARING)
	assert_eq(plan.rain_at(plan.end() + 1.0), 0.0)
	assert_eq(plan.cloud_at(plan.end() + 1.0), 0.0)
	assert_eq(plan.phase_at(plan.end() + 1.0), WeatherPlan.Phase.OVER)


func test_a_dry_plan_never_rains() -> void:
	var plan := WeatherPlan.make(3, _rainy(0.0), settings, 560.0)
	for t in range(0, 900, 15):
		assert_eq(plan.rain_at(float(t)), 0.0)
		assert_eq(plan.cloud_at(float(t)), 0.0)


func test_a_downpour_can_start_now_at_full_strength() -> void:
	var plan := WeatherPlan.make(3, _rainy(0.0), settings, 560.0)
	plan.start_now(100.0, true)
	assert_true(plan.rains)
	assert_eq(plan.phase_at(100.0), WeatherPlan.Phase.RAINING)
	assert_gt(plan.rain_at(100.0), 0.5)


# --- The weather through a shift ---

func _clock_for(seed_value: int = 5) -> WeatherClock:
	return WeatherClock.new(WeatherPlan.make(seed_value, _rainy(), settings, 560.0), settings, _time("mediodia"))


func _run(clock: WeatherClock, until: float) -> Array[WeatherClock.Change]:
	var changes: Array[WeatherClock.Change] = []
	while clock.clock < until:
		var change := clock.advance(DT)
		if change != WeatherClock.Change.NONE:
			changes.append(change)
	return changes


func test_the_downpour_starts_and_stops_once_each() -> void:
	var clock := _clock_for()
	var changes := _run(clock, clock.plan.end() + 10.0)
	assert_eq(changes, [WeatherClock.Change.DOWNPOUR_STARTED, WeatherClock.Change.RAIN_STOPPED] as Array[WeatherClock.Change])
	assert_gt(clock.peak_rain, 0.6)


func test_the_road_soaks_quickly_and_dries_slowly() -> void:
	var clock := _clock_for()
	_run(clock, clock.plan.start + clock.plan.build + 20.0)
	assert_gt(clock.wetness, 0.8, "Soaked within seconds of the downpour")
	_run(clock, clock.plan.end() + 1.0)
	assert_eq(clock.rain, 0.0)
	assert_gt(clock.wetness, 0.5, "Still wet as the sun comes back")
	_run(clock, clock.plan.end() + settings.dry_seconds + 5.0)
	assert_eq(clock.wetness, 0.0, "Dry again after a while")


func test_a_soaked_road_has_less_grip_and_slower_wider_spaced_traffic() -> void:
	var clock := _clock_for()
	assert_eq(clock.grip(), 1.0)
	assert_eq(clock.traffic_speed(), 1.0)
	assert_eq(clock.traffic_gap(), 1.0)
	clock.wetness = 1.0
	assert_almost_eq(clock.grip(), settings.wet_grip, 0.001)
	assert_almost_eq(clock.traffic_speed(), settings.traffic_speed, 0.001)
	assert_almost_eq(clock.traffic_gap(), settings.traffic_gap, 0.001)
	clock.wetness = 0.5
	assert_between(clock.grip(), settings.wet_grip, 1.0)


func test_people_shelter_from_a_downpour_and_some_open_umbrellas() -> void:
	var clock := _clock_for()
	assert_eq(clock.pedestrians(), 1.0)
	assert_eq(clock.umbrellas(), 0.0)
	clock.rain = 1.0
	assert_almost_eq(clock.pedestrians(), settings.pedestrians, 0.001)
	assert_gt(clock.umbrellas(), 0.0)
	assert_eq(StreetLife.walkers_out(40, 0.35), 14)
	assert_eq(StreetLife.walkers_out(40, 0.0), 2, "Never an empty street")


func test_lights_come_on_at_night_and_under_storm_clouds() -> void:
	var day := WeatherClock.new(WeatherPlan.make(5, _rainy(), settings, 560.0), settings, _time("mediodia"))
	assert_eq(day.lights(), 0.0)
	assert_false(day.headlights())
	day.cloud = 1.0
	assert_gt(day.lights(), 0.0)
	assert_true(day.headlights())
	var night := WeatherClock.new(WeatherPlan.make(5, _rainy(0.0), settings, 560.0), settings, _time("noche"))
	assert_eq(night.lights(), 1.0)
	assert_true(night.headlights())


func test_the_timetable_allows_for_a_wet_road() -> void:
	var clock := _clock_for()
	assert_eq(clock.slack_rate(), 0.0)
	clock.wetness = 1.0
	assert_almost_eq(clock.slack_rate(), settings.schedule_slack, 0.001)


# --- Sky and light ---

func test_a_storm_greys_the_sky_and_dims_the_sun() -> void:
	var noon := _time("mediodia")
	var clear := Atmosphere.mix(noon, settings, 0.0, 0.0)
	var storm := Atmosphere.mix(noon, settings, 1.0, 1.0)
	assert_eq(clear.sky_top, noon.sky_top)
	assert_lt(storm.sun_energy, clear.sun_energy * 0.5)
	assert_lt(_saturation(storm.sky_top), _saturation(clear.sky_top))
	assert_gt(storm.fog_extra, clear.fog_extra)
	assert_true(clear.shadows)
	assert_false(storm.shadows, "Overcast skies cast no hard shadows")


func test_a_night_storm_stays_dark() -> void:
	var night := _time("noche")
	var storm := Atmosphere.mix(night, settings, 1.0, 1.0)
	assert_lt(storm.sky_horizon.get_luminance(), 0.2)
	assert_lt(storm.fog.get_luminance(), 0.25)


func _saturation(colour: Color) -> float:
	return colour.s


func test_the_sun_shines_from_where_the_data_puts_it() -> void:
	var sun := Node3D.new()
	sun.rotation = Atmosphere.sun_rotation_for(90.0, 10.0)
	var shine := -sun.basis.z
	assert_lt(shine.x, -0.9, "A sun in the east shines west")
	assert_lt(shine.y, 0.0, "Down onto the town")
	sun.rotation = Atmosphere.sun_rotation_for(270.0, 60.0)
	shine = -sun.basis.z
	assert_gt(shine.x, 0.0, "A sun in the west shines east")
	assert_lt(shine.y, -0.8, "From high up")
	sun.free()


# --- The bus on a wet road ---

func _stopping_distance(grip: float) -> float:
	var model := BusPhysicsModel.new(load("res://data/packs/colombia/buses/buseta.tres"))
	model.grip = grip
	model.speed = 12.0
	var travelled := 0.0
	while model.speed > 0.05:
		var before := model.position
		model.step(0.0, 0.0, 1.0, DT)
		travelled += model.position.distance_to(before)
	return travelled


func test_braking_takes_longer_on_a_wet_road() -> void:
	var dry := _stopping_distance(1.0)
	var wet := _stopping_distance(settings.wet_grip)
	assert_gt(wet, dry * 1.2, "Noticeably longer")
	assert_lt(wet, dry * 1.6, "But still fair")


func test_the_bus_cannot_turn_as_tightly_at_speed_when_wet() -> void:
	var model := BusPhysicsModel.new(load("res://data/packs/colombia/buses/buseta.tres"))
	model.speed = 14.0
	var dry := model.steer_limit()
	model.grip = settings.wet_grip
	assert_lt(model.steer_limit(), dry)
	model.speed = 0.0
	assert_eq(model.steer_limit(), deg_to_rad(model._spec.max_steer_degrees), "Parked, still full lock")


# --- Traffic on a wet road ---

func test_drivers_keep_longer_gaps_in_the_rain() -> void:
	for speed: float in [0.0, 6.0, 12.0]:
		assert_gt(TrafficAgent.desired_gap(speed, 0.0, 1.6), TrafficAgent.desired_gap(speed, 0.0, 1.0), str(speed))
	assert_eq(TrafficAgent.desired_gap(10.0, 0.0), TrafficAgent.desired_gap(10.0, 0.0, 1.0))
	assert_lt(TrafficAgent.acceleration(10.0, 12.0, 20.0, 10.0, 1.6), TrafficAgent.acceleration(10.0, 12.0, 20.0, 10.0, 1.0),
		"The same gap feels too close in the rain")


func _straight_flow() -> TrafficFlow:
	var data := {
		"nodes": [{"id": "w", "x": -600, "z": 0}, {"id": "e", "x": 600, "z": 0}],
		"roads": [{"id": "main", "from": "w", "to": "e", "speed_limit": 60}],
	}
	var network := RoadNetwork.from_data(data, 1)
	var flow := TrafficFlow.new(LaneGraph.build(network, data), BusSpec.new())
	var props: Array[KnockableProp] = []
	flow.watch_props(props)
	flow.set_bus(Vector2(5000.0, 5000.0), 0.0, 0.0, Vector2(5000.0, 5000.0), 0.0, false)
	return flow


func _first_road_lane(flow: TrafficFlow) -> int:
	for i in flow.graph.lanes.size():
		if not (flow.graph.lanes[i] as TrafficLane).is_link and (flow.graph.lanes[i] as TrafficLane).length > 500.0:
			return i
	return 0


func _wet(flow: TrafficFlow) -> void:
	flow.speed_share = settings.traffic_speed
	flow.gap_scale = settings.traffic_gap


## A lone car's top speed on an open road.
func _cruise(wet: bool) -> float:
	var flow := _straight_flow()
	if wet:
		_wet(flow)
	var car := TrafficAgent.new(_first_road_lane(flow), 20.0, 12.0)
	flow.add_agent(car)
	for i in 60 * 30:
		flow.step(DT)
	return car.speed


## The gap a car settles at behind a slow leader.
func _following_gap(wet: bool) -> float:
	var flow := _straight_flow()
	if wet:
		_wet(flow)
	var lane := _first_road_lane(flow)
	var leader := TrafficAgent.new(lane, 120.0, 4.0)
	leader.speed = 4.0
	flow.add_agent(leader)
	var follower := TrafficAgent.new(lane, 40.0, 12.0)
	follower.speed = 8.0
	flow.add_agent(follower)
	var smallest := INF
	for i in 60 * 50:
		flow.step(DT)
		smallest = minf(smallest, leader.distance - follower.distance - TrafficAgent.CAR_LENGTH)
	assert_gt(smallest, 1.0, "Never touches")
	return leader.distance - follower.distance - TrafficAgent.CAR_LENGTH


func test_traffic_drives_slower_in_the_rain() -> void:
	var dry := _cruise(false)
	var wet := _cruise(true)
	assert_almost_eq(wet, dry * settings.traffic_speed, 0.4)


func test_traffic_keeps_longer_gaps_in_the_rain() -> void:
	assert_gt(_following_gap(true), _following_gap(false) + 1.0)


# --- Scoring and progression ---

func test_a_clean_downpour_earns_a_small_bonus() -> void:
	var plain := ShiftScore.new()
	var clean := ShiftScore.new()
	clean.add_downpour(true)
	assert_eq(int(clean.counts["downpours"]), 1)
	assert_eq(int(clean.counts["clean_downpours"]), 1)
	assert_eq(clean.coins(10) - plain.coins(10), ShiftScore.DOWNPOUR_COINS)
	assert_gte(clean.total(), plain.total())


func test_a_rough_downpour_earns_nothing_extra() -> void:
	var plain := ShiftScore.new()
	var rough := ShiftScore.new()
	rough.add_downpour(false)
	assert_eq(int(rough.counts["downpours"]), 1)
	assert_eq(int(rough.counts["clean_downpours"]), 0)
	assert_eq(rough.coins(10), plain.coins(10))
	assert_eq(rough.total(), plain.total())


func test_the_bonus_offsets_a_little_lost_satisfaction() -> void:
	var careful := ShiftScore.new()
	careful.add_jolt()
	careful.add_downpour(true)
	var bumpy := ShiftScore.new()
	bumpy.add_jolt()
	assert_gt(float(careful.categories()["satisfaction"]), float(bumpy.categories()["satisfaction"]))


func _report(counts: Dictionary, time_stat: String = "") -> Dictionary:
	var all := {"collisions": 0, "harsh_brakes": 0, "kerbs": 0, "indicators": 0, "red_lights": 0, "knocked": 0, "jolts": 0}
	all.merge(counts, true)
	return {"score": 80, "stars": 4, "coins": 400, "carried": 20, "counts": all, "time_stat": time_stat}


func test_rain_and_night_shifts_count_towards_achievements() -> void:
	var profile := PlayerProfile.new()
	var list := AchievementList.load_list()
	var rewards := ShiftRewards.apply(profile, _report({"downpours": 1, "clean_downpours": 1}, "night_shifts"), "route_01", "2026-11-08", DailyChallenge.load_list(), list)
	assert_eq(int(profile.stats["rain_shifts"]), 1)
	assert_eq(int(profile.stats["clean_downpours"]), 1)
	assert_eq(int(profile.stats["night_shifts"]), 1)
	var earned := (rewards["achievements"] as Array).map(func(entry: Dictionary) -> String: return entry["id"])
	assert_true(earned.has("first_aguacero"))
	for i in 4:
		ShiftRewards.apply(profile, _report({"downpours": 1, "clean_downpours": 1}, "night_shifts"), "route_01", "2026-11-08", DailyChallenge.load_list(), list)
	assert_true(profile.achievements.has("steady_in_the_rain"))
	assert_true(profile.achievements.has("night_owl"))


func test_an_old_report_without_weather_still_pays() -> void:
	var profile := PlayerProfile.new()
	var report := _report({})
	report.erase("time_stat")
	ShiftRewards.apply(profile, report, "route_01", "2026-11-08", DailyChallenge.load_list(), [])
	assert_eq(int(profile.stats["shifts"]), 1)
	assert_eq(int(profile.stats["rain_shifts"]), 0)


func test_the_choice_of_time_is_saved_and_needs_the_level() -> void:
	var profile := PlayerProfile.new()
	assert_false(profile.choose_time(_time("noche")), "Night is locked for a new driver")
	assert_true(profile.choose_time(_time("mediodia")))
	profile.xp = DriverLevel.xp_for_level(4)
	assert_true(profile.choose_time(_time("noche")))
	var copy := PlayerProfile.from_dict(profile.to_dict())
	assert_eq(copy.time_of_day, "noche")
	assert_eq(PlayerProfile.from_dict({"time_of_day": 7}).time_of_day, "")
	assert_eq(PlayerProfile.from_dict({}).time_of_day, "")
