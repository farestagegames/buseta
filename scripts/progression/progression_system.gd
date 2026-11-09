class_name ProgressionSystem
extends Node
## At the end of a shift, banks the rewards and saves straight away.


func _ready() -> void:
	GameEvents.shift_report_ready.connect(_on_report)


func _on_report(report: Dictionary) -> void:
	var route_id: String = Profile.selected_item(Catalog.ROUTES)["id"]
	var time := TimeOfDay.find(Profile.times_of_day(), str(report.get("time_of_day", "")))
	report["time_stat"] = time.stat if time != null else ""
	report["rewards"] = ShiftRewards.apply(Profile.data, report, route_id, DailyChallenge.today_key(),
		DailyChallenge.load_list(), AchievementList.load_list())
	Profile.save()
	GameEvents.shift_rewards_ready.emit(report)
