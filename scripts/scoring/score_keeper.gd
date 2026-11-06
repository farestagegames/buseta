class_name ScoreKeeper
extends Node
## Listens to game events and keeps the shift score. Nothing reports to it
## directly, and it only speaks through events, so it can be swapped or removed.

const KERB_COOLDOWN := 4.0
const OFF_ROAD_MARGIN := 0.4
const LOST_COLLISION_SPEED := 0.5

var score := ShiftScore.new()
var monitor := DrivingMonitor.new()

var _network: RoadNetwork
var _spec: BusSpec
var _kerb_timer: float = 0.0
var _wheels_were_on_road: bool = true


func setup(network: RoadNetwork, spec: BusSpec) -> void:
	_network = network
	_spec = spec
	monitor.harsh_brake.connect(_on_harsh_brake)
	monitor.harsh_accel.connect(_on_harsh_accel)
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.bus_collided.connect(_on_collided)
	GameEvents.obstacle_hit.connect(_on_obstacle_hit)
	GameEvents.bus_jolted.connect(_on_jolted)
	GameEvents.red_light_run.connect(_on_red_light)
	GameEvents.indicator_missed.connect(_on_indicator_missed)
	GameEvents.stop_arrived.connect(_on_stop_arrived)
	GameEvents.stop_missed.connect(_on_stop_missed)
	GameEvents.stop_served.connect(_on_stop_served)
	GameEvents.shift_completed.connect(_on_shift_completed)


func _on_telemetry(data: BusTelemetry) -> void:
	var dt := get_physics_process_delta_time()
	_kerb_timer = maxf(_kerb_timer - dt, 0.0)
	monitor.update(data.longitudinal_accel, dt)
	var rear := Vector2(data.position.x, data.position.z)
	var centre := BusFootprint.body_centre(rear, data.heading, _spec)
	var limit := _network.speed_limit_at(centre)
	var off_road := _network.edge_distance(centre) > OFF_ROAD_MARGIN
	score.add_time(dt, DrivingMonitor.is_speeding(data.speed, limit), off_road)
	_check_kerb(rear, data.heading, absf(data.speed))
	GameEvents.score_updated.emit(score.total())


## A wheel climbing the kerb. Only counts as a new strike when it comes back on.
func _check_kerb(rear: Vector2, heading: float, speed: float) -> void:
	var forward := Vector2(-sin(heading), -cos(heading))
	var right := Vector2(-forward.y, forward.x) * _spec.body_width / 2.0
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
	score.add_harsh_brake()
	GameEvents.penalty_shown.emit("Harsh braking")


func _on_harsh_accel() -> void:
	score.add_harsh_accel()
	GameEvents.penalty_shown.emit("Harsh acceleration")


func _on_jolted(_strength: float) -> void:
	if score.add_jolt():
		GameEvents.penalty_shown.emit("Too fast over a bump")


func _on_collided(impact_speed: float) -> void:
	if impact_speed >= LOST_COLLISION_SPEED:
		score.add_collision(impact_speed)
		GameEvents.penalty_shown.emit("Collision")


func _on_obstacle_hit(kind: String, _speed_loss: float) -> void:
	if kind in ["cone", "bin", "crate", "barrier"]:
		score.add_knocked()
		GameEvents.penalty_shown.emit("Hit a %s" % kind)


func _on_red_light() -> void:
	score.add_red_light()
	GameEvents.penalty_shown.emit("Ran a red light")


func _on_indicator_missed() -> void:
	score.add_missed_indicator()
	GameEvents.penalty_shown.emit("No indicator")


func _on_stop_arrived(_index: int, accuracy: float, seconds_late: float) -> void:
	score.add_stop(accuracy, seconds_late)


func _on_stop_missed(_index: int, stop_name: String) -> void:
	score.add_missed_stop()
	GameEvents.penalty_shown.emit("Missed %s" % stop_name)


func _on_stop_served(_index: int, _name: String, left_behind: int) -> void:
	if left_behind > 0:
		score.add_left_behind(left_behind)
		GameEvents.penalty_shown.emit("Left %d waiting" % left_behind)


func _on_shift_completed(summary: Dictionary) -> void:
	var report := summary.duplicate()
	var carried: int = summary["carried"]
	report["score"] = score.total()
	report["stars"] = score.stars()
	report["coins"] = score.coins(carried)
	report["categories"] = score.categories()
	report["details"] = _details(summary)
	GameEvents.shift_report_ready.emit(report)


func _details(summary: Dictionary) -> String:
	var counts := score.counts
	var notes: Array[String] = ["%d passengers carried" % summary["carried"]]
	var labels := {
		"collisions": "collisions", "red_lights": "red lights", "knocked": "objects hit",
		"harsh_brakes": "harsh stops", "harsh_accels": "harsh starts", "jolts": "hard bumps",
		"kerbs": "kerb strikes", "indicators": "turns not signalled", "missed_stops": "stops missed",
		"left_behind": "left waiting",
	}
	for key: String in labels:
		if int(counts[key]) > 0:
			notes.append("%d %s" % [counts[key], labels[key]])
	if score.speeding_seconds >= 1.0:
		notes.append("%d s speeding" % roundi(score.speeding_seconds))
	if score.off_road_seconds >= 1.0:
		notes.append("%d s off road" % roundi(score.off_road_seconds))
	return ", ".join(notes)
