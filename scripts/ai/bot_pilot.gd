class_name BotPilot
extends Node3D
## Bots do not fly the flight model. They ride the spline in a reserved lateral
## lane with look-ahead smoothing and a little wobble. One sixth of the cost of
## a real jet, and the line they take is something you can actually tune.

@export var pilot_name := "BOT"
@export var livery := Color(0.9, 0.2, 0.2)
@export var speed_scale := 1.0
@export var line_error := 6.0          ## metres of low-frequency drift
@export var corner_aggression := 1.0   ## how far toward the inside of a bend it cuts
@export var lane := 0.0                ## -1..1 across the canyon, times half-width
@export var height_lane := 0.50        ## fraction of wall height it cruises at

var canyon: Canyon
var base_speed := 310.0
var offset := 0.0
var laps_done := 0
var rubber_band := 1.0
var frozen := true

var _wobble_seed := 0.0
var _prev_pos := Vector3.ZERO
var _roll := 0.0

func setup(canyon_node: Canyon, start_offset: float, seed_value: float) -> void:
	canyon = canyon_node
	offset = start_offset
	_wobble_seed = seed_value
	_prev_pos = _target_position(offset)
	global_position = _prev_pos

func current_speed() -> float:
	return base_speed * speed_scale * rubber_band

func total_progress() -> float:
	return laps_done * canyon.length + offset

func get_speed() -> float:
	return current_speed()

func _physics_process(delta: float) -> void:
	if canyon == null or frozen:
		return
	var step := current_speed() * delta
	offset += step
	if offset >= canyon.length:
		offset -= canyon.length
		laps_done += 1

	var pos := _target_position(offset)
	# Look-ahead keeps the nose pointed where the lane is going, not where it is.
	var ahead := _target_position(offset + 90.0)
	var fwd := (ahead - pos)
	if fwd.length() < 0.01:
		fwd = -global_transform.basis.z
	fwd = fwd.normalized()

	var lateral := (pos - _prev_pos) - fwd * (pos - _prev_pos).dot(fwd)
	var want_roll := clampf(-lateral.dot(fwd.cross(Vector3.UP).normalized()) * 9.0, -1.2, 1.2)
	_roll = lerpf(_roll, want_roll, clampf(5.0 * delta, 0.0, 1.0))

	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	var basis := Basis(right, up, -fwd).rotated(fwd, _roll)
	global_transform = Transform3D(basis.orthonormalized(), pos)
	_prev_pos = pos

func _target_position(at: float) -> Vector3:
	var t := canyon.transform_at(at)
	var hw := canyon.half_width_at_offset(at)
	var h := canyon.wall_height_at_offset(at)
	# Lane plus a slow wander, so six jets in formation do not look like a bus.
	var wander := sin(at * 0.0035 + _wobble_seed) * line_error
	var cut := sin(at * 0.0012 + _wobble_seed * 1.7) * corner_aggression * hw * 0.18
	var lateral := clampf(lane * hw * 0.62 + wander + cut, -hw * 0.8, hw * 0.8)
	var height := h * height_lane + sin(at * 0.002 + _wobble_seed * 2.3) * h * 0.08
	return t.origin + t.basis.x * lateral + t.basis.y * height
