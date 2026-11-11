extends Node
## Flies a real race with one bot slowed to a crawl, so the player laps it,
## and watches the position readout the whole way round.
##
## The player and the bots count laps in completely different ways - the bots
## from their own distance along the spline, the player from its offset
## wrapping past the start line - so lapping someone is exactly where the two
## can disagree.
## godot --headless --path . res://tools/lap_check.tscn

const LIMIT := 9000           ## physics ticks before giving up
const SLOW_BOT_SPEED := 110.0
const PLAYER_SPEED := 430.0

var game: Node3D
var ticks := 0
var worst := ""
var faults := 0
var lapped_at := -1
var _travelled := 0.0
var _finish_place := 0
var _finish_recheck := 0
var _finish_progress := 0.0
var _finish_truth := 0.0
var _respawns := 0

func _ready() -> void:
	# The results screen pauses the tree when the race ends; without this the
	# check stops being ticked and hangs instead of reporting.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.mode = 0
	Settings.difficulty = 1
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	# One backmarker, so the player is guaranteed to put a lap on someone.
	game.bots[0].base_speed = SLOW_BOT_SPEED
	game.bots[0].rubber_band = 1.0
	Settings.rubber_banding = false
	game.jet.frozen = true
	_travelled = game.canyon.offset_of(game.jet.global_position)
	game.race.race_done.connect(_on_done)

## The place the game actually reported, next to the one the same numbers give
## a moment later. The lap count and the finish line are updated by different
## things in the same frame, so the instant of crossing is exactly where they
## can disagree.
func _on_done(place: int, total: int) -> void:
	var race = game.race
	_finish_place = place
	_finish_truth = _travelled - game.canyon.length
	_finish_progress = race.progress_of(game.jet)
	var ahead := 0
	for b in game.bots:
		if race.progress_of(b) > _finish_progress:
			ahead += 1
	_finish_recheck = ahead + 1
	print("BITIS: bildirilen %d/%d, ayni anda hesaplanan %d, ilerleme %.0f, gercek %.0f, sapma %.0f"
		% [place, total, _finish_recheck, _finish_progress, _finish_truth,
			_finish_progress - _finish_truth])

## Carries the player round the spline in small steps rather than flying it.
## The lap counter infers a lap from the offset wrapping, so the step has to
## stay well under half a lap or the inference breaks - and a teleport would
## be testing the teleport, not the standings.
func _physics_process(_d: float) -> void:
	ticks += 1
	if ticks > LIMIT or game.race.finished:
		_report()
		return
	if not game.race.running:
		return
	var canyon: Canyon = game.canyon
	# A crash every few seconds, which is the one thing a real player does
	# that carrying them along the spline does not: respawn teleports them
	# backwards, and the lap counter infers laps from position deltas.
	if ticks % 700 == 0:
		game.race.respawn_player()
		_travelled = _travelled - fposmod(_travelled, canyon.length) 			+ canyon.offset_of(game.jet.global_position)
		_respawns += 1
	_travelled += PLAYER_SPEED / 60.0
	var t: Transform3D = canyon.transform_at(fposmod(_travelled, canyon.length))
	t.origin += t.basis.y * (canyon.wall_height_at_offset(_travelled) * 0.45)
	game.jet.global_transform = t
	if ticks % 30 != 0:
		return

	var race = game.race
	var mine: float = race.progress_of(game.jet)
	var place: int = race.standing_of(game.jet)
	# Worked out here from the same numbers, independently of standing_of, so
	# a disagreement means the readout is wrong rather than the maths.
	var ahead := 0
	for b in game.bots:
		if race.progress_of(b) > mine:
			ahead += 1
	var expected := ahead + 1

	# Ground truth for the player, taken from the distance actually carried
	# rather than from the thing under test. _wrap_laps starts at -1 and the
	# grid sits inside the final lap, so progress should track this exactly.
	var truth: float = _travelled - canyon.length
	var drift: float = mine - truth
	if absf(drift) > 60.0:
		faults += 1
		if worst == "":
			worst = "t=%.0fs ilerleme %.0f, olmasi gereken %.0f (fark %.0f = %.2f tur)" % [
				ticks / 60.0, mine, truth, drift, drift / canyon.length]
	var slow: float = race.progress_of(game.bots[0])
	if lapped_at < 0 and mine - slow >= canyon.length:
		lapped_at = ticks
		print("tur bindirildi: t=%.0fs" % (ticks / 60.0))
	if place != expected:
		faults += 1
		if worst == "":
			worst = "t=%.0fs okunan %d, olmasi gereken %d (ilerleme %.0f)" % [
				ticks / 60.0, place, expected, mine]
	if ticks % 600 == 0:
		print("t=%3.0fs tur %d wrap=%2d ilerleme=%9.0f sira=%d/%d yavas bot=%9.0f fark=%8.0f"
			% [ticks / 60.0, race.lap, race._wrap_laps, mine, place,
				race.racers.size(), slow, mine - slow])
		print("        gercek=%9.0f  sapma=%7.0f" % [truth, drift])

func _report() -> void:
	print("--- sonuc ---")
	print("tur bindirme: ", "oldu" if lapped_at >= 0 else "OLMADI (test gecersiz)")
	print("respawn sayisi: %d" % _respawns)
	print("tutarsiz okuma: %d ornek  %s" % [faults, worst])
	if _finish_place > 0:
		var drift: float = _finish_progress - _finish_truth
		print("bitis anindaki tur sayimi: %s (sapma %.0f m)"
			% ["dogru" if absf(drift) < 60.0 else "BIR TUR EKSIK", drift])
	get_tree().quit()
