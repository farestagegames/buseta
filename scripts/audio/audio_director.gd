class_name AudioDirector
extends Node
## All game sound. Listens to events only, so nothing else knows audio exists.
## CityShift tells it which horn the bus has and where the coast, stalls and
## stops are.
## The decisions live in pure classes: HornVoice for the horn, AmbienceMixer for
## the street and RadioTuner for the radio.

const IDLE_RPM := AutomaticGearbox.IDLE_RPM
const ENGINE_MIN_PITCH := 0.85
const ENGINE_MAX_PITCH := 1.5
const COLLISION_COOLDOWN := 0.35
## A bus only vents its brakes now and then, not on every pedal lift.
const AIR_BRAKE_COOLDOWN := 8.0
const REVERSE_BEEP_SECONDS := 1.0
const BUS_HORN_DB := -13.0
## Traffic horns reuse the city bus horn at other pitches, so no extra sound is
## needed. Each kind (TrafficFlow.Honk) is a pitch and a pattern of sounding and
## silent spells, in seconds.
const HONKS := {
	TrafficFlow.Honk.TOOT: {"pitch": 1.45, "steps": [0.28]},
	TrafficFlow.Honk.LONG: {"pitch": 1.3, "steps": [0.9]},
	TrafficFlow.Honk.BEEP: {"pitch": 1.9, "steps": [0.12, 0.09, 0.12]},
}
const CAR_HORN_VOICES := 3
## Two honks never start closer together than this.
const CAR_HORN_COOLDOWN := 0.6
## A honk fades over its last moment instead of stopping dead.
const CAR_HORN_FADE := 0.05
const CAR_HORN_DB := -15.0
## Full volume up to this far from the bus, then 6 dB quieter each time the
## distance doubles, and not heard past CAR_HORN_RANGE.
const CAR_HORN_NEAR := 10.0
const CAR_HORN_RANGE := 90.0
## Street layers ease to a new level over this long, so nothing jumps.
const STREET_FADE := 0.6
## Players shared by the street's one-off sounds, such as a motorbike passing.
const STREET_SHOT_PLAYERS := 2
## The radio sits a few dB over the street bed in the cockpit, where the city and
## sea layers also dip while it plays (their "radio_ducks_db").
const RADIO_DB := 0.0
## From outside the bus the radio is quieter and muffled.
const RADIO_OUTSIDE_DB := -3.0
## Tuning in joins a song part-way through, as a real radio does.
const RADIO_JOIN_SHARE := 0.7
## A street layer's volume is only written again once its level has moved this
## much, so a settled layer costs nothing each frame. About 0.1 dB.
const LEVEL_STEP := 0.005

const SOUNDS := {
	"engine": "res://assets/audio/engine_loop.wav",
	"car_horn": "res://assets/audio/horn_loop.wav",
	"door_open": "res://assets/audio/door_open.wav",
	"door_close": "res://assets/audio/door_close.wav",
	"crash": "res://assets/audio/crash.wav",
	"thud": "res://assets/audio/thud.wav",
	"knock": "res://assets/audio/knock.wav",
	"pay": "res://assets/audio/pay.wav",
	"bell": "res://assets/audio/bell.wav",
	"air": "res://assets/audio/air_brake.wav",
	"tick": "res://assets/audio/indicator_tick.wav",
	"tock": "res://assets/audio/indicator_tock.wav",
	"reverse": "res://assets/audio/reverse_beep.wav",
	"bump": "res://assets/audio/bump.wav",
	"siren": "res://assets/audio/siren_whoop.wav",
	"perfect": "res://assets/audio/perfect_chime.wav",
}

## True from pressing the horn until it has faded out or finished its tune.
var horn_playing: bool:
	get:
		return horn_voice.sounding
var horn_voice := HornVoice.new()
var horn: Dictionary = {}
var mixer: AmbienceMixer
var tuner: RadioTuner

