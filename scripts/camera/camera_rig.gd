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

@export var target_path: NodePath

var view_index: int = START_VIEW

var _bus: BusController
var _visual: BusVisual
var _follow_heading: float = 0.0
var _steer_angle: float = 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	top_level = true
	_bus = get_node(target_path) as BusController
	_visual = _bus.get_node("Visual") as BusVisual
	_follow_heading = _bus.rotation.y
	GameEvents.camera_cycle_requested.connect(next_view)
	GameEvents.bus_telemetry_updated.connect(func(data: BusTelemetry) -> void: _steer_angle = data.steer_angle)
	GameEvents.reset_requested.connect(func() -> void: _follow_heading = _bus.rotation.y)
	_announce_view()


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
	var behind := Vector3(sin(_follow_heading), 0.0, cos(_follow_heading))
	global_position = centre + behind * float(view["distance"]) + Vector3.UP * float(view["height"])
	var look_at_point := centre - behind * float(view["look_ahead"]) + Vector3.UP * float(view["look_height"])
	look_at(look_at_point, Vector3.UP)


func _announce_view() -> void:
	GameEvents.camera_view_changed.emit(view_name())
