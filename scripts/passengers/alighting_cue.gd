class_name AlightingCue
extends RefCounted
## What the driver is told about people getting off at a stop, so they know when
## the last one is out (tester, 0.1.5: in the cockpit the rear door is out of
## sight and they sat waiting). A 2D line by the doors button, not a second mirror
## render, which was the main suspect in the cockpit freezes on phones.

enum State { HIDDEN, GETTING_OFF, ALL_OFF }

var state: State = State.HIDDEN
var left: int = 0


## A stop's session began. Nobody getting off shows nothing.
func start(alighting: int) -> void:
	left = maxi(alighting, 0)
	state = State.GETTING_OFF if left > 0 else State.HIDDEN


func alighted() -> void:
	if state != State.GETTING_OFF:
		return
	left = maxi(left - 1, 0)
	if left == 0:
		state = State.ALL_OFF


## The bus left the stop, served or not.
func end() -> void:
	state = State.HIDDEN
	left = 0


func is_shown() -> bool:
	return state != State.HIDDEN
