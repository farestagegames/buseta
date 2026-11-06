class_name GraphicsDirector
extends Node
## Applies the graphics level to the scene, and again if the player changes it.

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var camera_path: NodePath

var _applied: int = -99


func _ready() -> void:
	GameSettings.changed.connect(apply)
	apply()


func apply() -> void:
	if GameSettings.graphics_quality == _applied:
		return
	_applied = GameSettings.graphics_quality
	var profile := GraphicsQuality.current_profile()
	var viewport := get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = profile["render_scale"]
	viewport.msaa_3d = profile["msaa"]
	var sun: DirectionalLight3D = get_node(sun_path)
	sun.shadow_enabled = profile["shadows"]
	sun.directional_shadow_max_distance = profile["shadow_distance"]
	RenderingServer.directional_shadow_atlas_set_size(profile["shadow_size"], false)
	RenderingServer.directional_soft_shadow_filter_set_quality(profile["soft_shadows"])
	var environment: WorldEnvironment = get_node(environment_path)
	environment.environment.fog_density = profile["fog_density"]
	var camera: Camera3D = get_node(camera_path)
	camera.far = profile["view_distance"]
