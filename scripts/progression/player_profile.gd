class_name PlayerProfile
extends RefCounted
## All saved player progress as plain data, with the rules for spending it.
## Pure logic. Loading tolerates missing or damaged fields, so an old or hand
## edited save can never stop the game from starting.

const VERSION := 3
const DEFAULT_ROUTE := "starter_a"
const DEFAULT_BUS := "buseta_8"
const DEFAULT_LIVERY := "rojo_caribe"
const DEFAULT_DRIVER := "wilmer_pertuz"
const DEFAULT_DECORATION := "seat_sky"
const DEFAULTS := {
	Catalog.ROUTES: DEFAULT_ROUTE, Catalog.BUSES: DEFAULT_BUS, Catalog.LIVERIES: DEFAULT_LIVERY,
	Catalog.DRIVERS: DEFAULT_DRIVER, Catalog.DECORATIONS: DEFAULT_DECORATION,
}

var coins: int = 0
var xp: int = 0
var owned: Dictionary = {
	Catalog.ROUTES: [DEFAULT_ROUTE], Catalog.BUSES: [DEFAULT_BUS], Catalog.LIVERIES: [DEFAULT_LIVERY],
	Catalog.DRIVERS: [DEFAULT_DRIVER], Catalog.DECORATIONS: [DEFAULT_DECORATION],
}
var selected: Dictionary = DEFAULTS.duplicate()
var stats: Dictionary = {
	"shifts": 0, "passengers": 0, "best_stars": 0, "clean_shifts": 0, "smooth_shifts": 0,
	"rain_shifts": 0, "clean_downpours": 0, "night_shifts": 0,
	"vendors": 0, "fares": 0, "dailies": 0, "best_daily_streak": 0, "routes_driven": 0,
}
var achievements: Array[String] = []
var best_scores: Dictionary = {} ## Route id to best score.
var best_stars: Dictionary = {} ## Route id to best stars (0-3).
var completed_routes: Array[String] = [] ## Routes finished properly at least once.
var last_daily: String = "" ## Date key of the last daily challenge completed.
## Daily challenges completed on days in a row, ending on last_daily.
var daily_streak: int = 0
var intro_done: bool = false ## The opening scene and tutorial have been seen.
## The title screen has sent a brand-new player straight into the tutorial shift.
var first_launch_done: bool = false
var settings: Dictionary = {}
## Horns bought or given free. Horns are pack data, not catalog items.
var horns_owned: Array[String] = []
## The horn fitted to every bus, or "" for each bus's own horn.
var horn: String = ""
## The time of day picked for the next shift, by its pack id, or "" for the default.
var time_of_day: String = ""
## The difficulty picked for the next shift, by its pack id, or "" for the default.
var difficulty: String = ""
## First-time celebrations already shown and rewarded (stable snake_case ids).
var firsts: Array[String] = []
## The town (district) picked on the Routes tab, or "" to follow the selected route.
var town: String = ""



func owns(kind: String, id: String) -> bool:
	return (owned[kind] as Array).has(id)


func buy(kind: String, item: Dictionary) -> bool:
	var id: String = item["id"]
	var cost: int = item["cost"]
	if owns(kind, id) or coins < cost or DriverLevel.level_for(xp) < int(item.get("level", 1)):
		return false
	if kind == Catalog.ROUTES and str(item.get("requires", "")) != "" and not has_completed_route(str(item["requires"])):
		return false
	coins -= cost
	(owned[kind] as Array).append(id)
	return true


func select(kind: String, id: String) -> bool:
	if not owns(kind, id):
		return false
	selected[kind] = id
	return true


## Anything the catalog gives away is owned from the start. Routes that need
## another route finished first are unlocked when that route is completed.
func grant_free_items(catalog: Catalog) -> void:
	for kind: String in owned:
		for item: Dictionary in catalog.items(kind):
			if int(item.get("cost", 0)) == 0 and catalog.requires(item) == "" and not owns(kind, item["id"]):
				(owned[kind] as Array).append(item["id"])


