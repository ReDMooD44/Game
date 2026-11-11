class_name JetController
extends CharacterBody3D
## Player jet. Owns a FlightModel, turns its rates into motion, and resolves
## wall contact by sliding along the surface with a speed penalty.

signal scraped(point: Vector3, normal: Vector3)
signal stuck()
signal respawned()

@export var min_speed := 185.0
@export var max_speed := 320.0
@export var boost_speed := 372.0
@export var pitch_rate := 1.15
@export var roll_rate := 2.6
@export var coordinated_yaw := 0.95
@export var g_limit := 9.0
@export var scrape_speed_loss := 0.20     ## fraction of speed lost per wall contact
@export var scrape_cooldown := 0.12
@export var assist_probe_ahead := 30.0
@export_group("Tilt")
@export var tilt_roll_gain := 0.40
@export var tilt_pitch_gain := 0.36
@export var tilt_dead_zone := 0.04
@export var tilt_smoothing := 22.0   ## higher = less lag, lower = steadier
@export var tilt_curve := 1.45       ## >1 keeps small tilts gentle
@export var assist_floor_margin := 0.22   ## of the wall height: below this the assist lifts
@export var assist_ride_fraction := 0.40  ## of the wall height it lifts you back to
@export var assist_ride_gain := 0.6
## Optional: the track this jet is flying. With it the assist follows the
## canyon's own vertical profile instead of guessing from a raycast.
var canyon: Canyon

var model := FlightModel.new()
var input_source: Node = null             ## optional touch controls; keyboard is the fallback
## Optional Callable returning Vector2(roll, pitch). Used by the attract/demo
## mode so a build can be flown without hands on the screen.
var autopilot: Callable = Callable()
var frozen := true
var respawn_transform := Transform3D.IDENTITY

var _scrape_timer := 0.0
var _scrape_count := 0
var _scrape_window := 0.0
var _probe := PhysicsRayQueryParameters3D.new()
var _tilt_neutral := Vector3.ZERO
var _tilt_ready := false
var _tilt_value := Vector2.ZERO

func _ready() -> void:
	_push_tuning()
	model.reset()
	respawn_transform = global_transform
	_probe.collision_mask = 1

func _push_tuning() -> void:
	model.min_speed = min_speed
	model.max_speed = max_speed
	model.boost_speed = boost_speed
	model.pitch_rate = pitch_rate
	model.roll_rate = roll_rate
	model.coordinated_yaw = coordinated_yaw
	model.g_limit = g_limit

## Measured against however the phone was held when the race started, so it
## works lying on a table or propped at any angle - not just upright.
func calibrate_tilt() -> void:
	_tilt_ready = false

## The accelerometer is read first: the gravity sensor is heavily smoothed by
## the OS, which is what made tilt steering feel like it answered a moment
## late. We do our own, much lighter smoothing instead.
func _tilt_axes() -> Vector2:
	var g := Input.get_accelerometer()
	if g.length() < 0.5:
		g = Input.get_gravity()
	if g.length() < 0.5:
		return _tilt_value
	if not _tilt_ready:
		_tilt_neutral = g
		_tilt_ready = true
		_tilt_value = Vector2.ZERO
		return _tilt_value

	var sens: float = clampf(Settings.tilt_sensitivity, 0.25, 3.0)
	var d := g - _tilt_neutral
	var raw := Vector2(
		clampf(d.x * tilt_roll_gain * sens, -1.0, 1.0),
		clampf(-d.y * tilt_pitch_gain * sens, -1.0, 1.0))
	raw = Vector2(_shape(raw.x), _shape(raw.y))
	var k := clampf(tilt_smoothing * get_physics_process_delta_time(), 0.0, 1.0)
	_tilt_value = _tilt_value.lerp(raw, k)
	return _tilt_value

## Dead zone plus a curve, so holding the phone still is still, and small
## corrections stay small while a big lean still gives full authority.
func _shape(v: float) -> float:
	var a := absf(v)
	if a < tilt_dead_zone:
		return 0.0
	a = (a - tilt_dead_zone) / (1.0 - tilt_dead_zone)
	return signf(v) * pow(a, tilt_curve)

func arm(from: Transform3D) -> void:
	calibrate_tilt()
	respawn_transform = from
	global_transform = from
	model.reset()
	frozen = false

func respawn_at(from: Transform3D) -> void:
	respawn_transform = from
	global_transform = from
	model.reset(model.min_speed)
	respawned.emit()

func _physics_process(delta: float) -> void:
	if frozen:
		return
	_scrape_timer = maxf(0.0, _scrape_timer - delta)
	_scrape_window = maxf(0.0, _scrape_window - delta)
	if _scrape_window <= 0.0:
		_scrape_count = 0
	_read_input()
	var assist: bool = Settings.flight_assist
	model.step(delta, -global_transform.basis.x.y, -global_transform.basis.z.y,
		_target_climb() if assist else 0.0, assist)
	_integrate(delta)

