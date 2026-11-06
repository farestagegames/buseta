class_name CameraRig
extends Camera3D
## Cockpit, close follow and far follow views, switched with one tap. Runs per
## rendered frame and reads the interpolated bus position, so movement stays
## smooth when the frame rate and the 60 Hz physics tick disagree.

const VIEWS: Array[Dictionary] = [
	{"name": "Cockpit", "cockpit": true, "fov": 72.0},
	{"name": "Close", "cockpit": false, "fov": 62.0, "distance": 15.0, "height": 5.5, "look_ahead": 6.0, "look_height": 1.8, "heading_rate": 4.0},
	{"name": "Far", "cockpit": false, "fov": 58.0, "distance": 26.0, "height": 11.0, "look_ahead": 10.0, "look_height": 1.0, "heading_rate": 2.5},
]
const START_VIEW := 1
## Cockpit view turns a little toward the bend, as a driver's head would.
const COCKPIT_LOOK_INTO_TURN := 0.55
## While the doors are open, follow views swing round to the front corner of the
## bus and close in on the doorway, so doors and passengers face the player.
const DOOR_ORBIT := 2.15
const DOOR_ORBIT_RATE := 2.2
const DOOR_ZOOM := 0.58
const HEIGHT_RATE := 5.0

@export var target_path: NodePath

var view_index: int = START_VIEW

var _bus: BusController
var _visual: BusVisual
var _follow_heading: float = 0.0
var _steer_angle: float = 0.0
var _door_amount: float = 0.0
var _door_orbit: float = 0.0
var _door_focus: float = 0.0
var _door_position: Vector3 = Vector3.ZERO
var _follow_height: float = 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	top_level = true
	_bus = get_node(target_path) as BusController
	_visual = _bus.get_node("Visual") as BusVisual
	_follow_heading = _bus.rotation.y
	GameEvents.camera_cycle_requested.connect(next_view)
	_follow_height = _bus.global_position.y
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.bus_relocate_requested.connect(_snap_to_bus.unbind(2))
	GameEvents.reset_requested.connect(_snap_to_bus.call_deferred)
	_announce_view.call_deferred() # After every listener in the scene is ready.


func _on_telemetry(data: BusTelemetry) -> void:
	_steer_angle = data.steer_angle
	_door_amount = 0.0 if data.doors_closed else 1.0
	_door_position = data.door_position


func _snap_to_bus() -> void:
	_follow_heading = _bus.rotation.y
	_follow_height = _bus.global_position.y


func next_view() -> void:
	view_index = (view_index + 1) % VIEWS.size()
	_follow_heading = _bus.rotation.y
	_announce_view()


func view_name() -> String:
	return VIEWS[view_index]["name"]


func _process(dt: float) -> void:
	var view: Dictionary = VIEWS[view_index]
	fov = view["fov"]
	if view["cockpit"]:
		_update_cockpit()
	else:
		_update_follow(view, dt)


func _update_cockpit() -> void:
	var anchor := _visual.cockpit_anchor.get_global_transform_interpolated()
	global_transform = anchor.rotated_local(Vector3.UP, -_steer_angle * COCKPIT_LOOK_INTO_TURN)
	rotate_object_local(Vector3.RIGHT, deg_to_rad(-6.0))


func _update_follow(view: Dictionary, dt: float) -> void:
	var bus_transform := _bus.get_global_transform_interpolated()
	var centre := bus_transform.origin + bus_transform.basis.z * _bus.spec.body_centre_z()
	var bus_heading := bus_transform.basis.get_euler().y
	var blend := 1.0 - exp(-float(view["heading_rate"]) * dt)
	_follow_heading = lerp_angle(_follow_heading, bus_heading, blend)
	_follow_height = lerpf(_follow_height, bus_transform.origin.y, 1.0 - exp(-HEIGHT_RATE * dt))
	var door_blend := 1.0 - exp(-DOOR_ORBIT_RATE * dt)
	_door_orbit = lerpf(_door_orbit, _door_amount * DOOR_ORBIT * float(_bus.spec.door_side), door_blend)
	_door_focus = lerpf(_door_focus, _door_amount, door_blend)
	centre.y = _follow_height
	if _door_focus > 0.001:
		centre = centre.lerp(Vector3(_door_position.x, _follow_height, _door_position.z), _door_focus)
	var orbit_heading := _follow_heading + _door_orbit
	var behind := Vector3(sin(orbit_heading), 0.0, cos(orbit_heading))
	var ahead := Vector3(sin(_follow_heading), 0.0, cos(_follow_heading)) * -float(view["look_ahead"]) * (1.0 - _door_focus)
	var zoom := lerpf(1.0, DOOR_ZOOM, _door_focus)
	global_position = centre + behind * float(view["distance"]) * zoom + Vector3.UP * float(view["height"]) * zoom
	look_at(centre + ahead + Vector3.UP * float(view["look_height"]), Vector3.UP)


func _announce_view() -> void:
	GameEvents.camera_view_changed.emit(view_name())
