extends GutTest
## The hidden test cheats.

var taps: Cheats
var profile: PlayerProfile


func before_each() -> void:
	taps = Cheats.new()
	profile = PlayerProfile.new()


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


func test_unlock_everything_owns_all_and_keeps_the_current_choices() -> void:
	var catalog := Catalog.new()
	Cheats.unlock_everything(profile, catalog)
	Cheats.unlock_everything(profile, catalog)
	for kind: String in [Catalog.ROUTES, Catalog.BUSES, Catalog.LIVERIES]:
		var owned: Array = profile.owned[kind]
		assert_eq(owned.size(), catalog.items(kind).size(), "%s with no repeats" % kind)
	assert_eq(profile.selected[Catalog.ROUTES], PlayerProfile.DEFAULT_ROUTE)
