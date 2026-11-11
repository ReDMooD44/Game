extends Control
## Virtual stick on the left, airbrake and boost on the right.
## The stick is always drawn at a resting spot so you can see where to put your
## thumb, but it is still floating: press anywhere in the left half and it
## re-centres there, which is what survives different hand sizes.

@export var stick_radius := 125.0
@export var dead_zone := 0.08
@export var button_size := 150.0
@export var button_gap := 26.0

var _stick_origin := Vector2.ZERO
var _stick_point := Vector2.ZERO
var _stick_touch := -1
var _airbrake_touch := -1
var _boost_touch := -1
var _safe := Rect2()
var _boost_ratio := 1.0
var _boost_ready := true

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_safe_area()
	get_tree().get_root().size_changed.connect(_update_safe_area)

func _update_safe_area() -> void:
	# Size off the viewport, not the control: a Control parented straight to a
	# CanvasLayer never gets laid out, so its own size stays zero.
	var vp := get_viewport_rect().size
	_safe = Rect2(Vector2.ZERO, vp)
	if not OS.has_feature("mobile"):
		return
	var r := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if r.size.x <= 0 or win.x <= 0:
		return
	var sx := vp.x / float(win.x)
	var sy := vp.y / float(win.y)
	# Clip to the viewport: a safe area wider than the screen would push the
	# whole HUD off it, which is exactly what it is meant to prevent.
	_safe = Rect2(Vector2(r.position.x * sx, r.position.y * sy),
		Vector2(r.size.x * sx, r.size.y * sy)).intersection(Rect2(Vector2.ZERO, vp))
	if _safe.size.x < 100.0 or _safe.size.y < 100.0:
		_safe = Rect2(Vector2.ZERO, vp)

func set_boost_state(ratio: float, available: bool) -> void:
	_boost_ratio = clampf(ratio, 0.0, 1.0)
	_boost_ready = available
	queue_redraw()

## Where the stick sits when nobody is touching it.
func _rest_origin() -> Vector2:
	return Vector2(_safe.position.x + stick_radius + 46.0, _safe.end.y - stick_radius - 34.0)

func _origin() -> Vector2:
	return _stick_origin if _stick_touch >= 0 else _rest_origin()

func get_stick() -> Vector2:
	if _tilt_mode() or _stick_touch < 0:
		return Vector2.ZERO
	var d := (_stick_point - _stick_origin) / stick_radius
	if d.length() < dead_zone:
		return Vector2.ZERO
	return d.limit_length(1.0)

func get_airbrake() -> bool:
	return _airbrake_touch >= 0

func get_boost() -> bool:
	return _boost_touch >= 0

## With tilt steering the left half is free, so the thumb that used to hold
## the stick gets the afterburner instead.
func _tilt_mode() -> bool:
	return Settings.tilt_control

func _airbrake_rect() -> Rect2:
	var m := 40.0
	return Rect2(Vector2(_safe.end.x - button_size - m, _safe.end.y - button_size - m),
		Vector2(button_size, button_size))

func _boost_rect() -> Rect2:
	if _tilt_mode():
		return Rect2(Vector2(_safe.position.x + 46.0, _safe.end.y - button_size - 40.0),
			Vector2(button_size, button_size))
	var r := _airbrake_rect()
	return Rect2(Vector2(r.position.x - button_size - button_gap, r.position.y - button_size * 0.30),
		Vector2(button_size, button_size))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == _stick_touch:
		_stick_point = event.position
		queue_redraw()

func _handle_touch(e: InputEventScreenTouch) -> void:
	_update_safe_area()
	if e.pressed:
		if _airbrake_rect().has_point(e.position):
			_airbrake_touch = e.index
		elif _boost_rect().has_point(e.position):
			_boost_touch = e.index
		elif not _tilt_mode() and e.position.x < _safe.get_center().x and _stick_touch < 0:
			_stick_touch = e.index
			_stick_origin = e.position
			_stick_point = e.position
	else:
		if e.index == _stick_touch:
			_stick_touch = -1
		if e.index == _airbrake_touch:
			_airbrake_touch = -1
		if e.index == _boost_touch:
			_boost_touch = -1
	queue_redraw()

func _draw() -> void:
	_update_safe_area()
	if not _tilt_mode():
		_draw_stick()
	_draw_button(_airbrake_rect(), "BRAKE", Color(0.85, 0.92, 1.0), _airbrake_touch >= 0, 1.0)
	var boost_tint := Color(1.0, 0.78, 0.32) if _boost_ready else Color(0.55, 0.55, 0.58)
	_draw_button(_boost_rect(), "BOOST", boost_tint, _boost_touch >= 0 and _boost_ready,
		_boost_ratio)

func _draw_stick() -> void:
	var o := _origin()
	var active := _stick_touch >= 0
	var ring := Color(1, 1, 1, 0.26 if active else 0.16)
	draw_circle(o, stick_radius, Color(0, 0, 0, 0.16))
	draw_arc(o, stick_radius, 0.0, TAU, 56, ring, 3.0, true)
	# Faint cross so the axes are readable before you touch anything.
	var tick := Color(1, 1, 1, 0.12)
	draw_line(o - Vector2(stick_radius * 0.55, 0), o + Vector2(stick_radius * 0.55, 0), tick, 2.0)
	draw_line(o - Vector2(0, stick_radius * 0.55), o + Vector2(0, stick_radius * 0.55), tick, 2.0)

	var knob := o
	if active:
		knob = o + (_stick_point - o).limit_length(stick_radius)
	draw_circle(knob, 46.0, Color(1, 1, 1, 0.30 if active else 0.18))
	draw_arc(knob, 46.0, 0.0, TAU, 32, Color(0.45, 1.0, 0.55, 0.75 if active else 0.45), 3.0, true)

func _draw_button(r: Rect2, label: String, tint: Color, held: bool, fill_ratio: float) -> void:
	draw_rect(r, Color(0, 0, 0, 0.22), true)
	if fill_ratio < 0.999:
		# Boost draws its remaining charge as a rising fill.
		var fill := r
		fill.position.y += r.size.y * (1.0 - fill_ratio)
		fill.size.y *= fill_ratio
		draw_rect(fill, Color(tint.r, tint.g, tint.b, 0.22), true)
	else:
		draw_rect(r, Color(tint.r, tint.g, tint.b, 0.22 if not held else 0.42), true)
	if held:
		draw_rect(r, Color(tint.r, tint.g, tint.b, 0.42), true)
	draw_rect(r, Color(tint.r, tint.g, tint.b, 0.85), false, 3.0)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(font, r.position + Vector2((r.size.x - w) * 0.5, r.size.y * 0.58),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(tint.r, tint.g, tint.b, 0.95))
