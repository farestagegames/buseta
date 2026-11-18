extends GutTest
## Unit tests for MenuBusCard and MenuHomeDrawer.

var profile: PlayerProfile
var catalog: Catalog

func before_each() -> void:
	# Create a minimal profile and catalog for testing
	catalog = Catalog.new(MapLoader.read_json(Country.pack.content_path("catalog")))
	profile = PlayerProfile.new()
	profile.grant_free_items(catalog)
	profile.repair_choices(catalog)

func test_menu_bus_card_show_bus_sets_labels_and_bars() -> void:
	var card := MenuBusCard.new()
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child_autofree(card)
	card.size = Vector2(320, 240)

	var dots := [Color.RED, Color.BLUE, Color.GREEN]
	card.show_bus("Caimán B8", "Buseta", [0.5, 0.75, 0.3, 0.9], dots, 1)

	await get_tree().process_frame

	assert_eq(card.name_label.text, "CAIMÁN B8")
	assert_eq(card.tag_label.text, "BUSETA")

	# Check stat bar values via meta
	for i in 4:
		var bar := card.find_child("StatBar%d" % i, true, false)
		assert_true(bar != null, "StatBar%d should exist" % i)
		var value: float = bar.get_meta("value")
		assert_true(value >= 0.0 && value <= 1.0, "StatBar%d value %f not in 0..1" % [i, value])

	# Check livery dots created (3 dots, middle one chosen)
	var drawn := card.find_children("*", "Control", true, false).filter(func(node: Node) -> bool: return node.get_script() != null and node.get("chosen") != null)
	assert_eq(drawn.size(), 3, "One dot per livery")

func test_menu_bus_card_stats_for_returns_four_values_in_range() -> void:
	for bus_item: Dictionary in Profile.catalog.items(Catalog.BUSES):
		if bus_item.get("route_only", false):
			continue
		var spec: BusSpec = CityShift.spec_for(bus_item, Profile.selected_item(Catalog.LIVERIES))
		var stats := MenuBusCard.stats_for(spec)
		assert_eq(stats.size(), 4, "Bus %s should have 4 stats" % bus_item["name"])
		for i in 4:
			assert_true(stats[i] >= 0.0 && stats[i] <= 1.0,
				"Bus %s stat %d = %f not in 0..1" % [bus_item["name"], i, stats[i]])

func test_menu_home_drawer_add_arcade_keeps_button_findable() -> void:
	var drawer := MenuHomeDrawer.new()
	drawer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child_autofree(drawer)
	drawer.size = Vector2(300, 400)

	# Create a mock arcade button like main_menu.gd does
	var button := Button.new()
	button.name = "ArcadeButton"
	button.text = "Carrera Express"
	var badge := Label.new()
	badge.name = "NewBadge"
	badge.text = "New!"
	button.add_child(badge)

	drawer.add_arcade(button)

	await get_tree().process_frame

	var found := drawer.find_child("ArcadeButton", true, false)
	assert_true(found != null, "ArcadeButton should be findable after add_arcade")
	assert_true(found == button, "Should be the same button instance")
	assert_true(found.find_child("NewBadge", true, false) != null, "NewBadge child should be preserved")

func test_menu_home_drawer_set_daily_sets_texts() -> void:
	var drawer := MenuHomeDrawer.new()
	drawer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child_autofree(drawer)
	drawer.size = Vector2(300, 400)

	drawer.set_daily("Daily challenge", "Drive 50 passengers", "Reward: $500", false)
	await get_tree().process_frame

	assert_eq(drawer.daily_text.text, "Drive 50 passengers")
	var daily_card := drawer.find_child("DailyCard", true, false)
	assert_true(daily_card != null)
	var detail_label: Label = daily_card.get_meta("detail_label")
	assert_eq(detail_label.text, "Reward: $500")
	assert_eq(detail_label.get_theme_color("font_color"), MenuHomeDrawer.MUTED)

	drawer.set_daily("Daily challenge", "Drive 50 passengers", "Done today", true)
	await get_tree().process_frame
	assert_eq(detail_label.get_theme_color("font_color"), MenuHomeDrawer.GOOD)

func test_menu_home_drawer_set_next_unlock_sets_text() -> void:
	var drawer := MenuHomeDrawer.new()
	drawer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child_autofree(drawer)
	drawer.size = Vector2(300, 400)

	drawer.set_next_unlock("Caimán B10: $1,500 more")
	await get_tree().process_frame

	assert_eq(drawer.next_text.text, "Caimán B10: $1,500 more")

	var next_card := drawer.find_child("NextUnlockCard", true, false)
	assert_true(next_card != null)

func test_menu_home_drawer_arcade_button_min_height() -> void:
	var drawer := MenuHomeDrawer.new()
	drawer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child_autofree(drawer)
	drawer.size = Vector2(300, 400)

	var button := Button.new()
	button.name = "ArcadeButton"
	button.text = "Carrera Express"

	drawer.add_arcade(button)
	await get_tree().process_frame

	assert_true(button.custom_minimum_size.y >= 48,
		"ArcadeButton min height %d should be >= 48" % button.custom_minimum_size.y)

func test_quick_tray_window_keeps_order_the_chosen_one_and_at_most_four() -> void:
	assert_eq(MenuQuickTray.window(["a", "b"], "b"), ["a", "b"])
	assert_eq(MenuQuickTray.window(["a", "b", "c", "d", "e", "f"], "b"), ["a", "b", "c", "d"])
	assert_eq(MenuQuickTray.window(["a", "b", "c", "d", "e", "f"], "e"), ["b", "c", "d", "e"])
	assert_eq(MenuQuickTray.window(["a", "b", "c", "d", "e"], "missing"), ["a", "b", "c", "d"])


func test_quick_tray_cards_emit_their_id_and_the_more_card() -> void:
	var tray := MenuQuickTray.new()
	add_child_autofree(tray)
	var card := tray.add_pick("x", "Ruta X", "Nueva", MenuIcon.new(), true)
	var more := tray.add_more("Todas", "routes")
	watch_signals(tray)
	card.pressed.emit()
	more.pressed.emit()
	assert_signal_emitted_with_parameters(tray, "picked", ["x"])
	assert_signal_emitted(tray, "more_pressed")
	assert_gte(card.custom_minimum_size.y, 48.0, "a thumb-sized card")
	var step := tray.add_step(1)
	step.pressed.emit()
	assert_signal_emitted_with_parameters(tray, "stepped", [1])


func test_the_tab_bar_blank_matches_turno_or_shrinks_to_fit() -> void:
	assert_eq(MainMenu.centred_ghost_width(1500.0, 600.0, 300.0, 64.0), 300.0)
	assert_eq(MainMenu.centred_ghost_width(1236.0, 640.0, 300.0, 64.0), 232.0)
	assert_eq(MainMenu.centred_ghost_width(900.0, 640.0, 300.0, 64.0), 0.0)
