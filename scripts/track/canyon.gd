class_name Canyon
extends Node3D
## Procedural canyon: a swept cross section along a closed Path3D spline.
## The visual mesh is split into chunks so frustum culling has something to
## work with, and the collider is a separate, coarser sweep.

## x as a multiple of half-width, y as a multiple of wall height. Left rim
## through the floor to the right rim. The places where x steps back inward on
## the way up are undercuts: the overhang above each one is what stops the
## walls reading as a smooth extruded pipe.
const PROFILE := [
	Vector2(-1.22, 1.25), Vector2(-1.10, 1.06), Vector2(-0.99, 0.90),
	Vector2(-1.04, 0.78), Vector2(-0.97, 0.62), Vector2(-0.86, 0.50),
	Vector2(-0.93, 0.39), Vector2(-0.88, 0.27), Vector2(-0.74, 0.17),
	Vector2(-0.80, 0.08), Vector2(-0.70, 0.01), Vector2(-0.42, -0.03),
	Vector2(0.00, -0.05),
	Vector2(0.42, -0.03), Vector2(0.70, 0.01), Vector2(0.80, 0.08),
	Vector2(0.74, 0.17), Vector2(0.88, 0.27), Vector2(0.93, 0.39),
	Vector2(0.86, 0.50), Vector2(0.97, 0.62), Vector2(1.04, 0.78),
	Vector2(0.99, 0.90), Vector2(1.10, 1.06), Vector2(1.22, 1.25),
]
## Smooth hull strictly INSIDE the visual sweep, undercuts and relief
## included, so the jet can never bounce off a wall that is not drawn.
const COLLIDER_PROFILE := [
	Vector2(-1.14, 1.28), Vector2(-0.95, 0.94), Vector2(-0.92, 0.74),
	Vector2(-0.82, 0.52), Vector2(-0.80, 0.34), Vector2(-0.72, 0.18),
	Vector2(-0.68, 0.04), Vector2(-0.45, 0.01),
	Vector2(0.00, -0.01),
	Vector2(0.45, 0.01), Vector2(0.68, 0.04), Vector2(0.72, 0.18),
	Vector2(0.80, 0.34), Vector2(0.82, 0.52), Vector2(0.92, 0.74),
	Vector2(0.95, 0.94), Vector2(1.14, 1.28),
]
const COLLIDER_STRIDE := 2
const RELIEF := 0.155           ## outward relief, as a fraction of half-width
const UV_METRES := 62.0         ## metres of wall per rock-texture tile

@export var track: TrackData
@export var material: Material

var curve := Curve3D.new()
var length := 0.0

var _frames: Array[Transform3D] = []
var _halfs: PackedFloat32Array = PackedFloat32Array()
var _heights: PackedFloat32Array = PackedFloat32Array()
var _ao: PackedFloat32Array = PackedFloat32Array()
var _lit: PackedFloat32Array = PackedFloat32Array()
var _arc: PackedFloat32Array = PackedFloat32Array()
var _chunk_count := 0
var _v_repeats := 1.0

func build(difficulty := 1) -> void:
	if track == null or not track.is_valid():
		push_error("Canyon: track data missing or malformed")
		return
	for c in get_children():
		c.queue_free()
	curve = track.build_curve(difficulty)
	length = curve.get_baked_length()
	_sample_frames(difficulty)
	_bake_shading()
	_build_visual()
	_build_collider()

## Transport a frame along the spline without letting it spin about the tangent.
func _sample_frames(difficulty: int) -> void:
	_frames.clear()
	_halfs = PackedFloat32Array()
	_heights = PackedFloat32Array()
	var steps := int(length / track.section_spacing)
	var up := Vector3.UP
	for i in steps:
		var off := float(i) / steps * length
		var pos := curve.sample_baked(off)
		var ahead := curve.sample_baked(fposmod(off + 6.0, length))
		var fwd := (ahead - pos).normalized()
		if fwd.length() < 0.5:
			fwd = Vector3.FORWARD
		var right := fwd.cross(up).normalized()
		up = right.cross(fwd).normalized()
		_frames.append(Transform3D(Basis(right, up, -fwd), pos))
		var r := float(i) / steps
		_halfs.append(track.half_width_at(r, difficulty))
		# Ragged, so the rim reads as broken cliff top against the sky.
		_heights.append(track.wall_height_at(r) * CanyonShading.rim_jitter(r))
	_chunk_count = int(ceil(float(steps) / track.sections_per_chunk))
	# Whole number of tiles round the lap, so the texture meets itself at the
	# start line instead of showing a seam there.
	_v_repeats = maxf(round(length / UV_METRES), 1.0)

