extends Node3D
## Assembles the race: world, canyon, jets, camera, HUD and the race manager.
## Everything is built in code so there are no imported assets to go stale.

const BOT_COUNT := 5
const LIVERIES := [
	Color(0.90, 0.22, 0.20), Color(0.95, 0.62, 0.12), Color(0.25, 0.70, 0.95),
	Color(0.55, 0.85, 0.30), Color(0.78, 0.35, 0.90),
]
const BOT_NAMES := ["VIPER", "ASHEN", "KESTREL", "DUSTOFF", "NOMAD"]
const RUBBER_BAND_WINDOW := 900.0   ## metres of gap before bots are nudged

var mode := RaceManager.Mode.RACE

var track: TrackData
var canyon: Canyon
var jet: JetController
var camera: ChaseCamera
var race := RaceManager.new()
var hud: Hud
var touch: Control
var vignette: ColorRect
var menu: Control
var results: Control
var minimap: Control
var leaderboard: Control
var jet_audio: JetAudio

var bots: Array[BotPilot] = []
var _burners: Array = []
var _shadow: Decal
var _wing_trails: Array[Contrail] = []
var _sparks: GPUParticles3D
var _explosion: GPUParticles3D
var _ghost_node: Node3D
var _floor_probe := PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	mode = Settings.mode
	_build_world()
	_build_track()
	_build_player()
	_build_bots()
	_build_ui()
	_wire_race()
	_set_racing(false)
	race.start_countdown()
	_report_budget()
	_maybe_start_capture()

## The capture tool is stripped from shipped builds. It must never be a hard
## reference: a global class that is missing at runtime stops main.gd from
## loading at all, and on a phone that looks like a blank blue screen.
func _maybe_start_capture() -> void:
	if not ResourceLoader.exists("res://tools/capture.gd"):
		return
	var script: GDScript = load("res://tools/capture.gd")
	if script == null or not script.call("wanted"):
		return
	var node: Node = script.new()
	add_child(node)

func _build_world() -> void:
	var we := WorldEnvironment.new()
	we.environment = Vfx.environment()
	add_child(we)
	add_child(Vfx.sun())
	_floor_probe.collision_mask = 1

func _build_track() -> void:
	var path := TrackGen.track_path(Settings.track)
	track = load(path) if ResourceLoader.exists(path) else null
	if track == null or not track.is_valid():
		track = TrackGen.generate(Settings.track)
	canyon = Canyon.new()
	canyon.track = track
	canyon.material = StrataTexture.material()
	add_child(canyon)
	canyon.build(Settings.difficulty)
	var props := CanyonProps.populate(canyon, canyon)
	var dressing := CanyonDressing.populate(canyon, canyon)
	print("[budget] terrain formations=%d, scattered props=%d" % [props, dressing])
	_build_checkpoints()

func _build_checkpoints() -> void:
	var list: Array[Checkpoint] = []
	var per_sector: int = track.checkpoint_count / track.sector_count
	for i in track.checkpoint_count:
		var off := canyon.length * float(i) / track.checkpoint_count
		var cp := Checkpoint.new()
		canyon.add_child(cp)
		var is_gate := (i + 1) % per_sector == 0
		cp.setup(i, canyon.transform_at(off), canyon.half_width_at_offset(off),
			canyon.wall_height_at_offset(off), off, is_gate, (i + 1) / per_sector - 1)
		list.append(cp)
	race.register_checkpoints(list)

func _build_player() -> void:
	jet = JetController.new()
	jet.collision_layer = 2
	jet.collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 2.2
	cap.height = 11.0
	shape.shape = cap
	shape.rotation_degrees = Vector3(90, 0, 0)
	jet.add_child(shape)
	add_child(jet)

	jet.canyon = canyon
	var built := JetBuild.build(jet, Color(0.95, 0.95, 1.0), true)
	_burners = built["burners"]
	_shadow = built["shadow"]
	_shadow.top_level = true

	jet_audio = JetAudio.new()
	jet.add_child(jet_audio)
	jet_audio.model = jet.model

	# Wingtip vortices: thin white threads off each tip, the thing that makes
	# a hard turn read as a hard turn.
	for _i in 2:
		var w := Contrail.new()
		w.taper = 0.5
		w.points = 34
		add_child(w)
		TrailSkins.apply(w, Settings.trail_skin)
		_wing_trails.append(w)
	_sparks = Vfx.sparks()
	add_child(_sparks)
	_explosion = Vfx.explosion()
	add_child(_explosion)

	camera = ChaseCamera.new()
	camera.current = true
	add_child(camera)

	var start := _grid_transform(0)
	jet.arm(start)
	jet.frozen = true
	camera.set_target(jet)
	jet.scraped.connect(_on_scrape)
	jet.stuck.connect(_on_crash)

