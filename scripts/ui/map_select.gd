extends Control
## Map picker. Each circuit is drawn from its own spline, so the shape on the
## card is the track you are about to fly, not an illustration of it.

signal closed()

const MODAL_GROUP := "modal_ui"
const CARD := Vector2(300.0, 240.0)
const SAMPLES := 150

var _cards: Array = []       # [{rect, index, line, name, best, medal}]
var _font: Font
var _was_paused := false
var _hover := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["monospace", "Consolas", "Droid Sans Mono"])
	_font = sf
	_load_tracks()

func _load_tracks() -> void:
	_cards.clear()
	for i in TrackGen.track_count():
		var path := TrackGen.track_path(i)
		var data: TrackData = load(path) if ResourceLoader.exists(path) else TrackGen.generate(i)
		if data == null:
			continue
		_cards.append({
			"index": i,
			"name": data.track_name,
			"line": _outline(data),
			"best": Settings.best_lap_for(data.track_name),
			"medal": Settings.best_medal_for(data.track_name),
			"rect": Rect2(),
		})

## Flattens the spline to x/z and normalises it into a unit square.
func _outline(data: TrackData) -> PackedVector2Array:
	var curve := data.build_curve()
	var length := curve.get_baked_length()
	var pts := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in SAMPLES:
		var p := curve.sample_baked(length * float(i) / SAMPLES)
		var v := Vector2(p.x, p.z)
		pts.append(v)
		lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.y))
		hi = Vector2(maxf(hi.x, v.x), maxf(hi.y, v.y))
	pts.append(pts[0])
	var span := maxf(maxf(hi.x - lo.x, hi.y - lo.y), 1.0)
	var centre := (lo + hi) * 0.5
	var out := PackedVector2Array()
	for v in pts:
		out.append((v - centre) / span)
	return out

func open() -> void:
	_load_tracks()
	visible = true
	add_to_group(MODAL_GROUP)
	_was_paused = get_tree().paused
	get_tree().paused = true
	queue_redraw()

func close_panel() -> void:
	remove_from_group(MODAL_GROUP)
	visible = false
	get_tree().paused = _was_paused
	closed.emit()

func _gui_input(_e: InputEvent) -> void:
	pass

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pos = event.position
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	else:
		return
	if not pressed:
		return
	for card in _cards:
		if (card["rect"] as Rect2).has_point(pos):
			Settings.track = int(card["index"])
			Settings.save_settings()
			Audio.play("click")
			close_panel()
			return
	# A tap anywhere else backs out.
	if not _panel_rect().has_point(pos):
		Audio.play("click")
		close_panel()

func _panel_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var w := CARD.x * _cards.size() + 24.0 * (_cards.size() + 1)
	var h := CARD.y + 110.0
	return Rect2((vp - Vector2(w, h)) * 0.5, Vector2(w, h))

func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.03, 0.05, 0.93), true)
	var panel := _panel_rect()
	draw_string(_font, Vector2(panel.position.x + 8, panel.position.y + 34), "HARİTA SEÇ",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.45, 1.0, 0.55))

	for i in _cards.size():
		var card: Dictionary = _cards[i]
		var r := Rect2(
			Vector2(panel.position.x + 24.0 + i * (CARD.x + 24.0), panel.position.y + 56.0),
			CARD)
		card["rect"] = r
		var chosen: bool = int(card["index"]) == Settings.track
		draw_rect(r, Color(0.09, 0.10, 0.13, 0.95), true)
		draw_rect(r, Color(0.45, 1.0, 0.55, 0.85) if chosen else Color(1, 1, 1, 0.22),
			false, 3.0 if chosen else 1.5)
		_draw_outline(card["line"], Rect2(r.position + Vector2(16, 34), r.size - Vector2(32, 86)))

		draw_string(_font, r.position + Vector2(14, 26), str(card["name"]).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(1, 1, 1, 0.95))
		var best: float = card["best"]
		var line := "En iyi: " + (Hud.format_time(best) if best > 0.0 else "--:--.---")
		draw_string(_font, r.position + Vector2(14, r.size.y - 30), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.7))
		var medal: String = card["medal"]
		if medal != "":
			draw_string(_font, r.position + Vector2(14, r.size.y - 10), medal,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.82, 0.25))

	draw_string(_font, Vector2(panel.position.x + 8, panel.end.y - 10),
		"Bir haritaya dokun · dışarı dokun = kapat",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.5))

func _draw_outline(line: PackedVector2Array, box: Rect2) -> void:
	if line.size() < 3:
		return
	var scale := minf(box.size.x, box.size.y)
	var centre := box.get_center()
	var pts := PackedVector2Array()
	for v in line:
		pts.append(centre + v * scale)
	draw_polyline(pts, Color(0.95, 0.80, 0.60, 0.9), 2.0, true)