var _engine: AudioStreamPlayer
var _horn: AudioStreamPlayer
var _horn_db: float = BUS_HORN_DB
var _effects: Array[AudioStreamPlayer] = []
var _next_effect: int = 0
var _streams: Dictionary = {}
var _doors_were_closed: bool = true
var _was_braking: bool = false
var _cooldown: float = 0.0
var _air_cooldown: float = 0.0
var _lamp_was_on: bool = false
var _reverse_timer: float = 0.0
## Each voice: player, steps, step, left and db.
var _car_horns: Array[Dictionary] = []
var _car_horn_cooldown: float = 0.0
var _bus_spot: Vector2 = Vector2.ZERO
var _street: Dictionary = {} ## Loop layer id to its player.
var _street_levels: Dictionary = {} ## Loop layer id to its eased gain.
var _street_applied: Dictionary = {} ## Loop layer id to the gain its player has now.
var _street_shots: Array[AudioStreamPlayer] = []
var _shot_streams: Dictionary = {} ## One-shot layer id to its sound, loaded once.
var _next_shot: int = 0
var _coast_x: float = GroundSurface.NO_COAST
var _stalls := PackedVector2Array()
var _stops := PackedVector2Array()
var _radio: AudioStreamPlayer
var _outside: bool = false
var _horn_gain_applied: float = 1.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	SoundBuses.ensure()
	for key: String in SOUNDS:
		_streams[key] = load(Country.pack.sound(key, SOUNDS[key]))
	_engine = _player(looped(_streams["engine"]), -22.0)
	_engine.play()
	_horn = _player(null, BUS_HORN_DB)
	use_horn(Country.pack.horn(""))
	for i in CAR_HORN_VOICES:
		_car_horns.append({"player": _player(_streams["car_horn"], CAR_HORN_DB), "steps": [], "step": 0, "left": 0.0, "db": CAR_HORN_DB})
	for i in 4:
		_effects.append(_player(null, 0.0))
	_build_street()
	_build_radio()
	set_outside(not bool(CameraRig.VIEWS[CameraRig.START_VIEW]["cockpit"]))
	GameEvents.horn_changed.connect(_on_horn)
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.bus_collided.connect(_on_collided)
	GameEvents.obstacle_hit.connect(func(_kind: String, _loss: float) -> void: play_effect("knock", -9.0))
	GameEvents.bus_jolted.connect(_on_jolted)
	GameEvents.passenger_paid.connect(func() -> void: play_effect("pay", -18.0))
	GameEvents.perfect_stop.connect(func(_stop: int) -> void: play_effect("perfect", -14.0))
	GameEvents.stop_requested.connect(func() -> void: play_effect("bell", -16.0))
	GameEvents.stop_session_started.connect(func(_stop: int, _off: int, _on: int) -> void: play_effect("bell", -14.0))
	GameEvents.payout_tick.connect(func() -> void: play_effect("tick", -16.0))
	GameEvents.payout_total.connect(func() -> void: play_effect("pay", -12.0))
	GameEvents.payout_star.connect(func() -> void: play_effect("perfect", -12.0))
	GameEvents.payout_level_up.connect(func() -> void: play_effect("bell", -10.0))
	GameEvents.traffic_horn.connect(_on_traffic_horn)
	GameEvents.police_fined.connect(func(_coins: int, _reason: String) -> void: play_effect("siren", -12.0))
	GameEvents.police_ended_run.connect(func(_reason: String) -> void: play_effect("siren", -9.0))
	GameEvents.radio_cycle_requested.connect(cycle_radio)
	GameEvents.rain_changed.connect(func(amount: float) -> void: mixer.rain = amount)
	GameEvents.camera_view_changed.connect(_on_camera_view)


## Fits a horn from the pack. CityShift calls this with the player's choice.
func use_horn(item: Dictionary) -> void:
	if item.is_empty():
		return
	horn = item
	_horn.stop()
	_horn.stream = looped(load(Country.pack.resolve(item["file"])))
	_horn_db = BUS_HORN_DB + float(item.get("volume_db", 0.0))
	_horn.volume_db = _horn_db
	_horn_gain_applied = 1.0
	horn_voice = HornVoice.new(item)


