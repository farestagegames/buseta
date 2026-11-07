class_name PassengerLooks
extends RefCounted
## Everyone who can ride, read from a pack's passengers file: the looks people in
## the street and on the bus are drawn from, and the vendors. Pure logic. A missing
## or damaged file still gives a crowd, and check() lists what is wrong with one.

var looks: Array[PassengerLook] = []
var vendors: Array[PassengerLook] = []


static func read(path: String) -> PassengerLooks:
	return from_data(parse_file(path))


## The file's contents, or null if it is missing or not JSON. Never raises an error.
static func parse_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data


## Entries that are not objects are skipped. With nothing usable left, one default
## person stands in, so the game always has someone to show.
static func from_data(data: Variant) -> PassengerLooks:
	var cast := PassengerLooks.new()
	var section: Dictionary = data if data is Dictionary else {}
	cast.looks = _looks_in(section.get("looks"))
	cast.vendors = _looks_in(section.get("vendors"))
	if cast.looks.is_empty():
		cast.looks.append(PassengerLook.new())
	if cast.vendors.is_empty():
		cast.vendors.append(cast.looks[0])
	return cast


static func _looks_in(list: Variant) -> Array[PassengerLook]:
	var found: Array[PassengerLook] = []
	if list is Array:
		for entry: Variant in list:
			if entry is Dictionary:
				found.append(PassengerLook.from_data(entry))
	return found


## Everything wrong with a passengers file's contents, or nothing if it is usable.
static func check(data: Variant) -> Array[String]:
	if not data is Dictionary:
		return ["The passengers file could not be read"]
	var problems: Array[String] = []
	var look_list: Variant = (data as Dictionary).get("looks")
	if not look_list is Array or (look_list as Array).is_empty():
		problems.append("The passengers file needs a list of looks")
	else:
		_check_list(problems, look_list, "look")
	var vendor_list: Variant = (data as Dictionary).get("vendors", [])
	if not vendor_list is Array:
		problems.append("Passenger vendors must be a list")
	else:
		_check_list(problems, vendor_list, "vendor")
	return problems


static func _check_list(problems: Array[String], list: Array, label: String) -> void:
	var ids := {}
	for i in list.size():
		var entry: Variant = list[i]
		if not entry is Dictionary:
			problems.append("Passenger %s %d is not an object" % [label, i])
			continue
		var title := "Passenger %s %s" % [label, str(entry.get("id", i))]
		if not entry.get("id") is String:
			problems.append("%s has no id" % title)
		elif ids.has(entry["id"]):
			problems.append("%s appears twice" % title)
		else:
			ids[entry["id"]] = true
		_check_entry(problems, entry, title)


static func _check_entry(problems: Array[String], entry: Dictionary, title: String) -> void:
	for key: String in ["skin", "top"]:
		if not PassengerLook.is_colour(entry.get(key)):
			problems.append("%s needs a %s colour of three numbers from 0 to 1" % [title, key])
	for key: String in ["hair", "trim", "lower", "socks", "shoes", "hat_colour", "carry_colour"]:
		if entry.has(key) and not PassengerLook.is_colour(entry[key]):
			problems.append("%s has a bad %s colour" % [title, key])
	var choices := {
		"hair_style": HeadParts.HAIR_STYLES, "beard": HeadParts.BEARDS, "hat": HeadParts.HATS,
		"top_style": PassengerLook.TOP_STYLES, "sleeves": PassengerLook.SLEEVES,
		"lower_style": PassengerLook.LOWER_STYLES, "carry": PassengerLook.CARRIES,
	}
	for key: String in choices:
		if entry.has(key) and not (entry[key] is String and (choices[key] as Array).has(entry[key])):
			problems.append("%s has an unknown %s: %s" % [title, key, str(entry[key])])
	var ranges := {"size": PassengerLook.SIZES, "pace": PassengerLook.PACES}
	for key: String in ranges:
		var limits: Vector2 = ranges[key]
		var value: Variant = entry.get(key, 1.0)
		if not (value is float or value is int) or float(value) < limits.x or float(value) > limits.y:
			problems.append("%s needs a %s from %s to %s" % [title, key, limits.x, limits.y])
	var bands: Variant = entry.get("stripes", [])
	if not bands is Array or not (bands as Array).all(func(band: Variant) -> bool: return PassengerLook.is_colour(band)):
		problems.append("%s has bad stripes" % title)
	elif (bands as Array).size() > PassengerFigure.MAX_STRIPES:
		problems.append("%s has more than %d stripes" % [title, PassengerFigure.MAX_STRIPES])
