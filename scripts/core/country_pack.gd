class_name CountryPack
extends RefCounted
## One country: how its traffic works and all of its content, read from a folder
## of data files. A new country is a new folder, not new code. Pure logic.

const RIGHT_HAND := 1
const LEFT_HAND := -1
const SPEED_UNITS := {"kmh": 1.0, "mph": 0.621371}
const REQUIRED_FIELDS: Array[String] = [
	"id", "name", "city_name", "driving_side", "road_rules", "signage", "currency", "languages",
	"default_language", "fonts", "content", "sounds", "horns", "radio",
]
const REQUIRED_CONTENT: Array[String] = ["catalog", "achievements", "daily_challenges", "passengers"]
const REQUIRED_KINDS: Array[String] = [Catalog.ROUTES, Catalog.BUSES, Catalog.LIVERIES, Catalog.DRIVERS]

var id: String = ""
var display_name: String = ""
var traffic_side: int = RIGHT_HAND
var data: Dictionary = {}
var folder: String = ""

var _passenger_looks: PassengerLooks


static func read(pack_file: String) -> CountryPack:
	var pack := CountryPack.new()
	pack.folder = pack_file.get_base_dir() + "/"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(pack_file)) if FileAccess.file_exists(pack_file) else null
	pack.data = parsed if parsed is Dictionary else {}
	pack.id = str(pack.data.get("id", ""))
	pack.display_name = str(pack.data.get("name", ""))
	pack.traffic_side = LEFT_HAND if pack.data.get("driving_side") == "left" else RIGHT_HAND
	return pack


## A path in a pack is relative to its folder, unless it names a full res:// path.
func resolve(path: String) -> String:
	return path if path.begins_with("res://") else folder + path


func content_path(key: String) -> String:
	return resolve(data["content"][key])


func speed_unit() -> String:
	return data["road_rules"]["speed_unit"]


## Road speeds are kept in km/h. This converts one for the driver to read.
func display_speed(kmh: float) -> float:
	return kmh * float(SPEED_UNITS[speed_unit()])


func default_speed_limit() -> float:
	return float(data["road_rules"]["default_speed_limit"])


func languages() -> Array:
	return data["languages"]


func sound(key: String, fallback: String) -> String:
	return str((data["sounds"] as Dictionary).get(key, fallback))


## Every horn a player can fit: id, name, file, and optionally cost, level,
## volume_db and "finish" for a tune that plays to its end. Broken entries are
## left out here, so nothing that lists horns can trip on them; validate() names them.
func horns() -> Array:
	return _horn_entries().filter(func(item: Variant) -> bool:
		return item is Dictionary and (item as Dictionary).has("id") and item.has("file"))


func _horn_entries() -> Array:
	var list: Variant = data.get("horns", [])
	return list if list is Array else []


## The horn with this id, or the pack's first horn if there is none.
func horn(horn_id: String) -> Dictionary:
	for item: Dictionary in horns():
		if item["id"] == horn_id:
			return item
	return horns()[0] if not horns().is_empty() else {}


## The horn a bus comes with: its catalog entry's "horn", or the pack's first.
func bus_horn(bus_item: Dictionary) -> Dictionary:
	return horn(str(bus_item.get("horn", "")))


## Radio stations: id, name, frequency, genre and tracks. Empty hides the radio.
func radio_stations() -> Array:
	var list: Variant = data.get("radio", [])
	return list if list is Array else []


## Street sound layers, see AmbienceMixer. Optional: a pack without them is quiet.
func ambience_layers() -> Array:
	var list: Variant = data.get("ambience", [])
	return list if list is Array else []


func colour(section: String, key: String, fallback: Color) -> Color:
	var value: Variant = (data.get(section, {}) as Dictionary).get(key)
	if value is Array and (value as Array).size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]))
	return fallback


## How the people in the street and on the bus look. Read once, and never fails.
func passenger_looks() -> PassengerLooks:
	if _passenger_looks == null:
		var content: Variant = data.get("content")
		var file: Variant = (content as Dictionary).get("passengers") if content is Dictionary else null
		_passenger_looks = PassengerLooks.read(resolve(file) if file is String else "")
	return _passenger_looks


