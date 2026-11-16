class_name Catalog
extends RefCounted
## Everything a player can unlock, read from data/catalog.json.

const ROUTES := "routes"
const BUSES := "buses"
const LIVERIES := "liveries"
const DRIVERS := "drivers"
const DECORATIONS := "decorations"
const KINDS := [ROUTES, BUSES, LIVERIES, DRIVERS, DECORATIONS]
## Routes taken out of the game (Puerto Remanso, 16 Nov) but kept on disk with
## their maps: never listed, unlocked or played, only read by tests and tools.
const ARCHIVED := "archived_routes"

var data: Dictionary


## Reads the current country's catalog unless given one, as tests do.
func _init(catalog_data: Dictionary = {}) -> void:
	if not catalog_data.is_empty():
		data = catalog_data
		return
	data = MapLoader.read_json(Country.pack.content_path("catalog"))
	for kind: String in KINDS + [ARCHIVED]:
		for item: Dictionary in data.get(kind, []):
			if item.has("file"):
				item["file"] = Country.pack.resolve(item["file"])


func items(kind: String) -> Array:
	return data.get(kind, [])


func find(kind: String, id: String) -> Dictionary:
	for item: Dictionary in items(kind):
		if item["id"] == id:
			return item
	return {}


## An archived route by id, or {}.
func find_archived(id: String) -> Dictionary:
	for item: Dictionary in data.get(ARCHIVED, []):
		if item["id"] == id:
			return item
	return {}


## True for an arcade course (Carrera Express), which has its own Home button and
## is never listed with the routes or kept as the chosen route.
static func is_arcade(item: Dictionary) -> bool:
	return str(item.get("mode", "")) == "arcade"


## Every arcade course, one per town, in catalog order.
func arcade_routes() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for item: Dictionary in items(ROUTES):
		if is_arcade(item):
			found.append(item)
	return found


## The arcade course of a town (its map's name), or {} if that town has none.
## With no town, the first arcade in the catalog (Puerto Marisol's).
func arcade_route(town: String = "") -> Dictionary:
	for item: Dictionary in arcade_routes():
		if town == "" or route_town(item) == town:
			return item
	return {}


var _town_cache := {}


## The name of the town (map) a route runs in, or "" if it has no route file.
func route_town(item: Dictionary) -> String:
	var file := str(item.get("file", ""))
	if file == "":
		return ""
	if not _town_cache.has(file):
		var map_path := str(MapLoader.read_json(file).get("map", ""))
		_town_cache[file] = "" if map_path == "" else str(MapLoader.read_json(Country.pack.resolve(map_path)).get("name", ""))
	return _town_cache[file]


## The route a new player starts on.
func default_route() -> String:
	var route: Variant = data.get("default_route", "")
	if route is String and not find(ROUTES, route).is_empty():
		return route
	var routes := items(ROUTES)
	return routes[0]["id"] if not routes.is_empty() else ""


## The route id that must be finished before this item can be used, or "".
func requires(item: Dictionary) -> String:
	var need: Variant = item.get("requires", "")
	return need if need is String else ""


## A required item this player can already use: owned now, or finished in the past.
func requirement_met(item: Dictionary, profile: PlayerProfile) -> bool:
	var need := requires(item)
	if need == "":
		return true
	return profile.owns(ROUTES, need) or profile.has_completed_route(need)


## Items unlocked by finishing route_id, that the player does not own yet.
func unlocked_by(route_id: String, profile: PlayerProfile) -> Array[Dictionary]:
	var granted: Array[Dictionary] = []
	for item: Dictionary in items(ROUTES):
		if requires(item) == route_id and not profile.owns(ROUTES, item["id"]) and requirement_met(item, profile):
			granted.append(item)
	return granted

