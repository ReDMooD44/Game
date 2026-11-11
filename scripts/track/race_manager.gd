class_name RaceManager
extends Node
## Lap and sector timing, medals, respawns, standings and the ghost.
## Drives everything off the physics tick so a replayed ghost lines up exactly.

signal countdown(value: int)             # 3,2,1,0 (0 == GO)
signal sector_split(sector: int, delta: float, has_reference: bool)
signal lap_done(lap: int, lap_time: float, best: float, medal: String)
signal race_done(position: int, total: int)
signal checkpoint_hit(correct: bool)
signal respawned()
signal boundary_warning(active: bool)
signal resumed()

enum Mode { RACE, TIME_TRIAL }

const TICK := 1.0 / 60.0

var mode := Mode.TIME_TRIAL
var track: TrackData
var canyon: Canyon
var player: Node3D
var racers: Array[Node3D] = []           # player first, then bots

var running := false
var tick := 0
var lap := 1
var lap_time := 0.0
var last_lap := 0.0
var best_lap := 0.0
var current_sector := 1
var next_checkpoint := 0
var finished := false
var best_medal := ""

var sector_times := PackedFloat32Array()
var best_sector_times := PackedFloat32Array()

var ghost_recording := Ghost.new()
var ghost_best := Ghost.new()
var ghost_node: Node3D
var _ghost_tick := 0
var _lap_start_tick := 0
var _countdown_left := 3.0
var _counting := false
var _countdown_resets := true
var _last_shown := 4
var _outside_for := 0.0

## How far outside the canyon you may stray, and for how long, before you are
## put back. Generous enough to clip a rim, tight enough that you cannot just
## fly off across the desert.
## The side walls are solid, so the only way out of the canyon is over the rim:
## that is the one limit worth enforcing, and it is a hard ceiling the jet
## simply cannot climb through. A cylindrical side clamp was tried and fought
## the collider, because the canyon is a V - narrow at the floor, open at the
## rim - so sideways is left to the geometry, with a loose net behind it.
const CEILING_LIMIT := 1.15     # times the local wall height (rim tops out at 1.25)
const LATERAL_NET := 1.4        # times the half-width: should never be reached
const FLOOR_NET := -0.45
const GRACE := 2.5              # seconds leaning on the limit before a reset

func setup(data: TrackData, canyon_node: Canyon, player_node: Node3D, race_mode: int) -> void:
	track = data
	canyon = canyon_node
	player = player_node
	mode = race_mode
	best_sector_times.resize(track.sector_count)
	best_sector_times.fill(0.0)
	sector_times.resize(track.sector_count)
	if mode == Mode.TIME_TRIAL and ghost_best.load_from(track.track_name):
		pass

func start_countdown(reset := true) -> void:
	_counting = true
	_countdown_resets = reset
	_countdown_left = 3.999
	_last_shown = 4

func _physics_process(delta: float) -> void:
	if _counting:
		_tick_countdown(delta)
		return
	if not running or finished:
		return
	tick += 1
	lap_time += TICK
	_track_wrap()
	_record_ghost()
	_play_ghost()
	_check_out_of_bounds()

func _tick_countdown(delta: float) -> void:
	_countdown_left -= delta
	var shown := int(ceil(_countdown_left))
	if shown < _last_shown:
		_last_shown = shown
		countdown.emit(maxi(shown, 0))
	if _countdown_left <= 0.0:
		_counting = false
		running = true
		if _countdown_resets:
			tick = 0
			lap_time = 0.0
			_lap_start_tick = 0
			_wrap_laps = -1
			_prev_offset = -1.0
			ghost_recording.clear()
		else:
			resumed.emit()