## In-game coins as this country's money, such as $12.500.
func money(coins: int) -> String:
	var currency: Dictionary = data["currency"]
	var digits := str(absi(coins) * int(currency["per_coin"]))
	var grouped := ""
	while digits.length() > 3:
		grouped = str(currency["thousands"]) + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return "%s%s%s" % ["-" if coins < 0 else "", currency["symbol"], digits + grouped]


## Everything wrong with this pack, or nothing if it is ready to play.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if data.is_empty():
		return ["The pack file could not be read"]
	for field in REQUIRED_FIELDS:
		if not data.has(field):
			problems.append("Missing field: %s" % field)
	if not problems.is_empty():
		return problems
	if data["driving_side"] != "left" and data["driving_side"] != "right":
		problems.append("driving_side must be left or right")
	if not SPEED_UNITS.has(data["road_rules"].get("speed_unit")):
		problems.append("road_rules.speed_unit must be kmh or mph")
	if float(data["road_rules"].get("default_speed_limit", 0)) <= 0.0:
		problems.append("road_rules.default_speed_limit must be above zero")
	for key: String in ["symbol", "thousands", "per_coin"]:
		if not (data["currency"] as Dictionary).has(key):
			problems.append("currency.%s is missing" % key)
	_check_languages(problems)
	_check_sounds(problems)
	_check_weather(problems)
	problems.append_array(Difficulty.check(data.get("difficulties"), data.get("default_difficulty", "")))
	_check_content(problems)
	return problems


## Times of day and weather are optional. A pack without them gets a plain day
## from its map and no rain.
func _check_weather(problems: Array[String]) -> void:
	problems.append_array(TimeOfDay.check(data.get("times_of_day")))
	problems.append_array(RainSettings.check(data.get("weather")))
	var stats := PlayerProfile.new().stats
	for time in TimeOfDay.list_for(data):
		if time.stat != "" and not stats.has(time.stat):
			problems.append("Time %s counts an unknown stat %s" % [time.id, time.stat])


func _check_languages(problems: Array[String]) -> void:
	var codes: Array = (data["languages"] as Array).map(func(language: Dictionary) -> String: return language["code"])
	for language: Dictionary in data["languages"]:
		if language.has("file"):
			_check_file(problems, language["file"], "language file %s" % language["code"])
	if codes.is_empty():
		problems.append("A pack needs at least one language")
	if not codes.has(data["default_language"]):
		problems.append("default_language is not one of the languages")


func _check_sounds(problems: Array[String]) -> void:
	for key: String in data["sounds"]:
		_check_file(problems, data["sounds"][key], "sound %s" % key)
	_check_horns(problems)
	problems.append_array(RadioTuner.check(radio_stations()))
	for station: Variant in radio_stations():
		if station is Dictionary:
			for track: Variant in (station as Dictionary).get("tracks", []):
				if track is Dictionary and (track as Dictionary).has("file"):
					_check_file(problems, track["file"], "radio track")
	problems.append_array(AmbienceMixer.check(ambience_layers()))
	for layer: Variant in ambience_layers():
		if layer is Dictionary and (layer as Dictionary).has("file"):
			_check_file(problems, layer["file"], "ambience %s" % layer.get("id", ""))


func _check_horns(problems: Array[String]) -> void:
	if _horn_entries().is_empty():
		problems.append("A pack needs at least one horn")
		return
	var ids := {}
	var free := 0
	for item: Variant in _horn_entries():
		if not item is Dictionary or not ((item as Dictionary).has("id") and item.has("name") and item.has("file")):
			problems.append("Horns need an id, a name and a file")
			continue
		if ids.has(item["id"]):
			problems.append("Horns have %s twice" % item["id"])
		ids[item["id"]] = true
		for key: String in ["cost", "level", "volume_db"]:
			if item.has(key) and not (item[key] is int or item[key] is float):
				problems.append("Horn %s needs %s as a number" % [item["id"], key])
		if item.has("finish") and not item["finish"] is bool:
			problems.append("Horn %s needs finish as true or false" % item["id"])
		if not (item.get("cost", 0) is int or item.get("cost", 0) is float) \
				or not (item.get("level", 1) is int or item.get("level", 1) is float):
			continue
		if int(item.get("cost", 0)) < 0:
			problems.append("Horn %s costs less than nothing" % item["id"])
		if int(item.get("cost", 0)) == 0 and int(item.get("level", 1)) <= 1:
			free += 1
		_check_file(problems, item["file"], "horn %s" % item["id"])
	if free == 0:
		problems.append("A pack needs at least one free horn")


