extends GutTest
## Who can drive the bus, how they look and how they are unlocked.

var catalog: Catalog
var drivers: Array


func before_each() -> void:
	catalog = Catalog.new()
	drivers = catalog.items(Catalog.DRIVERS)


func _looks() -> Array[DriverLook]:
	var looks: Array[DriverLook] = []
	for item: Dictionary in drivers:
		looks.append(DriverLook.from_item(item))
	return looks


## One look for every hair style, beard, hat and outfit, plus every extra at once.
func _every_option() -> Array[DriverLook]:
	var looks: Array[DriverLook] = []
	for style: String in DriverLook.HAIR_STYLES:
		var look := DriverLook.new()
		look.hair_style = style
		looks.append(look)
	for beard: String in DriverLook.BEARDS:
		var look := DriverLook.new()
		look.beard = beard
		looks.append(look)
	for hat: String in DriverLook.HATS:
		var look := DriverLook.new()
		look.hat = hat
		looks.append(look)
	for outfit: String in DriverLook.OUTFITS:
		var look := DriverLook.new()
		look.outfit = outfit
		look.glasses = true
		look.greying = true
		look.earrings = true
		looks.append(look)
	for eyewear: String in DriverLook.EYEWEAR:
		var look := DriverLook.new()
		look.eyewear = eyewear
		looks.append(look)
	for neck: String in DriverLook.NECK:
		var look := DriverLook.new()
		look.neck = neck
		looks.append(look)
	for shoulder: String in DriverLook.SHOULDER:
		var look := DriverLook.new()
		look.shoulder = shoulder
		looks.append(look)
	for hands: String in DriverLook.HANDS:
		var look := DriverLook.new()
		look.hands = hands
		looks.append(look)
	var everything := DriverLook.new()
	everything.hat = "vueltiao_tricolor"
	everything.outfit = "chaleco"
	everything.eyewear = "mirror_shades"
	everything.neck = "rosary"
	everything.shoulder = "carriel"
	everything.hands = "gloves"
	looks.append(everything)
	return looks


func _vertices(mesh: ArrayMesh) -> int:
	return 0 if mesh.get_surface_count() == 0 else (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


## Vertex colours are stored at eight bits a channel, so close is equal.
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.02


func _has_colour(mesh: ArrayMesh, colour: Color) -> bool:
	return Array(mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]).any(func(c: Color) -> bool: return _near(c, colour))


func test_at_least_eight_drivers_with_no_repeated_looks() -> void:
	assert_gte(drivers.size(), 8)
	var looks := {}
	for look in _looks():
		looks["%s %s %s %s %s" % [look.skin, look.uniform, look.hair_style, look.beard, look.hat]] = true
	assert_eq(looks.size(), drivers.size(), "Every driver must look different")


func test_cast_is_varied() -> void:
	var skins := {}
	var uniforms := {}
	var hair_styles := {}
	for look in _looks():
		skins[look.skin] = true
		uniforms[look.uniform] = true
		hair_styles[look.hair_style] = true
	assert_gte(skins.size(), 8)
	assert_gte(uniforms.size(), 8)
	assert_gte(hair_styles.size(), 6)


func test_skin_tones_run_from_deep_brown_to_light() -> void:
	var lightness: Array = _looks().map(func(look: DriverLook) -> float: return look.skin.get_luminance())
	assert_gte(lightness.filter(func(value: float) -> bool: return value < 0.32).size(), 3, "Deep")
	assert_gte(lightness.filter(func(value: float) -> bool: return value > 0.62).size(), 3, "Light")
	assert_gte(lightness.filter(func(value: float) -> bool: return value >= 0.32 and value <= 0.62).size(), 3, "Medium")


func test_glasses_and_beards_are_not_tied_to_one_skin_tone() -> void:
	var glasses := _looks().filter(func(look: DriverLook) -> bool: return look.glasses)
	var tones := {}
	for look: DriverLook in glasses:
		tones[look.skin.get_luminance() < 0.32] = true
	assert_eq(tones.size(), 2, "Both deep and lighter skinned drivers wear glasses")


