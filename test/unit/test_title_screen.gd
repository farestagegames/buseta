extends GutTest
## The title screen: the feature graphic, a prompt, and any input to start.

const TITLE := preload("res://scenes/main/title_screen.tscn")


func _title() -> Control:
	var title: Control = TITLE.instantiate()
	title.change_scene = false
	add_child_autofree(title)
	return title


func test_it_shows_the_feature_art_and_a_prompt() -> void:
	var title := _title()
	assert_not_null(title.art.texture)
	assert_eq(title.prompt.text, "Tap to start")
	assert_eq(TranslationServer.get_translation_object("es_CO").get_message("Tap to start"), &"Toca para empezar")


func test_wide_screens_crop_and_narrow_screens_show_all_of_the_art() -> void:
	var script: GDScript = load("res://scripts/ui/title_screen.gd")
	assert_eq(script.stretch_for(Vector2(2400, 1080)), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	assert_eq(script.stretch_for(Vector2(1440, 1080)), TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "The title is never cut off")


func test_a_tap_a_key_or_a_button_starts_once() -> void:
	for event: InputEvent in [_tap(), _key(), _button()]:
		var title := _title()
		watch_signals(title)
		title._input(event)
		title._input(event)
		assert_signal_emit_count(title, "started", 1, str(event))


func test_only_a_brand_new_player_goes_straight_to_the_tutorial() -> void:
	var script: GDScript = load("res://scripts/ui/title_screen.gd")
	var fresh := PlayerProfile.new()
	assert_true(script.goes_to_tutorial(fresh))
	var launched := PlayerProfile.new()
	launched.first_launch_done = true
	assert_false(script.goes_to_tutorial(launched), "Only the first launch")
	var tutored := PlayerProfile.new()
	tutored.intro_done = true
	assert_false(script.goes_to_tutorial(tutored))
	var played := PlayerProfile.new()
	played.xp = 40
	assert_false(script.goes_to_tutorial(played), "An older save with progress keeps the menu")


func test_the_first_launch_flag_is_saved() -> void:
	var profile := PlayerProfile.new()
	assert_false(PlayerProfile.from_dict(profile.to_dict()).first_launch_done)
	profile.first_launch_done = true
	assert_true(PlayerProfile.from_dict(profile.to_dict()).first_launch_done)


func test_the_first_tap_opens_the_tutorial_shift_then_the_menu() -> void:
	var kept := Profile.data
	Profile.data = PlayerProfile.new()
	var first := _title()
	first._input(_tap())
	assert_eq(first.next_scene, "res://scenes/main/city_shift.tscn")
	assert_true(Profile.data.first_launch_done)
	var second := _title()
	second._input(_tap())
	assert_eq(second.next_scene, "res://scenes/main/main_menu.tscn")
	Profile.data = kept
	Profile.save()


func test_the_game_opens_on_the_title_screen() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/main/title_screen.tscn")


func _tap() -> InputEvent:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	return event


func _key() -> InputEvent:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	return event


func _button() -> InputEvent:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event
