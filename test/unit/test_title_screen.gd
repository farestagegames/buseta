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
