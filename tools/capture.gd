extends Node
## Development helper: flies the jet for a while and dumps frames to disk so a
## build can be eyeballed without a device. Enabled with `-- --shots <dir>`.

var out_dir := "user://shots"
var shots := [90, 240, 420, 600, 820]
var _frame := 0
var _taken := 0

static func wanted() -> bool:
	return OS.get_cmdline_user_args().has("--shots") or OS.get_environment("JET_SHOTS") != ""

static func out_path() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	var env := OS.get_environment("JET_SHOTS")
	return env if env != "" else "user://shots"

var main: Node

func _ready() -> void:
	out_dir = out_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = get_parent()
	if main.jet != null:
		main.jet.autopilot = _fly

## Fly the spline: convert the heading error into a bank angle, then roll
## toward it, which is how the jet actually turns. Steering with raw yaw error
## just makes it saw back and forth across the canyon.
func _fly() -> Vector2:
	var jet: JetController = main.jet
	var canyon: Canyon = main.canyon
	var off := canyon.offset_of(jet.global_position)
	var lead := 300.0 + jet.model.speed * 1.1
	var aim: Vector3 = canyon.point_at(off + lead)
	aim += Vector3.UP * canyon.wall_height_at_offset(off + lead) * 0.40
	var local: Vector3 = jet.global_transform.affine_inverse() * aim
	if local.z > -1.0:
		return Vector2.ZERO
	var yaw_err := atan2(local.x, -local.z)
	var pitch_err := atan2(local.y, -local.z)
	var want_bank := clampf(yaw_err * 2.4, -0.92, 0.92)
	var bank: float = -jet.global_transform.basis.x.y
	var roll := clampf((want_bank - bank) * 2.6, -1.0, 1.0)
	var pitch := clampf(pitch_err * 2.2 + absf(bank) * 0.35, -1.0, 1.0)
	return Vector2(roll, pitch)

func _process(_delta: float) -> void:
	_frame += 1
	if _taken >= shots.size():
		return
	if _frame < shots[_taken]:
		return
	_taken += 1
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/shot_%02d.png" % [out_dir, _taken])
	# What is actually on screen, rather than what the scene adds up to: the
	# terrain formations are 26k triangles each and live or die on their
	# visibility range, so the scene total says nothing useful.
	print("[frame %d] draw calls=%d primitives=%d" % [
		_taken,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	print("[capture] wrote shot_%02d.png at frame %d" % [_taken, _frame])
	if _taken >= shots.size():
		await get_tree().create_timer(0.3).timeout
		get_tree().quit()
