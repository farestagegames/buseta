class_name ScoreKeeper
extends Node
## Listens to game events and keeps the shift score. Nothing reports to it
## directly, and it only speaks through events, so it can be swapped or removed.

const KERB_COOLDOWN := 4.0
const OFF_ROAD_MARGIN := 0.4
const LOST_COLLISION_SPEED := 0.5
const HIT_MESSAGES := {"cone": "Hit a cone", "bin": "Hit a bin", "crate": "Hit a crate", "barrier": "Hit a barrier", "stall": "Hit a stall", "moto": "Hit a motorbike"}
const TIPS := {
	"punctuality": "Tip: you lost the most time between stops. Keep moving when the road is clear.",
	"accuracy": "Tip: stop with the bus in the middle of the bay.",
	"smoothness": "Tip: slow down for speed bumps and avoid sudden stops.",
	"rules": "Tip: watch the lights, the speed limit and the kerbs.",
	"satisfaction": "Tip: avoid knocks and wait for everyone to board.",
}
## Contact within this time is the same crash, however long the bus scrapes.
const COLLISION_COOLDOWN := 2.5
## The downpour counts as over once the rain is this light.
const DOWNPOUR_OVER_RAIN := 0.1

var score := ShiftScore.new()
var monitor := DrivingMonitor.new()

var _network: RoadNetwork
var _spec: BusSpec
var _kerb_timer: float = 0.0
var _collision_timer: float = 0.0
var _wheels_were_on_road: bool = true
var _held: bool = false ## Nothing counts against a driver in the tutorial.
var _time_of_day: String = ""
var _in_downpour: bool = false
var _faults_before_downpour: int = 0
var _speeding_for: float = 0.0
var _police_stopped: String = "" ## Why the police ended the run, or "".
var _police_stops: int = 0 ## Times the police stopped the bus this shift (fines and the last stop).
var _difficulty_id: String = ""
var _goals: Array = []
var _service: String = "bays"
## On the endless route, passengers give up when satisfaction gets this low.
var give_up_below: float = -1.0
var _gave_up: bool = false
var _patience_check: float = 0.0


func setup(network: RoadNetwork, spec: BusSpec, difficulty: Difficulty = null, goals: Array = [], service: String = "bays") -> void:
	_network = network
	_spec = spec
	_goals = goals
	_service = service
	if difficulty != null:
		score.penalty_scale = difficulty.penalty_scale
		score.coin_scale = difficulty.coin_scale
		_difficulty_id = difficulty.id
	GameEvents.police_fined.connect(_on_police_fined)
	GameEvents.police_ended_run.connect(_on_police_ended_run)
	GameEvents.fare_dodged.connect(_on_fare_dodged)
	monitor.harsh_brake.connect(_on_harsh_brake)
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.bus_collided.connect(_on_collided)
	GameEvents.obstacle_hit.connect(_on_obstacle_hit)
	GameEvents.bus_jolted.connect(_on_jolted)
	GameEvents.red_light_run.connect(_on_red_light)
	GameEvents.indicator_missed.connect(_on_indicator_missed)
	GameEvents.stop_arrived.connect(_on_stop_arrived)
	GameEvents.stop_missed.connect(_on_stop_missed)
	GameEvents.stop_served.connect(_on_stop_served)
	GameEvents.hail_ignored.connect(_on_hail_ignored)
	GameEvents.request_ignored.connect(_on_request_ignored)
	GameEvents.vendor_boarded.connect(_on_vendor_boarded)
	GameEvents.shift_completed.connect(_on_shift_completed)
	GameEvents.shift_held_changed.connect(func(held: bool) -> void: _held = held)
	GameEvents.weather_updated.connect(_on_weather)
	GameEvents.time_of_day_set.connect(func(time_id: String) -> void: _time_of_day = time_id)


## A downpour runs from when it pours hard to when it has nearly stopped. Driving
## all through it without a fault earns the bonus.
func _on_weather(weather: WeatherClock) -> void:
	if weather.is_downpour() and not _in_downpour:
		_in_downpour = true
		_faults_before_downpour = _faults()
	elif _in_downpour and weather.rain < DOWNPOUR_OVER_RAIN:
		_end_downpour()


func _end_downpour() -> void:
	_in_downpour = false
	score.add_downpour(_faults() == _faults_before_downpour)


func _faults() -> int:
	return int(score.counts["collisions"]) + int(score.counts["harsh_brakes"]) + int(score.counts["knocked"])


