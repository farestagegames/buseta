extends GutTest
## One-off first-time celebrations and mid-shift achievement banners.

const PATH := "user://test_firsts_unit.json"

var profile: PlayerProfile
var catalog: Catalog


func before_each() -> void:
	profile = PlayerProfile.new()
	catalog = Catalog.new()
	for suffix: String in ["", SaveStore.BACKUP_SUFFIX, SaveStore.TEMP_SUFFIX]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _firsts() -> Array:
	return [
		{"id": "first_passenger_picked_up", "reward": 50, "achievement": "", "text": "First passenger on board!"},
		{"id": "first_perfect_stop", "reward": 50, "achievement": "", "text": "First perfect stop!"},
		{"id": "first_full_bus", "reward": 75, "achievement": "", "text": "First full bus!"},
		{"id": "first_three_star_route", "reward": 100, "achievement": "five_stars", "text": "First 3-star route!"},
		{"id": "first_rain_shift", "reward": 75, "achievement": "first_aguacero", "text": "First shift in the rain!"},
		{"id": "first_shift_no_fines", "reward": 75, "achievement": "", "text": "First shift with no fines!"},
	]


func _achievements() -> Array:
	return [
		{"id": "five_stars", "name": "Three Star Service", "description": "x", "stat": "best_stars", "target": 3, "reward": 300},
		{"id": "first_aguacero", "name": "First Aguacero", "description": "x", "stat": "rain_shifts", "target": 1, "reward": 200},
	]


func test_first_fires_once_and_coins_added_once() -> void:
	assert_true(FirstsList.mark(profile, "first_passenger_picked_up"))
	assert_true(profile.firsts.has("first_passenger_picked_up"))
	assert_false(FirstsList.mark(profile, "first_passenger_picked_up"), "A first fires only once")


func test_firsts_survive_save_and_load() -> void:
	profile.firsts.append("first_perfect_stop")
	profile.firsts.append("first_full_bus")
	var copy := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	assert_true(copy.firsts.has("first_perfect_stop"))
	assert_true(copy.firsts.has("first_full_bus"))
	assert_eq(copy.firsts.size(), 2)


func test_firsts_survive_disk_save() -> void:
	profile.firsts.append("first_vendor_on_board")
	profile.coins = 123
	SaveStore.write(PATH, profile.to_dict())
	var loaded := PlayerProfile.from_dict(SaveStore.read(PATH))
	assert_true(loaded.firsts.has("first_vendor_on_board"))
	assert_eq(loaded.coins, 123)


func test_firsts_list_loads_and_finds() -> void:
	var list := _firsts()
	assert_eq(FirstsList.find(list, "first_perfect_stop")["reward"], 50)
	assert_true(FirstsList.find(list, "missing").is_empty())


func test_matching_achievement_unlocks_with_one_banner_not_two() -> void:
	# Use a real Profile context on a test save so CelebrationDirector can save safely.
	Profile.load_from(PATH)
	Profile.data.coins = 0
	Profile.data.firsts.clear()
	Profile.data.achievements.clear()
	var seen: Array = []
	var on_celebration := func(text: String, coins: int) -> void:
		seen.append({"text": text, "coins": coins})
	GameEvents.celebration.connect(on_celebration)
	var director := CelebrationDirector.new()
	add_child_autofree(director)
	var spec := BusSpec.new()
	spec.capacity = 20
	var time := TimeOfDay.new()
	time.id = "manana"
	director.setup(Profile.data, _achievements(), _firsts(), spec, null, time, "starter_a", "buseta_8")
	# End-of-shift report that is a 3-star route with no fines.
	var report := {
		"stars": 3, "service": "bays", "fined_coins": 0, "carried": 5, "served": 1, "completed": true,
		"counts": {"fines": 0, "collisions": 0, "harsh_brakes": 0, "knocked": 0, "downpours": 0, "clean_downpours": 0, "vendors": 0},
	}
	director.on_shift_report(report)
	GameEvents.celebration.disconnect(on_celebration)
	# first_three_star_route (100) + five_stars reward (300) in one banner, and
	# first_shift_no_fines (75) as its own first banner.
	assert_true(Profile.data.firsts.has("first_three_star_route"))
	assert_true(Profile.data.firsts.has("first_shift_no_fines"))
	assert_true(Profile.data.achievements.has("five_stars"))
	assert_eq(Profile.data.coins, 475)
	var star_banners := 0
	for entry: Dictionary in seen:
		if str(entry["text"]) == "First 3-star route!":
			star_banners += 1
	assert_eq(star_banners, 1, "One banner for a first that matches an achievement")
	assert_eq(seen.size(), 2)


func test_coins_added_once_even_if_triggered_again() -> void:
	Profile.load_from(PATH)
	Profile.data.coins = 10
	Profile.data.firsts.clear()
	Profile.data.achievements.clear()
	var director := CelebrationDirector.new()
	add_child_autofree(director)
	var spec := BusSpec.new()
	spec.capacity = 2
	var time := TimeOfDay.new()
	time.id = "manana"
	director.setup(Profile.data, [], _firsts(), spec, null, time, "starter_a", "buseta_8")
	GameEvents.passenger_boarded.emit(0)
	GameEvents.passenger_boarded.emit(0)
	assert_eq(Profile.data.coins, 10 + 50, "First passenger reward added once")
	assert_eq(Profile.data.firsts.count("first_passenger_picked_up"), 1)


func test_full_bus_first_fires_once() -> void:
	Profile.load_from(PATH)
	Profile.data.coins = 0
	Profile.data.firsts.clear()
	var director := CelebrationDirector.new()
	add_child_autofree(director)
	var spec := BusSpec.new()
	spec.capacity = 3
	var time := TimeOfDay.new()
	time.id = "manana"
	director.setup(Profile.data, [], _firsts(), spec, null, time, "starter_a", "buseta_8")
	GameEvents.onboard_changed.emit(3)
	GameEvents.onboard_changed.emit(3)
	assert_true(Profile.data.firsts.has("first_full_bus"))
	assert_eq(Profile.data.coins, 75, "Full bus reward once")
