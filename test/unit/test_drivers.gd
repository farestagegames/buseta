extends GutTest
## Who can drive the bus, how they look and how they are unlocked.

var catalog: Catalog
var drivers: Array


func before_each() -> void:
	catalog = Catalog.new()
	drivers = catalog.items(Catalog.DRIVERS)


func test_at_least_six_drivers_with_no_repeated_looks() -> void:
	assert_gte(drivers.size(), 6)
	var looks := {}
	for item: Dictionary in drivers:
		var look := DriverLook.from_item(item)
		looks["%s %s %s %s" % [look.skin, look.uniform, look.hair_style, look.beard]] = true
	assert_eq(looks.size(), drivers.size(), "Every driver must look different")


func test_cast_is_varied() -> void:
	var skins := {}
	var uniforms := {}
	var hair_styles := {}
	for item: Dictionary in drivers:
		var look := DriverLook.from_item(item)
		skins[look.skin] = true
		uniforms[look.uniform] = true
		hair_styles[look.hair_style] = true
	assert_gte(skins.size(), 6)
	assert_gte(uniforms.size(), 6)
	assert_gte(hair_styles.size(), 5)


func test_some_are_free_and_some_cost_coins() -> void:
	var free := drivers.filter(func(item: Dictionary) -> bool: return int(item["cost"]) == 0)
	assert_gte(free.size(), 2)
	assert_gte(drivers.size() - free.size(), 4)


func test_new_player_owns_the_free_drivers_only() -> void:
	var profile := PlayerProfile.new()
	profile.grant_free_items(catalog)
	for item: Dictionary in drivers:
		assert_eq(profile.owns(Catalog.DRIVERS, item["id"]), int(item["cost"]) == 0, item["id"])


func test_default_driver_is_in_the_catalog() -> void:
	assert_false(catalog.find(Catalog.DRIVERS, PlayerProfile.DEFAULT_DRIVER).is_empty())


func test_driver_can_be_bought_with_coins_and_chosen() -> void:
	var profile := PlayerProfile.new()
	var item := catalog.find(Catalog.DRIVERS, "mei_tanaka")
	assert_false(profile.select(Catalog.DRIVERS, "mei_tanaka"), "Not owned yet")
	assert_false(profile.buy(Catalog.DRIVERS, item), "No coins yet")
	profile.coins = int(item["cost"])
	assert_true(profile.buy(Catalog.DRIVERS, item))
	assert_eq(profile.coins, 0)
	assert_true(profile.select(Catalog.DRIVERS, "mei_tanaka"))


func test_chosen_driver_survives_a_save() -> void:
	var profile := PlayerProfile.new()
	profile.coins = 5000
	profile.buy(Catalog.DRIVERS, catalog.find(Catalog.DRIVERS, "joe_mensah"))
	profile.select(Catalog.DRIVERS, "joe_mensah")
	var copy := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	assert_eq(copy.selected[Catalog.DRIVERS], "joe_mensah")


func test_save_from_before_drivers_loads_with_the_default() -> void:
	var old := {"coins": 40, "owned": {"routes": ["route_01"]}, "selected": {"routes": "route_01"}}
	var profile := PlayerProfile.from_dict(old)
	assert_eq(profile.selected[Catalog.DRIVERS], PlayerProfile.DEFAULT_DRIVER)
	assert_eq(profile.coins, 40)


func test_look_reads_a_catalog_entry() -> void:
	var look := DriverLook.from_item(catalog.find(Catalog.DRIVERS, "walter_novak"))
	assert_eq(look.driver_name, "Walter Novak")
	assert_true(look.glasses)
	assert_true(look.cap)


func test_look_ignores_damaged_data() -> void:
	var look := DriverLook.from_item({"name": "X", "skin": [1], "hair_style": "mohawk", "beard": 4})
	assert_eq(look.hair_style, "short")
	assert_eq(look.beard, "")
	assert_eq(look.skin, DriverLook.new().skin)


func test_every_look_builds_a_figure() -> void:
	for item: Dictionary in drivers:
		var look := DriverLook.from_item(item)
		assert_gt(DriverFigure.build_bust(look).get_surface_count(), 0, item["id"])
		assert_gt(DriverFigure.build_head(look).get_surface_count(), 0, item["id"])


func test_every_hair_style_has_a_driver_or_stays_supported() -> void:
	for style: String in DriverLook.HAIR_STYLES:
		var look := DriverLook.new()
		look.hair_style = style
		assert_gt(DriverFigure.build_head(look).get_surface_count(), 0, style)
