extends GutTest


func test_a_route_fits_inside_the_view() -> void:
	var view := RouteMapView.new()
	view.size = Vector2(400.0, 300.0)
	add_child_autofree(view)
	view.show_route(Profile.catalog.find(Catalog.ROUTES, "route_01"))
	assert_false(view.road_lines.is_empty(), "The town's roads")
	assert_gt(view.route_line.size(), 1, "The route")
	assert_false(view.stop_points.is_empty(), "Its stops")
	var rect := Rect2(Vector2.ZERO, view.size).grow(0.5)
	for point in view.route_line:
		assert_true(rect.has_point(view.to_view(point)), "Inside the card")


func test_a_route_without_a_file_draws_an_empty_map() -> void:
	var view := RouteMapView.new()
	add_child_autofree(view)
	view.show_route({})
	assert_true(view.route_line.is_empty())
	assert_true(view.road_lines.is_empty())
