extends GutTest
## Guards the translations: nothing missing, and no text that could crash.

const LIVE_LABELS: Array[String] = [
	"VIEW", "MENU", "◀ IND", "IND ▶", "DOORS", "HORN", "GO", "BRAKE", "km/h", "DOORS OPEN",
	"Cockpit", "Close", "Far", "Speed bump ahead", "Kerb strike", "Emergency stop", "Collision",
	"Too fast over a bump", "Ran a red light", "No indicator", "Hit a cone", "Hit a bin", "Hit a crate",
	"Hit a barrier", "Hit a stall", "Hit a motorbike", "Punctuality", "Stopping accuracy", "Smooth driving", "Traffic rules",
	"Passenger satisfaction", "Home", "Routes", "Garage", "Drivers", "Career", "Settings", "Paused",
	"Wheel", "Tilt", "Buttons", "Tilt the phone to steer", "Invert tilt", "Resume", "Recover bus",
	"Quit shift", "Drive again", "Main menu", "Language", "Start shift", "Daily challenge",
	"Buses", "Liveries", "Selected", "Select", "Achievements",
	"Roundabout: go straight on", "Roundabout: exit right", "Roundabout: exit left",
	"Turn right", "Turn left", "Straight on at the junction", "%d:%02d late", "%d:%02d early", "On time",
]

const SPANISH := "res://data/packs/colombia/lang/es_CO.json"

var strings: Dictionary


func before_all() -> void:
	strings = MapLoader.read_json(SPANISH)


func after_each() -> void:
	TranslationServer.set_locale("en")


func _placeholders(text: String) -> Array[String]:
	var pattern := RegEx.create_from_string("%(\\.\\d+f|\\d*d|s|%|02d)")
	var found: Array[String] = []
	for hit in pattern.search_all(text):
		found.append(hit.get_string())
	found.sort()
	return found


func _scripts_in(path: String, into: Array[String]) -> void:
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".gd"):
			into.append(path + "/" + file)
	for folder in DirAccess.get_directories_at(path):
		_scripts_in(path + "/" + folder, into)


func test_colombian_spanish_comes_first_and_english_second() -> void:
	var languages := Country.pack.languages()
	assert_eq(languages.size(), 2)
	assert_eq(languages[0]["code"], "es_CO")
	assert_eq(languages[1]["code"], "en")
	assert_eq(Country.pack.data["default_language"], "es_CO")


func test_no_translation_is_blank() -> void:
	for key: String in strings:
		assert_ne((strings[key] as String).strip_edges(), "", key)


func test_placeholders_survive_translation() -> void:
	for key: String in strings:
		assert_eq(_placeholders(strings[key]), _placeholders(key), "%s -> %s" % [key, strings[key]])


func test_every_format_string_formats_without_error() -> void:
	for key: String in strings:
		var value: String = strings[key]
		if _in_text_order(value).is_empty():
			continue
		assert_ne(_format(value, _reordered(value, key, [])), "", value)


func _in_text_order(text: String) -> Array[String]:
	var pattern := RegEx.create_from_string("%(?:\\.\\d+f|\\d*d|s)")
	var found: Array[String] = []
	for hit in pattern.search_all(text):
		found.append(hit.get_string().right(1))
	return found


## Translations may put a word and a number in a different order.
func _reordered(value: String, _key: String, _arguments: Array) -> Array:
	var ordered := []
	for slot: String in _in_text_order(value):
		ordered.append("x" if slot == "s" else 1)
	return ordered


func _format(text: String, arguments: Array) -> String:
	return text % arguments


func test_mixed_placeholders_stay_in_the_same_order() -> void:
	for key: String in strings:
		var original := _in_text_order(key)
		if original.has("s") and original.size() > 1:
			assert_eq(_in_text_order(strings[key]), original, "%s must keep its argument order" % key)


func test_every_tr_call_in_the_code_has_a_translation() -> void:
	var files: Array[String] = []
	_scripts_in("res://scripts", files)
	var pattern := RegEx.create_from_string("\\btr\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)")
	for path in files:
		var source := FileAccess.get_file_as_string(path)
		for hit in pattern.search_all(source):
			var key := hit.get_string(1).replace("\\n", "\n")
			assert_true(strings.has(key), "%s: missing translation for %s" % [path.get_file(), key])


func test_labels_shown_at_runtime_have_translations() -> void:
	for key in LIVE_LABELS:
		assert_true(strings.has(key), key)


func test_every_catalog_and_challenge_text_has_a_translation() -> void:
	var catalog := Catalog.new()
	for kind: String in [Catalog.ROUTES, Catalog.BUSES, Catalog.LIVERIES, Catalog.DRIVERS]:
		for item: Dictionary in catalog.items(kind):
			if kind != Catalog.BUSES and kind != Catalog.DRIVERS:
				assert_true(strings.has(item["name"]), item["name"])
			if item.has("description"):
				assert_true(strings.has(item["description"]), item["description"])
			if item.has("bio"):
				assert_true(strings.has(item["bio"]), item["bio"])
	for entry: Dictionary in AchievementList.load_list():
		assert_true(strings.has(entry["name"]), entry["name"])
		assert_true(strings.has(entry["description"]), entry["description"])
	for entry: Dictionary in DailyChallenge.load_list():
		assert_true(strings.has(entry["text"]), entry["text"])


func test_every_score_keeper_message_has_a_translation() -> void:
	for key: String in ScoreKeeper.HIT_MESSAGES.values():
		assert_true(strings.has(key), key)
	for key: String in ScoreKeeper.TIPS.values():
		assert_true(strings.has(key), key)


func test_translation_applies_when_the_language_changes() -> void:
	TranslationServer.set_locale("es_CO")
	assert_eq(String(TranslationServer.translate("BRAKE")), "FRENO")
	TranslationServer.set_locale("en")
	assert_eq(String(TranslationServer.translate("BRAKE")), "BRAKE")


func test_phone_language_is_followed_until_the_player_chooses() -> void:
	assert_eq(Lang.resolve("", "en"), "en")
	assert_eq(Lang.resolve("es_CO", "en"), "es_CO")


func test_any_spanish_phone_gets_colombian_spanish() -> void:
	assert_eq(Lang.resolve("", "es"), "es_CO")
	assert_eq(Lang.resolve("", "es_MX"), "es_CO")


func test_a_saved_language_the_country_does_not_offer_falls_back() -> void:
	assert_eq(Lang.resolve("fr", "de"), "es_CO")


func test_unsupported_phone_language_falls_back_to_the_countrys_own() -> void:
	assert_eq(Lang.resolve("", "de"), Country.pack.data["default_language"])