## Counts laps from the offset wrapping round, not from a trigger. A racer
## sitting just before the line has a huge offset but has not completed
## anything, and nudging back across it must subtract a lap again - that
## mismatch is what made the position readout jump after a while.
func _track_wrap() -> void:
	if player == null:
		return
	var off := canyon.offset_of(player.global_position)
	if _prev_offset >= 0.0:
		var d := off - _prev_offset
		if d < -canyon.length * 0.5:
			_wrap_laps += 1
		elif d > canyon.length * 0.5:
			_wrap_laps -= 1
	_prev_offset = off
	# The gates are the authority on how many laps have been finished, and a
	# lap cannot be closed without crossing the line - so the wrap count can
	# never legitimately be behind them. If it is, a frame went missing
	# somewhere and the player is being scored a whole lap short of where they
	# are: leading the race and reading as second. Inference from position
	# deltas cannot undo its own mistakes, so the count is repaired here.
	#
	# Only ever upward. Running ahead of the gates IS legitimate - cross the
	# line having skipped a gate and the lap does not close, but the lap of
	# track really has been covered.
	#
	# And only once the line has been crossed at all: the grid sits inside the
	# final lap, so the count deliberately starts at -1 while lap is already 1.
	# Repairing from the first frame instead hands everyone a free lap.
	if _wrap_laps >= 0 and _wrap_laps < lap - 1:
		_wrap_laps = lap - 1

func _record_ghost() -> void:
	if player != null:
		ghost_recording.record(player.global_transform)

func _play_ghost() -> void:
	if ghost_node == null or ghost_best.frame_count() == 0:
		return
	_ghost_tick += 1
	if _ghost_tick >= ghost_best.frame_count():
		_ghost_tick = 0
	ghost_node.global_transform = ghost_best.sample(_ghost_tick)

## Enforces the ceiling every tick and keeps a loose net on the other axes.
func _check_out_of_bounds() -> void:
	if player == null:
		return
	var off := canyon.offset_of(player.global_position)
	var centre := canyon.point_at(off)
	var hw := canyon.half_width_at_offset(off)
	var h := canyon.wall_height_at_offset(off)
	var pos := player.global_position
	var ceiling := centre.y + h * CEILING_LIMIT

	var under_ceiling := true
	if pos.y > ceiling:
		pos.y = ceiling
		player.global_position = pos
		# Shed the climb so the jet skims the ceiling instead of grinding up
		# into it, which would otherwise feel like the controls locking up.
		var b := player.global_transform.basis
		var fwd := -b.z
		if fwd.y > 0.0:
			fwd.y = 0.0
			if fwd.length() > 0.01:
				fwd = fwd.normalized()
				var right := fwd.cross(Vector3.UP).normalized()
				if right.length() > 0.01:
					player.global_transform.basis = Basis(
						right, right.cross(fwd).normalized(), -fwd).orthonormalized()
		under_ceiling = false

	var d := pos - centre
	var lost := Vector2(d.x, d.z).length() > hw * LATERAL_NET or d.y < h * FLOOR_NET

	if under_ceiling and not lost:
		if _outside_for > 0.0:
			boundary_warning.emit(false)
		_outside_for = 0.0
		return

	if _outside_for <= 0.0:
		boundary_warning.emit(true)
	_outside_for += TICK
	if _outside_for >= GRACE:
		_outside_for = 0.0
		boundary_warning.emit(false)
		respawn_player()

## Metres of half width a respawn needs before it counts as somewhere you can
## fly out of. Part of the track is deliberately narrowed into corridors; the
## tightest of those is 24 m, and being put back into the middle of one at
## minimum speed just crashes you again.
const RESPAWN_ROOM := 60.0
## How far back along the track to look for that room.
const RESPAWN_LOOKBACK := 900.0

func respawn_player() -> void:
	_outside_for = 0.0
	var cp := _checkpoint_node(next_checkpoint - 1)
	if cp == null or not player.has_method("respawn_at"):
		respawned.emit()
		return
	player.respawn_at(_safe_respawn(cp))
	respawned.emit()

## The checkpoint itself if there is room there, otherwise the nearest point
## behind it that has some. Backwards rather than forwards, so a respawn never
## skips a piece of track the player has not flown.
func _safe_respawn(cp: Checkpoint) -> Transform3D:
	if canyon == null:
		return cp.respawn_transform
	var at := cp.spline_offset
	if canyon.half_width_at_offset(at) >= RESPAWN_ROOM:
		return cp.respawn_transform
	var best := at
	var best_room := canyon.half_width_at_offset(at)
	var step := 60.0
	var walked := 0.0
	while walked < RESPAWN_LOOKBACK:
		walked += step
		var probe := fposmod(at - walked, canyon.length)
		var room := canyon.half_width_at_offset(probe)
		if room > best_room:
			best_room = room
			best = probe
		if room >= RESPAWN_ROOM:
			break
	var t := canyon.transform_at(best)
	t.origin += t.basis.y * (canyon.wall_height_at_offset(best) * 0.52)
	return t

