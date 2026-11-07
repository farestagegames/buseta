class_name CountryPack
extends RefCounted
## One country: how its traffic works and all of its content, read from a folder
## of data files. A new country is a new folder, not new code. Pure logic.

const RIGHT_HAND := 1
const LEFT_HAND := -1
const SPEED_UNITS := {"kmh": 1.0, "mph": 0.621371}
const REQUIRED_FIELDS: Array[String] = [
	"id", "name", "driving_side", "road_rules", "signage", "currency", "languages",
	"default_language", "content", "sounds", "horns", "radio",
]
const REQUIRED_CONTENT: Array[String] = ["catalog", "achievements", "daily_challenges", "passengers"]
const REQUIRED_KINDS: Array[String] = [Catalog.ROUTES, Catalog.BUSES, Catalog.LIVERIES, Catalog.DRIVERS]

var id: String = ""
var display_name: String = ""
var traffic_side: int = RIGHT_HAND
var data: Dictionary = {}
var folder: String = ""


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


func colour(section: String, key: String, fallback: Color) -> Color:
	var value: Variant = (data.get(section, {}) as Dictionary).get(key)
	if value is Array and (value as Array).size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]))
	return fallback


func passengers() -> Dictionary:
	return MapLoader.read_json(content_path("passengers"))


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
	_check_content(problems)
	return problems


func _check_languages(problems: Array[String]) -> void:
	var codes: Array = (data["languages"] as Array).map(func(language: Dictionary) -> String: return language["code"])
	if codes.is_empty():
		problems.append("A pack needs at least one language")
	if not codes.has(data["default_language"]):
		problems.append("default_language is not one of the languages")


func _check_sounds(problems: Array[String]) -> void:
	for key: String in data["sounds"]:
		_check_file(problems, data["sounds"][key], "sound %s" % key)
	if (data["horns"] as Array).is_empty():
		problems.append("A pack needs at least one horn")
	for horn: Dictionary in data["horns"]:
		_check_file(problems, horn["file"], "horn %s" % horn["id"])
	for station: Dictionary in data["radio"]:
		for track: Dictionary in station.get("tracks", []):
			_check_file(problems, track["file"], "radio track")


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
	for bus: Dictionary in catalog.get(Catalog.BUSES, []):
		_check_file(problems, bus["file"], "bus %s" % bus["id"])
	for route: Dictionary in catalog.get(Catalog.ROUTES, []):
		_check_route(problems, route)


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
	if stops.is_empty() or not (stops[stops.size() - 1] as Dictionary).get("final", false):
		problems.append("Route %s must end at a final stop" % item["id"])