func _on_telemetry(data: BusTelemetry) -> void:
	if _held:
		return
	var dt := get_physics_process_delta_time()
	_kerb_timer = maxf(_kerb_timer - dt, 0.0)
	_collision_timer = maxf(_collision_timer - dt, 0.0)
	monitor.update(data.longitudinal_accel, dt)
	var rear := Vector2(data.position.x, data.position.z)
	var centre := BusFootprint.body_centre(rear, data.heading, _spec)
	var limit := _network.speed_limit_at(centre)
	var off_road := _network.edge_distance(centre) > OFF_ROAD_MARGIN
	var speeding := DrivingMonitor.is_speeding(data.speed, limit)
	score.add_time(dt, speeding, off_road)
	# Sustained speeding is a fault the police can see, once each time.
	var was := _speeding_for
	_speeding_for = _speeding_for + dt if speeding else 0.0
	if was < PoliceSystem.SPEEDING_SECONDS and _speeding_for >= PoliceSystem.SPEEDING_SECONDS:
		GameEvents.speeding_started.emit()
	_check_kerb(rear, data.heading, absf(data.speed))
	GameEvents.score_updated.emit(score.total())
	_patience_check -= dt
	if give_up_below > 0.0 and not _gave_up and _patience_check <= 0.0:
		_patience_check = 1.0
		if float(score.categories()["satisfaction"]) < give_up_below:
			_gave_up = true
			GameEvents.penalty_shown.emit("Your passengers have had enough")
			GameEvents.passengers_gave_up.emit()


## A wheel climbing the kerb. Only counts as a new strike when it comes back on.
func _check_kerb(rear: Vector2, heading: float, speed: float) -> void:
	var forward := Vector2(-sin(heading), -cos(heading))
	var right := Vector2(-forward.y, forward.x) * (_spec.body_width / 2.0 - BusController.WHEEL_TRACK_INSET)
	var front := rear + forward * _spec.wheelbase
	var on_road := true
	for wheel: Vector2 in [front - right, front + right, rear - right, rear + right]:
		if _network.edge_distance(wheel) > 0.05:
			on_road = false
	if _wheels_were_on_road and not on_road and speed > 0.5 and _kerb_timer <= 0.0:
		_kerb_timer = KERB_COOLDOWN
		score.add_kerb()
		GameEvents.penalty_shown.emit("Kerb strike")
	_wheels_were_on_road = on_road


func _on_harsh_brake() -> void:
	if _held:
		return
	score.add_harsh_brake()
	GameEvents.penalty_shown.emit("Emergency stop")


func _on_jolted(_strength: float) -> void:
	if _held:
		return
	if score.add_jolt():
		GameEvents.penalty_shown.emit("Too fast over a bump")


func _on_collided(impact_speed: float) -> void:
	if _held:
		return
	if impact_speed >= LOST_COLLISION_SPEED and _collision_timer <= 0.0:
		_collision_timer = COLLISION_COOLDOWN
		score.add_collision(impact_speed)
		GameEvents.penalty_shown.emit("Collision")


func _on_obstacle_hit(kind: String, _speed_loss: float) -> void:
	if _held:
		return
	if HIT_MESSAGES.has(kind):
		score.add_knocked()
		GameEvents.penalty_shown.emit(HIT_MESSAGES[kind])


func _on_red_light() -> void:
	if _held:
		return
	score.add_red_light()
	GameEvents.penalty_shown.emit("Ran a red light")


func _on_indicator_missed() -> void:
	if _held:
		return
	score.add_missed_indicator()
	GameEvents.penalty_shown.emit("No indicator")


func _on_stop_arrived(_index: int, accuracy: float, seconds_late: float, is_perfect: bool) -> void:
	score.add_stop(accuracy, seconds_late, is_perfect)


func _on_stop_missed(_index: int, stop_name: String) -> void:
	if _held:
		return
	score.add_missed_stop()
	GameEvents.penalty_shown.emit(tr("Missed %s") % stop_name)


func _on_stop_served(_index: int, _name: String, left_behind: int) -> void:
	if _held:
		return
	if left_behind > 0:
		score.add_left_behind(left_behind)
		GameEvents.penalty_shown.emit(tr("Left %d waiting") % left_behind)


func _on_hail_ignored(people: int) -> void:
	if _held:
		return
	score.add_ignored_hail(people)
	GameEvents.penalty_shown.emit(tr("Left %d waiting") % people)


func _on_request_ignored(people: int) -> void:
	if _held:
		return
	score.add_ignored_request(people)
	GameEvents.penalty_shown.emit("Missed a stop request")


func _on_police_fined(coins_lost: int, reason: String) -> void:
	_police_stops += 1
	score.add_fine(coins_lost)
	GameEvents.penalty_shown.emit(tr("Police fine %s: %s") % [Country.pack.money(coins_lost), tr(reason)])


func _on_police_ended_run(reason: String) -> void:
	_police_stops += 1
	_police_stopped = reason
	GameEvents.penalty_shown.emit(tr("Stopped by the transit police: %s") % tr(reason))


