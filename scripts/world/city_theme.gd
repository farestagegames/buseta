class_name CityTheme
extends RefCounted
## How a city looks, read from the "theme" block of its map. A map with no theme
## keeps the plain colours below, so the look of each city is data, not code.

var walls: Array[Color] = [Color(0.86, 0.66, 0.54), Color(0.8, 0.8, 0.8), Color(0.9, 0.8, 0.66)]
var roofs: Array[Color] = [Color(0.42, 0.24, 0.2), Color(0.3, 0.3, 0.34)]
var awnings: Array[Color] = [Color(0.7, 0.2, 0.18), Color(0.2, 0.3, 0.55)]
var leaves: Array[Color] = [Color(0.27, 0.42, 0.2)]
var car_colours: Array[Color] = [Color(0.2, 0.3, 0.55), Color(0.75, 0.75, 0.78)]
var bunting: Array[Color] = [Color(0.9, 0.2, 0.2), Color(0.95, 0.8, 0.2), Color(0.2, 0.4, 0.8)]
var grass_a := Color(0.62, 0.66, 0.56)
var grass_b := Color(0.68, 0.71, 0.6)
var sand := Color(0.93, 0.84, 0.64)
var sea := Color(0.1, 0.5, 0.62)
var palm_trunk := Color(0.5, 0.4, 0.3)
var palm_leaf := Color(0.26, 0.5, 0.2)
var palm_share: float = 0.0
var house_share: float = 0.3
var office_share: float = 0.2
var lowest_storeys: int = 3
var highest_storeys: int = 5
var chimneys: bool = true
var bunting_every: float = 0.0
var street_gap: float = 2.5 ## From the pavement to the buildings.
var gap_low: float = 3.0 ## Least space between two buildings.
var gap_high: float = 11.0
var trees_on_pavement: bool = false
var width_low: float = 12.0 ## Width of a building along the street.
var width_high: float = 24.0
var sky_top := Color(0.38, 0.58, 0.82)
var sky_horizon := Color(0.8, 0.85, 0.88)
var fog := Color(0.78, 0.83, 0.87)
var fog_scale: float = 1.0 ## Scale for morning/dawn fog on this map.
var ambient := Color(0.72, 0.74, 0.78)
var ambient_energy: float = 0.62
var sun_colour := Color(1.0, 0.97, 0.9)
var sun_energy: float = 0.82


static func from_data(map_data: Dictionary) -> CityTheme:
	var theme := CityTheme.new()
	var data: Dictionary = map_data.get("theme", {})
	for key: String in ["walls", "roofs", "awnings", "leaves", "car_colours", "bunting"]:
		if data.has(key):
			var colours: Array[Color] = []
			for value: Array in data[key]:
				colours.append(Color(value[0], value[1], value[2]))
			if not colours.is_empty():
				theme.set(key, colours)
	for key: String in ["grass_a", "grass_b", "sand", "sea", "palm_trunk", "palm_leaf", "sky_top", "sky_horizon",
			"fog", "ambient", "sun_colour"]:
		var value: Variant = data.get(key)
		if value is Array and (value as Array).size() >= 3:
			theme.set(key, Color(float(value[0]), float(value[1]), float(value[2])))
	for key: String in ["palm_share", "house_share", "office_share", "bunting_every", "ambient_energy", "sun_energy", "street_gap", "gap_low", "gap_high", "width_low", "width_high"]:
		if data.has(key):
			theme.set(key, float(data[key]))
	theme.lowest_storeys = int(data.get("lowest_storeys", theme.lowest_storeys))
	theme.highest_storeys = int(data.get("highest_storeys", theme.highest_storeys))
	theme.chimneys = data.get("chimneys", theme.chimneys)
	theme.trees_on_pavement = data.get("trees_on_pavement", theme.trees_on_pavement)
	theme.fog_scale = float(data.get("fog_scale", map_data.get("fog_scale", theme.fog_scale)))
	return theme
