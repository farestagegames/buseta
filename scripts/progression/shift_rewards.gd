class_name ShiftRewards
extends RefCounted
## Turns a finished shift's report into coins, XP, stats and awards. Pure logic:
## it changes the profile it is given and returns what happened.


static func apply(profile: PlayerProfile, report: Dictionary, route_id: String, date_key: String, challenges: Array, achievements: Array) -> Dictionary:
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

	var daily_coins := 0
	var daily: Dictionary = DailyChallenge.for_date(date_key, challenges)
	if profile.last_daily != date_key and DailyChallenge.is_passed(daily, report):
		profile.last_daily = date_key
		daily_coins = DailyChallenge.REWARD_COINS

	profile.coins += coins + daily_coins
	profile.xp += xp
	return {
		"coins": coins, "daily_coins": daily_coins, "xp": xp,
		"daily_text": daily["text"] if daily_coins > 0 else "",
		"level": DriverLevel.level_for(profile.xp),
		"levelled_up": DriverLevel.level_for(profile.xp) > level_before,
		"new_best": profile.record_best(route_id, report["score"]),
		"achievements": AchievementList.award_new(profile, achievements),
	}