func _on_fare_dodged() -> void:
	score.add_dodger()
	GameEvents.penalty_shown.emit("A fare dodger slipped on: watch the door from the cab")


func _on_vendor_boarded() -> void:
	score.add_vendor()


func live_report(time: float, served: int, carried: int) -> Dictionary:
	return {
		"time": time,
		"served": served,
		"carried": carried,
		"counts": score.counts.duplicate(),
		"categories": score.categories(),
		"fined_coins": score.fined_coins,
		"perfect_stops": int(score.counts.get("perfect_stops", 0)),
	}


func _on_shift_completed(summary: Dictionary) -> void:
	if _in_downpour:
		_end_downpour()
	var report := summary.duplicate()
	report["service"] = _service
	report["time_of_day"] = _time_of_day
	report["difficulty"] = _difficulty_id
	report["police_stopped"] = _police_stopped
	report["police_stops"] = _police_stops
	report["gave_up"] = _gave_up
	report["completed"] = bool(summary.get("completed", false))
	report["downpour"] = int(score.counts["downpours"]) > 0
	var carried: int = summary["carried"]
	report["score"] = score.total()
	report["categories"] = score.categories()
	report["counts"] = score.counts.duplicate()
	report["fined_coins"] = score.fined_coins
	report["perfect_stops"] = int(score.counts.get("perfect_stops", 0))
	report["served"] = int(summary.get("served", 0))
	if summary.has("arcade"):
		var arcade: Dictionary = summary["arcade"]
		report["arcade"] = arcade
		report["score"] = int(arcade["checkpoints"])
		report["stars"] = ArcadeRun.stars_for(int(arcade["checkpoints"]))
		report["coins"] = ArcadeRun.coins_for(int(arcade["checkpoints"]), float(arcade["distance"]))
		report["goals"] = []
		report["coin_breakdown"] = {}
	elif _service == "endless":
		report["stars"] = score.stars()
		report["coin_breakdown"] = score.coin_breakdown(carried, int(report["stars"]))
		report["coins"] = int(report["coin_breakdown"]["total"])
		report["goals"] = []
	else:
		var evaluated := RouteGoals.evaluate(_goals, report)
		report["goals"] = evaluated
		report["stars"] = RouteGoals.stars_for(_goals, report)
		report["coin_breakdown"] = score.coin_breakdown(carried, int(report["stars"]))
		report["coins"] = int(report["coin_breakdown"]["total"])
	report["details"] = _details(summary)
	var weakest := score.weakest_category()
	report["tip"] = tr(TIPS[weakest]) if weakest != "" else ""
	GameEvents.shift_report_ready.emit(report)


func _details(summary: Dictionary) -> String:
	var counts := score.counts
	var notes: Array[String] = [_count(summary["carried"], "%d passenger carried", "%d passengers carried")]
	if int(summary.get("fares", 0)) > 0:
		notes.append(tr("%s in fares") % Country.pack.money(summary["fares"]))
	var labels := {
		"collisions": ["%d collision", "%d collisions"], "red_lights": ["%d red light", "%d red lights"],
		"knocked": ["%d object hit", "%d objects hit"], "harsh_brakes": ["%d emergency stop", "%d emergency stops"],
		"jolts": ["%d hard bump", "%d hard bumps"], "kerbs": ["%d kerb strike", "%d kerb strikes"],
		"indicators": ["%d turn not signalled", "%d turns not signalled"],
		"missed_stops": ["%d stop missed", "%d stops missed"],
		"left_behind": ["%d person left waiting", "%d people left waiting"],
		"ignored_hails": ["%d person left waiting", "%d people left waiting"],
		"ignored_requests": ["%d stop request missed", "%d stop requests missed"],
		"vendors": ["%d vendor on board", "%d vendors on board"],
		"fines": ["%d police fine", "%d police fines"],
		"dodgers": ["%d fare dodger", "%d fare dodgers"],
	}
	for key: String in labels:
		if int(counts[key]) > 0:
			notes.append(_count(counts[key], labels[key][0], labels[key][1]))
	if int(counts["clean_downpours"]) > 0:
		notes.append(tr("Downpour survived: +%s") % Country.pack.money(ShiftScore.DOWNPOUR_COINS))
	elif int(counts["downpours"]) > 0:
		notes.append(tr("Drove through a downpour"))
	if score.speeding_seconds >= 1.0:
		notes.append(tr("%d s speeding") % roundi(score.speeding_seconds))
	if score.off_road_seconds >= 1.0:
		notes.append(tr("%d s off road") % roundi(score.off_road_seconds))
	if score.fined_coins > 0:
		notes.append(tr("%s in fines") % Country.pack.money(score.fined_coins))
	return ", ".join(notes)


func _count(amount: int, one: String, many: String) -> String:
	return tr(one if amount == 1 else many) % amount
