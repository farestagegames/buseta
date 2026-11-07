extends GutHookScript
## Runs before all tests: keeps them on a test save, in English, whatever the
## language of the machine running them.


func run() -> void:
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true
	GameSettings.language = "en"
	CityShift.shift_seed = 7
