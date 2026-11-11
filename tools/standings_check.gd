extends Node
## Leading the field must read as 1/6, and trailing it as 6/6. The player and
## the bots count laps in different ways, so this is easy to get wrong.
## godot --headless --path . res://tools/standings_check.tscn

enum Phase { WAIT, AHEAD, MEASURE_AHEAD, BEHIND, MEASURE_BEHIND, DONE }

var game: Node3D
var phase := Phase.WAIT
var phase_frame := 0
var lead := -1
var trail := -1

func _ready() -> void:
	Settings.mode = 0
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)

func _place(offset: float) -> void:
	var c: Canyon = game.canyon
	var t: Transform3D = c.transform_at(fposmod(offset, c.length))
	t.origin += t.basis.y * (c.wall_height_at_offset(offset) * 0.45)
	game.jet.global_transform = t

func _all_bots_started() -> bool:
	for b in game.bots:
		if b.laps_done < 0:
			return false
	return true

func _bot_span() -> Vector2:
	var lo := INF
	var hi := -INF
	for b in game.bots:
		lo = minf(lo, b.offset)
		hi = maxf(hi, b.offset)
	return Vector2(lo, hi)

func _physics_process(_d: float) -> void:
	phase_frame += 1
	match phase:
		Phase.WAIT:
			# Wait until the whole field has crossed the start line, so this
			# tests who is leading rather than how the wrap point is handled.
			if game.race.running and _all_bots_started() and _bot_span().x > 1500.0:
				_next(Phase.AHEAD)
		Phase.AHEAD:
			var span := _bot_span()
			_place(span.y + 900.0)
			_next(Phase.MEASURE_AHEAD)
		Phase.MEASURE_AHEAD:
			if phase_frame >= 3:
				lead = game.race.standing_of(game.jet)
				_next(Phase.BEHIND)
		Phase.BEHIND:
			var span2 := _bot_span()
			_place(span2.x - 900.0)
			_next(Phase.MEASURE_BEHIND)
		Phase.MEASURE_BEHIND:
			if phase_frame >= 3:
				trail = game.race.standing_of(game.jet)
				_next(Phase.DONE)
		Phase.DONE:
			var total: int = game.race.racers.size()
			print("ahead of the field -> %d/%d (%s)" % [lead, total,
				"ok" if lead == 1 else "WRONG"])
			print("behind the field  -> %d/%d (%s)" % [trail, total,
				"ok" if trail == total else "WRONG"])
			get_tree().quit()

func _next(p: int) -> void:
	phase = p
	phase_frame = 0
