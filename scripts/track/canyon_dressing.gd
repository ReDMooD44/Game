class_name CanyonDressing
extends RefCounted
## Scatters the canyon pack's rocks and plants along the foot of the walls.
##
## Everything lands in a band outboard of the collision hull, so none of it is
## reachable: these carry no colliders, and rock you can fly through is worse
## than no rock at all. Every placement is checked against the cross section
## before it is kept, the same way the big terrain formations are.
##
## Instances are welded into one mesh per segment per material rather than
## drawn individually. A few hundred props would otherwise be a few hundred
## draw calls, against a budget of 100; welded, a segment costs three.

const LIBRARY := "res://resources/canyon_props.tres"
const SEGMENTS := 26            ## stretches of track baked as one mesh each
const DRAW_DISTANCE := 760.0
const PER_SEGMENT := 48         ## placement attempts per segment, per side

## Two bands, because the canyon only has two places scenery can stand where
## it is both visible from the cockpit and impossible to reach.
##
## The rim is the good one: the race manager keeps the jet under 1.15 wall
## heights, so anything sitting on the lip is out of bounds by construction
## and has the sky behind it. Most of the pack goes here.
##
## The other is the shell between the collision hull and the visible wall at
## the foot of the cliff. It is only a few metres thick, so what goes there
## has to be small and is mostly buried - which is how scree against a cliff
## looks anyway.
const RIM_SHARE := 0.72         ## fraction of props placed along the rim
## Kept tight to the lip. There is no plateau mesh out past the rim - the
## canyon sweep simply ends there - so anything placed further out has nothing
## underneath it and hangs in the air.
const RIM_IN := 1.02
const RIM_OUT := 1.21
const RIM_LOW := 1.17
const RIM_HIGH := 1.25
const FOOT_IN := 0.80
const FOOT_OUT := 1.04
const FOOT_LOW := -0.02
const FOOT_HIGH := 0.30
## Metres of air left between a prop and anywhere the jet can reach.
const MARGIN := 3.0

## The canyon is 100 m across and the jet is 11 m long, so pack props at their
## authored size - a 2 m cactus, a 4 m boulder - are specks. Scaled up until
## they read at racing speed.
const ROCK_SCALE := Vector2(5.0, 15.0)
const PLANT_SCALE := Vector2(8.0, 18.0)
const GRASS_SCALE := Vector2(7.0, 15.0)

static var _library: PropLibrary = null

static func library() -> PropLibrary:
	if _library == null and ResourceLoader.exists(LIBRARY):
		_library = load(LIBRARY)
	return _library

## Rock taken from the pack's own texture, lit by the scene's sun like the
## terrain formations are.
static func rock_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	_set_albedo(m, "res://assets/props/rock_albedo.png")
	var n := "res://assets/props/rock_normal.png"
	if ResourceLoader.exists(n):
		m.normal_enabled = true
		m.normal_texture = load(n)
		m.normal_scale = 0.9
	m.albedo_color = Color(0.86, 0.66, 0.50)
	m.roughness = 1.0
	return m

static func plant_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	_set_albedo(m, "res://assets/props/plant_albedo.png")
	m.albedo_color = Color(0.82, 0.92, 0.70)
	m.roughness = 1.0
	# Cacti and sticks are built from flat cards; without this every one of
	# them is missing half its leaves depending on which way it faces.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_lift_backfaces(m)
	return m

static func grass_material() -> StandardMaterial3D:
	var m := grass_base()
	# Scissor rather than blended alpha: no sorting, no overdraw cost worth
	# worrying about on a phone, and grass does not need soft edges.
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_lift_backfaces(m)
	return m

static func grass_base() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	_set_albedo(m, "res://assets/props/grass_albedo.tga")
	m.albedo_color = Color(0.90, 0.95, 0.72)
	m.roughness = 1.0
	return m

## Two-sided foliage has one lit side and one that comes out solid black,
## because turning culling off does not flip the normal behind it. A little
## emission taken from the plant's own texture keeps the shaded side readable
## without washing the lit side out.
static func _lift_backfaces(m: StandardMaterial3D) -> void:
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission = Color(1.0, 1.0, 1.0)
	m.emission_energy_multiplier = 0.38

static func _set_albedo(m: StandardMaterial3D, path: String) -> void:
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)

static func _material_for(kind: int) -> StandardMaterial3D:
	match kind:
		PropLibrary.Kind.ROCK:
			return rock_material()
		PropLibrary.Kind.PLANT:
			return plant_material()
		_:
			return grass_material()

