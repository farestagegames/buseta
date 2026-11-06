class_name CameraShots
extends RefCounted
## Plays a list of camera moves in order. Pure logic. Each shot glides between two
## camera positions and two look targets, easing in and out.

var shots: Array[Dictionary] = [] ## from, to, look_from, look_to, seconds, caption
var index: int = 0
var time: float = 0.0


func add(from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, seconds: float, caption: String) -> void:
	shots.append({"from": from, "to": to, "look_from": look_from, "look_to": look_to, "seconds": seconds, "caption": caption})


func is_finished() -> bool:
	return index >= shots.size()


func update(dt: float) -> void:
	if is_finished():
		return
	time += dt
	if time >= float(shots[index]["seconds"]):
		time = 0.0
		index += 1


func caption() -> String:
	return "" if is_finished() else shots[index]["caption"]


func position() -> Vector3:
	var shot: Dictionary = shots[mini(index, shots.size() - 1)]
	return (shot["from"] as Vector3).lerp(shot["to"], _progress(shot))


func look_target() -> Vector3:
	var shot: Dictionary = shots[mini(index, shots.size() - 1)]
	return (shot["look_from"] as Vector3).lerp(shot["look_to"], _progress(shot))


func _progress(shot: Dictionary) -> float:
	if is_finished():
		return 1.0
	return smoothstep(0.0, 1.0, time / float(shot["seconds"]))
