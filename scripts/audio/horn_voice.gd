class_name HornVoice
extends RefCounted
## When the horn sounds and how it stops. Pure logic for AudioDirector.
##
## Held, the horn loops. Let go, a steady horn fades out in FADE_SECONDS, so it
## never clicks. A tune horn ("finish": true in the pack) plays to the end of the
## pass it is on, so a quick tap still gives the whole tune. Its file ends in a
## rest, and it stops in that rest, before the loop could start the tune again.

enum Action { NONE, START, STOP }

const FADE_SECONDS := 0.06
## A tune stops this close to its end, inside the closing rest.
const END_MARGIN := 0.1

var finish_pass: bool = false
var held: bool = false
var sounding: bool = false
## Multiplies the horn's volume: 1 while held, falling during a fade.
var gain: float = 0.0
var _last_position: float = 0.0


func _init(horn: Dictionary = {}) -> void:
	finish_pass = bool(horn.get("finish", false))


## Returns START when playback should begin from the start of the file.
func press() -> Action:
	held = true
	gain = 1.0
	# A steady horn caught while fading just carries on. A tune starts again.
	if sounding and not finish_pass:
		return Action.NONE
	sounding = true
	_last_position = 0.0
	return Action.START


func release() -> void:
	held = false


## position is where playback is in the file, length how long the file is. The
## position goes back when the loop wraps.
func update(dt: float, position: float, length: float) -> Action:
	var wrapped := position < _last_position
	_last_position = position
	if not sounding or held:
		return Action.NONE
	if finish_pass:
		if wrapped or position >= length - END_MARGIN:
			sounding = false
			gain = 0.0
			return Action.STOP
		return Action.NONE
	gain -= dt / FADE_SECONDS
	if gain <= 0.0:
		gain = 0.0
		sounding = false
		return Action.STOP
	return Action.NONE
