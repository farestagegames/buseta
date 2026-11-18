extends GutTest
## The player's own drivers: slots by level, parts and how they unlock, special
## items with one copy per driver, route payouts, name tags and the save.

var parts: DriverParts
var profile: PlayerProfile


func before_each() -> void:
	parts = DriverParts.for_pack(Country.pack)
	profile = PlayerProfile.new()


func _level(level: int) -> void:
	profile.xp = DriverLevel.xp_for_level(level)


func _fresh_profile() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_custom_driver_save.json"))
	Profile.load_from("user://test_custom_driver_save.json")
	Profile.data.xp = 0
	Profile.data.custom = CustomDrivers.new()


func _custom() -> CustomDrivers:
	return profile.custom


func test_the_pack_file_has_no_problems_and_a_special_for_every_route() -> void:
	var route_ids := Catalog.new().items(Catalog.ROUTES).map(func(r: Dictionary) -> String: return r["id"])
	assert_eq(parts.check(route_ids), [] as Array[String])
	for route_id: String in route_ids:
		assert_false(parts.special_for_route(route_id).is_empty(), "%s has a special item" % route_id)
		assert_false(parts.star_part_for_route(route_id).is_empty(), "%s has a three-star colour" % route_id)


func test_slots_open_at_levels_ten_twenty_and_thirty() -> void:
	assert_eq(parts.slot_levels(), [10, 20, 30] as Array[int])
	assert_eq(parts.slots_open(9), 0)
	assert_eq(parts.slots_open(10), 1)
	assert_eq(parts.slots_open(29), 2)
	assert_eq(parts.slots_open(40), 3)
	_level(9)
	assert_false(profile.custom_drivers_open(parts))
	_level(10)
	assert_true(profile.custom_drivers_open(parts))


func test_a_driver_is_made_in_an_open_slot_with_the_free_look() -> void:
	assert_false(_custom().create(0, "Yeimy", parts, 9), "no slot below level 10")
	assert_true(_custom().create(0, "  Yeimy  ", parts, 10))
	assert_eq(_custom().driver(0)["name"], "Yeimy")
	assert_false(_custom().create(0, "Otra", parts, 10), "slot taken")
	assert_false(_custom().create(1, "Otra", parts, 10), "second slot at 20")
	assert_false(_custom().create(1, "   ", parts, 20), "needs a name")
	var look := DriverLook.from_item(_custom().driver(0))
	assert_eq(look.driver_name, "Yeimy")
	assert_eq(look.outfit, "polo")
	assert_eq(look.hat, "")
	for field: String in ["skin", "hair", "hair_style", "uniform", "trim", "accent"]:
		var p := {}
		for candidate: Dictionary in parts.parts():
			if candidate["field"] != field and not (candidate["field"] == "cloth" and field in DriverParts.CLOTH_FIELDS):
				continue
			if _custom().wears_part(0, candidate["id"], parts, field if field in DriverParts.CLOTH_FIELDS else "uniform"):
				p = candidate
		assert_false(p.is_empty(), "starts with a %s part on" % field)
		assert_true(parts.is_free(p), "%s is free" % field)


func test_names_are_trimmed_to_sixteen_letters() -> void:
	_custom().create(0, "Un nombre larguísimo de verdad", parts, 10)
	assert_eq(str(_custom().driver(0)["name"]).length(), CustomDrivers.MAX_NAME)


func test_renaming_uses_up_a_name_tag() -> void:
	_custom().create(0, "Yeimy", parts, 10)
	assert_false(_custom().rename(0, "Yeimi"), "no tag yet")
	_custom().name_tags = 1
	assert_false(_custom().rename(0, "Yeimy"), "same name keeps the tag")
	assert_true(_custom().rename(0, "Yeimi"))
	assert_eq(_custom().driver(0)["name"], "Yeimi")
	assert_eq(_custom().name_tags, 0)


