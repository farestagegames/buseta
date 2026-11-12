class_name AchievementList
extends RefCounted
## Achievements are data: a stat, a target and an optional coin reward. Earning
## one needs no code.
##
## Besides the fixed stats in PlayerProfile, a stat can be "route:<id>" or
## "bus:<id>": shifts driven on that route or in that bus.

const ROUTE_PREFIX := "route:"
const BUS_PREFIX := "bus:"


static func load_list() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Country.pack.content_path("achievements")))
	return parsed if parsed is Array else []


## Marks and returns anything newly earned.
static func award_new(profile: PlayerProfile, list: Array) -> Array[Dictionary]:
	var earned: Array[Dictionary] = []
	for entry: Dictionary in list:
		var id: String = entry["id"]
		if profile.achievements.has(id):
			continue
		if progress(profile, entry) >= int(entry["target"]):
			profile.achievements.append(id)
			earned.append(entry)
	return earned


static func progress(profile: PlayerProfile, entry: Dictionary) -> int:
	return int(profile.stats.get(entry["stat"], 0))


static func reward_of(entry: Dictionary) -> int:
	return maxi(int(entry.get("reward", 0)), 0)


## The route this achievement is about, or "".
static func route_of(entry: Dictionary) -> String:
	var stat := str(entry.get("stat", ""))
	return stat.trim_prefix(ROUTE_PREFIX) if stat.begins_with(ROUTE_PREFIX) else ""


## True for a fixed stat, or a route or bus stat naming a real id.
static func is_known_stat(stat: String, route_ids: Array, bus_ids: Array) -> bool:
	if PlayerProfile.new().stats.has(stat):
		return true
	if stat.begins_with(ROUTE_PREFIX):
		return route_ids.has(stat.trim_prefix(ROUTE_PREFIX))
	if stat.begins_with(BUS_PREFIX):
		return bus_ids.has(stat.trim_prefix(BUS_PREFIX))
	return false


## Problems with an achievement list, for pack validation.
static func check(list: Variant, route_ids: Array, bus_ids: Array) -> Array[String]:
	var problems: Array[String] = []
	if not list is Array or (list as Array).is_empty():
		problems.append("achievements must be a non-empty list")
		return problems
	var seen := {}
	for value: Variant in list:
		if not value is Dictionary:
			problems.append("An achievement is not an object")
			continue
		var entry: Dictionary = value
		var id := str(entry.get("id", ""))
		if id == "" or seen.has(id):
			problems.append("Achievement id missing or repeated: '%s'" % id)
		seen[id] = true
		for key: String in ["name", "description"]:
			if str(entry.get(key, "")) == "":
				problems.append("Achievement %s has no %s" % [id, key])
		if not is_known_stat(str(entry.get("stat", "")), route_ids, bus_ids):
			problems.append("Achievement %s counts an unknown stat %s" % [id, entry.get("stat", "")])
		if not (entry.get("target") is float or entry.get("target") is int) or int(entry["target"]) < 1:
			problems.append("Achievement %s needs a target of 1 or more" % id)
		if entry.has("reward") and not (entry["reward"] is float or entry["reward"] is int):
			problems.append("Achievement %s has a reward that is not a number" % id)
	return problems
