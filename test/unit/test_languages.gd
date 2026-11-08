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
	"RADIO", "RADIO OFF", "Horn",
]

const SPANISH := "res://data/packs/colombia/lang/es_CO.json"

## Words from Spain or textbook Spanish that a Colombian driver would not use.
## Each has a Colombian word in the translations instead. The last three keep out
## "usted" and Spain's "vosotros": the game speaks to the player as "tú".
const NOT_COLOMBIAN: Array[String] = [
	"autobús", "autobuses", "bordillo", "bordillos", "pulsa", "pulsar", "badén", "badenes",
	"bocina", "rotonda", "intermitente", "conducir", "conduce", "conducción", "coche", "móvil",
	"aparcar", "aparca", "ajustes", "puntuación", "marcha", "recto", "retraso", "maletero",
	"vosotros", "os", "usted",
]

## Text in the code that stays English on purpose: checks only developers read,
## the hidden test cheats, and a default the catalog always replaces.
const ENGLISH_ONLY: Array[String] = [
	"The pack file could not be read", "language file %s", "sound %s", "horn %s", "radio track", "ambience %s",
	"content file %s", "bus %s", "Driver %s", "The passengers file could not be read",
	"Passenger %s %s", "Skip to next stop", "Finish shift", "City 12",
]

## Statements that never hold text a player sees. They are skipped only when the
## line starts with one, so text shown on the same line is still checked.
const NOT_SHOWN := ["push_error(", "push_warning(", "print(", "problems.append(", "assert(", "@export_group"]

## English words that would give away an English name in a Spanish city.
const ENGLISH_PLACE_WORDS: Array[String] = [
	"street", "road", "lane", "avenue", "square", "park", "market", "station", "bridge", "stop",
	"school", "beach", "hill", "north", "south", "east", "west", "old", "new", "the",
]

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


## Finds text a player could see anywhere in the code: anything with a space, a
## short capital label such as "PITO", or a capitalised word that is not a Godot
## class name. Each must have a Colombian Spanish entry or be English only on purpose.
func test_every_visible_string_in_the_code_has_a_translation() -> void:
	var files: Array[String] = []
	_scripts_in("res://scripts", files)
	var literal := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var placeholder := RegEx.create_from_string("%[.\\d]*[dsf]")
	var not_letters := RegEx.create_from_string("[^\\p{L}]")
	var caps_label := RegEx.create_from_string("^[A-Z◀▶ ]+$")
	var word := RegEx.create_from_string("^[A-Z][a-záéíóúñ]+$")
	# A node path is never shown, but the rest of its line might be.
	var node_path := RegEx.create_from_string("get_node\\(\"(?:[^\"\\\\]|\\\\.)*\"\\)")
	var checked := 0
	for path in files:
		if path.ends_with("cheat_panel.gd"):
			continue
		var number := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			number += 1
			var code := line.strip_edges()
			if code.begins_with("#") or NOT_SHOWN.any(func(marker: String) -> bool: return code.begins_with(marker)):
				continue
			for hit in literal.search_all(node_path.sub(line, "get_node()", true)):
				var text := hit.get_string(1).replace("\\n", "\n")
				if text.begins_with("res://") or text.begins_with("user://"):
					continue
				if not_letters.sub(placeholder.sub(text, "", true), "", true).length() < 2:
					continue
				var shown := text.contains(" ") or caps_label.search(text) != null \
					or (word.search(text) != null and not ClassDB.class_exists(text))
				if not shown or ENGLISH_ONLY.has(text):
					continue
				checked += 1
				assert_true(strings.has(text), "%s:%d needs a translation for \"%s\"" % [path.get_file(), number, text])
	assert_gt(checked, 150, "The scan should find the game's text")


func test_no_spanish_from_spain_in_the_translations() -> void:
	var words := RegEx.create_from_string("\\p{L}+")
	for key: String in strings:
		for hit in words.search_all((strings[key] as String).to_lower()):
			assert_false(NOT_COLOMBIAN.has(hit.get_string()), "\"%s\" in: %s" % [hit.get_string(), strings[key]])