## Start grid: the player on the centre line, bots fanned out behind.
func _grid_transform(slot: int) -> Transform3D:
	var off := canyon.length - 220.0 - slot * 55.0
	var t := canyon.transform_at(off)
	var hw := canyon.half_width_at_offset(off)
	var h := canyon.wall_height_at_offset(off)
	var lane := 0.0 if slot == 0 else (-1.0 + 2.0 * ((slot - 1) / float(maxi(BOT_COUNT - 1, 1))))
	t.origin += t.basis.x * (lane * hw * 0.55) + t.basis.y * (h * 0.52)
	return t

func _build_bots() -> void:
	if mode != RaceManager.Mode.RACE:
		_build_ghost_jet()
		return
	for i in BOT_COUNT:
		var b := BotPilot.new()
		b.pilot_name = BOT_NAMES[i]
		b.livery = LIVERIES[i]
		b.lane = -1.0 + 2.0 * (i / float(maxi(BOT_COUNT - 1, 1)))
		b.line_error = 3.0 + i * 0.9
		b.corner_aggression = 0.9 + i * 0.1
		b.speed_scale = 0.99 + i * 0.010
		b.base_speed = 312.0 * track.bot_speed_scale[clampi(Settings.difficulty, 0, 2)]
		add_child(b)
		var built_bot := JetBuild.build(b, b.livery, false)
		# 17.7k triangles a ship: a bot far down the canyon is not worth them.
		var bot_hull: MeshInstance3D = built_bot["hull"]
		bot_hull.visibility_range_end = 900.0
		bot_hull.visibility_range_end_margin = 150.0
		bot_hull.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		b.setup(canyon, canyon.length - 220.0 - 55.0 * (i + 1), float(i) * 1.37)
		# The grid sits just BEFORE the start line, so the first wrap past it
		# is lap one starting, not lap one finishing. Without this the whole
		# field counts a lap the player has not had yet and the HUD shows the
		# leader sitting in last place.
		b.laps_done = -1
		bots.append(b)

func _build_ghost_jet() -> void:
	_ghost_node = Node3D.new()
	add_child(_ghost_node)
	var built := JetBuild.build(_ghost_node, Color(0.5, 0.8, 1.0), false)
	var body: Node3D = built["body"]
	for child in body.get_children():
		if child is MeshInstance3D:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.45, 0.75, 1.0, 0.35)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			child.material_override = m
	_ghost_node.visible = false

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	vignette = preload("res://scripts/ui/vignette.gd").new()
	layer.add_child(vignette)
	hud = preload("res://scripts/ui/hud.gd").new()
	layer.add_child(hud)
	minimap = preload("res://scripts/ui/minimap.gd").new()
	layer.add_child(minimap)
	var gate_offsets := []
	for cp in canyon.get_children():
		if cp is Checkpoint and cp.is_sector_gate:
			gate_offsets.append(cp.spline_offset)
	minimap.setup(canyon, jet, bots, gate_offsets)
	if mode == RaceManager.Mode.RACE:
		leaderboard = preload("res://scripts/ui/leaderboard.gd").new()
		layer.add_child(leaderboard)
	touch = preload("res://scripts/ui/touch_controls.gd").new()
	layer.add_child(touch)
	menu = preload("res://scripts/ui/menu.gd").new()
	layer.add_child(menu)
	menu.restart_requested.connect(_restart)
	menu.quit_to_title.connect(_to_title)
	menu.resume_requested.connect(_resume_with_countdown)
	results = preload("res://scripts/ui/results.gd").new()
	layer.add_child(results)
	results.restart_requested.connect(_restart)
	results.quit_to_title.connect(_to_title)
	jet.input_source = touch
	hud.total_laps = track.laps
	hud.total_sectors = track.sector_count
	hud.g_limit = jet.g_limit
	Settings.play_reminder.connect(_on_play_reminder)
	if not Settings.seen_tutorial:
		hud.show_message("Sol: joystick   Sağ: BOOST / BRAKE", 5.0)
		Settings.seen_tutorial = true
		Settings.save_settings()

## Said once, plainly, and never in the way of the race.
func _on_play_reminder(minutes: int) -> void:
	hud.show_message("%d dakikadır oynuyorsun" % minutes, 3.5)

