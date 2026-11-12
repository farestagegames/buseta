class_name Catalog
extends RefCounted
## Everything a player can unlock, read from data/catalog.json.

const ROUTES := "routes"
const BUSES := "buses"
const LIVERIES := "liveries"
const DRIVERS := "drivers"
const DECORATIONS := "decorations"
const KINDS := [ROUTES, BUSES, LIVERIES, DRIVERS, DECORATIONS]

var data: Dictionary


## Reads the current country's catalog unless given one, as tests do.
func _init(catalog_data: Dictionary = {}) -> void:
	if not catalog_data.is_empty():
		data = catalog_data
		return
	data = MapLoader.read_json(Country.pack.content_path("catalog"))
	for kind: String in KINDS:
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

