extends GutTest
## Home after a shift (17 Nov, owner's phone: the stage behind Home came up black
## after pressing Menú on the shift report). The drive scales the window's 3D and
## turns its MSAA off; Home puts both back and keeps the stage drawing, also under
## the Unlocked cards a shift leaves.

var _scale: float
var _mode: Viewport.Scaling3DMode
var _msaa: Viewport.MSAA


func before_each() -> void:
	var root := get_tree().root
	_scale = root.scaling_3d_scale
	_mode = root.scaling_3d_mode
	_msaa = root.msaa_3d


func after_each() -> void:
	var root := get_tree().root
	root.scaling_3d_scale = _scale
	root.scaling_3d_mode = _mode
	root.msaa_3d = _msaa
	Profile.pending_unlocks.clear()
	MainMenu.unlock_cards = false


func test_restore_viewport_puts_back_the_project_settings() -> void:
	var viewport := SubViewport.new()
	add_child_autofree(viewport)
	viewport.scaling_3d_scale = 0.75
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	GraphicsDirector.restore_viewport(viewport)
	assert_eq(viewport.scaling_3d_scale, float(ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0)))
	assert_eq(viewport.msaa_3d, int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0)))
	assert_eq(viewport.msaa_3d, Viewport.MSAA_2X, "The project asks for 2x MSAA")


func test_home_after_a_low_quality_shift_draws_the_stage_under_the_unlocked_card() -> void:
	# What a Low-quality drive leaves on the window.
	var root := get_tree().root
	root.scaling_3d_scale = GraphicsQuality.PROFILES[GraphicsQuality.Level.LOW]["render_scale"]
	root.msaa_3d = Viewport.MSAA_DISABLED
	Profile.pending_unlocks = UnlockNews.between(Profile.catalog, Country.pack.horns(), 2, 3, [])
	MainMenu.unlock_cards = true
	var menu: MainMenu = load("res://scenes/main/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(3)
	assert_eq(root.scaling_3d_scale, 1.0, "Home renders the window's 3D whole")
	assert_eq(root.msaa_3d, Viewport.MSAA_2X)
	assert_not_null(menu.find_child("UnlockPopup", false, false), "The Unlocked card shows")
	var stage: TurntableStage = menu.find_child("BusStage", false, false)
	assert_false(stage.paused, "The stage runs on Home")
	assert_true(stage.is_processing())
	assert_eq(stage.stage.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "And draws every frame")


func test_back_to_home_from_a_sheet_tab_draws_the_stage_again() -> void:
	var menu: MainMenu = load("res://scenes/main/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	var stage: TurntableStage = menu.find_child("BusStage", false, false)
	menu.show_tab(4)
	assert_true(stage.paused, "Behind a full sheet the stage rests")
	assert_eq(stage.stage.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	menu.show_tab(0)
	assert_false(stage.paused)
	assert_eq(stage.stage.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
