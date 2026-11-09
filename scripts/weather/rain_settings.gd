class_name RainSettings
extends RefCounted
## How a country's downpours behave, read from "weather.rain" in its pack: how they
## build, last and clear, and what a wet road does to grip, traffic and people.
## Pure logic. Anything missing keeps the value below.

## Ranges, as [shortest, longest].
const RANGES: Array[String] = ["build_seconds", "rain_seconds", "clear_seconds", "start_share", "strength"]
## Shares, from 0 to 1.
const SHARES: Array[String] = ["wet_grip", "traffic_speed", "pedestrians", "umbrellas", "darken", "sun_dim", "lights", "schedule_slack"]
const NUMBERS: Array[String] = ["dry_seconds", "traffic_gap", "fog_density"]

var build_seconds := Vector2(15.0, 25.0) ## Clouds gather, wind, first drops.
var rain_seconds := Vector2(110.0, 190.0) ## The downpour itself.
var clear_seconds := Vector2(20.0, 30.0) ## Easing off until the sun is back.
var start_share := Vector2(0.2, 0.5) ## When it starts, as a share of the shift's timetable.
var strength := Vector2(0.7, 1.0) ## How hard it rains at its peak.
var wet_grip: float = 0.7 ## Tyre grip on a soaked road, as a share of dry.
var dry_seconds: float = 90.0 ## A soaked road takes this long to dry.
var traffic_speed: float = 0.8 ## Traffic's speed on a soaked road, as a share.
var traffic_gap: float = 1.6 ## Times the usual following gap on a soaked road.
var pedestrians: float = 0.35 ## Share of walkers still out in a downpour.
var umbrellas: float = 0.7 ## Share of those walkers with an umbrella.
var fog_density: float = 0.011 ## Extra haze in a full downpour.
var storm_sky := Color(0.45, 0.49, 0.55) ## The grey the sky turns, at midday brightness.
var darken: float = 0.55 ## How much the sky and fog turn to storm grey.
var sun_dim: float = 0.8 ## How much sunlight the clouds take away.
var lights: float = 0.5 ## Street lamps come on this much in a downpour.
var schedule_slack: float = 0.2 ## The timetable allows this much slower on a wet road.


static func from_pack(pack_data: Dictionary) -> RainSettings:
	var weather: Variant = pack_data.get("weather")
	var rain: Variant = (weather as Dictionary).get("rain") if weather is Dictionary else null
	return from_data(rain if rain is Dictionary else {})


static func from_data(data: Dictionary) -> RainSettings:
	var settings := RainSettings.new()
	for key in RANGES:
		var value: Variant = data.get(key)
		if _is_range(value):
			settings.set(key, Vector2(float(value[0]), float(value[1])))
	for key: String in SHARES + NUMBERS:
		var value: Variant = data.get(key)
		if value is float or value is int:
			settings.set(key, float(value))
	var sky: Variant = data.get("storm_sky")
	if sky is Array and (sky as Array).size() >= 3:
		settings.storm_sky = Color(float(sky[0]), float(sky[1]), float(sky[2]))
	return settings


static func _is_range(value: Variant) -> bool:
	return value is Array and (value as Array).size() == 2 \
		and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int) \
		and float(value[0]) <= float(value[1]) and float(value[0]) >= 0.0


## Everything wrong with a pack's "weather" block. A pack without one is fine.
static func check(weather: Variant) -> Array[String]:
	var problems: Array[String] = []
	if weather == null:
		return problems
	if not weather is Dictionary:
		problems.append("weather must be a set of values")
		return problems
	var rain: Variant = (weather as Dictionary).get("rain")
	if rain == null:
		return problems
	if not rain is Dictionary:
		problems.append("weather.rain must be a set of values")
		return problems
	for key in RANGES:
		if rain.has(key) and not _is_range(rain[key]):
			problems.append("weather.rain.%s needs [shortest, longest]" % key)
	for key in SHARES:
		if rain.has(key) and not ((rain[key] is float or rain[key] is int) and float(rain[key]) >= 0.0 and float(rain[key]) <= 1.0):
			problems.append("weather.rain.%s needs a number from 0 to 1" % key)
	for key in NUMBERS:
		if rain.has(key) and not ((rain[key] is float or rain[key] is int) and float(rain[key]) >= 0.0):
			problems.append("weather.rain.%s needs a number of 0 or more" % key)
	for key: String in ["start_share", "strength"]:
		if rain.has(key) and _is_range(rain[key]) and float(rain[key][1]) > 1.0:
			problems.append("weather.rain.%s cannot go above 1" % key)
	if rain.has("traffic_gap") and (rain["traffic_gap"] is float or rain["traffic_gap"] is int) and float(rain["traffic_gap"]) < 1.0:
		problems.append("weather.rain.traffic_gap must be 1 or more, as rain never shortens gaps")
	if rain.has("storm_sky") and not (rain["storm_sky"] is Array and (rain["storm_sky"] as Array).size() >= 3):
		problems.append("weather.rain.storm_sky needs three numbers")
	return problems
