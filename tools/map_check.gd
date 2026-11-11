extends Node
## Screenshots the map picker so its layout can be eyeballed.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var t: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	add_child(t)
	await get_tree().process_frame
	var picker: Node = (load("res://scripts/ui/map_select.gd") as GDScript).new()
	add_child(picker)
	picker.open()
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var dir := OS.get_environment("JET_SHOTS")
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir + "/map_select.png")
	get_tree().paused = false
	get_tree().quit()
