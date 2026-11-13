extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	Profile.load_from("user://driver_shots_save.json")
	Profile.data = PlayerProfile.new()
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.intro_done = true
	GameSettings.language = "es_CO"

	var angles := [
		{"name": "drivers_tab_angle_left", "angle": deg_to_rad(-25.0)},
		{"name": "drivers_tab_angle_center", "angle": 0.0},
		{"name": "drivers_tab_angle_right", "angle": deg_to_rad(25.0)},
	]

	for shot in angles:
		var vp := SubViewport.new()
		vp.size = Vector2i(1280, 720)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var menu: MainMenu = load("res://scenes/main/main_menu.tscn").instantiate()
		vp.add_child(menu)
		menu.show_tab(MainMenu.DRIVERS_TAB)
		var driver_item: Dictionary = Profile.catalog.find(Catalog.DRIVERS, "ruben_cardona")
		menu.try_on_driver(driver_item)
		var preview: DriverPreview = menu.get("_drivers_preview")
		if preview != null:
			preview.set_process(false)
			preview.pivot.rotation.y = shot["angle"]
		for f in 15:
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
