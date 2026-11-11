class_name ShipMesh
extends RefCounted
## Loads the space fighter FBX once and bakes it down to a couple of surfaces.
##
## The model arrives as 39 separate MeshInstance3D nodes, which would be 39
## draw calls per ship - over 200 for a six-jet grid, against a budget of 100.
## Everything sharing a material is welded into one mesh with the node
## transforms baked in, so a ship costs two draw calls instead of thirty-nine.

const SOURCE := "res://assets/ship/space_fighter.fbx"
const TEX_DIR := "res://assets/ship/textures/"
## Model is 323 units nose to tail; the game's jet is about 11 m long.
const TARGET_LENGTH := 11.5

static var _cached: ArrayMesh = null
static var _cached_size := Vector3.ZERO
static var _had_normals := false

static func mesh() -> ArrayMesh:
	if _cached != null:
		return _cached
	_cached = _build()
	return _cached

## Metres the baked mesh spans, after scaling. Useful for placing trails.
static func size() -> Vector3:
	mesh()
	return _cached_size

static func _build() -> ArrayMesh:
	var packed: PackedScene = load(SOURCE)
	if packed == null:
		push_error("ShipMesh: cannot load %s" % SOURCE)
		return ArrayMesh.new()
	var root := packed.instantiate()

	var groups := {}          # material name -> SurfaceTool
	_collect(root, Transform3D.IDENTITY, groups)
	root.free()

	# Weld first, measure after. (Accumulating bounds inside a lambda does not
	# work: GDScript closures capture locals by value, so the outer AABB never
	# changes and every vertex ends up scaled by a factor of ten thousand.)
	var welded := ArrayMesh.new()
	for key in groups:
		var st: SurfaceTool = groups[key]
		if not _had_normals:
			st.generate_normals()
		st.index()
		var baked := st.commit()
		if baked != null and baked.get_surface_count() > 0:
			welded.add_surface_from_arrays(
				Mesh.PRIMITIVE_TRIANGLES, baked.surface_get_arrays(0))
	if welded.get_surface_count() == 0:
		return welded

	var bounds := welded.get_aabb()
	var length: float = maxf(bounds.size.z, 0.001)
	var scale := TARGET_LENGTH / length
	var centre := bounds.position + bounds.size * 0.5

	var out := ArrayMesh.new()
	for s in welded.get_surface_count():
		var arrays: Array = welded.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = (verts[i] - centre) * scale
		arrays[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cached_size = bounds.size * scale
	return out

static func _collect(node: Node, parent: Transform3D, groups: Dictionary) -> void:
	var here := parent
	if node is Node3D:
		here = parent * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var m: Mesh = node.mesh
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s)
			var key := str(mat.resource_name) if mat != null else "default"
			if key == "":
				key = str(s)
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = st
			_append(groups[key], m, s, here)
	for c in node.get_children():
		_collect(c, here, groups)

static func _append(st: SurfaceTool, m: Mesh, surface: int, xform: Transform3D) -> void:
	var arrays: Array = m.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	if not normals.is_empty():
		_had_normals = true
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		indices = PackedInt32Array(range(verts.size()))
	var basis := xform.basis
	for i in indices:
		if i < uvs.size():
			st.set_uv(uvs[i])
		if i < normals.size():
			st.set_normal((basis * normals[i]).normalized())
		st.add_vertex(xform * verts[i])

## Hull material: the pack's base colour plus its normal and roughness maps.
## `tint` is multiplied in so each bot keeps its livery.
static func material(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = _tex("15_-_Default_Base_Color.png")
	var normal := _tex("15_-_Default_Normal_DirectX.png")
	if normal != null:
		m.normal_enabled = true
		m.normal_texture = normal
		m.normal_scale = 0.8
	m.roughness_texture = _tex("15_-_Default_Roughness.png")
	# No emission. The pack's emissive map is close to full white, so turning
	# it on lit the whole airframe and flattened it into a pale silhouette.
	m.metallic = 0.25
	m.roughness = 0.75
	return m

static func _tex(file: String) -> Texture2D:
	var path := TEX_DIR + file
	if not ResourceLoader.exists(path):
		return null
	return load(path)
