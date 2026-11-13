class_name TimeOfDay
extends RefCounted
## One time of day a shift can run at, such as dawn or night, read from the pack's
## "times_of_day" list. It sets the sun, sky, fog and ambient light, whether street
## lamps and windows are lit, how busy the streets are and how likely a downpour
## is. Pure logic. A pack without the list gets one plain day from its map theme.

const COLOURS: Array[String] = ["sun_colour", "sky_top", "sky_horizon", "fog", "ambient"]
const NUMBERS: Array[String] = [
	"level", "sun_from", "sun_elevation", "sun_energy", "ambient_energy", "fog_scale", "lights", "windows",
	"traffic", "pedestrians", "rain_chance",
]
## Values that are shares, from 0 to 1.
const SHARES: Array[String] = ["lights", "windows", "rain_chance"]
const FALLBACK_ID := "day"

var id: String = FALLBACK_ID
var name: String = "Day"
var level: int = 1 ## Driver level that unlocks it.
var is_default: bool = false
## Where the sun is: compass degrees it shines from (90 is east) and its height.
var sun_from: float = 150.0
var sun_elevation: float = 50.0
var sun_colour := Color(1.0, 0.97, 0.9)
var sun_energy: float = 0.82
var shadows: bool = true
var sky_top := Color(0.38, 0.58, 0.82)
var sky_horizon := Color(0.8, 0.85, 0.88)
var fog := Color(0.78, 0.83, 0.87)
var fog_scale: float = 1.0 ## Times the graphics level's haze, such as a misty dawn.
var ambient := Color(0.72, 0.74, 0.78)
var ambient_energy: float = 0.62
var lights: float = 0.0 ## Street lamps, stalls and shelters: 0 off, 1 full night.
var windows: float = 0.0 ## Share of windows lit.
var traffic: float = 1.0 ## Times the usual number of cars and motorbikes.
var pedestrians: float = 1.0
var rain_chance: float = 0.0
var stat: String = "" ## A profile stat counted for each shift at this time.


## Every time of day the pack offers, or one day built from the map theme.
static func list_for(pack_data: Dictionary, theme: CityTheme = null) -> Array[TimeOfDay]:
	var times: Array[TimeOfDay] = []
	var entries: Variant = pack_data.get("times_of_day")
	if entries is Array:
		for entry: Variant in entries:
			if entry is Dictionary and (entry as Dictionary).has("id"):
				var time := from_data(entry)
				if theme != null and (time.id == "madrugada" or time.id == "manana"):
					time.fog_scale *= theme.fog_scale
				times.append(time)
	if times.is_empty():
		times.append(from_theme(theme if theme != null else CityTheme.new()))
	return times


static func from_data(data: Dictionary) -> TimeOfDay:
	var time := TimeOfDay.new()
	time.id = str(data["id"])
	time.name = str(data.get("name", time.id))
	time.is_default = data.get("default") == true
	for key in COLOURS:
		var value: Variant = data.get(key)
		if value is Array and (value as Array).size() >= 3:
			time.set(key, Color(float(value[0]), float(value[1]), float(value[2])))
	for key in NUMBERS:
		var value: Variant = data.get(key)
		if value is float or value is int:
			time.set(key, int(value) if key == "level" else float(value))
	if data.get("shadows") is bool:
		time.shadows = data["shadows"]
	if data.get("stat") is String:
		time.stat = data["stat"]
	return time


## The plain day a map's own theme describes.
static func from_theme(theme: CityTheme) -> TimeOfDay:
	var time := TimeOfDay.new()
	time.is_default = true
	time.sky_top = theme.sky_top
	time.sky_horizon = theme.sky_horizon
	time.fog = theme.fog
	time.fog_scale = theme.fog_scale
	time.ambient = theme.ambient
	time.ambient_energy = theme.ambient_energy
	time.sun_colour = theme.sun_colour
	time.sun_energy = theme.sun_energy
	return time


## The one marked default, or else the first.
static func default_of(times: Array[TimeOfDay]) -> TimeOfDay:
	for time in times:
		if time.is_default:
			return time
	return times[0]


static func find(times: Array[TimeOfDay], time_id: String) -> TimeOfDay:
	for time in times:
		if time.id == time_id:
			return time
	return null


## The time to drive at: the chosen one if the driver's level has unlocked it,
## otherwise the default.
static func pick(times: Array[TimeOfDay], time_id: String, driver_level: int) -> TimeOfDay:
	var chosen := find(times, time_id)
	if chosen != null and chosen.is_unlocked(driver_level):
		return chosen
	return default_of(times)


func is_unlocked(driver_level: int) -> bool:
	return driver_level >= level


## Lamps and windows are on. Also when bus and car lights come on.
func is_dark() -> bool:
	return lights >= 0.3


## Everything wrong with a pack's list. An empty list is fine: the map's day is used.
static func check(entries: Variant) -> Array[String]:
	var problems: Array[String] = []
	if entries == null:
		return problems
	if not entries is Array:
		problems.append("times_of_day must be a list")
		return problems
	var ids := {}
	var defaults := 0
	var free := 0
	for entry: Variant in entries:
		if not entry is Dictionary or not (entry as Dictionary).has("id") or not entry.has("name"):
			problems.append("Times of day need an id and a name")
			continue
		var label := str(entry["id"])
		if ids.has(label):
			problems.append("Times of day have %s twice" % label)
		ids[label] = true
		for key in COLOURS:
			var value: Variant = entry.get(key)
			if not (value is Array and (value as Array).size() >= 3 and (value as Array).all(func(v: Variant) -> bool: return v is float or v is int)):
				problems.append("Time %s needs %s as three numbers" % [label, key])
		for key in NUMBERS:
			var value: Variant = entry.get(key)
			if key == "level" and value == null:
				continue
			if not (value is float or value is int):
				problems.append("Time %s needs %s as a number" % [label, key])
			elif SHARES.has(key) and (float(value) < 0.0 or float(value) > 1.0):
				problems.append("Time %s needs %s from 0 to 1" % [label, key])
			elif float(value) < 0.0:
				problems.append("Time %s has %s below zero" % [label, key])
		if entry.has("shadows") and not entry["shadows"] is bool:
			problems.append("Time %s needs shadows as true or false" % label)
		if entry.has("stat") and not entry["stat"] is String:
			problems.append("Time %s needs stat as text" % label)
		if entry.get("default") == true:
			defaults += 1
			if (entry.get("level", 1) is float or entry.get("level", 1) is int) and int(entry.get("level", 1)) > 1:
				problems.append("The default time of day must be open from level 1")
		var level_value: Variant = entry.get("level", 1)
		if (level_value is float or level_value is int) and int(level_value) <= 1:
			free += 1
	if defaults > 1:
		problems.append("Only one time of day can be the default")
	if not (entries as Array).is_empty() and free == 0:
		problems.append("A pack needs a time of day open from level 1")
	return problems
