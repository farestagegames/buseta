extends GutTest
## Unit tests for MenuTabBar: setup, selection, signals, touch targets and button press emission.

var tab_bar: MenuTabBar
var emitted_signals: Array = []

func before_each() -> void:
	tab_bar = MenuTabBar.new()
	tab_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child_autofree(tab_bar)
	tab_bar.size = Vector2(640, 120)

	# 5 items: 4 with labels only, 1 with a plain Control as icon
	var items := [
		{"label": "Home"},
		{"label": "Routes"},
		{"label": "Bus"},
		{"label": "Garage", "icon": Control.new()},
		{"label": "Settings"},
	]
	tab_bar.setup(items)
	emitted_signals.clear()

	# Watch tab_selected signal
	tab_bar.tab_selected.connect(_on_tab_selected)

func _on_tab_selected(index: int) -> void:
	emitted_signals.append(index)

func test_setup_creates_five_buttons() -> void:
	assert_eq(tab_bar.button_at(0).get_meta("tab_index"), 0)
	assert_eq(tab_bar.button_at(4).get_meta("tab_index"), 4)
	assert_true(tab_bar.button_at(5) == null)

func test_current_starts_at_zero() -> void:
	assert_eq(tab_bar.current, 0)
	var btn0 := tab_bar.button_at(0)
	assert_true(btn0.has_theme_stylebox_override("normal"))

func test_select_changes_current_and_emits_once() -> void:
	tab_bar.select(3)
	assert_eq(tab_bar.current, 3)
	assert_eq(emitted_signals.size(), 1)
	assert_eq(emitted_signals[0], 3)

func test_select_same_index_with_emit_false_does_not_emit() -> void:
	emitted_signals.clear()
	tab_bar.select(3, false)
	assert_eq(tab_bar.current, 3)
	assert_eq(emitted_signals.size(), 0)

func test_select_out_of_bounds_clamps() -> void:
	tab_bar.select(10)
	assert_eq(tab_bar.current, 4) # clamped to last index
	tab_bar.select(-5)
	assert_eq(tab_bar.current, 0) # clamped to first index

func test_every_button_is_at_least_48px_tall_and_wide() -> void:
	for i in 5:
		var btn := tab_bar.button_at(i)
		assert_true(btn.custom_minimum_size.x >= 48, "button %d width %d < 48" % [i, btn.custom_minimum_size.x])
		assert_true(btn.custom_minimum_size.y >= 48, "button %d height %d < 48" % [i, btn.custom_minimum_size.y])

func test_pressing_button_emits_tab_selected() -> void:
	emitted_signals.clear()
	var btn := tab_bar.button_at(2)
	btn.emit_signal("pressed")
	await get_tree().process_frame # allow signal propagation
	assert_eq(emitted_signals.size(), 1)
	assert_eq(emitted_signals[0], 2)
	assert_eq(tab_bar.current, 2)

func test_button_at_returns_correct_button() -> void:
	for i in 5:
		var btn := tab_bar.button_at(i)
		assert_true(btn != null)
		assert_eq(btn.get_meta("tab_index"), i)
	assert_true(tab_bar.button_at(-1) == null)
	assert_true(tab_bar.button_at(10) == null)

func test_active_tab_has_yellow_background_and_dark_outline() -> void:
	tab_bar.select(1)
	var active_btn := tab_bar.button_at(1)
	var normal_style := active_btn.get_theme_stylebox("normal")
	assert_true(normal_style is StyleBoxFlat)
	var flat := normal_style as StyleBoxFlat
	assert_eq(flat.bg_color, Color(1.0, 0.78, 0.2))
	assert_eq(flat.border_color, Color(0.13, 0.14, 0.18))
	assert_eq(flat.border_width_top, 3)

func test_inactive_tabs_have_transparent_background() -> void:
	tab_bar.select(1)
	var inactive_btn := tab_bar.button_at(0)
	var normal_style := inactive_btn.get_theme_stylebox("normal")
	assert_true(normal_style is StyleBoxFlat)
	var flat := normal_style as StyleBoxFlat
	assert_eq(flat.bg_color, Color(0, 0, 0, 0))
	assert_eq(flat.border_width_top, 0)

func test_icon_control_has_correct_size_and_mouse_filter() -> void:
	# The 4th item (index 3) has an icon
	var btn := tab_bar.button_at(3)
	# Button contains a VBoxContainer with icon and label
	var vbox := btn.get_child(0)
	assert_true(vbox is VBoxContainer)
	var icon := vbox.get_child(0)
	assert_true(icon is Control)
	assert_eq(icon.custom_minimum_size, MenuTabBar.ICON_SIZE)
	assert_eq(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_tabs_keep_clear_of_the_bar_and_button_edges() -> void:
	var panel := tab_bar.get_theme_stylebox("panel") as StyleBoxFlat
	assert_gt(panel.content_margin_left, float(MenuTabBar.BAR_OUTLINE_WIDTH), "Tabs clear of the bar's outline")
	assert_gt(panel.content_margin_top, float(MenuTabBar.BAR_OUTLINE_WIDTH))
	var vbox := tab_bar.button_at(0).get_child(0) as Control
	assert_gt(vbox.offset_top, 0.0, "Space over the icon")
	assert_lt(vbox.offset_bottom, 0.0, "Space under the label")
	assert_gte(MenuTabBar.BUTTON_MIN_SIZE.y, 48.0, "Still a thumb-sized target")

func test_label_is_uppercase() -> void:
	var btn := tab_bar.button_at(0)
	var vbox := btn.get_child(0)
	var label := vbox.get_child(1)
	assert_true(label is Label)
	assert_eq(label.text, "HOME")