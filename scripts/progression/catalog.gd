class_name Catalog
extends RefCounted
## Everything a player can unlock, read from data/catalog.json.

const ROUTES := "routes"
const BUSES := "buses"
const LIVERIES := "liveries"
const DRIVERS := "drivers"
const PATH := "res://data/catalog.json"

var data: Dictionary


func _init(catalog_data: Dictionary = {}) -> void:
	data = catalog_data if not catalog_data.is_empty() else MapLoader.read_json(PATH)


func items(kind: String) -> Array:
	return data[kind]


func find(kind: String, id: String) -> Dictionary:
	for item: Dictionary in data[kind]:
		if item["id"] == id:
			return item
	return {}
