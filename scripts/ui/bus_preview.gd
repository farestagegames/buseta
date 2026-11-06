class_name BusPreview
extends SubViewportContainer
## A slowly turning 3D bus in the player's chosen bus and livery.

const SPIN_SPEED := 0.45

var _pivot: Node3D


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)

	var spec := CityShift.chosen_spec()
	_pivot = Node3D.new()
	_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	viewport.add_child(_pivot)
	var visual := BusVisual.new()
	visual.spec = spec
	visual.position.z = -spec.body_centre_z()
	_pivot.add_child(visual)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 4.4, 15.5)
	camera.rotation.x = deg_to_rad(-10.0)
	camera.fov = 42.0
	viewport.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 1.0
	viewport.add_child(sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.82, 0.86)
	environment.ambient_light_energy = 0.75
	world.environment = environment
	viewport.add_child(world)
	_pivot.rotation.y = deg_to_rad(35.0)


func _process(dt: float) -> void:
	_pivot.rotate_y(SPIN_SPEED * dt)
