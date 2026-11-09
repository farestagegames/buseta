extends Node
## Holds the player's saved progress and keeps it on disk. Saves after every
## change and whenever the app is sent to the background, so swiping away or a
## phone call never loses anything.

const SAVE_PATH := "user://save.json"

var data := PlayerProfile.new()
var catalog := Catalog.new()
var ads := AdProvider.new()

var _path: String = SAVE_PATH


func _ready() -> void:
	load_from(_path)
	GameSettings.changed.connect(_on_settings_changed)
	GameSettings.radio_station_changed.connect(_on_radio_station_changed)
	Country.pack_changed.connect(_on_pack_changed)


## Tests use this to keep away from the real save.
func load_from(path: String) -> void:
	_path = path
	data = PlayerProfile.from_dict(SaveStore.read(path))
	data.grant_free_items(catalog)
	data.repair_choices(catalog)
	data.settle_horns(Country.pack.horns())
	_apply_settings()


func save() -> bool:
	return SaveStore.write(_path, data.to_dict())


func selected_item(kind: String) -> Dictionary:
	var item := catalog.find(kind, data.selected[kind])
	return item if not item.is_empty() else catalog.items(kind)[0]


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
	if not data.select(kind, id):
		return false
	save()
	return true


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
