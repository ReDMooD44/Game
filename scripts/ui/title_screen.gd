extends Control
## Title screen: pick a mode, pick a difficulty, go. Also the only place the
## player can leave the game, because on Android there is no window to close.

const GREEN := Color(0.45, 1.0, 0.55)
const DIFFICULTY_NAMES := ["KOLAY", "NORMAL", "ZOR"]

var _rows: VBoxContainer
var _difficulty_button: Button
var _map_button: Button
var _best_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_menu()

func _build_background() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	# The same strata strip the canyon uses, stretched into a backdrop.
	bg.texture = StrataTexture.strip()
	bg.modulate = Color(0.55, 0.45, 0.40)
	add_child(bg)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.04, 0.06, 0.55)
	add_child(shade)

func _build_menu() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	_rows.custom_minimum_size = Vector2(460, 0)
	centre.add_child(_rows)

	var title := Label.new()
	title.text = "CANYON JET RACER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", GREEN)
	_rows.add_child(title)

	_best_label = Label.new()
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.add_theme_font_size_override("font_size", 20)
	_best_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_rows.add_child(_best_label)
	_refresh_best()

	_rows.add_child(_spacer(14))
	_button("YARIŞ  (5 bota karşı)", func(): _start(0))
	_button("TIME TRIAL  (ghost ile)", func(): _start(1))
	_difficulty_button = _button("ZORLUK: " + DIFFICULTY_NAMES[Settings.difficulty], _cycle_difficulty)
	_map_button = _button("HARİTA: " + _track_name(), _open_maps)
	_button("AYARLAR", _open_settings)
	_rows.add_child(_spacer(8))
	_button("ÇIKIŞ", func(): get_tree().quit())

	var hint := Label.new()
	hint.text = "Sol başparmak: joystick · Sağ: BOOST / BRAKE · Gaz otomatik"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_rows.add_child(_spacer(10))
	_rows.add_child(hint)
	# The rock and plant models are Loafbrr's Canyon Set, released CC0.
	# Attribution is not required by that licence; it is theirs, so it is here.
	var credit := Label.new()
	credit.text = "Kaya ve bitki modelleri: Loafbrr Canyon Set (CC0)"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 14)
	credit.add_theme_color_override("font_color", Color(1, 1, 1, 0.38))
	_rows.add_child(credit)

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func():
		Audio.play("click")
		action.call())
	_rows.add_child(b)
	return b

func _refresh_best() -> void:
	var best: float = Settings.best_lap_for(str(TrackGen.preset(Settings.track)["name"]))
	if best > 0.0:
		var medal: String = Settings.best_medal_for(str(TrackGen.preset(Settings.track)["name"]))
		_best_label.text = "En iyi tur  %s%s" % [Hud.format_time(best),
			"   " + medal if medal != "" else ""]
	else:
		_best_label.text = "Henüz tur yok"

func _cycle_difficulty() -> void:
	Settings.difficulty = (Settings.difficulty + 1) % 3
	Settings.save_settings()
	_difficulty_button.text = "ZORLUK: " + DIFFICULTY_NAMES[Settings.difficulty]

func _track_name() -> String:
	return str(TrackGen.preset(Settings.track)["name"]).to_upper()

func _open_maps() -> void:
	var picker := preload("res://scripts/ui/map_select.gd").new()
	add_child(picker)
	picker.closed.connect(func():
		_map_button.text = "HARİTA: " + _track_name()
		_refresh_best())
	picker.open()

func _open_settings() -> void:
	var panel := preload("res://scripts/ui/settings_panel.gd").new()
	add_child(panel)
	panel.open()

func _start(mode: int) -> void:
	Settings.mode = mode
	Settings.save_settings()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	# A settings panel owns the back button while it is up.
	if preload("res://scripts/ui/settings_panel.gd").modal_open(get_tree()):
		return
	get_tree().quit()
