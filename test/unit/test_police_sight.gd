extends GutTest
## PoliceSight: the patrol's view cone and range.


func test_straight_ahead_in_range_is_seen() -> void:
	var eye := Vector2(0, 0)
	var forward := Vector2(0, -1)
	var target := Vector2(0, -10)
	assert_true(PoliceSight.in_view(eye, forward, target), "straight ahead in range should be seen")


func test_straight_behind_is_not() -> void:
	var eye := Vector2(0, 0)
	var forward := Vector2(0, -1)
	var target := Vector2(0, 10)
	assert_false(PoliceSight.in_view(eye, forward, target), "straight behind should not be seen")


func test_beyond_range_ahead_is_not() -> void:
	var eye := Vector2(0, 0)
	var forward := Vector2(0, -1)
	var target := Vector2(0, -100)
	assert_false(PoliceSight.in_view(eye, forward, target), "beyond range ahead should not be seen")


func test_exactly_at_range_is_seen() -> void:
	var eye := Vector2(0, 0)
	var forward := Vector2(0, -1)
	var target := Vector2(0, -70)
	assert_true(PoliceSight.in_view(eye, forward, target), "exactly at range should be seen")


func test_just_inside_cone_edge_is_seen() -> void:
	var eye := Vector2(0, 0)
	var forward := Vector2(1, 1).normalized()
	## 59 degrees from forward is inside the 60-degree cone.
	var target := eye + forward.rotated(deg_to_rad(59.0)) * 50.0
	assert_true(PoliceSight.in_view(eye, forward, target), "just inside cone edge should be seen")


func test_just_outside_cone_edge_is_not() -> void:
	var eye := Vector2(0, 0)
	var forward := Vector2(1, 1).normalized()
	## 61 degrees from forward is outside the 60-degree cone.
	var target := eye + forward.rotated(deg_to_rad(-61.0)) * 50.0
	assert_false(PoliceSight.in_view(eye, forward, target), "just outside cone edge should not be seen")


func test_unnormalised_forward_works() -> void:
	var eye := Vector2(0, 0)
	var forward := Vector2(0, -5) # unnormalised, same as Vector2(0, -1)
	var target := Vector2(0, -10)
	assert_true(PoliceSight.in_view(eye, forward, target), "unnormalised forward should work same as normalised")


func test_zero_forward_see_nothing() -> void:
	var eye := Vector2(0, 0)
	var forward := Vector2(0, 0)
	var target := Vector2(0, -10)
	assert_false(PoliceSight.in_view(eye, forward, target), "zero forward should see nothing")


func test_custom_half_angle_90_sees_to_side() -> void:
	var eye := Vector2(0, 0)
	var forward := Vector2(0, -1)
	## 90 degrees should see to the sides (90 degrees left and right)
	var target_left := Vector2(-10, -0.5)
	var target_right := Vector2(10, -0.5)
	assert_true(PoliceSight.in_view(eye, forward, target_left, 90.0), "90-degree cone left should be seen")
	assert_true(PoliceSight.in_view(eye, forward, target_right, 90.0), "90-degree cone right should be seen")


func test_custom_range_argument_is_respected() -> void:
	var eye := Vector2(0, 0)
	var forward := Vector2(0, -1)
	## Target at -50 is within custom range of 60, but -70 is beyond
	var target_near := Vector2(0, -50)
	var target_far := Vector2(0, -70)
	assert_true(PoliceSight.in_view(eye, forward, target_near, PoliceSight.HALF_ANGLE_DEGREES, 60.0), "within custom range should be seen")
	assert_false(PoliceSight.in_view(eye, forward, target_far, PoliceSight.HALF_ANGLE_DEGREES, 60.0), "beyond custom range should not be seen")

func test_a_building_between_blocks_the_sight_ray() -> void:
	var police := PoliceSystem.new()
	add_child_autofree(police)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 10.0, 4.0)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(1000.0, 0.0, -20.0)
	add_child_autofree(wall)
	await wait_physics_frames(2)
	assert_true(police._wall_between(Vector2(1000.0, 0.0), Vector2(1000.0, -40.0)), "the wall is in the way")
	assert_false(police._wall_between(Vector2(1010.0, 0.0), Vector2(1010.0, -40.0)), "a clear street beside it")
