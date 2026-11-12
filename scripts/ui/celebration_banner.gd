class_name CelebrationBanner
extends Control
## Mid-shift celebration: confetti and a short banner with a coin reward.
## Never blocks controls and stays clear of the HUD edges.

const SHOW_SECONDS := 2.6
const CONFETTI_COUNT := 28

var _timer: float = 0.0
var _text: String = ""
var _coins_text: String = ""
var _confetti: Array[Dictionary] = []
var _random := RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_random.seed = 991


func show_celebration(text: String, coins: int) -> void:
	_text = tr(text)
	_coins_text = ("+%s" % Country.pack.money(coins)) if coins > 0 else ""
	_timer = SHOW_SECONDS
	visible = true
	modulate.a = 1.0
	_spawn_confetti()
	set_process(true)
	queue_redraw()


func _spawn_confetti() -> void:
	_confetti.clear()
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280, 720)
	var cx := view_size.x * 0.5
	var top := view_size.y * 0.22
	var colours := [
		Color(0.98, 0.72, 0.2), Color(0.35, 0.85, 0.55), Color(0.95, 0.45, 0.35),
		Color(0.45, 0.7, 1.0), Color(0.95, 0.9, 0.5),
	]
	for i in CONFETTI_COUNT:
		var angle := _random.randf_range(-PI * 0.95, -PI * 0.05)
		var speed := _random.randf_range(120.0, 320.0)
		_confetti.append({
			"pos": Vector2(cx + _random.randf_range(-60.0, 60.0), top),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"color": colours[_random.randi() % colours.size()],
			"size": Vector2(_random.randf_range(6.0, 12.0), _random.randf_range(4.0, 8.0)),
			"rot": _random.randf_range(0.0, TAU),
			"spin": _random.randf_range(-8.0, 8.0),
		})


func _process(dt: float) -> void:
	if _timer <= 0.0:
		visible = false
		set_process(false)
		return
	_timer -= dt
	var fade := clampf(_timer / 0.5, 0.0, 1.0)
	for piece: Dictionary in _confetti:
		var vel: Vector2 = piece["vel"]
		vel.y += 420.0 * dt
		vel.x *= pow(0.98, dt * 60.0)
		piece["vel"] = vel
		piece["pos"] = (piece["pos"] as Vector2) + vel * dt
		piece["rot"] = float(piece["rot"]) + float(piece["spin"]) * dt
	modulate.a = 1.0 if _timer > 0.5 else fade
	if _timer <= 0.0:
		visible = false
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font
	# Confetti
	for piece: Dictionary in _confetti:
		var p: Vector2 = piece["pos"]
		var s: Vector2 = piece["size"]
		var c: Color = piece["color"]
		c.a *= modulate.a
		draw_set_transform(p, float(piece["rot"]), Vector2.ONE)
		draw_rect(Rect2(-s * 0.5, s), c, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _text == "":
		return
	var view_size := get_viewport_rect().size
	if view_size == Vector2.ZERO:
		view_size = Vector2(1280, 720)
	var centre := Vector2(view_size.x * 0.5, view_size.y * 0.26)
	var panel_w := minf(620.0, view_size.x - 80.0)
	var panel_h := 86.0 if _coins_text == "" else 112.0
	var rect := Rect2(centre.x - panel_w * 0.5, centre.y - panel_h * 0.5, panel_w, panel_h)
	var bg := Color(0.1, 0.12, 0.16, 0.92 * modulate.a)
	draw_rect(rect, bg, true)
	draw_rect(rect, Color(0.98, 0.78, 0.25, 0.9 * modulate.a), false, 3.0)
	var text_size := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 34)
	var text_pos := Vector2(centre.x - text_size.x * 0.5, rect.position.y + 44.0)
	draw_string(font, text_pos + Vector2(1, 1), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0, 0, 0, 0.5 * modulate.a))
	draw_string(font, text_pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1, modulate.a))
	if _coins_text != "":
		var csize := font.get_string_size(_coins_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
		var cpos := Vector2(centre.x - csize.x * 0.5, rect.position.y + 82.0)
		draw_string(font, cpos, _coins_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.98, 0.85, 0.35, modulate.a))
