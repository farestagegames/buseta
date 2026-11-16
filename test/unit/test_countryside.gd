extends GutTest
## Alto Cafeto's farmland on the empty grass between the streets and the woodland.


func test_farmland_keeps_off_roads_and_the_beach() -> void:
	assert_true(CityBuilder.countryside_spot_ok(12.0, 0.0, 8.0))
	assert_false(CityBuilder.countryside_spot_ok(5.0, 0.0, 8.0), "Too near a road")
	assert_false(CityBuilder.countryside_spot_ok(20.0, 0.4, 8.0), "On the beach")


func test_only_alto_cafeto_has_farmland() -> void:
	var cafeto := MapLoader.read_json("res://data/packs/colombia/maps/alto_cafeto.json")
	var marisol := MapLoader.read_json("res://data/packs/colombia/maps/puerto_marisol.json")
	assert_true(cafeto.has("countryside"))
	assert_false(marisol.has("countryside"), "The coast town keeps its own look")
