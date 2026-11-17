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
	report["rewards"] = rewards
	Profile.save()
	GameEvents.shift_rewards_ready.emit(report)
