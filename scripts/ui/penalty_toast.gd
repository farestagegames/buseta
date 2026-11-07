class_name PenaltyToast
extends Label
## Brief note when a driving fault is recorded, so a penalty is never a surprise
## at the end of the shift. Also shows tips, in yellow rather than red.

const SHOW_SECONDS := 2.6
const PENALTY_COLOUR := Color(1.0, 0.5, 0.4)
const HINT_COLOUR := Color(1.0, 0.86, 0.35)

var _timer: float = 0.0


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 24)
	add_theme_color_override("font_color", PENALTY_COLOUR)
	add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.06))
	add_theme_constant_override("outline_size", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameEvents.penalty_shown.connect(_show.bind(PENALTY_COLOUR))
	GameEvents.hint_shown.connect(_show.bind(HINT_COLOUR))


func _show(message: String, colour: Color) -> void:
	add_theme_color_override("font_color", colour)
	text = tr(message)
	_timer = SHOW_SECONDS
	visible = true
	modulate.a = 1.0


func _process(dt: float) -> void:
	if _timer <= 0.0:
		return
	_timer -= dt
	modulate.a = clampf(_timer / 0.6, 0.0, 1.0)
	if _timer <= 0.0:
		visible = false
