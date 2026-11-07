class_name Catalog
extends RefCounted
## Everything a player can unlock, read from data/catalog.json.

const ROUTES := "routes"
const BUSES := "buses"
const LIVERIES := "liveries"
const DRIVERS := "drivers"

var data: Dictionary


## Reads the current country's catalog unless given one, as tests do.
func _init(catalog_data: Dictionary = {}) -> void:
	if not catalog_data.is_empty():
		data = catalog_data
		return
	data = MapLoader.read_json(Country.pack.content_path("catalog"))
	for kind: String in data:
		for item: Dictionary in data[kind]:
			if item.has("file"):
				item["file"] = Country.pack.resolve(item["file"])


func items(kind: String) -> Array:
	return data[kind]


func find(kind: String, id: String) -> Dictionary:
	for item: Dictionary in data[kind]:
		if item["id"] == id:
			return item
	return {}
