extends GutTest
## The "unlocked" cards after a shift: what a level-up or a finished route opened.


func _catalog() -> Catalog:
	return Catalog.new({
		"routes": [
			{"id": "first", "name": "First"},
			{"id": "second", "name": "Second", "requires": "first"},
			{"id": "hills", "name": "Hills", "level": 3},
		],
		"buses": [
			{"id": "small", "name": "Small", "description": "Short and nimble"},
			{"id": "big", "name": "Big", "level": 3, "description": "Long and slow"},
		],
		"liveries": [
			{"id": "red", "name": "Red"},
			{"id": "blue", "name": "Blue", "level": 2},
			{"id": "gold", "name": "Gold", "level": 4},
		],
		"drivers": [{"id": "ana", "name": "Ana", "level": 2}],
		"decorations": [{"id": "dog", "name": "Dog", "level": 3}],
	})


func _ids(cards: Array[Dictionary]) -> Array:
	return cards.map(func(card: Dictionary) -> String: return "%s/%s" % [card["kind"], card["id"]])


func test_no_level_up_and_no_route_shows_nothing() -> void:
	assert_eq(UnlockNews.between(_catalog(), [], 2, 2, []).size(), 0)


func test_one_level_up_shows_what_that_level_opens() -> void:
	var cards := UnlockNews.between(_catalog(), [], 1, 2, [])
	assert_eq(_ids(cards), ["liveries/blue", "drivers/ana"])


func test_two_levels_at_once_show_both_and_nothing_beyond() -> void:
	var horns := [{"id": "air", "name": "Air horn", "level": 3}, {"id": "loud", "name": "Loud", "level": 5}]
	var cards := UnlockNews.between(_catalog(), horns, 1, 3, [])
	assert_eq(_ids(cards), ["routes/hills", "buses/big", "liveries/blue", "decorations/dog", "drivers/ana", "horns/air"])


func test_items_with_no_level_are_never_news() -> void:
	var cards := UnlockNews.between(_catalog(), [], 1, 9, [])
	assert_false(_ids(cards).has("liveries/red"))
	assert_false(_ids(cards).has("buses/small"))


func test_a_finished_route_opens_the_next_one_first() -> void:
	var second := _catalog().find(Catalog.ROUTES, "second")
	var cards := UnlockNews.between(_catalog(), [], 2, 3, [second])
	assert_eq(_ids(cards)[0], "routes/second")
	assert_eq(cards[0]["level"], 0, "Opened by a route, not a level")


func test_a_route_opened_both_ways_shows_once() -> void:
	var hills := _catalog().find(Catalog.ROUTES, "hills")
	var cards := UnlockNews.between(_catalog(), [], 2, 3, [hills])
	assert_eq(_ids(cards).count("routes/hills"), 1)


func test_cards_carry_a_name_and_a_line_of_description() -> void:
	var cards := UnlockNews.between(_catalog(), [], 2, 3, [])
	var bus: Dictionary = cards.filter(func(card: Dictionary) -> bool: return card["kind"] == Catalog.BUSES)[0]
	assert_eq(bus["name"], "Big")
	assert_eq(bus["description"], "Long and slow", "An item's own description")
	assert_eq(bus["level"], 3)
	var dog: Dictionary = cards.filter(func(card: Dictionary) -> bool: return card["id"] == "dog")[0]
	assert_eq(dog["description"], UnlockNews.BLURBS[Catalog.DECORATIONS], "Otherwise a line for its kind")


func test_reads_the_levels_from_a_shifts_rewards() -> void:
	var rewards := {"xp_before": DriverLevel.xp_for_level(2) - 1, "xp_after": DriverLevel.xp_for_level(2), "unlocked_routes": []}
	assert_eq(_ids(UnlockNews.from_rewards(_catalog(), [], rewards)), ["liveries/blue", "drivers/ana"])


func test_every_blurb_has_a_translation() -> void:
	var spanish: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/packs/colombia/lang/es_CO.json"))
	for blurb: String in UnlockNews.BLURBS.values():
		assert_true(spanish.has(blurb), blurb)
	for text: String in ["Unlocked!", "Collect"]:
		assert_true(spanish.has(text), text)


func test_the_menu_shows_each_card_until_collected() -> void:
	var cards := UnlockNews.between(Profile.catalog, Country.pack.horns(), 2, 3, [])
	assert_gt(cards.size(), 1, "Level 3 opens more than one thing")
	Profile.pending_unlocks = cards.duplicate()
	MainMenu.unlock_cards = true
	var menu: MainMenu = load("res://scenes/main/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(3)
	MainMenu.unlock_cards = false
	var popup: MenuUnlockPopup = menu.find_child("UnlockPopup", false, false)
	assert_not_null(popup)
	assert_eq(popup.name_label.text, tr(cards[0]["name"]))
	assert_gte(popup.collect_button.custom_minimum_size.y, 48.0, "A thumb-sized button")
	popup.collect_button.pressed.emit()
	await wait_frames(3)
	assert_eq(Profile.pending_unlocks.size(), cards.size() - 1)
	var next: MenuUnlockPopup = menu.find_child("UnlockPopup", false, false)
	assert_not_null(next, "The next card follows")
	assert_ne(next, popup)
	Profile.pending_unlocks.clear()
