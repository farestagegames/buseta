class_name DailyChallenge
extends RefCounted
## The same challenge for everyone on a given date, chosen from a data file.

const REWARD_COINS := 200


static func load_list() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Country.pack.content_path("daily_challenges")))
	return parsed if parsed is Array else []


## date_key is a YYYY-MM-DD string.
static func for_date(date_key: String, challenges: Array) -> Dictionary:
	var parts := date_key.split("-")
	var day_number := int(parts[0]) * 372 + int(parts[1]) * 31 + int(parts[2])
	return challenges[day_number % challenges.size()]


static func today_key() -> String:
	return Time.get_date_string_from_system()


static func is_passed(challenge: Dictionary, report: Dictionary) -> bool:
	if challenge.has("min_stars"):
		return int(report["stars"]) >= int(challenge["min_stars"])
	var counts: Dictionary = report["counts"]
	return int(counts.get(challenge["counter"], 0)) <= int(challenge["max"])
