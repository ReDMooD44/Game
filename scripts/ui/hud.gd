class_name Hud
extends Control
## Flight HUD. Layout follows the reference footage, with the lap panel moved
## from the bottom to the top: on a phone the bottom strip is under your thumbs.
## Everything is drawn in one pass; the only other element is the vignette rect.

const GREEN := Color(0.45, 1.0, 0.55)
const AMBER := Color(1.0, 0.78, 0.25)
const RED := Color(1.0, 0.33, 0.28)
const DIM := Color(0.45, 1.0, 0.55, 0.55)

var knots := 0.0
var mach := 0.0
var g_force := 1.0
var g_limit := 9.0
var braking := false
var boost_ratio := 1.0
var lap := 1
var total_laps := 3
var sector := 1
var total_sectors := 4
var lap_time := 0.0
var last_lap := 0.0
var best_lap := 0.0
var medal := ""
var position_text := ""
var gap_ahead := ""
var gap_behind := ""
var countdown_text := ""
var flight_path := Vector2.ZERO      ## screen-space velocity vector marker
var message := ""

var _delta_text := ""
var _delta_colour := GREEN
var _delta_life := 0.0
var _message_life := 0.0
var _font: Font
var _safe := Rect2()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["monospace", "Consolas", "Droid Sans Mono", "DejaVu Sans Mono"])
	_font = sf
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

func show_delta(value: float) -> void:
	_delta_text = ("%+.3f" % value).replace("+-", "-")
	_delta_colour = GREEN if value <= 0.0 else RED
	_delta_life = 1.5

func show_message(text: String, seconds := 2.0) -> void:
	message = text
	_message_life = seconds

func _process(delta: float) -> void:
	_delta_life = maxf(0.0, _delta_life - delta)
	_message_life = maxf(0.0, _message_life - delta)
	if _message_life <= 0.0:
		message = ""
	queue_redraw()

func _draw() -> void:
	# Recomputed per draw: the control has no size yet in _ready, and caching
	# that zero rect is what pushes the whole HUD into the top-left corner.
	_update_safe_area()
	_draw_speed_box()
	_draw_g_box()
	_draw_reticle()
	_draw_lap_panel()
	_draw_standings()
	_draw_delta()
	_draw_countdown()
	_draw_message()

func _label(pos: Vector2, text: String, px: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		p.x -= _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		p.x -= _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x * 0.5
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

func _box(rect: Rect2, col: Color) -> void:
	draw_rect(rect, Color(0, 0, 0, 0.30), true)
	draw_rect(rect, col, false, 2.0)

func _draw_speed_box() -> void:
	var y := _safe.position.y + _safe.size.y * 0.5
	var x := _safe.position.x + 10.0
	_label(Vector2(x + 8, y - 44), "KT", 20, DIM)
	var r := Rect2(Vector2(x, y - 38), Vector2(150, 56))
	_box(r, GREEN)
	_label(Vector2(x + 10, y + 4), "%d" % roundi(knots), 44, GREEN)
	_label(Vector2(x + 6, y + 44), "M %.2f" % mach, 24, GREEN)
	if braking:
		_label(Vector2(x + 6, y + 76), "BRAKE", 24, AMBER)

func _draw_g_box() -> void:
	var y := _safe.position.y + _safe.size.y * 0.5
	var x := _safe.end.x - 160.0
	var col := GREEN
	if g_force >= g_limit:
		col = RED
	elif g_force >= g_limit - 1.0:
		col = AMBER
	_label(Vector2(x + 8, y - 44), "G", 20, DIM)
	_box(Rect2(Vector2(x, y - 38), Vector2(150, 56)), col)
	_label(Vector2(x + 14, y + 4), "%.1f" % g_force, 44, col)
	_label(Vector2(x + 6, y + 40), "G-LIM", 22, DIM)

## The gunsight sits at the true centre of the screen, not the centre of the
## safe area - a notch inset would otherwise push the crosshair off-centre.
## The flight path marker is kept clear of it and leashed to a radius, so the
## two never collapse into one smudge and the marker never leaves the screen.
func _draw_reticle() -> void:
	var c := get_viewport_rect().size * 0.5
	var pale := Color(1, 1, 1, 0.5)
	draw_arc(c, 7.0, 0.0, TAU, 16, pale, 1.5, true)
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * 13.0, c + d * 22.0, pale, 1.5)

	var leash := minf(get_viewport_rect().size.y * 0.33, 220.0)
	var fp := c + flight_path.limit_length(leash)
	if fp.distance_to(c) < 26.0:
		return                      # on the nose: the crosshair already says so
	draw_arc(fp, 11.0, 0.0, TAU, 20, GREEN, 2.0, true)
	draw_line(fp + Vector2(11, 0), fp + Vector2(20, 0), GREEN, 2.0)
	draw_line(fp - Vector2(20, 0), fp - Vector2(11, 0), GREEN, 2.0)
	draw_line(fp - Vector2(0, 20), fp - Vector2(0, 11), GREEN, 2.0)