func _wire_race() -> void:
	add_child(race)
	race.setup(track, canyon, jet, mode)
	race.racers.append(jet)
	for b in bots:
		race.racers.append(b)
	race.ghost_node = _ghost_node
	if _ghost_node != null:
		_ghost_node.visible = race.ghost_best.frame_count() > 0
	if leaderboard != null:
		leaderboard.setup(race, jet)
	race.countdown.connect(_on_countdown)
	race.sector_split.connect(_on_sector)
	race.lap_done.connect(_on_lap)
	race.race_done.connect(_on_finish)
	race.respawned.connect(func(): hud.show_message("RESPAWN", 1.2))
	race.resumed.connect(func(): _set_racing(true))
	race.boundary_warning.connect(_on_boundary)
	race.checkpoint_hit.connect(func(ok: bool): if not ok: hud.show_message("WRONG GATE", 1.0))

# --- per-frame ----------------------------------------------------------

func _physics_process(delta: float) -> void:
	if jet == null:
		return
	_update_rubber_band()
	_update_vfx(delta)

func _process(_delta: float) -> void:
	_update_hud()
	if Input.is_action_just_pressed("restart"):
		_restart()

func _update_rubber_band() -> void:
	if not Settings.rubber_banding or bots.is_empty():
		return
	var mine := race.progress_of(jet)
	for b in bots:
		var gap := race.progress_of(b) - mine
		# A 5% nudge, nothing more: a bigger band is obvious and insulting.
		b.rubber_band = 0.95 if gap > RUBBER_BAND_WINDOW else (1.05 if gap < -RUBBER_BAND_WINDOW else 1.0)

func _update_vfx(delta: float) -> void:
	var ratio := jet.model.speed_ratio()
	camera.boosting = jet.model.boosting
	for b in _burners:
		var s := 0.55 + ratio * 0.8 + (0.6 if jet.model.boosting else 0.0)
		b.scale = Vector3(s, s, s * (1.6 if jet.model.boosting else 1.0))
		b.emitting = not jet.frozen
	var b := jet.global_transform.basis
	# Tips stream when the wing is loaded: hard turns and high speed.
	var load_factor := clampf((jet.model.g_force - 1.1) / 2.6, 0.0, 1.0)
	# Always on at speed, stronger when the wing is loaded.
	var tip_strength := clampf(0.35 + load_factor * 0.5 + ratio * 0.5, 0.0, 1.0)
	var span := ShipMesh.size()
	for i in _wing_trails.size():
		var side: float = span.x * 0.47 * (1.0 if i == 0 else -1.0)
		_wing_trails[i].push(
			Transform3D(b, jet.global_position + b.x * side + b.y * 0.1 + b.z * 1.0),
			tip_strength)
	# Speed lines thicken with speed and surge with the afterburner: this is
	# where the sense of acceleration comes from, since there is no motion blur.
	_update_shadow()

func _update_shadow() -> void:
	if _shadow == null:
		return
	var space := get_world_3d().direct_space_state
	_floor_probe.from = jet.global_position
	_floor_probe.to = jet.global_position + Vector3.DOWN * 400.0
	_floor_probe.exclude = [jet.get_rid()]
	var hit := space.intersect_ray(_floor_probe)
	if hit.is_empty():
		_shadow.visible = false
		return
	var fwd := -jet.global_transform.basis.z
	if not is_finite(fwd.x) or not is_finite(fwd.z):
		_shadow.visible = false
		return
	_shadow.visible = true
	_shadow.global_position = hit.position + Vector3.UP * 14.0
	_shadow.rotation = Vector3(0, atan2(fwd.x, fwd.z), 0)

func _update_hud() -> void:
	var m := jet.model
	hud.knots = m.display_knots()
	hud.mach = m.display_mach()
	hud.g_force = m.g_force
	hud.braking = m.airbrake
	hud.boost_ratio = m.boost_ratio()
	hud.lap = mini(race.lap, track.laps)
	hud.sector = race.current_sector
	hud.lap_time = race.lap_time
	hud.last_lap = race.last_lap
	hud.best_lap = race.best_lap
	hud.medal = race.best_medal
	hud.flight_path = _flight_path_marker()
	touch.set_boost_state(m.boost_ratio(), m.boost_available())
	vignette.set_intensity(camera.vignette_intensity())
	vignette.set_speed_lines(m.speed_ratio(), m.boosting)
	if mode == RaceManager.Mode.RACE:
		hud.gap_ahead = _gap_text(race.rival_ahead(), "-")
		hud.gap_behind = _gap_text(race.rival_behind(), "+")

