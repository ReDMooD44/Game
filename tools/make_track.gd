extends SceneTree
## Headless generator for every circuit in TrackGen.PRESETS.
## godot --headless --script tools/make_track.gd

func _initialize() -> void:
	TrackGen.write_all()
	quit()
