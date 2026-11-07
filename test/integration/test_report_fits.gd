extends GutTest
## The end of shift report must always show its buttons. It has to fit a 16:9
## phone in every language, with the longest report a shift can produce.

const LANGUAGES: Array[String] = ["en", "es_CO"]

var hud: DriveHud


## A viewport of its own, because a phone screen is shorter than the test window.
func before_each() -> void:
	Profile.load_from("user://test_save_report.json")
	Profile.data = PlayerProfile.new()
	Profile.data.intro_done = true
	var screen := SubViewport.new()
	screen.size = Vector2i(1280, 720)
	add_child_autofree(screen)
	hud = DriveHud.new()
	screen.add_child(hud)
	await wait_frames(2)


func after_each() -> void:
	GameSettings.language = "en"


func after_all() -> void:
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func _worst_report() -> Dictionary:
	var notes: Array[String] = []
	for line: String in ["%d passengers carried", "%d collisions", "%d red lights", "%d objects hit",
			"%d emergency stops", "%d hard bumps", "%d kerb strikes", "%d turns not signalled",
			"%d stops missed", "%d people left waiting"]:
		notes.append(tr(line) % 12)
	notes.append(tr("%d s speeding") % 40)
	notes.append(tr("%d s off road") % 40)
	return {
		"stars": 3, "time": 589.0, "score": 72, "coins": 412,
		"categories": {"punctuality": 80.0, "accuracy": 70.0, "smoothness": 60.0, "rules": 50.0, "satisfaction": 90.0},
		"details": ", ".join(notes), "tip": tr(ScoreKeeper.TIPS["satisfaction"]),
		"rewards": {"xp": 130, "coins": 412, "levelled_up": true, "level": 7, "new_best": true, "daily_coins": 200,
			"achievements": [{"name": "First Day"}, {"name": "Five Star Service"}, {"name": "Not a Scratch"}, {"name": "Smooth Operator"}]},
	}


func _assert_on_screen(button: Button, label: String) -> void:
	var screen := Rect2(Vector2.ZERO, hud.shift_panel.get_viewport_rect().size)
	var rect := button.get_global_rect()
	assert_true(button.is_visible_in_tree(), "%s must be visible" % label)
	assert_true(screen.encloses(rect), "%s must be on screen: %s in %s" % [label, rect, screen])


func test_buttons_fit_in_every_language_with_the_longest_report() -> void:
	for language in LANGUAGES:
		GameSettings.language = language
		await wait_frames(1)
		hud.shift_panel.show_report(_worst_report())
		await wait_frames(3)
		_assert_on_screen(hud.shift_panel.menu_button, "Main menu in %s" % language)
		_assert_on_screen(hud.shift_panel.again_button, "Drive again in %s" % language)


func test_buttons_fit_with_the_double_coins_offer() -> void:
	var ads := RewardedOffer.new()
	Profile.ads = ads
	hud.shift_panel.show_report(_worst_report())
	await wait_frames(3)
	_assert_on_screen(hud.shift_panel.menu_button, "Main menu")
	_assert_on_screen(hud.shift_panel.double_coins_button, "Double coins")
	Profile.ads = AdProvider.new()


class RewardedOffer:
	extends AdProvider

	func is_available() -> bool:
		return true
