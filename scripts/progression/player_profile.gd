class_name PlayerProfile
extends RefCounted
## All saved player progress as plain data, with the rules for spending it.
## Pure logic. Loading tolerates missing or damaged fields, so an old or hand
## edited save can never stop the game from starting.

const VERSION := 1
const DEFAULT_ROUTE := "route_01"
const DEFAULT_BUS := "buseta_8"
const DEFAULT_LIVERY := "rojo_caribe"
const DEFAULT_DRIVER := "sam_reed"

var coins: int = 0
var xp: int = 0
var owned: Dictionary = {
	Catalog.ROUTES: [DEFAULT_ROUTE], Catalog.BUSES: [DEFAULT_BUS], Catalog.LIVERIES: [DEFAULT_LIVERY],
	Catalog.DRIVERS: [DEFAULT_DRIVER],
}
var selected: Dictionary = {
	Catalog.ROUTES: DEFAULT_ROUTE, Catalog.BUSES: DEFAULT_BUS, Catalog.LIVERIES: DEFAULT_LIVERY,
	Catalog.DRIVERS: DEFAULT_DRIVER,
}
var stats: Dictionary = {
	"shifts": 0, "passengers": 0, "best_stars": 0, "clean_shifts": 0, "smooth_shifts": 0,
}
var achievements: Array[String] = []
var best_scores: Dictionary = {} ## Route id to best score.
var last_daily: String = "" ## Date key of the last daily challenge completed.
var intro_done: bool = false ## The opening scene and tutorial have been seen.
var settings: Dictionary = {}


func owns(kind: String, id: String) -> bool:
	return (owned[kind] as Array).has(id)


func buy(kind: String, item: Dictionary) -> bool:
	var id: String = item["id"]
	var cost: int = item["cost"]
	if owns(kind, id) or coins < cost or DriverLevel.level_for(xp) < int(item.get("level", 1)):
		return false
	coins -= cost
	(owned[kind] as Array).append(id)
	return true


func select(kind: String, id: String) -> bool:
	if not owns(kind, id):
		return false
	selected[kind] = id
	return true


## Anything the catalog gives away is owned from the start.
func grant_free_items(catalog: Catalog) -> void:
	for kind: String in owned:
		for item: Dictionary in catalog.items(kind):
			if int(item["cost"]) == 0 and not owns(kind, item["id"]):
				(owned[kind] as Array).append(item["id"])


func record_best(route_id: String, score: int) -> bool:
	if score <= int(best_scores.get(route_id, -1)):
		return false
	best_scores[route_id] = score
	return true


func to_dict() -> Dictionary:
	return {
		"version": VERSION, "coins": coins, "xp": xp, "owned": owned, "selected": selected,
		"stats": stats, "achievements": achievements, "best_scores": best_scores,
		"last_daily": last_daily, "settings": settings, "intro_done": intro_done,
	}


static func from_dict(saved: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.coins = maxi(int(_number(saved.get("coins"), 0.0)), 0)
	profile.xp = maxi(int(_number(saved.get("xp"), 0.0)), 0)
	var saved_owned: Variant = saved.get("owned")
	if saved_owned is Dictionary:
		for kind: String in profile.owned:
			var list: Variant = (saved_owned as Dictionary).get(kind)
			if list is Array:
				for id: Variant in list:
					if id is String and not (profile.owned[kind] as Array).has(id):
						(profile.owned[kind] as Array).append(id)
	var saved_selected: Variant = saved.get("selected")
	if saved_selected is Dictionary:
		for kind: String in profile.selected:
			var id: Variant = (saved_selected as Dictionary).get(kind)
			if id is String:
				profile.select(kind, id)
	var saved_stats: Variant = saved.get("stats")
	if saved_stats is Dictionary:
		for key: String in profile.stats:
			profile.stats[key] = maxi(int(_number((saved_stats as Dictionary).get(key), 0.0)), 0)
	var saved_achievements: Variant = saved.get("achievements")
	if saved_achievements is Array:
		for id: Variant in saved_achievements:
			if id is String:
				profile.achievements.append(id)
	var saved_best: Variant = saved.get("best_scores")
	if saved_best is Dictionary:
		for key: Variant in saved_best:
			profile.best_scores[str(key)] = int(_number((saved_best as Dictionary)[key], 0.0))
	var daily: Variant = saved.get("last_daily")
	profile.last_daily = daily if daily is String else ""
	profile.intro_done = saved.get("intro_done") == true
	var saved_settings: Variant = saved.get("settings")
	profile.settings = saved_settings if saved_settings is Dictionary else {}
	return profile


static func _number(value: Variant, fallback: float) -> float:
	return float(value) if value is float or value is int else fallback
