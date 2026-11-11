class_name CanyonProps
extends RefCounted
## Places the supplied slot-canyon terrain along the track.
##
## GROUND.fbx is a 50 x 150 unit plate with a winding canyon cut through it,
## built from three copies of the same 50-unit segment. One segment (five
## meshes, about 26k triangles) is welded here and dropped along the spline,
## scaled up to the size of the real canyon and sunk so its rim sits level
## with ours. Only a couple are ever drawn: each carries a visibility range,
## because 26k triangles times a dozen formations would eat the whole budget.

const SOURCE := "res://assets/ground/ground.fbx"
const ROCK := "res://assets/ground/canyon_wall.png"
const ROCK_FALLBACK := "res://assets/ground/rock.jpg"
## The first segment of the three; the others are identical copies.
const SEGMENT := ["Mesh1", "Mesh2", "Mesh3", "Mesh4", "Mesh5"]
const DRAW_DISTANCE := 1150.0
const COUNT := 20                  ## formations spaced round the lap
const SPAN := 4.0                  ## track half widths one formation covers
const RIM_X := 1.22                ## canyon profile x at the rim
const CLEARANCE := 55.0            ## metres between the rim and the rock
const RIM_DROP := 1.02             ## where the formation sits, in wall heights
const CHECK_GRID := 4              ## samples per box edge when vetting a spot
const GRID_CELLS := 34.0           ## clustering grid across the mesh

static var _cached: ArrayMesh = null

static func mesh() -> ArrayMesh:
	if _cached == null:
		_cached = _build()
	return _cached

static func _build() -> ArrayMesh:
	var out := ArrayMesh.new()
	if not ResourceLoader.exists(SOURCE):
		return out
	var packed: PackedScene = load(SOURCE)
	if packed == null:
		return out
	var root := packed.instantiate()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := _append(root, Transform3D.IDENTITY, st)
	root.free()
	if not any:
		return out
	st.index()
	var baked := st.commit()
	if baked == null:
		return out
	return _reduce(baked)