func test_levels_give_a_name_tag_every_five_from_fifteen_once_each() -> void:
	assert_eq(parts.name_tags_by_level(14), 0)
	assert_eq(parts.name_tags_by_level(15), 1)
	assert_eq(parts.name_tags_by_level(19), 1)
	assert_eq(parts.name_tags_by_level(25), 3)
	assert_eq(parts.name_tag_levels_between(14, 21), [15, 20] as Array[int])
	assert_eq(_custom().settle_name_tags(parts, 22), 2)
	assert_eq(_custom().settle_name_tags(parts, 22), 0)
	assert_eq(_custom().settle_name_tags(parts, 25), 1)
	assert_eq(_custom().name_tags, 3)


func test_name_tags_are_bought_for_coins() -> void:
	_level(10)
	profile.coins = parts.name_tag_cost() - 1
	assert_false(profile.buy_name_tag(parts))
	profile.coins = parts.name_tag_cost()
	assert_true(profile.buy_name_tag(parts))
	assert_eq(_custom().name_tags, 1)
	assert_eq(profile.coins, 0)


func test_locked_parts_cannot_be_worn_until_their_level_or_bought() -> void:
	_custom().create(0, "Yeimy", parts, 10)
	assert_false(_custom().wear_part(0, "hair_afro", parts, 10))
	assert_true(_custom().wear_part(0, "hair_afro", parts, 11))
	assert_eq(_custom().driver(0)["hair_style"], "afro")
	assert_eq(parts.how_to_get(parts.part("hair_afro")), {"kind": "level", "value": 11})
	assert_false(_custom().wear_part(0, "towel", parts, 30))
	assert_eq(parts.how_to_get(parts.part("towel"))["kind"], "cost")


func test_ordinary_parts_bought_once_dress_every_driver() -> void:
	_level(20)
	profile.coins = 1000
	assert_true(profile.buy_driver_part(parts, "towel"))
	assert_false(profile.buy_driver_part(parts, "towel"), "only once")
	assert_eq(profile.coins, 1000 - int(parts.part("towel")["cost"]))
	_custom().create(0, "A", parts, 20)
	_custom().create(1, "B", parts, 20)
	assert_true(_custom().wear_part(0, "towel", parts, 20))
	assert_true(_custom().wear_part(1, "towel", parts, 20))
	assert_true(_custom().driver(0)["towel"] and _custom().driver(1)["towel"])
	assert_true(_custom().wear_part(1, "towel", parts, 20), "a second tap takes it off")
	assert_false(_custom().driver(1)["towel"])


func test_parts_cannot_be_bought_before_level_ten_or_without_coins() -> void:
	_level(9)
	profile.coins = 5000
	assert_false(profile.buy_driver_part(parts, "towel"))
	_level(10)
	profile.coins = 10
	assert_false(profile.buy_driver_part(parts, "towel"))
	assert_false(profile.buy_driver_part(parts, "hair_short"), "free parts are not sold")


func test_a_cloth_colour_goes_on_the_shirt_trim_or_hat() -> void:
	_custom().create(0, "A", parts, 10)
	assert_true(_custom().wear_part(0, "cloth_red", parts, 10, "trim"))
	assert_true(_custom().wears_part(0, "cloth_red", parts, "trim"))
	assert_false(_custom().wears_part(0, "cloth_red", parts, "uniform"))
	assert_false(_custom().wear_part(0, "cloth_red", parts, 10, "hair"))
	assert_eq(DriverLook.from_item(_custom().driver(0)).trim, Color(0.82, 0.18, 0.15))


func test_finishing_a_route_gives_its_special_item_once_and_three_stars_a_colour() -> void:
	var item := parts.special_for_route("route_01")
	var cards := _custom().pay_route("route_01", 2, parts)
	assert_eq(cards.size(), 1)
	assert_eq(cards[0]["kind"], "custom_special")
	assert_eq(_custom().copies(item["id"]), 1)
	assert_eq(_custom().pay_route("route_01", 2, parts).size(), 0, "not twice")
	cards = _custom().pay_route("route_01", 3, parts)
	assert_eq(cards.size(), 1, "the colour for three stars")
	assert_eq(_custom().copies(item["id"]), 1)
	var colour := parts.star_part_for_route("route_01")
	assert_true(parts.is_unlocked(colour, 10, [], _custom().paid_stars))


