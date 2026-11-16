extends GutTest
## The hidden test cheats.

var taps: Cheats
var profile: PlayerProfile


func before_each() -> void:
	taps = Cheats.new()
	profile = PlayerProfile.new()
	# Each test starts with the release switch back at its shipped default, so a
	# failed test never leaves it off for the ones after it.
	ProjectSettings.set_setting(Cheats.RELEASE_SETTING, true)


func _tap_times(count: int, gap: float, start: float = 0.0) -> bool:
	var revealed := false
	for i in count:
		revealed = taps.tap(start + float(i) * gap)
	return revealed


func test_seven_quick_taps_reveal_the_cheats() -> void:
	assert_false(_tap_times(6, 0.3))
	assert_true(taps.tap(1.8))


func test_a_long_pause_starts_the_count_again() -> void:
	_tap_times(6, 0.3)
	assert_false(taps.tap(10.0), "The sixth tap was too long ago")
	assert_false(_tap_times(5, 0.3, 10.3))
	assert_true(taps.tap(11.8))


func test_the_count_starts_again_after_revealing() -> void:
	_tap_times(7, 0.2)
	assert_false(taps.tap(1.5))


func test_coins_are_added() -> void:
	profile.coins = 120
	Cheats.add_coins(profile, 1000)
	assert_eq(profile.coins, 1120)


func test_each_level_cheat_lands_on_the_start_of_a_level() -> void:
	Cheats.add_levels(profile, 1)
	assert_eq(DriverLevel.level_for(profile.xp), 2)
	assert_eq(DriverLevel.progress(profile.xp), 0.0)
	Cheats.add_levels(profile, 5)
	assert_eq(DriverLevel.level_for(profile.xp), 7)


func test_money_can_be_taken_away_but_not_below_none() -> void:
	profile.coins = 12000
	Cheats.add_coins(profile, -10000)
	assert_eq(profile.coins, 2000)
	Cheats.add_coins(profile, -10000)
	assert_eq(profile.coins, 0)


func test_levels_can_be_taken_away_down_to_level_one() -> void:
	Cheats.set_level(profile, 8)
	profile.xp += 50 # Part way along level 8.
	Cheats.add_levels(profile, -1)
	assert_eq(DriverLevel.level_for(profile.xp), 7)
	assert_eq(DriverLevel.progress(profile.xp), 0.0, "At the start of the level")
	Cheats.add_levels(profile, -5)
	assert_eq(DriverLevel.level_for(profile.xp), 2)
	Cheats.add_levels(profile, -5)
	assert_eq(profile.xp, 0, "Never below level 1")
	assert_eq(DriverLevel.level_for(profile.xp), 1)


func test_taking_levels_undoes_adding_them() -> void:
	Cheats.add_levels(profile, 5)
	Cheats.add_levels(profile, -5)
	assert_eq(DriverLevel.level_for(profile.xp), 1)
	assert_eq(profile.xp, 0)


func test_release_cheats_follow_the_project_switch() -> void:
	ProjectSettings.set_setting(Cheats.RELEASE_SETTING, true)
	assert_true(Cheats.available_in(false), "Release cheats are on while the switch is on")
	ProjectSettings.set_setting(Cheats.RELEASE_SETTING, false)
	assert_false(Cheats.available_in(false), "Release cheats are off while the switch is off")
	ProjectSettings.set_setting(Cheats.RELEASE_SETTING, true)


func test_debug_cheats_ignore_the_switch() -> void:
	ProjectSettings.set_setting(Cheats.RELEASE_SETTING, false)
	assert_true(Cheats.available_in(true), "Debug cheats stay on with the switch off")
	ProjectSettings.set_setting(Cheats.RELEASE_SETTING, true)


func test_max_level_reaches_every_level_gate() -> void:
	var catalog := Catalog.new()
	var top := Cheats.top_level(catalog, Country.pack.horns(), Profile.times_of_day())
	Cheats.set_level(profile, top)
	var level := DriverLevel.level_for(profile.xp)
	assert_eq(level, top)
	for kind: String in Catalog.KINDS:
		for item: Dictionary in catalog.items(kind):
			assert_gte(level, int(item.get("level", 1)), "%s/%s reachable" % [kind, item["id"]])
	for time: TimeOfDay in Profile.times_of_day():
		assert_true(time.is_unlocked(level), "time %s unlocked" % time.id)
	for horn: Dictionary in Country.pack.horns():
		assert_gte(level, int(horn.get("level", 1)), "horn %s reachable" % horn["id"])


func test_unlock_everything_owns_all_and_keeps_the_current_choices() -> void:
	var catalog := Catalog.new()
	Cheats.unlock_everything(profile, catalog, Country.pack.horns())
	Cheats.unlock_everything(profile, catalog, Country.pack.horns())
	for kind: String in Catalog.KINDS:
		var owned: Array = profile.owned[kind]
		assert_eq(owned.size(), catalog.items(kind).size(), "%s with no repeats" % kind)
		for item: Dictionary in catalog.items(kind):
			assert_true(owned.has(item["id"]), "%s owns %s" % [kind, item["id"]])
	for horn: Dictionary in Country.pack.horns():
		assert_true(profile.horns_owned.has(horn["id"]), "owns horn %s" % horn["id"])
	for item: Dictionary in catalog.items(Catalog.ROUTES):
		if catalog.requires(item) != "":
			assert_true(catalog.requirement_met(item, profile), "%s requirement met" % item["id"])
	assert_eq(profile.selected[Catalog.ROUTES], PlayerProfile.DEFAULT_ROUTE)
