class_name ChaseCamera
extends Camera3D
## Smoothed chase cam. Speed drives FOV, g drives shake and roll offset.
## Mobile keeps roughly half the shake of the desktop reference - on a phone
## held 30 cm from your face, the PC amount is nauseating.

@export var offset := Vector3(0.0, 4.5, 16.0)
@export var position_lerp := 12.0
@export var rotation_lerp := 8.0
@export var fov_min := 65.0
@export var fov_max := 88.0
@export var fov_lerp := 4.0
@export var shake_strength := 0.10      ## metres of shake per g above 1
@export var roll_offset := 0.12         ## extra camera roll per unit of bank
@export var proximity_punch := 5.0      ## extra degrees of FOV when hugging a wall
@export var boost_punch := 14.0         ## extra degrees while the afterburner is lit
@export var boost_pull_back := 3.5      ## metres the camera drops back under boost
@export var vignette_curve := 1.4

var target: Node3D
var shake_amount := 0.0
var proximity := 0.0                    ## 0 open canyon .. 1 wall in your face
var boosting := false
var _boost_blend := 0.0

var _noise_t := 0.0
var _probe := PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	_probe.collision_mask = 1
	top_level = true

func set_target(node: Node3D) -> void:
	target = node
	if target != null:
		global_transform = _desired_transform()

func _physics_process(delta: float) -> void:
	if target == null:
		return
	_update_proximity()
	var want := _desired_transform()
	var t := global_transform
	t.origin = t.origin.lerp(want.origin, clampf(position_lerp * delta, 0.0, 1.0))
	t.basis = t.basis.slerp(want.basis, clampf(rotation_lerp * delta, 0.0, 1.0)).orthonormalized()
	global_transform = t
	_apply_shake(delta)
	_apply_fov(delta)

func _desired_transform() -> Transform3D:
	var tb := target.global_transform.basis
	var eye := target.global_position + tb.z * (offset.z + _boost_blend * boost_pull_back) 		+ tb.y * offset.y
	var look := target.global_position - tb.z * 30.0
	var up := tb.y.lerp(Vector3.UP, 0.35).normalized()
	var t := Transform3D(Basis(), eye)
	t = t.looking_at(look, up)
	# Lean the frame into the turn, like the reference footage does.
	var bank := -tb.x.y
	t.basis = t.basis.rotated(t.basis.z, bank * roll_offset)
	return t

func _update_proximity() -> void:
	var space := get_world_3d().direct_space_state
	var b := target.global_transform.basis
	# Sideways only: the floor is always below you, so including it would keep
	# the frame permanently punched in.
	var reach := 40.0
	var nearest := reach
	for dir in [-b.x, b.x]:
		_probe.from = target.global_position
		_probe.to = target.global_position + dir * reach
		var hit := space.intersect_ray(_probe)
		if not hit.is_empty():
			nearest = minf(nearest, target.global_position.distance_to(hit.position))
	proximity = clampf(1.0 - nearest / reach, 0.0, 1.0)

func _apply_shake(delta: float) -> void:
	var g := 1.0
	if target.has_method("get_g_force"):
		g = target.get_g_force()
	var want := maxf(0.0, g - 1.0) * shake_strength + proximity * 0.15
	shake_amount = lerpf(shake_amount, want, clampf(6.0 * delta, 0.0, 1.0))
	if shake_amount < 0.001:
		return
	_noise_t += delta * 28.0
	var jitter := Vector3(sin(_noise_t * 1.7), cos(_noise_t * 2.3), sin(_noise_t * 3.1)) * shake_amount
	global_position += global_transform.basis * jitter

func _apply_fov(delta: float) -> void:
	var ratio := 0.0
	if target.has_method("get_speed_ratio"):
		ratio = clampf(target.get_speed_ratio(), 0.0, 1.3)
	_boost_blend = lerpf(_boost_blend, 1.0 if boosting else 0.0, clampf(5.0 * delta, 0.0, 1.0))
	var want := lerpf(fov_min, fov_max, ratio) + proximity * proximity_punch 		+ _boost_blend * boost_punch
	fov = lerpf(fov, want, clampf(fov_lerp * delta, 0.0, 1.0))

## 0..1, fed to the HUD vignette so speed and wall proximity tighten the frame.
func vignette_intensity() -> float:
	var ratio := 0.0
	if target != null and target.has_method("get_speed_ratio"):
		ratio = clampf(target.get_speed_ratio(), 0.0, 1.0)
	return clampf(pow(ratio, vignette_curve) * 0.6 + proximity * 0.3
		+ _boost_blend * 0.25, 0.0, 1.0)
