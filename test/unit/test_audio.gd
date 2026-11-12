extends GutTest
## Horns, street ambience and the radio: the logic behind the sound, and the
## pack data it reads.

const COLOMBIA := "res://data/packs/colombia/pack.json"
const TESTLAND := "res://test/fixtures/packs/testland/pack.json"

const STATIONS := [
	{"id": "uno", "name": "Uno", "frequency": "90.1 FM", "tracks": [{"file": "a.wav"}, {"file": "b.wav"}]},
	{"id": "dos", "name": "Dos", "frequency": "99.9 FM", "tracks": [{"file": "c.wav"}]},
]


func after_each() -> void:
	Country.use_pack(COLOMBIA)


func _broken_pack(changes: Dictionary) -> CountryPack:
	var pack := CountryPack.read(COLOMBIA)
	pack.data = pack.data.duplicate(true)
	pack.data.merge(changes, true)
	return pack


# --- Radio tuner ---

func test_the_radio_cycles_off_then_each_station_then_off() -> void:
	var tuner := RadioTuner.new(STATIONS)
	assert_false(tuner.is_on())
	assert_eq(tuner.next_station()["id"], "uno")
	assert_eq(tuner.next_station()["id"], "dos")
	assert_true(tuner.next_station().is_empty())
	assert_false(tuner.is_on())
	assert_eq(tuner.station_id(), "")
	assert_eq(tuner.next_station()["id"], "uno")


func test_a_station_moves_on_to_its_next_track_and_wraps() -> void:
	var tuner := RadioTuner.new(STATIONS, "uno")
	var first: String = tuner.track()["file"]
	var second: String = tuner.track_finished()["file"]
	assert_ne(first, second)
	assert_eq(tuner.track_finished()["file"], first, "Back to the first after the last")


func test_a_one_track_station_plays_its_track_again() -> void:
	var tuner := RadioTuner.new(STATIONS, "dos")
	assert_eq(tuner.track_finished()["file"], "c.wav")


func test_each_station_keeps_its_place_in_its_tracks() -> void:
	var tuner := RadioTuner.new(STATIONS, "uno")
	var next: String = tuner.track_finished()["file"]
	tuner.next_station()
	tuner.next_station()
	tuner.next_station()
	assert_eq(tuner.station_id(), "uno")
	assert_eq(tuner.track()["file"], next)


func test_the_saved_station_is_restored_and_an_unknown_one_is_off() -> void:
	assert_eq(RadioTuner.new(STATIONS, "dos").station_id(), "dos")
	assert_false(RadioTuner.new(STATIONS, "gone").is_on())


func test_no_stations_means_no_radio() -> void:
	var tuner := RadioTuner.new([])
	assert_false(tuner.has_stations())
	assert_true(tuner.next_station().is_empty())
	assert_true(tuner.track().is_empty())
	assert_true(tuner.track_finished().is_empty())


func test_the_first_track_depends_on_the_seed() -> void:
	var seen := {}
	for seed_value in 12:
		seen[RadioTuner.new(STATIONS, "uno", seed_value).track()["file"]] = true
	assert_eq(seen.size(), 2, "Both tracks can open a shift")


# --- Ambience mixer ---

func _layer(rule: String, extra: Dictionary = {}) -> Dictionary:
	var layer := {"id": rule, "file": "x.wav", "rule": rule, "near": 20.0, "far": 200.0}
	layer.merge(extra, true)
	return layer


func test_the_sea_grows_louder_towards_the_coast() -> void:
	var sea := _layer("sea")
	var mixer := AmbienceMixer.new([sea])
	var last := -1.0
	for distance: float in [400.0, 200.0, 150.0, 100.0, 50.0, 20.0, 0.0]:
		mixer.sea_distance = distance
		assert_gte(mixer.gain(sea), last, "At %d m" % distance)
		last = mixer.gain(sea)
	assert_eq(last, 1.0)
	mixer.sea_distance = 400.0
	assert_eq(mixer.gain(sea), 0.0)
	assert_eq(mixer.volume_db(sea), AmbienceMixer.SILENT_DB)


func test_distance_to_the_sea_comes_from_the_coast_line() -> void:
	assert_eq(AmbienceMixer.distance_to_sea(400.0, 488.0), 88.0)
	assert_eq(AmbienceMixer.distance_to_sea(500.0, 488.0), 0.0, "On the sand")
	assert_eq(AmbienceMixer.distance_to_sea(0.0, GroundSurface.NO_COAST), INF, "No coast, no sea")