func test_routes_finished_before_level_ten_pay_out_when_the_editor_opens() -> void:
	var cards := _custom().back_pay(["starter_a", "starter_b", "route_01"], {"starter_a": 3}, parts)
	assert_eq(cards.size(), 4)
	assert_true(_custom().editor_seen)
	assert_eq(_custom().copies(parts.special_for_route("starter_b")["id"]), 1)
	assert_eq(_custom().back_pay(["starter_a"], {"starter_a": 3}, parts).size(), 0)


func test_one_copy_of_a_special_item_is_worn_by_one_driver_at_a_time() -> void:
	var item := parts.special_for_route("route_02")
	_custom().create(0, "A", parts, 20)
	_custom().create(1, "B", parts, 20)
	assert_eq(_custom().wear_special(0, item["id"], parts), -2, "not owned yet")
	_custom().pay_route("route_02", 1, parts)
	assert_eq(_custom().wear_special(0, item["id"], parts), -1)
	assert_eq(_custom().driver(0)[item["field"]], item["value"])
	assert_eq(_custom().wear_special(1, item["id"], parts), 0, "taken off driver A")
	assert_eq(_custom().wearers(item["id"], parts), [1] as Array[int])
	assert_eq(_custom().driver(0)[item["field"]], DriverParts.SPECIAL_DEFAULTS[item["field"]])


func test_a_bought_copy_lets_two_drivers_wear_it() -> void:
	var item := parts.special_for_route("route_02")
	_level(20)
	profile.coins = int(item["copy_cost"])
	assert_false(profile.buy_special_copy(parts, item["id"]), "earn it on the route first")
	_custom().pay_route("route_02", 1, parts)
	assert_true(profile.buy_special_copy(parts, item["id"]))
	assert_eq(profile.coins, 0)
	_custom().create(0, "A", parts, 20)
	_custom().create(1, "B", parts, 20)
	_custom().wear_special(0, item["id"], parts)
	assert_eq(_custom().wear_special(1, item["id"], parts), -1)
	assert_eq(_custom().wearers(item["id"], parts).size(), 2)


func test_an_ordinary_hat_frees_a_special_hat() -> void:
	var item := parts.special_for_route("route_04")
	_custom().create(0, "A", parts, 20)
	_custom().pay_route("route_04", 1, parts)
	_custom().wear_special(0, item["id"], parts)
	_custom().wear_part(0, "hat_cap", parts, 20)
	assert_eq(_custom().wearers(item["id"], parts).size(), 0)


func test_the_save_keeps_drivers_parts_items_and_tags() -> void:
	_level(20)
	_custom().create(0, "Yeimy", parts, 20)
	_custom().bought.append("towel")
	_custom().pay_route("route_02", 3, parts)
	_custom().wear_special(0, parts.special_for_route("route_02")["id"], parts)
	_custom().name_tags = 2
	_custom().chosen = 0
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	assert_eq(loaded.custom.driver(0)["name"], "Yeimy")
	assert_eq(loaded.custom.bought, ["towel"] as Array[String])
	assert_eq(loaded.custom.copies("gold_chain"), 1)
	assert_eq(loaded.custom.name_tags, 2)
	assert_eq(loaded.custom.chosen, 0)
	assert_eq(loaded.custom.paid_stars, ["route_02"] as Array[String])
	assert_eq(DriverLook.from_item(loaded.custom.driver(0)).neck, "gold_chain")


func test_an_old_save_without_custom_drivers_loads() -> void:
	var loaded := PlayerProfile.from_dict({"version": 3, "coins": 50, "xp": 4000})
	assert_eq(loaded.custom.drivers.size(), 0)
	assert_eq(loaded.custom.chosen, -1)
	assert_false(loaded.custom.editor_seen)


