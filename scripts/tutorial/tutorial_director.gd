class_name TutorialDirector
extends Node
## Runs the tutorial on screen: shows each step, rings the control it is about,
## and tells the game when it is over.

signal finished

var script_steps := TutorialScript.new()
var active: bool = false

var _hud: DriveHud
var _route: RouteSystem
var _spec: BusSpec
var _state: Dictionary = {
	"speed": 0.0, "steer": 0.0, "brake": 0.0, "view_changes": 0, "indicator": 0, "turn_passed": false,
	"stop_distance": INF, "stop_index": 0, "parked": false, "doors_open": false, "doors_closed": true,
	"session_done": false,
}
var _shown_step: String = ""


func setup(hud: DriveHud, route: RouteSystem, spec: BusSpec) -> void:
	_hud = hud
	_route = route
	_spec = spec
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.camera_view_changed.connect(_on_view_changed)
	_hud.tutorial_panel.skip_requested.connect(finish)
	get_viewport().size_changed.connect(_on_viewport_resized)


func start() -> void:
	active = true
	_state["view_changes"] = 0
	_show_step()


## Ends the tutorial early, or at its natural end.
func finish() -> void:
	if not active:
		return
	active = false
	_hud.tutorial_panel.hide_panel()
	finished.emit()


func _on_view_changed(_name: String) -> void:
	_state["view_changes"] = int(_state["view_changes"]) + 1


func _on_telemetry(data: BusTelemetry) -> void:
	if not active:
		return
	_read_state(data)
	script_steps.update(_state, get_physics_process_delta_time())
	if script_steps.is_finished():
		finish()
	else:
		_show_step()


func _read_state(data: BusTelemetry) -> void:
	var runner := _route.runner
	var stop := runner.current_stop()
	var centre := BusFootprint.body_centre(Vector2(data.position.x, data.position.z), data.heading, _spec)
	_state["speed"] = data.speed
	_state["steer"] = data.steer_angle
	_state["brake"] = data.brake
	_state["indicator"] = data.indicator_side
	_state["turn_passed"] = runner.turns.is_empty() or float(runner.turns[0]["distance"]) < runner.progress
	_state["stop_distance"] = runner.distance_to_next_stop()
	_state["stop_index"] = runner.stop_index
	_state["parked"] = stop != null and stop.is_aligned(centre, data.heading) and absf(data.speed) < BusPhysicsModel.STOPPED_SPEED
	_state["doors_open"] = data.door_open_amount >= 1.0
	_state["doors_closed"] = data.doors_closed
	_state["session_done"] = _route.session != null and _route.session.is_complete()


func _on_viewport_resized() -> void:
	if active and _shown_step != "":
		# Controls may move after a resize; refresh on the next frame once layout settles.
		call_deferred("_refresh_ring")


func _refresh_ring() -> void:
	if not active or _shown_step == "":
		return
	var step := script_steps.step()
	if step.is_empty():
		return
	_hud.tutorial_panel.show_step(step["text"], _hud.control_rect(step["focus"]))


func _show_step() -> void:
	var step := script_steps.step()
	if step.is_empty() or step["id"] == _shown_step:
		return
	_shown_step = step["id"]
	_refresh_ring()