func test_the_proximity_curve_is_smooth_between_near_and_far() -> void:
	assert_eq(AmbienceMixer.proximity(5.0, 10.0, 50.0), 1.0)
	assert_almost_eq(AmbienceMixer.proximity(30.0, 10.0, 50.0), 0.5, 0.001)
	assert_eq(AmbienceMixer.proximity(60.0, 10.0, 50.0), 0.0)


func test_vendor_sounds_follow_the_nearest_stall_or_stop() -> void:
	var bell := _layer("vendors")
	var mixer := AmbienceMixer.new([bell])
	assert_eq(mixer.gain(bell), 0.0, "Nothing nearby")
	mixer.stop_distance = 10.0
	assert_eq(mixer.gain(bell), 1.0, "At a bus stop")
	mixer.stop_distance = INF
	mixer.stall_distance = 10.0
	assert_eq(mixer.gain(bell), 1.0, "At a stall")


func test_shop_music_is_heard_at_stalls_and_not_at_bus_stops() -> void:
	var music := _layer("stalls")
	var mixer := AmbienceMixer.new([music])
	mixer.stop_distance = 5.0
	assert_eq(mixer.gain(music), 0.0, "A bus stop is not a shop")
	mixer.stall_distance = 5.0
	assert_eq(mixer.gain(music), 1.0)


func test_the_colombian_shop_music_follows_stalls_only() -> void:
	for layer: Dictionary in CountryPack.read(COLOMBIA).ambience_layers():
		if layer["id"] == "shop_music":
			assert_eq(layer["rule"], "stalls")
		if layer["id"] == "vendor_bell":
			assert_eq(layer["rule"], "vendors")


func test_birds_are_loudest_when_the_bus_stands_still() -> void:
	var birds := _layer("calm")
	var mixer := AmbienceMixer.new([birds])
	assert_eq(mixer.gain(birds), 1.0)
	mixer.speed = 20.0
	assert_almost_eq(mixer.gain(birds), AmbienceMixer.CALM_FLOOR, 0.001)


func test_rain_fades_in_its_layer_and_dries_up_the_birds() -> void:
	var rain := _layer("rain")
	var birds := _layer("calm", {"dry": true})
	var mixer := AmbienceMixer.new([rain, birds])
	assert_eq(mixer.gain(rain), 0.0, "Dry by default until the weather says otherwise")
	mixer.rain = 0.75
	assert_eq(mixer.gain(rain), 0.75)
	assert_almost_eq(mixer.gain(birds), 0.25, 0.001)


func test_shop_music_goes_quiet_while_the_radio_plays() -> void:
	var music := _layer("always", {"radio_ducks": true})
	var mixer := AmbienceMixer.new([music])
	assert_eq(mixer.gain(music), 1.0)
	mixer.radio_on = true
	assert_eq(mixer.gain(music), 0.0)


func test_the_street_dips_under_the_radio_in_every_view() -> void:
	var city := _layer("always", {"radio_ducks_db": -6.0})
	var mixer := AmbienceMixer.new([city])
	assert_eq(mixer.gain(city), 1.0, "Radio off")
	mixer.radio_on = true
	assert_almost_eq(mixer.gain(city), db_to_linear(-6.0), 0.001)
	mixer.in_cockpit = false
	assert_almost_eq(mixer.gain(city), db_to_linear(-6.0 * AmbienceMixer.OUTSIDE_DUCK_SHARE), 0.001, "Half the dip from outside")


func test_the_colombian_city_and_sea_dip_under_the_radio() -> void:
	var dipped := {}
	for layer: Dictionary in CountryPack.read(COLOMBIA).ambience_layers():
		if float(layer.get("radio_ducks_db", 0.0)) < 0.0:
			dipped[layer["id"]] = true
	assert_true(dipped.has("city") and dipped.has("sea"), str(dipped))


func test_a_layer_volume_adds_its_own_level() -> void:
	var mixer := AmbienceMixer.new()
	var layer := _layer("always", {"volume_db": -9.0})
	assert_eq(mixer.volume_db(layer), -9.0)


func test_one_shots_play_now_and_then_within_their_range() -> void:
	var bike := _layer("always", {"id": "bike", "every": [4.0, 8.0]})
	var mixer := AmbienceMixer.new([bike], 3)
	var times: Array[float] = []
	var clock := 0.0
	for i in 6000:
		clock += 0.01
		if not mixer.update(0.01).is_empty():
			times.append(clock)
	assert_between(times.size(), 7, 15, "One every 4 to 8 s over a minute")
	for i in range(1, times.size()):
		assert_between(times[i] - times[i - 1], 3.99, 8.02)


