extends GutTest
## The driver can tell from the cockpit when the last rider is off.


func test_nobody_getting_off_shows_nothing() -> void:
	var cue := AlightingCue.new()
	cue.start(0)
	assert_false(cue.is_shown())


func test_counts_down_to_everyone_off() -> void:
	var cue := AlightingCue.new()
	cue.start(3)
	assert_eq(cue.state, AlightingCue.State.GETTING_OFF)
	assert_eq(cue.left, 3)
	cue.alighted()
	cue.alighted()
	assert_eq(cue.left, 1)
	assert_eq(cue.state, AlightingCue.State.GETTING_OFF)
	cue.alighted()
	assert_eq(cue.left, 0)
	assert_eq(cue.state, AlightingCue.State.ALL_OFF)
	assert_true(cue.is_shown(), "Everyone's off stays up until the bus leaves")


func test_extra_alightings_never_go_below_zero() -> void:
	var cue := AlightingCue.new()
	cue.start(1)
	cue.alighted()
	cue.alighted()
	assert_eq(cue.left, 0)
	assert_eq(cue.state, AlightingCue.State.ALL_OFF)


func test_alighting_without_a_stop_does_nothing() -> void:
	var cue := AlightingCue.new()
	cue.alighted()
	assert_false(cue.is_shown())


func test_leaving_the_stop_hides_it_even_with_people_still_on() -> void:
	var cue := AlightingCue.new()
	cue.start(4)
	cue.alighted()
	cue.end()
	assert_false(cue.is_shown())
	assert_eq(cue.left, 0)


func test_next_stop_starts_fresh() -> void:
	var cue := AlightingCue.new()
	cue.start(1)
	cue.alighted()
	cue.end()
	cue.start(2)
	assert_eq(cue.state, AlightingCue.State.GETTING_OFF)
	assert_eq(cue.left, 2)


func test_hud_shows_the_count_and_then_everyone_off() -> void:
	var hud: DriveHud = add_child_autofree(DriveHud.new())
	assert_false(hud.alighting_label.visible)
	GameEvents.stop_session_started.emit(1, 2, 0)
	assert_true(hud.alighting_label.visible)
	assert_eq(hud.alighting_label.text, tr("Getting off: %d") % 2)
	GameEvents.passenger_alighted.emit(1)
	assert_eq(hud.alighting_label.text, tr("Getting off: %d") % 1)
	GameEvents.passenger_alighted.emit(1)
	assert_eq(hud.alighting_label.text, tr("Everyone's off"))
	GameEvents.stop_served.emit(1, "Parque", 0)
	assert_false(hud.alighting_label.visible)