## A choice the catalog no longer has, such as a driver from an older version of the
## game, goes back to the default, or to the first item owned if there is none.
func repair_choices(catalog: Catalog) -> void:
	for kind: String in selected:
		if catalog.items(kind).is_empty():
			continue
		if not catalog.find(kind, selected[kind]).is_empty():
			continue
		var fallback: String = DEFAULTS.get(kind, "")
		if kind == Catalog.ROUTES:
			fallback = catalog.default_route()
		if catalog.find(kind, fallback).is_empty() or not owns(kind, fallback):
			var owned_items := catalog.items(kind).filter(func(item: Dictionary) -> bool: return owns(kind, item["id"]))
			fallback = owned_items[0]["id"] if not owned_items.is_empty() else ""
		if fallback != "":
			selected[kind] = fallback
	# A selected route the player cannot use yet falls back to one they can. The
	# arcade is never the chosen route: it has its own Home button.
	var chosen_route: String = selected.get(Catalog.ROUTES, "")
	if not can_play_route(chosen_route, catalog) or catalog.arcade_route().get("id", "") == chosen_route:
		var route := catalog.default_route()
		if not can_play_route(route, catalog):
			for item: Dictionary in catalog.items(Catalog.ROUTES):
				if can_play_route(item["id"], catalog) and item != catalog.arcade_route():
					route = item["id"]
					break
		if route != "":
			selected[Catalog.ROUTES] = route



func owns_horn(horn_id: String) -> bool:
	return horns_owned.has(horn_id)


func buy_horn(item: Dictionary) -> bool:
	var id: String = item["id"]
	var cost := int(item.get("cost", 0))
	if owns_horn(id) or coins < cost or DriverLevel.level_for(xp) < int(item.get("level", 1)):
		return false
	coins -= cost
	horns_owned.append(id)
	return true


## "" goes back to each bus's own horn.
func choose_horn(horn_id: String) -> bool:
	if horn_id != "" and not owns_horn(horn_id):
		return false
	horn = horn_id
	return true


## The pack's free horns are owned from the start, and a choice the pack no longer
## has goes back to the bus's own horn.
func settle_horns(pack_horns: Array) -> void:
	var ids: Array[String] = []
	for item: Dictionary in pack_horns:
		ids.append(item["id"])
		if int(item.get("cost", 0)) == 0 and int(item.get("level", 1)) <= 1 and not owns_horn(item["id"]):
			horns_owned.append(item["id"])
	if not ids.has(horn):
		horn = ""


## The horn to play on a bus whose own horn is bus_horn_id.
func horn_for(bus_horn_id: String) -> String:
	return horn if horn != "" and owns_horn(horn) else bus_horn_id


## Picks the time of day for the next shift. Refused until the driver's level
## unlocks it.
func choose_time(time: TimeOfDay) -> bool:
	if not time.is_unlocked(DriverLevel.level_for(xp)):
		return false
	time_of_day = time.id
	return true


func has_completed_route(route_id: String) -> bool:
	return completed_routes.has(route_id)


## A route the player owns and can start now.
## The arcade opens at its driver level; before that its Home button shows the level.
func arcade_unlocked(catalog: Catalog) -> bool:
	var item := catalog.arcade_route()
	return not item.is_empty() and DriverLevel.level_for(xp) >= int(item.get("level", 1))


## The arcade has been raced at least once, so its "New!" badge can go.
func arcade_tried(catalog: Catalog) -> bool:
	var item := catalog.arcade_route()
	return not item.is_empty() and best_scores.has(item["id"])


## A free route above the driver's level (such as a second map's first route) is
## owned from the start but cannot be driven until that level.
func can_play_route(route_id: String, catalog: Catalog) -> bool:
	if not owns(Catalog.ROUTES, route_id):
		return false
	var item := catalog.find(Catalog.ROUTES, route_id)
	return item != {} and DriverLevel.level_for(xp) >= int(item.get("level", 1))


## Marks a route as finished and grants any routes it unlocks.
func complete_route(route_id: String, catalog: Catalog) -> Array[Dictionary]:
	if not has_completed_route(route_id):
		completed_routes.append(route_id)
	var unlocked: Array[Dictionary] = []
	for item: Dictionary in catalog.unlocked_by(route_id, self):
		(owned[Catalog.ROUTES] as Array).append(item["id"])
		unlocked.append(item)
	return unlocked


func record_best(route_id: String, score: int) -> bool:
	if score <= int(best_scores.get(route_id, -1)):
		return false
	best_scores[route_id] = score
	return true


func record_best_stars(route_id: String, stars: int) -> bool:
	var value := clampi(stars, 0, 3)
	if value <= int(best_stars.get(route_id, -1)):
		return false
	best_stars[route_id] = value
	stats["best_stars"] = _max_best_stars()
	return true


func _max_best_stars() -> int:
	var best := 0
	for value: Variant in best_stars.values():
		best = maxi(best, int(value))
	return maxi(best, int(stats.get("best_stars", 0)))


