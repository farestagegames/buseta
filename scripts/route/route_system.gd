class_name RouteSystem
extends Node
## Runs the shift: watches the bus through telemetry, starts stop sessions when
## it is parked in a bay with the doors open, and publishes progress. Holds no
## reference to the bus, the HUD or any passenger visuals.

const STATUS_INTERVAL := 0.2
const PASSENGER_SEED := 2024
const INDICATOR_WINDOW := 70.0
const HAIL_NOTICE_DISTANCE := 90.0
## After the police stop the bus, the shift ends this long later so the message is seen.
const POLICE_STOP_SECONDS := 2.5
const DODGER_SEED := 3131
## Stopped this close short of a hail marker, the prompt says to pull forward.
## Further back, as at a red light, it just says how far the marker is.
const PULL_FORWARD_NOTICE := 30
## A vendor works the bus for this many stops, then gets off.
const VENDOR_STOPS := 2

var runner: RouteRunner
var ledger: PassengerLedger
var session: StopSession = null
var schedule: ShiftSchedule
var clock: float = 0.0
var finished: bool = false
var held: bool = false ## The timetable waits during the tutorial.

var _spec: BusSpec
var _session_stop: int = -1
var _status_timer: float = 0.0
var _served: int = 0
var _missed: int = 0
var _left_behind: int = 0
var _accuracy_total: float = 0.0
var _aligned: bool = false
var _session_was_accuracy_counted: bool = false
var _status: Dictionary = {}
var _network: RoadNetwork
var _next_turn: int = 0
var _indicated: bool = false
var _last_late: float = 0.0
var _fare: int = 0
var _fares: int = 0
var _vendor_stops_left: int = 0
var _vendor_stop: int = -1
## Seconds the timetable has allowed for driving on a wet road, and how fast that
## grows now. Everyone slows in a downpour, so the bus is not blamed for it.
var rain_slack: float = 0.0
## Chance each boarding passenger slips on without paying, from the difficulty.
var dodger_chance: float = 0.0
var _dodgers := RandomNumberGenerator.new()
var _slack_rate: float = 0.0


func setup(route: RouteRunner, spec: BusSpec, network: RoadNetwork, fare: int = 0) -> void:
	runner = route
	_fare = fare
	_spec = spec
	_network = network
	var times := PackedFloat32Array()
	for stop in route.stops:
		times.append(stop.due)
	schedule = ShiftSchedule.new(times)
	ledger = PassengerLedger.new(PASSENGER_SEED, route.stops.size() - 2)
	ledger.capacity = spec.capacity
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.reset_requested.connect(_on_recover_requested)
	GameEvents.skip_stop_requested.connect(skip_to_next_stop)
	GameEvents.finish_shift_requested.connect(finish_now)
	GameEvents.police_ended_run.connect(func(_reason: String) -> void:
		get_tree().create_timer(POLICE_STOP_SECONDS).timeout.connect(finish_now))
	_dodgers.seed = DODGER_SEED
	GameEvents.shift_held_changed.connect(func(value: bool) -> void: held = value)
	GameEvents.weather_updated.connect(func(weather: WeatherClock) -> void: _slack_rate = weather.slack_rate())


func _on_telemetry(data: BusTelemetry) -> void:
	tick(data, get_physics_process_delta_time())


func tick(data: BusTelemetry, dt: float) -> void:
	if finished:
		return
	if not held:
		clock += dt
		rain_slack += dt * _slack_rate
	var rear := Vector2(data.position.x, data.position.z)
	var centre := BusFootprint.body_centre(rear, data.heading, _spec)
	runner.update_position(centre, Vector2(-sin(data.heading), -cos(data.heading)))
	_check_indicator(data)
	var stop := runner.current_stop()
	_aligned = stop.is_aligned(centre, data.heading)
	var stopped := absf(data.speed) < BusPhysicsModel.STOPPED_SPEED

	if stop.is_final:
		if _aligned and stopped:
			GameEvents.stop_arrived.emit(runner.stop_index, stop.accuracy(centre), schedule.seconds_late(runner.stop_index, timetable_clock()))
			_finish()
			return
	elif session != null:
		_run_session(stop, data, centre, dt)
	elif _aligned and stopped and data.door_open_amount >= 1.0:
		_start_session(stop, centre)
	elif stop.is_passed(centre):
		if stop.kind == RouteStop.Kind.HAIL:
			_drive_past_hail(stop)
		else:
			GameEvents.stop_missed.emit(runner.stop_index, stop.stop_name)
			_missed += 1
		_next_stop()

	_status_timer -= dt
	if _status_timer <= 0.0:
		_status_timer = STATUS_INTERVAL
		_publish_status(data, centre)


