extends Node
## Development smoke test for the menus: builds each screen in turn and dumps
## a frame of it, so layout mistakes show up without playing a whole race.
## Attach by running: godot --path . tools/ui_check.tscn -- --shots <dir>

var out_dir := "user://shots"
var _step := 0
var _frame := 0
var _current: Node

const STEPS := ["title", "settings", "pause", "results"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		out_dir = args[i + 1]
	elif OS.get_environment("JET_SHOTS") != "":
		out_dir = OS.get_environment("JET_SHOTS")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build(STEPS[0])

func _build(step: String) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	match step:
		"title":
			_current = load("res://scenes/title.tscn").instantiate()
			add_child(_current)
		"settings":
			_current = load("res://scripts/ui/settings_panel.gd").new()
			add_child(_current)
			_current.open()
		"pause":
			_current = load("res://scripts/ui/menu.gd").new()
			add_child(_current)
			_current.open()
		"results":
			_current = load("res://scripts/ui/results.gd").new()
			add_child(_current)
			_current.show_results("2. SIRA", [
				"6 yarışçı içinde 2.",
				"En iyi tur:  00:57.412",
				"Son tur:     00:59.001",
				"Hedef (Author):  00:55.662",
			], "GOLD")

func _process(_delta: float) -> void:
	_frame += 1
	if _frame < 12:
		return
	_frame = 0
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/ui_%02d_%s.png" % [out_dir, _step + 1, STEPS[_step]])
	print("[ui_check] %s" % STEPS[_step])
	_step += 1
	if _step >= STEPS.size():
		get_tree().paused = false
		get_tree().quit()
		return
	get_tree().paused = false
	_build(STEPS[_step])
