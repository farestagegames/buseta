class_name FirstsList
extends RefCounted
## One-off first-time celebrations, kept in data. Each shows once, gives a small
## coin reward and may unlock an achievement at the same time.


static func load_list() -> Array:
	var content: Variant = Country.pack.data.get("content", {})
	if not content is Dictionary or not (content as Dictionary).has("firsts"):
		return []
	var path: String = Country.pack.content_path("firsts")
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []


static func find(list: Array, id: String) -> Dictionary:
	for value: Variant in list:
		if value is Dictionary and (value as Dictionary).get("id", "") == id:
			return value
	return {}


static func reward_of(entry: Dictionary) -> int:
	return maxi(int(entry.get("reward", 0)), 0)


static func achievement_id(entry: Dictionary) -> String:
	return str(entry.get("achievement", ""))


## Marks and returns a first if it has not happened yet. Does not touch coins or
## achievements; callers handle rewards and banners.
static func mark(profile: PlayerProfile, id: String) -> bool:
	if profile.firsts.has(id):
		return false
	profile.firsts.append(id)
	return true
