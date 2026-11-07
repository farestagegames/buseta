class_name AudioDirector
extends Node
## All game sound. Listens to events only, so nothing else knows audio exists.

const IDLE_RPM := AutomaticGearbox.IDLE_RPM
const ENGINE_MIN_PITCH := 0.85
const ENGINE_MAX_PITCH := 1.5
const COLLISION_COOLDOWN := 0.35
## A bus only vents its brakes now and then, not on every pedal lift.
const AIR_BRAKE_COOLDOWN := 8.0
const REVERSE_BEEP_SECONDS := 1.0

const SOUNDS := {
	"engine": "res://assets/audio/engine_loop.wav",
	"horn": "res://assets/audio/horn_loop.wav",
	"door_open": "res://assets/audio/door_open.wav",
	"door_close": "res://assets/audio/door_close.wav",
	"crash": "res://assets/audio/crash.wav",
	"thud": "res://assets/audio/thud.wav",
	"knock": "res://assets/audio/knock.wav",
	"pay": "res://assets/audio/pay.wav",
	"bell": "res://assets/audio/bell.wav",
	"air": "res://assets/audio/air_brake.wav",
	"ambience": "res://assets/audio/ambience_loop.wav",
	"tick": "res://assets/audio/indicator_tick.wav",
	"tock": "res://assets/audio/indicator_tock.wav",
	"reverse": "res://assets/audio/reverse_beep.wav",
	"bump": "res://assets/audio/bump.wav",
}

var horn_playing: bool:
	get:
		return _horn.playing

var _engine: AudioStreamPlayer
var _horn: AudioStreamPlayer
var _effects: Array[AudioStreamPlayer] = []
var _next_effect: int = 0
var _streams: Dictionary = {}
var _doors_were_closed: bool = true
var _was_braking: bool = false
var _cooldown: float = 0.0
var _air_cooldown: float = 0.0
var _ambience: AudioStreamPlayer
var _lamp_was_on: bool = false
var _reverse_timer: float = 0.0


func _ready() -> void:
	for key: String in SOUNDS:
		_streams[key] = load(SOUNDS[key])
	_engine = _make_loop("engine", -22.0)
	_horn = _make_loop("horn", -13.0)
	_engine.play()
	_ambience = _make_loop("ambience", -24.0)
	_ambience.play()
	for i in 4:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_effects.append(player)
	GameEvents.horn_changed.connect(_on_horn)
	GameEvents.bus_telemetry_updated.connect(_on_telemetry)
	GameEvents.bus_collided.connect(_on_collided)
	GameEvents.obstacle_hit.connect(func(_kind: String, _loss: float) -> void: play_effect("knock", -9.0))
	GameEvents.bus_jolted.connect(_on_jolted)
	GameEvents.passenger_paid.connect(func() -> void: play_effect("pay", -18.0))
	GameEvents.stop_session_started.connect(func(_stop: int, _off: int, _on: int) -> void: play_effect("bell", -14.0))


func play_effect(key: String, volume_db: float) -> void:
	var player := _effects[_next_effect]
	_next_effect = (_next_effect + 1) % _effects.size()
	player.stream = _streams[key]
	player.volume_db = volume_db
	player.play()


func _make_loop(key: String, volume_db: float) -> AudioStreamPlayer:
	var stream: AudioStreamWAV = _streams[key]
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player


func _process(dt: float) -> void:
	_cooldown = maxf(_cooldown - dt, 0.0)
	_air_cooldown = maxf(_air_cooldown - dt, 0.0)


func _on_horn(is_pressed: bool) -> void:
	if is_pressed:
		_horn.play()
	else:
		_horn.stop()


func _on_telemetry(data: BusTelemetry) -> void:
	var share := inverse_lerp(IDLE_RPM, AutomaticGearbox.MAX_RPM, data.rpm)
	_engine.pitch_scale = lerpf(ENGINE_MIN_PITCH, ENGINE_MAX_PITCH, clampf(share, 0.0, 1.0))
	_engine.volume_db = lerpf(-24.0, -16.0, data.throttle)

	if data.doors_closed != _doors_were_closed:
		_doors_were_closed = data.doors_closed
		if data.doors_closed:
			pass
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
