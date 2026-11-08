class_name TouchScroll
extends ScrollContainer
## A vertical list that scrolls like a phone list: a finger can start the drag
## anywhere on it, on a card, a button or a slider, and a flick keeps it moving.
## A drag never presses a button. Only a tap does, and a tap that stops a moving
## list only stops it. Every scrolling list in the game is one of these.

## How far a finger can wander, in UI pixels, before a touch becomes a scroll.
## Below this it is still a tap, so a shaky finger can still press a button.
const DEADZONE := 14
## Physics ticks the offset must hold still before a flick counts as over. The
## tail of a flick moves less than a pixel a tick, so one still tick is not enough.
const STILL_TICKS := 4

var _blocked := false
## True from the moment a finger starts a scroll until any flick has died down.
var _moving := false
var _last_offset := 0
var _still_ticks := 0
var _restore_to := -1
var _restore_frames := 0


func _init() -> void:
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	scroll_deadzone = DEADZONE
	set_process(false)
	set_physics_process(false)
	child_entered_tree.connect(_watch)
	scroll_started.connect(_on_scroll_started)
	# Godot ends the scroll when the finger lifts, while a flick carries on.
	scroll_ended.connect(_watch_flick)
	get_v_scroll_bar().changed.connect(_apply_restore)


## True when the touch in progress has scrolled the list, or stopped a fling.
## Tap handlers on rows check this before acting.
func taps_blocked() -> bool:
	return _blocked


## Scrolls back to an offset once the new content has been laid out, so a list
## rebuilt after buying or selecting stays where the player was.
func restore_offset(offset: int) -> void:
	if offset <= 0:
		return
	_restore_to = offset
	_restore_frames = 2
	set_process(true)
	_apply_restore()


func _process(_dt: float) -> void:
	_apply_restore()
	_restore_frames -= 1
	if _restore_frames <= 0:
		_restore_to = -1
		set_process(false)


func _apply_restore() -> void:
	if _restore_to >= 0:
		scroll_vertical = _restore_to


## A finger landing sends a touch and the mouse press Godot makes from it, and a
## button arms itself on either, so both are checked.
func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	var touch := event as InputEventScreenTouch
	var landed := (mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT) \
		or (touch != null and touch.pressed and touch.index == 0)
	if not landed:
		return
	_blocked = false
	_restore_to = -1
	if _moving:
		# The finger landed on a moving list: it stops it, and presses nothing.
		_block_taps()


func _watch_flick() -> void:
	_last_offset = scroll_vertical
	_still_ticks = 0
	set_physics_process(true)


## Notices when a flick has come to rest.
func _physics_process(_dt: float) -> void:
	_still_ticks = _still_ticks + 1 if scroll_vertical == _last_offset else 0
	if _still_ticks >= STILL_TICKS:
		_moving = false
		set_physics_process(false)
	_last_offset = scroll_vertical


func _on_scroll_started() -> void:
	_moving = true
	_block_taps()


func _block_taps() -> void:
	_blocked = true
	propagate_notification(NOTIFICATION_SCROLL_BEGIN)


## Lets a drag that starts on anything inside reach the list. Buttons and cards
## stop the touch by default, which is why lists only scrolled from the gaps.
func _watch(node: Node) -> void:
	# A dropdown's popup is a window of its own, with its own input. Leave it be.
	if node is ScrollBar or node is Viewport:
		return
	var control := node as Control
	if control != null:
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
		var button := control as BaseButton
		if button != null:
			button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	if not node.child_entered_tree.is_connected(_watch):
		node.child_entered_tree.connect(_watch)
	for child in node.get_children():
		_watch(child)


## Calls action when the control is tapped, but not when a scroll passes over it.
static func on_tap(control: Control, action: Callable) -> void:
	var start := [Vector2.INF]
	control.gui_input.connect(func(event: InputEvent) -> void:
		var mouse := event as InputEventMouseButton
		if mouse == null or mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			start[0] = mouse.global_position
			return
		var from: Vector2 = start[0]
		start[0] = Vector2.INF
		if from == Vector2.INF or from.distance_to(mouse.global_position) > DEADZONE:
			return
		var list := find_list(control)
		if list == null or not list.taps_blocked():
			action.call())


## The nearest TouchScroll holding this control, or null.
static func find_list(node: Node) -> TouchScroll:
	var parent := node.get_parent()
	while parent != null:
		if parent is TouchScroll:
			return parent
		parent = parent.get_parent()
	return null


## The first TouchScroll inside a node, or null.
static func first_in(node: Node) -> TouchScroll:
	if node is TouchScroll:
		return node
	for child in node.get_children():
		var found := first_in(child)
		if found != null:
			return found
	return null
