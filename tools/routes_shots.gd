extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	Profile.load_from("user://routes_shots_save.json")
	Profile.data = PlayerProfile.new()
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.intro_done = true
	Profile.data.coins = 5000
	Profile.data.xp = 500 # Driver Level 3, so Alto Cafeto (needs level 6) is locked!
	GameSettings.language = "es_CO"

	var shots := [
		{"name": "routes_phone_1280_puerto", "size": Vector2i(1280, 720), "town": "Puerto Marisol"},
		{"name": "routes_phone_1280_cafeto", "size": Vector2i(1280, 720), "town": "Alto Cafeto"},
		{"name": "routes_phone_1560_puerto", "size": Vector2i(1560, 720), "town": "Puerto Marisol"},
		{"name": "routes_phone_1560_cafeto", "size": Vector2i(1560, 720), "town": "Alto Cafeto"},
		{"name": "routes_desktop_1600_puerto", "size": Vector2i(1600, 900), "town": "Puerto Marisol"},
		{"name": "routes_desktop_1600_cafeto", "size": Vector2i(1600, 900), "town": "Alto Cafeto"},
	]

	for shot in shots:
		Profile.choose_town(shot["town"])
		var vp := SubViewport.new()
		vp.size = shot["size"]
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var menu: MainMenu = load("res://scenes/main/main_menu.tscn").instantiate()
		vp.add_child(menu)
		menu.show_tab(1)
		for f in 10:
			await get_tree().process_frame
		var img := vp.get_texture().get_image()
		var out_path := ProjectSettings.globalize_path("res://tools/screens/%s.png" % shot["name"])
		if img != null and not img.is_empty():
			img.save_png(out_path)
			print("Saved: ", out_path, " size=", img.get_size(), " format=", img.get_format())
		else:
			print("Image empty for ", shot["name"])
		vp.queue_free()
		for f in 3:
			await get_tree().process_frame

	get_tree().quit()