func _gap_text(rival: Node3D, sign_char: String) -> String:
	if rival == null:
		return ""
	return "%s%.1f" % [sign_char, absf(race.gap_to(rival))]

func _flight_path_marker() -> Vector2:
	var ahead := jet.global_position + jet.velocity.normalized() * 400.0
	if camera.is_position_behind(ahead):
		return Vector2.ZERO
	var screen := camera.unproject_position(ahead)
	return screen - get_viewport().get_visible_rect().size * 0.5

# --- events -------------------------------------------------------------

func _on_countdown(value: int) -> void:
	if value <= 0:
		hud.countdown_text = ""
		hud.show_message("GO", 0.8)
		_set_racing(true)
		Audio.play("go")
	else:
		hud.countdown_text = str(value)
		Audio.play("beep")

## The whole grid holds still through the countdown - bots included.
func _set_racing(active: bool) -> void:
	jet.frozen = not active
	for b in bots:
		b.frozen = not active

## Coming back from the pause menu gets its own 3-2-1, so nobody is dropped
## back into a canyon wall while still finding their thumb.
func _resume_with_countdown() -> void:
	get_tree().paused = false
	_set_racing(false)
	race.start_countdown(false)

func _on_boundary(active: bool) -> void:
	if active:
		hud.show_message("PİSTE DÖN", 1.3)

func _on_sector(sector: int, delta: float, has_reference: bool) -> void:
	if has_reference:
		hud.show_delta(delta)
		Audio.play("ding_up" if delta <= 0.0 else "ding_down")
	else:
		Audio.play("ding_up", 1.0, -6.0)

func _on_lap(lap_index: int, lap_time: float, _best: float, medal: String) -> void:
	var text := "LAP %d  %s" % [lap_index, Hud.format_time(lap_time)]
	if medal != "":
		text += "  " + medal
	hud.show_message(text, 2.5)
	if Settings.record_lap(track.track_name, lap_time, medal) or medal != "":
		Audio.play("fanfare")

func _on_finish(place: int, total: int) -> void:
	jet.frozen = true
	Audio.play("fanfare")
	menu.set_button_visible(false)
	var heading := "%d. SIRA" % place if mode == RaceManager.Mode.RACE else "BİTTİ"
	var lines := []
	if mode == RaceManager.Mode.RACE:
		lines.append("%d yarışçı içinde %d." % [total, place])
	lines.append("En iyi tur:  " + Hud.format_time(race.best_lap))
	lines.append("Son tur:     " + Hud.format_time(race.last_lap))
	lines.append("Hedef (Author):  " + Hud.format_time(track.author_time))
	lines.append_array(_progress_lines(place))
	Audio.set_music_ducked(true)
	results.show_results(heading, lines, race.best_medal)

## What the race was worth, plus where the session stands.
##
## The session line is deliberate: the paper that came with the brief points
## out that losing track of time is one of the clearest warning signs, and
## that a race ending is exactly the natural stopping point to put it at.
func _progress_lines(place: int) -> Array:
	var out := []
	var unlocked := Settings.note_race(track.track_name, place, race.best_medal)
	for skin in unlocked:
		out.append("YENİ İZ EFEKTİ: " + TrailSkins.skin_name(skin))
	var locked := -1
	for i in TrailSkins.count():
		if not Settings.is_skin_unlocked(i):
			locked = i
			break
	if locked >= 0:
		out.append("Sıradaki hedef: " + Progression.requirement(locked))
	else:
		out.append("Bütün iz efektleri açıldı.")
	out.append("Bu oturum: " + Hud.format_clock(Settings.session_seconds))
	return out

## A crash is the one moment the game should feel violent.
func _on_crash() -> void:
	_explosion.global_position = jet.global_position
	_explosion.restart()
	Audio.play("boom")
	Settings.vibrate(220)
	hud.show_message("ÇARPIŞMA", 1.4)
	race.respawn_player()

func _on_scrape(point: Vector3, normal: Vector3) -> void:
	_sparks.global_position = point
	# A floor hit gives a normal parallel to UP, which makes look_at degenerate.
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	_sparks.look_at(point + normal, up)
	_sparks.restart()
	Audio.play("scrape", randf_range(0.9, 1.15), -4.0)

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _report_budget() -> void:
	print("[budget] canyon chunks=%d sections=%d tris=%d" %
		[canyon.chunk_count(), canyon.section_count(), canyon.triangle_count()])
	print("[budget] track length=%.0f m, est lap=%.1f s at 320 m/s" %
		[canyon.length, canyon.length / 320.0])
