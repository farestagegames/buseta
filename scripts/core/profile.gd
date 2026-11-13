extends Node
## Holds the player's saved progress and keeps it on disk. Saves after every
## change and whenever the app is sent to the background, so swiping away or a
## phone call never loses anything.

const SAVE_PATH := "user://save.json"

var data := PlayerProfile.new()
var catalog := Catalog.new()
var ads := AdProvider.new()

var _path: String = SAVE_PATH
## A route this run plays instead of the chosen one (the arcade), or "".
var route_override: String = ""


func _ready() -> void:
	load_from(_path)
	GameSettings.changed.connect(_on_settings_changed)
	GameSettings.radio_station_changed.connect(_on_radio_station_changed)
	Country.pack_changed.connect(_on_pack_changed)


## Tests use this to keep away from the real save.
func load_from(path: String) -> void:
	_path = path
	catalog = Catalog.new()
	var saved := SaveStore.read(path)
	data = PlayerProfile.from_dict(saved)
	# A fresh save follows the country's default route, not the class default.
	if saved.is_empty():
		var route := catalog.default_route()
		if route != "":
			data.selected[Catalog.ROUTES] = route
			if not data.owns(Catalog.ROUTES, route):
				(data.owned[Catalog.ROUTES] as Array).append(route)
	data.grant_free_items(catalog)
	_grant_completed_unlocks()
	data.repair_choices(catalog)
	data.settle_horns(Country.pack.horns())
	_apply_settings()


## Routes unlocked by routes finished in earlier versions of the save.
func _grant_completed_unlocks() -> void:
	var changed := true
	while changed:
		changed = false
		for route_id: String in data.completed_routes:
			for item: Dictionary in catalog.unlocked_by(route_id, data):
				(data.owned[Catalog.ROUTES] as Array).append(item["id"])
				changed = true


## The next item the player can work towards: cheapest reachable, with what's missing.
## Exposed for the results screen (task 6).
func next_unlock() -> Dictionary:
	return UnlockProgress.next(data, catalog, Country.pack)


func save() -> bool:
	return SaveStore.write(_path, data.to_dict())


## The route the next shift drives: the arcade when its Home button started it,
## otherwise the chosen route. Not saved; the menu clears it.
func shift_route() -> Dictionary:
	if route_override != "":
		var item := catalog.find(Catalog.ROUTES, route_override)
		if not item.is_empty():
			return item
	return selected_item(Catalog.ROUTES)


func selected_item(kind: String) -> Dictionary:
	var item := catalog.find(kind, data.selected.get(kind, ""))
	if not item.is_empty():
		return item
	var items := catalog.items(kind)
	return items[0] if not items.is_empty() else {}


func buy(kind: String, id: String) -> bool:
	var item := catalog.find(kind, id)
	if item.is_empty() or not data.buy(kind, item):
		return false
	save()
	return true


func buy_horn(horn_id: String) -> bool:
	var item := Country.pack.horn(horn_id)
	if item.get("id") != horn_id or not data.buy_horn(item):
		return false
	save()
	return true


func choose_horn(horn_id: String) -> bool:
	if not data.choose_horn(horn_id):
		return false
	save()
	return true


## The horn the player hears on this bus: their chosen one, or the bus's own.
func horn_for(bus_item: Dictionary) -> Dictionary:
	return Country.pack.horn(data.horn_for(str(Country.pack.bus_horn(bus_item).get("id", ""))))


func select(kind: String, id: String) -> bool:
	if kind == Catalog.ROUTES and not data.can_play_route(id, catalog):
		return false
	if not data.select(kind, id):
		return false
	if kind == Catalog.ROUTES:
		var item := catalog.find(Catalog.ROUTES, id)
		var t := town_for_route(item)
		if t != "":
			data.town = t
	save()
	return true


## The town currently chosen on the Routes tab. Defaults to the town of the selected route.
func chosen_town() -> String:
	var available := catalog_towns()
	if data.town != "" and (available.is_empty() or available.has(data.town)):
		return data.town
	var default_town := town_for_route(selected_item(Catalog.ROUTES))
	if default_town != "" and (available.is_empty() or available.has(default_town)):
		return default_town
	return available[0] if not available.is_empty() else ""


func choose_town(town_name: String) -> void:
	data.town = town_name
	save()


func catalog_towns() -> Array[String]:
	var routes := catalog.items(Catalog.ROUTES)
	var towns := MainMenu.route_towns(routes)
	var list: Array[String] = []
	for item: Dictionary in routes:
		var town_name: String = towns.get(item.get("id", ""), "")
		if town_name != "" and not list.has(town_name):
			list.append(town_name)
	return list


func town_for_route(route_item: Dictionary) -> String:
	if not route_item.has("file"):
		return ""
	var route_data := MapLoader.read_json(route_item["file"])
	var map_path := str(route_data.get("map", ""))
	if map_path == "":
		return ""
	return str(MapLoader.read_json(Country.pack.resolve(map_path)).get("name", ""))


func town_lock_level(town_name: String) -> int:
	var routes := catalog.items(Catalog.ROUTES)
	var towns_map := MainMenu.route_towns(routes)
	var min_level := 999999
	var found := false
	for item: Dictionary in routes:
		if towns_map.get(item["id"], "") == town_name:
			found = true
			min_level = mini(min_level, int(item.get("level", 1)))
	return min_level if found and min_level != 999999 else 1


func is_town_locked(town_name: String) -> bool:
	return town_lock_level(town_name) > DriverLevel.level_for(data.xp)


func difficulties() -> Array[Difficulty]:
	return Difficulty.list_for(Country.pack.data)


func chosen_difficulty() -> Difficulty:
	return Difficulty.pick(difficulties(), data.difficulty, str(Country.pack.data.get("default_difficulty", "")))


func choose_difficulty(difficulty: Difficulty) -> void:
	data.difficulty = difficulty.id
	save()


func choose_time(time: TimeOfDay) -> bool:
	if not data.choose_time(time):
		return false
	save()
	return true


## Every time of day this country offers, and the one the next shift runs at.
func times_of_day() -> Array[TimeOfDay]:
	var times := TimeOfDay.list_for(Country.pack.data)
	if times.size() == 1 and times[0].id == TimeOfDay.FALLBACK_ID:
		# No list in the pack: the day comes from the map's own theme.
		var route := MapLoader.read_json(selected_item(Catalog.ROUTES)["file"])
		times = TimeOfDay.list_for(Country.pack.data, CityTheme.from_data(MapLoader.read_map_of(route)))
	return times


func chosen_time() -> TimeOfDay:
	return TimeOfDay.pick(times_of_day(), data.time_of_day, DriverLevel.level_for(data.xp))


## The next shift plays the opening scene and tutorial again.
func reset_tutorial() -> void:
	data.intro_done = false
	var route := catalog.default_route()
	if route != "":
		data.select(Catalog.ROUTES, route)
	save()


func finish_tutorial() -> void:
	data.intro_done = true
	save()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT:
			save()


func _on_pack_changed() -> void:
	catalog = Catalog.new()
	_grant_completed_unlocks()
	data.repair_choices(catalog)
	data.settle_horns(Country.pack.horns())


func _apply_settings() -> void:
	var saved := data.settings
	GameSettings.apply_saved(saved)


func _on_settings_changed() -> void:
	data.settings = GameSettings.to_dict()
	save()


## Kept in memory only: the next save (end of shift, quitting, or the app going to
## the background) writes it, so tuning the radio never waits on the disk.
func _on_radio_station_changed() -> void:
	data.settings = GameSettings.to_dict()
