extends GutTest
## The menu icon set knows its own names and never eats a tap meant for a button.

func test_every_name_reports_an_icon() -> void:
	for icon_name: String in MenuIcon.NAMES:
		assert_true(MenuIcon.has_icon(icon_name), "%s should have an icon" % icon_name)


func test_an_unknown_name_reports_nothing() -> void:
	assert_false(MenuIcon.has_icon("nope"))
	assert_false(MenuIcon.has_icon(""))


func test_setting_an_icon_draws_and_stays_out_of_the_way() -> void:
	var menu_icon := MenuIcon.new()
	add_child_autofree(menu_icon)
	menu_icon.size = Vector2(64.0, 64.0)
	assert_eq(menu_icon.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for icon_name: String in MenuIcon.NAMES:
		menu_icon.icon = icon_name
		assert_eq(menu_icon.icon, icon_name)
		assert_eq(menu_icon.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		# Let the control actually draw each shape.
		await wait_frames(1)