## A turn counts as signalled if the matching indicator was on during the approach.
func _check_indicator(data: BusTelemetry) -> void:
	if _next_turn >= runner.turns.size():
		return
	var turn: Dictionary = runner.turns[_next_turn]
	var ahead: float = float(turn["distance"]) - runner.progress
	if ahead < INDICATOR_WINDOW and data.indicator_side == int(turn["side"]):
		_indicated = true
	if ahead < 0.0:
		if int(turn["side"]) != 0 and not _indicated:
			GameEvents.indicator_missed.emit()
		_next_turn += 1
		_indicated = false


## Nothing stops an informal bus going past people, but they notice.
func _drive_past_hail(stop: RouteStop) -> void:
	var wanting := ledger.wanting_off(runner.stop_index)
	ledger.carry_on_past(runner.stop_index)
	if wanting > 0:
		GameEvents.request_ignored.emit(wanting)
	if stop.waiting > 0:
		GameEvents.hail_ignored.emit(stop.waiting)


func _start_session(stop: RouteStop, centre: Vector2) -> void:
	var alighting := ledger.alight_at(runner.stop_index)
	var boarding := ledger.boardable(stop.waiting)
	if runner.stop_index >= runner.stops.size() - 2:
		boarding = 0
	_accuracy_total += stop.accuracy(centre)
	GameEvents.stop_arrived.emit(runner.stop_index, stop.accuracy(centre), schedule.seconds_late(runner.stop_index, timetable_clock()))
	_session_stop = runner.stop_index
	session = StopSession.new(alighting, boarding)
	session.passenger_alighted.connect(_on_alighted)
	session.passenger_boarded.connect(_on_boarded)
	GameEvents.stop_session_started.emit(runner.stop_index, alighting, boarding)


func _run_session(stop: RouteStop, data: BusTelemetry, centre: Vector2, dt: float) -> void:
	session.update(dt, data.door_open_amount >= 1.0)
	if stop.vendor and session.is_complete() and _vendor_stop != runner.stop_index:
		_vendor_stop = runner.stop_index
		_vendor_stops_left = VENDOR_STOPS + 1
		GameEvents.vendor_boarded.emit()
	var driven_off := not stop.is_aligned(centre, data.heading) and absf(data.speed) > BusPhysicsModel.STOPPED_SPEED
	if (session.is_complete() and data.doors_closed) or driven_off:
		var behind := session.boarding_left
		_left_behind += behind
		_served += 1
		GameEvents.stop_served.emit(runner.stop_index, stop.stop_name, behind)
		session = null
		_next_stop()


func _on_alighted() -> void:
	GameEvents.passenger_alighted.emit(_session_stop)
	GameEvents.onboard_changed.emit(ledger.count() + session.alighting_left)


func _on_boarded() -> void:
	ledger.board_one(_session_stop)
	if _fare > 0 and dodger_chance > 0.0 and _dodgers.randf() < dodger_chance:
		GameEvents.fare_dodged.emit()
	else:
		_fares += _fare
	GameEvents.passenger_boarded.emit(_session_stop)
	GameEvents.onboard_changed.emit(ledger.count())


func _next_stop() -> void:
	_last_late = maxf(timetable_clock() - schedule.due_times[runner.stop_index], 0.0)
	runner.advance_stop()
	_count_down_vendor()
	if not runner.is_finished() and ledger.wanting_off(runner.stop_index) > 0:
		GameEvents.stop_requested.emit()


func _count_down_vendor() -> void:
	if _vendor_stops_left <= 0:
		return
	_vendor_stops_left -= 1
	if _vendor_stops_left == 0:
		GameEvents.vendor_left.emit()