static func _scale_range(kind: int) -> Vector2:
	match kind:
		PropLibrary.Kind.ROCK:
			return ROCK_SCALE
		PropLibrary.Kind.PLANT:
			return PLANT_SCALE
		_:
			return GRASS_SCALE

## Returns how many props were placed.
static func populate(canyon: Canyon, parent: Node3D) -> int:
	var lib := library()
	if lib == null or lib.meshes.is_empty():
		return 0
	var kinds := [PropLibrary.Kind.ROCK, PropLibrary.Kind.PLANT, PropLibrary.Kind.GRASS]
	var pools := {}
	for k in kinds:
		pools[k] = lib.of_kind(k)

	var rng := RandomNumberGenerator.new()
	var placed := 0
	for seg in SEGMENTS:
		# Deterministic: the same track dresses the same way every run, so a
		# corner someone has learned does not rearrange itself.
		rng.seed = hash("dressing") + seg * 7919
		var from := canyon.length * float(seg) / SEGMENTS
		var span := canyon.length / SEGMENTS
		var builders := {}
		for k in kinds:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			builders[k] = st
		var used := {}

		for side_index in 2:
			var side := -1.0 if side_index == 0 else 1.0
			for _try in PER_SEGMENT:
				var kind: int = kinds[rng.randi_range(0, kinds.size() - 1)]
				var pool: PackedInt32Array = pools[kind]
				if pool.is_empty():
					continue
				var index: int = pool[rng.randi_range(0, pool.size() - 1)]
				var xf := _place(canyon, lib, index, kind, from + rng.randf() * span,
					side, rng)
				if xf == Transform3D():
					continue
				_append(builders[kind], lib.meshes[index], xf)
				used[kind] = true
				placed += 1

		for k in kinds:
			if not used.has(k):
				continue
			var st: SurfaceTool = builders[k]
			st.index()
			var mesh := st.commit()
			if mesh == null or mesh.get_surface_count() == 0:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = _material_for(k)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = DRAW_DISTANCE
			mi.visibility_range_end_margin = 220.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			parent.add_child(mi)
	return placed

## Works out where one prop sits, or returns an empty transform if that spot
## would put it anywhere the jet can reach.
static func _place(canyon: Canyon, lib: PropLibrary, index: int, kind: int,
		offset: float, side: float, rng: RandomNumberGenerator) -> Transform3D:
	var t := canyon.transform_at(offset)
	var hw := canyon.half_width_at_offset(offset)
	var h := canyon.wall_height_at_offset(offset)
	var limits := _scale_range(kind)
	var scale := rng.randf_range(limits.x, limits.y)
	var box := lib.aabb_of(index)

	var on_rim := rng.randf() < RIM_SHARE
	var lateral := rng.randf_range(
		RIM_IN if on_rim else FOOT_IN,
		RIM_OUT if on_rim else FOOT_OUT) * hw * side
	var height := rng.randf_range(
		RIM_LOW if on_rim else FOOT_LOW,
		RIM_HIGH if on_rim else FOOT_HIGH) * h
	# Sat on its own base rather than centred, so nothing floats or sinks.
	var pos := t.origin + t.basis.x * lateral \
		+ t.basis.y * (height - box.position.y * scale)
	var basis := t.basis.rotated(t.basis.y, rng.randf() * TAU)
	# Leaned into the wall, which is how scree actually piles up against one.
	basis = basis.rotated(t.basis.z, rng.randf_range(-0.12, 0.12) * side)
	var xf := Transform3D(basis.scaled(Vector3(scale, scale, scale)), pos)
	return xf if _clear_of_flight(canyon, box, xf) else Transform3D()

## True when no part of the prop reaches into the air the jet can fly through.
## Measured against the collision hull rather than the rim: these are meant to
## sit against the wall, half buried in it, not out beyond the canyon.
static func _clear_of_flight(canyon: Canyon, box: AABB, xf: Transform3D) -> bool:
	for ix in 3:
		for iy in 3:
			for iz in 3:
				var p: Vector3 = xf * (box.position + Vector3(
					box.size.x * ix * 0.5, box.size.y * iy * 0.5, box.size.z * iz * 0.5))
				if canyon.is_reachable(p, MARGIN):
					return false
	return true

static func _append(st: SurfaceTool, mesh: ArrayMesh, xf: Transform3D) -> void:
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
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
				st.set_normal((xf.basis * normals[i]).normalized())
			st.add_vertex(xf * verts[i])