func test_time_since_the_last_motorbike_counts_up_and_resets() -> void:
	var bike := _layer("always", {"id": "bike", "every": [5.0, 5.0]})
	var mixer := AmbienceMixer.new([bike])
	mixer.update(3.0)
	assert_almost_eq(mixer.since("bike"), 3.0, 0.001)
	assert_eq(mixer.update(2.5).size(), 1)
	assert_eq(mixer.since("bike"), 0.0)


func test_a_one_shot_out_of_earshot_waits_for_its_next_turn() -> void:
	var bell := _layer("stalls", {"every": [2.0, 2.0]})
	var mixer := AmbienceMixer.new([bell])
	assert_true(mixer.update(2.5).is_empty(), "No stall nearby")
	mixer.stall_distance = 5.0
	assert_eq(mixer.update(2.5).size(), 1)


func test_bad_ambience_data_is_reported() -> void:
	assert_eq(AmbienceMixer.check([_layer("sea"), _layer("calm")]), [] as Array[String])
	assert_true(AmbienceMixer.check([_layer("sea"), _layer("sea")]).has("Ambience has sea twice"))
	assert_true(AmbienceMixer.check([_layer("thunder")]).has("Ambience thunder has an unknown rule thunder"))
	assert_true(AmbienceMixer.check([_layer("sea", {"near": 300.0})]).has("Ambience sea needs near closer than far"))
	assert_false(AmbienceMixer.check([_layer("always", {"every": [9.0, 3.0]})]).is_empty())
	assert_false(AmbienceMixer.check([{"rule": "always"}]).is_empty())


func test_ambience_value_types_are_checked() -> void:
	assert_true(AmbienceMixer.check([_layer("calm", {"dry": "yes"})]).has("Ambience calm needs dry as true or false"))
	assert_true(AmbienceMixer.check([_layer("calm", {"muffled": 1})]).has("Ambience calm needs muffled as true or false"))
	assert_true(AmbienceMixer.check([_layer("calm", {"radio_ducks": "no"})]).has("Ambience calm needs radio_ducks as true or false"))
	assert_true(AmbienceMixer.check([_layer("calm", {"volume_db": "-6"})]).has("Ambience calm needs volume_db as a number"))
	assert_true(AmbienceMixer.check([_layer("calm", {"radio_ducks_db": 3.0})]).has("Ambience calm needs radio_ducks_db as 0 or less"))
	assert_true(AmbienceMixer.check([_layer("sea", {"near": "close"})]).has("Ambience sea needs near closer than far"))
	assert_eq(AmbienceMixer.check([_layer("calm", {"dry": true, "volume_db": -6.0, "radio_ducks_db": -3.0})]), [] as Array[String])


# --- Horn voice ---

func test_a_steady_horn_loops_while_held_and_fades_when_let_go() -> void:
	var voice := HornVoice.new({"id": "two_tone"})
	assert_eq(voice.press(), HornVoice.Action.START)
	for i in 120:
		assert_eq(voice.update(1.0 / 60.0, fmod(i / 60.0, 1.0), 1.0), HornVoice.Action.NONE, "Held, it keeps going")
	voice.release()
	var stopped_after := 0.0
	while voice.sounding:
		var before := voice.gain
		voice.update(1.0 / 60.0, 0.5, 1.0)
		stopped_after += 1.0 / 60.0
		assert_lt(voice.gain, before)
	assert_almost_eq(stopped_after, HornVoice.FADE_SECONDS, 1.0 / 60.0, "A short fade, not a cut")


func test_pressing_again_during_the_fade_carries_on() -> void:
	var voice := HornVoice.new()
	voice.press()
	voice.release()
	voice.update(0.02, 0.1, 1.0)
	assert_eq(voice.press(), HornVoice.Action.NONE, "No restart, so no click")
	assert_eq(voice.gain, 1.0)


func test_a_tune_horn_plays_to_the_end_of_its_pass() -> void:
	var voice := HornVoice.new({"finish": true})
	voice.press()
	voice.update(0.05, 0.05, 1.8)
	voice.release()
	assert_eq(voice.update(0.5, 0.6, 1.8), HornVoice.Action.NONE, "A quick tap still plays the tune")
	assert_eq(voice.gain, 1.0)
	assert_eq(voice.update(0.5, 1.75, 1.8), HornVoice.Action.STOP, "Stops in the closing rest")
	assert_false(voice.sounding)


