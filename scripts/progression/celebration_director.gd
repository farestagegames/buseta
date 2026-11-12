class_name CelebrationDirector
extends Node
## Watches the shift for first-time celebrations and achievements, shows one
## mid-shift banner each and gives their coin rewards once.

var _profile: PlayerProfile
var _achievements: Array = []
var _firsts: Array = []
var _capacity: int = 0
var _route_id: String = ""
var _bus_id: String = ""
var _vendors_this_shift: int = 0
var _fares_this_shift: int = 0
var _passengers_this_shift: int = 0
var _ended: bool = false


var _perfect_stop_cb: Callable
var _connected: bool = false

func setup(profile: PlayerProfile, achievements: Array, firsts: Array, spec: BusSpec, route: Variant, time: Variant, route_id: String, bus_id: String) -> void:
	_profile = profile
	_achievements = achievements
	_firsts = firsts
	_capacity = spec.capacity if spec != null else 0
	_route_id = route_id
	_bus_id = bus_id
	_vendors_this_shift = 0
	_fares_this_shift = 0
	_passengers_this_shift = 0
	_ended = false
	_connect()
	# Shift-start firsts.
	if time != null and str(time.id) == "noche":
		_trigger_first("first_night_shift")
	if _bus_id == "chiva":
		_trigger_first("first_chiva_drive")
	if _route_id == "troncal":
		_trigger_first("first_la_ola_shift")
	_check_live_achievements()


func _connect() -> void:
	if _connected:
		return
	_connected = true
	GameEvents.passenger_boarded.connect(_on_passenger_boarded)
	_perfect_stop_cb = func(_i: int) -> void: _trigger_first("first_perfect_stop")
	GameEvents.perfect_stop.connect(_perfect_stop_cb)
	GameEvents.onboard_changed.connect(_on_onboard_changed)
	GameEvents.vendor_boarded.connect(_on_vendor_boarded)
	GameEvents.fare_collected.connect(_on_fare_collected)
	GameEvents.weather_updated.connect(_on_weather)


func _exit_tree() -> void:
	if not _connected:
		return
	if GameEvents.passenger_boarded.is_connected(_on_passenger_boarded):
		GameEvents.passenger_boarded.disconnect(_on_passenger_boarded)
	if _perfect_stop_cb.is_valid() and GameEvents.perfect_stop.is_connected(_perfect_stop_cb):
		GameEvents.perfect_stop.disconnect(_perfect_stop_cb)
	if GameEvents.onboard_changed.is_connected(_on_onboard_changed):
		GameEvents.onboard_changed.disconnect(_on_onboard_changed)
	if GameEvents.vendor_boarded.is_connected(_on_vendor_boarded):
		GameEvents.vendor_boarded.disconnect(_on_vendor_boarded)
	if GameEvents.fare_collected.is_connected(_on_fare_collected):
		GameEvents.fare_collected.disconnect(_on_fare_collected)
	if GameEvents.weather_updated.is_connected(_on_weather):
		GameEvents.weather_updated.disconnect(_on_weather)
	_connected = false


func _on_passenger_boarded(_stop: int) -> void:
	_passengers_this_shift += 1
	_trigger_first("first_passenger_picked_up")
	_check_live_achievements()


func _on_onboard_changed(count: int) -> void:
	if count >= _capacity and _capacity > 0:
		_trigger_first("first_full_bus")


func _on_vendor_boarded() -> void:
	_vendors_this_shift += 1
	_trigger_first("first_vendor_on_board")
	_check_live_achievements()


func _on_fare_collected(amount: int) -> void:
	_fares_this_shift += amount
	_check_live_achievements()


func _on_weather(weather: WeatherClock) -> void:
	if weather != null and weather.is_downpour():
		_trigger_first("first_rain_shift")


## Called when the shift report is ready, before rewards are applied, so end-of-
## shift firsts and achievements can celebrate and be recorded without double pay.
func on_shift_report(report: Dictionary) -> void:
	if _ended:
		return
	_ended = true
	# End-of-shift firsts.
	if int(report.get("stars", 0)) >= 3 and str(report.get("service", "bays")) not in ["arcade", "endless"]:
		_trigger_first("first_three_star_route")
	var counts: Dictionary = report.get("counts", {})
	if int(counts.get("fines", 0)) == 0 and int(report.get("fined_coins", 0)) == 0:
		_trigger_first("first_shift_no_fines")
	# Apply final stats in a temporary view? No: ShiftRewards will apply them. But
	# achievements like first_shift/clean_shift depend on final stats. We need to
	# award them now (with banner) so they are marked and not double-paid later.
	# Simulate the stat updates ShiftRewards will do, on the profile, is risky if
	# apply does them again. Instead, check against final totals without keeping
	# the increments except via a helper: award achievements whose condition is met
	# by (current stats + this shift's contribution).
	_award_end_achievements(report)


