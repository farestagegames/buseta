class_name BusPreview
extends PreviewStage
## A slowly turning 3D bus. It starts as the player's own, and the garage can show
## any bus and livery on it before they are bought.

var _visual: BusVisual
var _camera_distance: float = 15.5


func _ready() -> void:
	build_stage(Vector3(0.0, 4.4, _camera_distance), -10.0, 42.0)
	show_spec(CityShift.chosen_spec(), CityShift.chosen_decoration())


func show_spec(spec: BusSpec, decoration: Dictionary = {}) -> void:
	if _visual != null:
		_visual.free()
	_visual = BusVisual.new()
	_visual.spec = spec
	_visual.driver_look = CityShift.chosen_look()
	_visual.decoration = decoration
	_visual.position.z = spec.front_overhang + spec.wheelbase - spec.full_length() / 2.0
	pivot.add_child(_visual)
	stage.get_camera_3d().position.z = _camera_distance * clampf(spec.full_length() / 12.0, 0.8, 1.6)


func shown_spec() -> BusSpec:
	return _visual.spec


func shown_decoration() -> Dictionary:
	return _visual.decoration if _visual != null else {}
