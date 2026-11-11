extends SceneTree
## Integration test for the race system: flies a dummy body down the middle of
## the spline at a constant speed and reports every gate, sector and lap.
## godot --headless --path . --script tools/race_check.gd

const SPEED := 320.0

var canyon: Canyon
var body: CharacterBody3D
var race: RaceManager
var offset := 0.0
var ticks := 0
var events: Array[String] = []

func _initialize() -> void:
	var track: TrackData = load(TrackGen.track_path(0))
	track.laps = 2
	canyon = Canyon.new()
	canyon.track = track
	root.add_child(canyon)
	canyon.build(1)

	body = CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 2.2
	cap.height = 11.0
	cs.shape = cap
	cs.rotation_degrees = Vector3(90, 0, 0)
	body.add_child(cs)
	root.add_child(body)

	race = RaceManager.new()
	root.add_child(race)
	var list: Array[Checkpoint] = []
	var per_sector: int = track.checkpoint_count / track.sector_count
	for i in track.checkpoint_count:
		var off := canyon.length * float(i) / track.checkpoint_count
		var cp := Checkpoint.new()
		canyon.add_child(cp)
		cp.setup(i, canyon.transform_at(off), canyon.half_width_at_offset(off),
			canyon.wall_height_at_offset(off), off, (i + 1) % per_sector == 0,
			(i + 1) / per_sector - 1)
		list.append(cp)
	race.register_checkpoints(list)
	race.setup(track, canyon, body, RaceManager.Mode.TIME_TRIAL)
	race.racers.append(body)
	race.checkpoint_hit.connect(func(ok: bool): events.append("gate ok=%s t=%.2f" % [ok, race.lap_time]))
	race.sector_split.connect(func(s: int, d: float, has: bool): events.append("  SECTOR %d t=%.3f" % [s, race.lap_time]))
	race.lap_done.connect(func(l: int, t: float, b: float, m: String):
		events.append("LAP %d time=%.3f medal=%s%s" % [l, t, m,
			"   <-- BOGUS, lap far too short" if t < 20.0 else ""]))
	race.race_done.connect(func(p: int, n: int): events.append("FINISH place=%d/%d" % [p, n]))
	race.respawned.connect(func(): events.append("  !! respawn t=%.2f" % race.lap_time))

	offset = canyon.length - 500.0
	_place()
	race.start_countdown()

func _place() -> void:
	var t := canyon.transform_at(offset)
	t.origin += t.basis.y * (canyon.wall_height_at_offset(offset) * 0.52)
	body.global_transform = t

func _physics_process(delta: float) -> bool:
	ticks += 1
	if race.running:
		offset = fposmod(offset + SPEED * delta, canyon.length)
		_place()
	if ticks > 60 * 400 or race.finished:
		for e in events:
			print(e)
		print("ticks=%d finished=%s" % [ticks, race.finished])
		return true
	return false
