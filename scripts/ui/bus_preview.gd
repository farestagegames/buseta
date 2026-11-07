class_name BusPreview
extends PreviewStage
## A slowly turning 3D bus in the player's chosen bus and livery.


func _ready() -> void:
	build_stage(Vector3(0.0, 4.4, 15.5), -10.0, 42.0)
	var spec := CityShift.chosen_spec()
	var visual := BusVisual.new()
	visual.spec = spec
	visual.driver_look = CityShift.chosen_look()
	visual.position.z = -spec.body_centre_z()
	pivot.add_child(visual)
