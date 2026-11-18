extends Node
## Developer tool: the menu stage on Home, the Rutas and Chofer trays and the
## Garage, at the window size given by --resolution. Saves PNGs to the folder in
## the SHOTS_DIR environment variable (default tools/screens/).


func _ready() -> void:
	await get_tree().process_frame
	Profile.load_from("user://stage_tray_shots_save.json")
	Profile.data = PlayerProfile.new()
	Profile.data.grant_free_items(Profile.catalog)
	Profile.data.intro_done = true
	Profile.data.coins = 471700
	Profile.data.xp = 2000
	GameSettings.language = "es_CO"
	var menu: MainMenu = load("res://scenes/main/main_menu.tscn").instantiate()
	add_child(menu)
	await _frames(15)
	await _shot("home")
	menu.show_tab(1, true)
	await _frames(40)
	await _shot("rutas_tray")
	menu.show_tab(MainMenu.DRIVERS_TAB, true)
	await _frames(40)
	await _shot("chofer_tray")
	menu.show_tab(MainMenu.GARAGE_TAB)
	await _frames(40)
	await _shot("garage")
	menu.show_tab(0)
	await _frames(40)
	await _shot("home_again")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("SHOTS_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("res://tools/screens")
	var size := get_viewport().get_visible_rect().size
	var path := "%s/%s_%dx%d.png" % [dir, name, int(size.x), int(size.y)]
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved: ", path)