func test_drivers_wear_their_own_short_sleeved_shirts() -> void:
	for look in _looks():
		assert_has(DriverLook.OUTFITS, look.outfit)
		assert_true(_has_colour(DriverFigure.build_sleeve(look), look.skin), "%s shows forearms" % look.driver_name)
	assert_eq(DriverLook.from_item({"outfit": "uniform"}).outfit, "polo", "An old uniform entry wears a polo")


func test_drivers_wear_the_colombian_looks() -> void:
	var looks := _looks()
	assert_true(looks.any(func(look: DriverLook) -> bool: return look.hair_style == "braids"), "Braids")
	assert_true(looks.any(func(look: DriverLook) -> bool: return look.hat == "headwrap"), "A headwrap")
	assert_true(looks.any(func(look: DriverLook) -> bool: return look.hat == "vueltiao"), "A sombrero vueltiao")
	assert_true(looks.any(func(look: DriverLook) -> bool: return look.outfit == "guayabera"), "A guayabera")
	assert_true(looks.any(func(look: DriverLook) -> bool: return look.greying), "Greying hair")
	assert_true(looks.any(func(look: DriverLook) -> bool: return look.beard == "thin_moustache"), "A thin moustache")
	assert_true(looks.any(func(look: DriverLook) -> bool: return look.towel), "A towel over the shoulder")


func test_two_are_free_and_the_rest_cost_300_to_1200_coins() -> void:
	var free := drivers.filter(func(item: Dictionary) -> bool: return int(item["cost"]) == 0)
	assert_eq(free.size(), 2)
	for item: Dictionary in drivers:
		if int(item["cost"]) > 0:
			assert_between(int(item["cost"]), 300, 1200, item["id"])


func test_new_player_owns_the_free_drivers_only() -> void:
	var profile := PlayerProfile.new()
	profile.grant_free_items(catalog)
	for item: Dictionary in drivers:
		assert_eq(profile.owns(Catalog.DRIVERS, item["id"]), int(item["cost"]) == 0, item["id"])


func test_default_driver_is_in_the_catalog_and_free() -> void:
	var item := catalog.find(Catalog.DRIVERS, PlayerProfile.DEFAULT_DRIVER)
	assert_false(item.is_empty())
	assert_eq(int(item["cost"]), 0)


func test_driver_can_be_bought_with_coins_and_chosen() -> void:
	var profile := PlayerProfile.new()
	var item := catalog.find(Catalog.DRIVERS, "yolima_uriana")
	assert_false(profile.select(Catalog.DRIVERS, "yolima_uriana"), "Not owned yet")
	assert_false(profile.buy(Catalog.DRIVERS, item), "No coins yet")
	profile.coins = int(item["cost"])
	assert_true(profile.buy(Catalog.DRIVERS, item))
	assert_eq(profile.coins, 0)
	assert_true(profile.select(Catalog.DRIVERS, "yolima_uriana"))


func test_chosen_driver_survives_a_save() -> void:
	var profile := PlayerProfile.new()
	profile.coins = 5000
	profile.buy(Catalog.DRIVERS, catalog.find(Catalog.DRIVERS, "ramiro_mestra"))
	profile.select(Catalog.DRIVERS, "ramiro_mestra")
	var copy := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	copy.repair_choices(catalog)
	assert_eq(copy.selected[Catalog.DRIVERS], "ramiro_mestra")


func test_save_from_before_drivers_loads_with_the_default() -> void:
	var old := {"coins": 40, "owned": {"routes": ["route_01"]}, "selected": {"routes": "route_01"}}
	var profile := PlayerProfile.from_dict(old)
	assert_eq(profile.selected[Catalog.DRIVERS], PlayerProfile.DEFAULT_DRIVER)
	assert_eq(profile.coins, 40)


func test_a_driver_who_left_the_game_falls_back_to_the_default() -> void:
	var old := {"coins": 40, "owned": {"drivers": ["sam_reed", "walter_novak"]}, "selected": {"drivers": "walter_novak"}}
	var profile := PlayerProfile.from_dict(old)
	profile.grant_free_items(catalog)
	profile.repair_choices(catalog)
	assert_eq(profile.selected[Catalog.DRIVERS], PlayerProfile.DEFAULT_DRIVER)
	assert_eq(profile.selected[Catalog.ROUTES], PlayerProfile.DEFAULT_ROUTE, "Other choices are left alone")
	assert_eq(profile.coins, 40)