func test_a_tune_horn_stops_if_its_loop_wraps() -> void:
	var voice := HornVoice.new({"finish": true})
	voice.press()
	voice.update(0.1, 1.5, 1.8)
	voice.release()
	assert_eq(voice.update(0.1, 0.02, 1.8), HornVoice.Action.STOP)


func test_a_tune_horn_starts_again_when_pressed_again() -> void:
	var voice := HornVoice.new({"finish": true})
	voice.press()
	voice.release()
	assert_eq(voice.press(), HornVoice.Action.START)


# --- Horn choice in the profile ---

func _horns() -> Array:
	return CountryPack.read(COLOMBIA).horns()


func test_free_horns_are_owned_and_paid_ones_are_not() -> void:
	var profile := PlayerProfile.new()
	profile.settle_horns(_horns())
	assert_true(profile.owns_horn("two_tone"))
	assert_true(profile.owns_horn("standard"))
	assert_false(profile.owns_horn("chiva"))
	assert_eq(profile.horn, "", "Each bus keeps its own horn to begin with")


func test_every_bus_has_its_own_horn_until_one_is_chosen() -> void:
	var profile := PlayerProfile.new()
	profile.settle_horns(_horns())
	assert_eq(profile.horn_for("air"), "air")
	assert_true(profile.choose_horn("standard"))
	assert_eq(profile.horn_for("air"), "standard")
	assert_true(profile.choose_horn(""))
	assert_eq(profile.horn_for("chiva"), "chiva")


func test_a_horn_must_be_bought_before_it_is_chosen() -> void:
	var profile := PlayerProfile.new()
	var double_tap: Dictionary = CountryPack.read(COLOMBIA).horn("double_tap")
	assert_false(profile.choose_horn("double_tap"))
	assert_false(profile.buy_horn(double_tap), "No coins")
	profile.coins = 1000
	assert_true(profile.buy_horn(double_tap))
	assert_eq(profile.coins, 1000 - int(double_tap["cost"]))
	assert_true(profile.choose_horn("double_tap"))
	assert_false(profile.buy_horn(double_tap), "Bought once only")


func test_a_horn_with_a_level_waits_for_that_level() -> void:
	var profile := PlayerProfile.new()
	profile.coins = 10000
	var chiva: Dictionary = CountryPack.read(COLOMBIA).horn("chiva")
	assert_false(profile.buy_horn(chiva))
	profile.xp = DriverLevel.xp_for_level(int(chiva["level"]))
	assert_true(profile.buy_horn(chiva))


func test_the_horn_choice_is_saved_and_loaded() -> void:
	var profile := PlayerProfile.new()
	profile.coins = 1000
	profile.buy_horn(CountryPack.read(COLOMBIA).horn("double_tap"))
	profile.choose_horn("double_tap")
	var loaded := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	assert_true(loaded.owns_horn("double_tap"))
	assert_eq(loaded.horn, "double_tap")


func test_an_old_save_without_horns_still_loads() -> void:
	var old := PlayerProfile.new().to_dict()
	old.erase("horns_owned")
	old.erase("horn")
	var loaded := PlayerProfile.from_dict(old)
	loaded.settle_horns(_horns())
	assert_eq(loaded.horn, "")
	assert_true(loaded.owns_horn("two_tone"))


func test_a_damaged_horn_choice_falls_back_to_the_bus_horn() -> void:
	var loaded := PlayerProfile.from_dict({"horns_owned": "nonsense", "horn": "double_tap"})
	assert_eq(loaded.horn, "", "Not owned, so not chosen")
	var gone := PlayerProfile.from_dict({"horns_owned": ["old_horn"], "horn": "old_horn"})
	gone.settle_horns(_horns())
	assert_eq(gone.horn, "", "A horn the pack no longer has")


func test_each_bus_comes_with_a_horn_from_the_pack() -> void:
	var pack := CountryPack.read(COLOMBIA)
	var catalog := Catalog.new()
	for bus: Dictionary in catalog.items(Catalog.BUSES):
		assert_false(pack.bus_horn(bus).is_empty(), bus["id"])
	assert_eq(pack.bus_horn(catalog.find(Catalog.BUSES, "chiva"))["id"], "chiva")
	assert_eq(pack.bus_horn(catalog.find(Catalog.BUSES, "articulado_18"))["id"], "air")
	assert_eq(pack.bus_horn({})["id"], pack.horns()[0]["id"], "No horn named: the pack's first")


