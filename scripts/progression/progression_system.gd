class_name ProgressionSystem
extends Node
## At the end of a shift, banks the rewards and saves straight away.


func _ready() -> void:
	GameEvents.shift_report_ready.connect(_on_report)


func _on_report(report: Dictionary) -> void:
	var route: Dictionary = Profile.shift_route()
	var route_id: String = route["id"]
	var bus_id: String = str(route.get("only_bus", Profile.selected_item(Catalog.BUSES)["id"]))
	var time := TimeOfDay.find(Profile.times_of_day(), str(report.get("time_of_day", "")))
	report["time_stat"] = time.stat if time != null else ""
	var director: CelebrationDirector = get_parent().get_node_or_null("Celebrations") if get_parent() != null else null
	if director != null:
		director.on_shift_report(report)
	var rewards := ShiftRewards.apply(Profile.data, report, route_id, DailyChallenge.today_key(),
		DailyChallenge.load_list(), AchievementList.load_list(), bus_id)
	var unlocked: Array[Dictionary] = []
	if bool(report.get("completed", false)):
		unlocked = Profile.data.complete_route(route_id, Profile.catalog)
	rewards["unlocked_routes"] = unlocked
	Profile.pending_unlocks.append_array(UnlockNews.from_rewards(Profile.catalog, Country.pack.horns(), rewards))
	_pay_custom_drivers(route, bool(report.get("completed", false)), rewards)
	report["rewards"] = rewards
	Profile.save()
	GameEvents.shift_rewards_ready.emit(report)


## Custom drivers: cards for new slots, name tags and parts the levels reached,
## and the route's special item the first time it is finished at the slot level.
func _pay_custom_drivers(route: Dictionary, completed: bool, rewards: Dictionary) -> void:
	var parts := Profile.driver_parts
	var before := DriverLevel.level_for(int(rewards.get("xp_before", 0)))
	var after := DriverLevel.level_for(Profile.data.xp)
	Profile.pending_unlocks.append_array(UnlockNews.custom_between(parts, before, after))
	Profile.data.custom.settle_name_tags(parts, after)
	if Profile.custom_drivers_open() and (completed or (Profile.data.best_scores.has(route["id"]) and Profile.route_has_no_end(route))):
		var stars := int(Profile.data.best_stars.get(route["id"], 0))
		Profile.pending_unlocks.append_array(Profile.data.custom.pay_route(route["id"], stars, parts))