## Where the sea starts and where the stalls and stops are, for the street sounds.
func setup_street(coast_x: float, stalls: PackedVector2Array, stops: PackedVector2Array) -> void:
	_coast_x = coast_x
	_stalls = stalls
	_stops = stops


func play_effect(key: String, volume_db: float) -> void:
	var player := _effects[_next_effect]
	_next_effect = (_next_effect + 1) % _effects.size()
	player.stream = _streams[key]
	player.volume_db = volume_db
	player.play()


## A sound that loops: as it is if its file sets a loop, otherwise a copy looping
## the whole file. The copy leaves the original free to play once elsewhere, as a
## radio track does.
static func looped(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav == null or wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return stream
	wav = wav.duplicate()
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
	return wav


func _player(stream: AudioStream, volume_db: float, bus: String = "") -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	if bus != "":
		player.bus = bus
	add_child(player)
	return player


func _process(dt: float) -> void:
	_cooldown = maxf(_cooldown - dt, 0.0)
	_air_cooldown = maxf(_air_cooldown - dt, 0.0)
	_car_horn_cooldown = maxf(_car_horn_cooldown - dt, 0.0)
	for voice: Dictionary in _car_horns:
		_step_car_horn(voice, dt)
	_update_horn(dt)
	_update_street(dt)


func _update_horn(dt: float) -> void:
	if not horn_voice.sounding:
		return
	var position := _horn.get_playback_position() if _horn.playing else 0.0
	if horn_voice.update(dt, position, _horn.stream.get_length()) == HornVoice.Action.STOP:
		_horn.stop()
	# Only while the fade is moving: setting a volume is not free in Godot.
	if horn_voice.gain != _horn_gain_applied:
		_horn_gain_applied = horn_voice.gain
		_horn.volume_db = _horn_db + linear_to_db(maxf(horn_voice.gain, 0.001))


## A horn let go just as the game pauses would never finish its fade, and would
## blip back on resume. Stop it now instead; the player stops it softly.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and horn_voice.sounding and not horn_voice.held:
		horn_voice.sounding = false
		horn_voice.gain = 0.0
		_horn.stop()


## How loud a honk this far from the bus is, or -INF when out of earshot.
static func car_horn_db(distance: float) -> float:
	if distance > CAR_HORN_RANGE:
		return -INF
	return CAR_HORN_DB - 6.0 * log(maxf(distance, CAR_HORN_NEAR) / CAR_HORN_NEAR) / log(2.0)


func _on_traffic_horn(spot: Vector2, kind: int) -> void:
	var db := car_horn_db(spot.distance_to(_bus_spot))
	if _car_horn_cooldown > 0.0 or db == -INF:
		return
	var free := _car_horns.filter(func(voice: Dictionary) -> bool: return (voice["steps"] as Array).is_empty())
	if free.is_empty():
		return
	_car_horn_cooldown = CAR_HORN_COOLDOWN
	var honk: Dictionary = HONKS.get(kind, HONKS[TrafficFlow.Honk.TOOT])
	var voice: Dictionary = free[0]
	voice["steps"] = (honk["steps"] as Array).duplicate()
	voice["step"] = 0
	voice["left"] = voice["steps"][0]
	voice["db"] = db
	var player: AudioStreamPlayer = voice["player"]
	player.pitch_scale = honk["pitch"]
	player.volume_db = db
	player.play()


## Even steps sound and odd steps are silent; a voice is free once its steps run out.
func _step_car_horn(voice: Dictionary, dt: float) -> void:
	var steps: Array = voice["steps"]
	if steps.is_empty():
		return
	var player: AudioStreamPlayer = voice["player"]
	voice["left"] = float(voice["left"]) - dt
	var sounding := int(voice["step"]) % 2 == 0
	if sounding:
		player.volume_db = float(voice["db"]) + linear_to_db(clampf(float(voice["left"]) / CAR_HORN_FADE, 0.001, 1.0))
	if float(voice["left"]) > 0.0:
		return
	voice["step"] = int(voice["step"]) + 1
	if int(voice["step"]) >= steps.size():
		player.stop()
		steps.clear()
		return
	voice["left"] = steps[voice["step"]]
	if int(voice["step"]) % 2 == 0:
		player.volume_db = voice["db"]
		player.play()
	else:
		player.stop()


func _on_horn(is_pressed: bool) -> void:
	if not is_pressed:
		horn_voice.release()
	elif horn_voice.press() == HornVoice.Action.START:
		_horn.volume_db = _horn_db
		_horn_gain_applied = 1.0
		_horn.play()


# --- Street ambience ---

func _build_street() -> void:
	mixer = AmbienceMixer.new(Country.pack.ambience_layers(), randi())
	for layer: Dictionary in mixer.layers:
		if AmbienceMixer.is_one_shot(layer):
			_shot_streams[layer["id"]] = load(Country.pack.resolve(layer["file"]))
			continue
		var bus := SoundBuses.DISTANT if layer.get("muffled", false) else ""
		var player := _player(looped(load(Country.pack.resolve(layer["file"]))), AmbienceMixer.SILENT_DB, bus)
		_street[layer["id"]] = player
		_street_levels[layer["id"]] = 0.0
		_street_applied[layer["id"]] = 0.0
		# Each loop starts somewhere different, so the shift never opens the same way.
		player.play(_random.randf() * player.stream.get_length())
		player.stream_paused = true
	for i in STREET_SHOT_PLAYERS:
		_street_shots.append(_player(null, AmbienceMixer.SILENT_DB))


func _update_street(dt: float) -> void:
	for layer: Dictionary in mixer.layers:
		var player: AudioStreamPlayer = _street.get(layer["id"])
		if player == null:
			continue
		var id: String = layer["id"]
		var target := mixer.gain(layer)
		var level := move_toward(float(_street_levels[id]), target, dt / STREET_FADE)
		_street_levels[id] = level
		# A layer that cannot be heard is paused, so it costs nothing to mix.
		var silent := level < AmbienceMixer.AUDIBLE
		if player.stream_paused != silent:
			player.stream_paused = silent
		var applied := float(_street_applied[id])
		if silent or level == applied:
			continue
		# Settled layers are left alone: setting a volume makes the audio server
		# allocate, so it is only done when the level has really moved.
		if absf(level - applied) >= LEVEL_STEP or level == target:
			_street_applied[id] = level
			player.volume_db = float(layer.get("volume_db", 0.0)) + linear_to_db(maxf(level, 0.001))
	for layer: Dictionary in mixer.update(dt):
		var player := _street_shots[_next_shot]
		_next_shot = (_next_shot + 1) % _street_shots.size()
		player.stream = _shot_streams[layer["id"]]
		player.volume_db = mixer.volume_db(layer) + _random.randf_range(-3.0, 1.0)
		player.pitch_scale = _random.randf_range(0.92, 1.08)
		player.play()


## How loud a street layer is right now, from 0 to 1, after easing.
func street_level(layer_id: String) -> float:
	return float(_street_levels.get(layer_id, 0.0))


# --- Radio ---

func _build_radio() -> void:
	_radio = _player(null, RADIO_DB, SoundBuses.RADIO)
	# A bus radio keeps playing in the pause menu, so its volume slider can be
	# heard. Android still silences the whole app in the background.
	_radio.process_mode = Node.PROCESS_MODE_ALWAYS
	_radio.finished.connect(_on_track_finished)
	tuner = RadioTuner.new(Country.pack.radio_stations(), GameSettings.radio_station, randi())
	if tuner.is_on():
		_play_track(true)
		# Says which station is on once the HUD is ready to show it.
		_announce_station.call_deferred()


## Off, the next station, and back to off. Remembered for the next shift.
func cycle_radio() -> void:
	if not tuner.has_stations():
		return
	tuner.next_station()
	GameSettings.radio_station = tuner.station_id()
	_play_track(true)
	_announce_station()


func radio_playing() -> bool:
	return _radio.playing


func radio_stream() -> AudioStream:
	return _radio.stream


func _announce_station() -> void:
	var station := tuner.station()
	GameEvents.radio_tuned.emit(str(station.get("name", "")), str(station.get("frequency", "")))


func _play_track(join_midway: bool) -> void:
	mixer.radio_on = tuner.is_on()
	if not tuner.is_on():
		_radio.stop()
		return
	_radio.stream = load(Country.pack.resolve(tuner.track()["file"]))
	var start := _random.randf() * RADIO_JOIN_SHARE * _radio.stream.get_length() if join_midway else 0.0
	_radio.play(start)


func _on_track_finished() -> void:
	tuner.track_finished()
	_play_track(false)


func _on_camera_view(view_name: String) -> void:
	for view: Dictionary in CameraRig.VIEWS:
		if view["name"] == view_name:
			set_outside(not bool(view["cockpit"]))


## From the follow cameras the radio is heard through the bus, quieter and muffled.
func set_outside(outside: bool) -> void:
	_outside = outside
	mixer.in_cockpit = not outside
	SoundBuses.muffle_radio(outside)
	_radio.volume_db = RADIO_DB + (RADIO_OUTSIDE_DB if outside else 0.0)


# --- Driving sounds ---

func _on_telemetry(data: BusTelemetry) -> void:
	var share := inverse_lerp(IDLE_RPM, AutomaticGearbox.MAX_RPM, data.rpm)
	_engine.pitch_scale = lerpf(ENGINE_MIN_PITCH, ENGINE_MAX_PITCH, clampf(share, 0.0, 1.0))
	_engine.volume_db = lerpf(-24.0, -16.0, data.throttle)
	_update_surroundings(Vector2(data.position.x, data.position.z), absf(data.speed))

	if data.doors_closed != _doors_were_closed:
		_doors_were_closed = data.doors_closed
	elif not data.doors_closed and data.door_open_amount > 0.0 and data.door_open_amount < 0.03:
		play_effect("door_open", -10.0)
	if _door_started_closing(data):
		play_effect("door_close", -10.0)

	if data.indicator_lamp_on != _lamp_was_on:
		_lamp_was_on = data.indicator_lamp_on
		if data.indicator_side != 0:
			play_effect("tick" if data.indicator_lamp_on else "tock", -20.0)
	_reverse_timer -= get_physics_process_delta_time()
	if data.is_reverse and data.speed < -0.1 and _reverse_timer <= 0.0:
		_reverse_timer = REVERSE_BEEP_SECONDS
		play_effect("reverse", -20.0)

	var braking := data.brake > 0.25
	if _was_braking and not braking and absf(data.speed) < 1.0 and _air_cooldown <= 0.0:
		_air_cooldown = AIR_BRAKE_COOLDOWN
		play_effect("air", -14.0)
	_was_braking = braking


func _update_surroundings(at: Vector2, speed: float) -> void:
	_bus_spot = at
	mixer.speed = speed
	mixer.sea_distance = AmbienceMixer.distance_to_sea(at.x, _coast_x)
	mixer.stall_distance = _nearest(at, _stalls)
	mixer.stop_distance = _nearest(at, _stops)


static func _nearest(at: Vector2, spots: PackedVector2Array) -> float:
	var nearest := INF
	for spot in spots:
		nearest = minf(nearest, at.distance_squared_to(spot))
	return sqrt(nearest)


var _last_door_amount: float = 0.0


func _door_started_closing(data: BusTelemetry) -> bool:
	var closing := data.door_open_amount < _last_door_amount and _last_door_amount >= 0.999
	_last_door_amount = data.door_open_amount
	return closing


func _on_collided(impact_speed: float) -> void:
	if _cooldown <= 0.0:
		_cooldown = COLLISION_COOLDOWN
		play_effect("crash", clampf(-16.0 + impact_speed * 1.5, -16.0, -5.0))


func _on_jolted(strength: float) -> void:
	if _cooldown <= 0.0:
		_cooldown = COLLISION_COOLDOWN
		play_effect("bump", clampf(-20.0 + strength * 1.5, -20.0, -10.0))