func _draw_lap_panel() -> void:
	var w := 430.0
	var h := 112.0
	var r := Rect2(Vector2(_safe.position.x + (_safe.size.x - w) * 0.5, _safe.position.y + 8.0),
		Vector2(w, h))
	draw_rect(r, Color(0.05, 0.05, 0.07, 0.55), true)
	draw_rect(r, Color(1, 1, 1, 0.18), false, 1.5)
	var p := r.position + Vector2(14, 30)
	_label(p, "Lap", 22, Color(1, 1, 1, 0.75))
	_label(p + Vector2(84, 0), format_time(lap_time), 24, Color(1, 1, 1, 0.95))
	_label(p + Vector2(0, 28), "Last", 22, Color(1, 1, 1, 0.75))
	_label(p + Vector2(84, 28), format_time(last_lap), 24, Color(1, 1, 1, 0.95))
	_label(p + Vector2(0, 56), "Best", 22, Color(1, 1, 1, 0.75))
	_label(p + Vector2(84, 56), format_time(best_lap), 24, Color(0.75, 0.6, 1.0))

	_label(Vector2(r.end.x - 14, r.position.y + 26), "LAP", 20, Color(1, 1, 1, 0.7),
		HORIZONTAL_ALIGNMENT_RIGHT)
	_label(Vector2(r.end.x - 14, r.position.y + 58), "%d/%d" % [lap, total_laps], 30,
		Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_RIGHT)
	_label(Vector2(r.end.x - 14, r.position.y + 86), "SEC %d/%d" % [sector, total_sectors], 20,
		Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	if medal != "":
		draw_circle(Vector2(r.position.x + 16, r.end.y + 16), 7.0, _medal_colour())
		_label(Vector2(r.position.x + 30, r.end.y + 23), medal, 22, _medal_colour())

func _medal_colour() -> Color:
	match medal:
		"AUTHOR": return Color(0.35, 1.0, 0.6)
		"GOLD": return Color(1.0, 0.82, 0.25)
		"SILVER": return Color(0.82, 0.85, 0.9)
		"BRONZE": return Color(0.82, 0.52, 0.3)
	return Color(1, 1, 1)

## Gaps to the racers either side, printed under the standings board.
func _draw_standings() -> void:
	if gap_ahead == "" and gap_behind == "":
		return
	var x := get_viewport_rect().size.x - 24.0
	var y := _safe.position.y + 42.0 + 30.0 * 6.0 + 26.0
	if gap_ahead != "":
		_label(Vector2(x, y), gap_ahead, 20, Color(1, 0.6, 0.5), HORIZONTAL_ALIGNMENT_RIGHT)
	if gap_behind != "":
		_label(Vector2(x, y + 24), gap_behind, 20, Color(0.6, 1, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)

func _draw_delta() -> void:
	if _delta_life <= 0.0:
		return
	var t := _delta_life / 1.5
	var c := _delta_colour
	c.a = clampf(t * 1.6, 0.0, 1.0)
	var pos := _safe.position + Vector2(_safe.size.x * 0.5, _safe.size.y * 0.33 - (1.0 - t) * 48.0)
	_label(pos, _delta_text, 40, c, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_countdown() -> void:
	if countdown_text == "":
		return
	var c := _safe.position + _safe.size * Vector2(0.5, 0.42)
	_label(c, countdown_text, 110, Color(1, 1, 1, 0.92), HORIZONTAL_ALIGNMENT_CENTER)

func _draw_message() -> void:
	if message == "":
		return
	var c := _safe.position + _safe.size * Vector2(0.5, 0.72)
	_label(c, message, 34, Color(1, 1, 1, clampf(_message_life, 0.0, 1.0)),
		HORIZONTAL_ALIGNMENT_CENTER)

## Wall-clock style, for how long someone has been playing rather than how
## fast a lap was: hours only once there are any.
static func format_clock(seconds: float) -> String:
	var whole := int(maxf(seconds, 0.0))
	var hours := whole / 3600
	var mins := (whole % 3600) / 60
	var secs := whole % 60
	if hours > 0:
		return "%d sa %02d dk" % [hours, mins]
	return "%d dk %02d sn" % [mins, secs]

static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--.---"
	var m := int(seconds) / 60
	var s := seconds - m * 60
	return "%02d:%06.3f" % [m, s]
