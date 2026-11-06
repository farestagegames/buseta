class_name RouteSystem
extends Node
## Runs the shift: watches the bus through telemetry, starts stop sessions when
## it is parked in a bay with the doors open, and publishes progress. Holds no
## reference to the bus, the HUD or any passenger visuals.

const STATUS_INTERVAL := 0.2
const PASSENGER_SEED := 2024

var runner: RouteRunner
var ledger: PassengerLedger
var session: StopSession = null
var finished: bool = false

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


func setup(route: RouteRunner, spec: BusSpec) -> void:
	runner = route
	_spec = spec
	ledger = PassengerLedger.new(PASSENGER_SEED, route.stops.size() - 2)
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.reset_requested.connect(_on_recover_requested)


func _on_telemetry(data: BusTelemetry) -> void:
	tick(data, get_physics_process_delta_time())


func tick(data: BusTelemetry, dt: float) -> void:
	if finished:
		return
	var rear := Vector2(data.position.x, data.position.z)
	var centre := BusFootprint.body_centre(rear, data.heading, _spec)
	runner.update_position(centre)
	var stop := runner.current_stop()
	_aligned = stop.is_aligned(centre, data.heading)
	var stopped := absf(data.speed) < BusPhysicsModel.STOPPED_SPEED

	if stop.is_final:
		if _aligned and stopped:
			_finish()
			return
	elif session != null:
		_run_session(stop, data, centre, dt)
	elif _aligned and stopped and data.door_open_amount >= 1.0:
		_start_session(stop, centre)
	elif stop.is_passed(centre):
		GameEvents.stop_missed.emit(runner.stop_index, stop.stop_name)
		_missed += 1
		_next_stop()

	_status_timer -= dt
	if _status_timer <= 0.0:
		_status_timer = STATUS_INTERVAL
		_publish_status(data, centre)


func _start_session(stop: RouteStop, centre: Vector2) -> void:
	var alighting := ledger.alight_at(runner.stop_index)
	var boarding := ledger.boardable(stop.waiting)
	if runner.stop_index >= runner.stops.size() - 2:
		boarding = 0
	_accuracy_total += stop.accuracy(centre)
	_session_stop = runner.stop_index
	session = StopSession.new(alighting, boarding)
	session.passenger_alighted.connect(_on_alighted)
	session.passenger_boarded.connect(_on_boarded)
	GameEvents.stop_session_started.emit(runner.stop_index, alighting, boarding)


func _run_session(stop: RouteStop, data: BusTelemetry, centre: Vector2, dt: float) -> void:
	session.update(dt, data.door_open_amount >= 1.0)
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
	GameEvents.passenger_boarded.emit(_session_stop)
	GameEvents.onboard_changed.emit(ledger.count())


func _next_stop() -> void:
	runner.advance_stop()


func _finish() -> void:
	finished = true
	var carried := ledger.carried_total
	ledger.clear()
	GameEvents.onboard_changed.emit(0)
	GameEvents.shift_completed.emit({
		"route": runner.route_name, "carried": carried, "served": _served, "missed": _missed,
		"left_behind": _left_behind,
		"accuracy": _accuracy_total / float(maxi(_served, 1)),
	})


func _on_recover_requested() -> void:
	var pose := runner.recovery_pose()
	GameEvents.bus_relocate_requested.emit(pose["position"], pose["heading"])


func _publish_status(data: BusTelemetry, centre: Vector2) -> void:
	var stop := runner.current_stop()
	_status["next_stop"] = stop.stop_name
	_status["distance"] = runner.distance_to_next_stop()
	_status["turn"] = runner.upcoming_turn()
	_status["onboard"] = ledger.count()
	_status["prompt"] = _prompt(stop, data, centre)
	_status["stop_position"] = stop.position
	_status["stop_number"] = runner.stop_index + 1
	_status["stop_count"] = runner.stops.size()
	GameEvents.route_status_updated.emit(_status)


func _prompt(stop: RouteStop, data: BusTelemetry, centre: Vector2) -> String:
	if session != null:
		if session.is_complete():
			return "All aboard: close the doors"
		return "Passengers getting off" if session.stage == StopSession.Stage.ALIGHTING else "Passengers boarding"
	var offset := stop.offset_of(centre)
	if absf(offset.x) > 30.0:
		return ""
	if _aligned:
		if absf(data.speed) >= BusPhysicsModel.STOPPED_SPEED:
			return "Stop here"
		return "Stop reached" if stop.is_final else "Open the doors"
	if absf(offset.x) > RouteStop.ALONG_TOLERANCE:
		return "Pull forward %d m" % ceili(-offset.x - RouteStop.ALONG_TOLERANCE) if offset.x < 0.0 else "Too far forward"
	return "Pull into the bay" if absf(offset.y) > RouteStop.LATERAL_TOLERANCE else "Straighten up"
