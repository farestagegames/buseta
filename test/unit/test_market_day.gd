extends GutTest
## Market day in Alto Cafeto: seeded, only where a map plans one, never changing
## the map itself, and with every stall clear of the bus stops and parked cars.

const CAFETO := "res://data/packs/colombia/maps/alto_cafeto.json"
const MARISOL := "res://data/packs/colombia/maps/puerto_marisol.json"

var cafeto: Dictionary


func before_all() -> void:
	cafeto = MapLoader.read_json(CAFETO)


func test_about_half_of_shifts_are_market_days_and_the_seed_decides() -> void:
	var on := 0
	for seed_value in 200:
		if MarketDay.is_on(cafeto, seed_value):
			on += 1
		assert_eq(MarketDay.is_on(cafeto, seed_value), MarketDay.is_on(cafeto, seed_value))
	assert_between(on, 70, 130)


func test_towns_without_a_market_never_have_one() -> void:
	var marisol := MapLoader.read_json(MARISOL)
	for seed_value in 50:
		assert_false(MarketDay.is_on(marisol, seed_value))
	assert_eq(MarketDay.people(marisol, false), 1.0)


func test_the_market_adds_stalls_to_a_copy_only() -> void:
	var before: int = cafeto["knockables"].size()
	var market := MarketDay.apply(cafeto, true)
	assert_gt(market["knockables"].size(), before + 6)
	assert_eq(cafeto["knockables"].size(), before, "The town's own map is untouched")
	assert_eq(MarketDay.apply(cafeto, false)["knockables"].size(), before)
	assert_gt(MarketDay.people(cafeto, true), 1.0, "More people out")


func test_market_stalls_stay_clear_of_stops_and_parked_cars() -> void:
	var market := MarketDay.apply(cafeto, true)
	var network := RoadNetwork.from_data(market, Country.pack.traffic_side, Country.pack.default_speed_limit())
	var stalls: Array[Vector2] = []
	for entry: Dictionary in market["market_day"]["knockables"]:
		stalls.append(network.sample(entry["road"], entry["along"], entry["lateral"], entry["dir"])["position"])
	for item: Dictionary in Profile.catalog.items(Catalog.ROUTES):
		var data := MapLoader.read_json(item["file"])
		if not str(data["map"]).ends_with("alto_cafeto.json") or data.get("service", "") == "arcade":
			continue
		for stop in RouteRunner.build(data, network, 7, market).stops:
			for stall in stalls:
				assert_gt(stop.position.distance_to(stall), 18.0, "%s: %s" % [item["id"], stop.stop_name])
	for car: Dictionary in market["parked_cars"]:
		var parked: Vector2 = network.sample(car["road"], car["along"], car.get("lateral", 4.0), car.get("dir", 1))["position"]
		for stall in stalls:
			assert_gt(parked.distance_to(stall), 6.0, "Stall clear of the parked car on %s" % car["road"])