## Occlusion, sun and cross-section arc length, once per vertex of the sweep.
## The sun term needs the canyon's own left/right axis, which turns as the
## track winds, so the lit wall swaps sides over a lap by itself.
func _bake_shading() -> void:
	var n := _frames.size()
	var cols := PROFILE.size()
	_ao.resize(n * cols)
	_lit.resize(n * cols)
	_arc.resize(n * cols)
	var to_sun := SkyMood.to_sun()
	for i in n:
		var f := _frames[i]
		var hw := _halfs[i]
		var h := _heights[i]
		var lat := to_sun.dot(f.basis.x)
		var run := 0.0
		var base := i * cols
		for k in cols:
			var p: Vector2 = PROFILE[k]
			if k > 0:
				var q: Vector2 = PROFILE[k - 1]
				run += Vector2((p.x - q.x) * hw, (p.y - q.y) * h).length()
			_ao[base + k] = CanyonShading.occlusion(p.x, p.y, hw, h)
			_lit[base + k] = CanyonShading.sunlit(p.x, p.y, hw, h, lat, to_sun.y)
			_arc[base + k] = run

func _build_visual() -> void:
	var total := _frames.size()
	for c in _chunk_count:
		var from := c * track.sections_per_chunk
		var to := mini(from + track.sections_per_chunk, total)
		var mi := MeshInstance3D.new()
		mi.mesh = _sweep(from, to + 1)
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = track.lod_distance
		mi.visibility_range_end_margin = 400.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mi)

func _build_collider() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.backface_collision = true
	concave.set_faces(_collision_faces())
	shape.shape = concave
	body.add_child(shape)
	add_child(body)

## Visual ring: the profile pushed outward by its own relief, so the walls
## bulge and recede along the track instead of being one constant tube.
func _ring(index: int) -> PackedVector3Array:
	var n := _frames.size()
	var i := index % n
	var f := _frames[i]
	var hw := _halfs[i]
	var h := _heights[i]
	var r := float(i) / float(n)
	var out := PackedVector3Array()
	for k in PROFILE.size():
		var p: Vector2 = PROFILE[k]
		var nrm := CanyonShading.profile_normal(PROFILE, k, hw, h)
		var push := CanyonShading.relief(r, k, RELIEF) * hw
		var local := Vector2(p.x * hw, p.y * h) + nrm * push
		out.append(f.origin + f.basis.x * local.x + f.basis.y * local.y)
	return out

func _collider_ring(index: int) -> PackedVector3Array:
	var n := _frames.size()
	var i := index % n
	var f := _frames[i]
	var hw := _halfs[i]
	var h := _heights[i]
	var out := PackedVector3Array()
	for p in COLLIDER_PROFILE:
		out.append(f.origin + f.basis.x * (p.x * hw) + f.basis.y * (p.y * h))
	return out

