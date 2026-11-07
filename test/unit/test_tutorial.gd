extends GutTest

const DT := 1.0 / 60.0

var steps: TutorialScript


func before_each() -> void:
	steps = TutorialScript.new()


func _state(changes: Dictionary = {}) -> Dictionary:
	var state := {
		"speed": 0.0, "steer": 0.0, "brake": 0.0, "view_changes": 0, "indicator": 0, "turn_passed": false,
		"stop_distance": 400.0, "stop_index": 0, "parked": false, "doors_open": false, "doors_closed": true,
		"session_done": false,
	}
	state.merge(changes, true)
	return state


func _run(state: Dictionary, seconds: float = 1.2) -> void:
	for i in int(seconds / DT):
		steps.update(state, DT)


func test_waits_until_the_player_pulls_away() -> void:
	_run(_state(), 30.0)
	assert_eq(steps.step()["id"], "pull_away")
	_run(_state({"speed": 3.0}))
	assert_eq(steps.step()["id"], "steer")


func test_full_tutorial_runs_in_order() -> void:
	var path: Array[Dictionary] = [
		{"speed": 3.0}, {"steer": 0.2}, {"brake": 0.5}, {"view_changes": 1}, {"indicator": 1},
		{"stop_distance": 50.0}, {"parked": true}, {"doors_open": true},
		{"session_done": true, "doors_open": true, "doors_closed": false},
		{"doors_closed": true},
	]
	var seen: Array[String] = []
	for change in path:
		seen.append(steps.step()["id"])
		_run(_state(change))
	assert_eq(seen, ["pull_away", "steer", "brake", "view", "indicate", "follow", "bay", "open", "wait", "close"] as Array[String])
	assert_eq(steps.step()["id"], "finish")
	_run(_state(), TutorialScript.FINISH_SECONDS + 1.0)
	assert_true(steps.is_finished())


func test_steps_do_not_flash_past_too_quickly() -> void:
	steps.update(_state({"speed": 3.0}), DT)
	assert_eq(steps.step()["id"], "pull_away")


func test_tilt_players_are_not_stuck_on_steering() -> void:
	_run(_state({"speed": 3.0}))
	_run(_state(), TutorialScript.OPTIONAL_STEP_SECONDS + 1.0)
	assert_eq(steps.step()["id"], "brake")


func test_a_driver_who_misses_the_turn_prompt_moves_on() -> void:
	steps.index = 4
	_run(_state({"turn_passed": true}))
	assert_eq(steps.step()["id"], "follow")


func test_a_driver_who_passes_the_stop_is_not_stranded() -> void:
	steps.index = 6
	_run(_state({"stop_index": 1}), 0.1)
	assert_eq(steps.step()["id"], "finish")


func test_every_step_has_translated_text() -> void:
	var strings: Dictionary = MapLoader.read_json("res://data/packs/colombia/lang/es_CO.json")
	for step: Dictionary in TutorialScript.STEPS:
		assert_true(strings.has(step["text"]), step["id"])
	for caption in IntroCutscene.CAPTIONS:
		assert_true(strings.has(caption), caption)


func test_camera_shots_play_in_turn_and_finish() -> void:
	var shots := CameraShots.new()
	shots.add(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, 2.0, "One")
	shots.add(Vector3.ZERO, Vector3.ONE, Vector3.ZERO, Vector3.ONE, 1.0, "Two")
	assert_eq(shots.caption(), "One")
	shots.update(1.0)
	assert_almost_eq(shots.position().x, 5.0, 0.01, "Halfway through the first move")
	shots.update(1.1)
	assert_eq(shots.caption(), "Two")
	shots.update(1.1)
	assert_true(shots.is_finished())
