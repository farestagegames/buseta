class_name DriverPreview
extends PreviewStage
## A slowly turning head and shoulders of one driver.

var _figure: MeshInstance3D


func _ready() -> void:
	build_stage(Vector3(0.0, 0.2, 2.9), 0.0, 30.0)
	_figure = MeshInstance3D.new()
	_figure.rotation.y = PI # Figures face -Z, and the camera is on the +Z side.
	pivot.add_child(_figure)
	show_look(CityShift.chosen_look())


func show_look(look: DriverLook) -> void:
	_figure.mesh = DriverFigure.build_bust(look)


## Only ever turns a little, as nobody needs to see the back of a head.
func _process(_dt: float) -> void:
	pivot.rotation.y = sin(Time.get_ticks_msec() / 1400.0) * 0.5