func to_dict() -> Dictionary:
	return {
		"version": VERSION, "coins": coins, "xp": xp, "owned": owned, "selected": selected,
		"stats": stats, "achievements": achievements, "best_scores": best_scores, "best_stars": best_stars,
		"completed_routes": completed_routes,
		"last_daily": last_daily, "daily_streak": daily_streak, "settings": settings, "intro_done": intro_done,
		"first_launch_done": first_launch_done,
		"horns_owned": horns_owned, "horn": horn, "time_of_day": time_of_day, "difficulty": difficulty,
		"firsts": firsts, "town": town,
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
			if id is String and profile.owns(kind, id):
				profile.selected[kind] = id
	# Older saves or packs without this kind may not have a valid decoration yet.
	if not saved.has("version") or int(_number(saved.get("version"), 0.0)) < 3:
		if profile.selected.get(Catalog.DECORATIONS, "") == "":
			profile.selected[Catalog.DECORATIONS] = DEFAULT_DECORATION
		if not profile.owns(Catalog.DECORATIONS, profile.selected[Catalog.DECORATIONS]):
			(profile.owned[Catalog.DECORATIONS] as Array).append(profile.selected[Catalog.DECORATIONS])
	var saved_stats: Variant = saved.get("stats")
	if saved_stats is Dictionary:
		for key: String in profile.stats:
			profile.stats[key] = maxi(int(_number((saved_stats as Dictionary).get(key), 0.0)), 0)
		# Per-route and per-bus shift counts have open-ended names.
		for key: Variant in saved_stats:
			if key is String and ((key as String).begins_with(AchievementList.ROUTE_PREFIX) or (key as String).begins_with(AchievementList.BUS_PREFIX)):
				profile.stats[key] = maxi(int(_number((saved_stats as Dictionary)[key], 0.0)), 0)
	var saved_achievements: Variant = saved.get("achievements")
	if saved_achievements is Array:
		for id: Variant in saved_achievements:
			if id is String:
				profile.achievements.append(id)
	var saved_best: Variant = saved.get("best_scores")
	if saved_best is Dictionary:
		for key: Variant in saved_best:
			profile.best_scores[str(key)] = int(_number((saved_best as Dictionary)[key], 0.0))
	var saved_route_stars: Variant = saved.get("best_stars")
	if saved_route_stars is Dictionary:
		for key: Variant in saved_route_stars:
			profile.best_stars[str(key)] = clampi(int(_number((saved_route_stars as Dictionary)[key], 0.0)), 0, 3)
	var saved_completed: Variant = saved.get("completed_routes")
	if saved_completed is Array:
		for route_id: Variant in saved_completed:
			if route_id is String and not profile.completed_routes.has(route_id):
				profile.completed_routes.append(route_id)
	var daily: Variant = saved.get("last_daily")
	profile.last_daily = daily if daily is String else ""
	profile.daily_streak = maxi(int(_number(saved.get("daily_streak"), 0.0)), 0)
	profile.intro_done = saved.get("intro_done") == true
	profile.first_launch_done = saved.get("first_launch_done") == true
	var saved_settings: Variant = saved.get("settings")
	profile.settings = saved_settings if saved_settings is Dictionary else {}
	# Saves from before horns could be chosen have neither field: every bus keeps
	# its own horn.
	var saved_horns: Variant = saved.get("horns_owned")
	if saved_horns is Array:
		for id: Variant in saved_horns:
			if id is String and not profile.horns_owned.has(id):
				profile.horns_owned.append(id)
	var saved_horn: Variant = saved.get("horn")
	if saved_horn is String:
		profile.choose_horn(saved_horn)
	# Checked against the pack when a shift starts, so an unknown id is harmless.
	var saved_time: Variant = saved.get("time_of_day")
	profile.time_of_day = saved_time if saved_time is String else ""
	var saved_difficulty: Variant = saved.get("difficulty")
	profile.difficulty = saved_difficulty if saved_difficulty is String else ""
	var saved_firsts: Variant = saved.get("firsts")
	if saved_firsts is Array:
		for id: Variant in saved_firsts:
			if id is String and not profile.firsts.has(id):
				profile.firsts.append(id)
	var saved_town: Variant = saved.get("town")
	profile.town = saved_town if saved_town is String else ""
	var saved_version := int(_number(saved.get("version"), 0.0))
	if saved_version < 2:
		profile.stats["best_stars"] = RouteGoals.migrate_best_stars(int(profile.stats.get("best_stars", 0)))
		for key: Variant in profile.best_stars.keys():
			profile.best_stars[key] = RouteGoals.migrate_best_stars(int(profile.best_stars[key]))
	profile.stats["best_stars"] = maxi(int(profile.stats.get("best_stars", 0)), profile._max_best_stars())
	return profile


static func _number(value: Variant, fallback: float) -> float:
	return float(value) if value is float or value is int else fallback
