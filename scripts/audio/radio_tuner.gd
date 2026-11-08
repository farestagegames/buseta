class_name RadioTuner
extends RefCounted
## The bus radio's dial: off, then each of the pack's stations in turn, then off
## again. Each station plays its tracks in order and goes back to the first after
## the last. Pure logic: AudioDirector plays what it says.

var stations: Array = []
## -1 is off.
var index: int = -1
var _track: Dictionary = {} ## Station id to the index of its current track.


## saved_id is the station the player left on last time. Each station starts on a
## track picked by the seed, so the first song is not always the same.
func _init(station_list: Array = [], saved_id: String = "", seed_value: int = 0) -> void:
	stations = station_list
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for i in stations.size():
		var count: int = (stations[i]["tracks"] as Array).size()
		_track[stations[i]["id"]] = random.randi_range(0, count - 1) if count > 0 else 0
		if stations[i]["id"] == saved_id:
			index = i


func has_stations() -> bool:
	return not stations.is_empty()


func is_on() -> bool:
	return index >= 0


func station() -> Dictionary:
	return stations[index] if is_on() else {}


## The id to save, or "" when the radio is off.
func station_id() -> String:
	return str(station().get("id", ""))


## Off, first station, second station... and back to off.
func next_station() -> Dictionary:
	if stations.is_empty():
		return {}
	index = index + 1 if index + 1 < stations.size() else -1
	return station()


func track() -> Dictionary:
	if not is_on():
		return {}
	var tracks: Array = station()["tracks"]
	return tracks[int(_track[station_id()]) % tracks.size()] if not tracks.is_empty() else {}


## Called when a track ends: the station moves on to its next track.
func track_finished() -> Dictionary:
	if not is_on():
		return {}
	var tracks: Array = station()["tracks"]
	_track[station_id()] = (int(_track[station_id()]) + 1) % maxi(tracks.size(), 1)
	return track()


## Everything wrong with a pack's radio list. Files are checked by CountryPack.
static func check(station_list: Array) -> Array[String]:
	var problems: Array[String] = []
	var ids := {}
	for entry: Variant in station_list:
		if not entry is Dictionary:
			problems.append("Radio stations must be objects")
			continue
		for key: String in ["id", "name", "frequency"]:
			var value: Variant = (entry as Dictionary).get(key)
			if not value is String or (value as String).strip_edges() == "":
				problems.append("Radio station needs %s as some text" % key)
		if not (entry as Dictionary).has("tracks"):
			problems.append("Radio station needs tracks")
		var id := str(entry.get("id", ""))
		if ids.has(id):
			problems.append("Radio has %s twice" % id)
		ids[id] = true
		var tracks: Variant = entry.get("tracks", [])
		if not tracks is Array or (tracks as Array).is_empty():
			problems.append("Radio station %s needs at least one track" % id)
			continue
		for item: Variant in tracks:
			if not item is Dictionary or not (item as Dictionary).has("file"):
				problems.append("Radio station %s has a track with no file" % id)
	return problems