func _check_file(problems: Array[String], path: String, label: String) -> void:
	if not ResourceLoader.exists(resolve(path)) and not FileAccess.file_exists(resolve(path)):
		problems.append("Missing %s: %s" % [label, path])


func _check_content(problems: Array[String]) -> void:
	for key in REQUIRED_CONTENT:
		if not (data["content"] as Dictionary).has(key):
			problems.append("Missing content file: %s" % key)
		else:
			_check_file(problems, data["content"][key], "content file %s" % key)
	if not problems.is_empty():
		return
	var catalog: Dictionary = MapLoader.read_json(content_path("catalog"))
	for kind in REQUIRED_KINDS:
		var items: Array = catalog.get(kind, [])
		var free := items.filter(func(item: Dictionary) -> bool: return int(item["cost"]) == 0)
		if free.is_empty():
			problems.append("%s needs at least one free item" % kind)
		var ids := {}
		for item: Dictionary in items:
			if ids.has(item["id"]):
				problems.append("%s has %s twice" % [kind, item["id"]])
			ids[item["id"]] = true
	var horn_ids := horns().map(func(item: Variant) -> String: return str(item.get("id", "")) if item is Dictionary else "")
	for bus: Dictionary in catalog.get(Catalog.BUSES, []):
		_check_file(problems, bus["file"], "bus %s" % bus["id"])
		if bus.has("horn") and not horn_ids.has(bus["horn"]):
			problems.append("Bus %s has an unknown horn %s" % [bus["id"], bus["horn"]])
	problems.append_array(PassengerLooks.check(PassengerLooks.parse_file(content_path("passengers"))))
	for driver: Dictionary in catalog.get(Catalog.DRIVERS, []):
		problems.append_array(DriverLook.check(driver))
	for route: Dictionary in catalog.get(Catalog.ROUTES, []):
		_check_route(problems, route)
	var route_ids := (catalog.get(Catalog.ROUTES, []) as Array).map(func(item: Dictionary) -> String: return item["id"])
	var bus_ids := (catalog.get(Catalog.BUSES, []) as Array).map(func(item: Dictionary) -> String: return item["id"])
	var time_ids := TimeOfDay.list_for(data).map(func(time: TimeOfDay) -> String: return time.id)
	problems.append_array(DailyChallenge.check(JSON.parse_string(FileAccess.get_file_as_string(content_path("daily_challenges"))), route_ids, bus_ids, time_ids))
	problems.append_array(AchievementList.check(JSON.parse_string(FileAccess.get_file_as_string(content_path("achievements"))), route_ids, bus_ids))


func _check_route(problems: Array[String], item: Dictionary) -> void:
	var path := resolve(item["file"])
	if not FileAccess.file_exists(path):
		problems.append("Missing route %s" % item["id"])
		return
	var route: Dictionary = MapLoader.read_json(path)
	var map_path := resolve(route["map"])
	if not FileAccess.file_exists(map_path):
		problems.append("Route %s has no map at %s" % [item["id"], route["map"]])
		return
	var roads: Array = (MapLoader.read_json(map_path)["roads"] as Array).map(func(road: Dictionary) -> String: return road["id"])
	for leg: Dictionary in route["legs"]:
		if not roads.has(leg["road"]):
			problems.append("Route %s uses unknown road %s" % [item["id"], leg["road"]])
	var stops: Array = route["stops"]
	if route.get("service", "") == "endless":
		if not (route.get("hail") is Dictionary):
			problems.append("Endless route %s needs hail settings" % item["id"])
		return
	if stops.is_empty() or not (stops[stops.size() - 1] as Dictionary).get("final", false):
		problems.append("Route %s must end at a final stop" % item["id"])
