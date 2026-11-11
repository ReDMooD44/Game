extends Control
## End-of-race card: where you finished, your times, which medal you earned.

signal restart_requested()
signal quit_to_title()

var _rows: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.03, 0.05, 0.93)
	add_child(shade)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	_rows.custom_minimum_size = Vector2(470, 0)
	centre.add_child(_rows)

func show_results(heading: String, lines: Array, medal: String) -> void:
	for c in _rows.get_children():
		c.queue_free()
	_label(heading, 38, Color(0.45, 1.0, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	if medal != "":
		_label(medal + " MADALYA", 26, _medal_colour(medal), HORIZONTAL_ALIGNMENT_CENTER)
	for line in lines:
		_label(str(line), 22, Color(1, 1, 1, 0.88), HORIZONTAL_ALIGNMENT_CENTER)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	_rows.add_child(gap)
	_button("TEKRAR", func(): restart_requested.emit())
	_button("ANA MENÜ", func(): quit_to_title.emit())
	visible = true
	get_tree().paused = true

static func _medal_colour(medal: String) -> Color:
	match medal:
		"AUTHOR": return Color(0.35, 1.0, 0.6)
		"GOLD": return Color(1.0, 0.82, 0.25)
		"SILVER": return Color(0.82, 0.85, 0.9)
		"BRONZE": return Color(0.82, 0.52, 0.3)
	return Color(1, 1, 1)

func _label(text: String, px: int, col: Color, align: int) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	_rows.add_child(l)

func _button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func():
		Audio.play("click")
		action.call())
	_rows.add_child(b)
