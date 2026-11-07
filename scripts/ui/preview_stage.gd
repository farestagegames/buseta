class_name PreviewStage
extends SubViewportContainer
## A small lit 3D stage for the menus, with something turning slowly on it.

const SPIN_SPEED := 0.45

var pivot: Node3D
var stage: SubViewport


## Called by each kind of preview from its _ready.
func build_stage(camera_position: Vector3, camera_tilt: float, camera_fov: float) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = SubViewport.new()
	stage.own_world_3d = true
	stage.transparent_bg = true
	stage.msaa_3d = Viewport.MSAA_2X
	stage.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(stage)
	pivot = Node3D.new()
	pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	pivot.rotation.y = deg_to_rad(35.0)
	stage.add_child(pivot)
	var camera := Camera3D.new()
	camera.position = camera_position
	camera.rotation.x = deg_to_rad(camera_tilt)
	camera.fov = camera_fov
	stage.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 1.0
	stage.add_child(sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.82, 0.86)
	environment.ambient_light_energy = 0.75
	world.environment = environment
	stage.add_child(world)


func _process(dt: float) -> void:
	pivot.rotate_y(SPIN_SPEED * dt)
