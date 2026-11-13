extends Node

const SCENE := "res://scenes/main/city_shift.tscn"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	Profile.load_from("user://dawn_shots_save.json")
	Profile.data = PlayerProfile.new()
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.intro_done = true
	Profile.data.xp = DriverLevel.xp_for_level(6)
	if not (Profile.data.owned[Catalog.ROUTES] as Array).has("route_01"):
		(Profile.data.owned[Catalog.ROUTES] as Array).append("route_01")
	if not (Profile.data.owned[Catalog.ROUTES] as Array).has("cafeto_c0"):
		(Profile.data.owned[Catalog.ROUTES] as Array).append("cafeto_c0")

	var shots := [
		{"name": "dawn_puerto_marisol", "route": "route_01"},
		{"name": "dawn_alto_cafeto", "route": "cafeto_c0"},
	]

	for shot: Dictionary in shots:
		Profile.data.select(Catalog.ROUTES, shot["route"])
		CityShift.forced_time = "madrugada"
		CityShift.forced_rain = WeatherPlan.FORCE_DRY
		CityShift.shift_seed = 7
		var scene: CityShift = load(SCENE).instantiate()
		add_child(scene)
		for f in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var out_path := ProjectSettings.globalize_path("res://tools/screens/%s.png" % shot["name"])
		if img != null and not img.is_empty():
			img.save_png(out_path)
			print("Saved: ", out_path, " size=", img.get_size())
		else:
			print("Image empty for ", shot["name"])
		scene.queue_free()
		for f in 5:
			await get_tree().process_frame

	get_tree().quit()
