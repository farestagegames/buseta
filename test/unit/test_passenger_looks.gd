extends GutTest
## Who rides the bus: passengers are data, varied, and safe to load.

const COLOMBIA := "res://data/packs/colombia/passengers.json"
const BROKEN := "res://test/fixtures/passengers/not_json.json"
## Skin lightness below DARK is deep brown, above LIGHT is light, and medium between.
const DARK := 0.32
const LIGHT := 0.62
const WORK_CLOTHES: Array[String] = ["scrubs", "vest", "apron"]
const WORK_THINGS: Array[String] = ["briefcase", "basket", "bucket", "cool_box"]

var cast: PassengerLooks
var material := LowPolyBuilder.vertex_colour_material()


func before_all() -> void:
	cast = PassengerLooks.read(COLOMBIA)


func _tone(look: PassengerLook) -> String:
	var lightness := look.skin.get_luminance()
	return "dark" if lightness < DARK else "light" if lightness > LIGHT else "medium"


func _tones(looks: Array) -> Dictionary:
	var found := {}
	for look: PassengerLook in looks:
		found[_tone(look)] = int(found.get(_tone(look), 0)) + 1
	return found


func _builds(look: PassengerLook) -> bool:
	return PassengerFigure.build_body(look, material).get_surface_count() > 0 \
		and PassengerFigure.build_arm(look, material).get_surface_count() > 0 \
		and PassengerFigure.build_leg(look, material).get_surface_count() > 0