func test_the_radio_settings_are_saved() -> void:
	var fresh: Node = load("res://scripts/core/game_settings.gd").new()
	assert_eq(fresh.radio_station, "", "The radio starts off")
	fresh.radio_volume = 0.3
	fresh.radio_station = "pico_marisol"
	var other: Node = load("res://scripts/core/game_settings.gd").new()
	other.apply_saved(fresh.to_dict())
	assert_almost_eq(other.radio_volume, 0.3, 0.001)
	assert_eq(other.radio_station, "pico_marisol")
	other.apply_saved({})
	assert_eq(other.radio_station, "pico_marisol", "An old save leaves it alone")
	fresh.free()
	other.free()


# --- Pack data ---

func test_colombia_has_horns_ambience_and_radio() -> void:
	var pack := CountryPack.read(COLOMBIA)
	assert_gte(pack.horns().size(), 4)
	assert_gte(pack.radio_stations().size(), 2)
	for station: Dictionary in pack.radio_stations():
		assert_gte((station["tracks"] as Array).size(), 2, station["id"])
	var rules := pack.ambience_layers().map(func(layer: Dictionary) -> String: return layer["rule"])
	for rule: String in ["always", "sea", "stalls", "rain"]:
		assert_true(rules.has(rule), rule)
	assert_false(rules.has("calm"), "Birds are positional map clusters, not a map-wide layer")
	assert_false(pack.ambience_layers().any(func(layer: Dictionary) -> bool: return layer["id"] == "birds"))


func test_the_test_pack_has_no_radio_and_still_validates() -> void:
	var pack := CountryPack.read(TESTLAND)
	assert_true(pack.radio_stations().is_empty())
	assert_eq(pack.validate(), [] as Array[String])


func test_horn_ids_must_be_unique() -> void:
	var horns := _horns().duplicate(true)
	horns.append(horns[0].duplicate())
	assert_true(_broken_pack({"horns": horns}).validate().has("Horns have two_tone twice"))


func test_a_pack_needs_a_free_horn() -> void:
	var horns := _horns().duplicate(true)
	for item: Dictionary in horns:
		item["cost"] = 100
	assert_true(_broken_pack({"horns": horns}).validate().has("A pack needs at least one free horn"))


func test_a_missing_horn_file_is_reported() -> void:
	var horns := _horns().duplicate(true)
	horns[1]["file"] = "res://assets/audio/no_horn.wav"
	var problems := _broken_pack({"horns": horns}).validate()
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "no_horn.wav")


func test_a_bus_naming_an_unknown_horn_is_reported() -> void:
	var horns := _horns().filter(func(item: Dictionary) -> bool: return item["id"] != "air")
	assert_true(_broken_pack({"horns": horns}).validate().has("Bus articulado_18 has an unknown horn air"))


func test_radio_stations_are_checked() -> void:
	var stations: Array = CountryPack.read(COLOMBIA).radio_stations().duplicate(true)
	stations[0]["tracks"][0]["file"] = "res://assets/audio/radio/missing.wav"
	stations[1]["id"] = stations[2]["id"]
	var problems := _broken_pack({"radio": stations}).validate()
	assert_true(problems.any(func(problem: String) -> bool: return problem.contains("missing.wav")), str(problems))
	assert_true(problems.has("Radio has %s twice" % stations[2]["id"]), str(problems))
	stations = [{"id": "x", "name": "X", "frequency": "1 FM", "tracks": []}]
	assert_true(_broken_pack({"radio": stations}).validate().has("Radio station x needs at least one track"))


func test_station_names_and_frequencies_must_be_text() -> void:
	var good := {"id": "x", "name": "X", "frequency": "90.1 FM", "tracks": [{"file": "a.wav"}]}
	assert_eq(RadioTuner.check([good]), [] as Array[String])
	for key: String in ["id", "name", "frequency"]:
		var blank := good.duplicate(true)
		blank[key] = "  "
		assert_true(RadioTuner.check([blank]).has("Radio station needs %s as some text" % key), key)
		var number := good.duplicate(true)
		number[key] = 90.1
		assert_true(RadioTuner.check([number]).has("Radio station needs %s as some text" % key), key)


