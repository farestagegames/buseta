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


## Tests use this to keep away from the real save.
func load_from(path: String) -> void:
	_path = path
	data = PlayerProfile.from_dict(SaveStore.read(path))
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


func select(kind: String, id: String) -> bool:
	if not data.select(kind, id):
		return false
	save()
	return true


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


func _apply_settings() -> void:
	var saved := data.settings
	GameSettings.apply_saved(saved)


func _on_settings_changed() -> void:
	data.settings = GameSettings.to_dict()
	save()