## One segment is about 26k triangles, and several are in view at once; drawn
## at full detail they took the frame to 249k, against a budget of 150k. These
## are skyline beyond the rim, so the mesh is thinned once, at load.
##
## Thinned by vertex clustering: positions are snapped to a coarse grid, every
## vertex in a cell collapses to that cell's average, and triangles whose
## corners end up in the same cell disappear. Crude, but it holds a silhouette,
## which is all these need - and it is the mesh itself that gets smaller, so it
## works on the Compatibility renderer this game ships on.
##
## Done by hand because ImporterMesh.generate_lods() returned no levels at all
## here, and because Compatibility does not switch mesh LODs even when they
## exist: generating them left the frame at 249k, unchanged.
static func _reduce(src: ArrayMesh) -> ArrayMesh:
	var arrays: Array = src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if verts.is_empty() or idx.is_empty():
		return src
	var box := src.get_aabb()
	var cell: float = maxf(box.size.x, maxf(box.size.y, box.size.z)) / GRID_CELLS
	if cell <= 0.0:
		return src

	# Cell key -> representative index, plus running sums for its average.
	var keys := {}
	var sum_pos: Array[Vector3] = []
	var sum_uv: Array[Vector2] = []
	var counts: PackedInt32Array = PackedInt32Array()
	var remap: PackedInt32Array = PackedInt32Array()
	remap.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		var key := "%d,%d,%d" % [
			int(floor(v.x / cell)), int(floor(v.y / cell)), int(floor(v.z / cell))]
		var slot: int
		if keys.has(key):
			slot = keys[key]
		else:
			slot = sum_pos.size()
			keys[key] = slot
			sum_pos.append(Vector3.ZERO)
			sum_uv.append(Vector2.ZERO)
			counts.append(0)
		sum_pos[slot] += v
		if i < uvs.size():
			sum_uv[slot] += uvs[i]
		counts[slot] += 1
		remap[i] = slot

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := 0
	while tri + 2 < idx.size():
		var a := remap[idx[tri]]
		var b := remap[idx[tri + 1]]
		var c := remap[idx[tri + 2]]
		tri += 3
		# Two corners in one cell means the triangle has collapsed to a line.
		if a == b or b == c or a == c:
			continue
		for slot in [a, b, c]:
			var n: float = maxf(float(counts[slot]), 1.0)
			st.set_uv(sum_uv[slot] / n)
			st.add_vertex(sum_pos[slot] / n)
	st.generate_normals()
	st.index()
	var out := st.commit()
	if out == null or out.get_surface_count() == 0:
		return src
	print("[props] thinned %d triangles to %d" % [
		idx.size() / 3, (out.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3])
	return out

static func _append(node: Node, parent: Transform3D, st: SurfaceTool) -> bool:
	var here := parent
	if node is Node3D:
		here = parent * node.transform
	var any := false
	if node is MeshInstance3D and node.mesh != null and SEGMENT.has(str(node.name)):
		var m: Mesh = node.mesh
		for s in m.get_surface_count():
			var arrays: Array = m.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				idx = PackedInt32Array(range(verts.size()))
			for i in idx:
				if i < uvs.size():
					st.set_uv(uvs[i])
				if i < normals.size():
					st.set_normal((here.basis * normals[i]).normalized())
				st.add_vertex(here * verts[i])
			any = true
	for c in node.get_children():
		if _append(c, here, st):
			any = true
	return any

static func material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	# The same rock the canyon walls are made of, so the formations behind the
	# rim read as more of the same cliff rather than as separate pale lumps.
	var tex := ROCK if ResourceLoader.exists(ROCK) else ROCK_FALLBACK
	if ResourceLoader.exists(tex):
		mat.albedo_texture = load(tex)
		mat.uv1_scale = Vector3(5.0, 5.0, 5.0)
	# Tuned to sit behind the canyon rather than compete with it: the walls
	# are the subject, these are the land beyond them.
	mat.albedo_color = Color(0.62, 0.42, 0.30)
	mat.roughness = 1.0
	return mat

## Lines the lap with formations, each lying along the track just beyond the
## rim so it dresses the top of the wall rather than standing apart from it.
##
## Every candidate is vetted before it is kept, and one that reaches into the
## canyon is dropped. That check has to be here rather than expressed as a
## safe distance, because the track is a closed loop that doubles back on
## itself: a plate hundreds of metres long, laid along the tangent at its own
## offset, can cross the canyon somewhere else entirely. Pushing the whole
## ring further out does almost nothing about that - tried at 120, 180 and
## 240 m, and ten of thirty-two still cut through the track.
##
## Formations carry no collider, so one left inside is rock the jet flies
## straight through.
static func populate(canyon: Canyon, parent: Node3D) -> int:
	var baked := mesh()
	if baked == null or baked.get_surface_count() == 0:
		return 0
	var bounds := baked.get_aabb()
	var mat := material()
	var placed := 0

	for i in COUNT:
		var offset := canyon.length * float(i) / COUNT
		var t := canyon.transform_at(offset)
		var h := canyon.wall_height_at_offset(offset)
		var scale := maxf(canyon.half_width_at_offset(offset) * SPAN
			/ maxf(bounds.size.z, 1.0), 1.0)
		var length := bounds.size.z * scale
		# The plate is long and the canyon bends and narrows under it, so the
		# clearance answers to the TIGHTEST point it covers, not to the half
		# width at its midpoint.
		var keep_out := _tightest(canyon, offset, length) * RIM_X + CLEARANCE
		for side_index in 2:
			# Untyped array literals make every expression downstream a Variant.
			var side := -1.0 if side_index == 0 else 1.0
			# Push the mesh out until the edge FACING the canyon clears the
			# keep-out line, whichever edge of its own bounds that happens to
			# be. The old code assumed the plate was centred on its origin in
			# x and offset it by half its width, which it is not.
			var inner: float = bounds.position.x * scale if side > 0.0 				else (bounds.position.x + bounds.size.x) * scale
			# -Z of the track frame is forward and the plate runs along +Z, so
			# the two line up without any extra turn.
			var pos := t.origin + t.basis.x * (keep_out * side - inner) 				+ t.basis.y * (h * RIM_DROP - bounds.position.y * scale
					- bounds.size.y * scale)
			var xf := Transform3D(t.basis.scaled(Vector3(scale, scale, scale)), pos)
			if clearance(canyon, bounds, xf) < 0.0:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = baked
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = DRAW_DISTANCE
			mi.visibility_range_end_margin = 400.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			parent.add_child(mi)
			# Added to the tree first, then placed with the local transform:
			# the canyon is at the origin, so the two are the same thing.
			mi.transform = xf
			placed += 1
	return placed

## Narrowest half width over the stretch of track a formation covers.
static func _tightest(canyon: Canyon, offset: float, length: float) -> float:
	var out := INF
	for s in 9:
		out = minf(out, canyon.half_width_at_offset(
			offset + (float(s) / 8.0 - 0.5) * length))
	return out

## Smallest gap from the formation to the canyon rim line, over its whole
## oriented bounding box. Negative means some of it is inside the canyon.
##
## Each corner is measured against the cross section at ITS OWN offset along
## the spline. Testing the world axis-aligned box instead makes a long plate
## laid at an angle look far wider than it is.
static func clearance(canyon: Canyon, bounds: AABB, xf: Transform3D) -> float:
	var worst := INF
	for ix in CHECK_GRID + 1:
		for iy in 2:
			for iz in CHECK_GRID + 1:
				var p: Vector3 = xf * (bounds.position + Vector3(
					bounds.size.x * float(ix) / CHECK_GRID,
					bounds.size.y * float(iy),
					bounds.size.z * float(iz) / CHECK_GRID))
				var off := canyon.offset_of(p)
				var frame := canyon.transform_at(off)
				var rel: Vector3 = frame.affine_inverse() * p
				# Anything at or above the rim is skyline, not an obstacle.
				if rel.y > canyon.wall_height_at_offset(off) * 1.25:
					continue
				worst = minf(worst,
					absf(rel.x) - canyon.half_width_at_offset(off) * RIM_X)
	return worst