func _finish() -> void:
	finished = true
	var carried := ledger.carried_total
	ledger.clear()
	GameEvents.onboard_changed.emit(0)
	GameEvents.shift_completed.emit({
		"route": runner.route_name, "carried": carried, "served": _served, "missed": _missed,
		"left_behind": _left_behind, "time": clock, "fares": _fares,
		"accuracy": _accuracy_total / float(maxi(_served, 1)),
	})


## Cheat: treats the stop in hand as served and parks in the bay after it.
func skip_to_next_stop() -> void:
	if finished:
		return
	if session != null or (_aligned and not runner.current_stop().is_final):
		var stop := runner.current_stop()
		session = null
		_served += 1
		GameEvents.stop_served.emit(runner.stop_index, stop.stop_name, 0)
		_next_stop()
	runner.jump_to_stop()
	while _next_turn < runner.turns.size() and float(runner.turns[_next_turn]["distance"]) < runner.progress:
		_next_turn += 1
	_indicated = false
	var next := runner.current_stop()
	GameEvents.bus_relocate_requested.emit(next.position + next.forward() * _spec.body_centre_z(), next.heading)


## Cheat: ends the shift where the bus is.
func finish_now() -> void:
	if not finished:
		_finish()


func _on_recover_requested() -> void:
	var pose := runner.recovery_pose()
	GameEvents.bus_relocate_requested.emit(pose["position"], pose["heading"])


func _publish_status(data: BusTelemetry, centre: Vector2) -> void:
	var stop := runner.current_stop()
	_status["next_stop"] = stop.stop_name
	_status["distance"] = runner.distance_to_next_stop()
	_status["turn"] = "Speed bump ahead" if runner.hazard_ahead() else runner.upcoming_turn()
	_status["onboard"] = ledger.count()
	_status["fares"] = _fares
	_status["prompt"] = _prompt(stop, data, centre)
	_status["stop_position"] = stop.position
	_status["stop_number"] = runner.stop_index + 1
	_status["stop_count"] = runner.stops.size()
	_status["clock"] = clock
	_status["seconds_late"] = _running_lateness()
	_status["speed_limit"] = _network.speed_limit_at(centre)
	GameEvents.route_status_updated.emit(_status)


## The clock the timetable is judged by: the shift's time, less what the rain allowed.
func timetable_clock() -> float:
	return clock - rain_slack


## How the bus stands against the timetable. It only shows as late once a stop
## is overdue, or when it left the last stop behind time.
func _running_lateness() -> float:
	var due := schedule.due_times[runner.stop_index]
	var overdue := timetable_clock() - due
	return maxf(overdue, _last_late) if overdue > -ShiftSchedule.ON_TIME_EARLY else _last_late


func _prompt(stop: RouteStop, data: BusTelemetry, centre: Vector2) -> String:
	if session != null:
		if session.is_complete():
			return tr("All aboard: close the doors")
		return tr("Passengers getting off") if session.stage == StopSession.Stage.ALIGHTING else tr("Passengers boarding")
	var offset := stop.offset_of(centre)
	if stop.kind == RouteStop.Kind.HAIL and not stop.is_final and offset.x < -stop.along_tolerance() and -offset.x < HAIL_NOTICE_DISTANCE:
		# Say where, so nobody stops short and waits for people who are not
		# getting off yet.
		var metres := ceili(-offset.x - stop.along_tolerance())
		if absf(data.speed) < BusPhysicsModel.STOPPED_SPEED and metres <= PULL_FORWARD_NOTICE:
			return tr("Pull forward %d m") % metres
		return tr("Getting off at the green marker: %d m") % metres if ledger.wanting_off(runner.stop_index) > 0 else tr("Flagging you down at the green marker: %d m") % metres
	if absf(offset.x) > 30.0:
		return ""
	if _aligned:
		if absf(data.speed) >= BusPhysicsModel.STOPPED_SPEED:
			return tr("Stop here")
		return tr("Stop reached") if stop.is_final else tr("Open the doors")
	if absf(offset.x) > stop.along_tolerance():
		return tr("Pull forward %d m") % ceili(-offset.x - stop.along_tolerance()) if offset.x < 0.0 else tr("Too far forward")
	return tr("Pull into the bay") if absf(offset.y) > stop.lateral_tolerance() else tr("Straighten up")
