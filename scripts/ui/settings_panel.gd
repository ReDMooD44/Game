extends Control
## Modal settings. Shared by the title screen and the in-game pause menu, so
## the two can never drift apart. Every row cycles one value and saves.

signal closed()

const QUALITY_NAMES := ["DÜŞÜK", "ORTA", "YÜKSEK"]
const DIFFICULTY_NAMES := ["KOLAY", "NORMAL", "ZOR"]

var _rows: VBoxContainer
var _column: VBoxContainer
var _was_paused := false

## Anything in this group is a modal: the back button belongs to it, not to
## whatever is underneath. Without this, back from the settings closed the
## panel AND quit the game, because the notification reaches every node.
const MODAL_GROUP := "modal_ui"

static func modal_open(tree: SceneTree) -> bool:
	return tree != null and tree.get_node_count_in_group(MODAL_GROUP) > 0

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

	var panel := PanelContainer.new()
	# The default theme panel is translucent; over a game frame that reads as
	# a smear rather than a dialog.
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.10, 0.09, 0.11)
	box.border_color = Color(0.45, 1.0, 0.55, 0.35)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", box)
	centre.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	# Scrolled, because the list is now longer than a 720-high screen and the
	# close button was falling off the bottom of it.
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	margin.add_child(_column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(470, 520)
	_column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	add_to_group(MODAL_GROUP)
	_build()

## Shows the skin, and what it takes to get the next one that is still
## locked, so the list of goals is visible instead of being a surprise.
func _trail_label() -> String:
	var skin := Settings.trail_skin
	var text := "İz efekti: " + TrailSkins.skin_name(skin)
	var locked := _first_locked()
	if locked >= 0:
		text += "   (sıradaki: " + Progression.requirement(locked) + ")"
	return text

func _first_locked() -> int:
	for i in TrailSkins.count():
		if not Settings.is_skin_unlocked(i):
			return i
	return -1

## Steps over anything not earned yet, so a locked skin can never be worn.
func _next_skin(from: int) -> int:
	for step in range(1, TrailSkins.count() + 1):
		var candidate := wrapi(from + step, 0, TrailSkins.count())
		if Settings.is_skin_unlocked(candidate):
			return candidate
	return 0

func _build() -> void:
	_title("AYARLAR")
	_row(_trail_label, func(): Settings.trail_skin = _next_skin(Settings.trail_skin))
	_row(func(): return "Oyun süresi hatırlatıcı: " + (
			"kapalı" if Settings.reminder_minutes <= 0
			else "%d dk" % Settings.reminder_minutes),
		func():
			var steps := [0, 20, 30, 45, 60, 90]
			var at := steps.find(Settings.reminder_minutes)
			Settings.reminder_minutes = int(steps[(at + 1) % steps.size()]))
	_row(func(): return "Zorluk: " + DIFFICULTY_NAMES[Settings.difficulty],
		func(): Settings.difficulty = (Settings.difficulty + 1) % 3)
	_row(func(): return "Grafik: " + QUALITY_NAMES[Settings.quality],
		func():
			Settings.quality = (Settings.quality + 1) % 3
			Settings.apply())
	_row(func(): return "Kare hızı: %d fps" % Settings.target_fps,
		func():
			Settings.target_fps = 30 if Settings.target_fps == 60 else 60
			Settings.apply())
	_row(func(): return "Ses: " + _on_off(Settings.sound),
		func():
			Settings.sound = not Settings.sound
			Audio.apply_volume())
	_row(func(): return "Efekt sesi: %s" % _level(Settings.volume),
		func():
			Settings.volume = _step(Settings.volume)
			Audio.apply_volume())
	_row(func(): return "Müzik: " + _on_off(Settings.music),
		func():
			Settings.music = not Settings.music
			Audio.apply_volume())
	_row(func(): return "Müzik sesi: %s" % _level(Settings.music_volume),
		func():
			Settings.music_volume = _step(Settings.music_volume)
			Audio.apply_volume())
	_row(func(): return "Flight assist: " + _on_off(Settings.flight_assist),
		func(): Settings.flight_assist = not Settings.flight_assist)
	_row(func(): return "Tilt kontrol: " + _on_off(Settings.tilt_control),
		func(): Settings.tilt_control = not Settings.tilt_control)
	_row(func(): return "Tilt hassasiyeti: %.1fx" % Settings.tilt_sensitivity,
		func():
			Settings.tilt_sensitivity += 0.25
			if Settings.tilt_sensitivity > 2.01:
				Settings.tilt_sensitivity = 0.5)
	_row(func(): return "Titreşim: " + _on_off(Settings.haptics),
		func(): Settings.haptics = not Settings.haptics)
	_row(func(): return "Rubber band: " + _on_off(Settings.rubber_banding),
		func(): Settings.rubber_banding = not Settings.rubber_banding)

	var close := Button.new()
	close.text = "KAPAT"
	close.custom_minimum_size = Vector2(0, 46)
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func():
		Audio.play("click")
		close_panel())
	# Outside the scrolled list: it must never be the thing you have to scroll
	# to find.
	_column.add_child(close)

## 0 / 25 / 50 / 75 / 100 and back round, so every level is reachable.
func _step(v: float) -> float:
	var next := roundi(v * 4.0) + 1
	return float(next % 5) / 4.0

func _level(v: float) -> String:
	return "Kapalı" if v <= 0.001 else "%d%%" % roundi(v * 100.0)

func _on_off(v: bool) -> String:
	return "Açık" if v else "Kapalı"

func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	_rows.add_child(l)

func _row(label_fn: Callable, action: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 19)
	b.text = label_fn.call()
	b.pressed.connect(func():
		Audio.play("click")
		action.call()
		Settings.save_settings()
		b.text = label_fn.call())
	_rows.add_child(b)

func open() -> void:
	visible = true
	# Remember what the game was doing: opened from the pause menu it must
	# still be paused afterwards, not quietly running behind the menu.
	_was_paused = get_tree().paused
	get_tree().paused = true

func close_panel() -> void:
	remove_from_group(MODAL_GROUP)
	visible = false
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible:
		close_panel()