func _trigger_first(id: String) -> void:
	var entry := FirstsList.find(_firsts, id)
	if entry.is_empty():
		return
	if _profile.firsts.has(id):
		return
	_profile.firsts.append(id)
	var coins := FirstsList.reward_of(entry)
	var achievement := FirstsList.achievement_id(entry)
	if achievement != "" and not _profile.achievements.has(achievement):
		_profile.achievements.append(achievement)
		coins += _achievement_reward(achievement)
	_profile.coins += coins
	Profile.save()
	GameEvents.celebration.emit(str(entry.get("text", id)), coins)


func _achievement_reward(id: String) -> int:
	for value: Variant in _achievements:
		if value is Dictionary and (value as Dictionary).get("id", "") == id:
			return AchievementList.reward_of(value)
	return 0


func _check_live_achievements() -> void:
	for value: Variant in _achievements:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		var id: String = str(entry.get("id", ""))
		if id == "" or _profile.achievements.has(id):
			continue
		var stat: String = str(entry.get("stat", ""))
		var target := int(entry.get("target", 0))
		if target <= 0:
			continue
		if _live_progress(stat) >= target:
			_unlock_achievement(entry)


func _live_progress(stat: String) -> int:
	var base := int(_profile.stats.get(stat, 0))
	if stat == "passengers":
		return base + _passengers_this_shift
	if stat == "vendors":
		return base + _vendors_this_shift
	if stat == "fares":
		return base + _fares_this_shift
	return base


func _unlock_achievement(entry: Dictionary) -> void:
	var id: String = str(entry.get("id", ""))
	if _profile.achievements.has(id):
		return
	_profile.achievements.append(id)
	var coins := AchievementList.reward_of(entry)
	_profile.coins += coins
	Profile.save()
	var name := str(entry.get("name", id))
	GameEvents.celebration.emit(tr("Achievement: %s") % tr(name), coins)


func _award_end_achievements(report: Dictionary) -> void:
	# Build final stat totals as ShiftRewards will produce them.
	var stats: Dictionary = {}
	for key: Variant in _profile.stats.keys():
		stats[key] = int(_profile.stats[key])
	stats["shifts"] = int(stats.get("shifts", 0)) + 1
	stats["passengers"] = int(stats.get("passengers", 0)) + int(report.get("carried", 0))
	var counts: Dictionary = report.get("counts", {})
	if int(counts.get("collisions", 0)) == 0:
		stats["clean_shifts"] = int(stats.get("clean_shifts", 0)) + 1
	if int(counts.get("harsh_brakes", 0)) == 0:
		stats["smooth_shifts"] = int(stats.get("smooth_shifts", 0)) + 1
	if int(counts.get("downpours", 0)) > 0:
		stats["rain_shifts"] = int(stats.get("rain_shifts", 0)) + 1
	stats["clean_downpours"] = int(stats.get("clean_downpours", 0)) + int(counts.get("clean_downpours", 0))
	var time_stat: String = str(report.get("time_stat", ""))
	if time_stat != "":
		stats[time_stat] = int(stats.get(time_stat, 0)) + 1
	stats["vendors"] = int(stats.get("vendors", 0)) + int(counts.get("vendors", 0))
	stats["fares"] = int(stats.get("fares", 0)) + int(report.get("fares", 0))
	var route_stat := AchievementList.ROUTE_PREFIX + _route_id
	stats[route_stat] = int(stats.get(route_stat, 0)) + 1
	if _bus_id != "":
		var bus_stat := AchievementList.BUS_PREFIX + _bus_id
		stats[bus_stat] = int(stats.get(bus_stat, 0)) + 1
	# best_stars/routes_driven/dailies/best_daily_streak updated in apply; approximate conservatively
	var best_stars := maxi(int(stats.get("best_stars", 0)), int(report.get("stars", 0)))
	for v: Variant in _profile.best_stars.values():
		best_stars = maxi(best_stars, int(v))
	stats["best_stars"] = best_stars
	# routes_driven becomes best_scores.size() after record; if new best, +1 possible
	var routes_driven := _profile.best_scores.size()
	if not _profile.best_scores.has(_route_id):
		routes_driven += 1
	stats["routes_driven"] = routes_driven
	# dailies/streak handled in apply - can't know here easily, skip pre-award for them
	# (they'll award at end without mid-shift banner in this edge path, acceptable).
	for value: Variant in _achievements:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		var id: String = str(entry.get("id", ""))
		if id == "" or _profile.achievements.has(id):
			continue
		if int(stats.get(str(entry.get("stat", "")), 0)) >= int(entry.get("target", 0)):
			_unlock_achievement(entry)
