extends Node
## Languages: each country's pack lists the ones it offers and where their text
## lives. English needs no file, because the text in the code is the English.

var font: Font


func _ready() -> void:
	_load_translations()
	_build_font()
	GameSettings.changed.connect(apply)
	apply()


## Follows the setting, or the phone's language the first time the game runs.
func apply() -> void:
	var wanted := resolve(GameSettings.language, OS.get_locale_language())
	if TranslationServer.get_locale() != wanted:
		TranslationServer.set_locale(wanted)


## The player's choice, then the phone's language, then the country's own. A plain
## language matches its regional version, so Spanish phones get Colombian Spanish.
static func resolve(setting: String, phone_language: String) -> String:
	for choice: String in [setting, phone_language]:
		if choice == "":
			continue
		for language: Dictionary in Country.pack.languages():
			var code: String = language["code"]
			if code == choice or code.get_slice("_", 0) == choice.get_slice("_", 0):
				return code
	return Country.pack.data["default_language"]


func _load_translations() -> void:
	for language: Dictionary in Country.pack.languages():
		if not language.has("file"):
			continue
		var entries: Dictionary = MapLoader.read_json(Country.pack.resolve(language["file"]))
		var translation := Translation.new()
		translation.locale = language["code"]
		for key: String in entries:
			translation.add_message(key, entries[key])
		TranslationServer.add_translation(translation)


## Every piece of text uses this font, which falls back to any script the pack needs.
func _build_font() -> void:
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	var fallbacks: Array[Font] = []
	for path: String in Country.pack.data["fonts"]:
		fallbacks.append(load(path))
	variation.fallbacks = fallbacks
	font = variation
	ThemeDB.fallback_font = variation
	UiStyle.apply(variation)
