extends GutTest
## The first time experience: opening scene, tutorial, and nothing counted against
## a new driver until it ends.

const CITY := preload("res://scenes/main/city_shift.tscn")

var scene: CityShift
var intro: IntroCutscene
var tutorial: TutorialDirector
var system: RouteSystem
var keeper: ScoreKeeper
var hud: DriveHud


func before_each() -> void:
	Profile.load_from("user://test_save_first.json")
	Profile.data = PlayerProfile.new()
	scene = CITY.instantiate()
	add_child_autofree(scene)
	intro = scene.get_node("Intro")
	tutorial = scene.get_node("Tutorial")
	system = scene.get_node("RouteSystem")
	keeper = scene.get_node("ScoreKeeper")
	hud = scene.get_node("Hud")
	await wait_frames(2)


func after_all() -> void:
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func test_new_driver_gets_the_opening_scene_with_the_hud_hidden() -> void:
	assert_true(intro.playing)
	assert_false(hud.visible)


func test_nothing_counts_during_the_opening() -> void:
	await wait_physics_frames(30)
	assert_eq(system.clock, 0.0)
	GameEvents.bus_collided.emit(5.0)
	GameEvents.red_light_run.emit()
	assert_eq(int(keeper.score.counts["collisions"]), 0)
	assert_eq(int(keeper.score.counts["red_lights"]), 0)


func test_skipping_the_opening_starts_the_tutorial() -> void:
	intro.skip()
	assert_true(hud.visible)
	assert_true(tutorial.active)
	assert_true(hud.tutorial_panel.visible)
	assert_true(hud.tutorial_panel.ring().has_area(), "The GO pedal should be ringed")


func test_finishing_the_tutorial_starts_the_clock_and_saves() -> void:
	intro.skip()
	tutorial.finish()
	assert_true(Profile.data.intro_done)
	await wait_physics_frames(10)
	assert_gt(system.clock, 0.0)
	assert_false(hud.tutorial_panel.visible)
	var saved := PlayerProfile.from_dict(SaveStore.read("user://test_save_first.json"))
	assert_true(saved.intro_done)


func test_returning_driver_sees_neither() -> void:
	Profile.data.intro_done = true
	var again: CityShift = CITY.instantiate()
	add_child_autofree(again)
	await wait_frames(2)
	assert_false((again.get_node("Intro") as IntroCutscene).playing)
	assert_false((again.get_node("Tutorial") as TutorialDirector).active)


func test_replaying_the_tutorial_from_settings_brings_it_back() -> void:
	Profile.data.intro_done = true
	Profile.reset_tutorial()
	assert_false(Profile.data.intro_done)


func test_tutorial_message_is_fully_on_screen() -> void:
	intro.skip()
	await wait_frames(3)
	var screen := get_viewport().get_visible_rect()
	var panel: Control = hud.tutorial_panel.get_child(0)
	assert_true(screen.encloses(panel.get_global_rect()), "Message must not run off the screen")
