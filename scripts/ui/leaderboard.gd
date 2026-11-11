extends Control
## Live order of the field, in the style of the reference board: names right
## aligned against their position, the player picked out in green, everyone
## behind him dimmed. Refreshed a few times a second rather than every frame -
## positions do not change at 60 Hz and sorting six racers is not free.

const GREEN := Color(0.45, 1.0, 0.55)
const REFRESH := 0.2

var race: RaceManager
var player: Node3D
var player_name := "SEN"

var _rows: Array = []        # [{name, place, is_player}]
var _font: Font
var _timer := 0.0
var _safe := Rect2()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["monospace", "Consolas", "Droid Sans Mono"])
	_font = sf

func setup(race_node: RaceManager, player_node: Node3D) -> void:
	race = race_node
	player = player_node
	_rebuild()

func _process(delta: float) -> void:
	if race == null:
		return
	_timer += delta
	if _timer < REFRESH:
		return
	_timer = 0.0
	_rebuild()
	queue_redraw()

func _rebuild() -> void:
	if race == null:
		return
	var entries := []
	for r in race.racers:
		if r == null or not is_instance_valid(r):
			continue
		var is_player: bool = r == player
		var label: String = player_name if is_player else str(r.pilot_name) if "pilot_name" in r else "BOT"
		entries.append({"p": race.progress_of(r), "name": label, "me": is_player})
	entries.sort_custom(func(a, b): return a["p"] > b["p"])
	_rows.clear()
	for i in entries.size():
		_rows.append({"name": entries[i]["name"], "place": i + 1, "me": entries[i]["me"]})

func _draw() -> void:
	if _rows.is_empty():
		return
	var vp := get_viewport_rect().size
	_safe = Rect2(Vector2.ZERO, vp)

	var row_h := 30.0
	var w := 230.0
	var h := row_h * _rows.size() + 34.0
	var r := Rect2(Vector2(_safe.end.x - w - 14.0, _safe.position.y + 10.0), Vector2(w, h))

	draw_rect(r, Color(0.05, 0.07, 0.09, 0.55), true)
	draw_rect(r, Color(1, 1, 1, 0.14), false, 1.5)
	# Header rule, like the dotted divider on the reference board.
	var y := r.position.y + 24.0
	draw_string(_font, Vector2(r.position.x + 12, y), "SIRALAMA",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, 0.55))
	draw_line(Vector2(r.position.x + 10, y + 7), Vector2(r.end.x - 10, y + 7),
		Color(0.45, 1.0, 0.55, 0.35), 1.0)

	var found_me := false
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var top := r.position.y + 32.0 + i * row_h
		var me: bool = row["me"]
		if me:
			found_me = true
			draw_rect(Rect2(Vector2(r.position.x + 4, top + 2), Vector2(w - 8, row_h - 4)),
				Color(0.20, 0.55, 0.28, 0.75), true)
		var col := GREEN if me else Color(1, 1, 1, 0.85 if not found_me else 0.45)
		var name_text: String = str(row["name"]).to_upper()
		var place_text := str(row["place"])
		var text_y := top + row_h - 9.0
		# Name right-aligned against the number column, as on the reference.
		var nw := _font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(_font, Vector2(r.end.x - 34 - nw, text_y), name_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		draw_string(_font, Vector2(r.end.x - 24, text_y), place_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
