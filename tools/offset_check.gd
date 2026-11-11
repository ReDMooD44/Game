extends SceneTree
## Can the track confuse itself about where you are?
##
## Everything about the player's position - lap count, standing, gap, minimap
## marker - starts from Curve3D.get_closest_offset, which returns the nearest
## point on the WHOLE spline. On a closed loop that bends back toward itself,
## a jet flying wide or high can be nearer to a different part of the track
## than to the part it is actually on, and the answer jumps by kilometres.
##
## This walks the lap, puts a probe everywhere inside the canyon that the jet
## can legally be, and reports anywhere the recovered offset is not the one it
## started from.

const STEPS := 900              ## samples along the lap
const TOLERANCE := 250.0        ## metres of slack before it counts as a jump

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

	var jumps := 0
	var worst := 0.0
	var worst_at := 0.0
	var samples := 0
	for i in STEPS:
		var off := canyon.length * float(i) / STEPS
		var t := canyon.transform_at(off)
		var hw := canyon.half_width_at_offset(off)
		var h := canyon.wall_height_at_offset(off)
		for lat in [-0.62, 0.0, 0.62]:
			for height in [0.02, 0.5, 1.1]:
				var p: Vector3 = t.origin + t.basis.x * (lat * hw) \
					+ t.basis.y * (height * h)
				var back := canyon.offset_of(p)
				# Wrap the difference, so the start line is not a false alarm.
				var d: float = fposmod(back - off + canyon.length * 0.5,
					canyon.length) - canyon.length * 0.5
				samples += 1
				if absf(d) > TOLERANCE:
					jumps += 1
					if absf(d) > absf(worst):
						worst = d
						worst_at = off
	print("%-12s %d/%d örnek sıçradı, en kötü %.0f m (offset %.0f, tur %.0f m)"
		% [track.track_name, jumps, samples, worst, worst_at, canyon.length])
	canyon.queue_free()
