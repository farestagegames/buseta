extends GutTest
## The first two short routes and how they unlock the main ones.

const COLOMBIA := "res://data/packs/colombia/pack.json"


func before_each() -> void:
	Country.use_pack(COLOMBIA)


func _report(completed: bool = true) -> Dictionary:
	return {"score": 80, "stars": 3, "coins": 400, "carried": 8, "fares": 2320, "served": 3, "perfect_stops": 3,
		"completed": completed,
		"counts": {"collisions": 0, "harsh_brakes": 0, "kerbs": 0, "indicators": 0,
			"red_lights": 0, "knocked": 0, "jolts": 0}}


func test_fresh_profile_starts_on_starter_a() -> void:
	Profile.load_from("user://test_starter_fresh.json")
	assert_eq(Profile.data.selected[Catalog.ROUTES], "starter_a")
	assert_true(Profile.data.owns(Catalog.ROUTES, "starter_a"))
	assert_false(Profile.data.owns(Catalog.ROUTES, "starter_b"))
	assert_false(Profile.data.owns(Catalog.ROUTES, "route_01"))


func test_unlock_order_a_b_route_1() -> void:
	Profile.load_from("user://test_starter_unlock.json")
	Profile.data.select(Catalog.ROUTES, "starter_a")
	ShiftRewards.apply(Profile.data, _report(true), "starter_a", "2026-11-12", [], [], "buseta_8")
	Profile.data.complete_route("starter_a", Profile.catalog)
	assert_true(Profile.data.owns(Catalog.ROUTES, "starter_b"))
	assert_false(Profile.data.owns(Catalog.ROUTES, "route_01"))

	Profile.data.select(Catalog.ROUTES, "starter_b")
	ShiftRewards.apply(Profile.data, _report(true), "starter_b", "2026-11-12", [], [], "buseta_8")
	Profile.data.complete_route("starter_b", Profile.catalog)
	assert_true(Profile.data.owns(Catalog.ROUTES, "route_01"))


func test_existing_save_keeps_everything_owned() -> void:
	var path := "user://test_starter_old.json"
	SaveStore.write(path, {
		"coins": 123, "xp": 40, "intro_done": true,
		"owned": {"routes": ["route_01", "route_02"], "buses": ["buseta_8"], "liveries": ["rojo_caribe"], "drivers": ["wilmer_pertuz"]},
		"selected": {"routes": "route_01", "buses": "buseta_8", "liveries": "rojo_caribe", "drivers": "wilmer_pertuz"},
	})
	Profile.load_from(path)
	assert_true(Profile.data.owns(Catalog.ROUTES, "route_01"))
	assert_true(Profile.data.owns(Catalog.ROUTES, "route_02"))
	assert_eq(Profile.data.selected[Catalog.ROUTES], "route_01")
	assert_eq(Profile.data.coins, 123)