func test_horn_value_types_are_checked() -> void:
	var horns := _horns().duplicate(true)
	horns[2]["finish"] = "yes"
	horns[3]["cost"] = "a lot"
	horns[3]["level"] = "three"
	horns[4]["volume_db"] = "loud"
	var problems := _broken_pack({"horns": horns}).validate()
	assert_true(problems.has("Horn %s needs finish as true or false" % horns[2]["id"]), str(problems))
	assert_true(problems.has("Horn %s needs cost as a number" % horns[3]["id"]), str(problems))
	assert_true(problems.has("Horn %s needs level as a number" % horns[3]["id"]), str(problems))
	assert_true(problems.has("Horn %s needs volume_db as a number" % horns[4]["id"]), str(problems))


func test_a_horn_entry_that_is_not_an_object_is_reported_and_skipped() -> void:
	var horns := _horns().duplicate(true)
	horns.insert(0, "air horn")
	var pack := _broken_pack({"horns": horns})
	assert_true(pack.validate().has("Horns need an id, a name and a file"))
	assert_eq(pack.horns().size(), horns.size() - 1, "Left out of the list")
	assert_eq(pack.horn("chiva")["id"], "chiva", "Looking up a horn does not trip on it")
	assert_eq(pack.horn("")["id"], horns[1]["id"])


func test_ambience_layers_are_checked() -> void:
	var layers: Array = CountryPack.read(COLOMBIA).ambience_layers().duplicate(true)
	layers[0]["file"] = "res://assets/audio/ambience/missing.wav"
	var problems := _broken_pack({"ambience": layers}).validate()
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "missing.wav")


func test_radio_tracks_are_original_music_of_the_right_length() -> void:
	for station: Dictionary in CountryPack.read(COLOMBIA).radio_stations():
		for track: Dictionary in station["tracks"]:
			var stream: AudioStream = load(track["file"])
			assert_between(stream.get_length(), 45.0, 90.0, track["file"])


func test_steady_horns_and_ambience_beds_loop_from_their_files() -> void:
	var pack := CountryPack.read(COLOMBIA)
	for item: Dictionary in pack.horns():
		var horn: AudioStreamWAV = load(item["file"])
		assert_eq(horn.loop_mode, AudioStreamWAV.LOOP_FORWARD, item["id"])
	var two_tone: AudioStreamWAV = load(pack.horn("two_tone")["file"])
	assert_gt(two_tone.loop_begin, 0, "A fade in before the loop")
	for layer: Dictionary in pack.ambience_layers():
		if not AmbienceMixer.is_one_shot(layer):
			var bed: AudioStreamWAV = load(layer["file"])
			assert_eq(bed.loop_mode, AudioStreamWAV.LOOP_FORWARD, layer["id"])


func test_a_radio_track_does_not_loop_so_the_station_moves_on() -> void:
	var track: AudioStreamWAV = load(CountryPack.read(COLOMBIA).radio_stations()[0]["tracks"][0]["file"])
	assert_eq(track.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	var looping: AudioStreamWAV = AudioDirector.looped(track)
	assert_eq(looping.loop_mode, AudioStreamWAV.LOOP_FORWARD, "A street layer gets a looping copy")
	assert_eq(track.loop_mode, AudioStreamWAV.LOOP_DISABLED, "The radio's own stays as it was")


## The loudest sample in the first and last count samples of a 16-bit mono WAV
## file in the project, read straight from the file, since the imported stream is
## compressed. -1 if the file has no data.
func _loudest_edge(path: String, count: int) -> float:
	var bytes := FileAccess.get_file_as_bytes(path)
	var at := 12
	while at + 8 <= bytes.size():
		var size := bytes.decode_u32(at + 4)
		if bytes.slice(at, at + 4).get_string_from_ascii() == "data":
			var first := at + 8
			var last := first + size - 2
			var loudest := 0
			for i in count:
				loudest = maxi(loudest, maxi(absi(bytes.decode_s16(first + 2 * i)), absi(bytes.decode_s16(last - 2 * i))))
			return loudest / 32768.0
		at += 8 + size + (size % 2)
	return -1.0


func test_radio_songs_start_and_end_in_silence() -> void:
	# A song plays once, so a loud first or last 10 ms would click.
	for station: Dictionary in CountryPack.read(COLOMBIA).radio_stations():
		for track: Dictionary in station["tracks"]:
			var loudest := _loudest_edge(track["file"], int(0.01 * 22050))
			assert_between(loudest, 0.0, 0.01, track["file"])