func test_without_the_default_a_lost_choice_takes_the_first_driver_owned() -> void:
	var profile := PlayerProfile.new()
	profile.owned[Catalog.DRIVERS] = ["ramiro_mestra"]
	profile.selected[Catalog.DRIVERS] = "joe_mensah"
	profile.repair_choices(catalog)
	assert_eq(profile.selected[Catalog.DRIVERS], "ramiro_mestra")


func test_the_game_loads_an_old_save_with_a_driver_it_no_longer_has() -> void:
	var path := "user://test_old_driver_save.json"
	SaveStore.write(path, {"owned": {"drivers": ["joe_mensah"]}, "selected": {"drivers": "joe_mensah"}})
	Profile.load_from(path)
	assert_eq(Profile.data.selected[Catalog.DRIVERS], PlayerProfile.DEFAULT_DRIVER)
	assert_eq(Profile.selected_item(Catalog.DRIVERS)["id"], PlayerProfile.DEFAULT_DRIVER)
	Profile.load_from("user://test_save_scene.json")
	Profile.data.intro_done = true


func test_look_reads_a_catalog_entry() -> void:
	var look := DriverLook.from_item(catalog.find(Catalog.DRIVERS, "ramiro_mestra"))
	assert_eq(look.driver_name, "Ramiro Mestra")
	assert_eq(look.hat, "vueltiao")
	assert_eq(look.outfit, "guayabera")
	assert_eq(look.beard, "thin_moustache")


func test_an_older_entry_with_a_cap_still_wears_it() -> void:
	assert_eq(DriverLook.from_item({"cap": true}).hat, "cap")
	assert_eq(DriverLook.from_item({"cap": true, "hat": "vueltiao"}).hat, "vueltiao")


func test_look_ignores_damaged_data() -> void:
	var damaged := {
		"name": "X", "skin": [1], "hair_style": "mohawk", "beard": 4, "hat": "crown", "outfit": 7,
		"uniform": ["a", "b", "c"], "accent": null, "greying": "yes", "earrings": 1,
	}
	var look := DriverLook.from_item(damaged)
	var plain := DriverLook.new()
	assert_eq(look.hair_style, plain.hair_style)
	assert_eq(look.beard, "")
	assert_eq(look.hat, "")
	assert_eq(look.outfit, "polo")
	assert_eq(look.skin, plain.skin)
	assert_eq(look.uniform, plain.uniform)
	assert_false(look.greying)
	assert_false(look.earrings)


func test_every_driver_builds_a_figure_mirror_head_and_hands() -> void:
	for look in _looks():
		assert_gt(DriverFigure.build_bust(look).get_surface_count(), 0, look.driver_name)
		assert_gt(DriverFigure.build_head(look).get_surface_count(), 0, look.driver_name)
		assert_gt(DriverFigure.build_sleeve(look).get_surface_count(), 0, look.driver_name)
		assert_gt(DriverFigure.build_hand(look).get_surface_count(), 0, look.driver_name)


func test_every_option_builds_a_figure_mirror_head_and_hands() -> void:
	for look in _every_option():
		var label := "%s %s %s %s" % [look.hair_style, look.beard, look.hat, look.outfit]
		assert_gt(DriverFigure.build_bust(look).get_surface_count(), 0, label)
		assert_gt(DriverFigure.build_head(look).get_surface_count(), 0, label)
		assert_gt(DriverFigure.build_sleeve(look).get_surface_count(), 0, label)


func test_every_extra_shows_on_the_head() -> void:
	var plain := DriverLook.new()
	plain.hair_style = "bald"
	var base := _vertices(DriverFigure.build_head(plain))
	for change: Callable in [
		func(look: DriverLook) -> void: look.hair_style = "braids",
		func(look: DriverLook) -> void: look.hat = "vueltiao",
		func(look: DriverLook) -> void: look.hat = "headwrap",
		func(look: DriverLook) -> void: look.beard = "thin_moustache",
		func(look: DriverLook) -> void: look.beard = "goatee",
		func(look: DriverLook) -> void: look.greying = true,
		func(look: DriverLook) -> void: look.earrings = true,
	]:
		var look := DriverLook.new()
		look.hair_style = "bald"
		change.call(look)
		assert_gt(_vertices(DriverFigure.build_head(look)), base)


