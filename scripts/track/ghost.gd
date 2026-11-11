class_name Ghost
extends RefCounted
## Fixed-tick recording of one lap: position plus orientation, nothing else.
## Recorded at the physics rate so playback lines up with a deterministic model.

const DIR := "user://ghosts"
const FLOATS_PER_FRAME := 7  # pos xyz + quat xyzw

var frames := PackedFloat32Array()

func frame_count() -> int:
	return frames.size() / FLOATS_PER_FRAME

func clear() -> void:
	frames = PackedFloat32Array()

func record(t: Transform3D) -> void:
	var q := t.basis.get_rotation_quaternion()
	frames.append(t.origin.x)
	frames.append(t.origin.y)
	frames.append(t.origin.z)
	frames.append(q.x)
	frames.append(q.y)
	frames.append(q.z)
	frames.append(q.w)

func sample(tick: int) -> Transform3D:
	var n := frame_count()
	if n == 0:
		return Transform3D.IDENTITY
	var i := clampi(tick, 0, n - 1) * FLOATS_PER_FRAME
	var pos := Vector3(frames[i], frames[i + 1], frames[i + 2])
	var q := Quaternion(frames[i + 3], frames[i + 4], frames[i + 5], frames[i + 6])
	return Transform3D(Basis(q.normalized()), pos)

func save(track_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(_path(track_name), FileAccess.WRITE)
	if f == null:
		return
	f.store_32(frame_count())
	f.store_buffer(frames.to_byte_array())
	f.close()

func load_from(track_name: String) -> bool:
	var f := FileAccess.open(_path(track_name), FileAccess.READ)
	if f == null:
		return false
	var n := f.get_32()
	var bytes := f.get_buffer(n * FLOATS_PER_FRAME * 4)
	f.close()
	if bytes.size() < n * FLOATS_PER_FRAME * 4:
		return false
	frames = bytes.to_float32_array()
	return frame_count() > 0

func _path(track_name: String) -> String:
	return "%s/%s.ghost" % [DIR, track_name.to_snake_case()]
