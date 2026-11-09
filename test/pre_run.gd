extends GutHookScript
## Runs before all tests: keeps them on a test save, in English, whatever the
## language of the machine running them, and in dry weather unless a test asks
## for rain.


func run() -> void:
	Profile.load_from("user://test_save_scene.json")
	# Every run starts from a fresh player, so a run that stopped part-way (with
	# another route chosen, say) cannot change the next one.
	Profile.data = PlayerProfile.new()
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.intro_done = true
	Profile.save()
	GameSettings.language = "en"
	CityShift.shift_seed = 7
	CityShift.forced_rain = WeatherPlan.FORCE_DRY