func test_a_guayabera_has_pleats_and_pockets() -> void:
	var look := DriverLook.from_item(catalog.find(Catalog.DRIVERS, "ramiro_mestra"))
	assert_true(_has_colour(DriverFigure.build_sleeve(look), look.skin), "Short sleeves")
	assert_gt(_vertices(DriverFigure.build_bust(look)), _vertices(DriverFigure.build_bust(DriverLook.new())), "Pleats and pockets")


func test_a_towel_shows_over_the_shoulder() -> void:
	var look := DriverLook.from_item({"towel": true})
	assert_true(look.towel)
	assert_true(_has_colour(DriverFigure.build_bust(look), DriverFigure.TOWEL))
	assert_false(_has_colour(DriverFigure.build_bust(DriverLook.new()), DriverFigure.TOWEL))


func test_a_headwrap_covers_the_hair() -> void:
	var look := DriverLook.new()
	look.hair_style = "afro"
	look.hair = Color(0.9, 0.1, 0.9)
	assert_true(_has_colour(DriverFigure.build_head(look), look.hair))
	look.hat = "headwrap"
	assert_false(_has_colour(DriverFigure.build_head(look), look.hair))


func test_check_names_a_misspelt_style_or_bad_colour() -> void:
	for item: Dictionary in drivers:
		assert_eq(DriverLook.check(item), [] as Array[String], item["id"])
	var problems := DriverLook.check({
		"id": "x", "hat": "vueltaio", "outfit": "poncho", "hair_style": 3, "skin": [200, 150, 120], "towel": "yes",
	})
	for words: String in ["unknown hat", "unknown outfit", "unknown hair_style", "skin colour", "towel"]:
		assert_true(problems.any(func(problem: String) -> bool: return problem.contains(words)), words)


## Corners of the head's box once it is placed in the mirror, from the middle of the glass.
func _mirror_box(look: DriverLook, door_side: int) -> AABB:
	var mesh := DriverFigure.build_head(look, BusVisual.mirror_window(door_side))
	return BusVisual.mirror_face_transform(door_side) * mesh.get_aabb()


func test_the_mirror_face_stays_inside_the_glass_on_either_side() -> void:
	var half := BusVisual.MIRROR_GLASS / 2.0
	for item: Dictionary in drivers:
		var look := DriverLook.from_item(item)
		for door_side: int in [1, -1]:
			var box := _mirror_box(look, door_side)
			var label := "%s, doors on %d" % [item["id"], door_side]
			assert_gte(box.position.x, -half.x, label)
			assert_lte(box.end.x, half.x, label)
			assert_gte(box.position.y, -half.y, label)
			assert_lte(box.end.y, half.y, label)
			assert_gte(box.position.z, BusVisual.MIRROR_GLASS_FRONT - 0.0001, "%s: in front of the glass" % label)
			assert_lt(box.size.z, 0.03, "%s: flat, as a reflection is" % label)


func test_the_mirror_face_sits_towards_the_driver() -> void:
	for door_side: int in [1, -1]:
		var face := BusVisual.mirror_face_transform(door_side).origin
		assert_eq(signf(face.x), -float(door_side), "The driver sits opposite the doors")


func test_a_tall_hat_is_trimmed_to_the_mirror() -> void:
	var look := DriverLook.from_item(catalog.find(Catalog.DRIVERS, "ramiro_mestra"))
	var whole := DriverFigure.build_head(look).get_aabb()
	var trimmed := DriverFigure.build_head(look, BusVisual.mirror_window(1)).get_aabb()
	assert_lt(trimmed.size.x, whole.size.x, "The brim stops at the frame")
	var arrays := DriverFigure.build_head(look, BusVisual.mirror_window(1)).surface_get_arrays(0)
	var band_shows := false
	for i in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var colour: Color = arrays[Mesh.ARRAY_COLOR][i]
		if arrays[Mesh.ARRAY_VERTEX][i].y > 0.15 and _near(colour, HeadParts.STRAW_BLACK):
			band_shows = true
	assert_true(band_shows, "A black band on the crown still shows")


func test_greying_shows_in_the_moustache() -> void:
	var look := DriverLook.from_item(catalog.find(Catalog.DRIVERS, "ruben_cardona"))
	assert_true(look.greying)
	assert_ne(look.beard_colour(), look.hair)
	assert_true(_has_colour(DriverFigure.build_head(look), look.temple_colour()))