## The same thing always has the same Colombian word.
func test_one_word_for_each_thing() -> void:
	var values := " ".join(strings.values()).to_lower()
	for pair: Array in [["volante", "timón"], ["colisión", "choque"], ["frenada", "frenazo"],
			["desafío", "reto"], ["teléfono", "celular"], ["baliza", "marca"], ["marcha", "cambio"]]:
		assert_false(values.contains(pair[0]), "Use \"%s\", not \"%s\"" % [pair[1], pair[0]])


func test_short_capital_labels_stay_short_and_in_capitals() -> void:
	for key: String in strings:
		if key.length() > 1 and key == key.to_upper() and key.contains("%") == false and key != "km/h":
			var value: String = strings[key]
			assert_eq(value, value.to_upper(), "%s stays in capitals" % key)
			assert_lte(value.length(), maxi(key.length() + 6, 9), "%s -> %s is too long for its button" % [key, value])


func test_tutorial_and_opening_text_have_translations() -> void:
	for step: Dictionary in TutorialScript.STEPS:
		assert_true(strings.has(step["text"]), step["text"])
	for caption in IntroCutscene.CAPTIONS:
		assert_true(strings.has(caption), caption)
	for view: Dictionary in CameraRig.VIEWS:
		assert_true(strings.has(view["name"]), view["name"])
	for key: String in ShiftEndPanel.CATEGORY_NAMES.values():
		assert_true(strings.has(key), key)


## Stop and street names are Spanish proper names, shown the same in both languages,
## so none may slip in as an English name.
func test_stop_and_street_names_are_spanish_in_both_languages() -> void:
	var words := RegEx.create_from_string("\\p{L}+")
	var names: Array[String] = []
	for item: Dictionary in Profile.catalog.items(Catalog.ROUTES):
		var route := MapLoader.read_json(Country.pack.resolve(item["file"]))
		for stop: Dictionary in route.get("stops", []):
			names.append(stop["name"])
		for road: Dictionary in MapLoader.read_map_of(route).get("roads", []):
			if road.has("name"):
				names.append(road["name"])
	assert_gt(names.size(), 20)
	for place in names:
		for hit in words.search_all(place.to_lower()):
			assert_false(ENGLISH_PLACE_WORDS.has(hit.get_string()), "%s looks English" % place)


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


## Horn names show in the garage. Station names are names, the same in every
## language, so they need none.
func test_every_horn_name_has_a_translation() -> void:
	for item: Dictionary in Country.pack.horns():
		assert_true(strings.has(item["name"]), item["name"])


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


## First launch: Colombian Spanish, unless the phone is in English.
func test_first_launch_is_colombian_spanish_unless_the_phone_is_english() -> void:
	var fresh: Node = load("res://scripts/core/game_settings.gd").new()
	assert_eq(fresh.language, "", "No saved choice on first launch")
	fresh.apply_saved({})
	assert_eq(fresh.language, "", "An old save without a language still follows the phone")
	for phone: String in ["en", "en_US", "en_GB"]:
		assert_eq(Lang.resolve(fresh.language, phone), "en", phone)
	for phone: String in ["es", "es_CO", "es_ES", "pt_BR", "fr", "ar", "zh_CN", ""]:
		assert_eq(Lang.resolve(fresh.language, phone), "es_CO", phone)
	fresh.free()


## The live path: with no saved choice, the game follows the real phone language.
func test_apply_follows_the_phone_when_nothing_is_saved() -> void:
	var saved: String = GameSettings.language
	GameSettings.set_block_signals(true)
	GameSettings.language = ""
	Lang.apply()
	assert_eq(TranslationServer.get_locale(), Lang.resolve("", OS.get_locale_language()))
	GameSettings.language = saved
	GameSettings.set_block_signals(false)
	Lang.apply()


func test_a_saved_choice_beats_the_phone() -> void:
	assert_eq(Lang.resolve("en", "es"), "en")
	assert_eq(Lang.resolve("es_CO", "en_US"), "es_CO")


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
