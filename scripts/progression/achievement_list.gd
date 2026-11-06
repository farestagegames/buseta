class_name AchievementList
extends RefCounted
## Achievements are data: a stat and a target. Earning one needs no code.

const PATH := "res://data/achievements.json"


static func load_list() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Array else []


## Marks and returns anything newly earned.
static func award_new(profile: PlayerProfile, list: Array) -> Array[Dictionary]:
	var earned: Array[Dictionary] = []
	for entry: Dictionary in list:
		var id: String = entry["id"]
		if profile.achievements.has(id):
			continue
		if int(profile.stats.get(entry["stat"], 0)) >= int(entry["target"]):
			profile.achievements.append(id)
			earned.append(entry)
	return earned
