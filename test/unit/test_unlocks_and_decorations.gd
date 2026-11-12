extends GutTest

const CITY := preload("res://scenes/main/city_shift.tscn")


func before_each() -> void:
	Profile.load_from("user://test_save_unlocks.json")
	Profile.data = PlayerProfile.new()
	Profile.data.intro_done = true
	Country.use_pack("res://data/packs/colombia/pack.json")


func after_all() -> void:
	Country.use_pack("res://data/packs/colombia/pack.json")
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func _starter_report(score: int = 98, stars: int = 3, coins: int = 450) -> Dictionary:
	return {
		"score": score, "stars": stars, "coins": coins, "carried": 3, "served": 3,
		"perfect_stops": 3, "fares": 9, "time": 240.0, "completed": true,
		"counts": {"collisions": 0, "harsh_brakes": 0, "kerbs": 0, "indicators": 0, "red_lights": 0,
			"knocked": 0, "jolts": 0, "perfect_stops": 3, "missed_stops": 0, "vendors": 0,
			"downpours": 0, "clean_downpours": 0, "fines": 0, "dodgers": 0},
		"categories": {"satisfaction": 98.0}, "fined_coins": 0,
	}


func test_decoration_items_load_and_can_be_bought() -> void:
	var items := Profile.catalog.items(Catalog.DECORATIONS)
	assert_gte(items.size(), 6)
	assert_lte(items.size(), 8)
	for item: Dictionary in items:
		assert_true(item.has("id"))
		assert_true(item.has("name"))
		assert_true(item.has("kind"))
	var first_buyable: Dictionary = {}
	for item: Dictionary in items:
		if int(item.get("cost", 0)) > 0:
			first_buyable = item
			break
	assert_false(first_buyable.is_empty())
	Profile.data.coins = int(first_buyable["cost"])
	assert_true(Profile.buy(Catalog.DECORATIONS, first_buyable["id"]))
	assert_true(Profile.data.owns(Catalog.DECORATIONS, first_buyable["id"]))
	assert_eq(Profile.data.coins, 0)


func test_cockpit_shows_the_equipped_decoration() -> void:
	var deco := Profile.catalog.find(Catalog.DECORATIONS, "charm_palma")
	assert_false(deco.is_empty())
	Profile.data.coins = 500
	Profile.buy(Catalog.DECORATIONS, "charm_palma")
	Profile.select(Catalog.DECORATIONS, "charm_palma")
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	await wait_physics_frames(2)
	var visual: BusVisual = city.get_node("Bus/Visual")
	assert_true(visual.shows_decoration("charm_palma"))
	assert_not_null(visual.decoration_mesh())


func test_cockpit_shows_seat_cover_decoration() -> void:
	Profile.select(Catalog.DECORATIONS, "seat_sky")
	var city: CityShift = CITY.instantiate()
	add_child_autofree(city)
	await wait_physics_frames(2)
	var visual: BusVisual = city.get_node("Bus/Visual")
	assert_true(visual.shows_decoration("seat_sky"))
	assert_eq(str(visual.decoration.get("kind", "")), "seat_cover")


func test_next_unlock_picks_the_cheapest_reachable_item() -> void:
	Profile.data.coins = 0
	var next := Profile.next_unlock()
	assert_false(next.is_empty(), "There should be something to unlock")
	# Among reachable unowned items, no other has lower cost.
	var best_cost := int(next["cost"])
	for kind: String in [Catalog.ROUTES, Catalog.BUSES, Catalog.LIVERIES, Catalog.DRIVERS, Catalog.DECORATIONS]:
		for item: Dictionary in Profile.catalog.items(kind):
			if item.get("route_only", false) or Profile.data.owns(kind, item["id"]):
				continue
			if kind == Catalog.ROUTES and not Profile.catalog.requirement_met(item, Profile.data):
				continue
			assert_lte(best_cost, int(item.get("cost", 0)), "Cheapest reachable: %s" % item.get("id", ""))
	for item: Dictionary in Country.pack.horns():
		if Profile.data.owns_horn(item["id"]):
			continue
		assert_lte(best_cost, int(item.get("cost", 0)))


func test_ten_starter_level_shifts_unlock_at_least_five_items() -> void:
	var owned_before := _count_owned()
	var day := "2026-11-01"
	for i in 10:
		ShiftRewards.apply(Profile.data, _starter_report(), "starter_a", day, [], [], "buseta_8")
		Profile.data.complete_route("starter_a", Profile.catalog)
		Profile.data.complete_route("starter_b", Profile.catalog)
		Profile.data.grant_free_items(Profile.catalog)
		# Buy everything currently affordable and unlocked.
		var bought := true
		while bought:
			bought = false
			for kind: String in [Catalog.LIVERIES, Catalog.BUSES, Catalog.DRIVERS, Catalog.DECORATIONS]:
				for item: Dictionary in Profile.catalog.items(kind):
					if Profile.data.owns(kind, item["id"]):
						continue
					if Profile.buy(kind, item["id"]):
						bought = true
			for item: Dictionary in Country.pack.horns():
				if Profile.data.owns_horn(item["id"]):
					continue
				if Profile.buy_horn(item["id"]):
					bought = true
		day = "2026-11-%02d" % (i + 2)
	var gained := _count_owned() - owned_before
	assert_gte(gained, 5, "At least 5 items should unlock in 10 starter-level shifts")


func _count_owned() -> int:
	var total := 0
	for kind: String in [Catalog.ROUTES, Catalog.BUSES, Catalog.LIVERIES, Catalog.DRIVERS, Catalog.DECORATIONS]:
		total += (Profile.data.owned.get(kind, []) as Array).size()
	total += Profile.data.horns_owned.size()
	return total


func test_existing_saves_keep_purchases_and_coins() -> void:
	var saved := {
		"version": 2, "coins": 777, "xp": 200,
		"owned": {
			"routes": ["starter_a", "route_01"], "buses": ["buseta_8", "midi_10"],
			"liveries": ["rojo_caribe", "azul_bahia"], "drivers": ["wilmer_pertuz"],
		},
		"selected": {"routes": "route_01", "buses": "midi_10", "liveries": "azul_bahia", "drivers": "wilmer_pertuz"},
		"horns_owned": ["double_tap"], "horn": "double_tap",
	}
	var profile := PlayerProfile.from_dict(saved)
	assert_eq(profile.coins, 777)
	assert_true(profile.owns(Catalog.BUSES, "midi_10"))
	assert_true(profile.owns(Catalog.LIVERIES, "azul_bahia"))
	assert_true(profile.owns_horn("double_tap"))
	assert_true(profile.owns(Catalog.DECORATIONS, profile.selected[Catalog.DECORATIONS]), "Gets a default decoration")
	assert_ne(profile.selected[Catalog.DECORATIONS], "")


func test_next_unlock_helper_is_exposed_for_results_screen() -> void:
	# A clear function the results screen can call later.
	assert_true(Profile.has_method("next_unlock"))
	var info := UnlockProgress.next(Profile.data, Profile.catalog, Country.pack)
	assert_true(info.has("name"))
	assert_true(info.has("coins_missing"))
	assert_true(info.has("levels_missing"))
