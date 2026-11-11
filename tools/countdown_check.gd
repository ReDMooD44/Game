extends Node
## Nobody moves until GO: samples the player and the bots through the
## countdown and again after it. godot --headless --path . res://tools/countdown_check.tscn

var game: Node3D
var frame := 0
var at_start := []
var jet_start := Vector3.ZERO

func _ready() -> void:
	Settings.mode = 0
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)

func _physics_process(_d: float) -> void:
	frame += 1
	if frame == 10:
		jet_start = game.jet.global_position
		for b in game.bots:
			at_start.append(b.offset)
	elif frame == 150:            # still inside the 3 s countdown
		var moved := 0.0
		for i in game.bots.size():
			moved = maxf(moved, absf(game.bots[i].offset - at_start[i]))
		print("during countdown: bots moved %.2f m, jet moved %.2f m (%s)" % [
			moved, game.jet.global_position.distance_to(jet_start),
			"HELD" if moved < 0.01 else "MOVING - BUG"])
	elif frame == 300:            # ~2 s after GO
		var moved := 0.0
		for i in game.bots.size():
			moved = maxf(moved, absf(game.bots[i].offset - at_start[i]))
		print("after GO: bots moved %.0f m, jet moved %.0f m (%s)" % [
			moved, game.jet.global_position.distance_to(jet_start),
			"racing" if moved > 100.0 else "STILL FROZEN - BUG"])
		get_tree().quit()
