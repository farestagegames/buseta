extends GutTest
## Tester Claudio, 17 Nov: less text on the full menu pages, one spacing for the
## whole menu, and the Home bus in the middle of the screen.

const MENU := preload("res://scenes/main/main_menu.tscn")


func before_each() -> void:
	Profile.load_from("user://test_save_menu.json")
	Profile.data = PlayerProfile.new()
	Profile.data.intro_done = true


func after_all() -> void:
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func _labels(root: Node) -> Array[String]:
	var found: Array[String] = []
	for node in root.find_children("*", "Label", true, false):
		found.append((node as Label).text)
	return found


func test_home_camera_looks_straight_at_the_bus() -> void:
	var home: Dictionary = TurntableStage.PRESETS["home"]
	assert_eq((home["position"] as Vector3).x, 0.0, "the camera stands on the island's axis")
	assert_eq((home["rotation"] as Vector3).y, 0.0, "and does not turn aside")
	assert_eq(home.get("offset", Vector2.ZERO), Vector2.ZERO, "and does not shift the picture sideways")


func test_cards_sheets_and_lists_share_one_spacing() -> void:
	assert_eq(MenuCartoon.card_box().content_margin_left, float(MenuHomeDrawer.PAD))
	assert_eq(MenuCartoon.sheet_box().content_margin_top, float(MenuHomeDrawer.PAD))
	assert_eq(MenuHomeDrawer.card_box().content_margin_bottom, float(MenuHomeDrawer.PAD))
	assert_eq(MainMenu.sheet_box().content_margin_right, float(MenuHomeDrawer.PAD))
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(4)
	var list := TouchScroll.first_in(menu._content)
	assert_eq(list.get_child(0).get_theme_constant("separation"), MenuHomeDrawer.GAP)
	var drawer := menu.find_child("HomeDrawer", true, false)
	assert_null(drawer, "Home's cards go with Home")
	menu.show_tab(0)
	drawer = menu.find_child("HomeDrawer", true, false) as Control
	assert_eq(drawer.offset_right, -(MainMenu.ARROW_WIDTH + MenuHomeDrawer.GAP), "one gap from the arrow")


func test_full_pages_keep_names_and_goals_but_drop_descriptions() -> void:
	var menu: MainMenu = MENU.instantiate()
	add_child_autofree(menu)
	menu.show_tab(1)
	var shown := _labels(menu._content)
	var route := Profile.selected_item(Catalog.ROUTES)
	assert_has(shown, str(route["name"]), "route names stay")
	if route.has("description"):
		assert_does_not_have(shown, str(route["description"]), "route descriptions go")
	menu.show_tab(MainMenu.DRIVERS_TAB)
	shown = _labels(menu._content)
	for item: Dictionary in Profile.catalog.items(Catalog.DRIVERS):
		assert_does_not_have(shown, str(item["bio"]), "a driver's bio is on the quick tray's side card, not the list")
	menu.show_tab(MainMenu.GARAGE_TAB)
	shown = _labels(menu._content)
	assert_does_not_have(shown, "Each bus sounds the horn it came with")
	assert_has(shown, "The bus's own horn")