## Ray-triangle intersection returning distance t, or -1.0 if no hit.
func _ray_triangle_hit(ro: Vector3, rd: Vector3, v0: Vector3, v1: Vector3, v2: Vector3) -> float:
	var edge1 := v1 - v0
	var edge2 := v2 - v0
	var h := rd.cross(edge2)
	var a := edge1.dot(h)
	if absf(a) < 1e-7:
		return -1.0
	var f := 1.0 / a
	var s := ro - v0
	var u := f * s.dot(h)
	if u < 0.0 or u > 1.0:
		return -1.0
	var q := s.cross(edge1)
	var v := f * rd.dot(q)
	if v < 0.0 or u + v > 1.0:
		return -1.0
	var t := f * edge2.dot(q)
	return t if t > 1e-5 else -1.0


## Minimum distance from ray origin along ray direction to any hair/hat triangle on the head mesh.
func _hair_surface_distance(mesh: ArrayMesh, skin_colour: Color, origin: Vector3, dir: Vector3) -> float:
	if mesh.get_surface_count() == 0:
		return -1.0
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var hit_dist := INF
	for i in range(0, verts.size(), 3):
		var c: Color = colors[i]
		if _near(c, skin_colour) or _near(c, HeadParts.DARK):
			continue
		var t := _ray_triangle_hit(origin, dir, verts[i], verts[i + 1], verts[i + 2])
		if t > 0.0 and t < hit_dist:
			hit_dist = t
	return hit_dist if hit_dist != INF else -1.0


func test_every_driver_look_hair_sits_outside_skull_surface() -> void:
	var origin := Vector3(0.0, 0.12, 0.0)
	for look in _looks():
		var mesh := DriverFigure.build_head(look)
		for i in 16:
			var theta := -0.65 + float(i) * (1.30 / 15.0)
			var dir := Vector3(sin(theta), 0.0, -cos(theta)).normalized()
			var skull_dist := 0.115 / cos(theta)
			var hair_dist := _hair_surface_distance(mesh, look.skin, origin, dir)
			assert_gt(hair_dist, 0.0, "%s has hair/headwear at angle %.2f" % [look.driver_name, theta])
			var clearance_mm := (hair_dist - skull_dist) * 1000.0
			assert_gte(clearance_mm, 3.0, "%s hair clearance at angle %.2f must be >= 3 mm (was %.1f mm)" % [look.driver_name, theta, clearance_mm])


func test_every_hair_style_sits_outside_skull_surface() -> void:
	var origin := Vector3(0.0, 0.12, 0.0)
	for style: String in DriverLook.HAIR_STYLES:
		if style == "bald":
			continue
		var look := DriverLook.new()
		look.hair_style = style
		var mesh := DriverFigure.build_head(look)
		for i in 16:
			var theta := -0.65 + float(i) * (1.30 / 15.0)
			var dir := Vector3(sin(theta), 0.0, -cos(theta)).normalized()
			var skull_dist := 0.115 / cos(theta)
			var hair_dist := _hair_surface_distance(mesh, look.skin, origin, dir)
			assert_gt(hair_dist, 0.0, "Style %s has hair at angle %.2f" % [style, theta])
			var clearance_mm := (hair_dist - skull_dist) * 1000.0
			assert_gte(clearance_mm, 3.0, "Style %s clearance at angle %.2f must be >= 3 mm (was %.1f mm)" % [style, theta, clearance_mm])


func test_regression_hair_style_that_showed_glitch_sits_outside_skull() -> void:
	var glitch_styles: Array[String] = ["short", "fade", "braids", "long"]
	var origin := Vector3(0.0, 0.12, 0.0)
	for style in glitch_styles:
		var look := DriverLook.new()
		look.hair_style = style
		var mesh := DriverFigure.build_head(look)
		var dir := Vector3(0.0, 0.0, -1.0)
		var skull_dist := 0.115
		var hair_dist := _hair_surface_distance(mesh, look.skin, origin, dir)
		var clearance_mm := (hair_dist - skull_dist) * 1000.0
		assert_gte(clearance_mm, 5.0, "Regression style %s must sit >= 5 mm outside skull (was %.1f mm)" % [style, clearance_mm])

