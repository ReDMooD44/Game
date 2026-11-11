extends Node
## Walks the unlock rules through a plausible run of races and prints what
## each one opened, so the ladder can be read rather than guessed at.

func _ready() -> void:
	Settings.achievements = {}
	Settings.won_maps = []
	Settings.trail_skin = 0

	print("locked at the start: ", _locked_names())
	_race("Red Mesa", 5, "")
	_race("Red Mesa", 3, "BRONZE")
	_race("Red Mesa", 1, "SILVER")
	_race("Dust Basin", 1, "GOLD")
	_race("Red Mesa", 1, "AUTHOR")
	print("still locked: ", _locked_names())

	# A skin that has not been earned must not be selectable.
	Settings.achievements = {}
	Settings.trail_skin = 0
	var panel = load("res://scripts/ui/settings_panel.gd").new()
	var reachable := []
	var at := 0
	for _i in TrailSkins.count() + 2:
		at = panel._next_skin(at)
		if not reachable.has(at):
			reachable.append(at)
	panel.free()
	print("with nothing earned, the picker can reach: ", reachable)
	print("every one of those unlocked: ", _all_unlocked(reachable))
	get_tree().quit()

func _race(track_name: String, place: int, medal: String) -> void:
	var fresh := Settings.note_race(track_name, place, medal)
	var names := []
	for skin in fresh:
		names.append(TrailSkins.skin_name(skin))
	print("%-11s %d. sıra, madalya %-7s -> açılan: %s"
		% [track_name, place, medal if medal != "" else "yok",
			", ".join(names) if names.size() > 0 else "-"])

func _locked_names() -> Array:
	var out := []
	for i in TrailSkins.count():
		if not Settings.is_skin_unlocked(i):
			out.append(TrailSkins.skin_name(i))
	return out

func _all_unlocked(list: Array) -> bool:
	for i in list:
		if not Settings.is_skin_unlocked(int(i)):
			return false
	return true
