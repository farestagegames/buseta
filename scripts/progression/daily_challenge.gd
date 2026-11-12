class_name DailyChallenge
extends RefCounted
## One challenge a day, chosen from a data file. Everyone at the same level who
## owns the same things gets the same one on a given date.
##
## A challenge is a set of conditions, all of which must hold:
##   "min_stars": n            at least n stars
##   "counter": key, "max": n  a report count (or top-level number) at most n
##   "counter": key, "min": n  ... or at least n
##   "route": id, "bus": id    only on that route or in that bus
##   "time": id                only at that time of day
##   "level": n                only offered from that driver level
## A challenge that needs a route or bus is only offered once the player owns it.

const REWARD_COINS := 200
## Each day in a row adds this much, up to MAX_STREAK_DAYS days.
const STREAK_BONUS := 50
const MAX_STREAK_DAYS := 5
const CONDITION_KEYS: Array[String] = ["min_stars", "counter", "route", "bus", "time"]


static func load_list() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Country.pack.content_path("daily_challenges")))
	return parsed if parsed is Array else []


## date_key is a YYYY-MM-DD string. With a profile, only challenges it can do are
## offered.
static func for_date(date_key: String, challenges: Array, profile: PlayerProfile = null) -> Dictionary:
	var offered := challenges
	if profile != null:
		offered = challenges.filter(func(challenge: Dictionary) -> bool: return is_available(challenge, profile))
		if offered.is_empty():
			# Fall back to challenges with no route or bus requirement the player lacks.
			offered = challenges.filter(func(challenge: Dictionary) -> bool:
				return (not challenge.has("route") or profile.owns(Catalog.ROUTES, challenge["route"])) \
					and (not challenge.has("bus") or profile.owns(Catalog.BUSES, challenge["bus"])))
		if offered.is_empty():
			offered = challenges
	if offered.is_empty():
		return {}
	var parts := date_key.split("-")
	var day_number := int(parts[0]) * 372 + int(parts[1]) * 31 + int(parts[2])
	return offered[day_number % offered.size()]


static func is_available(challenge: Dictionary, profile: PlayerProfile) -> bool:
	if DriverLevel.level_for(profile.xp) < int(challenge.get("level", 1)):
		return false
	if challenge.has("route") and not profile.owns(Catalog.ROUTES, challenge["route"]):
		return false
	if challenge.has("bus") and not profile.owns(Catalog.BUSES, challenge["bus"]):
		return false
	return true


static func today_key() -> String:
	return Time.get_date_string_from_system()


## The day before date_key, as YYYY-MM-DD.
static func day_before(date_key: String) -> String:
	var seconds := Time.get_unix_time_from_datetime_string(date_key + "T12:00:00")
	return Time.get_datetime_string_from_unix_time(seconds - 86400).substr(0, 10)


## Coins for completing a challenge on the given day of a streak (1 = first day).
static func reward_for(streak: int) -> int:
	return REWARD_COINS + STREAK_BONUS * (clampi(streak, 1, MAX_STREAK_DAYS) - 1)


## context holds "route" and "bus": the ids actually driven.
static func is_passed(challenge: Dictionary, report: Dictionary, context: Dictionary = {}) -> bool:
	if challenge.is_empty():
		return false
	if challenge.has("route") and str(context.get("route", "")) != str(challenge["route"]):
		return false
	if challenge.has("bus") and str(context.get("bus", "")) != str(challenge["bus"]):
		return false
	if challenge.has("time") and str(report.get("time_of_day", "")) != str(challenge["time"]):
		return false
	if challenge.has("min_stars") and int(report["stars"]) < int(challenge["min_stars"]):
		return false
	if challenge.has("counter"):
		var value := count_of(report, challenge["counter"])
		if challenge.has("max") and value > int(challenge["max"]):
			return false
		if challenge.has("min") and value < int(challenge["min"]):
			return false
	return true


## A count from the report: the fault counts first, then top-level numbers such
## as "carried" and "fares".
static func count_of(report: Dictionary, key: String) -> int:
	var counts: Dictionary = report.get("counts", {})
	if counts.has(key):
		return int(counts[key])
	return int(report.get(key, 0))


## Problems with a challenge list, for pack validation.
static func check(challenges: Variant, route_ids: Array, bus_ids: Array, time_ids: Array) -> Array[String]:
	var problems: Array[String] = []
	if not challenges is Array or (challenges as Array).is_empty():
		problems.append("daily_challenges must be a non-empty list")
		return problems
	var seen := {}
	for entry: Variant in challenges:
		if not entry is Dictionary:
			problems.append("A daily challenge is not an object")
			continue
		var challenge: Dictionary = entry
		var id := str(challenge.get("id", ""))
		if id == "" or seen.has(id):
			problems.append("Daily challenge id missing or repeated: '%s'" % id)
		seen[id] = true
		if str(challenge.get("text", "")) == "":
			problems.append("Daily challenge %s has no text" % id)
		if not CONDITION_KEYS.any(func(key: String) -> bool: return challenge.has(key)):
			problems.append("Daily challenge %s has no condition" % id)
		if challenge.has("counter") and not (challenge.has("max") or challenge.has("min")):
			problems.append("Daily challenge %s has a counter but no max or min" % id)
		if challenge.has("route") and not route_ids.has(challenge["route"]):
			problems.append("Daily challenge %s names an unknown route" % id)
		if challenge.has("bus") and not bus_ids.has(challenge["bus"]):
			problems.append("Daily challenge %s names an unknown bus" % id)
		if challenge.has("time") and not time_ids.is_empty() and not time_ids.has(challenge["time"]):
			problems.append("Daily challenge %s names an unknown time of day" % id)
	return problems