func _read_input() -> void:
	var pitch := 0.0
	var roll := 0.0
	if autopilot.is_valid():
		var a: Vector2 = autopilot.call()
		model.pitch_input = clampf(a.y, -1.0, 1.0)
		model.roll_input = clampf(a.x, -1.0, 1.0)
		model.airbrake = false
		model.boosting = false
		return
	if input_source != null and input_source.has_method("get_stick"):
		var stick: Vector2 = input_source.get_stick()
		roll = stick.x
		pitch = -stick.y
		model.airbrake = input_source.get_airbrake()
		model.boosting = input_source.get_boost()
	else:
		pitch = Input.get_axis("pitch_down", "pitch_up")
		roll = Input.get_axis("roll_left", "roll_right")
		model.airbrake = Input.is_action_pressed("airbrake")
		model.boosting = Input.is_action_pressed("boost")

	if Settings.tilt_control:
		var t := _tilt_axes()
		if t != Vector2.ZERO:
			roll = t.x
			pitch = t.y

	model.pitch_input = clampf(pitch, -1.0, 1.0)
	model.roll_input = clampf(roll, -1.0, 1.0)

## Hands off, the jet rides the canyon's own vertical profile rather than a
## world horizon: the floor climbs and drops by tens of metres, and flying
## "level" just means ploughing into the next rise.
##
## The altitude comes from the spline, not a downward ray. A ray pointed at a
## sloping wall reads "the ground is close", so the jet climbs, which keeps the
## wall underneath it, so it climbs again - all the way to the rim.
## Only ever lifts, and only when the floor is genuinely close. It used to
## hold a fixed altitude, which felt like the jet was pinned to the middle of
## the canyon and dragged back down every time you tried to climb.
func _target_climb() -> float:
	if canyon == null:
		return 0.0
	var here := canyon.offset_of(global_position)
	var ahead := here + assist_probe_ahead + model.speed * 0.9
	var h: float = canyon.wall_height_at_offset(ahead)
	var floor_y: float = canyon.point_at(ahead).y
	var danger := floor_y + h * assist_floor_margin
	if global_position.y >= danger:
		return 0.0            # plenty of room: hands off means hold what you have
	var want := floor_y + h * assist_ride_fraction
	var err := (want - global_position.y) / maxf(h * assist_ride_fraction, 1.0)
	return clampf(err * assist_ride_gain, 0.0, 0.34)

func _integrate(delta: float) -> void:
	var b := global_transform.basis
	b = b.rotated(b.x, model.out_pitch * delta)
	# out_roll is a roll rate to the RIGHT. Local +Z points backwards, so a
	# right-hand rotation about it rolls left - hence the minus. Without it
	# the stick, the auto-levelling and the wall assist all work backwards.
	b = b.rotated(b.z, -model.out_roll * delta)
	b = b.rotated(Vector3.UP, model.out_yaw * delta)
	global_transform.basis = b.orthonormalized()

	velocity = -global_transform.basis.z * model.speed
	var hit := move_and_collide(velocity * delta)
	if hit == null:
		return
	_on_scrape(hit)

func _on_scrape(hit: KinematicCollision3D) -> void:
	var normal := hit.get_normal()
	var dir := (-global_transform.basis.z).slide(normal)
	if dir.length() < 0.05:
		dir = normal
	dir = dir.normalized()
	# Re-aim along the wall instead of bouncing off it; bouncing in a 100 m
	# canyon at 300 m/s reads as a crash, not a graze.
	var up := global_transform.basis.y.slide(dir)
	if up.length() < 0.05:
		up = Vector3.UP.slide(dir)
	if up.length() < 0.05:
		up = Vector3.FORWARD.slide(dir)
	up = up.normalized()
	var right := dir.cross(up)
	# A singular basis here survives into every later affine_inverse as a
	# "det == 0" error and a jet that can no longer be steered.
	if right.length() < 0.05:
		return
	global_transform.basis = Basis(right.normalized(), up, -dir).orthonormalized()
	# Push all the way back out of the surface. Nudging by a fixed 1.5 m is not
	# enough at 300 m/s: the jet ends up buried inside the cliff and stays there.
	global_position += normal * (hit.get_depth() + 2.5)

	if _scrape_timer <= 0.0:
		model.speed = maxf(model.min_speed * 0.5, model.speed * (1.0 - scrape_speed_loss))
		_scrape_timer = scrape_cooldown
		Settings.vibrate(50)
		scraped.emit(hit.get_position(), normal)
		_scrape_count += 1
		_scrape_window = 1.2
		# Repeated contact in one second means the line is unrecoverable, not
		# that the player is grazing a wall. Put them back on the track.
		if _scrape_count >= 5:
			_scrape_count = 0
			stuck.emit()

# --- read-only accessors used by the camera, HUD and race manager --------

func get_g_force() -> float:
	return model.g_force

func get_speed_ratio() -> float:
	return model.speed_ratio()

func get_speed() -> float:
	return model.speed