func _sweep(from: int, to: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := PROFILE.size()
	var i := from
	while i + 1 < to:
		var a := _ring(i)
		var b := _ring(i + 1)
		for k in cols - 1:
			_quad(st, a, b, i, k)
		i += 1
	st.generate_normals()
	# The detail normal map is applied in tangent space, which needs these.
	st.generate_tangents()
	st.index()
	return st.commit()

func _quad(st: SurfaceTool, a: PackedVector3Array, b: PackedVector3Array,
		section: int, col: int) -> void:
	var verts := [a[col], a[col + 1], b[col + 1], b[col]]
	var sections := [section, section, section + 1, section + 1]
	var cols := [col, col + 1, col + 1, col]
	# Wound so the faces point INTO the canyon. Get this backwards and the
	# whole track is invisible from the cockpit while still solid to collide with.
	var order := [0, 2, 1, 0, 3, 2]
	for oi in order:
		var v: Vector3 = verts[oi]
		_shade_vertex(st, v, int(sections[oi]), int(cols[oi]))
		st.add_vertex(v)

## Everything the shader needs that cannot be worked out per fragment:
##   COLOR rgb  strata variation, along-track grain, sand vs cut rock
##   COLOR a    ambient occlusion
##   UV2.x      direct sun, 0 in the shadow of the opposite rim
##   UV2.y      height up the wall
func _shade_vertex(st: SurfaceTool, v: Vector3, section: int, col: int) -> void:
	var n := _frames.size()
	var i := section % n
	var slot := i * PROFILE.size() + col
	var band := sin(v.y * 0.035 + i * 0.11) * 0.5 + 0.5
	var grain := sin(i * 0.73 + col * 2.1) * 0.5 + 0.5
	st.set_color(Color(0.72 + band * 0.28, 0.80 + grain * 0.20,
		_sandness(col), _ao[slot]))
	var py: float = (PROFILE[col] as Vector2).y
	st.set_uv2(Vector2(_lit[slot], clampf(py / 1.25, 0.0, 1.0)))
	# Arc length across the section and metres along the track, both in the
	# same units, so the rock grain never stretches on a tall wall.
	st.set_uv(Vector2(_arc[slot] / UV_METRES, float(i) / float(n) * _v_repeats))

## 1 on the canyon floor, 0 on the cliff faces, blended over the break.
static func _sandness(col: int) -> float:
	if col >= 11 and col <= 13:
		return 1.0
	if col == 10 or col == 14:
		return 0.5
	if col == 9 or col == 15:
		return 0.2
	return 0.0

func _collision_faces() -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := _frames.size()
	var cols := COLLIDER_PROFILE.size()
	var i := 0
	while i < n:
		var a := _collider_ring(i)
		var b := _collider_ring(i + COLLIDER_STRIDE)
		for k in cols - 1:
			# Same inward winding as the visual mesh. With the faces pointing
			# outward, ConcavePolygonShape3D culls them for raycasts started
			# inside the canyon: bodies still collide, but every assist probe,
			# the camera proximity test and the blob shadow silently miss.
			out.append(a[k]); out.append(b[k + 1]); out.append(a[k + 1])
			out.append(a[k]); out.append(b[k]); out.append(b[k + 1])
		i += COLLIDER_STRIDE
	return out

## Half width of the COLLISION hull at a height up the wall, both given as
## fractions - x of the canyon half width, y of the wall height.
##
## This is the line the jet cannot cross, and it sits inboard of the visible
## wall. The gap between the two is where scenery can stand: visible from the
## cockpit, impossible to reach, so none of it needs a collider of its own.
static func hull_half_width(py: float) -> float:
	var lo := Vector2(0.0, -1.0)
	var hi := Vector2(0.0, 99.0)
	var found_lo := false
	var found_hi := false
	for p in COLLIDER_PROFILE:
		var v: Vector2 = p
		if v.x < 0.0:
			continue
		if v.y <= py and v.y >= lo.y:
			lo = v
			found_lo = true
		if v.y >= py and v.y <= hi.y:
			hi = v
			found_hi = true
	if not found_lo:
		return hi.x if found_hi else 1.14
	if not found_hi:
		return lo.x
	if is_equal_approx(lo.y, hi.y):
		return lo.x
	return lerpf(lo.x, hi.x, clampf(inverse_lerp(lo.y, hi.y, py), 0.0, 1.0))

## True when a world point is somewhere the jet could actually fly, with a
## margin in metres around the hull.
func is_reachable(point: Vector3, margin: float) -> bool:
	var off := offset_of(point)
	var hw := half_width_at_offset(off)
	var h := wall_height_at_offset(off)
	var rel: Vector3 = transform_at(off).affine_inverse() * point
	var py := rel.y / maxf(h, 1.0)
	# Below the floor is inside solid rock; above the rim is open sky.
	if py < -0.02 or py > 1.26:
		return false
	return absf(rel.x) < hull_half_width(py) * hw + margin

# --- queries used by the race manager, bots and respawn ------------------

func offset_of(pos: Vector3) -> float:
	return curve.get_closest_offset(pos)

func point_at(offset: float) -> Vector3:
	return curve.sample_baked(fposmod(offset, length))

func transform_at(offset: float) -> Transform3D:
	var o := fposmod(offset, length)
	var pos := curve.sample_baked(o)
	var ahead := curve.sample_baked(fposmod(o + 12.0, length))
	var fwd := (ahead - pos).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	return Transform3D(Basis(right, up, -fwd), pos)

func half_width_at_offset(offset: float) -> float:
	var r := fposmod(offset, length) / maxf(length, 1.0)
	var n := _halfs.size()
	if n == 0:
		return 50.0
	return _halfs[int(r * n) % n]

func wall_height_at_offset(offset: float) -> float:
	var r := fposmod(offset, length) / maxf(length, 1.0)
	var n := _heights.size()
	if n == 0:
		return 80.0
	return _heights[int(r * n) % n]

func chunk_count() -> int:
	return _chunk_count

func section_count() -> int:
	return _frames.size()

func triangle_count() -> int:
	return _frames.size() * (PROFILE.size() - 1) * 2
