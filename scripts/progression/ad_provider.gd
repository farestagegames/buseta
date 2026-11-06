class_name AdProvider
extends RefCounted
## The seam for optional rewarded ads. This base version has no ad SDK and is
## never available, so the game shows no ad buttons. A real provider extends this
## and replaces Profile.ads, with no changes anywhere else.


func is_available() -> bool:
	return false


## Calls on_finished with true if the player earned the reward.
func show_rewarded(on_finished: Callable) -> void:
	on_finished.call(false)
