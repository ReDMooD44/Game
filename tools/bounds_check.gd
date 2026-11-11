extends Node
## The canyon boundary is a hard clamp: a single excursion is pulled straight
## back, and leaning on it for a couple of seconds puts you on the track.
## godot --headless --path . res://tools/bounds_check.tscn

enum Phase { WAIT, SHOVE_ONCE, MEASURE, HOLD, REPORT }

var game: Node3D
var frame := 0
var phase := Phase.WAIT
var phase_frame := 0
var warned := false
var respawned := false
var after_single := -1.0

func _ready() -> void:
	Settings.mode = 1
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().physics_frame
	game.race.boundary_warning.connect(func(a: bool): if a: warned = true)
	game.race.respawned.connect(func(): respawned = true)

## Height above the canyon floor line, as a multiple of the wall height.
func _outside_by() -> float:
	var off: float = game.canyon.offset_of(game.jet.global_position)
	var c: Vector3 = game.canyon.point_at(off)
	var h: float = game.canyon.wall_height_at_offset(off)
	return (game.jet.global_position.y - c.y) / h

func _shove() -> void:
	var off: float = game.canyon.offset_of(game.jet.global_position)
	var t: Transform3D = game.canyon.transform_at(off)
	game.jet.global_position = t.origin + Vector3.UP * 900.0

func _physics_process(_d: float) -> void:
	frame += 1
	phase_frame += 1
	match phase:
		Phase.WAIT:
			# Let the countdown finish and the race actually start.
			if game.race.running and phase_frame > 60:
				_next(Phase.SHOVE_ONCE)
		Phase.SHOVE_ONCE:
			_shove()
			_next(Phase.MEASURE)
		Phase.MEASURE:
			if phase_frame >= 4:
				after_single = _outside_by()
				warned = false
				_next(Phase.HOLD)
		Phase.HOLD:
			_shove()
			if phase_frame > 200:        # ~3.3 s pinned outside
				_next(Phase.REPORT)
		Phase.REPORT:
			print("shoved 900 m up -> now %.2f x wall height (%s), warned=%s" % [
				after_single,
				"at the ceiling" if after_single <= RaceManager.CEILING_LIMIT + 0.01 else "STILL OUT",
				warned])
			print("held at the limit -> respawned=%s (%s)" % [
				respawned, "ok" if respawned else "FAILED"])
			get_tree().quit()

func _next(p: int) -> void:
	phase = p
	phase_frame = 0
