extends Node
## Languages: loads the translations, adds fonts for Hindi and Arabic, and keeps
## the game's locale matched to the player's setting. Text is translated from
## data/lang/strings.json, keyed by the English text.

const PATH := "res://data/lang/strings.json"
const LOCALES: Array[String] = ["fr", "es", "pt", "hi", "ar"] ## Order of each entry in the file.
const LANGUAGES: Array[Dictionary] = [
	{"code": "en", "name": "English"}, {"code": "fr", "name": "Français"},
	{"code": "es", "name": "Español"}, {"code": "pt", "name": "Português"},
	{"code": "hi", "name": "हिन्दी"}, {"code": "ar", "name": "العربية"},
]
const HINDI_FONT := "res://assets/fonts/NotoSansDevanagari-Regular.ttf"
const ARABIC_FONT := "res://assets/fonts/NotoSansArabic-Regular.ttf"

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


static func resolve(setting: String, phone_language: String) -> String:
	var choice := setting if setting != "" else phone_language
	for language: Dictionary in LANGUAGES:
		if language["code"] == choice:
			return choice
	return "en"


func _load_translations() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var entries: Dictionary = parsed
	for i in LOCALES.size():
		var translation := Translation.new()
		translation.locale = LOCALES[i]
		for key: String in entries:
			var values: Array = entries[key]
			translation.add_message(key, values[i])
		TranslationServer.add_translation(translation)


## Every piece of text uses this font, which falls back to the right script.
func _build_font() -> void:
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	variation.fallbacks = [load(HINDI_FONT), load(ARABIC_FONT)]
	font = variation
	ThemeDB.fallback_font = variation
	get_tree().root.theme = UiStyle.build(variation)
