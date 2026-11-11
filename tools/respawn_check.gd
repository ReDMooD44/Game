extends SceneTree
## Is every respawn point somewhere you can actually fly out of?
##
## A respawn that drops the jet next to a wall, or pointing at one, costs the
## player the race twice over: they crash again immediately and the game looks
## broken. The autopilot got stuck doing exactly that during testing, so the
## points are measured rather than trusted.

const CLEAR_AHEAD := 260.0      ## metres of track the nose must have free

func _init() -> void:
	for index in TrackGen.track_count():
		_scan(index)
	quit()

func _scan(index: int) -> void:
	var track: TrackData = load(TrackGen.track_path(index))
	var canyon := Canyon.new()
	canyon.track = track
	canyon.material = StrataTexture.material()
	get_root().add_child(canyon)
	canyon.build(1)

	var tight := 0
	var worst := INF
	var worst_at := 0.0
	var facing := 0
	for i in track.checkpoint_count:
		var off := canyon.length * float(i) / track.checkpoint_count
		var t := canyon.transform_at(off)
		var hw := canyon.half_width_at_offset(off)
		var h := canyon.wall_height_at_offset(off)
		# Where the race manager puts the jet back: centre line, mid height.
		var pos: Vector3 = t.origin + t.basis.y * (h * 0.5)
		# Sideways room, as a share of the half width the hull allows there.
		# What the race manager would actually use, not the raw checkpoint.
		var room: float = hw
		if room < RaceManager.RESPAWN_ROOM:
			var walked := 0.0
			while walked < RaceManager.RESPAWN_LOOKBACK:
				walked += 60.0
				var probe := fposmod(off - walked, canyon.length)
				room = maxf(room, canyon.half_width_at_offset(probe))
				if room >= RaceManager.RESPAWN_ROOM:
					break
		if room < worst:
			worst = room
			worst_at = off
		if room < RaceManager.RESPAWN_ROOM:
			tight += 1
		# And room to fly forward: the nose must not be aimed into a wall.
		var ahead: Vector3 = canyon.point_at(off + CLEAR_AHEAD)
		var local: Vector3 = t.affine_inverse() * ahead
		if absf(local.x) > room * 0.80:
			facing += 1
	print("%-12s %d nokta: dar olan %d, duvara bakan %d, en dar %.0f m (offset %.0f)"
		% [track.track_name, track.checkpoint_count, tight, facing, worst, worst_at])
	canyon.queue_free()
