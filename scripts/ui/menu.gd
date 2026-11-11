extends Control
## In-game pause. The small II button lives here too, so the whole
## pause surface is one node that the game can hide during the countdown.

signal restart_requested()
signal quit_to_title()
signal resume_requested()

var _open_button: Button
var _panel: Control
var _rows: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	_open_button = Button.new()
	_open_button.text = "II"
	_open_button.custom_minimum_size = Vector2(76, 58)
	_open_button.position = Vector2(18, 18)
	_open_button.add_theme_font_size_override("font_size", 22)
	_open_button.pressed.connect(open)
	add_child(_open_button)

	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.03, 0.05, 0.90)
	_panel.add_child(shade)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(centre)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	_rows.custom_minimum_size = Vector2(420, 0)
	centre.add_child(_rows)

	_title("DURAKLATILDI")
	_button("DEVAM", close)
	_button("YENİDEN BAŞLA", func(): restart_requested.emit())
	_button("AYARLAR", _open_settings)
	_button("ANA MENÜ", func(): quit_to_title.emit())

func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
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

func _open_settings() -> void:
	var panel := preload("res://scripts/ui/settings_panel.gd").new()
	add_child(panel)
	panel.open()

func open() -> void:
	Audio.play("click")
	_panel.visible = true
	_open_button.visible = false
	get_tree().paused = true

## The game owns un-pausing, because coming back from a pause runs its own
## 3-2-1 rather than dropping you straight back into the canyon.
func close() -> void:
	_panel.visible = false
	_open_button.visible = true
	resume_requested.emit()

func set_button_visible(v: bool) -> void:
	_open_button.visible = v and not _panel.visible

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if preload("res://scripts/ui/settings_panel.gd").modal_open(get_tree()):
		return
	if _panel.visible:
		close()
	else:
		open()
