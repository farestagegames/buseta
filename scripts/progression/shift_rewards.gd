class_name ShiftRewards
extends RefCounted
## Turns a finished shift's report into coins, XP, stats and awards. Pure logic:
## it changes the profile it is given and returns what happened.


## bus_id is the bus actually driven, which a route can force.
static func apply(profile: PlayerProfile, report: Dictionary, route_id: String, date_key: String, challenges: Array, achievements: Array, bus_id: String = "") -> Dictionary:
	var level_before := DriverLevel.level_for(profile.xp)
	var coins: int = report["coins"]
	var xp := DriverLevel.xp_from_shift(report["score"], report["stars"])
	var counts: Dictionary = report["counts"]
	var stats := profile.stats
	stats["shifts"] = int(stats["shifts"]) + 1
	stats["passengers"] = int(stats["passengers"]) + int(report["carried"])
	stats["best_stars"] = maxi(int(stats["best_stars"]), int(report["stars"]))
	if int(counts["collisions"]) == 0:
		stats["clean_shifts"] = int(stats["clean_shifts"]) + 1
	if int(counts["harsh_brakes"]) == 0:
		stats["smooth_shifts"] = int(stats["smooth_shifts"]) + 1
	if int(counts.get("downpours", 0)) > 0:
		stats["rain_shifts"] = int(stats.get("rain_shifts", 0)) + 1
	stats["clean_downpours"] = int(stats.get("clean_downpours", 0)) + int(counts.get("clean_downpours", 0))
	# A time of day can count its shifts, such as night shifts for an achievement.
	var time_stat: String = str(report.get("time_stat", ""))
	if time_stat != "":
		stats[time_stat] = int(stats.get(time_stat, 0)) + 1
	stats["vendors"] = int(stats.get("vendors", 0)) + int(counts.get("vendors", 0))
	stats["fares"] = int(stats.get("fares", 0)) + int(report.get("fares", 0))
	var route_stat := AchievementList.ROUTE_PREFIX + route_id
	stats[route_stat] = int(stats.get(route_stat, 0)) + 1
	if bus_id != "":
		var bus_stat := AchievementList.BUS_PREFIX + bus_id
		stats[bus_stat] = int(stats.get(bus_stat, 0)) + 1

	# The challenge is picked before this shift's XP, so a level-up mid-shift
	# cannot swap it for another.
	var daily_coins := 0
	var daily: Dictionary = DailyChallenge.for_date(date_key, challenges, profile)
	var context := {"route": route_id, "bus": bus_id}
	if profile.last_daily != date_key and DailyChallenge.is_passed(daily, report, context):
		var on_a_run := profile.last_daily == DailyChallenge.day_before(date_key)
		profile.daily_streak = profile.daily_streak + 1 if on_a_run else 1
		profile.last_daily = date_key
		daily_coins = DailyChallenge.reward_for(profile.daily_streak)
		stats["dailies"] = int(stats.get("dailies", 0)) + 1
		stats["best_daily_streak"] = maxi(int(stats.get("best_daily_streak", 0)), profile.daily_streak)

	profile.xp += xp
	var new_best := profile.record_best(route_id, report["score"])
	stats["routes_driven"] = profile.best_scores.size()
	var earned := AchievementList.award_new(profile, achievements)
	var achievement_coins := 0
	for entry: Dictionary in earned:
		achievement_coins += AchievementList.reward_of(entry)
	profile.coins += coins + daily_coins + achievement_coins
	return {
		"coins": coins, "daily_coins": daily_coins, "xp": xp,
		"daily_text": daily["text"] if daily_coins > 0 else "",
		"daily_streak": profile.daily_streak if daily_coins > 0 else 0,
		"level": DriverLevel.level_for(profile.xp),
		"levelled_up": DriverLevel.level_for(profile.xp) > level_before,
		"new_best": new_best,
		"achievements": earned,
		"achievement_coins": achievement_coins,
	}