var _checkpoints: Array[Checkpoint] = []
var _last_passed := -1
## Gates cleared since the lap began. The start line only closes a lap once
## every gate has been visited, otherwise the very first crossing of gate 0
## would score a one-second lap.
var _gates_this_lap := 0
## Start-line crossings, counted exactly the way the bots count theirs. The
## lap NUMBER is a different thing - it only advances once every gate has been
## visited - and using it for position put a leader who had not yet reached
## the line a whole lap ahead of the field.
var _wrap_laps := -1
var _prev_offset := -1.0

func register_checkpoints(list: Array[Checkpoint]) -> void:
	_checkpoints = list
	for cp in _checkpoints:
		cp.passed.connect(_on_checkpoint)

func _checkpoint_node(idx: int) -> Checkpoint:
	if _checkpoints.is_empty():
		return null
	return _checkpoints[posmod(idx, _checkpoints.size())]

func _on_checkpoint(body: Node3D, index: int) -> void:
	if body != player or not running or finished:
		return
	if index != next_checkpoint:
		# Brushing back through the gate you just cleared is normal flying, not
		# a wrong turn, so it stays silent.
		if index != _last_passed:
			checkpoint_hit.emit(false)
		return
	_last_passed = index
	_gates_this_lap += 1
	checkpoint_hit.emit(true)
	next_checkpoint = (index + 1) % _checkpoints.size()
	var cp := _checkpoints[index]
	if cp.is_sector_gate:
		_close_sector(cp.sector)
	if index == 0 and _gates_this_lap > _checkpoints.size():
		_close_lap()

func _close_sector(sector_index: int) -> void:
	var s := clampi(sector_index, 0, track.sector_count - 1)
	sector_times[s] = lap_time
	var reference := best_sector_times[s]
	var delta := lap_time - reference
	sector_split.emit(s + 1, delta, reference > 0.0)
	current_sector = clampi(s + 2, 1, track.sector_count)

func _close_lap() -> void:
	last_lap = lap_time
	var improved := best_lap <= 0.0 or last_lap < best_lap
	if improved:
		best_lap = last_lap
		for i in track.sector_count:
			best_sector_times[i] = sector_times[i]
		if mode == Mode.TIME_TRIAL:
			ghost_best.frames = ghost_recording.frames.duplicate()
			ghost_best.save(track.track_name)
	var medal := track.medal_for(last_lap)
	if medal != "":
		best_medal = medal
	lap_done.emit(lap, last_lap, best_lap, medal)

	lap += 1
	lap_time = 0.0
	_gates_this_lap = 1   # the crossing that closed the lap opens the next one
	current_sector = 1
	ghost_recording.clear()
	_ghost_tick = 0
	if lap > track.laps:
		_finish()

func _finish() -> void:
	finished = true
	running = false
	race_done.emit(standing_of(player), racers.size())

## Progress is laps plus distance along the spline, which is also how the
## bots are ranked - they never leave the spline, so it is exact for them.
func progress_of(node: Node3D) -> float:
	if node == null:
		return 0.0
	if node.has_method("total_progress"):
		return node.total_progress()
	return _wrap_laps * canyon.length + canyon.offset_of(node.global_position)

func standing_of(node: Node3D) -> int:
	var mine := progress_of(node)
	var place := 1
	for r in racers:
		if r != node and progress_of(r) > mine:
			place += 1
	return place

func gap_to(other: Node3D) -> float:
	if other == null or player == null:
		return 0.0
	var d := progress_of(other) - progress_of(player)
	var speed := 320.0
	if player.has_method("get_speed"):
		speed = maxf(player.get_speed(), 60.0)
	return d / speed

func rival_ahead() -> Node3D:
	return _nearest(true)

func rival_behind() -> Node3D:
	return _nearest(false)

func _nearest(ahead: bool) -> Node3D:
	var mine := progress_of(player)
	var best: Node3D = null
	var best_d := INF
	for r in racers:
		if r == player:
			continue
		var d := progress_of(r) - mine
		if (ahead and d <= 0.0) or (not ahead and d >= 0.0):
			continue
		if absf(d) < best_d:
			best_d = absf(d)
			best = r
	return best