func _vertices(mesh: ArrayMesh) -> int:
	return (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


func test_the_pack_file_loads_with_plenty_of_people() -> void:
	assert_gte(cast.looks.size(), 16)
	assert_gte(cast.vendors.size(), 1)
	assert_eq(PassengerLooks.check(PassengerLooks.parse_file(COLOMBIA)), [] as Array[String])


func test_the_game_reads_the_live_packs_passengers() -> void:
	assert_eq(Country.pack.passenger_looks().looks.size(), cast.looks.size())


func test_every_look_has_its_own_id() -> void:
	var ids := {}
	for look in cast.looks:
		ids[look.id] = true
	assert_eq(ids.size(), cast.looks.size())


func test_skin_tones_run_from_deep_brown_to_light() -> void:
	var skins := {}
	for look in cast.looks:
		skins[look.skin] = true
	assert_gte(skins.size(), 6)
	var tones := _tones(cast.looks)
	for tone: String in ["dark", "medium", "light"]:
		assert_gte(int(tones.get(tone, 0)), 4, tone)


func test_there_are_children_and_older_people() -> void:
	var children := cast.looks.filter(func(look: PassengerLook) -> bool: return look.is_child())
	var older := cast.looks.filter(func(look: PassengerLook) -> bool: return look.is_older())
	assert_gte(children.size(), 2)
	assert_gte(older.size(), 2)
	for child: PassengerLook in children:
		assert_false(child.is_older(), child.id)
	for elder: PassengerLook in older:
		assert_lt(elder.pace, 1.0, elder.id)


func test_every_age_spans_the_skin_tones() -> void:
	var groups := {
		"children": cast.looks.filter(func(look: PassengerLook) -> bool: return look.is_child()),
		"older people": cast.looks.filter(func(look: PassengerLook) -> bool: return look.is_older()),
		"adults": cast.looks.filter(func(look: PassengerLook) -> bool: return not look.is_child() and not look.is_older()),
	}
	for group: String in groups:
		assert_eq(_tones(groups[group]).size(), 3, "%s come in deep, medium and light skin tones" % group)


func test_work_clothes_are_not_tied_to_one_skin_tone() -> void:
	var workers := (cast.looks + cast.vendors).filter(func(look: PassengerLook) -> bool:
		return WORK_CLOTHES.has(look.top_style) or WORK_THINGS.has(look.carry))
	assert_eq(_tones(workers).size(), 3)


func test_everyday_people_of_the_coast_are_there() -> void:
	var looks := cast.looks
	var has := func(test: Callable) -> bool: return looks.any(test)
	assert_true(has.call(func(look: PassengerLook) -> bool: return look.is_child() and look.carry == "backpack"), "A schoolchild")
	assert_true(has.call(func(look: PassengerLook) -> bool: return look.top_style == "scrubs"), "A nurse")
	assert_true(has.call(func(look: PassengerLook) -> bool: return look.carry == "briefcase"), "An office worker")
	assert_true(has.call(func(look: PassengerLook) -> bool: return look.carry == "basket"), "A market seller")
	assert_true(has.call(func(look: PassengerLook) -> bool: return look.is_older() and look.carry == "mochila" and look.stripes.size() >= 3), "A grandmother with a woven mochila")
	assert_true(has.call(func(look: PassengerLook) -> bool: return look.hat == "vueltiao"), "A sombrero vueltiao")
	assert_true(has.call(func(look: PassengerLook) -> bool: return look.hair_style == "braids"), "Long braids")
	assert_true(has.call(func(look: PassengerLook) -> bool: return look.top_style == "guayabera"), "A guayabera")
	assert_true(has.call(func(look: PassengerLook) -> bool: return look.hat == "hard_hat"), "A construction worker")
	assert_true(has.call(func(look: PassengerLook) -> bool: return look.carry == "baby"), "A young mother")
	assert_true(has.call(func(look: PassengerLook) -> bool: return look.carry == "bucket"), "A fisherman")
	assert_true(has.call(func(look: PassengerLook) -> bool: return look.top.r > 0.9 and look.top.g > 0.7 and look.top.b < 0.3), "A plain yellow shirt")


func test_every_look_and_vendor_builds_a_body_arm_and_leg() -> void:
	for look in cast.looks + cast.vendors:
		assert_true(_builds(look), look.id)


func test_every_option_builds_and_shows() -> void:
	var plain := PassengerLook.new()
	plain.hair_style = "bald"
	var base := _vertices(PassengerFigure.build_body(plain, material))
	var options := {
		"hair_style": HeadParts.HAIR_STYLES, "beard": HeadParts.BEARDS, "hat": HeadParts.HATS,
		"top_style": PassengerLook.TOP_STYLES, "carry": PassengerLook.CARRIES,
	}
	for key: String in options:
		for value: String in options[key]:
			var look := PassengerLook.new()
			look.hair_style = "bald"
			look.set(key, value)
			assert_true(_builds(look), "%s %s" % [key, value])
			if value not in ["", "bald", "shirt"]:
				assert_gt(_vertices(PassengerFigure.build_body(look, material)), base, "%s %s shows" % [key, value])
	for sleeves: String in PassengerLook.SLEEVES:
		var look := PassengerLook.new()
		look.sleeves = sleeves
		assert_true(_builds(look), sleeves)
	for lower: String in PassengerLook.LOWER_STYLES:
		var look := PassengerLook.new()
		look.lower_style = lower
		look.socks = Color.WHITE
		assert_true(_builds(look), lower)


func test_a_long_skirt_sways_instead_of_striding() -> void:
	var look := PassengerLook.new()
	assert_eq(PassengerFigure.leg_swing(look), 1.0)
	look.lower_style = "long_skirt"
	look.lower = Color(0.9, 0.1, 0.9)
	assert_lt(PassengerFigure.leg_swing(look), 1.0)
	assert_false(_has_colour(PassengerFigure.build_leg(look, material), look.lower), "One panel, not two swinging legs")
	var low := _colour_points(PassengerFigure.build_body(look, material), look.lower)
	assert_lt(Array(low).map(func(p: Vector3) -> float: return p.y).min(), 0.2, "Down to the ankles")


## Vertex colours are stored at eight bits a channel, so close is equal.
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.02


func _has_colour(mesh: ArrayMesh, colour: Color) -> bool:
	return not _colour_points(mesh, colour).is_empty()


## Where the vertices of one colour are.
func _colour_points(mesh: ArrayMesh, colour: Color) -> PackedVector3Array:
	var found := PackedVector3Array()
	var arrays := mesh.surface_get_arrays(0)
	for i in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		if _near(arrays[Mesh.ARRAY_COLOR][i], colour):
			found.append(arrays[Mesh.ARRAY_VERTEX][i])
	return found


func test_necklines_show_in_front_of_the_shoulders() -> void:
	for style: String in ["guayabera", "scrubs", "dress"]:
		var look := PassengerLook.new()
		look.top_style = style
		look.skin = Color(0.9, 0.1, 0.9)
		look.trim = Color(0.1, 0.9, 0.9)
		var neck := look.skin if style != "dress" else look.trim
		var points := _colour_points(PassengerFigure.build_body(look, material), neck)
		var front := Array(points).filter(func(p: Vector3) -> bool: return p.y > 1.44 and p.y < 1.56)
		assert_false(front.is_empty(), style)
		var nearest: float = front.map(func(p: Vector3) -> float: return p.z).min()
		assert_lt(nearest, -0.125, "%s stands in front of the yoke" % style)


func test_things_carried_in_the_hand_stay_clear_of_the_paying_arm() -> void:
	for carry: String in ["basket", "handbag", "briefcase", "bucket", "books", "cool_box", "mochila"]:
		var look := PassengerLook.new()
		look.carry = carry
		look.carry_colour = Color(0.9, 0.1, 0.9)
		var points := _colour_points(PassengerFigure.build_body(look, material), look.carry_colour)
		assert_false(points.is_empty(), carry)
		assert_lt(Array(points).map(func(p: Vector3) -> float: return p.x).max(), 0.0, "%s on the left" % carry)
	var elder := PassengerLook.new()
	elder.cane = true
	var cane := _colour_points(PassengerFigure.build_body(elder, material), PassengerFigure.CANE)
	assert_lt(Array(cane).map(func(p: Vector3) -> float: return p.x).max(), 0.0, "The cane too")
	assert_gt(PassengerFigure.SHOULDER.x, 0.0, "The right arm, which pays and waves, hangs at +x")


func test_a_headwrap_covers_the_hair() -> void:
	var look := PassengerLook.new()
	look.hair_style = "braids"
	look.hair = Color(0.9, 0.1, 0.9)
	assert_true(_has_colour(PassengerFigure.build_body(look, material), look.hair))
	look.hat = "headwrap"
	assert_false(_has_colour(PassengerFigure.build_body(look, material), look.hair))


func test_a_mochila_has_at_most_five_bands() -> void:
	var bands := []
	for i in 7:
		bands.append([0.1 * i, 0.5, 0.5])
	var entry := {"id": "a", "skin": [0.5, 0.4, 0.3], "top": [0, 0, 1], "carry": "mochila", "stripes": bands}
	assert_eq(PassengerLook.from_data(entry).stripes.size(), PassengerFigure.MAX_STRIPES)
	var problems := PassengerLooks.check({"looks": [entry]})
	assert_true(problems.any(func(problem: String) -> bool: return problem.contains("stripes")))


func test_from_afar_a_hat_shows_instead_of_hair() -> void:
	var look := PassengerLook.from_data({"hair": [0.1, 0.1, 0.1], "hat": "hard_hat", "hat_colour": [1, 1, 0]})
	assert_eq(look.crown_colour(), Color(1, 1, 0))
	look.hat = "vueltiao"
	assert_eq(look.crown_colour(), HeadParts.STRAW)
	look.hat = ""
	assert_eq(look.crown_colour(), look.hair)


func test_damaged_entries_fall_back_to_safe_values() -> void:
	var plain := PassengerLook.new()
	var damaged := {
		"id": 5, "skin": "brown", "size": "big", "pace": -3, "hat": 4, "carry": "piano", "top_style": null,
		"hair": [0.1, "x", 0.1], "stripes": [[1, 0, 0], "red", [0, 1]], "glasses": "yes",
	}
	var look := PassengerLook.from_data(damaged)
	assert_eq(look.id, plain.id)
	assert_eq(look.skin, plain.skin)
	assert_eq(look.hair, plain.hair)
	assert_eq(look.size, 1.0)
	assert_eq(look.pace, PassengerLook.PACES.x, "Clamped, so nobody stands still")
	assert_eq(look.hat, "")
	assert_eq(look.carry, "")
	assert_eq(look.top_style, "shirt")
	assert_eq(look.stripes.size(), 1)
	assert_false(look.glasses)
	assert_true(_builds(look))
	var giant := PassengerLook.from_data({"size": 40, "pace": 9})
	assert_eq(giant.size, PassengerLook.SIZES.y)
	assert_eq(giant.pace, PassengerLook.PACES.y)


func test_bad_data_never_crashes_and_still_gives_a_crowd() -> void:
	var broken_data: Array = [null, 7, "text", [], {}, {"looks": "everyone"}, {"looks": [1, "a", null]}, {"looks": [], "vendors": 3}]
	for data: Variant in broken_data:
		var broken := PassengerLooks.from_data(data)
		assert_gt(broken.looks.size(), 0, str(data))
		assert_gt(broken.vendors.size(), 0, str(data))
		assert_true(_builds(broken.looks[0]), str(data))
	for path: String in ["res://nowhere/passengers.json", BROKEN, ""]:
		assert_gt(PassengerLooks.read(path).looks.size(), 0, path)
	assert_null(PassengerLooks.parse_file(BROKEN))


func test_check_says_what_is_wrong() -> void:
	assert_false(PassengerLooks.check(null).is_empty())
	assert_false(PassengerLooks.check({}).is_empty())
	assert_false(PassengerLooks.check({"looks": []}).is_empty())
	assert_false(PassengerLooks.check({"looks": [{"id": "a", "skin": [0.5, 0.4, 0.3], "top": [0, 0, 1]}], "vendors": 3}).is_empty())
	var problems := PassengerLooks.check({"looks": [
		{"id": "a", "skin": [0.5, 0.4, 0.3], "top": [0, 0, 1], "hat": "crown"},
		{"id": "a", "skin": [0.5, 0.4, 0.3], "top": [0, 0, 1], "size": 3, "hair_style": 2},
		{"skin": "brown", "top": [0, 0, 1], "stripes": ["red"]},
		{"id": "c", "skin": [200, 150, 120], "top": [0, 0, 255]},
		12,
	]})
	for words: String in ["unknown hat", "unknown hair_style", "twice", "size", "no id", "skin colour", "top colour", "stripes", "not an object"]:
		assert_true(problems.any(func(problem: String) -> bool: return problem.contains(words)), words)