func test_damaged_custom_data_loads_safely() -> void:
	var loaded := PlayerProfile.from_dict({"custom": {"drivers": [5, {"name": ""}, {"name": "Ok", "skin": "x"}],
		"specials": {"gold_chain": "two", "rosary": 2}, "name_tags": -4, "chosen": 7, "bought": [1, "towel"]}})
	assert_false(loaded.custom.has_driver(0))
	assert_false(loaded.custom.has_driver(1))
	assert_eq(DriverLook.from_item(loaded.custom.driver(2)).driver_name, "Ok")
	assert_eq(loaded.custom.specials, {"rosary": 2})
	assert_eq(loaded.custom.name_tags, 0)
	assert_eq(loaded.custom.chosen, -1)
	assert_eq(loaded.custom.bought, ["towel"] as Array[String])
	assert_eq(PlayerProfile.from_dict({"custom": "junk"}).custom.drivers.size(), 0)


func test_repair_takes_off_items_worn_more_than_owned() -> void:
	_custom().create(0, "A", parts, 20)
	_custom().create(1, "B", parts, 20)
	_custom().driver(0)["neck"] = "gold_chain"
	_custom().driver(1)["neck"] = "gold_chain"
	_custom().add_special("gold_chain")
	_custom().repair(parts)
	assert_eq(_custom().wearers("gold_chain", parts), [0] as Array[int])


func test_a_look_reads_the_special_items() -> void:
	var look := DriverLook.from_item({"eyewear": "aviators", "neck": "rosary", "shoulder": "carriel",
		"hands": "gloves", "hat": "aguadeno", "outfit": "ruana"})
	assert_eq([look.eyewear, look.neck, look.shoulder, look.hands, look.hat, look.outfit],
		["aviators", "rosary", "carriel", "gloves", "aguadeno", "ruana"])
	look = DriverLook.from_item({"eyewear": "monocle", "neck": 3})
	assert_eq([look.eyewear, look.neck], ["", ""])


func test_level_ups_bring_cards_for_slots_name_tags_and_parts() -> void:
	assert_eq(UnlockNews.custom_between(parts, 5, 9), [] as Array[Dictionary], "nothing before level 10")
	var kinds := UnlockNews.custom_between(parts, 9, 10).map(func(c: Dictionary) -> String: return c["kind"])
	assert_eq(kinds, ["custom_slot"])
	var cards := UnlockNews.custom_between(parts, 10, 11)
	assert_eq(cards.size(), 1)
	assert_true((cards[0]["names"] as Array).has("Afro"))
	kinds = UnlockNews.custom_between(parts, 14, 20).map(func(c: Dictionary) -> String: return c["kind"])
	assert_eq(kinds.count("custom_name_tag"), 2)
	assert_eq(kinds.count("custom_slot"), 1)


func test_the_chosen_custom_driver_drives_and_a_hired_pick_undoes_it() -> void:
	_fresh_profile()
	Profile.data.xp = DriverLevel.xp_for_level(10)
	Profile.data.custom.create(0, "Yeimy", Profile.driver_parts, 10)
	assert_true(Profile.choose_custom(0))
	assert_eq(Profile.driver_item()["name"], "Yeimy")
	assert_eq(CityShift.chosen_look().driver_name, "Yeimy")
	Profile.data.xp = 0
	assert_ne(Profile.driver_item().get("name"), "Yeimy", "a lower level shows the hired driver")
	Profile.data.xp = DriverLevel.xp_for_level(10)
	Profile.select(Catalog.DRIVERS, PlayerProfile.DEFAULT_DRIVER)
	assert_eq(Profile.data.custom.chosen, -1)
	assert_ne(Profile.driver_item().get("name"), "Yeimy")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_custom_driver_save.json"))
	Profile.load_from("user://test_save_scene.json")


func test_opening_the_editor_pays_finished_routes_once() -> void:
	_fresh_profile()
	Profile.data.completed_routes.append("starter_a")
	Profile.data.best_scores["arcade"] = 7
	Profile.data.best_stars["starter_a"] = 3
	assert_eq(Profile.open_driver_editor().size(), 0, "closed below level 10")
	Profile.data.xp = DriverLevel.xp_for_level(10)
	assert_eq(Profile.open_driver_editor().size(), 3, "starter_a item and colour, arcade item")
	assert_eq(Profile.open_driver_editor().size(), 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_custom_driver_save.json"))
	Profile.load_from("user://test_save_scene.json")
